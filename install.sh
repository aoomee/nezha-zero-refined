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

install_docker() {
    if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
        return
    fi

    if [ ! -f /etc/os-release ]; then
        fail "Docker is missing. Install Docker Engine with Docker Compose v2, then run this command again."
    fi

    . /etc/os-release
    case "${ID:-}" in
        debian|ubuntu) ;;
        *) fail "Automatic Docker installation currently supports Debian and Ubuntu. Install Docker Engine with Compose v2, then run this command again." ;;
    esac

    echo "Installing Docker Engine and Docker Compose v2..."
    apt-get update
    apt-get install -y ca-certificates curl
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL "https://download.docker.com/linux/${ID}/gpg" -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc
    arch=$(dpkg --print-architecture)
    codename=${VERSION_CODENAME:-}
    [ -n "$codename" ] || codename=$(awk -F= '/^UBUNTU_CODENAME=/{print $2}' /etc/os-release)
    [ -n "$codename" ] || fail "Could not determine this system's release codename."
    printf 'deb [arch=%s signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/%s %s stable\n' \
        "$arch" "$ID" "$codename" > /etc/apt/sources.list.d/docker.list
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    systemctl enable --now docker
}

if ! command -v git >/dev/null 2>&1; then
    if command -v apt-get >/dev/null 2>&1; then
        apt-get update
        apt-get install -y git
    else
        fail "Git is required. Install Git, then run this command again."
    fi
fi

install_docker

if [ -d "$INSTALL_DIR/.git" ]; then
    git -C "$INSTALL_DIR" pull --ff-only
elif [ -e "$INSTALL_DIR" ]; then
    fail "$INSTALL_DIR already exists but is not a Nezha Zero Refined installation"
else
    git clone --depth=1 "$REPOSITORY" "$INSTALL_DIR"
fi

exec "$INSTALL_DIR/refined-install.sh"
