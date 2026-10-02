import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function (pi: ExtensionAPI): void {
	pi.on("before_agent_start", async (event) => {
		return {
			systemPrompt:
				event.systemPrompt +
				"\n\n[Conversation-before-coding policy]\n- Before writing code, first discuss implementation options with the user.\n- Ask clarifying questions, explain tradeoffs, and align on an approach.\n- Only start coding once the user explicitly asks for code.\n- After presenting an implementation plan, if you need approval to proceed, call the questionnaire tool instead of ending the turn and waiting. Offer concrete next steps, such as 'Implement this plan', 'Discuss alternatives', and 'Stop here'.\n- Selecting an implementation option in the questionnaire counts as explicit permission to code. Cancellation does not.\n- Do not request approval again for an already-approved plan or add next-step questions to purely informational answers.",
		};
	});
}
