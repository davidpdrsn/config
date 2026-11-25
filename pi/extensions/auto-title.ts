import type { ExtensionAPI, ExtensionContext, SessionEntry } from "@earendil-works/pi-coding-agent";
import { cleanTitle, describeMessage, smallModelId, SYSTEM_PROMPT, titlePrompt, type TranscriptMessage } from "../scripts/titles";

// Names the session with a small model. Pi puts the session name in the
// terminal title as "π - <name> - <cwd>", so the name becomes the tab title.
// The model call goes straight to the provider and never enters the
// agent's context.

const MAX_TOKENS = 100;
const TIMEOUT_MS = 30_000;

// A title for the first prompt must not replace a name the user set with
// /name while the model wrote. /retitle always replaces the name.
type Request = "firstPrompt" | "retitle";

function messageText(content: string | readonly { type: string; text?: string }[]): { text: string; images: number } {
	if (typeof content === "string") return { text: content, images: 0 };
	const text = content.flatMap(part => (part.type === "text" && part.text ? [part.text] : [])).join("\n");
	return { text, images: content.filter(part => part.type === "image").length };
}

function transcriptOf(entries: readonly SessionEntry[]): TranscriptMessage[] {
	return entries.flatMap(entry => {
		if (entry.type !== "message") return [];
		const { role } = entry.message;
		if (role !== "user" && role !== "assistant") return [];
		const { text, images } = messageText(entry.message.content);
		return [{ role, text: describeMessage(text, images) }];
	});
}

export default function autoTitle(pi: ExtensionAPI): void {
	// Bumped by every request and session switch, so only the newest request
	// for the current session names it.
	let generation = 0;

	async function title(ctx: ExtensionContext, transcript: readonly TranscriptMessage[], request: Request): Promise<void> {
		const current = ++generation;
		const main = ctx.model;
		if (!main) return;
		const ids = ctx.modelRegistry.getAvailable().filter(model => model.provider === main.provider).map(model => model.id);
		const id = smallModelId(ids);
		const model = id === undefined ? undefined : ctx.modelRegistry.find(main.provider, id);
		if (!model) {
			if (request === "retitle") ctx.ui.notify(`No small model for ${main.provider} to write a title`, "warning");
			return;
		}
		const answer = await ctx.modelRegistry
			.streamSimple(
				model,
				{ systemPrompt: SYSTEM_PROMPT, messages: [{ role: "user", content: titlePrompt(transcript), timestamp: Date.now() }] },
				{ maxTokens: MAX_TOKENS, signal: AbortSignal.timeout(TIMEOUT_MS) },
			)
			.result();
		if (current !== generation) return;
		if (answer.stopReason === "error" || answer.stopReason === "aborted") {
			ctx.ui.notify(`${model.id} wrote no title: ${answer.errorMessage ?? answer.stopReason}`, "warning");
			return;
		}
		const text = answer.content.flatMap(block => (block.type === "text" ? [block.text] : [])).join("");
		const name = cleanTitle(text);
		if (name === undefined) {
			ctx.ui.notify(`${model.id} wrote no title but ${JSON.stringify(text.slice(0, 200))}`, "warning");
			return;
		}
		if (request === "firstPrompt" && pi.getSessionName() !== undefined) return;
		pi.setSessionName(name);
	}

	pi.on("session_start", () => {
		generation++;
	});

	pi.on("before_agent_start", (event, ctx) => {
		if (ctx.mode !== "tui" || event.messageType !== "user" || pi.getSessionName() !== undefined) return;
		const prompt = { role: "user" as const, text: describeMessage(event.prompt, event.images?.length ?? 0) };
		title(ctx, [...transcriptOf(ctx.sessionManager.getBranch()), prompt], "firstPrompt").catch((error: unknown) => {
			ctx.ui.notify(`Naming the session failed: ${error instanceof Error ? error.message : String(error)}`, "warning");
		});
	});

	pi.registerCommand("retitle", {
		description: "Name the session and tab from the conversation so far",
		handler: async (_args, ctx) => {
			const transcript = transcriptOf(ctx.sessionManager.getBranch());
			if (transcript.length === 0) {
				ctx.ui.notify("Nothing to name yet", "info");
				return;
			}
			await title(ctx, transcript, "retitle");
		},
	});
}
