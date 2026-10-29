# regatta.tech on AWS — moving the marketing site off Netlify (29 Oct 2026)

**Why.** regatta.tech (the public marketing site, not the Regatta app) is on a Netlify account nobody can locate; the company pays for it from the HSBC account but no Netlify mail reaches daniela@iditarod.bio. The domain's DNS is at GoDaddy, so the domain itself is under our control. We host the new site in Iditarod's AWS account and point the domain at it. The Netlify site is never touched; it simply stops receiving traffic.

```
browser ── https://regatta.tech ──► CloudFront (ACM certificate) ──► S3 bucket (site files, private)
                                        │                 └─ /api/pilot ──► Lambda "regatta-website-pilot-form" ──► SNS ──► email
            www.regatta.tech ───────────┘  (301 redirect to regatta.tech)
DNS: GoDaddy keeps the domain registration; Route 53 serves the records.
```

**Files** (repo `regatta-app/regatta-website`, checked out at `Documents/Regatta/regatta-website/`):

| File | What it is |
|---|---|
| `site/` | The site as served: `index.html`, `home/`, `evidence/`, `thanks/`, `404.html`, `assets/`. |
| `aws/regatta-website.yaml` | CloudFormation template: bucket, certificate, CloudFront, URL redirects, form receiver. |
| `aws/website-aws-hosting-2026-10-29.md` | This guide. |

**The "Request a pilot" form.** The design used Netlify Forms, which only works on Netlify. On AWS the two `<form>` tags in `site/home/index.html` post to `/api/pilot`; CloudFront routes that path to a Lambda that checks the honeypot field, validates the email and publishes the submission to an SNS topic, which emails it to the address(es) given as stack parameters. Each recipient gets one "AWS Notification - Subscription Confirmation" email and must click its link once, or they receive nothing.

**Cost.** Route 53 hosted zone $0.50/month plus cents per million queries; S3, CloudFront, Lambda and SNS a few cents a month at marketing-site traffic. The ACM certificate is free and renews itself.

---

## 0. Before you start (5 min)

- Have the new site's folder on your Mac. Open it: `index.html` must be at its top level. If there is no `404.html`, that's fine (broken links will show a plain CloudFront error page; drop a `404.html` in later if you want a branded one).
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
   - **HostedZoneId:** pick `regatta.tech` from the list (`Z0337142YM9ANNYG6YXQ`).
   - **PilotNotifyEmail1 / 2:** who receives the pilot requests (second one optional).
4. Next. On the options page tick **"I acknowledge that AWS CloudFormation might create IAM resources"** (the form Lambda needs a role). Next, **Submit**.
5. Watch the **Events** tab. `Certificate` sits in CREATE_IN_PROGRESS while AWS checks DNS — it adds two CNAME records to your hosted zone and waits for them to be visible. If step 2 has not finished propagating, it simply waits; it does not fail. CloudFront takes another 5–10 minutes. Done at **CREATE_COMPLETE**.
6. **Outputs** tab: note **BucketName**, **DistributionId**, **DistributionDomainName** (a `dxxxx.cloudfront.net` name) and **TestUrl**.

## 4. Upload the site (3 min)

1. **S3 → Buckets →** the bucket from **BucketName** (starts with `regatta-website-sitebucket-`).
2. **Upload**. Open the site folder in Finder, select **everything inside it** (Cmd-A) and drag it onto the upload area. Don't drag the folder itself — that would put the site under `foldername/` and the home page would 404. Any subfolders (css, images, …) come along correctly.
3. Check that `index.html` is listed at the top level of the bucket, then **Upload**.

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
- Tell Austin the site has moved and that the Netlify subscription can be cancelled whenever the account turns up (the charge is visible in the HSBC statements). Nothing on Netlify is needed any more.
- Commit `regatta-website/` to its own GitHub repo (`regatta-app/regatta-website`).

---

## Day-to-day

**Publish a new version.** Upload the changed files to the same bucket (S3 → bucket → Upload; same names, they overwrite). Then clear the cache: **CloudFront → Distributions → your distribution → Invalidations → Create invalidation**, object path `/*`, Create. The new version shows within 1–2 minutes. (CloudFront caches pages for up to 24 hours otherwise.)

**Add a 404 page.** Upload a file named `404.html` to the bucket root. The template already sends missing pages to it.

**Pretty URLs.** `regatta.tech/about/` serves `about/index.html`; `regatta.tech/about` serves `about.html`. If the designer's export uses a different convention, tell Claude and the small function in the template gets adjusted.

**Add or change who receives pilot requests.** CloudFormation → `regatta-website` → **Update** → **Use existing template** → change PilotNotifyEmail1/2 (tick "Use previous value" for the rest) → Submit. The new address gets a confirmation email to click. (Or add a subscription by hand in SNS → Topics → `regatta-website-pilot-requests`.)

**Switch it off.** CloudFormation → `regatta-website` → Delete. The bucket is kept on purpose (Retain) so the files aren't lost; empty and delete it in S3 if you really want it gone. The hosted zone is separate and stays.

## If something fails

| What you see | What it means / what to do |
|---|---|
| Stack stuck on `Certificate` for more than ~40 min | The name servers haven't propagated yet (`dig regatta.tech NS +short` still shows GoDaddy) or the hosted zone isn't the one GoDaddy points to. Fix the name servers; the stack keeps waiting up to several hours. |
| Stack fails: "CNAMEAlreadyExists" on the Distribution | Another CloudFront distribution in the account already claims `regatta.tech`. Unlikely here; check CloudFront → Distributions. |
| TestUrl shows "AccessDenied" or a 404 page | `index.html` is not at the bucket root (uploaded inside a folder). Fix in S3 and retry. |
| Site shows but no styles/images | Paths in the HTML point to files that didn't upload, or are absolute paths from the old host. Check the browser's Network tab for the 404s. |
| `regatta.tech` still shows the Netlify site after step 6 | Your Mac's DNS cache. `sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder` or test from the phone. |
| Certificate warning in the browser | You opened the site before step 6 finished, or the AAAA record is missing. Make sure all four alias records (A and AAAA for apex and www) point at the distribution. |
| Form submits but no email arrives | The SNS subscription was never confirmed (check spam for the confirmation mail; or SNS → Topics → the topic → Subscriptions shows "Pending confirmation"). If confirmed, look at CloudWatch → Log groups → /aws/lambda/regatta-website-pilot-form. |
| Form shows a CloudFront error page | The `/api/*` behaviour or the Lambda URL origin is missing from the distribution; compare with the template. |
