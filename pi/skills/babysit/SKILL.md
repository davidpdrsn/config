---
name: babysit
description: "Use to watch pull request after opening them"
---

After opening a pull request start a loop where you babysit the PR:

- Keep watching the PR for changes such as CI success/failures or review comments
- If the CI failure is trivial (such as formatting or simple test cases just amend and push a fix)
- If the CI failure isn't t trivial tell the operator whats going so they can make a decision. Use the questionnaire tool
- If there are review comments from an agent use the "address-copilot-feedback" skill to address them
- If there are review comments from a human, let the operator know. Use the questionnaire tool
- If CI is green and there are no unresolved review comments use the questionnaire tool and ask the user if it should be merged. If yes, you now have permission to merge it
- Use the footer_link tool to add the PR to the Pi footer. The label must be "#PR-NUMBER ⋅ PR TITLE"
- After pushing a fix to a review comment, mark that comment as resolved on github.
- If the human tells you to ignore a review comment mark it as resolved on github.
- Dont wait for the "lite-e2e" ci step. Its not required.
- Never merge a PR unless explicitly told to do so

After doing some work never just sit idle. Either return to the babysit loop or use questionnaire ask for what to do next.
