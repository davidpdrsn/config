import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

/**
 * JJ Checkpoint Extension
 *
 * On each normal user prompt (interactive mode + inside a jj repo):
 * - If current change (@) has no description: `jj describe -m "ai: <PROMPT>"`
 * - Otherwise: `jj new -m "ai: <PROMPT>"`
 *
 * Workspace guard:
 * - Skip checkpoint commits when current workspace is not `default`
 *
 * Heuristics:
 * - Skip slash commands
 * - Skip single-word prompts
 *
 * The full prompt text is preserved in the jj description.
 * Best-effort only: failures never block prompt submission.
 */
export default function (pi: ExtensionAPI): void {
	pi.on("input", async (event, ctx) => {
		// Only run in interactive/RPC contexts with UI.
		if (!ctx.hasUI) return { action: "continue" };

		// Ignore extension-originated messages.
		if (event.source === "extension") return { action: "continue" };

		const rawPrompt = event.text;
		const prompt = rawPrompt.trim();
		if (!prompt) return { action: "continue" };
		if (prompt.startsWith("/")) return { action: "continue" };

		// Skip single-word prompts like "ok", "thanks", etc.
		if (prompt.split(/\s+/).length <= 1) return { action: "continue" };

		try {
			// Only run in a jj repo.
			const root = await pi.exec("jj", ["root"], { timeout: 1_000 });
			if (root.code !== 0) return { action: "continue" };

			// Skip non-default workspaces.
			const workspaceName = await pi.exec(
				"jj",
				[
					"workspace",
					"list",
					"-T",
					"if(self.target().current_working_copy(), self.name() ++ \"\\n\", \"\")",
				],
				{ timeout: 1_000 },
			);
			if (workspaceName.code !== 0) return { action: "continue" };
			if ((workspaceName.stdout ?? "").trim() !== "default") {
				return { action: "continue" };
			}

			const message = `ai: ${rawPrompt}`;

			// Check whether current change has a description.
			const state = await pi.exec(
				"jj",
				["log", "-r", "@", "--no-graph", "-T", "if(description,\"nonempty\",\"empty\")"],
				{ timeout: 1_000 },
			);
			const isCurrentDescriptionEmpty = (state.stdout ?? "").trim() === "empty";

			const cmd = isCurrentDescriptionEmpty ? ["describe", "-m", message] : ["new", "-m", message];
			await pi.exec("jj", cmd, { timeout: 5_000 });
		} catch {
			// Silent failure by design.
		}

		return { action: "continue" };
	});
}
