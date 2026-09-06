#!/usr/bin/env bash
# Can this box run the local tier on CPU? Run from your workstation. Do this FIRST.
#
# Target box comes from env vars (or ./.env.local next to this script):
#   BOX_HOST, BOX_USER, BOX_DEST, and optional BOX_SSH_KEY (default ~/.ssh/id_ed25519)
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

ssh -i "$BOX_SSH_KEY" "$BOX_USER@$BOX_HOST" 'bash -s' <<'REMOTE'
echo "=== cpu ==="; lscpu | grep -Ei "model name|^cpu\(s\)|thread|core|mhz|avx|flags" | head -8
echo "=== ram ==="; free -g
echo "=== gpu ==="; (nvidia-smi --query-gpu=name,memory.total --format=csv 2>/dev/null || echo "no nvidia gpu")
echo "=== disk ==="; df -h /usr/share/ollama "$HOME" 2>/dev/null
echo "=== docker ==="; docker --version; docker compose version
REMOTE
