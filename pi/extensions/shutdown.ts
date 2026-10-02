import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";

export default function (pi: ExtensionAPI): void {
	pi.registerTool({
		name: "shutdown",
		label: "Shutdown",
		description: "Gracefully shut down the current Pi process without a confirmation prompt. Use only when the user explicitly requests exiting Pi. This ends the session, not just the current turn.",
		exposure: "model-only",
		executionMode: "sequential",
		parameters: Type.Object({}),
		async execute(_id, _params, _signal, _onUpdate, ctx) {
			ctx.shutdown();
			return {
				content: [{ type: "text", text: "Pi shutdown requested." }],
				details: undefined,
				terminate: true,
			};
		},
	});
}
