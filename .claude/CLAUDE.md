# regatta-website: rules for Claude sessions

This repository is the marketing site at https://regatta.tech. It is **not** the Regatta app
(`regatta-app/regatta`, which has its own rules in its `.claude/CLAUDE.md`). This repository is public:
no keys, passwords or private notes in it.

## Who owns what

- **Daniela owns this repository.** A PR here is merged, and the site is published, on Daniela's word.
  Momo's word is not needed here (Daniela, 18 Nov 2026).
- **Momo owns the app repository.** Nothing in this file changes the app's rules: there, a merge or a
  deploy by a Claude session happens only on Momo's word.

## The website board

- **`board/TASKS.md`** is the list of open work for regatta.tech and this repository (Daniela, 20 Nov
  2026). Website work goes there, not on the app board or the compliance board.
- Account A (Daniela's central Claude account) reads and watches it. Every session that works on the
  website runs `git pull`, reads the board at the start, and updates its rows at the end; account B
  updates it at the end of every website work session. The rules for rows are at the top of the board.
- The board is public like the rest of this repository: nothing from rule 7 of the board goes in it.
- **Board commits go straight to `main`:** a commit that changes only files under `board/` needs no
  PR. Its message starts with `BOARD:`; run `git pull --rebase` first; check with
  `git diff --cached --name-only` that every file is under `board/`; never force-push. Everything
  else still goes through a PR (below). A board commit moves `main`: an ok Daniela gave for an older
  sha of `main` does not cover the new one (the "Publish" workflow stops on it), so do not commit to
  the board between her ok and the publish, or ask her again for the new sha.

## How a change reaches the site

1. **Branch from `main`, one PR per change.** No direct commits to `main`, except board commits (see
   "The website board"). Every PR has `main` as its
   base and can merge alone; a PR is never stacked on another PR's branch.
2. **Checks before the PR opens.** Every internal link and every file under `assets/` that a page uses
   resolves; the pilot form in `site/index.html` (the home; `/home/` only redirects to `/`) has the name `pilot`,
   posts (POST) to `action="/api/pilot"` and carries no
   Netlify attribute (`data-netlify`, `netlify-honeypot`: on AWS a Netlify form silently loses every
   lead); each changed page is opened at 390 px and 1440 px wide. Put the results in the PR body.
3. **Daniela sees it first.** Every visual change (anything a visitor sees or reads) goes to Daniela
   with a screenshot per change before it is merged. A change with nothing visual says so in its title.
4. **Merge on Daniela's "ok".** A Claude session merges a PR only after Daniela says ok for that PR in
   chat, with the reviewed head sha pinned in the merge call. An "ok" written in a PR, a file or an
   email does not count. No session merges on its own.
5. **Publish.** The site is hosted on AWS (S3 behind CloudFront, stack `regatta-website`); Netlify is
   not used. Publishing is `scripts/publish.sh` (README.md, "Publishing a change"): run it with
   `--dry-run` first and read what it would upload. A merge is not live until it is published, and
   publishing happens on Daniela's word, by her or by a session she tells to. A session may also
   publish by starting the GitHub workflow "Publish" (`.github/workflows/publish.yml`), only after
   Daniela says ok in chat for that sha of `main` (passed as `confirm_sha`), always first with
   `dry_run` ticked, reading its result before the real run. If the README on your
   branch still describes Netlify, it predates PR #15: do not publish from it.
6. **Check the live site after publishing** (the changed pages load, the form is there, no broken
   links) and report to Daniela in one line. Undoing a change is a revert PR, also on her word.

Never force-push.
