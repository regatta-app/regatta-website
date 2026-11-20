#!/usr/bin/env bash
# Check a publish request (publish/REQUEST.json) before anything touches AWS.
#
# Used by the "Publish" workflow when a push to main changes publish/REQUEST.json
# (see README.md, "Publishing a change", way C). Run from the root of a full
# clone (all history):
#
#   scripts/check-publish-request.sh BEFORE_SHA HEAD_SHA
#
# BEFORE_SHA is main before the push, HEAD_SHA main after it (the commit that
# is checked out and would be published).
#
# It stops with an error (exit 1, nothing published) unless ALL of this holds:
#   1. The push changed publish/REQUEST.json and nothing else: a request goes
#      to main alone, in its own pull request.
#   2. publish/REQUEST.json is valid JSON with exactly these four fields:
#        approved_sha  full 40-character lowercase sha of main that Daniela approved
#        dry_run       true or false (a real JSON boolean, not "true")
#        requested_on  date the request was written, YYYY-MM-DD (UTC, today or
#                      one day off; an old request brought back by a revert
#                      is refused)
#        daniela_ok    Daniela's ok, copied word for word from the chat
#   3. approved_sha is a commit of main's history (an ancestor of HEAD_SHA).
#   4. HEAD_SHA has exactly the same files as approved_sha, except
#      publish/REQUEST.json: what gets published (site/, scripts/publish.sh, this
#      workflow, everything) is what Daniela approved, byte for byte.
#   5. A real publish (dry_run false) only follows a dry run: before the push,
#      publish/REQUEST.json was a dry run for the same approved_sha, and that
#      dry run's "publish" check on GitHub finished with success.
#      (Needs GH_TOKEN and GITHUB_REPOSITORY, as in the workflow.)
#
# If the push deleted publish/REQUEST.json, nothing is published (exit 0,
# action=none).
#
# Writes action (publish|none), approved_sha and dry_run to $GITHUB_OUTPUT
# when that is set. TODAY (YYYY-MM-DD) may be set to test the date rule.
set -euo pipefail

REQ="publish/REQUEST.json"
err() { echo "::error::$*"; echo "Nothing was published." >&2; exit 1; }
out() { [ -n "${GITHUB_OUTPUT:-}" ] && echo "$1=$2" >> "$GITHUB_OUTPUT"; echo "  $1=$2"; }

[ "$#" -eq 2 ] || err "usage: $0 BEFORE_SHA HEAD_SHA"
BEFORE="$1"
HEAD_SHA="$2"
printf '%s' "$HEAD_SHA" | grep -qE '^[0-9a-f]{40}$' || err "HEAD sha '$HEAD_SHA' is not a full sha."
if ! printf '%s' "$BEFORE" | grep -qE '^[0-9a-f]{40}$' || [ "$BEFORE" = "0000000000000000000000000000000000000000" ]; then
  err "this push has no 'before' commit ('$BEFORE'), so it cannot be checked. A request must reach main through a merged pull request."
fi
git cat-file -e "$BEFORE^{commit}" 2>/dev/null || err "the commit before the push ($BEFORE) is not in this clone."
[ "$(git rev-parse HEAD)" = "$HEAD_SHA" ] || err "the checked-out commit is not $HEAD_SHA."

# ---- 1. the request goes alone ----
CHANGED="$(git diff --name-only --no-renames "$BEFORE" "$HEAD_SHA")"
if [ "$CHANGED" != "$REQ" ]; then
  echo "Files changed by this push:" >&2
  printf '%s\n' "${CHANGED:-  (none)}" | sed 's/^/  /' >&2
  err "a publish request must change $REQ and nothing else, in its own pull request. Merge the site change first, get Daniela's ok for the new sha of main, then open the request."
fi

if ! git cat-file -e "$HEAD_SHA:$REQ" 2>/dev/null; then
  echo "$REQ was removed by this push: nothing to publish."
  out action none
  exit 0
fi

