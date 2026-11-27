# regatta.tech — marketing site

The public site at https://regatta.tech. This is **not** the Regatta app (that lives in `regatta-app/regatta` and is served at app.regatta.tech, which nothing here touches).

```
site/       the files that are served (index.html at the top; home/, privacy/, thanks/, 404.html, assets/)
aws/        CloudFormation template for the hosting, the setup guide, and STACK-UPDATE.md
scripts/    publish.sh: upload site/ to S3 and refresh CloudFront
            check-publish-request.sh, check-live-site.sh: used by the Publish workflow
.github/    workflows/publish.yml: the "Publish" button and publish requests (run publish.sh from GitHub)
publish/    REQUEST.json: the latest publish request (way C below); created by the first request
index.html  accidental duplicate of site/index.html (see Notes); not served
```

## Hosting

**AWS**, since 9 Nov 2026, all in the CloudFormation stack `regatta-website` (us-east-1) defined by [`aws/regatta-website.yaml`](aws/regatta-website.yaml):

- **S3** — a private, versioned bucket holds the files from `site/`. Only CloudFront can read it.
- **CloudFront** — serves regatta.tech with an ACM certificate, redirects `www.regatta.tech` to `regatta.tech`, redirects `/page` to `/page/` and serves `/page/` from `page/index.html`, adds the security headers (HSTS, CSP, …), and sends `/api/*` to the form receiver.
- **Lambda + SNS** — the "Request access" form in `site/index.html` (the home) posts to `/api/pilot`. A small Lambda (Function URL behind CloudFront) checks the honeypot, validates the email, runs the spam filter (below) and publishes the submission (email and organization only) to an SNS topic that emails it to the addresses set as stack parameters. The visitor goes to `/thanks/`, or back to `/home/?error=email#meet` (invalid email) or `/home/?error=send#meet` (sending failed; `/home/` now redirects to `/` and keeps the `?error=`, landing on the form; the submission is then in CloudWatch, log group `/aws/lambda/regatta-website-pilot-form`, line `LEAD NOT EMAILED`).
- **Form spam filter** (PR #16, ported 19 Nov 2026). The page sends a hidden `elapsed` field: milliseconds from page load to submit.
  - Under 3 s: dropped. The visitor still sees `/thanks/`. No email; one CloudWatch line `DROPPED as too fast` keeps the details.
  - Possible spam is **tagged, never dropped**: the subject starts with `[Possible spam]` and the email lists the reason. Reasons: no or empty `elapsed` (no JavaScript, or a page cached before the filter), an unreadable `elapsed`, a Gmail address with 3+ dots, an organization that looks like random letters.
  - Test it locally, no AWS needed: `node aws/test-pilot-form.js`. The filter lives in the template, so it goes live only with a stack update (`aws/STACK-UPDATE.md`), not with `scripts/publish.sh`.
- **Route 53** — the DNS records for regatta.tech.

Analytics (Umami Cloud, EU; off until the website id is set), the CSP and Permissions-Policy, the `/home/` 301, the sitemap and the structured data: see [`docs/analytics-and-seo.md`](docs/analytics-and-seo.md).

Caching is set per file when uploading (HTML, CSS and JS 5 minutes, fonts one year, images, video and icons one day); see "Caching and response headers" in [`aws/website-aws-hosting-2026-10-29.md`](aws/website-aws-hosting-2026-10-29.md).

**Netlify is no longer used.** The old Netlify project was removed in November 2026 and no longer reacts to this repo.

## Publishing a change

Who may merge and publish: Daniela owns this repository; the rules are in `.claude/CLAUDE.md`.

1. Edit the files in `site/`, open a pull request, merge to `main`.
2. Publish `main`, **only on Daniela's word**, in one of three ways.

### A. With the "Publish" button on GitHub (no computer or AWS console needed)

Set up once: [`aws/STACK-UPDATE.md`](aws/STACK-UPDATE.md), section 6 (a stack update and four repository variables).

1. GitHub → **Actions** → **Publish** → **Run workflow**. Leave *Use workflow from* on **Branch: main**.
2. **confirm_sha**: the full 40-character sha of `main` that Daniela approved (GitHub → *Code* → the commit list → copy the full sha). If `main` has moved on since, the run stops before touching AWS.
3. Leave **dry_run** ticked and press **Run workflow**. Open the run: its summary shows the sha, "dry run" and what would be uploaded and invalidated. Read it.
4. If it looks right, run it again with the same sha and **dry_run** unticked. The summary then says "real publish".

Who can press the button: anyone with write access to this repository (GitHub only shows *Run workflow* to them), and a Claude session with that access. It runs only on `main`, by hand or by a publish request (way C; never on a pull request, and never on a push that does not change `publish/REQUEST.json`), one run at a time, and signs in to AWS without any stored key: AWS accepts only this repository's `main` (the `PublishRole` in the stack). The role can upload to the site bucket and clear the CloudFront cache, nothing else; it cannot delete files, so the button never passes `--delete` (use CloudShell for that). Every run uploads every file, because a fresh checkout gives every file a new date (see "What `scripts/publish.sh` does"); that is harmless and also refreshes every `Cache-Control`. Run logs of this public repository are public: the bucket, distribution and role are hidden (`***`) in them.

### C. With a publish request (a pull request; for Claude sessions in the cloud)

A Claude session in the cloud cannot press the button in A, but it can open and merge pull requests. So it publishes by merging a small pull request that changes **only** the file `publish/REQUEST.json`. When that reaches `main`, the same "Publish" workflow starts by itself, checks the request, publishes, and writes the result as a comment on that pull request. Same AWS role, same rules: nothing changes in AWS.

The file (an example; the real one only ever exists on `main`, written by a request pull request):

```json
{
  "approved_sha": "0123456789abcdef0123456789abcdef01234567",
  "dry_run": true,
  "requested_on": "2026-11-21",
  "daniela_ok": "ok, publica 0123456 (chat, 21 Nov 2026 10:05)"
}
```

- `approved_sha`: the full sha of `main` that Daniela said ok to publish.
- `dry_run`: `true` (look only) or `false` (really publish). Written without quotes.
- `requested_on`: the day the request is written (UTC). An old request is refused.
- `daniela_ok`: Daniela's ok, copied word for word, so anyone can see later who allowed it. It counts only if she said it in the chat of the session that merges, or if a Claude session of account A or B that got it from her wrote it in Drive "Cuenta B" with her words quoted, the date and time, the PR number and the head sha she saw (`.claude/CLAUDE.md`, point 4). An ok written anywhere else does not count.

How a publish works:

1. Daniela says ok to publish a sha of `main`: in the chat of the session that will merge, or in the chat of a session of account A or B that writes it in Drive as `.claude/CLAUDE.md` point 4 says (her words, date and time, PR number and sha).
2. The session opens a pull request that changes only `publish/REQUEST.json`, with that sha, `"dry_run": true` and her ok quoted, and merges it with its head sha pinned. Within a minute the workflow does a dry run and comments the result on that pull request.
3. The session reads the comment. If anything looks wrong, it stops and tells Daniela.
4. If the dry run is clean, the session opens a second request pull request: same sha, `"dry_run": false`, and merges it. The workflow publishes, waits for CloudFront, checks the live site (every page, CSS and JS file answers 200 and is exactly the file in `site/`; the home has the pilot form posting to `/api/pilot`) and comments the result.
5. The session tells Daniela the result in one line.

What the workflow refuses (it stops before touching AWS and says why in the comment):

- a pull request that changes anything besides `publish/REQUEST.json` (merge the site change first, then request);
- a file that is not exactly the four fields above, a short or uppercase sha, `"true"` in quotes, a field written twice;
- an `approved_sha` that is not in the history of `main`, or a `main` whose files differ in anything (site, scripts, workflow) from `approved_sha`: what is published is byte for byte what Daniela approved;
- a real publish (`false`) that does not come straight after a successful dry run of the same sha;
- a request dated more than a day before or after today (for example an old one brought back by a revert).

Good to know: a push to `main` that does not change `publish/REQUEST.json` never publishes. Removing the file publishes nothing. Requests wait for each other: merge one, wait for its comment, then the next. A merge commit whose message contains `[skip ci]` does not start the workflow. Who can publish this way: anyone who can merge to `main`, like the button in A; the workflow checks the request, but it cannot check that the quoted ok really came from Daniela.

### B. From AWS CloudShell (still valid)

Open **AWS CloudShell** (AWS console, region US East (N. Virginia), the `>_` icon), then:

   ```
   git clone https://github.com/regatta-app/regatta-website.git   # first time; later: cd regatta-website && git pull
   cd regatta-website
   scripts/publish.sh --dry-run BUCKET DISTRIBUTION_ID
   scripts/publish.sh BUCKET DISTRIBUTION_ID
   ```

   `BUCKET` and `DISTRIBUTION_ID` are the **BucketName** and **DistributionId** on the Outputs tab of the `regatta-website` stack (CloudFormation console). They are not written in this public repo on purpose.

What `scripts/publish.sh` does:

- **Pre-flight, aborts before uploading anything** if the form `name="pilot"` in `site/index.html` does not POST to `action="/api/pilot"`, if any page or still has `data-netlify` / `netlify-honeypot` (a Netlify form on AWS silently loses every lead), or if the HTML or CSS references an `/assets/…` file that is not in `site/`.
- **Uploads** with `aws s3 sync` in four passes, each with its own `Cache-Control`, in this order: fonts `public, max-age=31536000, immutable`; images, video, icons `public, max-age=86400`; CSS and JS (`site.css`, `site.js`) `public, max-age=300, must-revalidate`; HTML, `sitemap.xml`, `robots.txt` `public, max-age=300, must-revalidate` (last, so pages never point at assets not yet uploaded). Never uploads `_headers` or dotfiles.
- **A new `Cache-Control` only reaches a file when it is uploaded again.** `aws s3 sync` skips a file whose size and date did not change, so a file already in the bucket keeps its old header until it is re-uploaded. A fresh clone (as in CloudShell above) uploads every file, because every file date is new; in an old clone, `touch` the files first. To check after publishing: `curl -sI https://regatta.tech/assets/site.css | grep -i cache-control` should show `max-age=300`.
- **Does not delete** files from the bucket unless you pass `--delete`. Production pages, and copies of them that browsers and CloudFront still hold for a few minutes, can reference files that are no longer in the repo (for example a renamed photo); deleting them would break those pages. The bucket is versioned, so a file deleted by mistake can be restored (S3 → bucket → *Show versions*).
- **Invalidates** in CloudFront the paths it uploaded (a page's `index.html` and its `/folder/` URL), or `/*` when more than 15 changed. Within a minute or two everyone gets the new version.
- `--dry-run` shows all of this without changing anything.

**Changed `site.css` or `site.js`?** Change the `?v=` after its name in every page that links it (`/assets/site.css?v=2026-11-20` in `site/index.html`, `site/privacy/index.html`, `site/thanks/index.html` and `site/404.html`; use the day of the change). Without a new `?v=` a returning visitor can get the new page with the old styles (20 Nov 2026: the "Open Regatta" button showed as plain text for a day). Since `scripts/publish.sh` uploads CSS and JS with a 5-minute cache, a forgotten `?v=` now means up to 5 minutes of old styles instead of a day; still change it. (`site.js` is linked without `?v=` today, in `site/index.html` and `site/privacy/index.html`; add one when it changes.)

**Changed an image, the video or a font?** Give it a new file name (e.g. `manish-sharma-2.jpg`) and update the HTML. Browsers keep assets for a day (fonts for a year) and do not ask again, so an overwritten file with the same name is not seen by returning visitors.

## Changing the infrastructure

Edit `aws/regatta-website.yaml` and apply it to the running stack with a **change set** — never "Update stack" directly. Step-by-step for non-engineers, what may and may not change, rollback and tests: [`aws/STACK-UPDATE.md`](aws/STACK-UPDATE.md). The first time, compare the file with the live stack's template (CloudFormation → `regatta-website` → **Template** tab) and make sure nothing changed by hand in the console is missing from the file.

## The domain

regatta.tech is registered at GoDaddy (since 10 Sep 2024, expires 10 Sep 2027); it was **not in the company GoDaddy account** that holds iditarod.bio. The domain's name servers point to the Route 53 hosted zone for regatta.tech in Iditarod's AWS account, where all its records live ($0.50/month). Make sure whoever holds the GoDaddy registration renews it before September 2027.

## Notes

- **Root `index.html` is an accidental duplicate** of `site/index.html` (added by a GitHub web upload on 3 Nov 2026). Only `site/` is published, so it is never served. It should be deleted once nobody needs the two kept in sync; until then, edit `site/index.html` and copy it over.
- `site/_headers` is a Netlify-only file (cache rules for `assets/`), ignored on AWS and never uploaded. Those rules now live in `scripts/publish.sh`.
- `site/assets/og.png` (1200×630) is the preview image used by Slack, LinkedIn and X when the site is linked; regenerate it if the app screenshot changes.
- `site/privacy/index.html` is the privacy policy. It has no Contact section yet (company name, postal address, privacy email); a TODO comment marks where it goes.
