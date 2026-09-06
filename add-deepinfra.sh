#!/usr/bin/env bash
# Adds a DeepInfra overflow tier. Run from your workstation, inside this folder.
# Usage: DEEPINFRA_KEY=xxxx ./add-deepinfra.sh
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
: "${DEEPINFRA_KEY:?set DEEPINFRA_KEY=... first}"
BOX_SSH_KEY="${BOX_SSH_KEY:-$HOME/.ssh/id_ed25519}"
HOST="$BOX_USER@$BOX_HOST"
KEY="$BOX_SSH_KEY"
DEST="$BOX_DEST"

ssh -i "$KEY" "$HOST" "cd $DEST && grep -q DEEPINFRA_API_KEY .env || echo 'DEEPINFRA_API_KEY=$DEEPINFRA_KEY' >> .env; chmod 600 .env"

ssh -i "$KEY" "$HOST" "cd $DEST && python3 - <<'PY'
p='config.yaml'
s=open(p).read()
block = '''
  # ================= OVERFLOW: DeepInfra (per-token, NO concurrency cap) =================
  # Ollama Pro caps at 3 concurrent. These have none - this is what parallel agents land on.
  - model_name: burst                    # [tools] same family as agent, metered
    litellm_params:
      model: deepinfra/openai/gpt-oss-120b
      api_key: os.environ/DEEPINFRA_API_KEY
      timeout: 600
      rpm: 300
    model_info:
      max_input_tokens: 128000

  - model_name: burst-small              # cheap worker tier for fan-out
    litellm_params:
      model: deepinfra/openai/gpt-oss-20b
      api_key: os.environ/DEEPINFRA_API_KEY
      timeout: 300
      rpm: 600

  - model_name: burst-kimi               # when you need the big coder in parallel
    litellm_params:
      model: deepinfra/moonshotai/Kimi-K2.6
      api_key: os.environ/DEEPINFRA_API_KEY
      timeout: 600
      rpm: 120

'''
s = s.replace('router_settings:', block + 'router_settings:', 1)
# spend flat-rate ollama quota first, burst to metered, land on free-but-slow local
s = s.replace('    - agent:       [\"cloud-big\", \"cloud-small\", \"local\"]',
              '    - agent:       [\"cloud-big\", \"burst\", \"burst-kimi\", \"local\"]')
s = s.replace('    - cloud-big:   [\"agent\", \"cloud-small\", \"local\"]',
              '    - cloud-big:   [\"burst\", \"agent\", \"local\"]')
s = s.replace('    - cloud-small: [\"local\", \"agent\"]',
              '    - cloud-small: [\"burst-small\", \"local\"]')
s = s.replace('    - think:       [\"cloud-big\", \"agent\", \"local\"]',
              '    - think:       [\"burst-kimi\", \"burst\", \"local\"]')
open(p,'w').write(s)
print('patched')
PY"

ssh -i "$KEY" "$HOST" "cd $DEST && docker compose up -d --force-recreate litellm && sleep 15 && docker compose ps"
