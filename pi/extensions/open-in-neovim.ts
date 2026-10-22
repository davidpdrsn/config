import { resolve } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";

export default function (pi: ExtensionAPI): void {
	pi.registerTool({
		name: "open_in_neovim",
		label: "Open in Neovim",
		description: "Open a file at an optional line in the user's running Neovim instance. When the user says 'take me there' or 'show me', use this tool to open the file and line being discussed. Also use it when asked to open or jump to code in Neovim.",
		executionMode: "sequential",
		parameters: Type.Object({
			path: Type.String({ minLength: 1, description: "Absolute file path or path relative to Pi's working directory." }),
			line: Type.Optional(Type.Integer({ minimum: 1, description: "1-based line number." })),
		}),
		async execute(_id, params, signal, _onUpdate, ctx) {
			if (!params.path.trim() || params.path.includes("\0")) throw new Error("A non-empty file path without null bytes is required.");
			if (params.line !== undefined && (!Number.isSafeInteger(params.line) || params.line < 1)) {
				throw new Error("Line must be a positive integer.");
			}
			const path = resolve(ctx.cwd, params.path);
			const args = params.line === undefined ? [path] : ["--line", String(params.line), path];
			const result = await pi.exec("gitbutler-nvim-remote", args, { cwd: ctx.cwd, signal, timeout: 5_000 });
			if (result.killed || result.code !== 0) {
				throw new Error(`Could not open file in Neovim: ${result.stderr.trim() || (result.killed ? "command cancelled or timed out" : `command exited with code ${result.code}`)}`);
			}
			return {
				content: [{ type: "text", text: `Opened ${path}${params.line === undefined ? "" : `:${params.line}`} in Neovim.` }],
				details: { path, line: params.line },
			};
		},
	});
}
