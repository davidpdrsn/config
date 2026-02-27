import { access, mkdir, mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { Key, matchesKey, truncateToWidth } from "@mariozechner/pi-tui";

const HOST = "hetzner-1";
const REMOTE_NAME = "hetzner-1";

interface ExecResult {
	code: number | null;
	stdout: string;
	stderr: string;
}

interface SessionHeader {
	type: string;
	version?: number;
	id?: string;
	parentSession?: string;
}

interface CloudWorkspaceInfo {
	path: string;
	changeId: string;
	sessionShort: string;
	mtimeEpoch: number;
	active: boolean;
}

interface CloudCleanupSnapshot {
	workspaces: CloudWorkspaceInfo[];
	bareRepoExists: boolean;
	remoteWorkspaceBase: string;
	remoteBareRepo: string;
}

function sh(value: string): string {
	return `'${value.replaceAll("'", `'"'"'`)}'`;
}

function normalizeRemotePath(p: string): string {
	return p.replaceAll(path.sep, "/");
}

function relativeSessionPath(sessionFile: string): string {
	const normalized = normalizeRemotePath(sessionFile);
	const marker = "/sessions/";
	const index = normalized.lastIndexOf(marker);
	if (index === -1) {
		throw new Error(`Session path does not contain '/sessions/': ${sessionFile}`);
	}
	return normalized.slice(index + marker.length);
}

function shortId(value: string, length = 8): string {
	return value.slice(0, length);
}

function asRecord(value: unknown): Record<string, unknown> | null {
	if (!value || typeof value !== "object" || Array.isArray(value)) return null;
	return value as Record<string, unknown>;
}

function parseJsonSafe(value: string): unknown {
	try {
		return JSON.parse(value);
	} catch {
		return null;
	}
}

function resolveParentSessionPath(sessionFile: string, parentSession: string): string {
	if (path.isAbsolute(parentSession)) return parentSession;
	return path.resolve(path.dirname(sessionFile), parentSession);
}

function isPathInsideRepo(candidatePath: string, repoRoot: string): boolean {
	const repoRootAbs = path.resolve(repoRoot);
	const candidateAbs = path.resolve(candidatePath);
	const rel = path.relative(repoRootAbs, candidateAbs);
	return rel === "" || (!rel.startsWith("..") && !path.isAbsolute(rel));
}

function shouldSanitizeReadPath(readPath: string, repoRoot: string): boolean {
	if (!path.isAbsolute(readPath)) return false;
	return !isPathInsideRepo(readPath, repoRoot);
}

async function fileExists(filePath: string): Promise<boolean> {
	try {
		await access(filePath);
		return true;
	} catch {
		return false;
	}
}

async function collectSessionFiles(sessionFile: string): Promise<string[]> {
	const files: string[] = [];
	const seen = new Set<string>();
	let current: string | null = sessionFile;

	while (current && !seen.has(current)) {
		seen.add(current);
		files.push(current);
		const header = await readSessionHeader(current);
		if (!header.parentSession) break;
		current = resolveParentSessionPath(current, header.parentSession);
	}

	return files;
}

async function rewriteSessionForCloud(
	sessionFile: string,
	tempDir: string,
	repoRoot: string,
	placeholderPath: string,
): Promise<string> {
	const original = await readFile(sessionFile, "utf8");
	const rewrittenLines = original.split("\n").map((line) => {
		const trimmed = line.trim();
		if (!trimmed) return line;

		const parsed = parseJsonSafe(line);
		const entry = asRecord(parsed);
		if (!entry) return line;

		if (entry.type !== "message") return line;
		const message = asRecord(entry.message);
		if (!message || message.role !== "assistant") return line;

		const content = message.content;
		if (!Array.isArray(content)) return line;

		let changed = false;
		for (const itemValue of content) {
			const item = asRecord(itemValue);
			if (!item) continue;
			if (item.type !== "toolCall") continue;
			if (item.name !== "read") continue;

			const argumentsRecord = asRecord(item.arguments);
			if (argumentsRecord && typeof argumentsRecord.path === "string") {
				if (shouldSanitizeReadPath(argumentsRecord.path, repoRoot)) {
					argumentsRecord.path = placeholderPath;
					changed = true;
				}
			}

			if (typeof item.partialJson === "string") {
				const partial = parseJsonSafe(item.partialJson);
				const partialRecord = asRecord(partial);
				if (partialRecord && typeof partialRecord.path === "string") {
					if (shouldSanitizeReadPath(partialRecord.path, repoRoot)) {
						partialRecord.path = placeholderPath;
						item.partialJson = JSON.stringify(partialRecord);
						changed = true;
					}
				}
			}
		}

		return changed ? JSON.stringify(entry) : line;
	});

	const relativePath = relativeSessionPath(sessionFile);
	const rewrittenPath = path.join(tempDir, relativePath);
	await mkdir(path.dirname(rewrittenPath), { recursive: true });
	await writeFile(rewrittenPath, rewrittenLines.join("\n"), "utf8");
	return rewrittenPath;
}

async function execOrThrow(
	pi: ExtensionAPI,
	command: string,
	args: string[],
	step: string,
	timeoutMs = 30_000,
): Promise<ExecResult> {
	const result = (await pi.exec(command, args, { timeout: timeoutMs })) as ExecResult;
	if (result.code !== 0) {
		throw new Error(
			`${step} failed (exit ${result.code ?? "unknown"})\n` +
				`Command: ${command} ${args.join(" ")}\n` +
				(result.stderr || result.stdout || "(no output)"),
		);
	}
	return result;
}

async function runSsh(pi: ExtensionAPI, script: string, step: string, timeoutMs = 60_000): Promise<ExecResult> {
	return execOrThrow(pi, "ssh", [HOST, `bash -lc ${sh(script)}`], step, timeoutMs);
}

async function copyToClipboardIfSupported(pi: ExtensionAPI, value: string): Promise<boolean> {
	if (process.platform !== "darwin") return false;

	const hasPbcopy = (await pi.exec("bash", ["-lc", "command -v pbcopy >/dev/null 2>&1"], {
		timeout: 3_000,
	})) as ExecResult;
	if (hasPbcopy.code !== 0) return false;

	const copy = (await pi.exec("bash", ["-lc", `printf %s ${sh(value)} | pbcopy`], {
		timeout: 3_000,
	})) as ExecResult;
	return copy.code === 0;
}

async function readSessionHeader(sessionFile: string): Promise<SessionHeader> {
	const content = await readFile(sessionFile, "utf8");
	const firstLine = content.split("\n")[0]?.trim();
	if (!firstLine) throw new Error(`Session file is empty: ${sessionFile}`);

	const parsed = JSON.parse(firstLine) as SessionHeader;
	if (parsed.type !== "session") {
		throw new Error(`Invalid session header in ${sessionFile}`);
	}
	return parsed;
}

function formatAge(seconds: number): string {
	if (seconds < 60) return `${seconds}s`;
	if (seconds < 3600) return `${Math.floor(seconds / 60)}m`;
	if (seconds < 86_400) return `${Math.floor(seconds / 3600)}h`;
	return `${Math.floor(seconds / 86_400)}d`;
}

// Read cleanup-relevant state directly from the server so cleanup works
// even if local cloud bookmarks/remotes were modified manually.
async function scanCloudCleanupState(
	pi: ExtensionAPI,
	repoName: string,
	remoteHome: string,
): Promise<CloudCleanupSnapshot> {
	const remoteWorkspaceBase = `${remoteHome}/cloud-workspaces/${repoName}`;
	const remoteBareRepo = `${remoteHome}/.cloud-remotes/${repoName}.git`;
	const script = [
		"set -euo pipefail",
		`workspace_base=${sh(remoteWorkspaceBase)}`,
		`bare_repo=${sh(remoteBareRepo)}`,
		`repo_name=${sh(repoName)}`,
		"if [ -d \"$workspace_base\" ]; then",
		"  find \"$workspace_base\" -mindepth 2 -maxdepth 2 -type d -print0 | while IFS= read -r -d '' ws; do",
		"    change_id=$(basename \"$(dirname \"$ws\")\")",
		"    session_short=$(basename \"$ws\")",
		"    mtime=$(stat -c %Y \"$ws\")",
		"    if tmux has-session -t \"pi-cloud-${repo_name}-${change_id}-${session_short}\" 2>/dev/null; then active=1; else active=0; fi",
		"    printf 'WS\\t%s\\t%s\\t%s\\t%s\\t%s\\n' \"$ws\" \"$change_id\" \"$session_short\" \"$mtime\" \"$active\"",
		"  done",
		"fi",
		"if [ -d \"$bare_repo\" ]; then echo 'BARE\t1'; else echo 'BARE\t0'; fi",
	].join("\n");

	const result = await runSsh(pi, script, "Scanning remote cloud state", 60_000);
	const workspaces: CloudWorkspaceInfo[] = [];
	let bareRepoExists = false;
	for (const line of result.stdout.split("\n").map((l) => l.trim()).filter(Boolean)) {
		const parts = line.split("\t");
		if (parts[0] === "WS" && parts.length >= 6) {
			workspaces.push({
				path: parts[1],
				changeId: parts[2],
				sessionShort: parts[3],
				mtimeEpoch: Number(parts[4]) || 0,
				active: parts[5] === "1",
			});
		}
		if (parts[0] === "BARE") {
			bareRepoExists = parts[1] === "1";
		}
	}

	workspaces.sort((a, b) => a.path.localeCompare(b.path));
	return { workspaces, bareRepoExists, remoteWorkspaceBase, remoteBareRepo };
}

async function pickMany(ctx: any, title: string, options: string[]): Promise<number[] | undefined> {
	if (options.length === 0) return [];
	return ctx.ui.custom<number[] | undefined>((tui: any, theme: any, _kb: any, done: (value: number[] | undefined) => void) => {
		let selectedIndex = 0;
		const selected = new Set<number>();
		let cachedLines: string[] | undefined;

		function refresh() {
			cachedLines = undefined;
			tui.requestRender();
		}

		return {
			handleInput(data: string) {
				if (matchesKey(data, Key.up) || matchesKey(data, Key.ctrl("p")) || data === "k") {
					selectedIndex = Math.max(0, selectedIndex - 1);
					refresh();
					return;
				}
				if (matchesKey(data, Key.down) || matchesKey(data, Key.ctrl("n")) || data === "j") {
					selectedIndex = Math.min(options.length - 1, selectedIndex + 1);
					refresh();
					return;
				}
				if (matchesKey(data, Key.space)) {
					if (selected.has(selectedIndex)) selected.delete(selectedIndex);
					else selected.add(selectedIndex);
					refresh();
					return;
				}
				if (matchesKey(data, Key.enter)) {
					done(Array.from(selected).sort((a, b) => a - b));
					return;
				}
				if (matchesKey(data, Key.escape)) {
					done(undefined);
				}
			},
			render(width: number) {
				if (cachedLines) return cachedLines;
				const lines: string[] = [];
				const add = (line: string) => lines.push(truncateToWidth(line, width));
				add(theme.fg("accent", title));
				lines.push("");
				for (let i = 0; i < options.length; i++) {
					const focused = i === selectedIndex;
					const mark = selected.has(i) ? "[x]" : "[ ]";
					const prefix = focused ? theme.fg("accent", "> ") : "  ";
					const text = `${mark} ${options[i]}`;
					add(prefix + (focused ? theme.fg("accent", text) : text));
				}
				lines.push("");
				add(theme.fg("dim", "↑/↓, j/k navigate • Space toggle • Enter confirm • Esc cancel"));
				cachedLines = lines;
				return lines;
			},
			invalidate() {
				cachedLines = undefined;
			},
		};
	});
}

async function pickOne(ctx: any, title: string, options: string[]): Promise<number | undefined> {
	if (options.length === 0) return undefined;
	return ctx.ui.custom<number | undefined>((tui: any, theme: any, _kb: any, done: (value: number | undefined) => void) => {
		let selectedIndex = 0;
		let cachedLines: string[] | undefined;

		function refresh() {
			cachedLines = undefined;
			tui.requestRender();
		}

		return {
			handleInput(data: string) {
				if (matchesKey(data, Key.up) || matchesKey(data, Key.ctrl("p")) || data === "k") {
					selectedIndex = Math.max(0, selectedIndex - 1);
					refresh();
					return;
				}
				if (matchesKey(data, Key.down) || matchesKey(data, Key.ctrl("n")) || data === "j") {
					selectedIndex = Math.min(options.length - 1, selectedIndex + 1);
					refresh();
					return;
				}
				if (matchesKey(data, Key.enter)) {
					done(selectedIndex);
					return;
				}
				if (matchesKey(data, Key.escape)) {
					done(undefined);
				}
			},
			render(width: number) {
				if (cachedLines) return cachedLines;
				const lines: string[] = [];
				const add = (line: string) => lines.push(truncateToWidth(line, width));
				add(theme.fg("accent", title));
				lines.push("");
				for (let i = 0; i < options.length; i++) {
					const focused = i === selectedIndex;
					const prefix = focused ? theme.fg("accent", "> ") : "  ";
					add(prefix + (focused ? theme.fg("accent", options[i]) : options[i]));
				}
				lines.push("");
				add(theme.fg("dim", "↑/↓, j/k navigate • Enter confirm • Esc cancel"));
				cachedLines = lines;
				return lines;
			},
			invalidate() {
				cachedLines = undefined;
			},
		};
	});
}

// Confirmation UI where only the final actions are selectable.
// Summary lines are rendered as plain text for clarity.
async function confirmCloudCleanup(ctx: any, title: string, summaryLines: string[]): Promise<boolean | undefined> {
	return ctx.ui.custom<boolean | undefined>((tui: any, theme: any, _kb: any, done: (value: boolean | undefined) => void) => {
		const actions = ["Proceed with deletion", "Cancel"];
		let selectedIndex = 0;
		let cachedLines: string[] | undefined;

		function refresh() {
			cachedLines = undefined;
			tui.requestRender();
		}

		return {
			handleInput(data: string) {
				if (matchesKey(data, Key.up) || matchesKey(data, Key.ctrl("p")) || data === "k") {
					selectedIndex = Math.max(0, selectedIndex - 1);
					refresh();
					return;
				}
				if (matchesKey(data, Key.down) || matchesKey(data, Key.ctrl("n")) || data === "j") {
					selectedIndex = Math.min(actions.length - 1, selectedIndex + 1);
					refresh();
					return;
				}
				if (matchesKey(data, Key.enter)) {
					done(selectedIndex === 0);
					return;
				}
				if (matchesKey(data, Key.escape)) {
					done(undefined);
				}
			},
			render(width: number) {
				if (cachedLines) return cachedLines;
				const lines: string[] = [];
				const add = (line: string) => lines.push(truncateToWidth(line, width));
				add(theme.fg("accent", title));
				lines.push("");
				for (const line of summaryLines) add(line);
				lines.push("");
				for (let i = 0; i < actions.length; i++) {
					const focused = i === selectedIndex;
					const prefix = focused ? theme.fg("accent", "> ") : "  ";
					add(prefix + (focused ? theme.fg("accent", actions[i]) : actions[i]));
				}
				lines.push("");
				add(theme.fg("dim", "↑/↓, j/k navigate • Enter confirm • Esc cancel"));
				cachedLines = lines;
				return lines;
			},
			invalidate() {
				cachedLines = undefined;
			},
		};
	});
}

export default function (pi: ExtensionAPI): void {
	pi.registerCommand("cloud", {
		description: "Move this session to hetzner-1 and run it in remote tmux",
		handler: async (args, ctx) => {
			let tempDir: string | undefined;
			const cloudPrompt = args.trim() || "continue";
			const setCloudProgress = (line: string) => {
				ctx.ui.setWidget("cloud-progress", [line], { placement: "belowEditor" });
			};
			const clearCloudProgress = () => {
				ctx.ui.setWidget("cloud-progress", undefined);
			};
			const runWithProgress = async <T>(label: string, run: () => Promise<T>): Promise<T> => {
				const startedAt = Date.now();
				const render = () => {
					const elapsedSeconds = Math.floor((Date.now() - startedAt) / 1000);
					setCloudProgress(`☁️ ${label}… ${elapsedSeconds}s`);
				};
				render();
				const timer = setInterval(render, 2_000);
				try {
					const result = await run();
					clearInterval(timer);
					setCloudProgress(`✅ ${label} done`);
					return result;
				} catch (error) {
					clearInterval(timer);
					setCloudProgress(`❌ ${label} failed`);
					throw error;
				}
			};
			try {
				const sessionFile = ctx.sessionManager.getSessionFile();
				if (!sessionFile) {
					ctx.ui.notify("/cloud requires a persisted session file.", "error");
					return;
				}

				ctx.ui.notify("Preparing cloud handoff...", "info");

				const jjRootResult = await execOrThrow(
					pi,
					"jj",
					["root"],
					"Detecting jj repo",
					5_000,
				);
				const repoRoot = jjRootResult.stdout.trim();

				await runWithProgress("Creating dedicated cloud build change", async () =>
					execOrThrow(
						pi,
						"jj",
						["-R", repoRoot, "new", "-r", "@"],
						"Creating dedicated cloud build change",
						10_000,
					),
				);

				const repoName = path.basename(repoRoot);
				const changeIdResult = await execOrThrow(
					pi,
					"jj",
					["-R", repoRoot, "log", "-r", "@", "--no-graph", "-T", "change_id.short(8) ++ \"\\n\""],
					"Reading current jj change id",
					5_000,
				);
				const changeId = changeIdResult.stdout.trim();
				if (!changeId) throw new Error("Could not determine current jj change id");

				const hasLocalSessionFile = await fileExists(sessionFile);
				if (!hasLocalSessionFile) {
					ctx.ui.notify(
						"No local session transcript yet; /cloud will start a fresh session on the remote machine.",
						"info",
					);
				}
				const sessionHeader = hasLocalSessionFile ? await readSessionHeader(sessionFile) : undefined;
				const sessionShort = shortId(sessionHeader?.id ?? path.basename(sessionFile, ".jsonl"));
				const bookmarkName = `cloud/${changeId}`;

				const remoteHome = "/home/davidpdrsn";

				const remoteBareRepo = `${remoteHome}/.cloud-remotes/${repoName}.git`;
				const remoteWorkspace = `${remoteHome}/cloud-workspaces/${repoName}/${changeId}/${sessionShort}`;
				const remotePlaceholderPath = `${remoteHome}/.pi/agent/cloud-placeholders/missing-local-file.txt`;

				await runWithProgress("Bootstrapping remote repository", async () =>
					runSsh(
						pi,
						[
							"set -euo pipefail",
							`if [ -e ${sh(remoteWorkspace)} ]; then`,
							`  echo ${sh(`Workspace already exists: ${remoteWorkspace}`)}`,
							"  exit 22",
							"fi",
							`mkdir -p ${sh(`${remoteHome}/.cloud-remotes`)}`,
							`if [ ! -d ${sh(remoteBareRepo)} ]; then git init --bare ${sh(remoteBareRepo)}; fi`,
							`mkdir -p ${sh(path.posix.dirname(remotePlaceholderPath))}`,
							`echo ${sh("This path was local-only and removed by /cloud transfer.")} > ${sh(remotePlaceholderPath)}`,
						].join("\n"),
						"Bootstrapping remote bare repository",
					),
				);

				const remoteUrl = `${HOST}:${remoteBareRepo}`;
				const remotesResult = await execOrThrow(
					pi,
					"jj",
					["-R", repoRoot, "git", "remote", "list"],
					"Listing jj git remotes",
					5_000,
				);
				const hasRemote = remotesResult.stdout
					.split("\n")
					.map((line) => line.trim())
					.filter(Boolean)
					.some((line) => line.split(/\s+/, 1)[0] === REMOTE_NAME);

				if (hasRemote) {
					await execOrThrow(
						pi,
						"jj",
						["-R", repoRoot, "git", "remote", "set-url", REMOTE_NAME, remoteUrl],
						"Updating jj git remote URL",
						5_000,
					);
				} else {
					await execOrThrow(
						pi,
						"jj",
						["-R", repoRoot, "git", "remote", "add", REMOTE_NAME, remoteUrl],
						"Adding jj git remote",
						5_000,
					);
				}

				await runWithProgress("Pushing cloud bookmark (large repos may take a while)", async () =>
					execOrThrow(
						pi,
						"jj",
						[
							"-R",
							repoRoot,
							"git",
							"push",
							"--remote",
							REMOTE_NAME,
							"--allow-private",
							"--allow-empty-description",
							"--named",
							`${bookmarkName}=@`,
						],
						"Pushing cloud bookmark to remote",
						180_000,
					),
				);

				await runWithProgress("Creating local sibling working change", async () =>
					execOrThrow(
						pi,
						"jj",
						["-R", repoRoot, "new", "-r", "parents(@)"],
						"Creating local sibling working change",
						10_000,
					),
				);

				await runWithProgress("Creating cloud workspace", async () =>
					runSsh(
						pi,
						[
							"set -euo pipefail",
							`mkdir -p ${sh(path.posix.dirname(remoteWorkspace))}`,
							`jj git clone ${sh(remoteBareRepo)} ${sh(remoteWorkspace)} -b ${sh(bookmarkName)}`,
							`cd ${sh(remoteWorkspace)}`,
							// Ensure the cloud bookmark is tracked in this clone so `jj git push --bookmark` works first try.
							`jj bookmark track ${sh(bookmarkName)} --remote origin`,
						].join("\n"),
						"Creating cloud workspace",
						180_000,
					),
				);

				const envSyncCandidatesByRepo: Record<string, string[]> = {
					"web-main": [
						"apps/kelvin/.env",
						"libraries/api/.env",
						"libraries/energy10-integration/.env",
					],
					calor: [".env.docker", "env.dboverride"],
				};
				const envSyncCandidates = [
					...(envSyncCandidatesByRepo[repoName] ?? []),
					".env",
				];
				const seenEnvCandidates = new Set<string>();
				const envFilesToSync: Array<{ localPath: string; relativePath: string; remotePath: string }> = [];
				const missingEnvFiles: string[] = [];

				for (const candidate of envSyncCandidates) {
					if (seenEnvCandidates.has(candidate)) continue;
					seenEnvCandidates.add(candidate);
					if (candidate.toLowerCase().includes("example")) continue;

					const localPath = path.resolve(repoRoot, candidate);
					if (!isPathInsideRepo(localPath, repoRoot)) continue;

					try {
						await access(localPath);
						envFilesToSync.push({
							localPath,
							relativePath: candidate,
							remotePath: `${remoteWorkspace}/${normalizeRemotePath(candidate)}`,
						});
					} catch {
						missingEnvFiles.push(candidate);
					}
				}

				if (envFilesToSync.length > 0) {
					await runWithProgress(`Syncing env files (${envFilesToSync.length})`, async () => {
						for (const envFile of envFilesToSync) {
							await runSsh(
								pi,
								`mkdir -p ${sh(path.posix.dirname(envFile.remotePath))}`,
								`Preparing remote directory for ${envFile.relativePath}`,
								30_000,
							);
							await execOrThrow(
								pi,
								"rsync",
								["-az", envFile.localPath, `${HOST}:${envFile.remotePath}`],
								`Syncing ${envFile.relativePath} to cloud workspace`,
								180_000,
							);
						}
					});
					ctx.ui.notify(
						`Synced env files: ${envFilesToSync.map((file) => file.relativePath).join(", ")}`,
						"info",
					);
				} else {
					ctx.ui.notify("No env files found for sync; skipping env sync.", "info");
				}

				if (missingEnvFiles.length > 0) {
					ctx.ui.notify(`Env files not found (skipped): ${missingEnvFiles.join(", ")}`, "info");
				}

				const sessionRelPath = relativeSessionPath(sessionFile);
				const remoteSessionPath = `${remoteHome}/.pi/agent/sessions/${sessionRelPath}`;
				await runSsh(
					pi,
					`mkdir -p ${sh(path.posix.dirname(remoteSessionPath))}`,
					"Creating remote session directory",
					30_000,
				);

				if (hasLocalSessionFile) {
					const sessionFiles = await collectSessionFiles(sessionFile);
					tempDir = await mkdtemp(path.join(tmpdir(), "pi-cloud-sessions-"));
					const rewrittenSessionFiles = new Map<string, string>();
					for (const localSessionFile of sessionFiles) {
						const rewritten = await rewriteSessionForCloud(
							localSessionFile,
							tempDir,
							repoRoot,
							remotePlaceholderPath,
						);
						rewrittenSessionFiles.set(localSessionFile, rewritten);
					}

					for (const [index, localSessionFile] of sessionFiles.entries()) {
						const rewrittenSessionFile = rewrittenSessionFiles.get(localSessionFile) ?? localSessionFile;
						const localSessionRelPath = relativeSessionPath(localSessionFile);
						const remoteLocalSessionPath = `${remoteHome}/.pi/agent/sessions/${localSessionRelPath}`;
						await runSsh(
							pi,
							`mkdir -p ${sh(path.posix.dirname(remoteLocalSessionPath))}`,
							`Creating remote session directory for ${path.basename(localSessionFile)}`,
							30_000,
						);
						await runWithProgress(
							`Copying session file ${index + 1}/${sessionFiles.length}: ${path.basename(localSessionFile)}`,
							async () =>
								execOrThrow(
									pi,
									"scp",
									[rewrittenSessionFile, `${HOST}:${remoteLocalSessionPath}`],
									`Copying session file ${path.basename(localSessionFile)}`,
									180_000,
								),
						);
					}
				}
				const cwdRel = path.relative(repoRoot, ctx.cwd);
				const remoteCwd =
					cwdRel && cwdRel !== "."
						? path.posix.join(remoteWorkspace, normalizeRemotePath(cwdRel))
						: remoteWorkspace;
				const remoteAgentInstructions = [
					"This session was moved from a local machine to a cloud workspace.",
					`Local repo root was: ${repoRoot}`,
					`Local working directory was: ${ctx.cwd}`,
					`Remote repo root is now: ${remoteWorkspace}`,
					`Remote working directory is now: ${remoteCwd}`,
					"Do not use old absolute local paths. Use remote paths from this workspace.",
					"This repo may rely on a nix dev environment; if commands/tools are missing, run them via `nix develop -c <command>`.",
					"Cloud workers may lack untracked/generated files. If missing files break commands, infer what is needed and regenerate using repo build scripts/docs (Justfile/Makefile/package scripts).",
					"When finishing work, before your final response, you must run these commands:",
					`1) jj commit -m \"<good, specific commit message>\"`,
					`2) jj bookmark set \"${bookmarkName}\" -r @-`,
					`3) jj git push --remote origin --bookmark \"${bookmarkName}\" --allow-private --allow-empty-description`,
					"4) Send a completion notification using openclaw-msg in this exact format (edit placeholders, keep structure):",
					"   cat <<'EOF' | openclaw-msg",
					"   Relay this message verbatim, with no changes:",
					"",
					"   ✅ Cloud run complete",
					"",
					"   Summary:",
					"   - <short bullet about what you changed>",
					"   - <short bullet about key result>",
					"   - <short bullet about anything important to know>",
					"",
					"   Status: <done|partial|blocked>",
					`   Bookmark: ${bookmarkName}`,
					`   Workspace: ${remoteWorkspace}`,
					"   Follow-up: <what the user should do next, if anything>",
					"   EOF",
					`5) tmux kill-session -t "$(tmux display-message -p '#S')"`,
					"Do not close tmux before openclaw-msg succeeds.",
					"Then explicitly confirm in your final response that commit, bookmark move, push, openclaw notification, and tmux session shutdown succeeded.",
				].join("\n");
				const remotePiCommand = `cd ${sh(remoteCwd)} && exec pi --session ${sh(remoteSessionPath)} --append-system-prompt ${sh(remoteAgentInstructions)} ${sh(cloudPrompt)}`;
				const tmuxSessionName = `pi-cloud-${repoName}-${changeId}-${sessionShort}`;
				const attachCommand = `ssh -t ${HOST} tmux attach -t ${tmuxSessionName}`;
				const copiedAttachCommand = await copyToClipboardIfSupported(pi, attachCommand);

				await runSsh(
					pi,
					[
						"set -euo pipefail",
						`if tmux has-session -t ${sh(tmuxSessionName)} 2>/dev/null; then tmux kill-session -t ${sh(tmuxSessionName)}; fi`,
						`tmux new-session -d -s ${sh(tmuxSessionName)} ${sh(remotePiCommand)}`,
					].join("\n"),
					"Starting remote tmux session",
					30_000,
				);

				if (!ctx.hasUI) {
					process.stdout.write(`${attachCommand}\n`);
					if (copiedAttachCommand) {
						process.stderr.write("Copied attach command to clipboard\n");
					}
				} else {
					ctx.ui.notify(
						`Cloud started in tmux '${tmuxSessionName}'. Attach: ${attachCommand}${copiedAttachCommand ? " (copied to clipboard)" : ""} | Remote workspace: ${remoteWorkspace} | Bookmark: ${bookmarkName} | Pull back later: jj git fetch --remote ${REMOTE_NAME}`,
						"info",
					);
				}
			} catch (error) {
				const message = error instanceof Error ? error.message : String(error);
				if (!ctx.hasUI) {
					process.stderr.write(`/cloud failed: ${message}\n`);
				} else {
					ctx.ui.notify(`/cloud failed: ${message}`, "error");
				}
			} finally {
				clearCloudProgress();
				if (tempDir) {
					await rm(tempDir, { recursive: true, force: true });
				}
			}
		},
	});

	pi.registerCommand("cloud-clean", {
		description: "Clean up cloud workspaces on hetzner-1",
		handler: async (_args, ctx) => {
			if (!ctx.hasUI) {
				ctx.ui.notify("/cloud-clean requires UI mode.", "error");
				return;
			}

			const setCleanupProgress = (line: string) => {
				ctx.ui.setWidget("cloud-clean-progress", [line], { placement: "belowEditor" });
			};
			const clearCleanupProgress = () => {
				ctx.ui.setWidget("cloud-clean-progress", undefined);
			};
			const runCleanupStep = async <T>(label: string, run: () => Promise<T>): Promise<T> => {
				const startedAt = Date.now();
				const render = () => {
					const elapsedSeconds = Math.floor((Date.now() - startedAt) / 1000);
					setCleanupProgress(`🧹 ${label}… ${elapsedSeconds}s`);
				};
				render();
				const timer = setInterval(render, 2_000);
				try {
					const result = await run();
					clearInterval(timer);
					setCleanupProgress(`✅ ${label} done`);
					return result;
				} catch (error) {
					clearInterval(timer);
					setCleanupProgress(`❌ ${label} failed`);
					throw error;
				}
			};

			try {
				const repoRoot = (await execOrThrow(pi, "jj", ["root"], "Detecting jj repo", 5_000)).stdout.trim();
				const repoName = path.basename(repoRoot);
				const remoteHome = "/home/davidpdrsn";
				const snapshot = await runCleanupStep("Scanning remote cloud state", async () =>
					scanCloudCleanupState(pi, repoName, remoteHome),
				);

				const nowEpoch = Math.floor(Date.now() / 1000);
				const workspaceOptions = snapshot.workspaces.map((ws) => {
					const ageSeconds = Math.max(0, nowEpoch - ws.mtimeEpoch);
					const state = ws.active ? "ACTIVE" : "inactive";
					return `${ws.changeId}/${ws.sessionShort} · ${formatAge(ageSeconds)} old · ${state}`;
				});

				const selectedWorkspaceIndexes = await pickMany(
					ctx,
					`/cloud-clean: select workspaces to delete (${snapshot.workspaces.length} total)`,
					workspaceOptions,
				);
				if (selectedWorkspaceIndexes === undefined) {
					ctx.ui.notify("/cloud-clean cancelled.", "info");
					return;
				}

				const selectedWorkspaces = selectedWorkspaceIndexes.map((index) => snapshot.workspaces[index]);
				const shouldOfferBareRepoDelete =
					snapshot.workspaces.length === 0 || selectedWorkspaces.length === snapshot.workspaces.length;

				let deleteBareRepo = false;
				if (shouldOfferBareRepoDelete && snapshot.bareRepoExists) {
					const bareChoice = await pickOne(ctx, "/cloud-clean: shared bare repo action", [
						"Keep shared bare repo",
						`Delete ${snapshot.remoteBareRepo} and remove local remote '${REMOTE_NAME}'`,
					]);
					if (bareChoice === undefined) {
						ctx.ui.notify("/cloud-clean cancelled.", "info");
						return;
					}
					deleteBareRepo = bareChoice === 1;
				}

				if (selectedWorkspaces.length === 0 && !deleteBareRepo) {
					ctx.ui.notify("/cloud-clean: nothing selected.", "info");
					return;
				}

				// Only clean bookmark/ref state for change IDs that are fully removed.
				// A change ID can have multiple session workspaces.
				const totalByChange = new Map<string, number>();
				for (const ws of snapshot.workspaces) {
					totalByChange.set(ws.changeId, (totalByChange.get(ws.changeId) ?? 0) + 1);
				}
				const selectedByChange = new Map<string, number>();
				for (const ws of selectedWorkspaces) {
					selectedByChange.set(ws.changeId, (selectedByChange.get(ws.changeId) ?? 0) + 1);
				}
				const fullyDeletedChangeIds = Array.from(selectedByChange.entries())
					.filter(([changeId, count]) => count === (totalByChange.get(changeId) ?? 0))
					.map(([changeId]) => changeId)
					.sort();

				const summaryLines: string[] = [];
				if (selectedWorkspaces.length > 0) {
					summaryLines.push(`Delete ${selectedWorkspaces.length} workspace(s):`);
					for (const ws of selectedWorkspaces) {
						summaryLines.push(`- ${ws.path}`);
					}
				}
				if (fullyDeletedChangeIds.length > 0) {
					summaryLines.push(`Clean local/remote bookmark state for ${fullyDeletedChangeIds.length} change(s).`);
				}
				if (deleteBareRepo) {
					summaryLines.push(`Delete bare repo: ${snapshot.remoteBareRepo}`);
					summaryLines.push(`Remove local remote: ${REMOTE_NAME}`);
				}

				// Final explicit confirmation before destructive operations.
				const confirmChoice = await confirmCloudCleanup(ctx, "/cloud-clean: confirm", summaryLines);
				if (confirmChoice !== true) {
					ctx.ui.notify("/cloud-clean cancelled.", "info");
					return;
				}

				if (selectedWorkspaces.length > 0) {
					for (const ws of selectedWorkspaces) {
						if (!ws.path.startsWith(`${snapshot.remoteWorkspaceBase}/`)) {
							throw new Error(`Refusing to delete unexpected path: ${ws.path}`);
						}
					}
					await runCleanupStep("Deleting selected cloud workspaces", async () =>
						runSsh(
							pi,
							[
								"set -euo pipefail",
								...selectedWorkspaces.map((ws) => `rm -rf ${sh(ws.path)}`),
							].join("\n"),
							"Deleting selected cloud workspaces",
							120_000,
						),
					);
				}

				// Remove server-side cloud/* refs in the shared bare repo so they don't get re-fetched.
				let deletedRemoteRefs = 0;
				if (!deleteBareRepo && snapshot.bareRepoExists && fullyDeletedChangeIds.length > 0) {
					const validChangeIds = fullyDeletedChangeIds.filter((id) => /^[a-z0-9]+$/i.test(id));
					if (validChangeIds.length > 0) {
						deletedRemoteRefs = await runCleanupStep("Deleting cloud refs in bare repo", async () => {
							const refDeleteScript = [
								"set -euo pipefail",
								...validChangeIds.map((changeId) => {
									const ref = `refs/heads/cloud/${changeId}`;
									return `if git --git-dir ${sh(snapshot.remoteBareRepo)} show-ref --verify --quiet ${sh(ref)}; then git --git-dir ${sh(snapshot.remoteBareRepo)} update-ref -d ${sh(ref)}; echo ${sh(`REFDEL\t${changeId}`)}; fi`;
								}),
							].join("\n");
							const refDeleteResult = await runSsh(pi, refDeleteScript, "Deleting cloud refs in bare repo", 30_000);
							return refDeleteResult.stdout
								.split("\n")
								.map((line) => line.trim())
								.filter((line) => line.startsWith("REFDEL\t")).length;
						});
					}
				}

				// Clear local bookmark state and remote-tracking metadata for fully deleted changes.
				const bookmarkCleanupResult = await runCleanupStep("Cleaning local bookmark state", async () => {
					let forgottenBookmarks = 0;
					let untrackedRemoteBookmarks = 0;
					for (const changeId of fullyDeletedChangeIds) {
						const bookmarkName = `cloud/${changeId}`;
						const forgetResult = (await pi.exec(
							"jj",
							["-R", repoRoot, "bookmark", "forget", "--include-remotes", bookmarkName],
							{ timeout: 10_000 },
						)) as ExecResult;
						if (forgetResult.code === 0) forgottenBookmarks += 1;

						const untrackResult = (await pi.exec(
							"jj",
							["-R", repoRoot, "bookmark", "untrack", bookmarkName, "--remote", REMOTE_NAME],
							{ timeout: 10_000 },
						)) as ExecResult;
						if (untrackResult.code === 0) untrackedRemoteBookmarks += 1;
					}
					return { forgottenBookmarks, untrackedRemoteBookmarks };
				});
				const { forgottenBookmarks, untrackedRemoteBookmarks } = bookmarkCleanupResult;

				let removedLocalRemote = false;
				if (deleteBareRepo) {
					await runCleanupStep("Deleting shared bare repo", async () =>
						runSsh(
							pi,
							[`set -euo pipefail`, `rm -rf ${sh(snapshot.remoteBareRepo)}`].join("\n"),
							"Deleting shared bare repo",
							30_000,
						),
					);
					const remoteRemove = (await pi.exec(
						"jj",
						["-R", repoRoot, "git", "remote", "remove", REMOTE_NAME],
						{ timeout: 10_000 },
					)) as ExecResult;
					removedLocalRemote = remoteRemove.code === 0;
				}

				ctx.ui.notify(
					`/cloud-clean done: deleted ${selectedWorkspaces.length} workspace(s), forgot ${forgottenBookmarks} bookmark(s), untracked ${untrackedRemoteBookmarks} remote bookmark(s)` +
						(deleteBareRepo ? "" : `, deleted ${deletedRemoteRefs} remote ref(s)`) +
						(deleteBareRepo
							? `, deleted bare repo and ${removedLocalRemote ? "removed" : "could not remove"} local remote '${REMOTE_NAME}'`
							: ""),
					"info",
				);
			} catch (error) {
				const message = error instanceof Error ? error.message : String(error);
				ctx.ui.notify(`/cloud-clean failed: ${message}`, "error");
			} finally {
				clearCleanupProgress();
			}
		},
	});
}
