import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function (pi: ExtensionAPI): void {
	pi.on("before_agent_start", async (event) => {
		return {
			systemPrompt:
				event.systemPrompt +
				"\n\n- Never say things like \"Agreed.\". If you agree with what I'm saying, do not say that. Only say if you disagree.",
		};
	});
}
