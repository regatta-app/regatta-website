# regatta.tech on AWS (written 29 Oct 2026; in use since 9 Nov 2026)

> **Status.** Since 9 Nov 2026 regatta.tech is served from AWS with this template: stack `regatta-website` in us-east-1 (S3 + CloudFront + the `/api/pilot` form receiver), DNS in the Route 53 hosted zone for regatta.tech. Netlify is no longer used. Steps 1–7 below are the record of how it was set up; they are only needed again to rebuild from scratch. For changes to the running stack see [`STACK-UPDATE.md`](STACK-UPDATE.md); to publish site changes see the repo README (`scripts/publish.sh`).
>
> The one `<form>` in `site/home/index.html` must post to `action="/api/pilot"` with no `data-netlify` / `netlify-honeypot` attributes (Netlify Forms do nothing on AWS: every lead would be lost). `scripts/publish.sh` refuses to publish otherwise.

**Why.** regatta.tech (the public marketing site, not the Regatta app) was on a Netlify account that is hard to manage (no Netlify mail reaches the company inbox). The domain itself is under our control, so the site is hosted in Iditarod's AWS account and the domain points at it. The Netlify site was never touched; it simply stopped receiving traffic.

```
browser ── https://regatta.tech ──► CloudFront (ACM certificate) ──► S3 bucket (site files, private)
                                        │                 └─ /api/pilot ──► Lambda "regatta-website-pilot-form" ──► SNS ──► email
            www.regatta.tech ───────────┘  (301 redirect to regatta.tech)
DNS: GoDaddy keeps the domain registration; Route 53 serves the records.
```

**Files** (repo `regatta-app/regatta-website`):

| File | What it is |
|---|---|
| `site/` | The site as served: `index.html`, `home/`, `privacy/`, `thanks/`, `404.html`, `assets/`. |
| `aws/regatta-website.yaml` | CloudFormation template: bucket, certificate, CloudFront, URL redirects, form receiver. |
| `aws/website-aws-hosting-2026-10-29.md` | This guide. |
| `aws/STACK-UPDATE.md` | How to apply template changes to the running stack (change sets). |
| `scripts/publish.sh` | Uploads `site/` with the right caching and clears the CloudFront cache. |

