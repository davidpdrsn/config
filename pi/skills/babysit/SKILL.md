---
name: babysit
description: "Use to watch pull request after opening them"
---

After openig a pull request start a loop where you babysit the PR:

- Keep watching the PR for changes such as CI success/failures or review comments
- If the CI failure is trivial (such as formatting or simple test cases just amend and push a fix)
- If the CI failure isn't t trivial tell the operator whats going so they can make a decision
- If there are review comments from an agent use the "address-copilot-feedback" skill to address them
- If there are review comments from a human, let the operator know
- Never merge a PR unless explicitly told to do so

Return to this babysitting loop after completing a step (for example, continue babysitting after fixing CI)
