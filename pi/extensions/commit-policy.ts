import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

export default function (pi: ExtensionAPI): void {
	pi.on("before_agent_start", async (event) => {
		return {
			systemPrompt:
				event.systemPrompt +
				"\n\n[Commit policy]\n- Never create commits (in git or jj) unless the user explicitly asks you to commit.\n- If a request is ambiguous, do not commit.",
		};
	});
}
