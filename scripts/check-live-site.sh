#!/usr/bin/env bash
# Check that the live site serves exactly the files in site/.
#
#   scripts/check-live-site.sh [BASE_URL]     # default https://regatta.tech
#
# Used by the "Publish" workflow after a real publish; anyone can also run it.
# For every page, CSS and JS file in site/ it fetches the live URL
# (site/index.html -> /, site/privacy/index.html -> /privacy/,
# site/assets/site.css -> /assets/site.css, ...) and checks:
#   - the answer is 200;
#   - the bytes served are the same as the file (sha256);
#   - the home (/) has the form name="pilot", method="POST", action="/api/pilot".
# CloudFront takes a minute or two to drop its old copies after a publish, so
# it tries again every LIVE_WAIT seconds (default 20), LIVE_TRIES times
# (default 30, about 10 minutes), until everything matches.
# Exit 0 when everything matches, 1 otherwise. It never changes anything.
set -uo pipefail

BASE="${1:-https://regatta.tech}"
BASE="${BASE%/}"
TRIES="${LIVE_TRIES:-30}"
WAIT="${LIVE_WAIT:-20}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SITE="$ROOT/site"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mapfile -t FILES < <(cd "$SITE" && find . -type f \( -name '*.html' -o -name '*.css' -o -name '*.js' \) | sed 's#^\./##' | LC_ALL=C sort)
[ "${#FILES[@]}" -gt 0 ] || { echo "No pages found in site/."; exit 1; }

url_path() { # site-relative file -> URL path
  case "$1" in
    index.html) echo "/" ;;
    */index.html) echo "/${1%index.html}" ;;
    *) echo "/$1" ;;
  esac
}

check_once() {
  local bad=0 f p code want got
  : > "$TMP/report"
  for f in "${FILES[@]}"; do
    p="$(url_path "$f")"
    code="$(curl -sS -o "$TMP/body" -w '%{http_code}' --max-time 20 \
      -H 'Cache-Control: no-cache' -H 'Pragma: no-cache' "$BASE$p" 2>>"$TMP/curl.err" || true)"
    want="$(sha256sum "$SITE/$f" | cut -c1-64)"
    got="$( [ -f "$TMP/body" ] && sha256sum "$TMP/body" | cut -c1-64 || echo none)"
    if [ "$code" != "200" ]; then
      echo "FAIL $p: HTTP $code" >> "$TMP/report"; bad=1
    elif [ "$want" != "$got" ]; then
      echo "FAIL $p: served file differs from site/$f (CloudFront may still hold the old copy)" >> "$TMP/report"; bad=1
    else
      echo "ok   $p: 200, same as site/$f" >> "$TMP/report"
    fi
    if [ "$p" = "/" ] && [ "$code" = "200" ]; then
      tag="$(grep -oE '<form[^>]*name="pilot"[^>]*>' "$TMP/body" | head -n 1 || true)"
      if [ -n "$tag" ] && printf '%s' "$tag" | grep -q 'action="/api/pilot"' && printf '%s' "$tag" | grep -qi 'method="post"'; then
        echo "ok   /: pilot form posts (POST) to /api/pilot" >> "$TMP/report"
      else
        echo "FAIL /: no form name=\"pilot\" with method=\"POST\" action=\"/api/pilot\"" >> "$TMP/report"; bad=1
      fi
    fi
    rm -f "$TMP/body"
  done
  return "$bad"
}

for i in $(seq 1 "$TRIES"); do
  if check_once; then
    echo "Live check: everything matches ($BASE, attempt $i of $TRIES)."
    cat "$TMP/report"
    exit 0
  fi
  [ "$i" -lt "$TRIES" ] && sleep "$WAIT"
done
echo "Live check FAILED after $TRIES attempts ($BASE). Last result:"
cat "$TMP/report"
[ -s "$TMP/curl.err" ] && { echo "curl errors (last 5):"; tail -n 5 "$TMP/curl.err"; }
exit 1
