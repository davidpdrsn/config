---
name: splitting-commits
description: "Use this skill when told to split or clean up commits"
---

Using GitButler inspect the contents of the commits and split or squash it into new commits that are easier to review and tell a better story. Generally lower level changes should go in earlier commits, and higher level changes that build on the lower levels so be in later commits, and so on.

Also look out for distinct chunks that make sense in their own commit.

It is not a requirement that each commit builds and passes tests.

Use `t "git tree hash"` before and after to verify that you didn't change the actual files on disk. This command prints the hash of the current git tree and if hasn't changed then we're sure the commit splitting didn't change any code. Show the exact before and after hashes to the user.
