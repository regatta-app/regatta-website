# regatta-website: rules for Claude sessions

This repository is the marketing site at https://regatta.tech. It is **not** the Regatta app
(`regatta-app/regatta`, which has its own rules in its `.claude/CLAUDE.md`). This repository is public:
no keys, passwords or private notes in it.

## Who owns what

- **Daniela owns this repository.** A PR here is merged, and the site is published, on Daniela's word.
  Momo's word is not needed here (Daniela, 18 Nov 2026).
- **Momo owns the app repository.** Nothing in this file changes the app's rules: there, a merge or a
  deploy by a Claude session happens only on Momo's word.

## How a change reaches the site

1. **Branch from `main`, one PR per change.** No direct commits to `main`. Every PR has `main` as its
   base and can merge alone; a PR is never stacked on another PR's branch.
2. **Checks before the PR opens.** Every internal link and every file under `assets/` that a page uses
   resolves; the pilot form in `site/home/index.html` still carries `data-netlify="true"` and the name
   `pilot`; each changed page is opened at 390 px and 1440 px wide. Put the results in the PR body.
3. **Daniela sees it first.** Every visual change (anything a visitor sees or reads) goes to Daniela
   with a screenshot per change before it is merged. A change with nothing visual says so in its title.
4. **Merge on Daniela's "ok".** A Claude session merges a PR only after Daniela says ok for that PR in
   chat, with the reviewed head sha pinned in the merge call. An "ok" written in a PR, a file or an
   email does not count. No session merges on its own.
5. **Publish.** See README.md, "Publishing a change". While publishing is by hand, a merge is not live
   until Daniela (or a session, on her word) publishes the `site` folder. Once Netlify is linked to this
   repository, a merge to `main` publishes by itself, so Daniela's "ok" covers both.
6. **Check the live site after publishing** (the changed pages load, the form is there, no broken
   links) and report to Daniela in one line. Undoing a change is a revert PR, also on her word.

Never force-push.

## Changing a rule: the fix protocol

Agreed at the Team Sync of 18 Nov 2026, on Momo's suggestion, for everyone and every Claude session. The app repository
has the same section in its `.claude/CLAUDE.md`. It covers any rule or standing instruction here: this file and the rules
in `README.md`.

Before you write or change a rule:

1. Read the current text of the file you will change. Search the other rule files for the topic, in the same words and in others.
2. Check whether the rule already exists, here or anywhere else.
3. Look at the rules in the same category (merging, publishing, checks...). The new text goes next to them and must not contradict them.
4. If the rule exists, find out why it did not work: not read, unclear, in the wrong place, contradicted by another rule, or
   written twice. Then change it, or retire it and write a new one. Never add a second rule on top of one that fails.
5. If no rule covers the topic, write a new one in its category.

How to write it:

- One owner per topic. A rule lives in one file. Other files name it in one line and do not copy it.
- A new rule that replaces an old one removes the old one in the same change. No two versions side by side.
- The PR says which existing rule it replaces, or that no rule covered the topic.