# ---- 2. strict format ----
parse() { # $1 = commit; prints approved_sha and dry_run, or fails
  git show "$1:$REQ" | python3 -I -c '
import json, re, sys, datetime
raw = sys.stdin.buffer.read()
def bad(m):
    print("BAD: " + m); sys.exit(1)
if len(raw) > 4096: bad("the file is over 4 KB")
try: txt = raw.decode("utf-8")
except UnicodeDecodeError: bad("the file is not UTF-8")
def pairs(p):
    keys = [k for k, _ in p]
    if len(keys) != len(set(keys)): bad("a field appears twice")
    return dict(p)
def const(c): bad("not valid JSON (" + c + ")")
try: d = json.loads(txt, object_pairs_hook=pairs, parse_constant=const)
except json.JSONDecodeError as e: bad("not valid JSON: " + str(e))
if not isinstance(d, dict): bad("the file must hold one JSON object {...}")
want = {"approved_sha", "dry_run", "requested_on", "daniela_ok"}
if set(d) != want:
    bad("fields must be exactly approved_sha, dry_run, requested_on, daniela_ok (missing: %s; unknown: %s)"
        % (", ".join(sorted(want - set(d))) or "none", ", ".join(sorted(set(d) - want)) or "none"))
s = d["approved_sha"]
if not isinstance(s, str) or not re.fullmatch(r"[0-9a-f]{40}", s):
    bad("approved_sha must be the full 40-character lowercase sha")
if type(d["dry_run"]) is not bool: bad("dry_run must be true or false, without quotes")
r = d["requested_on"]
if not isinstance(r, str) or not re.fullmatch(r"\d{4}-\d{2}-\d{2}", r): bad("requested_on must be a date YYYY-MM-DD")
try: datetime.date.fromisoformat(r)
except ValueError: bad("requested_on is not a real date")
ok = d["daniela_ok"]
if not isinstance(ok, str) or not ok.strip() or len(ok) > 1000:
    bad("daniela_ok must be Daniela'"'"'s ok copied from the chat (1 to 1000 characters)")
print(s); print("true" if d["dry_run"] else "false"); print(r)
'
}
if ! P="$(parse "$HEAD_SHA")"; then err "$REQ: ${P#BAD: }"; fi
APPROVED="$(sed -n 1p <<<"$P")"
DRY_RUN="$(sed -n 2p <<<"$P")"
REQUESTED_ON="$(sed -n 3p <<<"$P")"
echo "Request: approved_sha=$APPROVED dry_run=$DRY_RUN requested_on=$REQUESTED_ON"

TODAY="${TODAY:-$(date -u +%F)}"
days=$(( ( $(date -u -d "$TODAY" +%s) - $(date -u -d "$REQUESTED_ON" +%s) ) / 86400 ))
if [ "$days" -gt 1 ] || [ "$days" -lt -1 ]; then
  err "requested_on is $REQUESTED_ON but today (UTC) is $TODAY. A request is valid only the day it is written (one day off is allowed). If this is an old request brought back (for example by a revert), it is refused on purpose: write a new request with Daniela's new ok."
fi

# ---- 3. approved_sha is in main's history ----
git cat-file -e "$APPROVED^{commit}" 2>/dev/null || err "approved_sha $APPROVED is not a commit of this repository."
git merge-base --is-ancestor "$APPROVED" "$HEAD_SHA" || err "approved_sha $APPROVED is not in the history of main."

# ---- 4. what is published is exactly what was approved ----
if ! git diff --quiet "$APPROVED" "$HEAD_SHA" -- . ":(exclude)$REQ"; then
  echo "Files that differ between the approved sha and main now:" >&2
  git diff --name-only "$APPROVED" "$HEAD_SHA" -- . ":(exclude)$REQ" | sed 's/^/  /' >&2
  err "main has changed since the approved sha $APPROVED. Get Daniela's ok for the current sha of main and write a new request."
fi
echo "main matches the approved sha $APPROVED (apart from $REQ)."

# ---- 5. a real publish only after a successful dry run of the same sha ----
if [ "$DRY_RUN" = "false" ]; then
  if ! PREV="$(parse "$BEFORE" 2>/dev/null)"; then
    err "a real publish must follow a dry run: before this push, $REQ was not a valid dry-run request for $APPROVED. Merge a dry-run request first and read its result."
  fi
  if [ "$(sed -n 1p <<<"$PREV")" != "$APPROVED" ] || [ "$(sed -n 2p <<<"$PREV")" != "true" ]; then
    err "a real publish must follow a dry run of the same sha: the previous request was approved_sha=$(sed -n 1p <<<"$PREV") dry_run=$(sed -n 2p <<<"$PREV"). Merge a dry-run request for $APPROVED first and read its result."
  fi
  : "${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is not set}"
  CONCLUSION="$(gh api "repos/$GITHUB_REPOSITORY/commits/$BEFORE/check-runs?check_name=publish&per_page=100" \
    --jq '[.check_runs[] | select(.app.slug == "github-actions")] | sort_by(.started_at) | last | .conclusion // "none"' 2>/dev/null || echo "unreadable")"
  if [ "$CONCLUSION" != "success" ]; then
    err "the dry run for $APPROVED (check 'publish' on commit $BEFORE) did not finish with success (it says: $CONCLUSION). Nothing real is published after a failed or missing dry run."
  fi
  echo "The dry run for $APPROVED on $BEFORE finished with success."
fi

out action publish
out approved_sha "$APPROVED"
out dry_run "$DRY_RUN"
