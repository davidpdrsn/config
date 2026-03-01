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

interface SshConfig {
	host: string;
	user: string;
	knownHosts: string;
	identity?: string;
	pattern: string;
}

interface SessionCandidate {
	session: string;
	attached: boolean;
	createdEpoch: number | null;
	created: string | null;
	workingDirectory: string | null;
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

function sshBaseArgs(config: SshConfig): string[] {
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
		`UserKnownHostsFile=${config.knownHosts}`,
		"-o",
		"IdentitiesOnly=yes",
		"-l",
		config.user,
	];
	if (config.identity) args.push("-i", config.identity);
	return args;
}

async function runSsh(config: SshConfig, script: string, timeoutMs = 20_000): Promise<ExecResult> {
	const args = [...sshBaseArgs(config), config.host, "bash", "-s", "--"];
	return await exec("ssh", args, { input: script, timeoutMs });
}

async function runSshInteractive(config: SshConfig, commandArgs: string[]): Promise<number> {
	const args = [...sshBaseArgs(config), "-t", config.host, ...commandArgs];
	const child = spawn("ssh", args, { stdio: "inherit" });
	return await new Promise((resolve) => {
		child.on("close", (code) => resolve(code ?? 1));
		child.on("error", () => resolve(1));
	});
}

async function resolveSshConfig(
	options: {
		host?: string;
		user?: string;
		knownHosts?: string;
		identity?: string;
		pattern?: string;
	},
	context: "status" | "attach",
): Promise<SshConfig | null> {
	const host = options.host ?? process.env.CLOUD_TMUX_STATUS_HOST ?? "46.225.16.43";
	const user = options.user ?? process.env.CLOUD_TMUX_STATUS_USER ?? "davidpdrsn";
	const knownHosts = options.knownHosts ?? process.env.CLOUD_TMUX_STATUS_KNOWN_HOSTS ?? `${process.env.HOME}/.ssh/known_hosts_hetzner`;
	let identity = options.identity ?? process.env.CLOUD_TMUX_STATUS_IDENTITY;
	const pattern = options.pattern ?? process.env.CLOUD_TMUX_STATUS_PATTERN ?? "^pi-cloud-";

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
		process.stderr.write(`cloud-agent ${context}: known_hosts file not found: ${knownHosts}\n`);
		return null;
	}

	if (identity) {
		try {
			await access(identity);
		} catch {
			process.stderr.write(`cloud-agent ${context}: identity file not found: ${identity}\n`);
			return null;
		}
	}

	return { host, user, knownHosts, identity, pattern };
}

function parsePattern(pattern: string, context: "status" | "attach"): RegExp | null {
	try {
		return new RegExp(pattern);
	} catch (error) {
		process.stderr.write(`cloud-agent ${context}: invalid --pattern regex: ${pattern}\n`);
		if (error instanceof Error && error.message) process.stderr.write(`${error.message}\n`);
		return null;
	}
}

async function listRemoteSessions(config: SshConfig, sessionRegex: RegExp, context: "status" | "attach"): Promise<string[] | null> {
	const listScript = [
		"set -euo pipefail",
		"if ! command -v tmux >/dev/null 2>&1; then",
		"  echo 'tmux not found on remote host' >&2",
		"  exit 2",
		"fi",
		"tmux list-sessions -F '#{session_name}' 2>/dev/null || true",
	].join("\n");
	const listed = await runSsh(config, listScript, 20_000);
	if (listed.code !== 0) {
		const details = listed.stderr || listed.stdout || "Failed to list tmux sessions";
		process.stderr.write(`cloud-agent ${context}: ${details.trim()}\n`);
		return null;
	}

	return listed.stdout
		.split("\n")
		.map((line) => line.trim())
		.filter(Boolean)
		.filter((name) => sessionRegex.test(name));
}

