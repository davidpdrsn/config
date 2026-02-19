import { constants } from "fs"
import { lstat, mkdir, open, unlink } from "fs/promises"
import { homedir } from "os"
import { basename, join } from "path"
import type { Plugin } from "@opencode-ai/plugin"

export const MyPlugin: Plugin = async ({ $, directory }) => {
    // FIFO location per workspace so consumers can tail events per project.
    const pipesDir = join(homedir(), ".config", "opencode", "pipes")
    const pipePath = join(pipesDir, basename(directory))

    await mkdir(pipesDir, { recursive: true })

    // Ensure a FIFO exists at the target path, recreating if a file is present.
    const ensurePipe = async () => {
        try {
            const stats = await lstat(pipePath)
            if (stats.isFIFO()) {
                return
            }
            await unlink(pipePath)
        } catch (error) {
            if ((error as NodeJS.ErrnoException).code !== "ENOENT") {
                throw error
            }
        }

        try {
            await $`mkfifo ${pipePath}`.quiet()
        } catch (error) {
            // Ignore fifo creation failures
            void error
        }
    }

    await ensurePipe()

    // Buffer events so temporary writer errors do not drop data.
    const buffer: string[] = []
    let flushing = false
    let retryTimer: NodeJS.Timeout | null = null

    // Coalesce retries so rapid failures don't spin the event loop.
    const scheduleRetry = () => {
        if (retryTimer) {
            return
        }
        retryTimer = setTimeout(() => {
            retryTimer = null
            void flushBuffer()
        }, 250)
    }

    // Attempt to drain the buffer into the FIFO, retrying on transient errors.
    const flushBuffer = async () => {
        // Skip if another flush is in progress or there is nothing to send.
        if (flushing || buffer.length === 0) {
            return
        }

        flushing = true
        const lines = buffer.splice(0, buffer.length)

        try {
            // Non-blocking open avoids hanging when no reader is attached.
            const handle = await open(pipePath, constants.O_WRONLY | constants.O_NONBLOCK)
            let index = 0
            try {
                for (; index < lines.length; index += 1) {
                    await handle.write(lines[index])
                }
            } catch (error) {
                const code = (error as NodeJS.ErrnoException).code
                buffer.unshift(...lines.slice(index))
                // EPIPE/EAGAIN indicates the reader disappeared or is slow.
                if (code === "EPIPE" || code === "EAGAIN") {
                    scheduleRetry()
                    return
                }
                throw error
            } finally {
                await handle.close()
            }
        } catch (error) {
            const code = (error as NodeJS.ErrnoException).code
            buffer.unshift(...lines)
            // ENXIO: no reader yet. ENOENT: pipe missing (recreate).
            if (code === "ENXIO" || code === "ENOENT") {
                if (code === "ENOENT") {
                    try {
                        await ensurePipe()
                    } catch (ensureError) {
                        // Ignore fifo creation failures
                        void ensureError
                    }
                }
                scheduleRetry()
                return
            }
            throw error
        } finally {
            flushing = false
        }
    }

    return {
        event: async ({ event }) => {
            try {
                // Add a newline so consumers can read line-delimited JSON.
                buffer.push(`${JSON.stringify(event)}\n`)
                await flushBuffer()
            } catch (error) {
                // Ignore logging failures
                void error
            }
        }
    }
}
