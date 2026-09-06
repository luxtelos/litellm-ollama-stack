#!/usr/bin/env bash
# Pull the open-weight models config.yaml expects, on the box. Run from your workstation.
# Pass tier as arg:  ./pull-models.sh small   (job aliases only, ~4.5 GB)
#                    ./pull-models.sh mid     (default: + gpt-oss:20b and qwen2.5-coder:14b, ~23 GB more)
#                    ./pull-models.sh heavy   (+ qwen3-coder:30b, needs ~32 GB RAM)
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

TIER=${1:-mid}
ssh -i "$BOX_SSH_KEY" "$BOX_USER@$BOX_HOST" "bash -s -- $TIER" <<'REMOTE'
set -e
TIER=${1:-mid}
echo ">> embeddings (tiny, always)"
ollama pull nomic-embed-text
echo ">> job-alias models (classify/extract/gate/commit/docstring/oneliner/explain/autocomplete)"
ollama pull qwen2.5:0.5b
ollama pull qwen2.5-coder:3b
ollama pull starcoder:latest
if [ "$TIER" = "mid" ] || [ "$TIER" = "heavy" ]; then
  echo ">> mid tier (local / coder aliases)"
  ollama pull gpt-oss:20b
  ollama pull qwen2.5-coder:14b
fi
if [ "$TIER" = "heavy" ]; then
  echo ">> heavy tier"
  ollama pull qwen3-coder:30b
fi
echo ">> final list"
ollama list
REMOTE
