#!/usr/bin/env bash
# Inspect what is running on the box: ports, containers, ollama models, proxy health.
# Run from your workstation. Read-only, changes nothing.
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

ssh -i "$BOX_SSH_KEY" "$BOX_USER@$BOX_HOST" "bash -s -- '$BOX_DEST'" <<'REMOTE'
DEST=$1
echo "=== host ==="; hostname; uname -a
echo "=== listening ports ==="; (ss -tlnp 2>/dev/null || netstat -tlnp 2>/dev/null) | grep -E "4000|11434|8000|3000|8080|1234|5000"
echo "=== docker ==="; docker ps --format '{{.Names}}\t{{.Image}}\t{{.Ports}}' 2>/dev/null
echo "=== systemd units ==="; systemctl list-units --type=service --state=running 2>/dev/null | grep -Ei "litellm|ollama|vllm|openwebui|open-webui|llama|tabby|localai"
echo "=== binaries ==="; for b in litellm ollama vllm llama-server lm-studio; do command -v "$b"; done
echo "=== python pkgs ==="; (pip list 2>/dev/null; pipx list 2>/dev/null) | grep -Ei "litellm|openai|anthropic|vllm"
echo "=== stack dir ($DEST) ==="; ls -la "$DEST" 2>/dev/null
echo "=== config files ==="; ls -la ~/ 2>/dev/null | head -40
find / -maxdepth 5 \( -iname "*litellm*config*" -o -iname "litellm*.yaml" -o -iname "config.yaml" -path "*litellm*" \) 2>/dev/null | head -20
echo "=== ollama models ==="; ollama list 2>/dev/null
echo "=== proxy health ==="; curl -s -m 3 http://127.0.0.1:4000/health/liveliness; echo; curl -s -m 3 http://127.0.0.1:4000/v1/models | head -c 800
REMOTE
