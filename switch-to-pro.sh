#!/usr/bin/env bash
# Run AFTER upgrading to Ollama Pro ($20/mo). Swaps the cloud tier to Pro-only models.
# Run from your workstation, inside this folder.
#
# Target box comes from env vars (or ./.env.local next to this script):
#   BOX_HOST, BOX_USER, BOX_DEST, and optional BOX_SSH_KEY (default ~/.ssh/id_ed25519)
#   LITELLM_VIRTUAL_KEY is only used to print the test command at the end.
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

echo ">> pulling Pro models on the box"
ssh -i "$KEY" "$HOST" '
ollama pull kimi-k2.7-code:cloud
ollama pull glm-5.3
ollama pull qwen3.5
ollama list
'

echo ">> patching config.yaml on the box"
ssh -i "$KEY" "$HOST" "cd $DEST && python3 - <<'PY'
p='config.yaml'
s=open(p).read()
# agent: gpt-oss:120b -> kimi-k2.7-code (best coding agent on Pro)
s=s.replace('model: openai/gpt-oss:120b','model: openai/kimi-k2.7-code')
# cloud-big: nemotron-3-super -> glm-5.3 (flagship coder)
s=s.replace('model: openai/nemotron-3-super','model: openai/glm-5.3')
# think: nemotron-3-ultra -> qwen3.5 (256K context, multimodal family)
s=s.replace('model: openai/nemotron-3-ultra','model: openai/qwen3.5')
open(p,'w').write(s)
print('patched')
PY"

echo ">> restarting"
ssh -i "$KEY" "$HOST" "cd $DEST && docker compose up -d --force-recreate litellm && sleep 15 && docker compose ps"
echo
echo "test:  curl -s http://$BOX_HOST:4000/v1/chat/completions -H 'Authorization: Bearer ${LITELLM_VIRTUAL_KEY:-<your-litellm-virtual-key>}' -H 'Content-Type: application/json' -d '{\"model\":\"agent\",\"messages\":[{\"role\":\"user\",\"content\":\"say hi\"}]}'"
