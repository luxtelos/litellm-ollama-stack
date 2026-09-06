# First run, in order

Do these one at a time. Each step is cheap to verify before you move on, and stopping early is a valid
outcome if the simpler setup already does what you need.

## 0. See what the box can handle

```bash
./hw-check.sh
```

Note the RAM figure. Under 16 GB, lean on cloud models and skip the large local ones entirely. See
[verdict.md](verdict.md) for what is worth pulling at each size.

## 1. Sign Ollama in to the cloud (on the box, once)

Only needed if you want the cloud tier. Skip it for a fully local setup.

```bash
ssh "$BOX_USER@$BOX_HOST"
ollama signin      # prints a URL; log in at ollama.com, a free account is enough
exit
```

## 2. Pull models (on the box)

```bash
ssh "$BOX_USER@$BOX_HOST"

# Small and instant. Pull these regardless: they power the job aliases.
ollama pull qwen2.5:0.5b
ollama pull qwen2.5-coder:3b
ollama pull nomic-embed-text

# Larger local models, only if hw-check said you have the RAM.
ollama pull gpt-oss:20b          # ~13 GB, mixture-of-experts, the best local option
ollama pull qwen2.5-coder:14b    # ~9 GB, dense, slower

ollama list
exit
```

Check the sizes in `ollama list`. A cloud pointer entry shows no size at all: pulling `<model>-cloud`
gives you a few hundred bytes that forward to Ollama's servers, not weights on your disk. If you want the
model running locally, pull the plain tag.

Or run `./pull-models.sh mid` from your workstation, which does the same thing over SSH.

## 3. Raise the Ollama context length

Agent tools need a large context and the default is small. Do not use `systemctl edit` interactively if
you are scripting this; write the drop-in directly:

```bash
sudo mkdir -p /etc/systemd/system/ollama.service.d
sudo tee /etc/systemd/system/ollama.service.d/override.conf >/dev/null <<'EOF'
[Service]
Environment="OLLAMA_CONTEXT_LENGTH=32768"
EOF
sudo systemctl daemon-reload && sudo systemctl restart ollama
systemctl show ollama -p Environment
```

If a drop-in already exists, merge with it rather than overwriting: these files often carry a long `PATH`
line that the service needs.

A larger context costs RAM for the key-value cache on every loaded model, and on a CPU-only box that adds
up quickly. Start at 32768. Raise it to 65536 only if you have headroom, and drop back down if a large
model stops loading.

## 4. Test without the proxy first

Prove the Ollama path works before adding anything in front of it:

```bash
curl "http://$BOX_HOST:11434/api/generate" \
  -d '{"model":"qwen2.5:0.5b","prompt":"say hi","stream":false}'
```

If that returns text, Ollama is healthy. If this is all you need, stop here.

## 5. Bring up LiteLLM

You want this for fallback between tiers, response caching, virtual keys with budgets, and a usage
dashboard.

The secrets live in `.env` **on the box**, not on your workstation. Run the deploy script; the first run
copies the stack over, creates `.env` there from the template, and stops without starting anything:

```bash
./deploy.sh
```

Fill in that file on the box, then run the script again:

```bash
ssh "$BOX_USER@$BOX_HOST"
# BOX_DEST is a variable on your workstation, not on the box: use the literal
# path deploy.sh just printed, for example
$EDITOR ~/litellm-stack/.env      # generate values with: openssl rand -hex 24
exit
./deploy.sh
```

The script refuses to start the stack while any value is still `CHANGE_ME`, and that refusal matters:
`POSTGRES_PASSWORD` is written into the database volume the first time Postgres starts and
`LITELLM_SALT_KEY` encrypts stored provider keys. Neither can be changed afterwards without destroying
data, so a stack brought up on the placeholders would have a database password that is published in this
repository.

Wait for the container to report healthy, then:

```bash
curl -s "http://$BOX_HOST:4000/health/liveliness"
```

## 6. Create a virtual key

Open `http://$BOX_HOST:4000/ui` and log in with `UI_USERNAME` and `UI_PASSWORD`. Create a virtual key
for your clients. Hand out virtual keys, never the master key: each one carries its own budget and can be
revoked on its own.

Test it:

```bash
curl -s "http://$BOX_HOST:4000/v1/chat/completions" \
  -H "Authorization: Bearer $LITELLM_VIRTUAL_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model":"classify","messages":[{"role":"user","content":"one word: is package.json config, test, or source?"}]}'
```

## 7. Point Claude Code at it

```bash
export ANTHROPIC_BASE_URL="http://$BOX_HOST:4000"
export ANTHROPIC_AUTH_TOKEN="$LITELLM_VIRTUAL_KEY"
export ANTHROPIC_API_KEY=""
export ANTHROPIC_MODEL=agent
export ANTHROPIC_SMALL_FAST_MODEL=cloud-small
claude
```

Ask it to list the files in a directory. If it actually calls a tool rather than describing one, the
chain works end to end.

## 8. Make it permanent

```bash
echo 'source /path/to/litellm-ollama-stack/claude-code-local.sh' >> ~/.zshrc
```

That gives you `claude-sub`, `claude-proxy` and `claude-ollama` as shell functions.

## 9. Lock it down

Work through [hardening-checklist.md](hardening-checklist.md) before you use this for anything real. The
defaults are LAN-trusting, and Ollama itself has no authentication whatsoever.
