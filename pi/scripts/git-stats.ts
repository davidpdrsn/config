import { execFile } from "node:child_process";
import { lstat, readFile, readlink } from "node:fs/promises";
import { join } from "node:path";
import { promisify } from "node:util";

const exec = promisify(execFile);

export type GitStats = { added: number; removed: number };

export function parseNumstat(output: string): GitStats {
	const stats = { added: 0, removed: 0 };
	// --no-renames ensures each NUL-delimited record has exactly one path.
	for (const record of output.split("\0")) {
		const match = /^(\d+)\t(\d+)\t/.exec(record);
		if (!match) continue; // Binary files have '-' counts.
		stats.added += Number(match[1]);
		stats.removed += Number(match[2]);
	}
	return stats;
}

export async function getGitStats(cwd: string): Promise<GitStats | undefined> {
	const git = async (args: string[], directory = cwd) =>
		(await exec("git", ["-C", directory, ...args], { timeout: 5000, maxBuffer: 16 * 1024 * 1024 })).stdout;
	try {
		const root = (await git(["rev-parse", "--show-toplevel"])).replace(/\r?\n$/, "");
		let hasHead = true;
		try {
			await git(["rev-parse", "--verify", "HEAD"], root);
		} catch {
			hasHead = false;
		}
		const stats = hasHead
			? parseNumstat(await git(["diff", "--numstat", "-z", "--no-renames", "--no-ext-diff", "--no-textconv", "HEAD", "--"], root))
			: { added: 0, removed: 0 };
		const files = await git(["ls-files", "-z", "--others", "--exclude-standard", ...(hasHead ? [] : ["--cached"])], root);
		for (const file of new Set(files.split("\0").filter(Boolean))) {
			try {
				const path = join(root, file);
				const info = await lstat(path);
				if (info.isSymbolicLink()) {
					stats.added += (await readlink(path)).split("\n").length;
					continue;
				}
				if (!info.isFile()) continue;
				const content = await readFile(path);
				if (content.subarray(0, 8000).includes(0)) continue;
				for (const byte of content) if (byte === 10) stats.added++;
				if (content.length > 0 && content[content.length - 1] !== 10) stats.added++;
			} catch (error) {
				// Files can disappear while a tool or editor is changing them.
				if ((error as NodeJS.ErrnoException).code !== "ENOENT") throw error;
			}
		}
		return stats;
	} catch {
		return undefined; // Not a repository, unavailable Git, or failed refresh.
	}
}
