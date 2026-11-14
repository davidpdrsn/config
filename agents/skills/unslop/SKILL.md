---
name: unslop
description: Cut AI tells from any writing.
disable-model-invocation: true
---

# Unslop

Edit text to remove AI patterns. The patterns are the numbered rules under "Writing" in your global instructions (`~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md` or `~/.pi/agent/AGENTS.md`, all symlinks to `~/config/agents/AGENTS.md`). Scan the text for each rule, then rewrite. Preserve meaning and match the intended tone.