async function listSessionCandidates(config: SshConfig, sessionRegex: RegExp, context: "status" | "attach"): Promise<SessionCandidate[] | null> {
	const listScript = [
		"set -euo pipefail",
		"if ! command -v tmux >/dev/null 2>&1; then",
		"  echo 'tmux not found on remote host' >&2",
		"  exit 2",
		"fi",
		"tmux list-sessions -F '#{session_name}\t#{session_attached}\t#{session_created}\t#{session_created_string}' 2>/dev/null || true",
	].join("\n");
	const listed = await runSsh(config, listScript, 20_000);
	if (listed.code !== 0) {
		const details = listed.stderr || listed.stdout || "Failed to list tmux sessions";
		process.stderr.write(`cloud-agent ${context}: ${details.trim()}\n`);
		return null;
	}

	const paneScript = [
		"set -euo pipefail",
		"if ! command -v tmux >/dev/null 2>&1; then",
		"  echo 'tmux not found on remote host' >&2",
		"  exit 2",
		"fi",
		"tmux list-panes -a -F '#{session_name}\t#{window_index}\t#{pane_index}\t#{pane_current_path}' 2>/dev/null || true",
	].join("\n");
	const listedPanes = await runSsh(config, paneScript, 20_000);
	if (listedPanes.code !== 0) {
		const details = listedPanes.stderr || listedPanes.stdout || "Failed to list tmux panes";
		process.stderr.write(`cloud-agent ${context}: ${details.trim()}\n`);
		return null;
	}

	const workingDirectoryBySession = new Map<string, { window: number; pane: number; cwd: string }>();
	for (const line of listedPanes.stdout.split("\n").map((row) => row.replace(/\r$/, "")).filter((row) => row.trim().length > 0)) {
		const [session, windowRaw, paneRaw, ...cwdTail] = line.split("\t");
		if (!session) continue;
		const windowIndex = Number(windowRaw);
		const paneIndex = Number(paneRaw);
		if (!Number.isInteger(windowIndex) || !Number.isInteger(paneIndex)) continue;
		const cwd = cwdTail.join("\t").trim();
		const existing = workingDirectoryBySession.get(session);
		if (!existing || windowIndex < existing.window || (windowIndex === existing.window && paneIndex < existing.pane)) {
			workingDirectoryBySession.set(session, { window: windowIndex, pane: paneIndex, cwd });
		}
	}

	const candidates = listed.stdout
		.split("\n")
		.map((line) => line.replace(/\r$/, ""))
		.filter((line) => line.trim().length > 0)
		.map((line) => line.split("\t"))
		.filter((parts) => parts.length >= 3)
		.map((parts) => {
			const [session, attachedRaw, createdEpochRaw, ...createdTail] = parts;
			const createdEpochNumber = Number(createdEpochRaw);
			return {
				session,
				attached: attachedRaw === "1",
				createdEpoch: Number.isFinite(createdEpochNumber) ? createdEpochNumber : null,
				created: createdTail.length > 0 ? createdTail.join("\t") : null,
				workingDirectory: workingDirectoryBySession.get(session)?.cwd || null,
			} satisfies SessionCandidate;
		})
		.filter((candidate) => sessionRegex.test(candidate.session))
		.sort((a, b) => {
			const aEpoch = a.createdEpoch ?? -1;
			const bEpoch = b.createdEpoch ?? -1;
			if (aEpoch !== bEpoch) return bEpoch - aEpoch;
			return a.session.localeCompare(b.session);
		});

	return candidates;
}

async function hasCommand(name: string): Promise<boolean> {
	const checked = await exec(name, ["--version"], { timeoutMs: 5_000 });
	return checked.code === 0;
}

