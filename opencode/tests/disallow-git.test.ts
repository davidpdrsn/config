import { mkdtempSync, mkdirSync, rmSync } from "fs"
import { tmpdir } from "os"
import { join } from "path"
import { afterEach, describe, expect, test } from "bun:test"

import { MyPlugin } from "../plugins/disallow-git"

const tempDirs: string[] = []

const createRepo = (withJj = true) => {
    const dir = mkdtempSync(join(tmpdir(), "disallow-git-"))
    tempDirs.push(dir)
    if (withJj) {
        mkdirSync(join(dir, ".jj"))
    }
    return dir
}

afterEach(() => {
    for (const dir of tempDirs.splice(0, tempDirs.length)) {
        rmSync(dir, { recursive: true, force: true })
    }
})

describe("disallow-git plugin", () => {
    test("returns no hooks outside jj repos", async () => {
        const hooks = await MyPlugin({ directory: createRepo(false) } as never)
        expect(hooks).toEqual({})
    })

    test("permission.ask denies git commands", async () => {
        const hooks = await MyPlugin({ directory: createRepo() } as never)
        const ask = hooks["permission.ask"]
        expect(ask).toBeDefined()

        const cases = [
            "git status",
            "echo hi && git log",
            "(git commit -m test)",
            "Git status",
            "git.exe status"
        ]

        for (const message of cases) {
            const output: { status: "ask" | "deny" | "allow" } = { status: "ask" }
            await ask!(
                {
                    type: "tool.execute",
                    title: message,
                    pattern: "",
                    metadata: {}
                } as never,
                output
            )
            expect(output.status).toBe("deny")
        }
    })

    test("permission.ask ignores non-command git-like text", async () => {
        const hooks = await MyPlugin({ directory: createRepo() } as never)
        const ask = hooks["permission.ask"]
        expect(ask).toBeDefined()

        const cases = [
            "use --git flag",
            "json key \"git\": true",
            "legit",
            "gitlab"
        ]

        for (const message of cases) {
            const output: { status: "ask" | "deny" | "allow" } = { status: "ask" }
            await ask!(
                {
                    type: "tool.execute",
                    title: message,
                    pattern: "",
                    metadata: {}
                } as never,
                output
            )
            expect(output.status).toBe("ask")
        }
    })

    test("tool.execute.before only blocks bash with git command text", async () => {
        const hooks = await MyPlugin({ directory: createRepo() } as never)
        const before = hooks["tool.execute.before"]
        expect(before).toBeDefined()

        await before!(
            {
                tool: "bash",
                sessionID: "s",
                callID: "c"
            },
            { args: "jj git push --bookmark dp/jj-lpmqtxmyskuz" }
        )

        let denied = false
        try {
            await before!(
                {
                    tool: "bash",
                    sessionID: "s",
                    callID: "c"
                },
                { args: "echo hi; git status" }
            )
        } catch (error) {
            denied = true
            expect((error as Error).message).toContain("git")
        }
        expect(denied).toBeTrue()

        await before!(
            {
                tool: "read",
                sessionID: "s",
                callID: "c"
            },
            { args: "git status" }
        )
    })

    test("command.execute.before writes denial text", async () => {
        const hooks = await MyPlugin({ directory: createRepo() } as never)
        const before = hooks["command.execute.before"]
        expect(before).toBeDefined()

        const denied = { parts: [] as Array<{ type: string; text: string }> }
        await before!(
            {
                command: "shell",
                arguments: "git status",
                sessionID: "s"
            },
            denied as never
        )
        expect(denied.parts).toHaveLength(1)
        expect(denied.parts[0]?.text).toContain("use `jj` instead")

        const allowed = { parts: [] as Array<{ type: string; text: string }> }
        await before!(
            {
                command: "shell",
                arguments: "echo --git",
                sessionID: "s"
            },
            allowed as never
        )
        expect(allowed.parts).toEqual([])
    })
})
