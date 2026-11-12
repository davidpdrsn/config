---
name: review-it
description: "Use when told to review your work with 'review it'"
---

1. Commit your work.
2. Note your tile: `but --json _ui state | jq -r .keys.tile` (yours has the keys while the user talks to you).
3. Write the reviewer's prompt to a file in your scratchpad:
   - review `<branch>` (`git log master..<branch>`); review only, no edits, commits or pushes;
   - read this session's transcript for the decisions made, and flag code that doesn't match them:
     `~/.claude/projects/<project>/<session-id>.jsonl` (the session id is in your scratchpad path);
   - real bugs only, no edge cases normal users never hit, no style nits;
   - when done, write the review to `<scratchpad>/review.md`, then send one line back, and Enter
     as a separate call a moment later (Claude Code takes a burst of input as a paste, where Enter
     is a newline, not a submit):
     `but _ui type --tile <your tile> --text 'Review done: read <scratchpad>/review.md' && sleep 1 && but _ui type --tile <your tile> --key enter`
     (one line: a newline in `--text` presses Enter early);
   - stay open afterwards.
4. Open the reviewer beside your tile, wherever the user is looking:
   `but _ui open --beside <your tile> --terminal --run 'claude "$(cat <prompt file>)"'`
5. When the review arrives, verify each finding against the code before acting; don't trust it blindly.
