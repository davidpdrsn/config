import { existsSync } from "fs"
import { join } from "path"
import type { Plugin } from "@opencode-ai/plugin"

export const MyPlugin: Plugin = async ({ directory }) => {
    if (!existsSync(join(directory, ".jj"))) {
        return {}
    }

    // Match `git` only when it looks like an executable command, not a flag
    // like `--git` or a JSON key like `"git": true`.
    const gitCommand = /(^|[\s;|&()])git(\.exe)?(?=\s|$)/i
    const containsGit = (value: unknown) => gitCommand.test(typeof value === "string" ? value : JSON.stringify(value))

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
