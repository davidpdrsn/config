import type { ExtensionAPI, ExtensionContext, SessionEntry } from "@earendil-works/pi-coding-agent";
import {
	type Component,
	type Focusable,
	Input,
	Key,
	matchesKey,
	type OverlayHandle,
	type OverlayOptions,
	TuiAltScreen,
	type TuiMouseEvent,
	type TuiMouseEventResult,
	truncateToWidth,
	visibleWidth,
} from "@earendil-works/pi-tui";

// Select text in the fullscreen transcript and a quote box opens at the
// selection. Type an optional comment and press enter to append the selection
// as a Markdown blockquote, followed by the comment, to the prompt. The
// transcript keeps its scroll position and focus goes back to where it was.
//
// Pi has no extension API for transcript selections, so this wraps
// TuiAltScreen's viewport input handler to learn when a mouse selection ends,
// and reads the selection through TuiAltScreen methods that its type
// declarations mark private.

const BOX_WIDTH = 64;
const BOX_HEIGHT = 3;

type Theme = ExtensionContext["ui"]["theme"];

// The parts of a ScrollView this extension uses.
interface ScrollView {
	readonly scrollTop: number;
	readonly viewportHeight: number;
	scrollTo(scrollTop: number, options?: { disableFollow?: boolean }): void;
}

// The fields of TuiAltScreen this extension uses. Some are private in the
// type declarations but plain properties at runtime.
interface SelectionTui {
	readonly viewportTop: number;
	hasActiveSelection(): boolean;
	getActiveSelectionText?(): string | undefined;
	resetTextSelection?(): void;
	getPrimaryScrollView?(): ScrollView;
	showOverlay(component: Component, options?: OverlayOptions): OverlayHandle;
	requestRender(): void;
}

type InputHook = (tui: SelectionTui, data: string) => void;

// Patch the prototype once per process. `/reload` creates a new extension
// instance, so the wrapper calls whichever hook is registered now instead of
// closing over the first one.
const HOOK = Symbol.for("pi-quote-selection.hook");
const PATCHED = Symbol.for("pi-quote-selection.patched");
type HookRegistry = { [HOOK]?: InputHook };
type PatchableProto = { [PATCHED]?: boolean; handleViewportInput?: (data: string) => unknown };

function installPatch(): boolean {
	const proto = TuiAltScreen?.prototype as unknown as PatchableProto | undefined;
	const original = proto?.handleViewportInput;
	if (!proto || typeof original !== "function") return false;
	if (proto[PATCHED]) return true;
	proto.handleViewportInput = function (this: SelectionTui, data: string) {
		const result = original.call(this, data);
		try {
			(globalThis as HookRegistry)[HOOK]?.(this, data);
		} catch {
			// A broken hook must never break transcript input.
		}
		return result;
	};
	proto[PATCHED] = true;
	return true;
}

type SgrMouse = { button: number; x: number; y: number; release: boolean };

