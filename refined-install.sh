#!/bin/sh

set -eu

PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ENV_FILE="${PROJECT_DIR}/.env"
COMPOSE_FILE="${PROJECT_DIR}/compose.refined.yaml"
DATA_CONFIG="${PROJECT_DIR}/data/config.yaml"

random_hex() {
    if command -v openssl >/dev/null 2>&1; then
        openssl rand -hex "$1"
        return
    fi

    od -An -N"$1" -tx1 /dev/urandom | tr -d ' \n'
}

env_value() {
    sed -n "s/^${1}=//p" "$ENV_FILE" | tail -n 1
}

fail() {
    echo "Install failed: $*" >&2
    exit 1
}

if ! command -v docker >/dev/null 2>&1; then
    echo "Docker is required. Install Docker Engine and Docker Compose, then run this script again." >&2
    exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
    echo "Docker Compose v2 is required." >&2
    exit 1
fi

if ! docker compose up --help 2>/dev/null | grep -q -- '--wait'; then
    echo "A current Docker Compose v2 with 'up --wait' support is required." >&2
    exit 1
fi

created_env=0
existing_config=0
[ -s "$DATA_CONFIG" ] && existing_config=1

if [ ! -f "$ENV_FILE" ]; then
    # 31 characters and four character classes; safe in a Compose env file.
    admin_password="Nz!$(random_hex 14)"
    grpc_secret=$(random_hex 18)
    umask 077
    {
        echo "REFINED_IMAGE=ghcr.io/aoomee/nezha-zero-refined:latest"
        echo "NZ_ADMIN=admin"
        echo "NZ_ADMIN_PASSWORD=${admin_password}"
        echo "NZ_SITE_NAME=Nezha Monitoring"
        echo "NZ_HTTP_PORT=10086"
        echo "NZ_GRPC_PORT=10086"
        echo "NZ_GRPC_HOST="
        echo "NZ_GRPC_SECRET=${grpc_secret}"
        echo "TZ=Asia/Shanghai"
    } > "$ENV_FILE"
    created_env=1
fi

chmod 600 "$ENV_FILE"

image_ref=$(env_value REFINED_IMAGE)
admin_password_value=$(env_value NZ_ADMIN_PASSWORD)
grpc_secret_value=$(env_value NZ_GRPC_SECRET)
http_port_value=$(env_value NZ_HTTP_PORT)
grpc_port_value=$(env_value NZ_GRPC_PORT)

[ -n "$image_ref" ] || fail "REFINED_IMAGE is missing in .env"
[ -n "$(env_value NZ_ADMIN)" ] || fail "NZ_ADMIN is missing in .env"
[ -n "$admin_password_value" ] || fail "NZ_ADMIN_PASSWORD is missing in .env"
[ -n "$grpc_secret_value" ] || fail "NZ_GRPC_SECRET is missing in .env"
[ -n "$http_port_value" ] || fail "NZ_HTTP_PORT is missing in .env"
[ -n "$grpc_port_value" ] || fail "NZ_GRPC_PORT is missing in .env"

if [ "$http_port_value" != "$grpc_port_value" ]; then
    fail "NZ_HTTP_PORT and NZ_GRPC_PORT must both use the same port (default: 10086)"
fi

case "$admin_password_value" in
    Change-*|replace-with-*) fail "replace the NZ_ADMIN_PASSWORD placeholder in .env" ;;
esac

case "$grpc_secret_value" in
    Change-*|replace-with-*) fail "replace the NZ_GRPC_SECRET placeholder in .env" ;;
esac

docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" pull
if ! docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" \
    up -d --wait --wait-timeout 180; then
    docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" \
        logs --tail=100 dashboard >&2 || true
    fail "dashboard did not become healthy within 180 seconds"
fi

http_port=$(env_value NZ_HTTP_PORT)
admin_user=$(env_value NZ_ADMIN)
grpc_host=$(env_value NZ_GRPC_HOST)

echo
echo "Nezha Zero Refined is healthy."
echo "Dashboard: http://127.0.0.1:${http_port:-10086}"

if [ "$created_env" -eq 1 ] && [ "$existing_config" -eq 0 ]; then
    echo "Admin user: ${admin_user:-admin}"
    echo "Admin password: ${admin_password}"
    echo "Credentials were saved to .env with owner-only permissions."
elif [ "$existing_config" -eq 1 ]; then
    echo "Existing data/config.yaml was kept; continue using its current login settings."
else
    echo "Existing .env was kept unchanged."
fi

if [ -z "$grpc_host" ]; then
    echo "Next step: set the public Agent address in Dashboard Settings before installing agents."
fi
