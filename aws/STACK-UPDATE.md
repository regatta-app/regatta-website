# Applying template changes to the running stack

For anyone who needs to apply a new version of `aws/regatta-website.yaml` to the live stack `regatta-website` (us-east-1) — no engineering background needed. Always go through a **change set**: CloudFormation first shows exactly what it would change, and nothing happens until you press **Execute**.

Takes about 20 minutes, most of it waiting for CloudFront.

## 0. Before the first update: compare with what is running

On 9 Nov 2026 four fixes were made to the live stack before they were in the repo; the repo now has them (commit "Template: commit the four fixes applied live on 9 Nov"), but the file was rebuilt by hand. **Before the first update from this repo, someone technical must compare the two:**

1. CloudFormation → **Stacks** → `regatta-website` → **Template** tab. Copy the whole text into a file and save it as `live-template-<date>.yaml` on your computer. **Keep this file: it is your rollback.**
2. Compare it with the repo's `aws/regatta-website.yaml` *as of that commit* (e.g. `git diff --no-index live-template-<date>.yaml aws/regatta-website.yaml`, or any text-compare tool). The only differences should be the changes made after it in the repo (the form receiver, the security headers). Anything else that is in the live file but not in the repo was made by hand: bring it into the repo first, or the update will undo it.

## 1. Create the change set

1. AWS console, region **US East (N. Virginia) us-east-1**. **CloudFormation → Stacks →** `regatta-website`.
2. **Stack actions → Create change set for current stack**.
3. **Replace existing template → Upload a template file →** choose `aws/regatta-website.yaml` from the repo (download it from GitHub with the *Raw* → Save as… button, or use your clone). **Next**.
4. **Parameters:** leave every value as it is (DomainName, HostedZoneId, PilotNotifyEmail1, PilotNotifyEmail2 keep their current values). **Next**.
5. **Options:** change nothing. At the bottom tick **"I acknowledge that AWS CloudFormation might create IAM resources"** (the form function has a role; it is not changed). **Next**.
6. Change set name: e.g. `security-headers-and-form-2026-11`. **Create change set**. Wait until its status is **CREATE_COMPLETE** (refresh; under a minute).

## 2. Review it — this is the important step

Open the change set → **Changes** tab. Each row is a resource with an **Action** (Add / Modify / Remove) and a **Replacement** column (True / False / Conditional).

**Expected for the changes after 9 Nov (form receiver + security headers):**

| Resource (logical ID) | Action | Replacement | Why |
|---|---|---|---|
| `PilotFunction` | Modify | False | New form code, runtime Node.js 24 |
| `SecurityHeadersPolicy` | **Add** | — | New: HSTS, CSP and the other security headers |
| `Distribution` | Modify | False | Attaches the headers policy to both behaviours |

Nothing else. If the live stack is not exactly the repo's 9-Nov version you may also see `UrlFunction` (Modify, False) — fine only if step 0 explained it.

**STOP — do not execute — if any of these appears:**

- **Replacement: True** (or **Conditional**) on `SiteBucket`, `Distribution`, `Certificate`, `OriginAccessControl`, `PilotTopic`, `PilotSubscription1`/`2` or `PilotFunctionUrl`. Replacing the bucket or distribution takes the site down; a new certificate needs DNS validation again; a new topic or subscription means every recipient must confirm their email again (until then leads are not delivered).
- Action **Remove** on anything.
- `PilotFunctionUrlPermission` or `PilotFunctionInvokePermission` in the list at all (both are needed for the form; any change to them replaces them, and during the swap the form returns 403).

In that case **Delete** the change set (nothing has changed) and ask for help.

## 3. Execute

**Execute change set** → keep the default *Roll back all stack resources* on failure → **Execute change set**. Watch the **Events** tab. `Distribution` takes 5–15 minutes. Done when the stack status is **UPDATE_COMPLETE**.

The site stays online the whole time.

## 4. Test afterwards (5 minutes)

From any computer (Terminal or CloudShell):

```
curl -sI https://regatta.tech/home | grep -iE '^(HTTP|location)'
#   HTTP/2 301   location: /home/

curl -sI https://regatta.tech/home/ | grep -iE '^(HTTP|strict-transport|content-security|x-frame|x-content-type|referrer-policy|cache-control)'
#   HTTP/2 200, strict-transport-security: max-age=31536000, content-security-policy: default-src 'self'; ...,
#   x-frame-options: DENY, x-content-type-options: nosniff, referrer-policy: strict-origin-when-cross-origin,
#   cache-control: public, max-age=300, must-revalidate

curl -s -o /dev/null -w '%{http_code} %{redirect_url}\n' -X POST -d 'email=not-an-email' https://regatta.tech/api/pilot
#   303 https://regatta.tech/home/?error=email#meet

curl -s -o /dev/null -w '%{http_code} %{redirect_url}\n' https://regatta.tech/api/pilot
#   303 https://regatta.tech/home/
```

Then in a browser:

1. Open https://regatta.tech/ and https://regatta.tech/home/. Open the browser's developer console (right-click → Inspect → Console): there must be **no** red "Refused to load / Refused to execute … Content Security Policy" messages. The cover video plays; fonts look right; the menu opens on a phone.
2. **One real form submission** on https://regatta.tech/home/#meet with your own email and an accented organization, e.g. `Société d’Études – Test`. You must land on `/thanks/`, and within a minute the recipients get an email titled `Pilot request: Societe d'Etudes - Test (you@…)` whose body shows the organization with its accents. No IP address or browser line in it.
3. Lambda → Functions → `regatta-website-pilot-form` → *Runtime settings* shows **Node.js 24.x**.

If the form lands on `/home/?error=send#meet`: CloudWatch → Log groups → `/aws/lambda/regatta-website-pilot-form` → search `LEAD NOT EMAILED` for the submission and the error.

## 5. Rolling back

- **The update failed:** CloudFormation rolls back by itself to the previous state (status `UPDATE_ROLLBACK_COMPLETE`). Nothing to do except read the first red event in **Events** for the reason.
- **The update succeeded but something is wrong** (e.g. the site looks broken because of the CSP): repeat steps 1–3 with the `live-template-<date>.yaml` you saved in step 0 (or the previous version of the file from GitHub → *History*). Review the change set the same way: this time `SecurityHeadersPolicy` shows as **Remove**, which is expected.

## One-time steps outside the template

**Log retention (30 days).** The form function's log group already exists (it was created the first time the function ran), so it is not declared in the template — declaring it would make every update fail with "already exists". Set its retention once, in CloudShell (us-east-1):

```
aws logs put-retention-policy --log-group-name /aws/lambda/regatta-website-pilot-form --retention-in-days 30
```

The logs can hold the email and organization of a submission that could not be sent, so they should not be kept forever. (Chosen over importing the log group into the stack, which is an advanced, error-prone operation.)

**Optional: cap the form function's concurrency.** Limiting the function to e.g. 2 parallel runs caps the cost of a flood of bot submissions. It is *not* in the template because it fails on accounts with a low Lambda quota: AWS always keeps 100 units unreserved, and new accounts often have a total of only 10, so setting it would make the stack update fail and roll back. To check: Lambda console → **Dashboard** (or Service Quotas → AWS Lambda → *Concurrent executions*). Only if the account limit is at least 110: Lambda → `regatta-website-pilot-form` → Configuration → Concurrency → Edit → *Reserve concurrency* = `2`. (Two parallel runs are plenty for real visitors; a submission above the limit gets an error page.)
