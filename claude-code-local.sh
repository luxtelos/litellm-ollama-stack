#!/usr/bin/env bash
# Claude Code launchers. Source this file (bash or zsh), e.g. add to ~/.zshrc:
#   source /path/to/litellm-ollama-stack/claude-code-local.sh
# Just shell shortcuts - they set env vars, then run `claude`.
#
# Needs (env vars, or ./.env.local next to this file):
#   BOX_HOST             LAN IP or hostname of the box running the stack
#   LITELLM_VIRTUAL_KEY  a virtual key made in the LiteLLM UI (never the master key)
#   LITELLM_URL          optional, default http://$BOX_HOST:4000
#   OLLAMA_URL           optional, default http://$BOX_HOST:11434

_lls_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
if [ -n "${ZSH_VERSION:-}" ]; then eval '_lls_dir="$(cd "$(dirname "${(%):-%x}")" && pwd)"'; fi
# shellcheck source=/dev/null
[ -f "$_lls_dir/.env.local" ] && source "$_lls_dir/.env.local"
unset _lls_dir

# Returns 1 (and prints what is missing) unless BOX_HOST/LITELLM_URL and LITELLM_VIRTUAL_KEY are set.
_lls_require() {
  local missing=""
  [ -n "${LITELLM_VIRTUAL_KEY:-}" ] || missing="$missing LITELLM_VIRTUAL_KEY"
  [ -n "${BOX_HOST:-}${LITELLM_URL:-}" ] || missing="$missing BOX_HOST"
  if [ -n "$missing" ]; then
    echo "claude-code-local: unset:$missing. Export them or put them in .env.local next to claude-code-local.sh (LITELLM_VIRTUAL_KEY = a virtual key from the LiteLLM UI)." >&2
    return 1
  fi
  LITELLM_URL="${LITELLM_URL:-http://$BOX_HOST:4000}"
  OLLAMA_URL="${OLLAMA_URL:-http://${BOX_HOST:-localhost}:11434}"
}

# 1) your Claude subscription, real Claude models
claude-sub() {
  unset ANTHROPIC_BASE_URL ANTHROPIC_AUTH_TOKEN ANTHROPIC_MODEL ANTHROPIC_SMALL_FAST_MODEL ANTHROPIC_API_KEY
  claude "$@"
}

# 2) through LiteLLM - fallback, cache, usage dashboard.  M=<model> to override
claude-proxy() {
  _lls_require || return 1
  export ANTHROPIC_BASE_URL="$LITELLM_URL"
  export ANTHROPIC_AUTH_TOKEN="$LITELLM_VIRTUAL_KEY"
  export ANTHROPIC_API_KEY=""
  export ANTHROPIC_MODEL="${M:-agent}"
  export ANTHROPIC_SMALL_FAST_MODEL="cloud-small"
  export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1
  echo "-> LiteLLM $LITELLM_URL  model=$ANTHROPIC_MODEL"
  claude "$@"
}

# 3) straight to ollama on the box, no proxy (debug only)
claude-ollama() {
  if [ -z "${BOX_HOST:-}${OLLAMA_URL:-}" ]; then
    echo "claude-code-local: unset: BOX_HOST (or OLLAMA_URL)." >&2
    return 1
  fi
  export ANTHROPIC_BASE_URL="${OLLAMA_URL:-http://$BOX_HOST:11434}"
  export ANTHROPIC_AUTH_TOKEN="ollama"
  export ANTHROPIC_API_KEY=""
  claude --model "${M:-gpt-oss:120b-cloud}" "$@"
}

# quick curl test against the proxy:  llm classify "is package.json config or source?"
llm() {
  _lls_require || return 1
  local model="$1"; shift
  curl -s "$LITELLM_URL/v1/chat/completions" \
    -H "Authorization: Bearer $LITELLM_VIRTUAL_KEY" -H "Content-Type: application/json" \
    -d "$(python3 -c 'import json,sys;print(json.dumps({"model":sys.argv[1],"messages":[{"role":"user","content":" ".join(sys.argv[2:])}]}))' "$model" "$@")" \
    | python3 -c 'import json,sys;print(json.load(sys.stdin)["choices"][0]["message"]["content"])'
}
