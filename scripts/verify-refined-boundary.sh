#!/bin/sh

set -eu

PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$PROJECT_DIR"

CSS_PATH="resource/static/refined/refined.css"
LOADER_PATH="resource/static/refined/refined-loader.js"
COMMON_HEADER="resource/template/common/header.html"
PUBLIC_HEADER="resource/template/theme-default/header.html"
STANDALONE_TEMPLATES="
resource/template/dashboard-default/file.html
resource/template/dashboard-default/redirect.html
resource/template/dashboard-default/terminal.html
"
STYLESHEET_PATH="/static/refined/refined.css"
LOADER_PATH_URL="/static/refined/refined-loader.js"

fail() {
    echo "Refined boundary check failed: $*" >&2
    exit 1
}

[ -s "$CSS_PATH" ] || fail "$CSS_PATH is missing or empty"
[ -s "$LOADER_PATH" ] || fail "$LOADER_PATH is missing or empty"

for header in "$COMMON_HEADER" "$PUBLIC_HEADER"; do
    count=$(grep -F -c "$STYLESHEET_PATH" "$header" || true)
    [ "$count" -eq 1 ] || fail "$header must load the Refined stylesheet exactly once"
done

for template in $STANDALONE_TEMPLATES; do
    count=$(grep -F -c "$STYLESHEET_PATH" "$template" || true)
    [ "$count" -eq 1 ] || fail "$template must load the Refined stylesheet exactly once"
done

loader_count=$(grep -F -c "$LOADER_PATH_URL" "$PUBLIC_HEADER" || true)
[ "$loader_count" -eq 1 ] || fail "$PUBLIC_HEADER must load the Refined homepage loader exactly once"
grep -Fq 'id="refined-page-loader"' "$PUBLIC_HEADER" || fail "homepage loader markup is missing"

grep -Fq -- "--nz-accent:" "$CSS_PATH" || fail "design tokens are missing"
grep -Fq ".refined-page-loader" "$CSS_PATH" || fail "homepage loader styles are missing"
grep -Fq ".status.cards .ui.progress.fine .bar" "$CSS_PATH" || fail "status compatibility rule is missing"
grep -Fq "@media (prefers-reduced-motion: reduce)" "$CSS_PATH" || fail "reduced-motion support is missing"

if [ "${1:-}" != "" ]; then
    base_ref=$1
    git rev-parse --verify "$base_ref^{commit}" >/dev/null 2>&1 ||
        fail "base ref $base_ref is unavailable"

    unexpected=$(
        git diff --name-only "$base_ref"...HEAD |
            grep -Ev '^(\.env\.example|\.github/.*|\.gitignore|README\.md|compose\.refined\.yaml|docs/.*|install\.sh|refined-install\.sh|refined-update\.sh|cmd/dashboard/controller/member_api\.go|model/config\.go|resource/static/refined/.*|resource/static/public-note-editor\.css|resource/template/common/(header|menu)\.html|resource/template/dashboard-default/(file|login|redirect|server|setting|terminal)\.html|resource/template/theme-default/(header|home|menu|network|service)\.html|scripts/smoke-refined-image\.sh|scripts/verify-refined-boundary\.sh)$' ||
            true
    )

    [ -z "$unexpected" ] ||
        fail "files outside the presentation/deployment boundary changed:
$unexpected"
fi

echo "Refined presentation boundary verified."
