import { access, copyFile, mkdir, readFile, writeFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import * as Diff from "diff";
import { renderDiff, type ExtensionAPI, type ExtensionContext } from "@mariozechner/pi-coding-agent";
import { Text } from "@mariozechner/pi-tui";
import { Type } from "@sinclair/typebox";

const PLAN_MODE_TOOLS = [
	"read",
	"bash",
	"grep",
	"find",
	"ls",
	"questionnaire",
	"plan_show",
	"plan_init",
	"plan_revise",
] as const;

const STATE_CUSTOM_TYPE = "plan-mode-state";

interface PlanModeState {
	enabled: boolean;
	planFile: string;
	historyDir: string;
	toolsBeforePlanMode: string[];
}

interface PlanToolDetails {
	planFile: string;
	snapshot?: string;
	diff: string;
	mustEchoVerbatim: true;
}

interface PlanShowToolDetails {
	planFile?: string;
	lineCount?: number;
	charCount?: number;
}

function getPaths(ctx: ExtensionContext): { planFile: string; historyDir: string } {
	const sessionId = ctx.sessionManager.getSessionId();
	return {
		planFile: join(ctx.cwd, ".pi", "tmp", "plans", `${sessionId}.md`),
		historyDir: join(ctx.cwd, ".pi", "tmp", "plans", "history"),
	};
}

function toRelative(cwd: string, fullPath: string): string {
	if (fullPath.startsWith(`${cwd}/`)) return fullPath.slice(cwd.length + 1);
	return fullPath;
}

function timestampForFileName(): string {
	return new Date().toISOString().replace(/[:.]/g, "-");
}

async function fileExists(path: string): Promise<boolean> {
	try {
		await access(path);
		return true;
	} catch {
		return false;
	}
}

export default function (pi: ExtensionAPI): void {
	let enabled = false;
	let planFile = "";
	let historyDir = "";
	let toolsBeforePlanMode: string[] = [];
	let mustEchoPlanVerbatim = false;

	function syncPathsFromContext(ctx: ExtensionContext): void {
		const paths = getPaths(ctx);
		if (!planFile) planFile = paths.planFile;
		if (!historyDir) historyDir = paths.historyDir;
	}

	async function ensurePlanDirs(ctx: ExtensionContext): Promise<void> {
		syncPathsFromContext(ctx);
		await mkdir(dirname(planFile), { recursive: true });
		await mkdir(historyDir, { recursive: true });
	}

	function persistState() {
		pi.appendEntry(STATE_CUSTOM_TYPE, {
			enabled,
			planFile,
			historyDir,
			toolsBeforePlanMode,
		} satisfies PlanModeState);
	}

	function updateUi(ctx: ExtensionContext) {
		if (!enabled) {
			ctx.ui.setStatus("plan-mode", undefined);
			ctx.ui.setWidget("plan-mode", undefined);
			return;
		}

		ctx.ui.setStatus("plan-mode", undefined);
		ctx.ui.setWidget("plan-mode", (_tui, theme) => new Text(theme.fg("warning", "⏸ plan"), 0, 0), {
			placement: "belowEditor",
		});
	}

	async function setPlanMode(next: boolean, ctx: ExtensionContext): Promise<void> {
		const paths = getPaths(ctx);
		planFile = paths.planFile;
		historyDir = paths.historyDir;

		if (next === enabled) {
			updateUi(ctx);
			return;
		}

		enabled = next;
		if (enabled) {
			toolsBeforePlanMode = pi.getActiveTools();
			pi.setActiveTools([...PLAN_MODE_TOOLS]);
			await ensurePlanDirs(ctx);
			ctx.ui.notify(`Plan mode enabled. Plan file: ${toRelative(ctx.cwd, planFile)}`, "info");
		} else {
			mustEchoPlanVerbatim = false;
			const restoredTools = toolsBeforePlanMode.length > 0 ? toolsBeforePlanMode : pi.getActiveTools();
			pi.setActiveTools(restoredTools);
			ctx.ui.notify("Plan mode disabled.", "info");
		}

		updateUi(ctx);
		persistState();
	}

	async function makeSnapshotIfExists(ctx: ExtensionContext): Promise<string | undefined> {
		await ensurePlanDirs(ctx);
		if (!(await fileExists(planFile))) return undefined;

		const snapshotPath = join(historyDir, `${ctx.sessionManager.getSessionId()}-${timestampForFileName()}.md`);
		await copyFile(planFile, snapshotPath);
		return snapshotPath;
	}

	function generateNumberedDiffString(oldContent: string, newContent: string, contextLines = 4): string {
		const parts = Diff.diffLines(oldContent, newContent);
		const output: string[] = [];
		const oldLines = oldContent.split("\n");
		const newLines = newContent.split("\n");
		const maxLineNum = Math.max(oldLines.length, newLines.length);
		const lineNumWidth = String(maxLineNum).length;

		let oldLineNum = 1;
		let newLineNum = 1;
		let lastWasChange = false;

		for (let i = 0; i < parts.length; i++) {
			const part = parts[i];
			const raw = part.value.split("\n");
			if (raw[raw.length - 1] === "") raw.pop();

			if (part.added || part.removed) {
				for (const line of raw) {
					if (part.added) {
						const lineNum = String(newLineNum).padStart(lineNumWidth, " ");
						output.push(`+${lineNum} ${line}`);
						newLineNum++;
					} else {
						const lineNum = String(oldLineNum).padStart(lineNumWidth, " ");
						output.push(`-${lineNum} ${line}`);
						oldLineNum++;
					}
				}
				lastWasChange = true;
				continue;
			}

			const nextPartIsChange = i < parts.length - 1 && (parts[i + 1].added || parts[i + 1].removed);
			if (lastWasChange || nextPartIsChange) {
				let linesToShow = raw;
				let skipStart = 0;
				let skipEnd = 0;

				if (!lastWasChange) {
					skipStart = Math.max(0, raw.length - contextLines);
					linesToShow = raw.slice(skipStart);
				}
				if (!nextPartIsChange && linesToShow.length > contextLines) {
					skipEnd = linesToShow.length - contextLines;
					linesToShow = linesToShow.slice(0, contextLines);
				}

				if (skipStart > 0) {
					output.push(` ${"".padStart(lineNumWidth, " ")} ...`);
					oldLineNum += skipStart;
					newLineNum += skipStart;
				}

				for (const line of linesToShow) {
					const lineNum = String(oldLineNum).padStart(lineNumWidth, " ");
					output.push(` ${lineNum} ${line}`);
					oldLineNum++;
					newLineNum++;
				}

				if (skipEnd > 0) {
					output.push(` ${"".padStart(lineNumWidth, " ")} ...`);
					oldLineNum += skipEnd;
					newLineNum += skipEnd;
				}
			} else {
				oldLineNum += raw.length;
				newLineNum += raw.length;
			}

			lastWasChange = false;
		}

		return output.join("\n");
	}

	async function unifiedDiff(oldPath: string, newPath: string): Promise<string> {
		const oldContent = oldPath === "/dev/null" || !(await fileExists(oldPath)) ? "" : await readFile(oldPath, "utf8");
		const newContent = (await fileExists(newPath)) ? await readFile(newPath, "utf8") : "";
		return generateNumberedDiffString(oldContent, newContent);
	}

	function normalizePlanContent(content: string): string {
		return content.endsWith("\n") ? content : `${content}\n`;
	}

	function isFinalAssistantTextMessage(message: unknown): boolean {
		if (!message || typeof message !== "object") return false;
		const m = message as { role?: string; content?: Array<{ type?: string; text?: string }> };
		if (m.role !== "assistant" || !Array.isArray(m.content)) return false;
		const hasToolCall = m.content.some((part) => part?.type === "toolCall");
		const hasText = m.content.some((part) => part?.type === "text" && typeof part.text === "string" && part.text.length > 0);
		return hasText && !hasToolCall;
	}

	function renderPlanToolResult(_label: string, result: { details?: unknown }, theme: any): Text {
		const details = (result.details ?? {}) as Partial<PlanToolDetails>;
		let text = theme.fg("accent", details.planFile ?? "");
		if (details.snapshot) text += `\n${theme.fg("muted", `Snapshot: ${details.snapshot}`)}`;
		if (details.diff) text += `\n\n${renderDiff(details.diff)}`;
		return new Text(text, 0, 0);
	}

	function renderPlanShowResult(result: { details?: unknown; content?: Array<{ type?: string; text?: string }> }, theme: any): Text {
		const details = (result.details ?? {}) as Partial<PlanShowToolDetails>;
		if (!details.planFile) {
			const fallback = result.content?.find((part) => part?.type === "text")?.text ?? "";
			return new Text(fallback, 0, 0);
		}

		let text = `${theme.fg("success", "Loaded plan")}: ${theme.fg("accent", details.planFile)}`;
		if (typeof details.lineCount === "number" && typeof details.charCount === "number") {
			text += `\n${theme.fg("muted", `${details.lineCount} lines, ${details.charCount} chars`)}`;
		}
		return new Text(text, 0, 0);
	}

	function toolNotInPlanModeText(ctx: ExtensionContext): string {
		const relPlanFile = toRelative(ctx.cwd, planFile || getPaths(ctx).planFile);
		return `Plan mode is not active. Call enter_plan_mode first. Target plan file: ${relPlanFile}`;
	}

	pi.registerTool({
		name: "enter_plan_mode",
		label: "Enter Plan Mode",
		description:
			"Enter collaborative plan mode. Use when user asks to plan first or revise plans before execution.",
		parameters: Type.Object({}),
		async execute(_toolCallId, _params, _signal, _onUpdate, ctx) {
			await setPlanMode(true, ctx);
			const relPlanFile = toRelative(ctx.cwd, planFile);
			return {
				content: [
					{
						type: "text",
						text: `Plan mode enabled. Source-of-truth plan file: ${relPlanFile}. Use plan_init/plan_revise/plan_show and wait for exact 'go' to exit.`,
					},
				],
				details: { enabled: true, planFile: relPlanFile },
			};
		},
	});

	pi.registerTool({
		name: "plan_show",
		label: "Show Plan",
		description: "Show current plan file contents.",
		parameters: Type.Object({}),
		renderResult(result, _options, theme) {
			return renderPlanShowResult(result, theme);
		},
		async execute(_toolCallId, _params, _signal, _onUpdate, ctx) {
			syncPathsFromContext(ctx);
			if (!enabled) {
				return { content: [{ type: "text", text: toolNotInPlanModeText(ctx) }], details: {} };
			}
			if (!(await fileExists(planFile))) {
				return {
					content: [{ type: "text", text: `Plan file does not exist yet: ${toRelative(ctx.cwd, planFile)}` }],
					details: {},
				};
			}

			const content = await readFile(planFile, "utf8");
			const relPlanFile = toRelative(ctx.cwd, planFile);
			const lineCount = content.split("\n").length;
			return {
				content: [
					{
						type: "text",
						text: `Current plan (${relPlanFile}):\n\n${content}`,
					},
				],
				details: {
					planFile: relPlanFile,
					lineCount,
					charCount: content.length,
				} satisfies PlanShowToolDetails,
			};
		},
	});

	pi.registerTool({
		name: "plan_init",
		label: "Initialize Plan",
		description:
			"Start a new plan by replacing the session plan file with the full plan markdown.",
		parameters: Type.Object({
			content: Type.String({ description: "Full markdown content for the plan file" }),
		}),
		renderResult(result, _options, theme) {
			return renderPlanToolResult("plan_init", result, theme);
		},
		async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
			syncPathsFromContext(ctx);
			if (!enabled) {
				return { content: [{ type: "text", text: toolNotInPlanModeText(ctx) }], details: {} };
			}

			await ensurePlanDirs(ctx);
			const normalizedContent = normalizePlanContent(params.content);
			const snapshot = await makeSnapshotIfExists(ctx);
			await writeFile(planFile, normalizedContent, "utf8");
			const diff = await unifiedDiff(snapshot ?? "/dev/null", planFile);
			const relPlanFile = toRelative(ctx.cwd, planFile);
			const relSnapshot = snapshot ? toRelative(ctx.cwd, snapshot) : undefined;

			mustEchoPlanVerbatim = true;
			return {
				content: [{ type: "text", text: `Plan written to ${relPlanFile}.` }],
				details: {
					planFile: relPlanFile,
					snapshot: relSnapshot,
					diff,
					mustEchoVerbatim: true,
				} satisfies PlanToolDetails,
			};
		},
	});

	pi.registerTool({
		name: "plan_revise",
		label: "Revise Plan",
		description:
			"Revise existing plan file by providing full updated markdown. Always snapshots previous version and returns a unified diff.",
		parameters: Type.Object({
			content: Type.String({ description: "Full revised markdown content for the plan file" }),
		}),
		renderResult(result, _options, theme) {
			return renderPlanToolResult("plan_revise", result, theme);
		},
		async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
			syncPathsFromContext(ctx);
			if (!enabled) {
				return { content: [{ type: "text", text: toolNotInPlanModeText(ctx) }], details: {} };
			}

			await ensurePlanDirs(ctx);
			const normalizedContent = normalizePlanContent(params.content);
			const snapshot = await makeSnapshotIfExists(ctx);
			await writeFile(planFile, normalizedContent, "utf8");
			const diff = await unifiedDiff(snapshot ?? "/dev/null", planFile);
			const relPlanFile = toRelative(ctx.cwd, planFile);
			const relSnapshot = snapshot ? toRelative(ctx.cwd, snapshot) : undefined;

			mustEchoPlanVerbatim = true;
			return {
				content: [{ type: "text", text: `Plan revised at ${relPlanFile}.` }],
				details: {
					planFile: relPlanFile,
					snapshot: relSnapshot,
					diff,
					mustEchoVerbatim: true,
				} satisfies PlanToolDetails,
			};
		},
	});

	pi.registerCommand("plan", {
		description: "Toggle plan mode",
		handler: async (_args, ctx) => {
			await setPlanMode(!enabled, ctx);
		},
	});

	pi.on("session_start", async (_event, ctx) => {
		const paths = getPaths(ctx);
		planFile = paths.planFile;
		historyDir = paths.historyDir;

		const entries = ctx.sessionManager.getEntries();
		const latest = [...entries]
			.reverse()
			.find((entry) => entry.type === "custom" && (entry as { customType?: string }).customType === STATE_CUSTOM_TYPE) as
			| { data?: PlanModeState }
			| undefined;

		if (latest?.data) {
			enabled = latest.data.enabled;
			planFile = latest.data.planFile || planFile;
			historyDir = latest.data.historyDir || historyDir;
			toolsBeforePlanMode = latest.data.toolsBeforePlanMode || [];
		}
		if (!enabled) mustEchoPlanVerbatim = false;

		if (enabled) {
			await ensurePlanDirs(ctx);
			pi.setActiveTools([...PLAN_MODE_TOOLS]);
		}

		updateUi(ctx);
	});

	pi.on("input", async (event, ctx) => {
		if (event.source === "extension") return { action: "continue" };

		const text = event.text.trim();
		if (!text) return { action: "continue" };

		if (enabled && text === "go") {
			await setPlanMode(false, ctx);
			const relPlanFile = toRelative(ctx.cwd, planFile);
			return {
				action: "transform",
				text: `Execution mode begins now. Read ${relPlanFile} and execute that approved plan step by step.`,
			};
		}

		return { action: "continue" };
	});

	pi.on("tool_call", async (event) => {
		if (!enabled) return;

		if (event.toolName === "edit" || event.toolName === "write") {
			return {
				block: true,
				reason:
					"Plan mode blocks generic edit/write tools. Use plan_init/plan_revise for plan file updates.",
			};
		}
	});

	pi.on("context", async (event) => {
		if (!enabled || !mustEchoPlanVerbatim) return;
		if (!(await fileExists(planFile))) {
			mustEchoPlanVerbatim = false;
			return;
		}

		const latestPlan = await readFile(planFile, "utf8");
		const steerMessage = {
			role: "user" as const,
			content:
				`Output the revised plan verbatim from ${planFile} in your next response. ` +
				"Do not summarize or paraphrase. Do not add any introduction or commentary. Output only the exact markdown plan text below:\n\n" +
				latestPlan,
			timestamp: Date.now(),
		};

		return {
			messages: [...event.messages, steerMessage],
		};
	});

	pi.on("message_end", async (event) => {
		if (!mustEchoPlanVerbatim) return;
		if (isFinalAssistantTextMessage(event.message)) {
			mustEchoPlanVerbatim = false;
		}
	});

	pi.on("before_agent_start", async (event, ctx) => {
		const paths = getPaths(ctx);
		const relPlanFile = toRelative(ctx.cwd, planFile || paths.planFile);
		const relHistoryDir = toRelative(ctx.cwd, historyDir || paths.historyDir);

		if (!enabled) {
			return {
				systemPrompt:
					event.systemPrompt +
					`\n\n[Plan mode availability]\n- If the user asks to plan first, asks for plan revisions, or wants planning before execution, call tool enter_plan_mode first.\n- Do not rely on strict trigger phrases; infer intent from user request.`,
			};
		}

		return {
			systemPrompt:
				event.systemPrompt +
				`\n\n[Plan mode]\n- Plan mode is active.\n- The plan file is the source of truth: ${relPlanFile}\n- Always read ${relPlanFile} before discussing, answering questions about, or revising the plan.\n- Fold user feedback into the existing plan file; do not ignore previous content.\n- Generic edit/write tools are blocked in plan mode.\n- Use plan_show to inspect, plan_init to start a new plan (discarding previous content), and plan_revise to update the current plan.\n- plan_init/plan_revise automatically maintain timestamped snapshots in ${relHistoryDir} and return unified diff only.\n- After any successful plan_init/plan_revise call, your next assistant message MUST print the revised plan verbatim from ${relPlanFile}.\n- Do not summarize/paraphrase the plan after writing it. If needed, call plan_show and copy the plan text exactly.\n- bash is available, but DO NOT make code or config edits with bash.\n- Strongly avoid bash file-mutation patterns for repository files: sed -i, perl -pi, awk in-place rewrites, redirections (> or >>), tee, mv/cp overwrites, here-doc writes.\n\n[Exit plan mode]\n- Stay in plan mode until the user sends exact text: go`,
		};
	});
}
