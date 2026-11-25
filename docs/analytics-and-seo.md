# Analytics and technical SEO on regatta.tech

Added on 25 Nov 2026 (branch `seo-analytics-2026-11-25`). Daniela chose the tool and approved the event list.
Line numbers are as of that branch.

## 1. What is measured, and why

We want to know which parts of the site are useful and how visitors reach the "Request access" form.
We count in aggregate. We never identify a visitor.

| Event name | When it fires | Where (file:line) |
|---|---|---|
| pageview (automatic) | Every page load. Includes referrer and UTM tags (`utm_source`, `utm_medium`, `utm_campaign`, ...). | Umami script, loaded by `site/assets/analytics.js:35-41` |
| `request-access-sent` | `/thanks/` is reached: the form was sent. This is the main goal. The `/thanks/` pageview counts too. | `site/assets/analytics.js:44` |
| `request-access-hero` | Click on the hero "Request access" button. | mark: `site/index.html:347` |
| `request-access-form` | Click on the form's "Request access" button (also an attempt that fails validation). | mark: `site/index.html:464` |
| `open-app` {place: nav / footer} | Click on an "Open Regatta" link to app.regatta.tech. | marks: `site/index.html:330`, `:476`; `site/privacy/index.html:87`, `:207` |
| `chart-switch` {view: all / marker} | Click on the switch of the section 2 chart. The automatic switch is not counted. | marks: `site/index.html:365-366` |
| `contact-section-seen` | The form section (`#s6`) comes into view. Once per page view. | `site/assets/analytics.js:55-61` |
| `app-demo-seen` | The app demo (`#rgdemo`) comes into view. Once per page view. | `site/assets/analytics.js:55-61` |
| privacy page viewed | The `/privacy/` pageview. No extra event. | automatic |

Clicks are sent by one listener: `site/assets/analytics.js:47-52`. It reads `data-ev` (event name) and
`data-ev-place` / `data-ev-view` (event data) from the clicked element.

Why not Umami's own `data-umami-event` attribute: on links, Umami re-navigates to the link after it sends
the event. For `#s6` (the hero button) that would break the smooth scroll to the form.

Known limits:
- Keyboard use of the chart switch (arrow keys) is not counted. Clicks and taps are.
- A click on the form button right before the page changes may be lost. `request-access-sent` is the reliable count.
- `/thanks/` is also shown to a bot that fills the form in under 3 s. Compare with the emails received.

## 2. Umami setup

