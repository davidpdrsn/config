---
name: review-it
description: "Use when told to review your work with 'review it'"
---

Run a review loop with two pi subagents as reviewers, one on Opus and one on Astra.

1. Commit your work.
2. Start both reviewers with `subagent_spawn` in the same tool call block, without `wait`, so they run in parallel:
   - `name: "reviewer-opus"`, `model: "anthropic/claude-opus-5-5"`
   - `name: "reviewer-astra"`, `model: "openai-codex/gpt-6.2-astra"`

   Give both the same task. The reviewers can't see this conversation, so the task tells them to:
   - Review `<branch>` (`git log master..<branch>`) with the code-review skill. Review only, with no edits, commits or pushes.
   - Read this session's transcript for the decisions made, and flag code that doesn't match them. Write the path from `$PI_SESSION_FILE` into the task. The reviewers have their own sessions, so the variable won't point to yours.
   - End the reply with the full review. The final message is the result you get back.
3. Wait for both with `subagent_wait` and `ids: ["reviewer-opus", "reviewer-astra"]`.
4. Merge the two reviews. A finding both reviewers raise counts once. Check each finding against the code before acting on it. A finding that changes or expands the scope, such as a new feature, a different design or work beyond the branch's goal, goes to the user to decide. Don't act on it yourself.
5. Loop:
   - Fix the findings that hold up and matter, including refactors that simplify the code. Skip edge cases, nits and speculation.
   - Commit the fixes.
   - Send each reviewer one message with `subagent_send`, both in the same tool call block. Say what you fixed and in which commit, what you skipped and why, and ask for a new review of the branch. Send both reviewers the same message, so each sees what you did with the other's findings. The reviewers keep their earlier context between runs.
   - Repeat from step 3.

   A review always finds something, so stop when a round finds nothing from either reviewer that holds up and matters. Tell the user what you fixed and skipped in each round, and which reviewer raised each finding.
6. When the loop is done, stop both reviewers with `subagent_stop` and `ids: ["reviewer-opus", "reviewer-astra"]`.
