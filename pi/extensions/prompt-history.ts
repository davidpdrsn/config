import type { ExtensionAPI, ExtensionContext, SessionEntry } from "@earendil-works/pi-coding-agent";
import { getSelectListTheme } from "@earendil-works/pi-coding-agent";
import { fuzzyFilter, Input, Key, matchesKey, SelectList, truncateToWidth } from "@earendil-works/pi-tui";

export function collectPrompts(entries: SessionEntry[]): string[] {
	const prompts = new Set<string>();
	for (const entry of [...entries].reverse()) {
		if (entry.type !== "message" || entry.message.role !== "user") continue;
		const content = entry.message.content;
		const text = typeof content === "string"
			? content
			: content.filter(part => part.type === "text").map(part => part.text).join("\n");
		if (text.trim()) prompts.add(text);
	}
	return [...prompts];
}

// Follow pi-tui's greedy matching, token splitting, and alphanumeric fallback.
export function underlineMatches(text: string, query: string): string {
	const lower = text.toLowerCase();
	function positions(token: string): number[] | undefined {
		const result: number[] = [];
		let start = 0;
		for (let i = 0; i < token.length; i++) {
			const index = lower.indexOf(token[i]!, start);
			if (index < 0) return undefined;
			result.push(index);
			start = index + 1;
		}
		return result;
	}
	const matched = new Set<number>();
	for (const token of query.toLowerCase().split(/[\s/]+/).filter(Boolean)) {
		let indices = positions(token);
		if (!indices) {
			const parts = token.match(/^([a-z]+)([0-9]+)$/) ?? token.match(/^([0-9]+)([a-z]+)$/);
			if (parts) indices = positions(parts[2]! + parts[1]!);
		}
		if (!indices) return text;
		for (const index of indices) matched.add(index);
	}
	let offset = 0;
	return Array.from(text, char => {
		const length = char.toLowerCase().length;
		const highlight = Array.from({ length }, (_, i) => offset + i).some(index => matched.has(index));
		offset += length;
		// Reset only underline so the selected row's foreground stays intact.
		return highlight ? `\x1b[4m${char}\x1b[24m` : char;
	}).join("");
}

export default function promptHistory(pi: ExtensionAPI): void {
	let open = false;
	async function search(ctx: ExtensionContext): Promise<void> {
		if (ctx.mode !== "tui" || open) return;
		const prompts = collectPrompts(ctx.sessionManager.getEntries());
		if (prompts.length === 0) {
			ctx.ui.notify("No prompts in this session yet", "info");
			return;
		}
		open = true;
		try {
			const selected = await ctx.ui.custom<string | undefined>((tui, theme, kb, done) => {
				const input = new Input();
				const items = prompts.map(text => ({ value: text, label: text.replace(/\s+/g, " ").trim() }));
				function makeList(query: string): SelectList {
					const list = new SelectList(fuzzyFilter(items, query, item => item.label), 10, getSelectListTheme(), {
						truncatePrimary: ({ text, maxWidth }) => truncateToWidth(underlineMatches(text, query), maxWidth, ""),
					});
					list.onSelect = item => done(item.value);
					list.onCancel = () => done(undefined);
					return list;
				}
				let list = makeList("");
				return {
					get focused() { return input.focused; },
					set focused(value: boolean) { input.focused = value; },
					render(width: number) {
						return [
							truncateToWidth(theme.fg("accent", "Prompt history"), width),
							...input.render(width),
							...list.render(width),
							truncateToWidth(theme.fg("dim", "Type to search • ↑↓ / Ctrl+R browse • Enter restore • Esc cancel"), width),
						];
					},
					invalidate() { input.invalidate(); list.invalidate(); },
					handleInput(data: string) {
						if (matchesKey(data, Key.ctrl("r"))) {
							list.handleInput("\x1b[B");
						} else if ((["tui.select.up", "tui.select.down", "tui.select.pageUp", "tui.select.pageDown", "tui.select.confirm", "tui.select.cancel"] as const)
							.some(action => kb.matches(data, action))) {
							list.handleInput(data);
						} else {
							const before = input.getValue();
							input.handleInput(data);
							if (input.getValue() !== before) list = makeList(input.getValue());
						}
						tui.requestRender();
					},
				};
			});
			if (selected !== undefined) ctx.ui.setEditorText(selected);
		} finally {
			open = false;
		}
	}
	pi.registerShortcut(Key.ctrl("r"), { description: "Search this session's prompts", handler: search });
	pi.registerCommand("prompt-history", {
		description: "Search this session's prompts",
		handler: async (_args, ctx) => search(ctx),
	});
}
