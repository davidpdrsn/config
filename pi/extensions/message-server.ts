import { createServer, type Server, type Socket } from "node:net";
import { chmod, mkdir, realpath, rename, rm, writeFile } from "node:fs/promises";
import { existsSync } from "node:fs";
import path from "node:path";
import type { ExtensionAPI, ExtensionContext } from "@mariozechner/pi-coding-agent";

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

type Delivery = "auto" | "steer" | "followUp";

interface IncomingMessage {
	message?: unknown;
	deliverAs?: unknown;
}

const HEARTBEAT_MS = 5_000;

function nowIso(): string {
	return new Date().toISOString();
}

function getRuntimeDir(): string {
	const override = process.env.PI_MESSAGE_AGENT_DIR;
	if (override) return override;
	const uid = typeof process.getuid === "function" ? process.getuid() : process.env.USER || "unknown";
	return path.join("/tmp", `pi-message-agents-${uid}`);
}

async function canonicalizeCwd(cwd: string): Promise<string> {
	try {
		return await realpath(cwd);
	} catch {
		return path.resolve(cwd);
	}
}

async function writeAtomicJson(filePath: string, data: unknown): Promise<void> {
	const tmpPath = `${filePath}.tmp-${process.pid}-${Date.now()}-${Math.random().toString(16).slice(2)}`;
	await writeFile(tmpPath, `${JSON.stringify(data)}\n`, { encoding: "utf8", mode: 0o600 });
	await rename(tmpPath, filePath);
}

function writeJson(socket: Socket, value: unknown): void {
	socket.write(`${JSON.stringify(value)}\n`);
}

function parseIncoming(raw: string): IncomingMessage {
	const parsed = JSON.parse(raw) as unknown;
	if (typeof parsed !== "object" || parsed === null) throw new Error("request must be a JSON object");
	return parsed as IncomingMessage;
}

function validateDelivery(value: unknown): Delivery {
	if (value === undefined || value === "auto") return "auto";
	if (value === "steer" || value === "followUp") return value;
	throw new Error("deliverAs must be one of: auto, steer, followUp");
}

function sendUserMessage(pi: ExtensionAPI, ctx: ExtensionContext, message: string, delivery: Delivery): void {
	if (delivery === "followUp") {
		pi.sendUserMessage(message, { deliverAs: "followUp" });
		return;
	}

	if (delivery === "steer") {
		pi.sendUserMessage(message, { deliverAs: "steer" });
		return;
	}

	if (ctx.isIdle()) {
		pi.sendUserMessage(message);
		return;
	}

	pi.sendUserMessage(message, { deliverAs: "steer" });
}

export default function (pi: ExtensionAPI): void {
	let server: Server | undefined;
	let heartbeat: ReturnType<typeof setInterval> | undefined;
	let recordFile: string | undefined;
	let socketPath: string | undefined;
	let record: MessageAgentRecord | undefined;
	let currentCtx: ExtensionContext | undefined;

	async function publishRecord(): Promise<void> {
		if (!record || !recordFile) return;
		record.updatedAt = nowIso();
		await writeAtomicJson(recordFile, record);
	}

	async function stop(): Promise<void> {
		if (heartbeat) {
			clearInterval(heartbeat);
			heartbeat = undefined;
		}

		const oldServer = server;
		server = undefined;
		if (oldServer) {
			await new Promise<void>((resolve) => oldServer.close(() => resolve()));
		}

		if (recordFile) await rm(recordFile, { force: true });
		if (socketPath) await rm(socketPath, { force: true });
		recordFile = undefined;
		socketPath = undefined;
		record = undefined;
		currentCtx = undefined;
	}

	async function start(ctx: ExtensionContext): Promise<void> {
		await stop();

		currentCtx = ctx;
		const runtimeDir = getRuntimeDir();
		await mkdir(runtimeDir, { recursive: true, mode: 0o700 });
		await chmod(runtimeDir, 0o700).catch(() => {});

		socketPath = path.join(runtimeDir, `${process.pid}.sock`);
		recordFile = path.join(runtimeDir, `${process.pid}.json`);
		await rm(socketPath, { force: true });

		server = createServer((socket) => {
			let buffer = "";
			socket.setEncoding("utf8");
			socket.on("data", (chunk) => {
				buffer += chunk;
				const newline = buffer.indexOf("\n");
				if (newline === -1) return;

				const raw = buffer.slice(0, newline).trim();
				buffer = buffer.slice(newline + 1);

				try {
					const request = parseIncoming(raw);
					if (typeof request.message !== "string" || request.message.trim().length === 0) {
						throw new Error("message must be a non-empty string");
					}
					const delivery = validateDelivery(request.deliverAs);
					const latestCtx = currentCtx;
					if (!latestCtx) throw new Error("agent context is not ready");

					sendUserMessage(pi, latestCtx, request.message, delivery);
					writeJson(socket, { ok: true, delivery: delivery === "auto" && latestCtx.isIdle() ? "immediate" : delivery });
				} catch (error) {
					writeJson(socket, { ok: false, error: error instanceof Error ? error.message : String(error) });
				} finally {
					socket.end();
				}
			});
		});

		await new Promise<void>((resolve, reject) => {
			const onError = (error: Error) => {
				server?.off("listening", onListening);
				reject(error);
			};
			const onListening = () => {
				server?.off("error", onError);
				resolve();
			};
			server?.once("error", onError);
			server?.once("listening", onListening);
			server?.listen(socketPath);
		});
		if (existsSync(socketPath)) await chmod(socketPath, 0o600).catch(() => {});

		const startedAt = nowIso();
		record = {
			version: 1,
			pid: process.pid,
			user: process.env.USER || process.env.LOGNAME || "unknown",
			host: process.env.HOSTNAME || process.env.HOST || "unknown",
			cwd: await canonicalizeCwd(ctx.cwd),
			socketPath,
			sessionId: ctx.sessionManager.getSessionId(),
			sessionFile: ctx.sessionManager.getSessionFile() ?? null,
			startedAt,
			updatedAt: startedAt,
		};
		await publishRecord();

		heartbeat = setInterval(() => {
			void publishRecord();
		}, HEARTBEAT_MS);
		heartbeat.unref?.();

		if (ctx.hasUI) ctx.ui.notify(`pi-msg listening for ${record.cwd}`, "info");
	}

	pi.on("session_start", async (_event, ctx) => {
		await start(ctx);
	});

	pi.on("session_shutdown", async () => {
		await stop();
	});
}
