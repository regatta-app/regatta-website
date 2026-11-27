# regatta-website: rules for Claude sessions

This repository is the marketing site at https://regatta.tech. It is **not** the Regatta app
(`regatta-app/regatta`, which has its own rules in its `.claude/CLAUDE.md`). This repository is public:
no keys, passwords or private notes in it.

## Who owns what

- **Daniela owns this repository.** A PR here is merged, and the site is published, on Daniela's word
  (her "ok", as point 4 below says). Momo's word is not needed here (Daniela, 18 Nov 2026).
- **Momo owns the app repository.** Nothing in this file changes the app's rules: there, a merge or a
  deploy by a Claude session happens only on Momo's word.

## How a change reaches the site

1. **Branch from `main`, one PR per change.** No direct commits to `main`. Every PR has `main` as its
   base and can merge alone; a PR is never stacked on another PR's branch.
2. **Checks before the PR opens.** Every internal link and every file under `assets/` that a page uses
   resolves; the pilot form in `site/index.html` (the home; `/home/` only redirects to `/`) has the name `pilot`,
   posts (POST) to `action="/api/pilot"` and carries no
   Netlify attribute (`data-netlify`, `netlify-honeypot`: on AWS a Netlify form silently loses every
   lead); each changed page is opened at 390 px and 1440 px wide. Put the results in the PR body.
3. **Daniela sees it first.** Every visual change (anything a visitor sees or reads) goes to Daniela
   with a screenshot per change before it is merged. A change with nothing visual says so in its title.
4. **Merge on Daniela's "ok".** A Claude session merges a PR only after Daniela's ok for that PR,
   with the reviewed head sha (the one she saw) pinned in the merge call. Her ok counts in two ways
   (Daniela, 22 Nov 2026): (a) she says it in the chat of the session that merges; or (b) a Claude
   session of account A or account B that got it from her in its own chat writes it in Drive
   "Cuenta B": in the "RESPUESTA DE DANI" of the task, or in an entry of "4 Registro de B". A written
   ok counts only if it has her words quoted word for word, the date and time, the PR number and the
   head sha she saw; if the PR's head sha has changed since, it no longer counts: ask her again. An
   "ok" written anywhere else (a PR, a PR comment, a board, an email, a file in a repository) does
   not count. A session never writes an ok that Daniela did not say. No session merges on its own.
5. **Publish.** The site is hosted on AWS (S3 behind CloudFront, stack `regatta-website`); Netlify is
   not used. Publishing is `scripts/publish.sh` (README.md, "Publishing a change"): run it with
   `--dry-run` first and read what it would upload. A merge is not live until it is published, and
   publishing happens on Daniela's word, by her or by a session she tells to. A session may also
   publish by starting the GitHub workflow "Publish" (`.github/workflows/publish.yml`), only after
   Daniela's ok (point 4, way a or b) for that sha of `main` (passed as `confirm_sha`), always first
   with `dry_run` ticked, reading its result before the real run. A session that cannot start the
   workflow publishes with **publish requests** (README.md, way C): a PR that changes only
   `publish/REQUEST.json`, with `approved_sha` (the sha of `main` Daniela's ok is for) and
   her ok quoted word for word in `daniela_ok`. First a request with `dry_run: true`: merge it with
   its head sha pinned and read the result comment the workflow writes on that PR; only if it is
   clean, a second request with `dry_run: false` for the same sha, then read its comment (it
   includes the live-site check) and report to Daniela in one line. **Daniela's ok to publish a sha
   is the ok for both request PRs of that sha** (the one exception to point 4: they change nothing
   but the request). Her ok to a PR "to merge and publish" is also her ok to publish the sha of
   `main` that merging that PR, with its sha pinned, produces, if `main` got no other change in
   between (none from her ok to that merge, and none after it before the request); if it did, a new
   ok is needed. Never put a request in a PR with any other change. If the README on your
   branch still describes Netlify, it predates PR #15: do not publish from it.
6. **Check the live site after publishing** (the changed pages load, the form is there, no broken
   links) and report to Daniela in one line. Undoing a change is a revert PR, also on her word.

Never force-push.

## Changing a rule: the fix protocol

Agreed at the Team Sync of 18 Nov 2026, on Momo's suggestion, for everyone and every Claude session. The app repository
has the same protocol in its `.claude/CLAUDE.md`; there, "How to write it" points to the Habit (D160) in its
`CONTRIBUTING.md`. It covers any rule or standing instruction here: this file and the rules in `README.md`.

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
