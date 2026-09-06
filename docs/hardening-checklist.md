# Hardening checklist

Work through this before the stack does anything real. The defaults assume a trusted LAN, and one of
them (Ollama's total lack of authentication) is a genuine hole rather than a soft default.

## 1. Pull the local models you actually reference

Any model named in `config.yaml` but absent from the box fails with a 404 that surfaces as
`APIConnectionError`. Check with `ollama list` and confirm each entry has a real size. An entry with no
size is a cloud pointer, not local weights: pulling `<model>-cloud` stores a few hundred bytes that
forward to Ollama's servers. Pull the plain tag if you want it running on your hardware.

## 2. Give cold-start models a long timeout

A large model loading from disk on a CPU-only box takes one to two minutes before it emits a single
token. If `timeout` is lower than that, the first request after an idle period always fails, and the
model looks broken when it is merely cold. Set `timeout: 900` on the large local entries and on any
cloud model that has shown a 408.

## 3. Raise the Ollama context length

```bash
sudo mkdir -p /etc/systemd/system/ollama.service.d
sudo tee /etc/systemd/system/ollama.service.d/override.conf >/dev/null <<'EOF'
[Service]
Environment="OLLAMA_CONTEXT_LENGTH=32768"
EOF
sudo systemctl daemon-reload && sudo systemctl restart ollama
```

Merge with any existing drop-in rather than overwriting it; these files often carry a `PATH` the service
depends on. Every increase costs key-value cache RAM per loaded model. Verify with `free -g` and
`ollama ps` under load, and fall back to a smaller value if a large model stops loading.

## 4. Firewall Ollama — do not bind it to loopback

**Ollama has no authentication.** Anyone who can reach port 11434 can run any model you have pulled and
read every prompt going through it. By default the service commonly listens on `0.0.0.0`.

The instinct is to set `OLLAMA_HOST=127.0.0.1`. **That breaks the stack**, and it is worth understanding
why rather than discovering it at runtime. The LiteLLM container reaches the host through
`host.docker.internal`, which Docker resolves to the bridge gateway address, not to loopback. Bind
Ollama to loopback and the container's route to it disappears, while the change looks like the safer
option.

Use a firewall instead. Keep Ollama on `0.0.0.0` and restrict who may reach it:

```bash
sudo ufw allow from 192.168.0.0/16 to any port 22     # do not lock yourself out
sudo ufw allow from 192.168.0.0/16 to any port 4000   # the proxy, LAN only
sudo ufw allow from 172.16.0.0/12 to any port 11434   # Docker bridges only
sudo ufw deny 11434
sudo ufw enable
```

Adjust the ranges to your own network. Verify from another machine that
`curl -m 5 http://<box>:11434/api/version` now fails, and that a request through LiteLLM to a local model
still succeeds. If the second check fails, find the container's actual bridge subnet with
`docker network inspect` and widen the allow rule to match.

## 5. Rotate the master key

`LITELLM_MASTER_KEY` is full admin over keys, spend and configuration. Never leave it at whatever you
first typed:

```bash
NEW="$(openssl rand -hex 24)"   # prefix it as LiteLLM requires, then:
# edit .env, replace LITELLM_MASTER_KEY, then
docker compose up -d --force-recreate litellm
```

Wait about 45 seconds, then confirm the old key returns 401 and the new one returns 200 on `/models`.
Virtual keys are hashed separately and keep working across a master key rotation.

Never touch `LITELLM_SALT_KEY` or `POSTGRES_PASSWORD` after first start. The salt key encrypts stored
provider keys and the Postgres password is baked into the database volume; changing either breaks
something that is tedious to recover.

## 6. Change the UI password

```bash
UI_PASSWORD="$(openssl rand -base64 18)"
```

Then recreate the container. A memorable admin password on a service that holds your API keys is not
worth the convenience.

## 7. Check what is actually exposed

Find the box's public address with `curl -s ifconfig.me` and test port 4000 **from outside your network**
(a phone on mobile data works). Then check three things that can each publish a port without your
noticing:

- `sudo ufw status verbose` — is the firewall even on?
- Any tunnel daemon (`cloudflared`, `tailscale`, `ngrok`) — check its ingress rules, since these publish
  ports without touching your router.
- Router port forwarding — this cannot be checked from the box itself. Look at the router.

Note that a box with a global IPv6 address is reachable over IPv6 even when IPv4 is behind NAT. If you
are unsure, publish the port on IPv4 only by binding `0.0.0.0:4000:4000` in the compose file.

## 8. Verify the chain end to end

```bash
# cloud tier
curl -s "http://$BOX_HOST:4000/v1/chat/completions" \
  -H "Authorization: Bearer $LITELLM_VIRTUAL_KEY" -H "Content-Type: application/json" \
  -d '{"model":"agent","messages":[{"role":"user","content":"say hi"}]}'

# local tier, timed
time curl -s "http://$BOX_HOST:4000/v1/chat/completions" \
  -H "Authorization: Bearer $LITELLM_VIRTUAL_KEY" -H "Content-Type: application/json" \
  -d '{"model":"local","messages":[{"role":"user","content":"write a python function to reverse a string"}]}'

# tiny local alias
curl -s "http://$BOX_HOST:4000/v1/chat/completions" \
  -H "Authorization: Bearer $LITELLM_VIRTUAL_KEY" -H "Content-Type: application/json" \
  -d '{"model":"classify","messages":[{"role":"user","content":"one word: is package.json config, test, or source?"}]}'
```

Run these from another machine on the LAN, not from the box's own shell. Requests from the box to
`localhost:4000` traverse the `docker-proxy` loopback path, where they can stall for over a minute for
reasons that have nothing to do with the proxy. See [health-and-throughput.md](health-and-throughput.md).

## 9. Confirm tool calling works

The whole point of the `agent` alias is driving a coding agent, and tool calling is the thing that most
often does not work through a proxy. Test it explicitly:

```bash
export ANTHROPIC_BASE_URL="http://$BOX_HOST:4000"
export ANTHROPIC_AUTH_TOKEN="$LITELLM_VIRTUAL_KEY"
export ANTHROPIC_API_KEY=""
export ANTHROPIC_MODEL=agent
claude -p "List the files in this directory and summarise the project."
```

Watch for an actual tool invocation, not a description of one. A model that only talks about listing
files has failed this test even when the prose looks right. If it fails, try the next model down before
concluding anything: tool-calling support varies more between models than between providers.

## 10. Back up before you change config

```bash
cp config.yaml "config.yaml.bak.$(date +%Y%m%d-%H%M)"
```

After any change to `config.yaml` or `.env`:

```bash
docker compose up -d --force-recreate litellm
sleep 15
docker compose ps
curl -s http://127.0.0.1:4000/health/liveliness
```

If it does not come up, read `docker compose logs --tail 50 litellm` before changing anything else.
