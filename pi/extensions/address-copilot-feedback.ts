import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

interface ParsedPullRequest {
	owner: string;
	repo: string;
	number: number;
	normalizedUrl: string;
}

function parseGitHubPullRequestUrl(raw: string): ParsedPullRequest | undefined {
	const value = raw.trim();
	if (!value) return undefined;

	let parsed: URL;
	try {
		parsed = new URL(value);
	} catch {
		return undefined;
	}

	if (parsed.protocol !== "https:" || parsed.hostname !== "github.com") return undefined;

	const path = parsed.pathname.replace(/\/+$/, "");
	const segments = path.split("/").filter(Boolean);
	if (segments.length < 4) return undefined;
	if (segments[2] !== "pull") return undefined;

	const owner = segments[0];
	const repo = segments[1];
	const number = Number.parseInt(segments[3] ?? "", 10);

	if (!owner || !repo || !Number.isInteger(number) || number <= 0) return undefined;

	return {
		owner,
		repo,
		number,
		normalizedUrl: `https://github.com/${owner}/${repo}/pull/${number}`,
	};
}

function extractGitHubPullRequestUrlFromText(raw: string): string | undefined {
	const match = raw.match(/https:\/\/github\.com\/[^\s)]+\/[^\s)]+\/pull\/\d+/i);
	if (!match) return undefined;
	return match[0].replace(/[.,;:!?]+$/, "");
}

function extractTextFromMessageContent(content: unknown): string {
	if (typeof content === "string") return content;
	if (!Array.isArray(content)) return "";

	const chunks: string[] = [];
	for (const part of content) {
		if (
			typeof part === "object" &&
			part !== null &&
			(part as { type?: unknown }).type === "text" &&
			typeof (part as { text?: unknown }).text === "string"
		) {
			chunks.push((part as { text: string }).text);
		}
	}

	return chunks.join("\n\n");
}

function extractPrUrlFromQuestionnaireDetails(details: unknown): string | undefined {
	if (!details || typeof details !== "object") return undefined;
	const answers = (details as { answers?: unknown }).answers;
	if (!Array.isArray(answers)) return undefined;

	for (const item of answers) {
		if (!item || typeof item !== "object") continue;
		const answer = (item as { answer?: unknown }).answer;
		if (typeof answer === "string") {
			const extracted = extractGitHubPullRequestUrlFromText(answer);
			if (extracted) return extracted;
		}
		if (Array.isArray(answer)) {
			for (const value of answer) {
				if (typeof value !== "string") continue;
				const extracted = extractGitHubPullRequestUrlFromText(value);
				if (extracted) return extracted;
			}
		}
	}

	return undefined;
}

function buildAgentPrompt(pr: ParsedPullRequest): string {
	return [
		`Please address Copilot feedback for this pull request: ${pr.normalizedUrl}`,
		"",
		"Use the gh CLI to fetch unresolved pull request review comments/threads, then focus on comments authored by Copilot.",
		"If needed, include likely Copilot author handles such as github-copilot[bot] and Copilot variants, and clearly state what you matched.",
		"",
		"For each unresolved Copilot comment, assess whether it is:",
		"1) Valuable (actionable, likely correct, or meaningful risk), or",
		"2) Overly paranoid / nitpicky (low-value concern, speculative, or style-only noise).",
		"",
		"Return:",
		"- A short summary with counts by category.",
		"- A per-comment breakdown with: file/line context, Copilot claim, your assessment, and a brief reason.",
		"- Concrete next actions for only the valuable comments.",
		"",
		"If you cannot fetch data (e.g. missing gh auth or API limits), explain exactly what failed and what command/auth is required.",
	].join("\n");
}

export default function (pi: ExtensionAPI): void {
	let waitingForPrUrl = false;
	let waitingSinceEntryCount: number | undefined;

	pi.on("input", async (event) => {
		if (!waitingForPrUrl) return { action: "continue" as const };
		const extractedUrl = extractGitHubPullRequestUrlFromText(event.text);
		const pr = extractedUrl ? parseGitHubPullRequestUrl(extractedUrl) : undefined;
		if (!pr) return { action: "continue" as const };

		waitingForPrUrl = false;
		waitingSinceEntryCount = undefined;
		return {
			action: "transform" as const,
			text: buildAgentPrompt(pr),
		};
	});

	pi.on("agent_end", async (_event, ctx) => {
		if (!waitingForPrUrl) return;

		const branch = ctx.sessionManager.getBranch();
		const start = Math.max(0, waitingSinceEntryCount ?? branch.length - 10);
		for (let i = branch.length - 1; i >= start; i--) {
			const entry = branch[i] as {
				type?: string;
				message?: {
					role?: string;
					toolName?: string;
					content?: unknown;
					details?: unknown;
				};
			};
			if (entry.type !== "message") continue;

			const role = entry.message?.role;
			if (role === "assistant") {
				const text = extractTextFromMessageContent(entry.message?.content);
				const extractedUrl = extractGitHubPullRequestUrlFromText(text);
				const pr = extractedUrl ? parseGitHubPullRequestUrl(extractedUrl) : undefined;
				if (!pr) continue;

				waitingForPrUrl = false;
				waitingSinceEntryCount = undefined;
				pi.sendUserMessage(buildAgentPrompt(pr));
				return;
			}

			if (role === "toolResult" && entry.message?.toolName === "questionnaire") {
				const extractedFromDetails = extractPrUrlFromQuestionnaireDetails(entry.message.details);
				const extractedFromContent = extractGitHubPullRequestUrlFromText(
					extractTextFromMessageContent(entry.message.content),
				);
				const extractedUrl = extractedFromDetails ?? extractedFromContent;
				const pr = extractedUrl ? parseGitHubPullRequestUrl(extractedUrl) : undefined;
				if (!pr) continue;

				waitingForPrUrl = false;
				waitingSinceEntryCount = undefined;
				pi.sendUserMessage(buildAgentPrompt(pr));
				return;
			}
		}
	});

	pi.registerCommand("address-copilot-feedback", {
		description:
			"Review unresolved Copilot PR feedback and classify which comments are valuable vs nitpicky/paranoid",
		handler: async (args, ctx) => {
			if (!ctx.isIdle()) {
				ctx.ui.notify("Agent is busy. Run this command again when the current turn finishes.", "warning");
				return;
			}

			if (!args.trim()) {
				waitingForPrUrl = true;
				waitingSinceEntryCount = ctx.sessionManager.getEntries().length;
				pi.sendUserMessage(
					"You should ask me for a GitHub pull request URL so you can run /address-copilot-feedback. Keep it brief and ask for a URL in the form https://github.com/<owner>/<repo>/pull/<number>.",
				);
				return;
			}

			const extractedUrl = extractGitHubPullRequestUrlFromText(args) ?? args;
			const pr = parseGitHubPullRequestUrl(extractedUrl);
			if (!pr) {
				ctx.ui.notify(
					"Usage: /address-copilot-feedback https://github.com/<owner>/<repo>/pull/<number>",
					"warning",
				);
				return;
			}

			waitingForPrUrl = false;
			waitingSinceEntryCount = undefined;
			pi.sendUserMessage(buildAgentPrompt(pr));
		},
	});
}
