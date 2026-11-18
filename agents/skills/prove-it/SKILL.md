---
name: prove-it
description: Send the user proof or suggestions through their Prove It inbox and wait for their answer. Use it to prove a bug exists before fixing it, to prove a fix or feature works, and to send suggestions (designs, names, approaches) for the user to pick from.
---

# Prove It

Prove It is where you show the user proof instead of telling them. Saying "it's broken" or "it works" isn't enough. Send something the user can check: a screenshot, a screen recording, the rendered SVG, failing or passing test output, the relevant code.

It is also where you show the user suggestions when there is more than one reasonable way to do something. The user picks one or rejects them all.

`prove-it` puts proofs and suggestions in the user's review inbox. The inbox is a macOS app where the user goes through each review, comments on each item, and approves, chooses or rejects. You get their answer back as JSON.

## Fixing a bug

Bug fixes take two reviews. Don't skip the first one.

1. Reproduce the bug and send proof that it exists. Show the wrong behavior itself: a screenshot or recording of it happening, a failing test, an error log. Use `--message` to say what you expected, what happened instead, and what you think the cause is.
2. Wait for the review. Don't change any code until the user approves it.
   - `approved` means you found the right bug. Go ahead and fix it.
   - `changes_requested` means the user wants something different, for example another reproduction or a different bug. Follow the comments and send new proof of the bug.
   - `rejected` means stop and ask the user how to proceed.
3. Fix the bug, then send proof of the fix. Reproduce it the same way as in step 1 so the user can compare. Include the before proof again if that helps.
4. Wait for the review. The bug is fixed when the user approves it.

If you can't reproduce the bug, don't guess at a fix. Send what you tried and what you saw, and ask the user for help in the message.

If there are several reasonable ways to fix the bug, send them as suggestions after the user approves the bug, and fix it the way the user chooses.

## Building a feature

New features take one review. Build the feature, then send proof that it works, for example a screenshot or recording of the running app or the output of the tests that cover it. Wait for the review before calling the task done.

## Offering suggestions

When there is more than one reasonable option, such as two layouts, three names for a command, or two ways to structure a fix, don't pick one yourself. Send them all with `prove-it suggest` and let the user choose.

1. Make each suggestion one file or one `--text`. Each must stand on its own, because the user looks at them one at a time.
2. Send at least two. Say in `--message` how they differ and which one you'd pick and why.
3. Wait for the review.
   - `chosen` means continue with the suggestion at index `choice`. Read the comments too. The user may want changes to the one they chose.
   - `rejected` means the user rejected them all. Read the comments, then send new suggestions or ask the user how to proceed.

## What makes good proof

- Show the behavior itself, not a description of it.
- Capture the proof yourself, from the current code. Don't reuse old screenshots.
- Use `--message` to say what the proof shows and what the user should check.
- If you can't produce proof, say so in the message instead of sending something unrelated.

## Send a review

```sh
# Step 1 of a bug fix: proof that the bug exists.
prove-it send login-bug.mov --title "Bug: Log in button does nothing" \
  --message "Expected the dashboard after clicking Log in. Nothing happens and the console is empty. I think the click handler is never attached."

# Step 3: proof of the fix, reproduced the same way.
prove-it send login-fixed.mov --title "Fix: Log in button does nothing" \
  --message "Same steps as before. Clicking Log in now opens the dashboard."

# Suggestions: the user picks one.
prove-it suggest empty-a.png empty-b.png empty-c.png --title "Empty inbox screen" \
  --message "A is closest to the current style. B adds an illustration. C shows the CLI command. I'd pick A."
prove-it suggest --text "prove-it send" --text "prove-it submit" --title "Name for the send command"
```

`send` and `suggest` take the same options and print the review id, for example `20250116-153012-a3f9`.

- Pass any number of files. Supported kinds are images (png, jpg, gif, heic, webp, tiff, bmp), videos (mp4, mov, m4v), svg, and any UTF-8 text or code file.
- `--text "..."` adds inline text as an item. You can repeat it.
- `-` as a file name reads text from stdin.
- `--title` is the line the user sees in the inbox. Make it specific.
- `--message` tells the user what to check. Ask a concrete question.
- `--agent <name>` labels the sender. It defaults to `$PROVE_IT_AGENT`.
- The CLI copies the files, so you can change or delete them after sending.

Put related items in one review. Send separate reviews for unrelated questions.

## Wait for the answer

```sh
prove-it wait <id> --timeout 540
```

- It blocks until the user responds, then prints the response JSON to stdout.
- Exit code 0 means the user responded. Exit code 3 means the timeout passed and the review is still pending. Run the same command again to keep waiting.
- Choose a timeout below your shell tool's time limit. Without `--timeout` it waits forever.
- `prove-it send ... --wait --timeout 540` and `prove-it suggest ... --wait --timeout 540` send and wait in one step. On timeout, stderr has the id to wait on.

## Read the response

```json
{
  "comment": "Close. Fix the header.",
  "id": "20250116-153012-a3f9",
  "items": [
    {
      "comment": "Too much padding above the title",
      "file": "/Users/me/Library/Application Support/prove-it/inbox/20250116-153012-a3f9/assets/0-screenshot.png",
      "index": 0,
      "kind": "image",
      "name": "screenshot.png"
    }
  ],
  "responded_at": "2025-01-16T15:31:40Z",
  "status": "changes_requested",
  "version": 2
}
```

- `status` is `approved`, `changes_requested` or `rejected` for proof, and `chosen` or `rejected` for suggestions.
- `choice` is the index of the chosen suggestion in `items`. It is only present when `status` is `chosen`.
- `comment` is the overall comment. It is absent when the user left none.
- `items` has one entry per item, in the order you sent them. `comment` is the user's note on that item.
- `file` is an absolute path to the copy the user reviewed.

What to do next depends on the review. For proof of a bug, follow the steps in "Fixing a bug". For suggestions, follow "Offering suggestions". For proof of a fix or a feature:

- `approved`: the work is done.
- `changes_requested`: make the changes the comments ask for, then send new proof.
- `rejected`: stop and ask the user how to proceed.

## Other commands

- `prove-it list` prints pending reviews as `id<TAB>mode<TAB>status<TAB>title`, where mode is `proof` or `suggestions`. Add `--all` to include reviewed ones.
- `prove-it --help` and `prove-it <command> --help` describe every option.

