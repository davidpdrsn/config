import type { ExtensionAPI, ExtensionContext } from "@mariozechner/pi-coding-agent";
import { Type } from "@sinclair/typebox";

type Mode = "normal" | "plan";

interface PlanModeState {
	mode: Mode;
}

const PLAN_MODE_BASH_ALLOWED_COMMANDS = new Set([
	"ls",
	"pwd",
	"find",
	"grep",
	"rg",
	"fd",
	"cat",
	"head",
	"tail",
	"wc",
	"sort",
	"uniq",
	"cut",
	"file",
	"stat",
	"du",
	"df",
	"jq",
]);

const PLAN_MODE_BASH_ALLOWED_GIT_SUBCOMMANDS = new Set(["status", "log", "diff", "show", "branch"]);
const PLAN_MODE_BASH_ALLOWED_JJ_SUBCOMMANDS = new Set([
	"root",
	"status",
	"log",
	"diff",
	"show",
	"bookmark",
	"help",
	"version",
]);
const PLAN_MODE_BASH_ALLOWED_JJ_BOOKMARK_SUBCOMMANDS = new Set(["list"]);

function normalizeCommandName(token: string): string {
	const stripped = token.replace(/^['"]+|['"]+$/g, "");
	const basename = stripped.split("/").pop() ?? stripped;
	return basename.toLowerCase();
}

function firstCommandToken(segment: string): string | undefined {
	const tokens = segment.trim().split(/\s+/).filter(Boolean);

	for (const token of tokens) {
		if (/^[A-Za-z_][A-Za-z0-9_]*=.*/.test(token)) continue;
		return token;
	}

	return undefined;
}

function nextArgumentToken(tokens: string[], startIndex: number): string | undefined {
	for (let i = startIndex; i < tokens.length; i++) {
		const token = tokens[i];
		if (!token || token.startsWith("-")) continue;
		if (/^[A-Za-z_][A-Za-z0-9_]*=.*/.test(token)) continue;
		return token;
	}
	return undefined;
}

function hasHelpFlag(tokens: string[]): boolean {
	return tokens.some((token) => token === "--help" || token === "-h");
}

function splitCommandSegments(command: string): string[] {
	const segments: string[] = [];
	let current = "";
	let inSingleQuote = false;
	let inDoubleQuote = false;
	let escaped = false;

	for (let i = 0; i < command.length; i++) {
		const char = command[i];
		const next = command[i + 1];

		if (escaped) {
			current += char;
			escaped = false;
			continue;
		}

		if (char === "\\" && !inSingleQuote) {
			current += char;
			escaped = true;
			continue;
		}

		if (inSingleQuote) {
			current += char;
			if (char === "'") inSingleQuote = false;
			continue;
		}

		if (inDoubleQuote) {
			current += char;
			if (char === '"') inDoubleQuote = false;
			continue;
		}

		if (char === "'") {
			inSingleQuote = true;
			current += char;
			continue;
		}

		if (char === '"') {
			inDoubleQuote = true;
			current += char;
			continue;
		}

		const isDoubleSeparator =
			(char === "&" && next === "&") ||
			(char === "|" && next === "|");
		if (isDoubleSeparator) {
			const segment = current.trim();
			if (segment) segments.push(segment);
			current = "";
			i++;
			continue;
		}

		const isSingleSeparator = char === "|" || char === ";" || char === "\n";
		if (isSingleSeparator) {
			const segment = current.trim();
			if (segment) segments.push(segment);
			current = "";
			continue;
		}

		current += char;
	}

	const tail = current.trim();
	if (tail) segments.push(tail);

	return segments;
}

function validatePlanModeBashCommand(command: string): { ok: true } | { ok: false; reason: string } {
	const segments = splitCommandSegments(command);

	for (const segment of segments) {
		const commandToken = firstCommandToken(segment);
		if (!commandToken) continue;

		const normalizedCommand = normalizeCommandName(commandToken);
		if (normalizedCommand === "git") {
			const tokens = segment.split(/\s+/).filter(Boolean);
			const subcommandToken = nextArgumentToken(tokens, 1);
			const subcommand = subcommandToken ? normalizeCommandName(subcommandToken) : undefined;
			if (!subcommand || !PLAN_MODE_BASH_ALLOWED_GIT_SUBCOMMANDS.has(subcommand)) {
				return {
					ok: false,
					reason: `Disallowed git subcommand in plan mode: ${subcommand ?? "(missing)"}`,
				};
			}
			continue;
		}

		if (normalizedCommand === "jj") {
			const tokens = segment.split(/\s+/).filter(Boolean);
			const subcommandToken = nextArgumentToken(tokens, 1);
			const subcommand = subcommandToken ? normalizeCommandName(subcommandToken) : undefined;

			if (!subcommand || !PLAN_MODE_BASH_ALLOWED_JJ_SUBCOMMANDS.has(subcommand)) {
				return {
					ok: false,
					reason: `Disallowed jj subcommand in plan mode: ${subcommand ?? "(missing)"}`,
				};
			}

			if (hasHelpFlag(tokens) || subcommand === "help" || subcommand === "version") {
				continue;
			}

			if (subcommand === "bookmark") {
				const bookmarkSubcommandToken = nextArgumentToken(tokens, 2);
				const bookmarkSubcommand = bookmarkSubcommandToken
					? normalizeCommandName(bookmarkSubcommandToken)
					: undefined;
				if (!bookmarkSubcommand || !PLAN_MODE_BASH_ALLOWED_JJ_BOOKMARK_SUBCOMMANDS.has(bookmarkSubcommand)) {
					return {
						ok: false,
						reason: `Disallowed jj bookmark subcommand in plan mode: ${bookmarkSubcommand ?? "(missing)"}`,
					};
				}
			}

			continue;
		}

		if (!PLAN_MODE_BASH_ALLOWED_COMMANDS.has(normalizedCommand)) {
			return {
				ok: false,
				reason: `Disallowed command in plan mode: ${normalizedCommand}`,
			};
		}
	}

	return { ok: true };
}

function makeSystemPromptAddition(mode: Mode): string {
	return `

[Plan mode controller]
You can control planning behavior using tools:
- enter_plan_mode: switch to planning behavior.
- exit_plan_mode: switch to normal execution behavior.

Mode switching policy:
- Decide mode based on the user's latest message and intent.
- If the user asks for planning, exploration, tradeoffs, architecture, sequencing, or "how should we do this", call enter_plan_mode first.
- If plan mode is active, never call exit_plan_mode unless the latest user message is exactly \`go\` (and nothing else).
- Do not leave plan mode just because the user asks to execute/build/implement; wait for explicit \`go\` or manual /plan.
- Avoid flip-flopping. Switch only when intent clearly changes.

Current mode: ${mode}

Behavior in plan mode:
- Prioritize analysis and planning.
- Provide assumptions, risks, alternatives, and a concrete step-by-step plan.
- Ask clarifying questions.
- Bash is allowed, but only for read-only analysis commands from the allowlist (including read-only git/jj inspection commands).
- Do not use shell tricks (chaining, substitution, redirection, heredocs) to mutate files or bypass restrictions.
- Never use interpreters or non-allowlisted commands to edit files.
- Do not start implementing until plan mode is exited (via /plan or exact \`go\`).

Behavior in normal mode:
- Execute requested work normally.
- If planning is requested again, switch back to plan mode first.
`;
}

export default function (pi: ExtensionAPI): void {
	let mode: Mode = "normal";
	let allowToolExitForCurrentPrompt = false;

	function persistState() {
		pi.appendEntry("plan-mode", { mode } satisfies PlanModeState);
	}

	function updateUi(ctx: ExtensionContext) {
		if (mode === "plan") {
			ctx.ui.setStatus("plan-mode", undefined);
			ctx.ui.setWidget("plan-mode", ["⏸ Plan mode is active"], { placement: "belowEditor" });
		} else {
			ctx.ui.setStatus("plan-mode", undefined);
			ctx.ui.setWidget("plan-mode", undefined);
		}
	}

	function setMode(nextMode: Mode, ctx: ExtensionContext, source: "tool" | "command") {
		if (mode === nextMode) {
			if (source === "tool") {
				ctx.ui.notify(`Plan mode already ${nextMode === "plan" ? "enabled" : "disabled"}.`, "info");
			}
			updateUi(ctx);
			return false;
		}

		mode = nextMode;
		persistState();
		updateUi(ctx);

		const message =
			nextMode === "plan" ? "Entered plan mode" : "Exited plan mode";
		ctx.ui.notify(message, "info");
		return true;
	}

	pi.registerTool({
		name: "enter_plan_mode",
		label: "Enter Plan Mode",
		description:
			"Switch to planning behavior mode. Use this when user intent is planning, exploration, design, tradeoff analysis, or sequencing.",
		parameters: Type.Object({}),
		async execute(_toolCallId, _params, _signal, _onUpdate, ctx) {
			setMode("plan", ctx, "tool");
			return {
				content: [{ type: "text", text: "Plan mode is now active." }],
				details: { mode },
			};
		},
	});

	pi.registerTool({
		name: "exit_plan_mode",
		label: "Exit Plan Mode",
		description:
			"Switch back to normal execution mode. Only allowed when user explicitly sends `go` (exactly) for this prompt.",
		parameters: Type.Object({}),
		async execute(_toolCallId, _params, _signal, _onUpdate, ctx) {
			if (mode === "plan" && !allowToolExitForCurrentPrompt) {
				ctx.ui.notify("Plan mode can only be exited via /plan or when user prompt is exactly `go`.", "info");
				return {
					content: [
						{
							type: "text",
							text: "Refusing to exit plan mode. Ask the user to run /plan or send exactly `go`.",
						},
					],
					details: { mode, allowToolExitForCurrentPrompt },
				};
			}

			setMode("normal", ctx, "tool");
			return {
				content: [{ type: "text", text: "Plan mode is now inactive." }],
				details: { mode },
			};
		},
	});

	pi.registerCommand("plan", {
		description: "Toggle plan mode manually",
		handler: async (_args, ctx) => {
			setMode(mode === "plan" ? "normal" : "plan", ctx, "command");
		},
	});

	pi.on("tool_call", async (event) => {
		if (mode !== "plan") return;

		if (event.toolName === "edit" || event.toolName === "write") {
			return {
				block: true,
				reason: "Plan mode is active. Exit via /plan or ask user to send exactly `go` before editing/writing.",
			};
		}

		if (event.toolName === "bash") {
			const command = typeof event.input?.command === "string" ? event.input.command : "";
			const validation = validatePlanModeBashCommand(command);
			if (!validation.ok) {
				return {
					block: true,
					reason: `Plan mode blocks bash command. ${validation.reason}`,
				};
			}
		}
	});

	pi.on("before_agent_start", async (event, _ctx) => {
		allowToolExitForCurrentPrompt = event.prompt.trim() === "go";
		return {
			systemPrompt: event.systemPrompt + makeSystemPromptAddition(mode),
		};
	});

	pi.on("session_start", async (_event, ctx) => {
		const lastState = ctx.sessionManager
			.getEntries()
			.filter((entry: { type: string; customType?: string }) => {
				return entry.type === "custom" && entry.customType === "plan-mode";
			})
			.pop() as { data?: PlanModeState } | undefined;

		if (lastState?.data?.mode === "plan" || lastState?.data?.mode === "normal") {
			mode = lastState.data.mode;
		}

		updateUi(ctx);
	});
}