function parseSgrMouse(data: string): SgrMouse | undefined {
	const match = /^\x1b\[<(\d+);(\d+);(\d+)([Mm])$/.exec(data);
	if (!match) return undefined;
	return {
		button: Number(match[1]),
		x: Number(match[2]) - 1,
		y: Number(match[3]) - 1,
		release: match[4] === "m",
	};
}

// Turn rendered transcript lines into quotable text. The first line usually
// starts mid-line, so it is only trimmed. The rest lose the indentation they
// share, which removes the transcript's left padding but keeps nesting.
export function cleanSelection(text: string): string {
	const lines = text.replace(/\r/g, "").split("\n").map(line => line.trimEnd());
	const [first = "", ...rest] = lines;
	const indents = rest.filter(line => line.trim()).map(line => line.length - line.trimStart().length);
	const indent = indents.length > 0 ? Math.min(...indents) : 0;
	const cleaned = [first.trimStart(), ...rest.map(line => line.slice(indent))];
	while (cleaned.length > 0 && !cleaned[0]!.trim()) cleaned.shift();
	while (cleaned.length > 0 && !cleaned.at(-1)!.trim()) cleaned.pop();
	return cleaned.join("\n");
}

const MARKUP = "[*_`~]*";
const escapeRegExp = (text: string) => text.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");

// Restore the line breaks the selection had in its message. The terminal
// wraps lines to the window width, so the rendered selection has breaks the
// message never had. This finds the selected words in the message text, with
// Markdown markers allowed between characters, and rebuilds the selection
// with the message's own whitespace between words. Words keep their rendered
// form, so the quote matches what was on screen.
export function restoreLineBreaks(selection: string, sources: string[]): string | undefined {
	const words = selection.split(/\s+/).filter(Boolean);
	if (words.length === 0 || selection.length > 20_000) return undefined;
	const word = (w: string) => Array.from(w, char => escapeRegExp(char)).join(MARKUP);
	// Each gap captures the whitespace and drops heading and blockquote markers.
	const gap = `${MARKUP}(\\s+)(?:[>#]+\\s*)?${MARKUP}`;
	const pattern = new RegExp(words.map(word).join(gap));
	for (const source of sources) {
		const match = pattern.exec(source);
		if (!match) continue;
		return words.reduce((text, w, i) => {
			if (i === 0) return w;
			const space = match[i]!;
			return text + (space.includes("\n") ? space.replace(/^[ \t]+/, "") : " ") + w;
		}, "");
	}
	return undefined;
}

function messageTexts(entries: SessionEntry[]): string[] {
	const texts: string[] = [];
	for (const entry of [...entries].reverse()) {
		if (entry.type !== "message") continue;
		const content = (entry.message as { content?: unknown }).content;
		if (typeof content === "string") {
			texts.push(content);
		} else if (Array.isArray(content)) {
			for (const part of content) {
				if (part?.type === "text" && typeof part.text === "string") texts.push(part.text);
			}
		}
	}
	return texts;
}

export function toBlockquote(text: string): string {
	return text.split("\n").map(line => (line ? `> ${line}` : ">")).join("\n");
}

// Append the quote and the comment on it after the existing prompt, each
// separated by a blank line. A blank line at the end puts the next thing typed
// in the prompt in a new paragraph.
export function appendQuote(prompt: string, text: string, comment = ""): string {
	const head = prompt.replace(/\s+$/, "");
	const parts = [head, toBlockquote(text), comment.trim()].filter(Boolean);
	return `${parts.join("\n\n")}\n\n`;
}

// A one-line comment input in a rounded border:
//
//   ╭─ Quote ───────────────────╮
//   │ Comment (optional)        │
//   ╰─ enter add · esc cancel ──╯
class QuoteBox implements Component, Focusable {
	private readonly input = new Input({ prompt: "", placeholder: "Comment (optional)" });
	private isFocused = false;

	constructor(
		private readonly theme: Theme | undefined,
		private readonly onSubmit: (comment: string) => void,
		private readonly onCancel: () => void,
	) {}

	get focused(): boolean {
		return this.isFocused;
	}

	set focused(value: boolean) {
		this.isFocused = value;
		this.input.focused = value;
	}

	handleInput(data: string): void {
		if (matchesKey(data, Key.enter)) this.onSubmit(this.input.getValue());
		else if (matchesKey(data, Key.escape)) this.onCancel();
		else this.input.handleInput(data);
	}

	handleMouse(event: TuiMouseEvent): TuiMouseEventResult {
		// Claim every event so the box never starts a transcript selection.
		return event.type === "press" ? { focus: true } : { handled: true };
	}

	render(width: number): string[] {
		const border = (text: string) => (this.theme ? this.theme.fg("borderAccent", text) : text);
		const title = (text: string) => (this.theme ? this.theme.fg("accent", this.theme.bold(text)) : text);
		const hint = (text: string) => (this.theme ? this.theme.fg("dim", text) : text);
		const inner = Math.max(1, width - 4);
		const rule = (label: string, style: (text: string) => string, left: string, right: string) => {
			const fill = Math.max(0, width - 2 - 2 - visibleWidth(label) - 1);
			return border(`${left}─ `) + style(label) + border(` ${"─".repeat(fill)}${right}`);
		};
		const field = truncateToWidth(this.input.render(inner)[0] ?? "", inner, "", true);
		return [
			rule("Quote", title, "╭", "╮"),
			`${border("│")} ${field} ${border("│")}`,
			rule("enter add to prompt · esc cancel", hint, "╰", "╯"),
		].map(line => truncateToWidth(line, width, ""));
	}

	invalidate(): void {
		this.input.invalidate();
	}
}

type OpenBox = { tui: SelectionTui; handle: OverlayHandle; text: string };

export default function quoteSelection(pi: ExtensionAPI): void {
	let ctx: ExtensionContext | undefined;
	let open: OpenBox | undefined;
	let pressY: number | undefined;

	function closeBox(): void {
		open?.handle.hide();
		open = undefined;
	}

	function submit(comment: string): void {
		const box = open;
		if (!box || !ctx) return;
		closeBox();
		const cleaned = cleanSelection(box.text);
		if (!cleaned) return;
		const quoted = restoreLineBreaks(cleaned, messageTexts(ctx.sessionManager.getBranch())) ?? cleaned;
		// A taller prompt shrinks the transcript. Pin the transcript's top
		// line so nothing on screen moves, even when it was following new
		// output.
		const scrollView = box.tui.getPrimaryScrollView?.();
		const scrollTop = scrollView?.scrollTop;
		ctx.ui.setEditorText(appendQuote(ctx.ui.getEditorText(), quoted, comment));
		if (scrollView && scrollTop !== undefined) scrollView.scrollTo(scrollTop, { disableFollow: true });
		box.tui.resetTextSelection?.();
		box.tui.requestRender();
	}

	function openBox(tui: SelectionTui, text: string, x: number, topY: number, bottomY: number): void {
		closeBox();
		const transcriptHeight = () => tui.getPrimaryScrollView?.().viewportHeight ?? Infinity;
		// Below the selection, or above it when there is no room below.
		const anchorRow = bottomY + 1 + BOX_HEIGHT <= transcriptHeight() ? bottomY + 1 : topY - BOX_HEIGHT;
		// Follow the selection when the transcript scrolls or new output
		// arrives.
		const anchorTop = tui.viewportTop;
		const currentRow = () => anchorRow - (tui.viewportTop - anchorTop);
		const options: OverlayOptions = {
			width: BOX_WIDTH,
			col: Math.max(0, x - 2),
			visible: () => {
				const row = currentRow();
				return row >= 0 && row + BOX_HEIGHT <= transcriptHeight();
			},
		};
		// The TUI reads `row` on every render.
		Object.defineProperty(options, "row", { enumerable: true, get: currentRow });
		const box = new QuoteBox(ctx?.ui.theme, submit, closeBox);
		open = { tui, handle: tui.showOverlay(box, options), text };
	}

	function isInBox(x: number, y: number): boolean {
		const bounds = open?.handle.getBounds();
		if (!bounds) return false;
		return y >= bounds.row && y < bounds.row + bounds.height && x >= bounds.col && x < bounds.col + bounds.width;
	}

	// Runs after TuiAltScreen has handled each input in the transcript.
	const hook: InputHook = (tui, data) => {
		const mouse = parseSgrMouse(data);
		if (!mouse) return;
		const isWheel = (mouse.button & 64) !== 0;
		const isMotion = (mouse.button & 32) !== 0;
		const isPrimary = (mouse.button & 3) === 0;
		if (isWheel || isMotion || !isPrimary) return;
		if (!mouse.release) {
			if (isInBox(mouse.x, mouse.y)) return;
			// A press outside the box starts a new selection or clicks
			// something else. Either way the old selection is gone.
			closeBox();
			pressY = mouse.y;
			return;
		}
		const startY = pressY ?? mouse.y;
		pressY = undefined;
		if (open || !tui.hasActiveSelection()) return;
		const text = tui.getActiveSelectionText?.();
		if (text?.trim()) openBox(tui, text, mouse.x, Math.min(startY, mouse.y), Math.max(startY, mouse.y));
	};

	const patched = installPatch();
	(globalThis as HookRegistry)[HOOK] = hook;

	pi.on("session_start", (_event, nextCtx) => {
		ctx = nextCtx;
		if (!patched && nextCtx.mode === "tui") {
			nextCtx.ui.notify("quote-selection: this Pi version has no transcript selection hook", "warning");
		}
	});

	pi.on("session_shutdown", () => {
		closeBox();
		ctx = undefined;
		if ((globalThis as HookRegistry)[HOOK] === hook) delete (globalThis as HookRegistry)[HOOK];
	});
}
