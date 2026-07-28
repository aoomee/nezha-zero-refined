#!/bin/sh

set -eu

PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ENV_FILE="${PROJECT_DIR}/.env"
COMPOSE_FILE="${PROJECT_DIR}/compose.refined.yaml"
BACKUP_DIR="${PROJECT_DIR}/backups"
DATA_DIR="${PROJECT_DIR}/data"

env_value() {
    sed -n "s/^${1}=//p" "$ENV_FILE" | tail -n 1
}

if ! command -v docker >/dev/null 2>&1 ||
    ! docker compose up --help 2>/dev/null | grep -q -- '--wait'; then
    echo "Docker and a current Docker Compose v2 with 'up --wait' are required." >&2
    exit 1
fi

if [ ! -f "$ENV_FILE" ]; then
    echo "Missing .env. Run ./refined-install.sh first." >&2
    exit 1
fi

if [ ! -d "$DATA_DIR" ]; then
    echo "Missing data directory. Run ./refined-install.sh first." >&2
    exit 1
fi

image_ref=$(env_value REFINED_IMAGE)
image_ref=${image_ref:-ghcr.io/aoomee/nezha-zero-refined:latest}
old_image_id=$(docker inspect --format '{{.Image}}' nezha-zero-refined 2>/dev/null || true)

[ -n "$old_image_id" ] || {
    echo "The current nezha-zero-refined container was not found." >&2
    exit 1
}

docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" pull

timestamp=$(date +%Y%m%d-%H%M%S)
backup_file="${BACKUP_DIR}/data-${timestamp}.tar.gz"
failed_data="${PROJECT_DIR}/data.failed.${timestamp}"
mkdir -p "$BACKUP_DIR"

docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" stop dashboard
if ! docker run --rm --entrypoint tar \
    -v "${PROJECT_DIR}:/work" "$old_image_id" \
    -czf "/work/backups/data-${timestamp}.tar.gz" -C /work data; then
    docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" start dashboard || true
    echo "Update stopped because the data backup failed." >&2
    exit 1
fi

if docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" \
    up -d --remove-orphans --wait --wait-timeout 180; then
    echo "Nezha Zero Refined is healthy and updated."
    echo "Backup: $backup_file"
    exit 0
fi

echo "The new image failed its health check; restoring the previous image and data." >&2
docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" \
    logs --tail=100 dashboard >&2 || true
docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" down || true
mv "$DATA_DIR" "$failed_data"
docker run --rm --entrypoint tar \
    -v "${PROJECT_DIR}:/work" "$old_image_id" \
    -xzf "/work/backups/data-${timestamp}.tar.gz" -C /work
docker image tag "$old_image_id" "$image_ref"

if docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" \
    up -d --wait --wait-timeout 180; then
    echo "Rollback succeeded. Failed update data was kept at: $failed_data" >&2
else
    echo "Rollback also failed. Inspect Compose logs and restore $backup_file manually." >&2
fi

exit 1
