# Website board (regatta.tech)

The list of open work for the marketing site https://regatta.tech and this repository. Started 20 Nov 2026 on Daniela's request: website work no longer goes on the app board or the compliance board. Git history is its record.

**This repository is public. Anyone on the internet can read this board.**

## Rules

1. **What goes here:** everything about regatta.tech and this repository. Nothing about the app (`regatta-app/regatta`, its own board) or about compliance (its own board).
2. **Who writes:** Daniela and her Claude sessions (account A and account B). Everyone else on the team may update their own rows (Status and a dated note) or ask Daniela to.
3. **Who reads:** account A reads and watches this board. Account B updates it at the end of every website work session. Every Claude session that works on the website reads it at the start (`git pull` first) and updates it at the end.
4. **Status** is one of `To do`, `In progress`, `Waiting`, `Done`. A `Waiting` row names who it waits on. Notes are dated (`2026-11-20: ...`), newest last.
5. **Ids** are `W-001`, `W-002`, ... for tasks and questions alike, never reused. Next free id: **W-021**.
6. **No row is ever deleted.** A finished row moves to "Done" in one line that says where the evidence is (PR, commit).
7. **Never write here:** keys, passwords, AWS account numbers, bucket names, CloudFront distribution ids, ARNs, personal email addresses, personal folder paths, client names or private notes. They stay in Daniela's private notes.
8. **Visual decisions are Daniela's.** A row never decides for her; it asks her in "Questions".
9. **An "ok" to merge or publish is given by Daniela in chat**, never on this board (`.claude/CLAUDE.md`, rule 4).
10. Each row is the short version. The full text of a row moved from another board is in that board's git history, at the commit named in Source.

## Open

### Manish

