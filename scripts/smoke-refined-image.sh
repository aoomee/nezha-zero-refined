#!/bin/sh

set -eu

IMAGE=${1:?Usage: smoke-refined-image.sh IMAGE}
CONTAINER="nezha-refined-smoke-$$"
DATA_DIR=$(mktemp -d)

cleanup() {
    docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
    rm -rf "$DATA_DIR"
}
trap cleanup EXIT INT TERM

docker run -d --name "$CONTAINER" \
    -p 127.0.0.1:18080:80 \
    -v "${DATA_DIR}:/dashboard/data" \
    -e NZ_LANGUAGE=zh-CN \
    -e NZ_HTTPPORT=80 \
    -e NZ_GRPCPORT=5555 \
    -e NZ_GRPCDISCOVERKEY=refined-smoke-discovery-key \
    -e NZ_OAUTH2_ADMIN=admin \
    -e NZ_OAUTH2_DISABLEOAUTHLOGIN=true \
    -e NZ_SITE_THEME=default \
    -e NZ_SITE_ADMINPASSWORD='Nz!refined-smoke-2026' \
    -e NZ_SITE_DISABLEPASSWORDLOGIN=false \
    "$IMAGE" >/dev/null

attempt=0
while [ "$attempt" -lt 60 ]; do
    if curl --fail --silent --show-error http://127.0.0.1:18080/ >/dev/null 2>&1 &&
        curl --fail --silent --show-error \
            http://127.0.0.1:18080/static/refined/refined.css |
            grep -Fq -- '--nz-accent:'; then
        echo "Refined container smoke test passed."
        exit 0
    fi
    attempt=$((attempt + 1))
    sleep 2
done

docker logs "$CONTAINER" >&2 || true
echo "Refined container smoke test failed." >&2
exit 1
