import type { ExtensionAPI, ExtensionContext, Theme } from "@mariozechner/pi-coding-agent";
import { Text } from "@mariozechner/pi-tui";
import { clearSessionStatusLines, getSessionStatusLines, type StatusLine } from "./status-hub-state";

const WIDGET_KEY = "status-hub";
const REFRESH_MS = 150;

const SLOT_ORDER = ["cloud", "cloud-clean", "plan", "todo", "topic"] as const;

function slotOrder(slot: string): number {
	const index = SLOT_ORDER.indexOf(slot as (typeof SLOT_ORDER)[number]);
	return index === -1 ? SLOT_ORDER.length : index;
}

function styleLine(line: StatusLine, theme: Theme): string {
	switch (line.tone) {
		case "muted":
			return theme.fg("muted", line.text);
		case "dim":
			return theme.fg("dim", line.text);
		case "warning":
			return theme.fg("warning", line.text);
		case "success":
			return theme.fg("success", line.text);
		case "error":
			return theme.fg("error", line.text);
		case "accent":
			return theme.fg("accent", line.text);
		default:
			return line.text;
	}
}

function renderStatusHub(ctx: ExtensionContext, lastSignature: { value: string }): void {
	if (!ctx.hasUI) return;
	const sessionId = ctx.sessionManager.getSessionId();
	const lines = getSessionStatusLines(ctx.cwd, sessionId)
		.filter((line) => line.text.length > 0)
		.sort((a, b) => slotOrder(a.slot) - slotOrder(b.slot));
	const signature = JSON.stringify(lines);
	if (signature === lastSignature.value) return;
	lastSignature.value = signature;

	if (lines.length === 0) {
		ctx.ui.setWidget(WIDGET_KEY, undefined);
		return;
	}

	ctx.ui.setWidget(
		WIDGET_KEY,
		(_tui, theme) => new Text(lines.map((line) => styleLine(line, theme)).join("\n"), 0, 0),
		{ placement: "belowEditor" },
	);
}

export default function (pi: ExtensionAPI): void {
	let poller: ReturnType<typeof setInterval> | undefined;
	const lastSignature = { value: "" };

	const startPolling = (ctx: ExtensionContext) => {
		if (poller) return;
		renderStatusHub(ctx, lastSignature);
		poller = setInterval(() => {
			renderStatusHub(ctx, lastSignature);
		}, REFRESH_MS);
	};

	const stopPolling = () => {
		if (!poller) return;
		clearInterval(poller);
		poller = undefined;
	};

	pi.on("session_start", async (_event, ctx) => {
		startPolling(ctx);
	});

	pi.on("session_switch", async (_event, ctx) => {
		stopPolling();
		lastSignature.value = "";
		startPolling(ctx);
	});

	pi.on("session_fork", async (_event, ctx) => {
		stopPolling();
		lastSignature.value = "";
		startPolling(ctx);
	});

	pi.on("session_tree", async (_event, ctx) => {
		stopPolling();
		lastSignature.value = "";
		startPolling(ctx);
	});

	pi.on("before_agent_start", async (event, ctx) => {
		startPolling(ctx);
		return { systemPrompt: event.systemPrompt };
	});

	pi.on("session_shutdown", async (_event, ctx) => {
		clearSessionStatusLines(ctx.cwd, ctx.sessionManager.getSessionId());
		stopPolling();
		lastSignature.value = "";
		if (ctx.hasUI) ctx.ui.setWidget(WIDGET_KEY, undefined);
	});
}
