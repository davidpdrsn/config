import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";

const statusKey = "footer-link";
const controls = /[\u0000-\u001f\u007f-\u009f]/;

type Link = { url: string; label: string };

function validateLink(url: string, label?: string): Link {
	if (controls.test(url) || (label !== undefined && controls.test(label))) {
		throw new Error("URL and label must not contain terminal control characters.");
	}
	const parsed = new URL(url);
	if (parsed.protocol !== "https:" && parsed.protocol !== "http:") {
		throw new Error("Only HTTP and HTTPS links are supported.");
	}
	if (label !== undefined && !label.trim()) throw new Error("Label must not be blank.");
	return { url: parsed.href, label: label ?? parsed.href };
}

export default function (pi: ExtensionAPI): void {
	function display(ctx: ExtensionContext, link: Link | null): void {
		if (!ctx.hasUI) return;
		ctx.ui.setStatus(statusKey, link
			? `\x1b]8;;${link.url}\x07${link.label}\x1b]8;;\x07`
			: undefined);
	}

	function restore(ctx: ExtensionContext): void {
		let link: Link | null = null;
		for (const entry of ctx.sessionManager.getBranch()) {
			if (entry.type !== "message" || entry.message.role !== "toolResult"
				|| entry.message.toolName !== "footer_link" || entry.message.isError) continue;
			const details = entry.message.details as { link?: Link | null } | undefined;
			if (details?.link === null) link = null;
			else if (typeof details?.link?.url === "string" && typeof details.link.label === "string") {
				try { link = validateLink(details.link.url, details.link.label); } catch { /* Ignore invalid saved links. */ }
			}
		}
		display(ctx, link);
	}

	pi.registerTool({
		name: "footer_link",
		// Restoration depends on top-level tool-result details in the session branch.
		exposure: "model-only",
		executionMode: "sequential",
		label: "Footer Link",
		description: "Set or clear a clickable HTTP(S) link in the Pi footer. Setting replaces the previous link. The link is restored with the session. Clicking requires terminal hyperlink support.",
		parameters: Type.Object({
			action: Type.String({ enum: ["set", "clear"] }),
			url: Type.Optional(Type.String({ description: "HTTP(S) URL, required for set." })),
			label: Type.Optional(Type.String({ description: "Display label, defaults to the URL." })),
		}),
		async execute(_id, params, _signal, _onUpdate, ctx) {
			if (params.action !== "set" && params.action !== "clear") throw new Error("Invalid action.");
			if (params.action === "set" && !params.url) throw new Error("URL is required for set.");
			const link = params.action === "set" ? validateLink(params.url!, params.label) : null;
			display(ctx, link);
			return {
				content: [{ type: "text", text: link ? `Footer link set: ${link.label} (${link.url})` : "Footer link cleared." }],
				details: { link },
			};
		},
	});

	pi.on("session_start", (_event, ctx) => restore(ctx));
	pi.on("session_tree", (_event, ctx) => restore(ctx));
}
