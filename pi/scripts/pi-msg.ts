import { access, readdir, readFile, realpath, rm, stat } from "node:fs/promises";
import net from "node:net";
import path from "node:path";
import { cac } from "cac";

interface MessageAgentRecord {
	version: 1;
	pid: number;
	user: string;
	host: string;
	cwd: string;
	socketPath: string;
	sessionId: string;
	sessionFile: string | null;
	startedAt: string;
	updatedAt: string;
}

interface ObservedRecord extends MessageAgentRecord {
	recordPath: string;
	staleMs: number;
}

type Delivery = "auto" | "steer" | "followUp";

const DEFAULT_STALE_MS = 30_000;

function getRuntimeDir(): string {
	const override = process.env.PI_MESSAGE_AGENT_DIR;
	if (override) return override;
	const uid = typeof process.getuid === "function" ? process.getuid() : process.env.USER || "unknown";
	return path.join("/tmp", `pi-message-agents-${uid}`);
}

function isObject(value: unknown): value is Record<string, unknown> {
	return typeof value === "object" && value !== null;
}

function parseRecord(value: unknown): MessageAgentRecord | undefined {
	if (!isObject(value)) return undefined;
	if (value.version !== 1) return undefined;
	if (typeof value.pid !== "number") return undefined;
	if (typeof value.user !== "string") return undefined;
	if (typeof value.host !== "string") return undefined;
	if (typeof value.cwd !== "string") return undefined;
	if (typeof value.socketPath !== "string") return undefined;
	if (typeof value.sessionId !== "string") return undefined;
	if (!(typeof value.sessionFile === "string" || value.sessionFile === null)) return undefined;
	if (typeof value.startedAt !== "string") return undefined;
	if (typeof value.updatedAt !== "string") return undefined;
	return value as unknown as MessageAgentRecord;
}

function isPidAlive(pid: number): boolean {
	if (!Number.isInteger(pid) || pid < 1) return false;
	try {
		process.kill(pid, 0);
		return true;
	} catch (error) {
		return (error as NodeJS.ErrnoException).code === "EPERM";
	}
}

async function canonicalizeCwd(cwd: string): Promise<string> {
	try {
		return await realpath(cwd);
	} catch {
		return path.resolve(cwd);
	}
}

async function socketExists(socketPath: string): Promise<boolean> {
	try {
		await access(socketPath);
		return true;
	} catch {
		return false;
	}
}

async function removeStale(record: MessageAgentRecord, recordPath: string): Promise<void> {
	if (isPidAlive(record.pid)) return;
	await rm(recordPath, { force: true }).catch(() => {});
	await rm(record.socketPath, { force: true }).catch(() => {});
}

async function collectAgents(staleMs: number): Promise<{ agents: ObservedRecord[]; errors: string[] }> {
	const runtimeDir = getRuntimeDir();
	const errors: string[] = [];
	const agents: ObservedRecord[] = [];
	const dirExists = await stat(runtimeDir)
		.then((info) => info.isDirectory())
		.catch(() => false);
	if (!dirExists) return { agents, errors };

	const now = Date.now();
	const entries = await readdir(runtimeDir, { withFileTypes: true });
	for (const entry of entries) {
		if (!entry.isFile() || !entry.name.endsWith(".json")) continue;
		const recordPath = path.join(runtimeDir, entry.name);
		let parsed: unknown;
		try {
			parsed = JSON.parse(await readFile(recordPath, "utf8"));
		} catch (error) {
			errors.push(`${recordPath}: failed to parse (${String(error)})`);
			continue;
		}

		const record = parseRecord(parsed);
		if (!record) {
			errors.push(`${recordPath}: invalid record`);
			continue;
		}

		await removeStale(record, recordPath);
		if (!isPidAlive(record.pid)) continue;
		if (!(await socketExists(record.socketPath))) continue;

		const updatedAt = Date.parse(record.updatedAt);
		const age = Number.isNaN(updatedAt) ? Number.MAX_SAFE_INTEGER : Math.max(0, now - updatedAt);
		if (age > staleMs) continue;

		agents.push({ ...record, recordPath, staleMs: age });
	}

	agents.sort((a, b) => a.pid - b.pid);
	return { agents, errors };
}

function validateDelivery(options: { steer?: boolean; followUp?: boolean }): Delivery {
	if (options.steer && options.followUp) throw new Error("use only one of --steer or --follow-up");
	if (options.steer) return "steer";
	if (options.followUp) return "followUp";
	return "auto";
}

