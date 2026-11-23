// Reads the Claude subscription limits through the endpoint that Claude Code's
// `/usage` command uses. The endpoint is undocumented and only accepts OAuth tokens.

export type UsageWindow = { label: string; percent: number };

type UsageResponse = Record<string, { utilization?: number } | null | undefined>;

// Response fields, in display order, and the labels shown for them.
const windows = [
	["five_hour", "5h"],
	["seven_day", "week"],
] as const;

export function parseUsage(response: UsageResponse): UsageWindow[] {
	return windows.flatMap(([field, label]) => {
		const percent = response[field]?.utilization;
		return typeof percent === "number" ? [{ label, percent }] : [];
	});
}

export async function fetchUsage(accessToken: string): Promise<UsageWindow[] | undefined> {
	try {
		const response = await fetch("https://api.anthropic.com/api/oauth/usage", {
			headers: { Authorization: `Bearer ${accessToken}`, "anthropic-beta": "oauth-2025-04-20" },
			signal: AbortSignal.timeout(10_000),
		});
		if (!response.ok) return undefined;
		return parseUsage((await response.json()) as UsageResponse);
	} catch {
		return undefined;
	}
}
