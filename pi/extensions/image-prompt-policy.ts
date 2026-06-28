import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

export default function (pi: ExtensionAPI): void {
	pi.on("before_agent_start", async (event) => {
		return {
			systemPrompt:
				event.systemPrompt +
				"\n\n[Image prompt policy]\n- If the user's prompt contains one or more images, you MUST read and visually inspect the image(s) before answering.\n- Do not infer image contents from surrounding conversation context, filenames, or prior assumptions.\n- Look at the attached image(s) directly and base your response on what you observe.",
		};
	});
}
