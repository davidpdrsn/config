---
name: but-briefs
description: Create and review code briefs with but briefs.
---

# but briefs

Briefs is the product, `but briefs` is its command line, and a **brief** is one focused review of code with the explanation beside it. `but briefs` computes a brief from git, here where the repository is, and keeps it on the Briefs server at an address of its own to share. Only what the brief shows leaves the machine: a diff carries the hunks around what you asked for, never the whole file.

Treat requests such as "brief me on authentication" or "walk me through this change" as requests for a brief, not just prose in chat.

## Measure the change first

Before you write a brief of a change, run `but briefs shape --base REF --head REF` (the brief's own `base` and `head`). It reads the declarations on both sides and says what the change is like, each with the numbers behind it, and how much each asks of a reviewer: green, nothing to act on; yellow, worth a look; red, act before merging. A change with nothing to flag says so, and what was checked.

The published brief carries the same measures: the brief's own comparison at the top, when a block shows it, and each comparison a block names with `--base` and `--head` on the first card that shows it. A brief of several pull requests, each block naming its own, says what each is like on its card.

Write the brief to answer them. A function it says is harder to follow deserves a `diff` block and a sentence on why it is shaped that way; an unrelated edit deserves a line saying why it is in this change, or a brief of its own; a copied block, a word on why not a shared helper. `--by-commit` prints one row per commit when the range has several.

## Write a brief

A brief is a markdown document, passed on stdin or as a file (`but briefs brief.md`). Your prose is the explanation; each line of a ```` ```brief ```` fence is one block of code, shown where the fence stands:

````bash
but briefs --open <<'BRIEF'
---
title: Matching split from the handler lookup
base: main
head: feature
---

Routes can now be matched without running a handler.

- **Matching** returns the params and a route key.
- **Dispatch** looks the handler up by that key.
- **One leftover**: an import nobody calls.

## Matching and dispatch

[`match_route`](#matcher) now returns the params and the route key, so a caller can match without running anything.

```brief
diff src/router.rs:12-30 --context 2 #matcher
```

[`dispatch`](#lookup) looks the handler up by that key, instead of matching again.

```brief
diff src/dispatch.rs:40-55 --context 2 #lookup
```

## Left behind

[`handlers.rs`](#leftover) still imports the old `resolve`, which nobody calls now.

```brief
excerpt src/handlers.rs:1-8 #leftover
```
BRIEF
````

The quoted heredoc passes the text as written; pick another delimiter if a line of the brief is exactly `BRIEF`.

- **Front matter** (optional): `title`, one line over the brief; `base`, what to compare against (default: where head left the default branch); `head`, a branch or commit, or `worktree` (the default) for uncommitted work. Without a `title`, a `# Heading` on the first line is the title.
- **Blocks**, one per line of a ```` ```brief ```` fence, paths relative to the repository root:
  - `files [PATH]`: which files changed, under PATH or in the whole change. The map of a change of any size.
  - `diff FILE`, `diff FILE:N-M`, `diff FILE:old:N-M`: the hunks around each change of a file, or around lines on the new side, or lines that only exist at base. `--context N` keeps N lines around each change (default 3, at most 200); nothing beyond the hunks reaches the reader, so give the context the explanation needs.
  - `signatures [FILE[:NAME]]`: which declarations changed shape, in the change, a file, or the one named (`src/lib.rs:Repo::commit`, `src/repo.ts:Repo.commit`), read from Rust, TypeScript/JavaScript, Python, Go, Java, Kotlin, Swift, C, C++, C#, Ruby and PHP. A change only inside a body is counted, not listed; a declaration that moved to another file says where it came from.
  - `excerpt FILE[:N-M][@REF]`: lines of a file at a ref (default: the brief's head), with no diff: the caller that still names a removed function, the config that should have changed.
  - `media FILE WORDS`: a screenshot, then the words saying what it shows, which a reader who cannot see it reads instead: `media shots/login.png The login form, after the change`. For what code cannot show, such as a screen before and after. A PNG, JPEG, GIF, WebP or AVIF image of at most 10 MiB, inside the repository but not necessarily committed; it is uploaded with the brief. Neighbouring `media` lines show side by side as one set, stepped through at full size, so one sentence before them is enough.
  - `files`, `signatures` and `diff` take `--base REF` and `--head REF` to compare something else than the brief does.
- **Proposals**: a ```` ```diff FILE ```` fence is a change you propose and have not written, shown as a diff whose head is the proposal. Write its lines as git would, ` ` for context, `-` removed and `+` added, with no line numbers and a line of `@@` between hunks; each hunk goes where its context and removed lines are, so give enough of them to fit one place. A new file is all `+` lines. It is written over the brief's head, the working tree unless the front matter says otherwise, so lines you have not committed are context like any other; `--base REF` writes it over a commit instead. It takes `--context N` and `#name` too. A `diff` fence without a file stays a code sample in the prose.
- **Names**: end a block line with `#name`, and link to it from your prose as `[words](#name)`. The link reads as your words and leads to the block. The contents list each block by the words of its first link, so link every block worth finding, in a few words that say what it shows: [`match_route`](#matcher), [the lookup by key](#lookup). A block nothing links to is not listed.
- **Prose** comes before every block: at least one sentence saying why that block is there and what to see in it. Prose never restates the diff.

## Size it to the change, and fold the depth

Make one point. Show the code that proves it, and fold the rest into details. How much to show grows with the change, counted in lines of code changed, not tests or docs; the brief's labels say which it is:

- **Small** (under 150 lines): one to three spots, a minute or two to read.
- **Medium** (150 to 400 lines): three to five spots, about three minutes.
- **Large** (over 400 lines): five to eight spots, a `##` part each, and a `files` map, about five to eight minutes. Don't stop short: a reviewer shown three spots of a large change has to guess at the rest.

Whatever the size:

- **One point per brief.** If you need "and also", write a second brief.
- **Highlight, don't tour.** Show the spots a reviewer must see: the core logic, a new type, the one tricky line. Say the rest in a bullet.
- **Eight places and 250 lines of code at most** in what shows unfolded, the `files` map included, however large the change.
- **10 to 30 lines a place.** Narrow every diff with `FILE:N-M`, and keep `--context` to one or two lines. Show a function's heart, not the whole function.
- **A reason before every block.** At least one sentence saying why the block is there, so give each block its own fence, after its sentence. Two or three sentences when the reader needs them.

Where something is worth digging into but not everyone needs it, fold it into a **detail**. The page shows its teaser as one closed row, with how much it holds and how long it takes to read. The reader opens it in place.

````markdown
[`place`](#place) puts each hunk where its old lines are, so authors never count line numbers.

```brief
diff src/proposal.rs:132-150 --context 1 #place
```

:::deep How a hunk that fits nowhere is reported
The error names the first line that differs, and what the file has there, so the author can fix the hunk:

```brief
diff src/proposal.rs:150-170 --context 1
```
:::
````

- **The teaser is the `:::deep` line.** Say what is inside, as a reason to open it: "How a hunk that fits nowhere is reported", not "More details".
- **Most briefs need none or one.** Fold what a curious reader wants, not what you could not cut.
- **One to five minutes a detail.** Under a minute, say it inline or cut it: a fold that hides two sentences is not worth the click. Over five, split it into two details, or give it a brief of its own.
- **A detail holds prose and blocks** until a `:::` line, eight places and 250 lines of code at most, like the brief around it. It cannot hold another detail.

If the change is large and the request does not say how deep to go, ask once.

## Write plainly

Write for a busy reader, not to sound clever.

- **Short sentences.** One idea each, under about 20 words. Split a sentence at "and", "which" or a semicolon.
- **Common words.** Say "removes", not "retires". Say "is slow", not "has a performance cost". No metaphors.
- **Say what changed, then why.** Skip the history, the alternatives you dropped and how hard it was, unless the reader needs them to review.
- **Bullets fit on one line.** A bold key term, then a few words. Fragments are fine.
- **Name things exactly.** Use the function or file name in backticks, not "the helper" or "this part".

Too long:

> The matcher has been reworked so that it now returns the route key alongside the params, which means that dispatch no longer has to perform the handler lookup on its own, and as a consequence the old `resolve` function is left without any callers.

Better:

> `match_route` now returns the route key. `dispatch` looks the handler up by it, so nothing calls `resolve` any more.

## Make it easy to read at a glance

A reader skims a brief before reading it. Shape the prose so the skim already tells the story:

- **Open with the point**: one or two short sentences on what changed and why. Then a short bullet list of the parts, before any code.
- **A `##` heading per part** of the explanation, `###` for a part of one. A brief with two headings or more gets a table of contents that links to each heading and to the blocks under it, so headings are how a reader finds their way.
- **Bullets** for three items or more. Lead each with the key term in **bold**, and keep it to one line.
- **Short paragraphs**: one or two sentences. A table to compare options or before and after. A numbered list when order matters.
- **Code words** in backticks, and a link to the block they are about.
- **Callouts**: GitHub-style `NOTE`, `TIP`, `IMPORTANT`, `WARNING`, and `CAUTION` are supported. Put `> [!NOTE]` on its own line, followed by the body on `>` lines. Use them sparingly for information a reviewer should not miss.

Put the places in the order your explanation walks through them, under one title.

## What it says back

A mistake in the brief (an unknown kind, a range that is not one, a link to a name nobody has) is reported with its line, before anything is computed. Then every block is computed, and each path, ref or line that git does not have is reported at once, with the line of its block.

`--dry-run` computes the brief and lists its blocks without sending anything, marks the blocks folded in a detail, says when the brief is long, past eight places or 250 lines of code, or a detail past the same, and names any block with no sentence before it. With `--json` it prints the brief exactly as it would be sent. Check a brief that way before you share it.

Without `--dry-run`, it sends the brief to the Briefs server, with the publishing token from `BRIEFS_TOKEN`, and prints the brief's address on the last line (`{"href": …}` with `--json`): give that address to the person. Publish with `--open`, as the example does, so the brief opens in their browser as soon as it is kept, and they can start reading without copying the address; leave it out only when they are not at this machine or asked for just the address. Exit status 3 means the server could not take the brief, not that it is wrong: try again later.

## Take the review

Anyone with the address can comment on the brief, under a name they type: on a whole block, on lines of a diff or an excerpt, or on any passage they select. Anyone can also reply to a comment, resolve it, open it again, or remove a comment or a reply.

`but briefs comments <address>` lists them, oldest first, with how many are open. Each comes with where it is (the block, then for code the file, its lines, the side and the commit), the words it quotes, its replies, whether it is resolved, and a short id in brackets:

```
p2 · src/router.rs:40, new side at d9a7f36 [ea6fb6c5]
  > let route = table.get(key)?;
  Sam: What happens when two routes share a key?
    agent [7a76dbcb]: The later one wins; I added a test that says so.
```

Act on it from here, naming a comment or a reply by its id or the start of it:

- `--reply ID -m TEXT` answers a comment, as `agent` unless `--as NAME` says who.
- `--resolve ID` and `--reopen ID` close a comment or open it again.
- `--remove ID` removes a comment with its replies, or one reply.
- `--json` gives any of this as data.

Answer every open comment, saying what you did and where, not only that you did it. When the answer is a change to the code, make it, and reply with the address of a brief of that change: it shows the reviewer exactly what moved. Publishing again always makes a new brief at a new address, with no comments; the thread stays on the brief it was written on, so answer it there. Leave resolving to the person unless they asked you to; remove only what you wrote by mistake.

To be told when review moves instead of asking, run `but briefs comments <address> --wait` in the background. It looks every five seconds (`--every N` to change that) and exits as soon as a comment or a reply is written, resolved, reopened or removed, printing each change with its thread. When it exits, act on what it printed, then start it again; stop when the person says the review is done.

While it waits, the brief's page shows that you are listening, under the name `--as` gives, and anyone on it can ask you to stop. Then `--wait` exits saying who asked: do not start it again on that brief unless the person asks you to.
