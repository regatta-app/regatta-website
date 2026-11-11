# regatta.tech — marketing site

The public site at https://regatta.tech. This is **not** the Regatta app (that lives in `regatta-app/regatta` and is served at app.regatta.tech, which nothing here touches).

```
site/       the files that are served (index.html at the top; home/, privacy/, thanks/, 404.html, assets/)
aws/        CloudFormation template for the hosting, the setup guide, and STACK-UPDATE.md
scripts/    publish.sh: upload site/ to S3 and refresh CloudFront
index.html  accidental duplicate of site/index.html (see Notes); not served
```

## Hosting

**AWS**, since 9 Nov 2026, all in the CloudFormation stack `regatta-website` (us-east-1) defined by [`aws/regatta-website.yaml`](aws/regatta-website.yaml):

- **S3** — a private, versioned bucket holds the files from `site/`. Only CloudFront can read it.
- **CloudFront** — serves regatta.tech with an ACM certificate, redirects `www.regatta.tech` to `regatta.tech`, redirects `/page` to `/page/` and serves `/page/` from `page/index.html`, adds the security headers (HSTS, CSP, …), and sends `/api/*` to the form receiver.
- **Lambda + SNS** — the "Request a pilot" form in `site/home/index.html` posts to `/api/pilot`. A small Lambda (Function URL behind CloudFront) checks the honeypot, validates the email and publishes the submission (email and organization only) to an SNS topic that emails it to the addresses set as stack parameters. The visitor goes to `/thanks/`, or back to `/home/?error=email#meet` (invalid email) or `/home/?error=send#meet` (sending failed; the submission is then in CloudWatch, log group `/aws/lambda/regatta-website-pilot-form`, line `LEAD NOT EMAILED`).
- **Route 53** — the DNS records for regatta.tech.

Caching is set per file when uploading (HTML 5 minutes, fonts one year, other assets one day); see "Caching and response headers" in [`aws/website-aws-hosting-2026-10-29.md`](aws/website-aws-hosting-2026-10-29.md).

**Netlify is no longer used.** The old Netlify project should be disconnected from this repo (its deploy-preview bot still comments on pull requests, and those previews use Netlify Forms, which never reach us): unlink the repository in the Netlify project's *Build & deploy* settings, or remove this repo from the Netlify GitHub App's access in the `regatta-app` organization settings. The Netlify subscription can then be cancelled.

## Publishing a change

1. Edit the files in `site/`, open a pull request, merge to `main`.
2. Open **AWS CloudShell** (AWS console, region US East (N. Virginia), the `>_` icon), then:

   ```
   git clone https://github.com/regatta-app/regatta-website.git   # first time; later: cd regatta-website && git pull
   cd regatta-website
   scripts/publish.sh --dry-run BUCKET DISTRIBUTION_ID
   scripts/publish.sh BUCKET DISTRIBUTION_ID
   ```

   `BUCKET` and `DISTRIBUTION_ID` are the **BucketName** and **DistributionId** on the Outputs tab of the `regatta-website` stack (CloudFormation console). They are not written in this public repo on purpose.

What `scripts/publish.sh` does:

- **Pre-flight, aborts before uploading anything** if `site/home/index.html` does not post the form to `action="/api/pilot"` or still has `data-netlify` / `netlify-honeypot` (a Netlify form on AWS silently loses every lead), or if the HTML references an `/assets/…` file that is not in `site/`.
- **Uploads** with `aws s3 sync` in three passes, each with its own `Cache-Control`: fonts `public, max-age=31536000, immutable`; images, video, CSS, icons `public, max-age=86400`; HTML, `sitemap.xml`, `robots.txt` `public, max-age=300, must-revalidate` (last, so pages never point at assets not yet uploaded). Never uploads `_headers` or dotfiles.
- **Does not delete** files from the bucket unless you pass `--delete`. Production pages, and copies of them that browsers and CloudFront still hold for a few minutes, can reference files that are no longer in the repo (for example a renamed photo); deleting them would break those pages. The bucket is versioned, so a file deleted by mistake can be restored (S3 → bucket → *Show versions*).
- **Invalidates** in CloudFront the paths it uploaded (a page's `index.html` and its `/folder/` URL), or `/*` when more than 15 changed. Within a minute or two everyone gets the new version.
- `--dry-run` shows all of this without changing anything.

**Changed an image, the video or a font?** Give it a new file name (e.g. `manish-sharma-2.jpg`) and update the HTML. Browsers keep assets for a day (fonts for a year) and do not ask again, so an overwritten file with the same name is not seen by returning visitors.

## Changing the infrastructure

Edit `aws/regatta-website.yaml` and apply it to the running stack with a **change set** — never "Update stack" directly. Step-by-step for non-engineers, what may and may not change, rollback and tests: [`aws/STACK-UPDATE.md`](aws/STACK-UPDATE.md). The first time, compare the file with the live stack's template (CloudFormation → `regatta-website` → **Template** tab) and make sure nothing changed by hand in the console is missing from the file.

## The domain

regatta.tech is registered at GoDaddy (since 10 Sep 2024, expires 10 Sep 2027); it was **not in the company GoDaddy account** that holds iditarod.bio. The domain's name servers point to the Route 53 hosted zone for regatta.tech in Iditarod's AWS account, where all its records live ($0.50/month). Make sure whoever holds the GoDaddy registration renews it before September 2027.

## Notes

- **Root `index.html` is an accidental duplicate** of `site/index.html` (added by a GitHub web upload on 3 Nov 2026). Only `site/` is published, so it is never served. It should be deleted once nobody needs the two kept in sync; until then, edit `site/index.html` and copy it over.
- `site/_headers` was removed: it was a Netlify-only file (cache rules for `assets/`), ignored on AWS. Those rules now live in `scripts/publish.sh`.
- `site/assets/og.png` (1200×630) is the preview image used by Slack, LinkedIn and X when the site is linked; regenerate it if the app screenshot changes.
- `site/privacy/index.html` is the privacy policy. It has no Contact section yet (company name, postal address, privacy email); a TODO comment marks where it goes.
