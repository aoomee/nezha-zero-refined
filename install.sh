#!/bin/sh

# Remote bootstrap entrypoint. Run with:
# curl -fsSL https://raw.githubusercontent.com/aoomee/nezha-zero-refined/main/install.sh | sudo sh
set -eu

REPOSITORY="https://github.com/aoomee/nezha-zero-refined.git"
INSTALL_DIR="${NEZHA_REFINED_DIR:-/opt/nezha-zero-refined}"

fail() {
    echo "Install failed: $*" >&2
    exit 1
}

if [ "$(id -u)" -ne 0 ]; then
    fail "run with: curl -fsSL https://raw.githubusercontent.com/aoomee/nezha-zero-refined/main/install.sh | sudo sh"
fi

if ! command -v git >/dev/null 2>&1; then
    if command -v apt-get >/dev/null 2>&1; then
        apt-get update
        apt-get install -y git
    else
        fail "Git is required. Install Git, then run this command again."
    fi
fi

if [ -d "$INSTALL_DIR/.git" ]; then
    git -C "$INSTALL_DIR" pull --ff-only
elif [ -e "$INSTALL_DIR" ]; then
    fail "$INSTALL_DIR already exists but is not a Nezha Zero Refined installation"
else
    git clone --depth=1 "$REPOSITORY" "$INSTALL_DIR"
fi

exec "$INSTALL_DIR/refined-install.sh"
