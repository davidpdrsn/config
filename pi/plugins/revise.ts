import { mkdir, readFile, writeFile } from "node:fs/promises";
import { join } from "node:path";
import { spawn } from "node:child_process";
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

function extractAssistantText(content: unknown): string {
	if (typeof content === "string") return content;
	if (!Array.isArray(content)) return "";

	const chunks: string[] = [];
	for (const part of content) {
		if (
			typeof part === "object" &&
			part !== null &&
			(part as { type?: unknown }).type === "text" &&
			typeof (part as { text?: unknown }).text === "string"
		) {
			chunks.push((part as { text: string }).text);
		}
	}

	return chunks.join("\n\n");
}

function getEditorBinary(command: string): string {
	const trimmed = command.trim();
	if (!trimmed) return "";
	if (trimmed.startsWith("\"") || trimmed.startsWith("'")) {
		const quote = trimmed[0];
		const end = trimmed.indexOf(quote, 1);
		if (end > 1) return trimmed.slice(1, end);
	}
	return trimmed.split(/\s+/)[0] ?? "";
}

function isTerminalEditorCommand(command: string): boolean {
	const bin = getEditorBinary(command).toLowerCase();
	return new Set(["vim", "nvim", "vi", "nano", "hx", "helix", "emacs", "kak", "less", "more"]).has(bin);
}

async function runEditorCommand(command: string): Promise<number> {
	return await new Promise((resolve) => {
		const child = spawn(command, {
			shell: true,
			stdio: "ignore",
		});

		child.on("close", (code) => resolve(code ?? 0));
		child.on("error", () => resolve(1));
	});
}

export default function (pi: ExtensionAPI): void {
	pi.registerCommand("revise", {
		description: "Open the latest assistant output in your external editor, then load edits as draft",
		handler: async (_args, ctx) => {
			if (!ctx.hasUI) return;

			const branch = ctx.sessionManager.getBranch();
			for (let i = branch.length - 1; i >= 0; i--) {
				const entry = branch[i] as {
					type?: string;
					message?: { role?: string; content?: unknown };
				};

				if (entry.type !== "message") continue;
				if (entry.message?.role !== "assistant") continue;

				const text = extractAssistantText(entry.message.content).trim();
				if (!text) continue;

				const dirPath = join(ctx.cwd, ".pi", "tmp");
				const filePath = join(dirPath, "revise-last-output.md");
				try {
					await mkdir(dirPath, { recursive: true });
					await writeFile(filePath, text, "utf8");
				} catch {
					ctx.ui.notify("Failed to prepare revise file. Loaded original text into draft.", "error");
					ctx.ui.setEditorText(text);
					return;
				}

				const editor = process.env.VISUAL || process.env.EDITOR;
				let exitCode = 1;

				if (editor) {
					if (isTerminalEditorCommand(editor)) {
						ctx.ui.setEditorText(text);
						ctx.ui.notify(
							"/revise can't safely launch terminal editors inside the Pi TUI. Loaded draft instead; press Ctrl+G, or set $EDITOR/$VISUAL to a GUI editor (e.g. 'code --wait').",
							"warning",
						);
						return;
					}
					exitCode = await runEditorCommand(`${editor} "${filePath.replace(/"/g, '\\"')}"`);
				} else if (process.platform === "darwin") {
					exitCode = await runEditorCommand(`open -W "${filePath.replace(/"/g, '\\"')}"`);
				} else {
					ctx.ui.notify("Set $VISUAL or $EDITOR to a GUI editor (for example: 'code --wait') to use /revise.", "error");
					ctx.ui.setEditorText(text);
					return;
				}

				if (exitCode !== 0) {
					ctx.ui.notify("External editor exited with an error.", "error");
					return;
				}

				try {
					const edited = await readFile(filePath, "utf8");
					ctx.ui.setEditorText(edited);
					ctx.ui.notify("Revised text loaded into draft. Press Enter to submit.", "info");
				} catch {
					ctx.ui.notify("Failed to read revised file. Loaded original text into draft.", "error");
					ctx.ui.setEditorText(text);
				}
				return;
			}

			ctx.ui.notify("No assistant output found to revise.", "warning");
		},
	});
}
