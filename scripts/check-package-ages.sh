#!/usr/bin/env bash
# SnapMark — Supply-Chain Age Gate
#
# Blocks any Swift Package dependency published less than MIN_AGE_DAYS ago.
# Run automatically before every build. Fail = build aborts.
#
# Rationale: malicious merges or account-takeover releases are usually
# identified by the community within a few days. Waiting 7 days before
# consuming a new package version avoids being an early victim.
#
# Usage:
#   ./scripts/check-package-ages.sh            # default: 7 days
#   ./scripts/check-package-ages.sh 14         # stricter: 14 days
#   GITHUB_TOKEN=ghp_xxx ./scripts/check-package-ages.sh  # higher rate-limit
#
# Exit codes: 0 = all packages pass, 1 = at least one is too new / hard error

set -euo pipefail

MIN_AGE_DAYS="${1:-7}"
MIN_AGE_SECONDS=$(( MIN_AGE_DAYS * 86400 ))
NOW=$(date -u +%s)
RESOLVED="${RESOLVED_PATH:-Package.resolved}"
FAILED=0
WARNINGS=0

# ── Colours (disabled when not a TTY) ──────────────────────────────────────
if [ -t 1 ]; then
    RED='\033[0;31m'; GREEN='\033[0;32m'
    YELLOW='\033[1;33m'; RESET='\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; RESET=''
fi

ok()   { echo -e "${GREEN}    ✓ OK${RESET}       — ${1} day(s) old"; }
fail() { echo -e "${RED}    ✗ BLOCKED${RESET}  — only ${1} day(s) old (must be ≥ ${MIN_AGE_DAYS})"; }
warn() { echo -e "${YELLOW}    ⚠ WARNING${RESET}  — ${1}"; }

# ── Parse ISO-8601 date → Unix epoch ───────────────────────────────────────
date_to_epoch() {
    python3 - "$1" <<'PYEOF'
import sys
from datetime import datetime, timezone

s = sys.argv[1]
for fmt in (
    "%Y-%m-%dT%H:%M:%SZ",
    "%Y-%m-%dT%H:%M:%S+00:00",
    "%Y-%m-%dT%H:%M:%S%z",
    "%Y-%m-%dT%H:%M:%S.%fZ",
):
    try:
        dt = datetime.strptime(s, fmt)
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        print(int(dt.astimezone(timezone.utc).timestamp()))
        sys.exit(0)
    except ValueError:
        pass
sys.exit(1)
PYEOF
}

# ── GitHub API helpers ──────────────────────────────────────────────────────
is_github() { echo "$1" | grep -qi "github\.com"; }

gh_repo_path() {
    echo "$1" | sed -E 's|.*github\.com[:/]||; s|\.git$||'
}

gh_curl() {
    local url="$1"
    local args=(-sf --max-time 15
        -H "Accept: application/vnd.github+json"
        -H "X-GitHub-Api-Version: 2022-11-28")
    if [ -n "${GITHUB_TOKEN:-}" ]; then
        args+=(-H "Authorization: Bearer $GITHUB_TOKEN")
    fi
    curl "${args[@]}" "$url" 2>/dev/null
}

# Return ISO date for a GitHub tag version (tries Releases API, then tag ref + commit)
github_tag_date() {
    local repo="$1" version="$2"
    local date_str=""

    # 1) GitHub Releases API (most reliable published_at timestamp)
    date_str=$(gh_curl "https://api.github.com/repos/${repo}/releases/tags/${version}" \
        | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('published_at',''))" 2>/dev/null) || true

    # 2) Annotated tag object → tagger date
    if [ -z "$date_str" ]; then
        local tag_sha
        tag_sha=$(gh_curl "https://api.github.com/repos/${repo}/git/ref/tags/${version}" \
            | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('object',{}).get('sha',''))" 2>/dev/null) || true

        if [ -n "$tag_sha" ]; then
            local tag_type
            tag_type=$(gh_curl "https://api.github.com/repos/${repo}/git/tags/${tag_sha}" \
                | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('type',''))" 2>/dev/null) || true

            if [ "$tag_type" = "tag" ]; then
                # Annotated tag: use tagger.date
                date_str=$(gh_curl "https://api.github.com/repos/${repo}/git/tags/${tag_sha}" \
                    | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('tagger',{}).get('date',''))" 2>/dev/null) || true
            else
                # Lightweight tag → commit date
                date_str=$(gh_curl "https://api.github.com/repos/${repo}/git/commits/${tag_sha}" \
                    | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('committer',{}).get('date',''))" 2>/dev/null) || true
            fi
        fi
    fi

    echo "$date_str"
}

