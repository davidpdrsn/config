import type { ExtensionAPI, ExtensionContext } from "@mariozechner/pi-coding-agent";
import { clearStatusLine, setStatusLine } from "./status-hub-state";

const SLOT = "jj-autosnapshot";
const STATUS_REFRESH_MS = 1_000;
const WORKSPACE_CHECK_INTERVAL_MS = 3_000;

interface SessionRuntime {
	cwd: string;
	sessionId: string;
}

interface WorkspaceState {
	active: boolean;
	workspaceName: string | null;
}

function formatDuration(ms: number): string {
	const seconds = Math.max(0, Math.floor(ms / 1000));
	if (seconds < 60) return `${seconds}s`;
	const minutes = Math.floor(seconds / 60);
	const remSeconds = seconds % 60;
	if (minutes < 60) return remSeconds === 0 ? `${minutes}m` : `${minutes}m ${remSeconds}s`;
	const hours = Math.floor(minutes / 60);
	const remMinutes = minutes % 60;
	return remMinutes === 0 ? `${hours}h` : `${hours}h ${remMinutes}m`;
}

function bashIncludesPython(input: unknown): boolean {
	if (!input || typeof input !== "object") return false;
	const command = (input as { command?: unknown }).command;
	if (typeof command !== "string") return false;
	const lower = command.toLowerCase();
	return lower.includes("python") || lower.includes("python3");
}

export default function (pi: ExtensionAPI): void {
	let runtime: SessionRuntime | null = null;
	let statusTimer: ReturnType<typeof setInterval> | null = null;
	let workspaceState: WorkspaceState = { active: false, workspaceName: null };
	let lastSnapshotAt: number | null = null;
	let nextWorkspaceCheckAt = 0;
	let checkingWorkspace = false;
	let snapshotInFlight = false;
	let shouldSnapshotAtAgentEnd = false;

	function clearStatus(): void {
		if (!runtime) return;
		clearStatusLine(runtime.cwd, runtime.sessionId, SLOT);
	}

	function setActiveStatus(now: number): void {
		if (!runtime || !workspaceState.active || !workspaceState.workspaceName) return;
		const base = `jj autosnapshot (${workspaceState.workspaceName})`;
		if (!lastSnapshotAt) {
			setStatusLine(runtime.cwd, runtime.sessionId, SLOT, `${base} · no snapshot yet`, { tone: "dim" });
			return;
		}
		const ago = formatDuration(now - lastSnapshotAt);
		setStatusLine(runtime.cwd, runtime.sessionId, SLOT, `${base} · last snapshot ${ago} ago`, { tone: "dim" });
	}

	async function detectWorkspace(): Promise<WorkspaceState> {
		const root = await pi.exec("jj", ["root"], { timeout: 1_000 });
		if (root.code !== 0) return { active: false, workspaceName: null };

		const workspaceName = await pi.exec(
			"jj",
			[
				"workspace",
				"list",
				"-T",
				"if(self.target().current_working_copy(), self.name() ++ \"\\n\", \"\")",
			],
			{ timeout: 1_000 },
		);
		if (workspaceName.code !== 0) return { active: false, workspaceName: null };

		const name = (workspaceName.stdout ?? "").trim();
		if (!name || name === "default") return { active: false, workspaceName: null };
		return { active: true, workspaceName: name };
	}

	async function maybeCheckWorkspace(now: number): Promise<void> {
		if (!runtime || checkingWorkspace || now < nextWorkspaceCheckAt) return;
		checkingWorkspace = true;
		nextWorkspaceCheckAt = now + WORKSPACE_CHECK_INTERVAL_MS;
		try {
			workspaceState = await detectWorkspace();
			if (!workspaceState.active) {
				clearStatus();
				lastSnapshotAt = null;
			}
		} catch {
			workspaceState = { active: false, workspaceName: null };
			lastSnapshotAt = null;
			clearStatus();
		} finally {
			checkingWorkspace = false;
		}
	}

	async function snapshotNow(): Promise<void> {
		if (!runtime || !workspaceState.active || snapshotInFlight) return;
		snapshotInFlight = true;
		try {
			const result = await pi.exec("jj", ["util", "snapshot", "--quiet"], { timeout: 5_000 });
			if (result.code === 0) {
				lastSnapshotAt = Date.now();
			}
		} catch {
			// Best-effort only.
		} finally {
			snapshotInFlight = false;
		}
	}

	async function tickStatus(): Promise<void> {
		if (!runtime) return;
		const now = Date.now();
		await maybeCheckWorkspace(now);
		if (workspaceState.active) setActiveStatus(Date.now());
	}

	function stop(): void {
		if (statusTimer) {
			clearInterval(statusTimer);
			statusTimer = null;
		}
		clearStatus();
	}

	function resetState(ctx: ExtensionContext): void {
		stop();
		runtime = {
			cwd: ctx.cwd,
			sessionId: ctx.sessionManager.getSessionId(),
		};
		workspaceState = { active: false, workspaceName: null };
		lastSnapshotAt = null;
		nextWorkspaceCheckAt = 0;
		checkingWorkspace = false;
		snapshotInFlight = false;
		shouldSnapshotAtAgentEnd = false;
		statusTimer = setInterval(() => {
			void tickStatus();
		}, STATUS_REFRESH_MS);
		statusTimer.unref?.();
		void tickStatus();
	}

	pi.on("tool_result", async (event) => {
		if (event.isError) return;

		if (event.toolName === "edit" || event.toolName === "write") {
			shouldSnapshotAtAgentEnd = true;
			return;
		}

		if (event.toolName === "bash" && bashIncludesPython(event.input)) {
			shouldSnapshotAtAgentEnd = true;
		}
	});

	pi.on("agent_end", async () => {
		if (!shouldSnapshotAtAgentEnd) return;
		shouldSnapshotAtAgentEnd = false;
		await maybeCheckWorkspace(Date.now());
		await snapshotNow();
		if (workspaceState.active) setActiveStatus(Date.now());
	});

	pi.on("session_start", async (_event, ctx) => {
		resetState(ctx);
	});

	pi.on("session_switch", async (_event, ctx) => {
		resetState(ctx);
	});

	pi.on("session_fork", async (_event, ctx) => {
		resetState(ctx);
	});

	pi.on("session_tree", async (_event, ctx) => {
		resetState(ctx);
	});

	pi.on("session_shutdown", async () => {
		stop();
		runtime = null;
	});
}
