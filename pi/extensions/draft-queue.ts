import type { ExtensionAPI, ExtensionContext } from "@mariozechner/pi-coding-agent";
import { Key, matchesKey, truncateToWidth } from "@mariozechner/pi-tui";

type DraftItem = {
	id: string;
	text: string;
	createdAt: number;
};

type DraftQueueState = {
	items: DraftItem[];
};

function makeDraftId(): string {
	return `${Date.now()}-${Math.random().toString(36).slice(2, 10)}`;
}

function firstLinePreview(text: string): string {
	const normalized = text.replace(/\s+/g, " ").trim();
	return normalized.length > 0 ? normalized : "(empty)";
}

function restoreState(ctx: ExtensionContext): DraftItem[] {
	let items: DraftItem[] = [];

	for (const entry of ctx.sessionManager.getBranch()) {
		if (entry.type === "custom" && entry.customType === "draft-queue") {
			const data = entry.data as DraftQueueState | undefined;
			items = Array.isArray(data?.items)
				? data.items.filter(
					(item): item is DraftItem =>
						typeof item?.id === "string" &&
						typeof item?.text === "string" &&
						typeof item?.createdAt === "number",
				)
				: [];
		}
	}

	return items;
}

export default function draftQueueExtension(pi: ExtensionAPI): void {
	let items: DraftItem[] = [];
	let managerOpen = false;

	function persistState(): void {
		pi.appendEntry<DraftQueueState>("draft-queue", { items });
	}

	function updateUi(ctx: ExtensionContext): void {
		if (!ctx.hasUI) return;

		if (items.length === 0 || managerOpen) {
			ctx.ui.setStatus("draft-queue", undefined);
			ctx.ui.setWidget("draft-queue", undefined);
			return;
		}

		ctx.ui.setStatus("draft-queue", ctx.ui.theme.fg("accent", `drafts:${items.length}`));

		const visibleItems = items.slice(0, 5);
		const lines = [
			ctx.ui.theme.fg("accent", `Draft queue (${items.length})`),
			...visibleItems.map((item, index) => `${ctx.ui.theme.fg("muted", `${index + 1}. `)}${firstLinePreview(item.text)}`),
		];

		if (items.length > visibleItems.length) {
			lines.push(ctx.ui.theme.fg("dim", `… ${items.length - visibleItems.length} more`));
		}

		lines.push(ctx.ui.theme.fg("dim", "Ctrl+Shift+Enter queue • Ctrl+Shift+Q manage"));
		ctx.ui.setWidget("draft-queue", lines, { placement: "belowEditor" });
	}

	function queueText(text: string, ctx: ExtensionContext): boolean {
		const trimmed = text.trim();
		if (!trimmed) {
			ctx.ui.notify("Nothing to queue", "warning");
			return false;
		}

		items = [...items, { id: makeDraftId(), text, createdAt: Date.now() }];
		persistState();
		updateUi(ctx);
		ctx.ui.notify("Draft queued", "info");
		return true;
	}

	function removeAt(index: number): DraftItem | undefined {
		if (index < 0 || index >= items.length) return undefined;
		const [removed] = items.splice(index, 1);
		items = [...items];
		return removed;
	}

	function takeDraft(index: number): DraftItem | undefined {
		const item = removeAt(index);
		if (!item) return undefined;
		persistState();
		return item;
	}

	function sendDraft(index: number, ctx: ExtensionContext): boolean {
		const item = removeAt(index);
		if (!item) return false;

		persistState();
		updateUi(ctx);

		if (ctx.isIdle()) {
			pi.sendUserMessage(item.text);
		} else {
			pi.sendUserMessage(item.text, { deliverAs: "followUp" });
			ctx.ui.notify("Draft queued to send as follow-up", "info");
		}

		return true;
	}

	async function openManager(ctx: ExtensionContext): Promise<void> {
		if (!ctx.hasUI) return;
		if (items.length === 0) {
			ctx.ui.notify("Draft queue is empty", "info");
			return;
		}

		managerOpen = true;
		updateUi(ctx);

		try {
			const action = await ctx.ui.custom<{ type: "restore" | "close"; text?: string }>((tui, theme, _kb, done) => {
				let selected = 0;
				let cachedWidth: number | undefined;
				let cachedLines: string[] | undefined;

				function refresh(): void {
					if (items.length === 0) {
						done({ type: "close" });
						return;
					}
					selected = Math.max(0, Math.min(selected, items.length - 1));
					cachedWidth = undefined;
					cachedLines = undefined;
					tui.requestRender();
				}

				return {
				handleInput(data: string) {
					if (matchesKey(data, Key.up) || data === "k") {
						selected = Math.max(0, selected - 1);
						refresh();
						return;
					}
					if (matchesKey(data, Key.down) || data === "j") {
						selected = Math.min(items.length - 1, selected + 1);
						refresh();
						return;
					}
					if (matchesKey(data, Key.enter)) {
						const item = takeDraft(selected);
						if (!item) return;
						done({ type: "restore", text: item.text });
						return;
					}
					if (data === "s") {
						sendDraft(selected, ctx);
						if (items.length === 0) done({ type: "close" });
						else refresh();
						return;
					}
					if (data === "d") {
						const removed = removeAt(selected);
						if (!removed) return;
						persistState();
						updateUi(ctx);
						ctx.ui.notify("Draft deleted", "info");
						if (items.length === 0) done({ type: "close" });
						else refresh();
						return;
					}
					if (matchesKey(data, Key.escape)) {
						done({ type: "close" });
					}
				},
				render(width: number) {
					if (cachedLines && cachedWidth === width) return cachedLines;

					const lines: string[] = [];
					const add = (line: string) => lines.push(truncateToWidth(line, width));

					add(theme.fg("accent", theme.bold(`Draft Queue (${items.length})`)));
					lines.push("");

					for (let i = 0; i < items.length; i++) {
						const item = items[i]!;
						const active = i === selected;
						const prefix = active ? theme.fg("accent", "> ") : "  ";
						const label = `${i + 1}. ${firstLinePreview(item.text)}`;
						add(prefix + (active ? theme.fg("accent", label) : label));

						const extraLines = item.text
							.trim()
							.split(/\r?\n/)
							.slice(1, 3)
							.map((line) => line.trim())
							.filter((line) => line.length > 0);
						for (const extra of extraLines) {
							add(`    ${theme.fg("dim", extra)}`);
						}
						if (item.text.split(/\r?\n/).length > 3) {
							add(`    ${theme.fg("dim", "…")}`);
						}
					}

					lines.push("");
					add(theme.fg("dim", "Enter restore • s send • d delete • Esc close"));

					cachedWidth = width;
					cachedLines = lines;
					return lines;
				},
				invalidate() {
					cachedWidth = undefined;
					cachedLines = undefined;
				},
			};
			});

			updateUi(ctx);
			if (action?.type === "restore" && typeof action.text === "string") {
				ctx.ui.setEditorText(action.text);
				ctx.ui.notify("Draft restored to editor", "info");
			}
		} finally {
			managerOpen = false;
			updateUi(ctx);
		}
	}

	pi.registerShortcut(Key.ctrlShift("enter"), {
		description: "Queue current draft without sending",
		handler: async (ctx) => {
			if (!ctx.hasUI) return;
			const text = ctx.ui.getEditorText();
			if (!queueText(text, ctx)) return;
			ctx.ui.setEditorText("");
		},
	});

	pi.registerShortcut(Key.ctrlShift("q"), {
		description: "Open draft queue manager",
		handler: async (ctx) => {
			await openManager(ctx);
		},
	});

	pi.registerCommand("draft-queue-clear", {
		description: "Clear all queued drafts",
		handler: async (_args, ctx) => {
			if (items.length === 0) {
				ctx.ui.notify("Draft queue is already empty", "info");
				return;
			}

			const confirmed = ctx.hasUI
				? await ctx.ui.confirm("Clear draft queue?", `Delete ${items.length} queued draft${items.length === 1 ? "" : "s"}?`)
				: true;
			if (!confirmed) return;

			items = [];
			persistState();
			updateUi(ctx);
			ctx.ui.notify("Draft queue cleared", "info");
		},
	});

	function restoreAndRefresh(ctx: ExtensionContext): void {
		items = restoreState(ctx);
		updateUi(ctx);
	}

	pi.on("session_start", async (_event, ctx) => {
		restoreAndRefresh(ctx);
	});

	pi.on("session_tree", async (_event, ctx) => {
		restoreAndRefresh(ctx);
	});
}
