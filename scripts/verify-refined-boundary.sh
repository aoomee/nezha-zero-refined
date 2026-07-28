#!/bin/sh

set -eu

PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$PROJECT_DIR"

CSS_PATH="resource/static/refined/refined.css"
COMMON_HEADER="resource/template/common/header.html"
PUBLIC_HEADER="resource/template/theme-default/header.html"
STYLESHEET_URL="/static/refined/refined.css?v20260728"

fail() {
    echo "Refined boundary check failed: $*" >&2
    exit 1
}

[ -s "$CSS_PATH" ] || fail "$CSS_PATH is missing or empty"

for header in "$COMMON_HEADER" "$PUBLIC_HEADER"; do
    count=$(grep -F -c "$STYLESHEET_URL" "$header" || true)
    [ "$count" -eq 1 ] || fail "$header must load the Refined stylesheet exactly once"
done

grep -Fq -- "--nz-accent:" "$CSS_PATH" || fail "design tokens are missing"
grep -Fq ".status.cards .ui.progress.fine .bar" "$CSS_PATH" || fail "status compatibility rule is missing"
grep -Fq "@media (prefers-reduced-motion: reduce)" "$CSS_PATH" || fail "reduced-motion support is missing"

if [ "${1:-}" != "" ]; then
    base_ref=$1
    git rev-parse --verify "$base_ref^{commit}" >/dev/null 2>&1 ||
        fail "base ref $base_ref is unavailable"

    unexpected=$(
        git diff --name-only "$base_ref"...HEAD |
            grep -Ev '^(\.env\.example|\.github/.*|\.gitignore|README\.md|compose\.refined\.yaml|docs/.*|refined-install\.sh|refined-update\.sh|resource/static/refined/.*|resource/template/common/header\.html|resource/template/theme-default/header\.html|scripts/smoke-refined-image\.sh|scripts/verify-refined-boundary\.sh)$' ||
            true
    )

    [ -z "$unexpected" ] ||
        fail "files outside the presentation/deployment boundary changed:
$unexpected"
fi

echo "Refined presentation boundary verified."
