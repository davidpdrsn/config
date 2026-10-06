---
name: babysit
description: "Use to babysit pull requests"
---

After being told to babysit a PR, or told to open one, start a loop where you:

- Keep watching the PR for changes such as CI success/failures or review comments
- If the CI failure is trivial, such as formatting or lints, just amend and push a fix. Use the questionnaire tool to ask for permission to amend a fix and push
- If the CI failure isn't trivial, tell the operator what's going on so they can make a decision. Use the questionnaire tool
- If there are review comments from an agent, use the "address-copilot-feedback" skill to address them
- If there are review comments from a human, let the operator know. Use the questionnaire tool
- If CI is green and there are no unresolved review comments, use the questionnaire tool and ask the user if it should be merged. If yes, you now have permission to merge it
- Use the footer_link tool to add the PR to the Pi footer. The label must be "#PR-NUMBER ⋅ PR TITLE"
- After pushing a fix to a review comment, mark that comment as resolved on GitHub
- If the human tells you to ignore a review comment, mark it as resolved on GitHub
- If you see the human manually push commits to address review comments, ask if they should be resolved.
- Don't wait for the "lite-e2e" CI step. It's not required
- If you're watching a draft PR and CI passes and all initial review comments have been resolved, offer to mark it as ready for review and continue looping
- Never merge a PR unless explicitly told to do so
- Do a normal merge, not a rebase or squash
- Once the PR has merged, use the shutdown tool

After doing some work, never just sit idle. Either return to the babysit loop or use the questionnaire tool to ask what to do next.
