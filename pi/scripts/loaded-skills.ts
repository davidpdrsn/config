import { basename, dirname, resolve } from "node:path";
import type { SessionEntry } from "@earendil-works/pi-coding-agent";

// `/skill:name` wraps the skill's instructions in this tag in the user message.
const skillTagPattern = /<skill name="([^"]+)" location="[^"]*">/g;

type ToolCall = { name: string; arguments: unknown };
type NestedCall = { name?: unknown; status?: unknown; arguments?: unknown };

function skillFilePath(call: ToolCall, cwd: string): string | undefined {
	if (call.name !== "read" || typeof call.arguments !== "object" || call.arguments === null) return undefined;
	const path = (call.arguments as { path?: unknown }).path;
	if (typeof path !== "string" || basename(path) !== "SKILL.md") return undefined;
	return resolve(cwd, path);
}

/**
 * Names of the skills in the model's context, in the order they were loaded.
 * A skill counts as loaded when the user ran `/skill:name` or the model read
 * its SKILL.md, either directly or through codemode.
 *
 * `entries` should be the compaction-aware context entries, so skills that
 * compaction summarized away drop out.
 *
 * `skillNames` maps absolute SKILL.md paths to skill names. Paths missing from
 * it use the name of the directory that holds SKILL.md.
 */
export function getLoadedSkills(entries: SessionEntry[], cwd: string, skillNames: Map<string, string>): string[] {
	const loaded = new Set<string>();
	const pendingReads = new Map<string, string>();
	const nameFor = (path: string) => skillNames.get(path) ?? basename(dirname(path));

	for (const entry of entries) {
		if (entry.type !== "message") continue;
		const message = entry.message;
		if (message.role === "user") {
			const content = typeof message.content === "string" ? [{ type: "text", text: message.content }] : message.content;
			for (const part of content) {
				if (part.type !== "text") continue;
				for (const match of (part as { text: string }).text.matchAll(skillTagPattern)) loaded.add(match[1]);
			}
		} else if (message.role === "assistant") {
			for (const part of message.content) {
				if (part.type !== "toolCall") continue;
				const path = skillFilePath(part, cwd);
				if (path) pendingReads.set(part.id, path);
			}
		} else if (message.role === "toolResult") {
			const path = pendingReads.get(message.toolCallId);
			if (path && !message.isError) loaded.add(nameFor(path));
			// Codemode records the tools its script called on its own result message.
			const nested = (message as { nestedCalls?: { calls?: NestedCall[] } }).nestedCalls?.calls ?? [];
			for (const call of nested) {
				if (call.status !== "ok" || typeof call.name !== "string") continue;
				const nestedPath = skillFilePath({ name: call.name, arguments: call.arguments }, cwd);
				if (nestedPath) loaded.add(nameFor(nestedPath));
			}
		}
	}
	return [...loaded];
}
