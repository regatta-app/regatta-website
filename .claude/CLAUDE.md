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
   publishing happens on Daniela's word, by her or by a session she tells to. If the README on your
   branch still describes Netlify, it predates PR #15: do not publish from it.
6. **Check the live site after publishing** (the changed pages load, the form is there, no broken
   links) and report to Daniela in one line. Undoing a change is a revert PR, also on her word.

Never force-push.
