---
name: linear-issue-fetch
description: When told to do something with Linear. Use when the user provides a Linear issue identifier or URL and asks to read, inspect, summarize, or work from that issue.
---

Use the `linear` MCP.

# Finding issues

1. Identify the issue key from the user's input.
   - For an identifier such as `ENG-123`, use it directly.
   - For a Linear URL, extract the issue identifier from the URL path.
   - Preserve the identifier's original team prefix.

2. Fetch the issue.

3. Use the returned title, description, status, priority, assignee, labels, project, attachments, and comments as relevant to the user's request.

Remember to consider the project when finding the scope for the ticket, in case it isn't clear from the ticket text itself.

When you start working on a linear ticket, make sure the branch matches the ticket. If you're in a worktree you can just rename the branch or create a new branch if necessary.
