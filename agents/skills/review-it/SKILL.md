---
name: review-it
description: "Use when told to review your work with 'review it'"
---

Run a review loop with a second pi agent, the reviewer, in a GitButler tile beside yours.

1. Commit your work.
2. Find your tile. `but --json _ui state | jq -r .keys.tile` prints the tile that has the keys, which is yours while the user talks to you. Check in `but _ui state` that it's your terminal. If the user is in another tile, find yours by its title.
3. Make a scratch directory with `mktemp -d` and write the reviewer's prompt to a file in it. The prompt tells the reviewer to:
   - Review `<branch>` (`git log master..<branch>`) with the code-review skill. Review only, with no edits, commits or pushes.
   - Read this session's transcript for the decisions made, and flag code that doesn't match them. Write the path from `$PI_SESSION_FILE` into the prompt. The reviewer has its own session, so the variable won't point to yours.
   - When done, write the review to `<scratch dir>/review-<n>.md` and tell you with the command in "Sending a message". Write the command into the prompt with your tile and the review path filled in.
   - Stay open afterwards.
4. Open the reviewer beside your tile and note the tile it prints:
   `but _ui open --beside <your tile> --terminal --run 'pi "$(cat <prompt file>)"'`
5. When the review arrives, check each finding against the code before acting on it. A finding that changes or expands the scope, such as a new feature, a different design or work beyond the branch's goal, goes to the user to decide. Don't act on it yourself.
6. Loop:
   - Fix the findings that hold up and matter, including refactors that simplify the code. Skip edge cases, nits and speculation.
   - Commit the fixes.
   - Send the reviewer one message with what you fixed and in which commit, what you skipped and why, and the next `review-<n>.md` to write.
   - Repeat from step 5.

   A review always finds something, so stop when a round finds nothing that holds up and matters. Tell the user what you fixed and skipped in each round.
7. When the loop is done, close the reviewer with `but _ui close --tile <reviewer tile>`.

## Sending a message

Type the text and press Enter in two separate calls, a second apart. A terminal app can take a burst of input as a paste, and then Enter adds a newline instead of submitting.

```bash
but _ui type --tile <tile> --text '<message>' && sleep 1 && but _ui type --tile <tile> --key enter
```

Keep the message on one line. A newline in `--text` presses Enter early.
