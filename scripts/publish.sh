#!/usr/bin/env bash
# Publish site/ to the regatta.tech S3 bucket and refresh CloudFront.
#
# Run it in AWS CloudShell (us-east-1) from a clone of this repo:
#
#   git clone https://github.com/regatta-app/regatta-website.git && cd regatta-website
#   scripts/publish.sh --dry-run BUCKET DISTRIBUTION_ID   # look first
#   scripts/publish.sh BUCKET DISTRIBUTION_ID             # then publish
#
# BUCKET and DISTRIBUTION_ID are the BucketName and DistributionId outputs of
# the regatta-website CloudFormation stack. Nothing account-specific is stored
# in this public repo.
#
# Options:
#   --dry-run   show what would be uploaded and invalidated; change nothing
#   --delete    also delete files from the bucket that are no longer in site/.
#               Off by default: production pages (and browsers' cached copies
#               of them, for a few minutes) may still reference files that
#               are not in this repo, so deleting can break the live site.
#               The bucket is versioned, so a deleted file can be restored
#               from S3 -> bucket -> "Show versions".
#
# What it does:
#   1. Pre-flight checks; aborts if any fails (nothing is uploaded):
#      - site/home/index.html posts the form to /api/pilot and has no Netlify
#        form attributes (on AWS a Netlify form silently loses every lead);
#      - every /assets/... file referenced by the HTML exists in site/;
#      - the AWS CLI works and the bucket is reachable.
#   2. Uploads with per-type Cache-Control (HTML last, so new pages never
#      point at assets that are not there yet). Never uploads _headers or
#      dotfiles. Note: aws s3 sync skips files whose size and date did not
#      change, so to change only the Cache-Control of files already in the
#      bucket, touch them first (a fresh clone uploads everything anyway).
#   3. Creates one CloudFront invalidation for the files that changed
#      (or /* when more than 15 paths changed).
set -euo pipefail

usage() {
  sed -n '2,/^set -euo/p' "$0" | grep '^#' | sed 's/^# \{0,1\}//'
  exit 2
}

DRY_RUN=0
DELETE=0
ARGS=()
for a in "$@"; do
  case "$a" in
    --dry-run) DRY_RUN=1 ;;
    --delete) DELETE=1 ;;
    -h|--help) usage ;;
    -*) echo "Unknown option: $a" >&2; usage ;;
    *) ARGS+=("$a") ;;
  esac
done
[ "${#ARGS[@]}" -eq 2 ] || usage
BUCKET="${ARGS[0]#s3://}"
BUCKET="${BUCKET%/}"
DIST_ID="${ARGS[1]}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SITE="$ROOT/site"
HOME_PAGE="$SITE/home/index.html"

fail() { echo "ABORTED: $*" >&2; exit 1; }

# ---------- 1. Pre-flight ----------
[ -f "$SITE/index.html" ] || fail "$SITE/index.html not found."
[ -f "$HOME_PAGE" ] || fail "$HOME_PAGE not found."
grep -q 'action="/api/pilot"' "$HOME_PAGE" \
  || fail "site/home/index.html has no form with action=\"/api/pilot\". On AWS the form must post to /api/pilot or no lead ever arrives."
if grep -qiE 'data-netlify|netlify-honeypot' "$HOME_PAGE"; then
  fail "site/home/index.html still has Netlify form attributes (data-netlify / netlify-honeypot). Netlify Forms do nothing on AWS: every lead would be lost."
fi

missing=0
while IFS= read -r ref; do
  path="${ref%%[?#]*}"
  if [ ! -f "$SITE$path" ]; then
    echo "  missing: $path (referenced in the HTML)" >&2
    missing=1
  fi
done < <(grep -rhoE '(src|href|poster|data-src)="/assets/[^"]+"' "$SITE" --include='*.html' | sed -E 's/^[a-z-]+="//; s/"$//' | sort -u)
[ "$missing" -eq 0 ] || fail "the HTML references files that are not in site/ (see above)."

command -v aws >/dev/null || fail "the AWS CLI is not installed (use AWS CloudShell)."
aws sts get-caller-identity >/dev/null || fail "the AWS CLI has no working credentials."
aws s3api head-bucket --bucket "$BUCKET" >/dev/null 2>&1 || fail "bucket '$BUCKET' not found or not accessible."
aws cloudfront get-distribution --id "$DIST_ID" >/dev/null 2>&1 || fail "CloudFront distribution '$DIST_ID' not found or not accessible."
echo "Pre-flight OK: form posts to /api/pilot, no Netlify attributes, all referenced assets present."

# ---------- 2. Upload ----------
SYNC_OPTS=(--no-progress)
# Applied after each pass's own filters, because later filters win in aws s3 sync.
NEVER=(--exclude "_headers" --exclude ".*" --exclude "*/.*")
[ "$DRY_RUN" -eq 1 ] && SYNC_OPTS+=(--dryrun)
[ "$DELETE" -eq 1 ] && SYNC_OPTS+=(--delete)

LOG="$(mktemp)"
trap 'rm -f "$LOG"' EXIT

sync_pass() { # $1 = Cache-Control, rest = filters
  local cc="$1"; shift
  aws s3 sync "$SITE/" "s3://$BUCKET/" "${SYNC_OPTS[@]}" "$@" "${NEVER[@]}" --cache-control "$cc" | tee -a "$LOG"
}

echo "== Fonts (1 year, immutable)"
sync_pass "public, max-age=31536000, immutable" --exclude "*" --include "assets/fonts/*.woff2"
echo "== Other files: images, video, CSS, icons (1 day)"
sync_pass "public, max-age=86400" --exclude "*.html" --exclude "sitemap.xml" --exclude "robots.txt" --exclude "assets/fonts/*.woff2"
echo "== Pages, sitemap.xml, robots.txt (5 minutes)"
sync_pass "public, max-age=300, must-revalidate" --exclude "*" --include "*.html" --include "sitemap.xml" --include "robots.txt"

# ---------- 3. Invalidate what changed ----------
PATHS=()
while IFS= read -r key; do
  PATHS+=("/$key")
  case "$key" in
    index.html) PATHS+=("/") ;;
    */index.html) PATHS+=("/${key%index.html}") ;;
  esac
done < <(sed -nE "s#^(\(dryrun\) )?(upload|delete): .* to s3://$BUCKET/(.*)\$#\3#p; s#^(\(dryrun\) )?delete: s3://$BUCKET/(.*)\$#\2#p" "$LOG" | sort -u)

if [ "${#PATHS[@]}" -eq 0 ]; then
  echo "Nothing changed; no invalidation needed."
  exit 0
fi
if [ "${#PATHS[@]}" -gt 15 ]; then
  PATHS=("/*")
fi

if [ "$DRY_RUN" -eq 1 ]; then
  echo "Dry run: would invalidate: ${PATHS[*]}"
  echo "Dry run finished; nothing was changed."
  exit 0
fi

echo "== Invalidating: ${PATHS[*]}"
aws cloudfront create-invalidation --distribution-id "$DIST_ID" --paths "${PATHS[@]}" \
  --query 'Invalidation.{Id:Id,Status:Status}' --output text
echo "Done. The new version is live within a minute or two (check https://regatta.tech/ in a private window)."