- Service: **Umami Cloud**, free (Hobby) plan, **EU data region**. Account created 25 Nov 2026 by Daniela's session, owner daniela@iditarod.bio (sign-in with Google). Website "Regatta website" (regatta.tech). Hobby plan: 100k events a month, 1 website, 6 months of history.
- Script host: `https://cloud.umami.is` (`site/assets/analytics.js:23`), as in the tracking code Umami shows.
  Events are sent to `https://gateway.umami.is/api/send` (the script's default). Both hosts are in the CSP (section 3).
- **Website id** goes in one place: `WEBSITE_ID` in `site/assets/analytics.js:22`.
  Today: `857cf497-e110-4348-9437-b0a28ec8c3c4`. The id is not secret: it is in every page that loads Umami.
- **Off by default.** While `WEBSITE_ID` is not a real id (a UUID), the script stops at once. No request
  goes to Umami. A merge by mistake sends nothing.
- **Turn it off later:** put any non-id text (e.g. `OFF`) in `WEBSITE_ID` and publish.
- Also not loaded:
  - on any host other than `regatta.tech` (local copies, previews);
  - when the browser sends **Do Not Track** or **Global Privacy Control** (`analytics.js:29`).
    We check this ourselves, so it works whatever Umami's own setting does. The script tag also
    carries `data-do-not-track="true"`.
- The script tag also carries `data-domains="regatta.tech"`.
- Pages that load `analytics.js`: home, privacy, thanks, 404 (one `<script defer>` in each `<head>`).
  `/home/` does not: it only redirects.

Order to switch it on:
1. Update the stack first (`aws/STACK-UPDATE.md`), so the CSP allows `cloud.umami.is` and `gateway.umami.is`.
   Until then the CSP blocks the script: nothing is sent, nothing breaks.
2. PR, Daniela's ok, publish.
3. Publish the privacy page text at the same time, or before. It must say we use analytics.

## 3. Headers and CloudFront (aws/regatta-website.yaml)

These change only with a **stack update**, not with `scripts/publish.sh`.

- **CSP** (`aws/regatta-website.yaml:419`): `https://cloud.umami.is` added to `script-src` and
  `https://gateway.umami.is` to a new `connect-src`. Why: the Umami script loads from the first and sends events
  to the second. Nothing else is allowed.
- **Permissions-Policy** (`aws/regatta-website.yaml:421-425`): `camera=(), microphone=(), geolocation=(), interest-cohort=()`.
  Why: the site uses none of these. `interest-cohort` opts out of FLoC. Chrome retired FLoC and may log a
  harmless console note about it.
- **`/home/` 301** (`aws/regatta-website.yaml:363-372`): `/home`, `/home/` and `/home/index.html` answer a
  permanent redirect to `/`, query kept. Why: one URL for the home, so search engines do not split it.
  - The form receiver still sends errors to `/home/?error=...#meet`. Browsers keep `#meet` across the redirect.
    The home maps the old anchors to the new sections (`site/index.html:562-566`): `#meet` -> `#s6`, and so on.
  - `site/home/index.html` stays as a fallback (client-side redirect) until the stack is updated.

## 4. Sitemap

- `site/sitemap.xml` lists `/` and `/privacy/`, each with `<lastmod>`.
- **Process:** `lastmod` is set **by hand**. When a PR changes the text of a page, set that page's
  `lastmod` to the day of the PR. Today both are `2026-11-25`.
- Why not automatic on publish: the Publish workflow uploads a fresh checkout of `main`. Rewriting the
  sitemap at publish time would make the live file differ from `main`, and the post-publish check
  (every file equals the one in `site/`) would fail.

## 5. Structured data (JSON-LD on the home)

One `<script type="application/ld+json">` in `site/index.html:28-63`, with three nodes:
- `Organization` (already there): name, url, logo, founder, parent company, contact point.
- `WebSite` (already there).
- `SoftwareApplication` (new): name "Regatta", description (the page's meta description), url,
  `applicationCategory: BusinessApplication`, publisher = the Organization.

Not added on purpose: price, offers, ratings, reviews, `sameAs`. None is on the site, so none can be
verified. There is no LinkedIn link on the site today. If one is added, it can go in `Organization.sameAs`.

## 6. Other changes

- Team photos (`site/index.html:440-441`): `loading="lazy"` and `decoding="async"`. Same files.
- Not done: a lighter format for the team photos. They are 15-18 KB JPEGs already.
- Not done: a longer cache for images and video. Their file names are not versioned
  (`entry-loop.mp4`, `austin-cole.jpg`). A longer cache would keep an old file in browsers after a change.

## 7. What is deliberately NOT measured

- No cookies. No localStorage or sessionStorage. Nothing stored on the visitor's device.
- No personal data in events: no email, no organization, no form text, no IP address.
  Event data is only `place` or `view`, fixed words from the page.
- No form field contents. The form posts to our own receiver only.
- Nothing in the app (app.regatta.tech). This file and `analytics.js` cover only regatta.tech.
- No advertising or social-media pixels. No session recording, no heatmaps.

## 8. How to check it works

Locally, before a PR:
1. Serve `site/` (for example `python3 -m http.server -d site 8000`). Open the home with the browser's
   Network tab. With the placeholder id: `analytics.js` loads, and **no** request goes to `umami.is`.
   `typeof window.umami` in the console is `"undefined"`.

After the stack update:
2. `curl -sI https://regatta.tech/ | grep -iE 'content-security|permissions-policy'` shows `cloud.umami.is`, `gateway.umami.is` and the Permissions-Policy.
3. `curl -sI 'https://regatta.tech/home/?error=email'` shows `301` and `location: /?error=email`.

After the real id is published:
4. Open https://regatta.tech/ in a private window **without** Do Not Track. Network tab: `cloud.umami.is/script.js`
   loads, then a request to `gateway.umami.is/api/send` for the pageview. Console: no red CSP message.
5. Click the hero button, switch the chart, scroll to the form, click "Open Regatta". Umami's dashboard
   (Events) shows `request-access-hero`, `chart-switch`, `contact-section-seen`, `app-demo-seen`, `open-app`
   within a minute.
6. Turn on Do Not Track and reload: no request to `umami.is`.
7. Optional: open `https://regatta.tech/?utm_source=test` and check the source appears in Umami.

## 8. Accounts and setup log (no passwords here)

- **Umami Cloud:** created 25 Nov 2026, owner daniela@iditarod.bio (Continue with Google), EU region, Hobby plan.
  Website "Regatta website", regatta.tech, id `857cf497-e110-4348-9437-b0a28ec8c3c4`.
- **Google Search Console:** Domain property `regatta.tech` already existed and was verified (owner
  daniela@iditarod.bio). Sitemap submitted 9 Nov 2026, status Success. No DNS change was needed.
- **Bing Webmaster Tools:** set up 25 Nov 2026 by import from Search Console (signed in with Google as
  daniela@iditarod.bio, view-only Search Console access). Sitemap submitted; Bing says up to 48 h to process.
- **Route 53:** not changed.