async function pickSessionWithFzf(candidates: SessionCandidate[]): Promise<string | null> {
	const rows = candidates.map((candidate) => {
		const attachedLabel = candidate.attached ? "attached" : "detached";
		const createdLabel = candidate.created ?? "unknown";
		const cwdLabel = candidate.workingDirectory ?? "unknown cwd";
		const label = `${candidate.session}  [${attachedLabel}]  [${createdLabel}]  ${cwdLabel}`;
		return `${label}\t${candidate.session}`;
	});
	const child = spawn("fzf", ["--prompt", "cloud-agent attach> ", "--delimiter", "\t", "--with-nth", "1"], {
		stdio: ["pipe", "pipe", "inherit"],
	});

	child.stdin.write(rows.join("\n"));
	child.stdin.end();

	let stdout = "";
	child.stdout.on("data", (chunk: Buffer) => {
		stdout += chunk.toString("utf8");
	});

	return await new Promise((resolve) => {
		child.on("close", (code) => {
			if (code !== 0) {
				resolve(null);
				return;
			}
			const selected = stdout.trim();
			if (!selected) {
				resolve(null);
				return;
			}
			const [, session] = selected.split("\t");
			resolve(session ?? null);
		});
		child.on("error", () => resolve(null));
	});
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
	const lines = Number(options.lines ?? process.env.CLOUD_TMUX_STATUS_LINES ?? "300");
	const includePane = Boolean(options.includePane);
	const format = options.table ? "table" : "json";

	if (!Number.isInteger(lines) || lines < 1) {
		process.stderr.write("cloud-agent status: --lines must be a positive integer\n");
		return 1;
	}

	const config = await resolveSshConfig(options, "status");
	if (!config) return 1;

	const sessionRegex = parsePattern(config.pattern, "status");
	if (!sessionRegex) return 1;

	const allSessions = await listRemoteSessions(config, sessionRegex, "status");
	if (!allSessions) return 1;

	const sessions: StatusSession[] = [];
	for (const session of allSessions) {
		const targetScript = [
			"set -euo pipefail",
			`tmux list-panes -t ${JSON.stringify(session)} -F '#{session_name}:#{window_index}.#{pane_index}' | head -n1`,
		].join("\n");
		const targetRes = await runSsh(config, targetScript, 20_000);
		const target = targetRes.code === 0 ? targetRes.stdout.trim() || null : null;

		let pane = "";
		if (target) {
			const captureScript = ["set -euo pipefail", `tmux capture-pane -p -J -t ${JSON.stringify(target)} -S -${lines} || true`].join("\n");
			const cap = await runSsh(config, captureScript, 30_000);
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
		host: config.host,
		pattern: config.pattern,
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

async function cloudAttach(sessionArg: string | undefined, options: {
	host?: string;
	user?: string;
	knownHosts?: string;
	identity?: string;
	pattern?: string;
}): Promise<number> {
	const config = await resolveSshConfig(options, "attach");
	if (!config) return 1;

	const sessionRegex = parsePattern(config.pattern, "attach");
	if (!sessionRegex) return 1;

	const candidates = await listSessionCandidates(config, sessionRegex, "attach");
	if (!candidates) return 1;

	let session = sessionArg?.trim();
	if (session) {
		if (!candidates.some((candidate) => candidate.session === session)) {
			process.stderr.write(`cloud-agent attach: session not found: ${session}\n`);
			return 1;
		}
	} else if (candidates.length === 0) {
		process.stderr.write(`cloud-agent attach: no matching sessions found on ${config.host} (pattern: ${config.pattern})\n`);
		return 1;
	} else if (candidates.length === 1) {
		session = candidates[0].session;
	} else {
		if (!(await hasCommand("fzf"))) {
			process.stderr.write("cloud-agent attach: fzf is required but was not found in PATH\n");
			return 1;
		}
		const picked = await pickSessionWithFzf(candidates);
		if (!picked) {
			process.stderr.write("cloud-agent attach: no session selected\n");
			return 1;
		}
		session = picked;
	}

	if (!session) {
		process.stderr.write("cloud-agent attach: no session selected\n");
		return 1;
	}

	const code = await runSshInteractive(config, ["tmux", "attach", "-t", session]);
	if (code !== 0) {
		process.stderr.write(`cloud-agent attach: failed to attach to session '${session}'\n`);
	}
	return code;
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

cli
	.command("attach [session]", "Attach to a cloud tmux session on the remote host")
	.option("--host <host>", "SSH host/IP to inspect")
	.option("--user <user>", "SSH user")
	.option("--identity <path>", "SSH private key path")
	.option("--known-hosts <path>", "known_hosts file path")
	.option("--pattern <regex>", "Session name regex filter")
	.action(async (session: string | undefined, options) => {
		const code = await cloudAttach(session, options as any);
		process.exitCode = code;
	});

cli.parse();
