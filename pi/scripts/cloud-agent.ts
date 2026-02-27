import { access } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { spawn } from "node:child_process";
import { cac } from "cac";

interface ExecResult {
	code: number | null;
	stdout: string;
	stderr: string;
}

interface StatusSession {
	session: string;
	target: string | null;
	state: "running" | "done" | "partial" | "blocked" | "failed" | "unknown";
	status: string | null;
	bookmark: string | null;
	workspace: string | null;
	followUp: string | null;
	summary: string[];
	lastLine: string | null;
	pane?: string;
}

interface StatusOutput {
	host: string;
	pattern: string;
	generatedAt: string;
	includePane: boolean;
	sessions: StatusSession[];
	counts: {
		total: number;
		running: number;
		done: number;
		partial: number;
		blocked: number;
		failed: number;
		unknown: number;
	};
}

function workerPath(): string {
	const here = path.dirname(fileURLToPath(import.meta.url));
	return path.resolve(here, "./cloud.ts");
}

async function exec(command: string, args: string[], options?: { input?: string; timeoutMs?: number }): Promise<ExecResult> {
	const timeoutMs = options?.timeoutMs ?? 60_000;
	return await new Promise((resolve) => {
		const child = spawn(command, args, { stdio: ["pipe", "pipe", "pipe"] });
		let stdout = "";
		let stderr = "";
		let timedOut = false;

		const timer = setTimeout(() => {
			timedOut = true;
			child.kill("SIGTERM");
			setTimeout(() => child.kill("SIGKILL"), 1_000);
		}, timeoutMs);

		if (options?.input) {
			child.stdin.write(options.input);
		}
		child.stdin.end();

		child.stdout.on("data", (chunk: Buffer) => {
			stdout += chunk.toString("utf8");
		});
		child.stderr.on("data", (chunk: Buffer) => {
			stderr += chunk.toString("utf8");
		});
		child.on("error", (err) => {
			clearTimeout(timer);
			resolve({ code: 1, stdout, stderr: `${stderr}\n${String(err)}`.trim() });
		});
		child.on("close", (code) => {
			clearTimeout(timer);
			if (timedOut) {
				resolve({ code: 124, stdout, stderr: `${stderr}\nCommand timed out after ${timeoutMs}ms`.trim() });
				return;
			}
			resolve({ code, stdout, stderr });
		});
	});
}

async function runWorker(command: "run" | "clean", context: Record<string, unknown>, json: boolean): Promise<number> {
	const contextBase64 = Buffer.from(JSON.stringify(context), "utf8").toString("base64");
	const child = spawn("bun", [workerPath(), command, "--mode", json ? "ndjson" : "plain", "--context-base64", contextBase64], {
		stdio: "inherit",
	});

	return await new Promise((resolve) => {
		child.on("close", (code) => resolve(code ?? 1));
		child.on("error", () => resolve(1));
	});
}

function pickLast(lines: string[], prefix: string): string | null {
	for (let i = lines.length - 1; i >= 0; i--) {
		if (lines[i].startsWith(prefix)) {
			const value = lines[i].slice(prefix.length).trim();
			return value.length > 0 ? value : null;
		}
	}
	return null;
}

function parseSummary(lines: string[]): string[] {
	const start = lines.findIndex((line) => line.trim() === "Summary:");
	if (start === -1) return [];
	const out: string[] = [];
	for (let i = start + 1; i < lines.length; i++) {
		const line = lines[i];
		if (line.startsWith("Status:")) break;
		if (line.startsWith("- ")) out.push(line.slice(2).trim());
	}
	return out;
}

function inferState(statusRaw: string | null, paneRecent: string, target: string | null): StatusSession["state"] {
	const lower = statusRaw?.toLowerCase().trim();
	if (lower) {
		if (lower.startsWith("done")) return "done";
		if (lower.startsWith("partial")) return "partial";
		if (lower.startsWith("blocked")) return "blocked";
		if (lower.startsWith("failed")) return "failed";
	}
	if (paneRecent.includes("✅ Cloud run complete")) return "done";
	if (paneRecent.includes("/cloud failed:")) return "failed";
	if (target) return "running";
	return "unknown";
}

function pickLastInterestingLine(lines: string[]): string | null {
	const preferred = lines
		.filter((line) => line.trim().length > 0)
		.filter((line) => !/^\s*[↑↓]/.test(line))
		.filter((line) => !/gpt-[0-9]/.test(line));
	if (preferred.length > 0) return preferred[preferred.length - 1].trim();
	const any = lines.filter((line) => line.trim().length > 0);
	if (any.length > 0) return any[any.length - 1].trim();
	return null;
}

