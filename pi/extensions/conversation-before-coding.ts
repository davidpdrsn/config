import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

export default function (pi: ExtensionAPI): void {
	pi.on("before_agent_start", async (event) => {
		return {
			systemPrompt:
				event.systemPrompt +
				"\n\n[Conversation-before-coding policy]\n- Before writing code, first discuss implementation options with the user.\n- Ask clarifying questions, explain tradeoffs, and align on an approach.\n- Only start coding once the user explicitly asks for code.",
		};
	});
}
