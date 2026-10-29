# regatta.tech — marketing site

The public site at https://regatta.tech. This is **not** the Regatta app (that lives in `regatta-app/regatta`).

```
site/   the files that are served (index.html at the top; home/, evidence/, thanks/, 404.html, assets/)
aws/    how it is hosted: CloudFormation template + deploy guide
```

## Hosting (since 29 Oct 2026)

Iditarod's AWS account, region **us-east-1**, CloudFormation stack **`regatta-website`**:
S3 bucket (files) → CloudFront (CDN + certificate) → Route 53 (DNS for regatta.tech; the domain itself is still registered at GoDaddy).
The "Request a pilot" form posts to `/api/pilot`, a small Lambda that emails each submission through SNS.

Full instructions, day-to-day tasks and troubleshooting: `aws/website-aws-hosting-2026-10-29.md`.

## Publishing a change

1. Edit the files in `site/`, commit and push.
2. Upload the changed files to the stack's S3 bucket (same paths; they overwrite).
3. CloudFront → the distribution → Invalidations → Create invalidation → `/*`.

## Notes

- `site/_headers` is a leftover from Netlify (cache headers). It is harmless and ignored on AWS.
- The form originally used Netlify Forms (`data-netlify="true"`); the two `<form>` tags in `site/home/index.html` were changed to `action="/api/pilot"`. Keep that if the page is regenerated from the design tool.
- The footer links to `https://regatta.tech/privacy/`, which does not exist in `site/` yet.