function resolveTargetAndMessage(args: string[], cwdOption?: string): { cwd: string; message: string } {
	if (args.length === 0) throw new Error("missing message");
	if (cwdOption) return { cwd: cwdOption, message: args.join(" ") };

	if (args.length >= 2 && path.isAbsolute(args[0])) {
		return { cwd: args[0], message: args.slice(1).join(" ") };
	}

	return { cwd: process.env.PI_MSG_CALLER_CWD || process.cwd(), message: args.join(" ") };
}

async function sendToSocket(socketPath: string, payload: unknown): Promise<unknown> {
	return await new Promise((resolve, reject) => {
		const socket = net.createConnection(socketPath);
		let buffer = "";
		let settled = false;

		function settleError(error: Error): void {
			if (settled) return;
			settled = true;
			socket.destroy();
			reject(error);
		}

		socket.setEncoding("utf8");
		socket.on("connect", () => {
			socket.write(`${JSON.stringify(payload)}\n`);
		});
		socket.on("data", (chunk) => {
			buffer += chunk;
			const newline = buffer.indexOf("\n");
			if (newline === -1) return;
			const raw = buffer.slice(0, newline);
			try {
				const response = JSON.parse(raw) as unknown;
				settled = true;
				resolve(response);
				socket.end();
			} catch (error) {
				settleError(error instanceof Error ? error : new Error(String(error)));
			}
		});
		socket.on("error", settleError);
		socket.on("end", () => {
			if (!settled) settleError(new Error("agent closed connection without a response"));
		});
	});
}

function shortAgent(agent: ObservedRecord): string {
	return `pid=${agent.pid} session=${agent.sessionId} cwd=${agent.cwd} socket=${agent.socketPath}`;
}

async function run(args: string[], options: { cwd?: string; steer?: boolean; followUp?: boolean; session?: string; staleMs?: string; list?: boolean }): Promise<number> {
	const staleMs = Number(options.staleMs ?? process.env.PI_MESSAGE_AGENT_STALE_MS ?? DEFAULT_STALE_MS);
	if (!Number.isInteger(staleMs) || staleMs < 1) throw new Error("--stale-ms must be a positive integer");

	const { agents, errors } = await collectAgents(staleMs);
	if (options.list) {
		for (const agent of agents) process.stdout.write(`${shortAgent(agent)}\n`);
		for (const error of errors) process.stderr.write(`pi-msg: ${error}\n`);
		return 0;
	}

	const { cwd, message } = resolveTargetAndMessage(args, options.cwd);
	const canonicalCwd = await canonicalizeCwd(cwd);
	const delivery = validateDelivery(options);
	let matches = agents.filter((agent) => agent.cwd === canonicalCwd);
	if (options.session) matches = matches.filter((agent) => agent.sessionId.startsWith(options.session!));

	if (matches.length === 0) {
		process.stderr.write(`pi-msg: no running pi agent found for ${canonicalCwd}\n`);
		return 1;
	}

	if (matches.length > 1) {
		process.stderr.write(`pi-msg: multiple running pi agents found for ${canonicalCwd}\n`);
		for (const agent of matches) process.stderr.write(`  ${shortAgent(agent)}\n`);
		process.stderr.write("Use --session <id-prefix> to select one.\n");
		return 1;
	}

	const response = await sendToSocket(matches[0].socketPath, { message, deliverAs: delivery });
	if (!isObject(response) || response.ok !== true) {
		const error = isObject(response) && typeof response.error === "string" ? response.error : JSON.stringify(response);
		process.stderr.write(`pi-msg: target agent rejected message: ${error}\n`);
		return 1;
	}

	process.stdout.write(`sent to pid ${matches[0].pid}\n`);
	return 0;
}

const cli = cac("pi-msg");
cli.help();
cli.version("0.1.0");

cli
	.command("[...args]", "Send a message to a running Pi agent in a cwd")
	.option("--cwd <path>", "Target cwd (defaults to current directory)")
	.option("--steer", "Queue as steering if the agent is busy")
	.option("--follow-up", "Queue as a follow-up after the agent finishes")
	.option("--session <id-prefix>", "Select an agent by session ID prefix")
	.option("--stale-ms <n>", "Ignore records older than this")
	.option("--list", "List discoverable message targets")
	.action(async (args: string[], options) => {
		try {
			process.exitCode = await run(args, options as any);
		} catch (error) {
			process.stderr.write(`pi-msg: ${error instanceof Error ? error.message : String(error)}\n`);
			process.exitCode = 1;
		}
	});

cli.parse();