**The "Request a pilot" form.** The one `<form>` in `site/home/index.html` posts to `/api/pilot`; CloudFront routes that path to a Lambda that checks the honeypot field, validates the email and publishes the submission (email and organization only) to an SNS topic, which emails it to the address(es) given as stack parameters. The visitor is redirected to `/thanks/`, or back to `/home/?error=email#meet` (invalid email) or `/home/?error=send#meet` (the email could not be sent; the submission is then in the function's CloudWatch log, see below). Each recipient gets one "AWS Notification - Subscription Confirmation" email and must click its link once, or they receive nothing.

**Cost.** Route 53 hosted zone $0.50/month plus cents per million queries; S3, CloudFront, Lambda and SNS a few cents a month at marketing-site traffic. The ACM certificate is free and renews itself.

---

## 0. Before you start (5 min)

- Have a clone of this repo (or open AWS CloudShell and `git clone https://github.com/regatta-app/regatta-website.git`). The site is the `site/` folder.
- Log in to GoDaddy and to the AWS console in another tab.
- In Terminal, write down what the domain has today (you will copy some of it):

```
dig regatta.tech +short
dig www.regatta.tech +short
dig regatta.tech MX +short
dig regatta.tech TXT +short
dig regatta.tech NS +short
```

## 1. Create the hosted zone in Route 53 (5 min)

Route 53 is global; the region menu doesn't matter here.

1. **Route 53 → Hosted zones → Create hosted zone.** Domain name `regatta.tech`, type **Public**, Create.
2. Open the new zone. It has two records: **NS** (four `awsdns-…` names) and **SOA**. Leave both. Copy the four NS values somewhere — step 3 needs them.
3. **Copy the current records so nothing breaks while the name servers change.** In GoDaddy go to *My Products → regatta.tech → DNS → Manage DNS* and recreate in Route 53 (**Create record**):
   - `regatta.tech` — type **A** — the IP(s) that `dig regatta.tech +short` printed (the Netlify ones). TTL 300.
   - `www` — type **CNAME** — the target that `dig www.regatta.tech +short` printed (`…netlify.app`). TTL 300.
   - Any **MX** and **TXT** records GoDaddy shows (SPF, Google/Microsoft verification, etc.) — same name, same value.
   - Skip GoDaddy's own **NS** and **SOA** rows and anything that is just a GoDaddy parking/forwarding default.

   This keeps the old site online through Route 53 until the moment you switch it in step 6.

## 2. Change the name servers at GoDaddy (3 min, then wait)

1. GoDaddy → *My Products → regatta.tech → DNS → Nameservers → Change → "I'll use my own nameservers"*.
2. Replace the two GoDaddy servers with the **four** `awsdns-…` names from step 1 (without the trailing dot if GoDaddy complains). Save; confirm the warning.
3. Wait until Terminal shows the AWS servers (usually 10–60 minutes, can be longer):

```
dig regatta.tech NS +short
```

   The site keeps working during this, because Route 53 serves the same records GoDaddy did.

## 3. Create the stack (about 20 min, mostly waiting)

1. In the AWS console switch the region to **US East (N. Virginia) us-east-1**. This stack must live there: CloudFront only accepts certificates created in that region. (The app stays in Oregon; nothing changes for it.)
2. **CloudFormation → Create stack → With new resources (standard) → Upload a template file** → `regatta-website.yaml` → Next.
3. Settings:
   - **Stack name:** `regatta-website`
   - **DomainName:** leave `regatta.tech`
   - **HostedZoneId:** paste the ID of the regatta.tech hosted zone (Route 53 → Hosted zones → regatta.tech → *Hosted zone ID*, starts with `Z`). It is a plain text field.
   - **PilotNotifyEmail1 / 2:** who receives the pilot requests (second one optional).
4. Next. On the options page tick **"I acknowledge that AWS CloudFormation might create IAM resources"** (the form Lambda needs a role). Next, **Submit**.
5. Watch the **Events** tab. `Certificate` sits in CREATE_IN_PROGRESS while AWS checks DNS — it adds two CNAME records to your hosted zone and waits for them to be visible. If step 2 has not finished propagating, it simply waits; it does not fail. CloudFront takes another 5–10 minutes. Done at **CREATE_COMPLETE**.
6. **Outputs** tab: note **BucketName**, **DistributionId**, **DistributionDomainName** (a `dxxxx.cloudfront.net` name) and **TestUrl**.

## 4. Upload the site (3 min)

In AWS CloudShell, from the repo clone:

```
scripts/publish.sh --dry-run BUCKET DISTRIBUTION_ID
scripts/publish.sh BUCKET DISTRIBUTION_ID
```

with **BucketName** and **DistributionId** from the Outputs tab. Do not upload through the S3 console: it sets no `Cache-Control`, would upload `_headers`/dotfiles, and makes it easy to drop the folder itself instead of its contents (the home page would then 404).

## 5. Test before touching DNS

Open **TestUrl** (`https://dxxxx.cloudfront.net`). The site should appear with its styles and images. Click through the menu. Fix any missing-file problem now (usually a wrong relative path in the HTML or a file that didn't upload).

## 6. Switch the domain (2 min, no downtime)

In **Route 53 → Hosted zones → regatta.tech**:

1. Click the **A** record for `regatta.tech` → **Edit record**. Turn on **Alias**, choose **Alias to CloudFront distribution**, pick your distribution (it appears once you click the box), Save.
2. Add **Create record**: name empty (apex), type **AAAA**, Alias on, Alias to CloudFront distribution, same distribution, Create.
3. Delete the **CNAME** record for `www` (select it → Delete record). Then **Create record**: name `www`, type **A**, Alias on, Alias to CloudFront distribution, Create. Add an **AAAA** for `www` the same way.
4. Within a few minutes `https://regatta.tech` serves the new site and `https://www.regatta.tech` redirects to it. Check from your phone on mobile data too (different DNS cache).

```
dig regatta.tech +short
curl -I https://www.regatta.tech
```

## 7. Afterwards

- Check the inbox of each notification address for "AWS Notification - Subscription Confirmation" and click **Confirm subscription**. Then send one test through the form on the live site; the email arrives within seconds.
- Tell Austin the site has moved and that the Netlify subscription can be cancelled whenever appropriate. Nothing on Netlify is needed any more.
- Set the log retention of the form function once (see `STACK-UPDATE.md`, "Log retention").
- Disconnect the old Netlify project from the GitHub repo: in the Netlify project's *Build & deploy* settings unlink the repository, or in GitHub (organization `regatta-app` → Settings → GitHub Apps → Netlify) remove this repo from the app's access. Its deploy-preview bot still comments on pull requests, and its previews use Netlify Forms, not `/api/pilot`.

---

## Day-to-day

**Publish a new version.** `scripts/publish.sh BUCKET DISTRIBUTION_ID` in CloudShell (try `--dry-run` first). It uploads with the right `Cache-Control` and creates the CloudFront invalidation for what changed. Details in the repo README.

**404 page.** `site/404.html`; the template sends missing pages to it.

**Pretty URLs.** Every page is a folder with an `index.html`: `regatta.tech/about/` serves `about/index.html`, and `regatta.tech/about` (no slash, no extension) is 301-redirected to `regatta.tech/about/`. There are no `about.html`-style files.

**Add or change who receives pilot requests.** CloudFormation → `regatta-website` → **Update** → **Use existing template** → change PilotNotifyEmail1/2 (tick "Use previous value" for the rest) → Submit. The new address gets a confirmation email to click. (Or add a subscription by hand in SNS → Topics → `regatta-website-pilot-requests`.)

**Switch it off.** CloudFormation → `regatta-website` → Delete. The bucket is kept on purpose (Retain) so the files aren't lost; empty and delete it in S3 if you really want it gone. The hosted zone is separate and stays.

## Caching and response headers

**Where `Cache-Control` comes from.** Nothing in the template sets `Cache-Control`: the default behaviour uses the managed **CachingOptimized** cache policy (edge TTL: min 1 s, default 24 h, max 1 year, and it obeys the object's own `Cache-Control`), and the security headers policy adds no caching header. The `public, max-age=300, must-revalidate` seen on `/` and `/home/` in production is therefore **S3 object metadata set when those files were uploaded** (`--cache-control` on `aws s3 cp`/`sync`). Files uploaded without it are sent with no `Cache-Control` at all (the edge then keeps them 24 h and browsers guess).

So the upload decides caching. `scripts/publish.sh` sets it per type:

| Files | `Cache-Control` | Why |
|---|---|---|
| `*.html` (and `sitemap.xml`, `robots.txt`) | `public, max-age=300, must-revalidate` | Same as production today; a change reaches everyone within 5 minutes even without an invalidation. |
| `assets/fonts/*` | `public, max-age=31536000, immutable` | Font files never change under the same name. |
| other `assets/*` (images, video, `fonts.css`), `favicon.ico` | `public, max-age=86400` | One day. |

The same thing by hand (AWS CloudShell, from the repo root):

```
aws s3 sync site/ s3://BUCKET/ --exclude "*" --include "assets/fonts/*" --exclude "assets/fonts/*.css" --cache-control "public, max-age=31536000, immutable"
aws s3 sync site/ s3://BUCKET/ --exclude "*" --include "assets/*" --include "favicon.ico" --exclude "assets/fonts/*.woff2" --cache-control "public, max-age=86400"
aws s3 sync site/ s3://BUCKET/ --exclude "*" --include "*.html" --include "sitemap.xml" --include "robots.txt" --cache-control "public, max-age=300, must-revalidate"
```

**Cache-busting.** An image or video that changes must get a **new file name** (as the team photo did: `manish-sharma.jpg` became `manish-sharma-2.jpg` in production) and the HTML updated to point at it; browsers that already have the old name keep it for up to a day. Fonts must always be renamed if they change (they are cached for a year, `immutable`). HTML is short-lived, but after a publish create a CloudFront invalidation for the changed pages (`/`, `/home/`, `/home/index.html`, …) or `/*` so the edge serves the new version at once. The first 1,000 invalidation paths a month are free; `/*` counts as one path.

**Security headers.** The template attaches a response headers policy (`<stack>-security-headers`) to every response, including `/api/*`:

- `Strict-Transport-Security: max-age=31536000` — one year, **without** `includeSubDomains` and without `preload`. `app.regatta.tech` is HTTPS, but other subdomains of regatta.tech are not known, and `includeSubDomains` would make browsers refuse plain HTTP on all of them for a year. Add it only once every subdomain is confirmed HTTPS.
- `X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY`, `Referrer-Policy: strict-origin-when-cross-origin`.
- `Content-Security-Policy: default-src 'self'; img-src 'self' data:; media-src 'self'; font-src 'self'; style-src 'self' 'unsafe-inline'; script-src 'self' 'unsafe-inline'; form-action 'self'; frame-ancestors 'none'; base-uri 'self'; object-src 'none'`. Everything on the site is same-origin; `'unsafe-inline'` is needed because the pages use inline `<style>`, `<script>` and `style=""` attributes. If a page ever loads something from another domain (analytics, a font CDN, an embedded video), the CSP must be extended or that resource is blocked — check the browser console for "Refused to load".
- `form-action 'self'` also applies to the form's redirect: the form only works on `https://regatta.tech` itself, not when testing through the `dxxxx.cloudfront.net` test address (the receiver redirects to `https://regatta.tech/thanks/`, a different origin there).

## If something fails

| What you see | What it means / what to do |
|---|---|
| Stack stuck on `Certificate` for more than ~40 min | The name servers haven't propagated yet (`dig regatta.tech NS +short` still shows GoDaddy) or the hosted zone isn't the one GoDaddy points to. Fix the name servers; the stack keeps waiting up to several hours. |
| Stack fails: "CNAMEAlreadyExists" on the Distribution | Another CloudFront distribution in the account already claims `regatta.tech`. Unlikely here; check CloudFront → Distributions. |
| TestUrl shows "AccessDenied" or a 404 page | `index.html` is not at the bucket root (uploaded inside a folder). Fix in S3 and retry. |
| Site shows but no styles/images | Paths in the HTML point to files that didn't upload, or are absolute paths from the old host. Check the browser's Network tab for the 404s. |
| `regatta.tech` still shows the Netlify site after step 6 | Your computer's DNS cache. On a Mac: `sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder`; or test from a phone on mobile data. |
| Certificate warning in the browser | You opened the site before step 6 finished, or the AAAA record is missing. Make sure all four alias records (A and AAAA for apex and www) point at the distribution. |
| Form submits but no email arrives | The SNS subscription was never confirmed (check spam for the confirmation mail; or SNS → Topics → the topic → Subscriptions shows "Pending confirmation"). If confirmed, look at CloudWatch → Log groups → /aws/lambda/regatta-website-pilot-form. |
| Visitor lands on `/home/?error=send#meet` | SNS refused the message. The submission is not lost: search the log group above for `LEAD NOT EMAILED`; the line holds the email and organization. Reply to that person by hand. |
| Form shows a CloudFront error page | The `/api/*` behaviour or the Lambda URL origin is missing from the distribution; compare with the template. |
