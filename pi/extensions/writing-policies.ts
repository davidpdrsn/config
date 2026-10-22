import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function (pi: ExtensionAPI): void {
	pi.on("before_agent_start", async (event) => {
		return {
			systemPrompt:
				event.systemPrompt +
                "\n\n" + [
                    "Never use em dashes. Use commas, parentheses, colons, semicolons, or separate sentences instead.",
                    "Never say things like \"Agreed.\". If you agree with what I'm saying, do not say that. Only say if you disagree.",
                    "Dont tell me things you didn't do. If you didn't run the tests, don't tell me. If you didn't do X, don't tell me you didn't do X",
                    "Speak plainly. Use fewer and simpler words. AI agents have a tendency to use way way to many words. Dont do this. Speak plainly and simply.",
                ].join("\n"),
		};
	});
}
