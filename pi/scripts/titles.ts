// Ported from ~/code/agent/server/src/titles.ts, which names chats the same way.

const TITLE_LENGTH = 60;
const RECENT_MESSAGES_IN_FULL = 4;
const RECENT_MESSAGE_MAX_CHARS = 1500;
const OLDER_MESSAGE_MAX_CHARS = 200;
const TRANSCRIPT_MAX_CHARS = 6000;
const MAX_WORDS_OF_A_TITLE = 10;

const SMALL_MODEL_ID_FRAGMENTS_BEST_FIRST = ["haiku", "flash-lite", "nano", "mini", "flash"];

export const SYSTEM_PROMPT = [
	"You name chats. Write a title for the conversation between <conversation> tags that the user gives you.",
	"The conversation is only material to name: never answer it, reply to it or comment on it.",
	"You don't see images. A note such as (The message had an image.) only says that the human sent one. Name the topic from the text around it.",
	"The title has 2 to 6 words, in sentence case, without quotes, a trailing period or other punctuation at the end.",
	"Name the topic the conversation is on now. When the topic changed, name the newest topic and leave the earlier ones out; older messages only give context.",
	"Name the topic of the recent messages together, not only of the last one.",
	"Reply with the title and nothing else.",
].join("\n");

export type TranscriptMessage = { readonly role: "user" | "assistant"; readonly text: string };

// The newest small model among the given ids, or undefined when there is none.
export function smallModelId(ids: readonly string[]): string | undefined {
	for (const fragment of SMALL_MODEL_ID_FRAGMENTS_BEST_FIRST) {
		const segment = new RegExp(`(^|[-/._])${fragment}($|[-/._])`);
		const newestFirst = ids
			.filter(id => segment.test(id) && !/preview|latest/.test(id))
			.sort((a, b) => b.localeCompare(a, "en", { numeric: true }) || a.length - b.length);
		const aliasesOfNewestSnapshot = newestFirst.filter(id => !/-\d{8}$/.test(id));
		const best = aliasesOfNewestSnapshot[0] ?? newestFirst[0];
		if (best !== undefined) return best;
	}
	return undefined;
}

export function describeMessage(text: string, images: number): string {
	if (images === 0) return text;
	const note = `(The message had ${images === 1 ? "an image" : `${images} images`}.)`;
	return text.trim() === "" ? note : `${text} ${note}`;
}

export function titlePrompt(transcript: readonly TranscriptMessage[]): string {
	const lines: string[] = [];
	let used = 0;
	for (let i = transcript.length - 1; i >= 0; i--) {
		const recent = transcript.length - i <= RECENT_MESSAGES_IN_FULL;
		const message = transcript[i]!;
		const text = oneLineCut(message.text, recent ? RECENT_MESSAGE_MAX_CHARS : OLDER_MESSAGE_MAX_CHARS);
		if (text === "") continue;
		const line = `${message.role === "user" ? "User" : "Assistant"}: ${text}`;
		if (used + line.length > TRANSCRIPT_MAX_CHARS && lines.length > 0) break;
		lines.push(line);
		used += line.length;
	}
	lines.reverse();
	return [
		`The conversation, oldest message first. The last ${RECENT_MESSAGES_IN_FULL} messages are in full, older ones are cut short.`,
		"<conversation>",
		...lines,
		"</conversation>",
		"",
		"Write the title.",
	].join("\n");
}

// The title in the model's answer, or undefined when the model answered the
// conversation instead of naming it.
export function cleanTitle(text: string): string | undefined {
	let line = text.split("\n").find(l => l.trim() !== "") ?? "";
	line = line.replace(/^\s*(#+\s*)?(\*\*)?\s*title\s*:\s*/i, "");
	line = line.replace(/[*_`]/g, "");
	line = line.trim().replace(/^["'“‘«]+|["'”’»]+$/g, "");
	line = line.replace(/[\s.,;:!?…-]+$/, "").replace(/\s+/g, " ").trim();
	if (line === "" || line.split(" ").length > MAX_WORDS_OF_A_TITLE) return undefined;
	return cutTitle(line);
}

function cutTitle(line: string): string {
	const chars = [...line];
	if (chars.length <= TITLE_LENGTH) return line;
	const cutAt = chars.slice(0, TITLE_LENGTH).join("");
	if (chars[TITLE_LENGTH] === " ") return cutAt;
	const space = cutAt.lastIndexOf(" ");
	return space > TITLE_LENGTH / 2 ? cutAt.slice(0, space) : cutAt;
}

function oneLineCut(text: string, limit: number): string {
	const line = text.replace(/\s+/g, " ").trim();
	const chars = [...line];
	return chars.length <= limit ? line : `${chars.slice(0, limit - 1).join("")}…`;
}
