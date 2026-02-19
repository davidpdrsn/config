import { existsSync, mkdirSync } from "fs"
import { homedir } from "os"
import { join, resolve } from "path"
import type { Plugin } from "@opencode-ai/plugin"

export const MyPlugin: Plugin = async ({ $, directory }) => {
    const jjWorkspacesRoot = resolve(homedir(), "code", "jj-workspaces")

    if (!existsSync(jjWorkspacesRoot)) {
        mkdirSync(jjWorkspacesRoot, { recursive: true })
    }

    const currentDir = resolve(directory)

    if (currentDir === jjWorkspacesRoot || currentDir.startsWith(`${jjWorkspacesRoot}/`)) {
        return {}
    }

    // Skip if not a jj repo
    if (!existsSync(join(directory, ".jj"))) {
        return {}
    }

    // Track user messages: id -> agent name
    const userMessages = new Map<string, string>()

    async function changeIsEmpty(): Promise<boolean> {
        const description = await $`jj show --no-patch -T description`.cwd(directory).text()
        const empty = await $`jj show --no-patch -T empty`.cwd(directory).text()
        return description.trim() === "" && empty.trim() === "true"
    }

    return {
        event: async ({ event }) => {
            // Track user messages
            if (event.type === "message.updated" && event.properties.info.role === "user") {
                const info = event.properties.info
                userMessages.set(info.id, info.agent)
            }

            // Handle prompt submission
            if (event.type === "message.part.updated") {
                const part = event.properties.part
                if (part.type === "text" && userMessages.has(part.messageID)) {
                    const agent = userMessages.get(part.messageID)
                    userMessages.delete(part.messageID)

                    // Skip subagent prompts (only process main agents)
                    if (agent !== "build" && agent !== "plan") {
                        return
                    }

                    const prompt = part.text

                    // Skip commit message generation prompts
                    if (prompt.includes("Generate a commit message for the following diff")) {
                        return
                    }

                    if (prompt.includes("go")) {
                        return
                    }

                    const message = `ai: ${prompt}`

                    try {
                        if (await changeIsEmpty()) {
                            await $`jj describe -m ${message}`.cwd(directory).quiet()
                        } else {
                            await $`jj new -m ${message}`.cwd(directory).quiet()
                        }
                    } catch {
                        // jj error, ignore
                    }
                }
            }
        }
    }
}
