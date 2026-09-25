Using the GitButler CLI, inspect the uncommitted changes and make topical commits to the appropriate branches.

Prefer making smaller more reviewable commits that tell a good story. Generally lower level changes should go in earlier commits, and higher level changes that build on the lower levels so be in later commits, and so on.

Also consider if the changes should instead be amended into existing commits, if they're fix up style changes. You might need to create new independent branches or stacked branches.

Dont run tests or perform any verification before committing.
