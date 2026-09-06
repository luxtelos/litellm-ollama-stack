# Measured behaviour and known quirks

Numbers below come from a real deployment on a modest CPU-only box: a 4-core, 8-thread desktop processor
with 31 GB of RAM and no GPU, running the stack in Docker with Ollama as a host systemd service. Your
figures will differ, but the shape of the result will not: CPU inference is bound by memory bandwidth,
not by core count.

## Model health

Checked one model at a time through the proxy after everything was configured.

| alias | model | result |
|---|---|---|
| `agent` | gpt-oss:120b (cloud) | healthy, 2.8 s |
| `cloud-big` | nemotron-3-super (cloud) | healthy, 13.4 s |
| `think` | nemotron-3-ultra (cloud) | cold start exceeded the 60 s health timeout |
| `vision` | gemma4:31b (cloud) | healthy, 31.8 s once the timeout was raised to 900 |
| `cloud-small` | nemotron-3-nano:30b (cloud) | healthy, 4.6 s |
| `local` | gpt-oss:20b | real requests succeed; health check exceeds 60 s while loading |
| `coder` | qwen2.5-coder:14b | same |
| `embed` | nomic-embed-text | healthy, 3.4 s |
| `classify` `extract` `gate` | qwen2.5:0.5b | healthy, 0.3 to 4.4 s |
| `commit` `docstring` `oneliner` `explain` | qwen2.5-coder:3b | healthy, 0.9 to 18.9 s |
| `autocomplete` | starcoder | healthy, 15.3 s |

The three entries that report a health failure are not broken models. They are models whose cold load
takes longer than the health check is willing to wait.

## Throughput

Prompt: "write a python function to reverse a string". Measured directly against Ollama, so these are the
model's own numbers rather than the proxy's.

| model | cold load | prompt tokens/s | generation tokens/s |
|---|---|---|---|
| gpt-oss:20b (`local`) | 134 s | 30.8 | 7.65 |
| qwen2.5-coder:14b (`coder`) | 87 s | 11.5 | 3.48 |

Through the proxy on a cold model, including that load time, the same requests worked out to 1.78 and
0.95 tokens per second end to end.

**What this means in practice.** The large local models are usable for a single question where you can
wait, and unusable for agent loops. One coding-agent task is twenty to sixty round trips; at 7 tokens per
second, with a two-minute reload every time the other model evicts it from memory, a task the cloud tier
finishes in ninety seconds takes the better part of an hour locally.

Note also that the mixture-of-experts 20B model beats the dense 14B despite being larger on disk, because
only a fraction of its parameters activate per token.

The small models are a different story entirely. The job aliases answer in 0.2 to 2 seconds and cost
nothing, which is the real argument for owning the box. Use the cloud tier for reasoning and the local
tier for volume.

## Quirk: the health tab reports false failures

`GET /health` checks every model at once. On a CPU-only box, Ollama then loads models one after another,
and most checks time out waiting their turn. A run that showed eight models unhealthy, including cloud
models that have nothing to do with local RAM, showed all of them healthy when checked one at a time.

Check individual models instead:

```bash
curl -s "http://<box>:4000/health?model=classify" -H "Authorization: Bearer <master key>"
```

You can enable `background_health_checks` with a long interval and a raised `health_check_timeout`, but
consider the cost first: every interval loads your largest models, evicting the small ones that were
answering in milliseconds, and stalls real requests for a minute or two while it does so. On a box this
size, leaving the health tab unreliable is usually the better trade.

## Quirk: loopback requests from the box can stall

Requests issued **from the box's own shell** to `localhost:4000` or `127.0.0.1:4000` intermittently stall
for 68 or 130 seconds. Roughly three or four in ten. The stalled requests never appear in the LiteLLM log
even at debug level, and never reach Ollama.

In the same minutes, on the same models:

- from another machine on the LAN to the box's IP: 126 requests, zero stalls
- from inside the container to the proxy: zero stalls

So the request is being lost before it arrives. The durations match TCP SYN retransmission backoff rather
than any application timeout, and the host's counters showed a substantial number of SYN retransmits and
failed connection attempts. The path involved is `docker-proxy`, which handles published ports on
loopback; connections that instead traverse the bridge (from the LAN, or from inside the container via
`host.docker.internal`) are unaffected.

Ruled out by experiment: worker count, the HTTP transport library, Redis, and DNS.

**Workaround: on the box, use the LAN address rather than `localhost`.** Scripts that run on the box
should call `http://<box-lan-ip>:4000`. Clients elsewhere on the network are not affected at all, which
is why this never shows up in normal use.

If you want to chase it, these need root:

```bash
sudo iptables -S | grep -E 'INVALID|4000|DOCKER'
sudo conntrack -L | grep 'dport=4000'
sudo sysctl -w net.netfilter.nf_conntrack_tcp_be_liberal=1   # then retry; reversible with =0
```

## Tool calling

Verified working through the proxy on `gpt-oss:120b` (the `agent` alias). A coding agent pointed at the
proxy made genuine tool calls, listing a directory and reading a file, finishing in 18 seconds over three
turns.

The cost is worth planning for: that small task consumed roughly 54,000 tokens, because Ollama Cloud does
no prompt caching and every turn resends the whole context. A long session runs to hundreds of thousands
of tokens. On a flat-rate plan this only affects your session quota; on a metered provider it is the
dominant cost, and no change to this stack alters it.