| Id | Owner | Task | Status | Waiting on | Source | Notes |
|---|---|---|---|---|---|---|
| W-001 | Manish | Apply the form spam filter to the live AWS stack `regatta-website` with a change set (`aws/STACK-UPDATE.md`), run the tests in section 4b, tell Daniela. The code is merged (PR #24, main c2e181d) and the page already sends `elapsed`; the live form receiver still ignores it. | Waiting | Daniela (W-009) | moved from regatta app board t573, asset-pages 774756a | 2026-11-19: change set `form-spam-filter-2026-11` prepared, not executed; besides PilotFunction it showed PilotFunctionUrl Modify (Replacement Conditional) and Distribution Modify, and section 4b says stop on Conditional. Form tests 15 of 15 (`node aws/test-pilot-form.js`). 2026-11-20: that change set is OBSOLETE: the live stack changed today (publish role added, W-020); create a new one. Live template = commit 413e60a + the publish role; template on main 76d8131 = live + only the filter code. A preview with the main template showed PilotFunction Modify (Replacement False), PilotFunctionUrl Modify (Replacement Conditional), Distribution Modify (Replacement False); account B deleted it without executing. |

### Austin

| Id | Owner | Task | Status | Waiting on | Source | Notes |
|---|---|---|---|---|---|---|
| W-002 | Austin | One graphic per hero capability, like the biomarker selection graphic, for all five: centralize your data, identify responsive patients, draft biomarkers, identify cryptic toxicity, monitor external clinical programs. Needed: five graphics, five short paragraphs, five article links (blog / Substack, "Learn more"). | To do | | moved from regatta app board t593, asset-pages 774756a | 2026-11-20: assigned by Daniela; Austin said he would make them on 20 and 21 Nov. The hero cycles these five since PR #27 (live 20 Nov). Daniela's side builds the click-through (W-008). Same as item 4 of Manish's 20 Nov email. |

### Daniela and her sessions (account A, account B)

| Id | Owner | Task | Status | Waiting on | Source | Notes |
|---|---|---|---|---|---|---|
| W-003 | Daniela | Cookies and analytics for the website: what is wanted for analytics, a consent notice if one is needed, and the privacy page to match. (The app half stays on the app board.) | To do | | moved from regatta app board t433 (website half), asset-pages 774756a | 2026-11-09: planned for 10 Nov. 2026-11-20: checked on main 76d8131: no page loads analytics, and `/privacy/` says the site sets no cookies and uses no analytics. Whether analytics are wanted: not re-checked with Daniela. |
| W-004 | Daniela | Git fix protocol in `.claude/CLAUDE.md` (Team Sync 18 Nov): PR #20, docs only. | Waiting | Daniela (her ok in chat) | moved from regatta app board t565 (website half), asset-pages 774756a | App half (regatta #480) merged 20 Nov, stays on the app board. 2026-11-20: PR #20 still open on GitHub, head 89f1f4c4. |
| W-005 | Account B | Header logo is out of place while the window width changes. | To do | | Manish's email of 20 Nov 2026, item 1 | 2026-11-20: not reproduced yet. Visual: screenshots to Daniela before any merge. |
| W-006 | Account B | Publish through a request PR, because Claude cloud sessions cannot use the GitHub Actions API to start the "Publish" workflow. | In progress | | account B, 20 Nov 2026 | 2026-11-20: being prepared on branch `cuenta-b/publish-by-pr`; no PR yet. |
| W-007 | Account B | Read the result of the first dry run of the "Publish" workflow (W-020) before any real run. | In progress | | account B, 20 Nov 2026 | 2026-11-20: dry run launched, result pending. |
| W-008 | Daniela's sessions | Build the capability click-through on the home (graphic, short text, "Learn more") once the material arrives. | Waiting | Austin (W-002); Austin or Momo (W-013) | new, 20 Nov 2026, from app board t593 and Q24 | Visual: screenshots to Daniela before any merge. |

## Questions

| Id | Asked | From | To | Question | Source | Answer | Status |
|---|---|---|---|---|---|---|---|
| W-009 | 2026-11-19 | Manish | Daniela | Spam filter (W-001): is it safe to apply? The preview shows PilotFunctionUrl with Replacement Conditional (because it refers to the function's ARN); the code change keeps the function, so its address should not change, but the change set cannot prove it. Reply "execute" (Manish creates a fresh change set, checks it lists only those three rows, executes it, sends a test form) or say what to check first. | question part of regatta app board t573, asset-pages 774756a; restated 2026-11-20 with today's preview | | Open |
| W-010 | 2026-11-20 | Account B | Daniela | Header across the full width: yes or no? Only screenshots exist, no PR. | account B, 20 Nov 2026 | | Open |
| W-011 | 2026-11-20 | Account B | Daniela | Write these into the brand guide (account A keeps it)? (a) `/privacy/` section headings at 28 px; (b) form fields show focus only by a lighter underline colour (PR #32); (c) Playfair Display SC in place of Cormorant SC. | account B, 20 Nov 2026 | | Open |
| W-012 | 2026-11-11 | Daniela | Austin or Momo | Between 3 and 5 Nov the four stat figures on the home (3.1x, 79%, 17%, 45%) and their references were removed, and several lines rewritten, through GitHub web uploads. Was that on purpose? A yes is enough; nothing changes unless someone asks. | moved from regatta app board t480, asset-pages 774756a | No answer yet. Note 2026-11-20: the current home (redesign, PR #22) shows none of these figures (checked on main 76d8131); restorable from 241a9b6 if wanted. | Open |
| W-013 | 2026-11-20 | Daniela | Austin, Momo | One short text per line of the capabilities section, for a dropdown or click-through on each line (Austin's idea). Daniela designs it; the texts must come from Austin or Momo. | moved from regatta app board QUESTIONS.md Q24 (asked again from Q17), asset-pages 774756a | 2026-11-20 10:22: seen by Momo's manager session; Momo told. No texts yet. | Open |

**Answers for Daniela, to copy all at once:** copy this block, fill in after each colon, paste it into the chat; her session writes the answers into the rows.

```
W-009 spam filter, execute a fresh change set? :
W-010 header across the full width? :
W-011a brand guide, /privacy/ headings 28 px? :
W-011b brand guide, focus = lighter underline only? :
W-011c brand guide, Playfair Display SC replaces Cormorant SC? :
```

## Done

| Id | Owner | Task | Done | Source | Evidence |
|---|---|---|---|---|---|
| W-014 | Daniela | Splash: Enter became two buttons, Login (app.regatta.tech) and Product (/home/) | 2026-11-10 | moved from regatta app board t434, asset-pages 774756a | PR #13, 9e86fb7, live 10 Nov; replaced by the redesign (PR #22, 19 Nov) |
| W-015 | Daniela | UX/UI audit of regatta.tech | 2026-11-11 | moved from regatta app board t461, asset-pages 774756a | `docs/audit-2026-11-11.md` |
| W-016 | Daniela | The repo did not match the live `/home/` (live form posted to `/api/pilot`, repo had Netlify) | 2026-11-20 | moved from regatta app board t469, asset-pages 774756a | PRs #19, #21, #22 (live setup in main; `/home/` now redirects to `/`; the form posts to `/api/pilot`); live published from main 3f98469 on 20 Nov |
| W-017 | Daniela | Write down who owns which repository (Daniela owns this one) | 2026-11-18 | moved from regatta app board t548, asset-pages 774756a | PR #18 |
| W-018 | Manish | Accept the invitation to this repository | 2026-11-19 | moved from regatta app board t580, asset-pages 774756a | Manish accepted |
| W-019 | Account B | Published: hero cycles five capabilities (#27), "Open Regatta" button (#28), `site.css?v=` (#29), footer wordmark and link (#30), CSS and JS with a 5-minute cache (#31), focus by underline colour, no 1023 px breakpoint (#32) | 2026-11-20 | Daniela, 20 Nov 2026; Manish's email of 20 Nov, items 2 and 3 | main 3f98469, published 20 Nov |
| W-020 | Account B | Manual "Publish" workflow on GitHub and its AWS role | 2026-11-20 | Daniela, 20 Nov 2026 | PR #33, main 76d8131; role and OIDC provider created in the stack (change set with only two Add rows, executed 20 Nov 19:24 UTC); 4 repository variables set. Follow-ups W-006, W-007 |

## Related rows left on the app board

Not moved, because they are about the app (`app.regatta.tech`) and only mention the website: t432 and t455 (serving the app at app.regatta.tech; done), t460 (small app cleanups; its website item (d), "README still says Netlify", is already fixed in this repo), t478 (Momo's check of the 11 Nov audit; done). Read them on the app board, branch `asset-pages`, commit 774756a.