# Return ISO date for a GitHub commit SHA
github_commit_date() {
    local repo="$1" sha="$2"
    gh_curl "https://api.github.com/repos/${repo}/git/commits/${sha}" \
        | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('committer',{}).get('date',''))" 2>/dev/null || true
}

# ── Fallback: shallow clone + git log ──────────────────────────────────────
git_date_for_ref() {
    local url="$1" ref="$2"   # ref = version tag or commit SHA
    local tmpdir date_str=""
    tmpdir=$(mktemp -d)
    trap 'rm -rf "$tmpdir"' RETURN

    if git clone --quiet --depth=1 ${ref:+--branch "$ref"} "$url" "$tmpdir/repo" 2>/dev/null; then
        date_str=$(git -C "$tmpdir/repo" log -1 --format="%cI" 2>/dev/null) || true
    fi
    echo "$date_str"
}

# ── Parse Package.resolved ─────────────────────────────────────────────────
parse_resolved() {
    python3 - "$1" <<'PYEOF'
import json, sys

with open(sys.argv[1]) as f:
    data = json.load(f)

# Support both Package.resolved v1 and v2
pins = data.get("pins", [])
for p in pins:
    url = p.get("location", p.get("repositoryURL", ""))
    state = p.get("state", {})
    version  = state.get("version", "")
    revision = state.get("revision", "")
    if url:
        print(f"{url}\t{version}\t{revision}")
PYEOF
}

# ── Entry point ─────────────────────────────────────────────────────────────
echo "══════════════════════════════════════════════════"
echo " SnapMark — Package Age Security Check"
echo " Minimum age: ${MIN_AGE_DAYS} day(s)"
echo "══════════════════════════════════════════════════"

if [ ! -f "$RESOLVED" ]; then
    echo ""
    echo -e "${GREEN}✓ No Package.resolved found — no external dependencies.${RESET}"
    exit 0
fi

PACKAGE_LIST=$(parse_resolved "$RESOLVED")

if [ -z "$PACKAGE_LIST" ]; then
    echo ""
    echo -e "${GREEN}✓ Package.resolved is empty — nothing to check.${RESET}"
    exit 0
fi

echo ""

while IFS=$'\t' read -r URL VERSION REVISION; do
    [ -z "$URL" ] && continue
    LABEL="${VERSION:-${REVISION:0:12}…}"
    printf "  %s @ %s\n" "$URL" "$LABEL"

    DATE_STR=""

    if is_github "$URL"; then
        REPO=$(gh_repo_path "$URL")
        if [ -n "$VERSION" ]; then
            DATE_STR=$(github_tag_date "$REPO" "$VERSION")
        fi
        if [ -z "$DATE_STR" ] && [ -n "$REVISION" ]; then
            DATE_STR=$(github_commit_date "$REPO" "$REVISION")
        fi
    fi

    # Non-GitHub or API unavailable → shallow clone
    if [ -z "$DATE_STR" ]; then
        REF="${VERSION:-$REVISION}"
        DATE_STR=$(git_date_for_ref "$URL" "$REF")
    fi

    if [ -z "$DATE_STR" ]; then
        warn "Could not determine publication date — skipping (treat as suspect if adding new dep)"
        (( WARNINGS++ )) || true
        continue
    fi

    EPOCH=$(date_to_epoch "$DATE_STR") || {
        warn "Unparseable date '${DATE_STR}' — skipping"
        (( WARNINGS++ )) || true
        continue
    }

    AGE=$(( NOW - EPOCH ))
    AGE_DAYS=$(( AGE / 86400 ))

    if [ "$AGE" -lt "$MIN_AGE_SECONDS" ]; then
        fail "$AGE_DAYS"
        (( FAILED++ )) || true
    else
        ok "$AGE_DAYS"
    fi

done <<< "$PACKAGE_LIST"

echo ""
echo "══════════════════════════════════════════════════"

if [ "$FAILED" -ne 0 ]; then
    echo -e "${RED}BLOCKED: ${FAILED} package(s) are too new (< ${MIN_AGE_DAYS} days old).${RESET}"
    echo "Do not use packages published less than ${MIN_AGE_DAYS} days ago."
    echo "Wait for the community to vet them, then re-run the build."
    exit 1
fi

if [ "$WARNINGS" -ne 0 ]; then
    echo -e "${YELLOW}PASSED with ${WARNINGS} warning(s) — review unresolvable packages manually.${RESET}"
else
    echo -e "${GREEN}✓ PASSED — all packages are at least ${MIN_AGE_DAYS} days old.${RESET}"
fi