async function runSsh(
	host: string,
	user: string,
	knownHosts: string,
	identity: string | undefined,
	script: string,
	timeoutMs = 20_000,
): Promise<ExecResult> {
	const args = [
		"-F",
		"/dev/null",
		"-o",
		"BatchMode=yes",
		"-o",
		"ConnectTimeout=10",
		"-o",
		"StrictHostKeyChecking=yes",
		"-o",
		`UserKnownHostsFile=${knownHosts}`,
		"-o",
		"IdentitiesOnly=yes",
		"-l",
		user,
	];
	if (identity) args.push("-i", identity);
	args.push(host, "bash", "-s", "--");
	return await exec("ssh", args, { input: script, timeoutMs });
}

function toTable(output: StatusOutput): string {
	const lines: string[] = [];
	lines.push(`host: ${output.host}`);
	lines.push(`pattern: ${output.pattern}`);
	lines.push("");
	lines.push(`${"SESSION".padEnd(42)}  ${"STATE".padEnd(8)}  ${"STATUS".padEnd(18)}  BOOKMARK`);
	lines.push(`${"-".repeat(42)}  ${"-".repeat(8)}  ${"-".repeat(18)}  ${"-".repeat(16)}`);
	for (const s of output.sessions) {
		lines.push(`${s.session.padEnd(42)}  ${s.state.padEnd(8)}  ${(s.status ?? "").padEnd(18)}  ${s.bookmark ?? ""}`);
	}
	return lines.join("\n");
}

async function cloudStatus(options: {
	host?: string;
	user?: string;
	knownHosts?: string;
	identity?: string;
	lines?: string;
	pattern?: string;
	includePane?: boolean;
	table?: boolean;
	json?: boolean;
}): Promise<number> {
	const host = options.host ?? process.env.CLOUD_TMUX_STATUS_HOST ?? "46.225.16.43";
	const user = options.user ?? process.env.CLOUD_TMUX_STATUS_USER ?? "davidpdrsn";
	const knownHosts = options.knownHosts ?? process.env.CLOUD_TMUX_STATUS_KNOWN_HOSTS ?? `${process.env.HOME}/.ssh/known_hosts_hetzner`;
	let identity = options.identity ?? process.env.CLOUD_TMUX_STATUS_IDENTITY;
	const lines = Number(options.lines ?? process.env.CLOUD_TMUX_STATUS_LINES ?? "300");
	const pattern = options.pattern ?? process.env.CLOUD_TMUX_STATUS_PATTERN ?? "^pi-cloud-";
	const includePane = Boolean(options.includePane);
	const format = options.table ? "table" : "json";

	if (!Number.isInteger(lines) || lines < 1) {
		process.stderr.write("cloud-agent status: --lines must be a positive integer\n");
		return 1;
	}

	if (!identity) {
		const home = process.env.HOME ?? "";
		const candidateA = `${home}/.ssh/hetzner-to-hetzner-1`;
		const candidateB = `${home}/.ssh/hetzner`;
		try {
			await access(candidateA);
			identity = candidateA;
		} catch {
			try {
				await access(candidateB);
				identity = candidateB;
			} catch {
				identity = undefined;
			}
		}
	}

	try {
		await access(knownHosts);
	} catch {
		process.stderr.write(`cloud-agent status: known_hosts file not found: ${knownHosts}\n`);
		return 1;
	}

	if (identity) {
		try {
			await access(identity);
		} catch {
			process.stderr.write(`cloud-agent status: identity file not found: ${identity}\n`);
			return 1;
		}
	}

	let sessionRegex: RegExp;
	try {
		sessionRegex = new RegExp(pattern);
	} catch (error) {
		process.stderr.write(`cloud-agent status: invalid --pattern regex: ${pattern}\n`);
		if (error instanceof Error && error.message) process.stderr.write(`${error.message}\n`);
		return 1;
	}

	const listScript = [
		"set -euo pipefail",
		"if ! command -v tmux >/dev/null 2>&1; then",
		"  echo 'tmux not found on remote host' >&2",
		"  exit 2",
		"fi",
		"tmux list-sessions -F '#{session_name}' 2>/dev/null || true",
	].join("\n");
	const listed = await runSsh(host, user, knownHosts, identity, listScript, 20_000);
	if (listed.code !== 0) {
		process.stderr.write(listed.stderr || listed.stdout || "Failed to list tmux sessions\n");
		return 1;
	}

	const allSessions = listed.stdout
		.split("\n")
		.map((line) => line.trim())
		.filter(Boolean)
		.filter((name) => sessionRegex.test(name));

	const sessions: StatusSession[] = [];
	for (const session of allSessions) {
		const targetScript = [
			"set -euo pipefail",
			`tmux list-panes -t ${JSON.stringify(session)} -F '#{session_name}:#{window_index}.#{pane_index}' | head -n1`,
		].join("\n");
		const targetRes = await runSsh(host, user, knownHosts, identity, targetScript, 20_000);
		const target = targetRes.code === 0 ? targetRes.stdout.trim() || null : null;

		let pane = "";
		if (target) {
			const captureScript = ["set -euo pipefail", `tmux capture-pane -p -J -t ${JSON.stringify(target)} -S -${lines} || true`].join("\n");
			const cap = await runSsh(host, user, knownHosts, identity, captureScript, 30_000);
			pane = cap.stdout;
		}
		const paneLines = pane.split("\n");
		const paneRecentLines = paneLines.slice(-120);
		const paneRecent = paneRecentLines.join("\n");

		const statusRaw = pickLast(paneRecentLines, "Status:");
		const bookmark = pickLast(paneRecentLines, "Bookmark:");
		const workspace = pickLast(paneRecentLines, "Workspace:");
		const followUp = pickLast(paneRecentLines, "Follow-up:");
		const summary = parseSummary(paneRecentLines);
		const state = inferState(statusRaw, paneRecent, target);
		const lastLine = pickLastInterestingLine(paneRecentLines);

		const row: StatusSession = {
			session,
			target,
			state,
			status: statusRaw,
			bookmark,
			workspace,
			followUp,
			summary,
			lastLine,
		};
		if (includePane) row.pane = paneRecent;
		sessions.push(row);
	}

	const output: StatusOutput = {
		host,
		pattern,
		generatedAt: new Date().toISOString(),
		includePane,
		sessions,
		counts: {
			total: sessions.length,
			running: sessions.filter((s) => s.state === "running").length,
			done: sessions.filter((s) => s.state === "done").length,
			partial: sessions.filter((s) => s.state === "partial").length,
			blocked: sessions.filter((s) => s.state === "blocked").length,
			failed: sessions.filter((s) => s.state === "failed").length,
			unknown: sessions.filter((s) => s.state === "unknown").length,
		},
	};

	if (format === "table") process.stdout.write(`${toTable(output)}\n`);
	else process.stdout.write(`${JSON.stringify(output)}\n`);

	return 0;
}

