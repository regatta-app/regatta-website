# regatta.tech — marketing site

The public site at https://regatta.tech. This is **not** the Regatta app (that lives in `regatta-app/regatta`).

```
site/   the files that are served (index.html at the top; home/, evidence/, thanks/, 404.html, assets/)
aws/    plan B: CloudFormation template + guide to host the same files on AWS (not in use)
```

## Hosting

**Netlify**, project `regatta-website`, with the custom domain regatta.tech already attached. The project used to deploy from a third-party GitHub repo (an Astro build); that link was removed on 29 Oct 2026 and the site is now published from the plain files in `site/`.

The "Request a pilot" form uses Netlify Forms (`data-netlify="true"` on the two `<form>` tags in `site/home/index.html`); submissions show up under *Forms* in the Netlify project. Form name: `pilot`.

`site/_headers` sets long browser caching for `assets/` (Netlify reads it at deploy time).

## Publishing a change

1. Edit the files in `site/`, commit and push to `main`.
2. Netlify → project `regatta-website` → **Deploys** → scroll to "Need to update your project?" → drag the **`site`** folder (the folder itself, not its contents) onto the box. Live in a few seconds.

Or, once the project is linked to this repo (Netlify's free plan only links public repos, which is why this one is public): every push to `main` deploys automatically — publish directory `site`, no build command.

## The domain

regatta.tech is registered at GoDaddy (since 10 Sep 2024, expires 10 Sep 2027) but **not in the company GoDaddy account** (the one that holds iditarod.bio and the other company domains). Which GoDaddy account holds it is still unknown. DNS at that account points regatta.tech → Netlify (A 75.2.60.5, www CNAME regatta-website.netlify.app). Nothing needs to change there while the site stays on Netlify.

A Route 53 hosted zone for regatta.tech was created in Iditarod's AWS account (us-east-1) as part of the plan B on 29 Oct 2026; it costs $0.50/month and does nothing until the domain's name servers are pointed at it. Delete it if plan B is dropped.

## Notes

- The footer links to `https://regatta.tech/privacy/`, which does not exist in `site/` yet.
- `aws/` is a complete, tested-by-review alternative (S3 + CloudFront + ACM, plus a Lambda/SNS receiver for the form) for the day Netlify is no longer wanted; see `aws/website-aws-hosting-2026-10-29.md`.
