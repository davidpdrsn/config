import { existsSync } from "fs"
import { join } from "path"
import type { Plugin } from "@opencode-ai/plugin"

export const MyPlugin: Plugin = async ({ directory }) => {
    if (!existsSync(join(directory, ".jj"))) {
        return {}
    }

    // Match `git` only when it looks like an executable command, not a flag
    // like `--git` or a JSON key like `"git": true`.
    const gitCommand = /\bgit(\.exe)?\b/gi
    const separator = /[\s;|&()]/
    const commandToken = /[A-Za-z0-9_.-]/
    const containsGit = (value: unknown) => {
        const text = typeof value === "string" ? value : JSON.stringify(value)

        for (const match of text.matchAll(gitCommand)) {
            const index = match.index ?? -1
            if (index < 0) {
                continue
            }

            const prevChar = index === 0 ? "" : text[index - 1]
            if (index > 0 && !separator.test(prevChar)) {
                continue
            }

            let cursor = index - 1
            while (cursor >= 0 && /\s/.test(text[cursor])) {
                cursor -= 1
            }

            const tokenEnd = cursor
            while (cursor >= 0 && commandToken.test(text[cursor])) {
                cursor -= 1
            }

            const previousToken = text.slice(cursor + 1, tokenEnd + 1).toLowerCase()
            if (previousToken === "jj") {
                continue
            }

            return true
        }

        return false
    }

    const msg = "Policy violation: `git` commands are disabled in this environment, use `jj` instead.";

    return {
        "permission.ask": async (input, output) => {
            const pattern = Array.isArray(input.pattern)
                ? input.pattern.join(" ")
                : (input.pattern ?? "")
            const metadata = JSON.stringify(input.metadata ?? {})
            const haystack = `${input.type} ${input.title} ${pattern} ${metadata}`

            if (containsGit(haystack)) {
                output.status = "deny"
            }
        },

        "tool.execute.before": async (input, output) => {
            if (input.tool !== "bash") {
                return
            }

            if (containsGit(output.args)) {
                throw new Error(msg)
            }
        },

        "command.execute.before": async (input, output) => {
            const commandText = `${input.command} ${input.arguments}`.trim()
            if (containsGit(commandText)) {
                output.parts = [
                    {
                        type: "text",
                        text: msg
                    } as never
                ]
            }
        }
    }
}
