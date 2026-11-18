import { homedir } from "node:os";
import { basename, dirname, resolve } from "node:path";
import type { SessionEntry } from "@earendil-works/pi-coding-agent";

// `/skill:name` wraps the skill's instructions in this tag in the user message.
const skillTagPattern = /<skill name="([^"]+)" location="[^"]*">/g;
// A SKILL.md path inside a shell command, ending at whitespace, a quote or an operator.
const shellSkillPathPattern = /[^\s'"`;|&<>()]*SKILL\.md/g;
// Commands that print the files they're given, as opposed to cp, grep or git diff.
const printCommands = new Set(["cat", "head", "tail", "sed", "awk", "nl", "bat", "less", "more"]);

type ToolCall = { name: string; arguments: unknown };
type NestedCall = { name?: unknown; status?: unknown; arguments?: unknown };

function argument(call: ToolCall, key: string): unknown {
	if (typeof call.arguments !== "object" || call.arguments === null) return undefined;
	return (call.arguments as Record<string, unknown>)[key];
}

/**
 * Known skill paths that a shell command prints. Each simple command counts
 * when it starts with a command from `printCommands`, so `cp` or `grep -v` on
 * a skill, or a path to some other SKILL.md, doesn't count.
 */
function printedSkillPaths(command: string, cwd: string, skillNames: Map<string, string>): string[] {
	return command
		.split(/&&|\|\||[;|\n]/)
		.filter((segment) => printCommands.has(segment.trim().split(/\s+/)[0]))
		.flatMap((segment) => [...segment.matchAll(shellSkillPathPattern)])
		.map(([path]) => resolve(cwd, path.replace(/^(~|\$HOME|\$\{HOME\})(?=\/)/, homedir())))
		.filter((path) => skillNames.has(path));
}

/** Absolute paths of the SKILL.md files a tool call reads. A read of any SKILL.md counts. */
function skillFilePaths(call: ToolCall, cwd: string, skillNames: Map<string, string>): string[] {
	if (call.name === "read") {
		const path = argument(call, "path");
		return typeof path === "string" && basename(path) === "SKILL.md" ? [resolve(cwd, path)] : [];
	}
	if (call.name === "bash") {
		const command = argument(call, "command");
		return typeof command === "string" ? printedSkillPaths(command, cwd, skillNames) : [];
	}
	return [];
}

/**
 * Names of the skills in the model's context, in the order they were loaded.
 * A skill counts as loaded when the user ran `/skill:name` or the model read
 * its SKILL.md with the read tool or a bash command, either directly or
 * through codemode.
 *
 * `entries` should be the compaction-aware context entries, so skills that
 * compaction summarized away drop out.
 *
 * `skillNames` maps absolute SKILL.md paths to skill names. Paths missing from
 * it use the name of the directory that holds SKILL.md.
 */
export function getLoadedSkills(entries: SessionEntry[], cwd: string, skillNames: Map<string, string>): string[] {
	const loaded = new Set<string>();
	const pendingReads = new Map<string, string[]>();
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
				const paths = skillFilePaths(part, cwd, skillNames);
				if (paths.length) pendingReads.set(part.id, paths);
			}
		} else if (message.role === "toolResult") {
			if (!message.isError) for (const path of pendingReads.get(message.toolCallId) ?? []) loaded.add(nameFor(path));
			// Codemode records the tools its script called on its own result message.
			const nested = (message as { nestedCalls?: { calls?: NestedCall[] } }).nestedCalls?.calls ?? [];
			for (const call of nested) {
				if (call.status !== "ok" || typeof call.name !== "string") continue;
				for (const path of skillFilePaths({ name: call.name, arguments: call.arguments }, cwd, skillNames)) loaded.add(nameFor(path));
			}
		}
	}
	return [...loaded];
}
