# Regatta brand guidelines

Version 1.0, 18 Nov 2026. Owner: Daniela Morales. Applies to the app (app.regatta.tech) and the website (regatta.tech).

This is the single source for how Regatta looks. Every visual change, by any person or Claude session, stays inside it. If a change needs something that is not here, stop and ask Daniela. If she approves, this guide is updated first, then the change is made.

Visual version with live samples: https://claude.ai/artifact/2F2o25y278NPk1TqA33D7v

## 1. Logo

- The mark is the three sails in gold `#CAA229`, orange `#F05910` and navy `#0D3769`. Always these three colours. Source file: `app/brand/mark.svg`.
- No white or off-white sail. No white circle behind the mark. Never recolour it.
- Place it on cream or another light background so the navy sail stays visible.
- The word REGATTA is text set in the wordmark typeface, not an image.
- One written exception: the faint off-white sails in the background of the website hero.

## 2. Typefaces

| Role | App | Website |
|---|---|---|
| Headings | Tenor Sans 400 | Tenor Sans 400 |
| Text and interface | Open Sans | Inter |
| Wordmark REGATTA | Playfair Display SC | Playfair Display SC |

- The wordmark is the same in both products (Daniela, 18 Nov 2026). The website still shows Cormorant SC today; it changes to Playfair Display SC with the next approved website change.
- Fonts are self-hosted. No Google Fonts or other outside font links.
- No other typeface, ever. In the app, always go through the three font variables (`--fh`, `--fb`, `--fm`).

## 3. Type sizes

Only these sizes. No decimals. No new size without Daniela's OK.

**App (11 steps, px):**

| Size | Use |
|---|---|
| 11 | Labels |
| 12 | Meta, small notes |
| 13 | Secondary interface text |
| 14 | Interface text |
| 15 | Body |
| 17 | Lead |
| 19 | Small heading |
| 22 | Heading |
| 26 | Section heading |
| 36 | Page title |
| 44 | Display |

Existing one-off giant numerals (54, 72) stay where they are. New ones need Daniela's OK.

**Website (7 steps, px):**

| Size | Use | On phones |
|---|---|---|
| 13 | Caption | 13 |
| 15 | Small | 15 |
| 17 | Body | 17 |
| 20 | Lead | 20 |
| 28 | Sub-heading, quote | 24 |
| 44 | Every section title | 32 |
| 64 | Hero title | 40 |

**Weights:** 400 and 600 only, in both products. The website's 500 is retired.
**Line spacing:** 1.1 for display, 1.3 for headings, 1.6 for text.

## 4. Colour

**Brand**

| Name | Value | Use |
|---|---|---|
| Navy | `#0D3769` | Text, logo sail, buttons |
| Cream | `#F5EEE3` | Page background |
| Gold | `#CAA229` | Highlights, logo sail, dark-mode accent |
| Orange | `#F05910` | Logo and chart accents only |

Orange never goes on hover, focus or click states, and never on divider lines.

**App extras**

| Name | Value | Use |
|---|---|---|
| Signal | `#A93C0A` | Alert text |
| OK green | `#2E8B57` | Success |
| Gauge ramp | `#C75549` `#D98C6E` `#E8B7A0` `#F0D2C2` | Gauges only |
| Navy tints | 6, 9, 15, 20, 26, 74 % of navy | Lines, raised areas, secondary text |

Dark mode uses the set defined in `app/theme.css` (background `#01060F`, surface `#030F22`, raised `#0A2340`, text `#F5EEE3`, gold `#CAA229`, orange `#F05910`). Every colour used in the app must have a dark-mode value.

**Website extras**

| Name | Value | Use |
|---|---|---|
| Deep navy | `#071833` | Dark page background |
| Light text | `#F3F6FB` | Text on dark |
| Grey text | `#4E5A6B` | Secondary text |
| Line | `#C3CFDF` | Thin lines |
| Muted | `#8397B3` | Quiet text and icons |

**Retired.** Do not use: `#FF5A1F` (use Orange), `#7E8DA6` (use Muted), `#3A5BB0`, and any colour not listed above.

**Open:** `#9A5B00` (brown) is what a "queue full" note shows today in light mode in the app. Daniela decides its replacement.

## 5. Shape and spacing

- Corners: 10 (cards), 7 (inner elements), pill (999), circle.
- Spacing steps: 4, 8, 12, 16, 24, 32. Plus 2 and 6 for tight spots.
- Screen-width switch points: app 600, 760, 1100, 1280, 1600; website 460, 720.

## 6. Rules for changing the app

1. Colours come from the named variables. Never type a colour value by hand in new work.
2. Type sizes come from the scale in section 3. Typefaces come from the three font variables.
3. New styles go in the stylesheets as classes. No new inline styles written on elements.
4. Every new colour works in light and in dark mode.
5. Corners, spacing and switch points come from section 5.
6. The logo rules and the orange rule in sections 1 and 4 always apply.
7. Anything that changes what the reader sees needs Daniela's approval before a PR opens, with before and after captures: computer and phone, light and dark. The PR carries the line "FOR DANIELA TO REVIEW".
8. If a change needs something outside this guide, stop and ask Daniela. Do not invent a value "close enough".
9. Do not tidy old off-guide values in passing. Clean-ups are their own proposal, reviewed on their own.
10. Before a PR opens, run the brand check (`checks/check_brand.py`) on the changed lines and put its result in the PR.

## 7. Rules for changing the website

1. Rules 1, 2, 5, 6, 7, 8 and 9 above apply the same way.
2. Shared styles live in one stylesheet used by every page. A page does not carry its own copy of header, type or colour styles.
3. Every section title is 44 (32 on phones).
4. /thanks/ and 404 stay minimal: no header, no orange bar.
5. Texts on /home/ belong to Momo. Text problems are noted for her, not fixed.

## 8. Where the products break these rules today

Nothing below has been changed. Fixes come as separate proposals.

- Website: three section titles on /home/ at 48 instead of 44; orange divider lines on /home/; orange bar on /thanks/ and 404 in `#FF5A1F`; orange focus ring on the entry page; about 30 type sizes; weight 500 in 16 places; no shared stylesheet; wordmark in Cormorant SC.
- App: 24 type sizes; more than 200 sizes written directly on elements in the main shell file; off-scale corners (6, 8, 12, 14); 13 switch points; the old shell spec describes the logo with wrong colours.
