import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function (pi: ExtensionAPI): void {
	pi.on("before_agent_start", async (event) => {
		return {
			systemPrompt:
				event.systemPrompt +
				"\n\n[Punctuation policy]\n- Never use em dashes. Use commas, parentheses, colons, semicolons, or separate sentences instead.",
		};
	});
}