const cli = cac("cloud-agent");
cli.help();
cli.version("0.1.0");

cli
	.command("run [...prompt]", "Start a cloud agent run")
	.option("--cwd <path>", "Working directory to treat as local cwd")
	.option("--session-file <path>", "Optional local Pi session file to sync")
	.option("--json", "Emit worker NDJSON events instead of human output")
	.action(async (prompt: string[], options: { cwd?: string; sessionFile?: string; json?: boolean }) => {
		const code = await runWorker(
			"run",
			{
				cwd: options.cwd ?? process.cwd(),
				sessionFile: options.sessionFile ?? null,
				cloudPrompt: prompt.join(" ").trim() || "continue",
				hasUI: false,
			},
			Boolean(options.json),
		);
		process.exitCode = code;
	});

cli
	.command("clean", "Clean cloud workspaces (interactive mode currently requires Pi UI adapter)")
	.option("--json", "Emit worker NDJSON events")
	.action(async (options: { json?: boolean }) => {
		const code = await runWorker(
			"clean",
			{
				cwd: process.cwd(),
				hasUI: false,
			},
			Boolean(options.json),
		);
		process.exitCode = code;
	});

cli
	.command("status", "Inspect remote cloud tmux sessions and summarize status")
	.option("--host <host>", "SSH host/IP to inspect")
	.option("--user <user>", "SSH user")
	.option("--identity <path>", "SSH private key path")
	.option("--known-hosts <path>", "known_hosts file path")
	.option("--lines <n>", "Lines to capture from each pane")
	.option("--pattern <regex>", "Session name regex filter")
	.option("--include-pane", "Include captured pane text in JSON")
	.option("--json", "Output JSON (default)")
	.option("--table", "Output a compact table")
	.action(async (options) => {
		const code = await cloudStatus(options as any);
		process.exitCode = code;
	});

cli.parse();
