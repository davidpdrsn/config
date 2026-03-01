import path from "node:path";
import { tmpdir } from "node:os";
import { cac } from "cac";
import { collectAgentStatuses } from "./agent-status-lib";

interface StatusOutput {
	generatedAt: string;
	statusDir: string;
	staleAfterMs: number;
	filters: {
		cwd?: string;
		sessionId?: string;
		allUsers: boolean;
	};
	agents: Awaited<ReturnType<typeof collectAgentStatuses>>["agents"];
	counts: Awaited<ReturnType<typeof collectAgentStatuses>>["counts"];
	errors: string[];
}

function defaultStatusDir(): string {
	return process.env.PI_AGENT_STATUS_DIR || path.join(tmpdir(), "pi-agent-status");
}

function toSummary(output: StatusOutput): string {
	const c = output.counts;
	return `busy=${c.busy} idle=${c.idle} waiting_input=${c.waiting_input} offline=${c.offline} unknown=${c.unknown} total=${c.total}`;
}

function toTable(output: StatusOutput): string {
	const lines: string[] = [];
	lines.push(`statusDir: ${output.statusDir}`);
	lines.push(`counts: ${toSummary(output)}`);
	if (output.errors.length > 0) lines.push(`errors: ${output.errors.length}`);
	lines.push("");
	lines.push(`${"PID".padEnd(7)} ${"STATE".padEnd(14)} ${"SESSION".padEnd(16)} ${"UPDATED(ms)".padEnd(12)} ${"TOOL".padEnd(18)} CWD`);
	lines.push(`${"-".repeat(7)} ${"-".repeat(14)} ${"-".repeat(16)} ${"-".repeat(12)} ${"-".repeat(18)} ${"-".repeat(24)}`);
	for (const agent of output.agents) {
		lines.push(
			`${String(agent.pid).padEnd(7)} ${agent.observedState.padEnd(14)} ${agent.sessionId.slice(0, 16).padEnd(16)} ${String(agent.staleMs).padEnd(12)} ${(agent.currentTool ?? "").slice(0, 18).padEnd(18)} ${agent.cwd}`,
		);
	}
	if (output.agents.length === 0) lines.push("(no matching agents)");
	if (output.errors.length > 0) {
		lines.push("");
		lines.push("parse errors:");
		for (const error of output.errors) lines.push(`- ${error}`);
	}
	return lines.join("\n");
}

async function runStatus(options: {
	json?: boolean;
	table?: boolean;
	summary?: boolean;
	cwd?: string;
	session?: string;
	all?: boolean;
	statusDir?: string;
	staleMs?: string;
}): Promise<number> {
	const statusDir = options.statusDir || defaultStatusDir();
	const staleAfterMs = Number(options.staleMs ?? process.env.PI_AGENT_STATUS_STALE_MS ?? "30000");
	if (!Number.isInteger(staleAfterMs) || staleAfterMs < 1) {
		process.stderr.write("agent-status: --stale-ms must be a positive integer\n");
		return 1;
	}

	const data = await collectAgentStatuses({
		statusDir,
		staleAfterMs,
		cwd: options.cwd,
		sessionId: options.session,
		allUsers: Boolean(options.all),
	});

	const output: StatusOutput = {
		generatedAt: new Date().toISOString(),
		statusDir,
		staleAfterMs,
		filters: {
			cwd: options.cwd,
			sessionId: options.session,
			allUsers: Boolean(options.all),
		},
		agents: data.agents,
		counts: data.counts,
		errors: data.errors,
	};

	if (options.summary) process.stdout.write(`${toSummary(output)}\n`);
	else if (options.table) process.stdout.write(`${toTable(output)}\n`);
	else process.stdout.write(`${JSON.stringify(output)}\n`);

	return 0;
}

const cli = cac("agent-status");
cli.help();
cli.version("0.1.0");

cli
	.command("", "Inspect local Pi agent activity status")
	.option("--json", "Output JSON (default)")
	.option("--table", "Output a compact table")
	.option("--summary", "Output single-line counts")
	.option("--cwd <path>", "Filter by cwd prefix")
	.option("--session <id>", "Filter by session ID")
	.option("--all", "Include all users")
	.option("--status-dir <path>", "Status directory")
	.option("--stale-ms <n>", "Mark alive records older than this as unknown")
	.action(async (options) => {
		const code = await runStatus(options as any);
		process.exitCode = code;
	});

cli.parse();
