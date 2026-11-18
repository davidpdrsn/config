---
name: review-it
description: "Use when told to review your work with 'review it'"
---

Run a review loop with a pi subagent, the reviewer.

1. Commit your work.
2. Start the reviewer with `subagent_spawn`, named `reviewer`, with `wait: true`. The reviewer can't see this conversation, so the task tells it to:
   - Review `<branch>` (`git log master..<branch>`) with the code-review skill. Review only, with no edits, commits or pushes.
   - Read this session's transcript for the decisions made, and flag code that doesn't match them. Write the path from `$PI_SESSION_FILE` into the task. The reviewer has its own session, so the variable won't point to yours.
   - End its reply with the full review. Its final message is the result you get back.
3. When the review arrives, check each finding against the code before acting on it. A finding that changes or expands the scope, such as a new feature, a different design or work beyond the branch's goal, goes to the user to decide. Don't act on it yourself.
4. Loop:
   - Fix the findings that hold up and matter, including refactors that simplify the code. Skip edge cases, nits and speculation.
   - Commit the fixes.
   - Send the reviewer one message with `subagent_send` and `wait: true`. Say what you fixed and in which commit, what you skipped and why, and ask for a new review of the branch. The reviewer keeps its earlier context between runs.
   - Repeat from step 3.

   A review always finds something, so stop when a round finds nothing that holds up and matters. Tell the user what you fixed and skipped in each round.
5. When the loop is done, stop the reviewer with `subagent_stop` and `ids: ["reviewer"]`.
