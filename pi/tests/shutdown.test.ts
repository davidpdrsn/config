import { describe, expect, mock, test } from "bun:test";
import type { ExtensionAPI, ExtensionContext, ToolDefinition } from "@earendil-works/pi-coding-agent";
import extension from "../extensions/shutdown";

function setup() {
	let tool: ToolDefinition | undefined;
	extension({
		registerTool: (value: ToolDefinition) => { tool = value; },
	} as ExtensionAPI);
	return tool!;
}

describe("shutdown", () => {
	test("registers a dedicated sequential, model-only tool", () => {
		const tool = setup();
		expect(tool.name).toBe("shutdown");
		expect(tool.exposure).toBe("model-only");
		expect(tool.executionMode).toBe("sequential");
		expect(tool.parameters.properties).toEqual({});
	});

	test("requests graceful shutdown without a UI and suppresses follow-up", async () => {
		const tool = setup();
		const shutdown = mock(() => {});
		const ctx = { shutdown, hasUI: false } as unknown as ExtensionContext;
		const result = await tool.execute("id", {}, undefined, undefined, ctx);
		expect(shutdown).toHaveBeenCalledTimes(1);
		expect(result.content).toEqual([{ type: "text", text: "Pi shutdown requested." }]);
		expect(result.terminate).toBe(true);
	});

	test("propagates shutdown failures", async () => {
		const tool = setup();
		const ctx = {
			shutdown: () => { throw new Error("Shutdown failed"); },
		} as unknown as ExtensionContext;
		await expect(tool.execute("id", {}, undefined, undefined, ctx)).rejects.toThrow("Shutdown failed");
	});
});
