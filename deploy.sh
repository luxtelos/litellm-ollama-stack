#!/usr/bin/env bash
# Push the whole docker stack to the box and bring it up. Run from your workstation, inside this folder.
#
# Target box comes from env vars (or ./.env.local next to this script):
#   BOX_HOST     LAN IP or hostname of the box
#   BOX_USER     ssh login on the box
#   BOX_SSH_KEY  private key (default ~/.ssh/id_ed25519)
#   BOX_DEST     directory on the box that holds the stack
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
[ -f "$SCRIPT_DIR/.env.local" ] && source "$SCRIPT_DIR/.env.local"
missing=()
for v in BOX_HOST BOX_USER BOX_DEST; do [ -n "${!v:-}" ] || missing+=("$v"); done
if [ "${#missing[@]}" -gt 0 ]; then
  echo "error: unset: ${missing[*]}. Required: BOX_HOST BOX_USER BOX_DEST (optional BOX_SSH_KEY). Export them or put them in $SCRIPT_DIR/.env.local" >&2
  exit 2
fi
BOX_SSH_KEY="${BOX_SSH_KEY:-$HOME/.ssh/id_ed25519}"
HOST="$BOX_USER@$BOX_HOST"
KEY="$BOX_SSH_KEY"
DEST="$BOX_DEST"

cd "$SCRIPT_DIR"

echo ">> creating remote dir"
ssh -i "$KEY" "$HOST" "mkdir -p $DEST/caddy"

echo ">> copying files"
scp -i "$KEY" docker-compose.yml config.yaml .env.example "$HOST:$DEST/"
scp -i "$KEY" caddy/Caddyfile "$HOST:$DEST/caddy/"

echo ">> checking .env on box (will NOT overwrite existing)"
# POSTGRES_PASSWORD is baked into the database volume on the FIRST start and
# LITELLM_SALT_KEY encrypts stored provider keys. Neither can be changed later
# without destroying data, so refuse to start the stack while either is still a
# placeholder rather than initialising a database with a password published in
# this repository.
if ! ssh -i "$KEY" "$HOST" "cd $DEST && [ -f .env ] || { cp .env.example .env && chmod 600 .env && exit 10; }"; then
  cat >&2 <<EOF

*** A fresh .env was created at $DEST/.env on the box, holding placeholder values. ***
*** Nothing was started. ***

Edit it on the box, fill in every value, then run this script again:

    ssh -i $KEY $HOST
    \$EDITOR $DEST/.env

Generate secrets with:  openssl rand -hex 24
EOF
  exit 3
fi

if ssh -i "$KEY" "$HOST" "cd $DEST && grep -qE '^(LITELLM_MASTER_KEY|LITELLM_SALT_KEY|POSTGRES_PASSWORD|UI_PASSWORD)=CHANGE_ME\$' .env"; then
  cat >&2 <<EOF

*** $DEST/.env on the box still contains CHANGE_ME placeholders. Refusing to deploy. ***

Fill in every value there, then run this script again. Generate them with:

    openssl rand -hex 24

POSTGRES_PASSWORD and LITELLM_SALT_KEY cannot be changed after the first start.
EOF
  exit 3
fi

echo ">> bringing stack up"
ssh -i "$KEY" "$HOST" "cd $DEST && docker compose pull -q && docker compose up -d"

sleep 12
echo ">> status"
ssh -i "$KEY" "$HOST" "cd $DEST && docker compose ps; curl -s -m 5 http://127.0.0.1:4000/health/liveliness; echo"
echo
echo "UI:  http://$BOX_HOST:4000/ui"
echo "API: http://$BOX_HOST:4000/v1"
