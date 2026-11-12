---
name: review-it
description: "Use when told to review your work with 'review it'"
---

1. Commit your work.
2. Note your tile: `but --json _ui state | jq -r .keys.tile` (yours has the keys while the user talks to you).
   Check it's your terminal in `but _ui state`; if the user is elsewhere, find yours by its title.
3. Write the reviewer's prompt to a file in your scratchpad:
   - review `<branch>` (`git log master..<branch>`); review only, no edits, commits or pushes;
   - read this session's transcript for the decisions made, and flag code that doesn't match them:
     `~/.claude/projects/<project>/<session-id>.jsonl` (the session id is in your scratchpad path);
   - real bugs, and refactoring opportunities: duplication, code the change made unnecessary,
     simpler shapes for what it added; no edge cases normal users never hit, no style nits;
   - when done, write the review to `<scratchpad>/review-<n>.md`, then send one line back, and Enter
     as a separate call a moment later (Claude Code takes a burst of input as a paste, where Enter
     is a newline, not a submit):
     `but _ui type --tile <your tile> --text 'Review done: read <scratchpad>/review-<n>.md' && sleep 1 && but _ui type --tile <your tile> --key enter`
     (one line: a newline in `--text` presses Enter early);
   - stay open afterwards.
4. Open the reviewer beside your tile, wherever the user is looking, and note its tile:
   `but _ui open --beside <your tile> --terminal --run 'claude "$(cat <prompt file>)"'`
5. When the review arrives, verify each finding against the code before acting; don't trust it blindly.
   A finding that changes or expands the scope (a new feature, a different design, work beyond the
   branch's goal) goes to the user to decide; don't act on it yourself.
6. Loop:
   - fix the findings that hold up and matter, refactors included when they simplify; skip edge
     cases, nits and speculation;
   - commit the fixes;
   - ask the same reviewer to review again, in one line, Enter sent separately as above: what you
     fixed (commit), what you skipped and why, and the next `review-<n>.md` to write;
   - repeat from 5.
   Stop when a round finds nothing that holds up and matters: a review always finds something.
   Tell the user what you fixed and skipped each round.
7. When the loop is done, close the reviewer: `but _ui close --tile <reviewer tile>`
