# Which models are worth running on CPU

Written for a mid-range desktop processor with four cores, 31 GB of RAM and no GPU. Adjust the sizes to
your own box; the reasoning holds at any scale.

## The one rule that predicts everything

CPU inference speed is bound by memory bandwidth, not by cores. Dual-channel DDR4 or DDR5 gives you
roughly 45 to 70 GB/s, so a rough estimate is:

```
tokens/second  ≈  memory bandwidth ÷ active model size in GB
```

The words "active model size" matter. A mixture-of-experts model activates only a fraction of its
parameters per token, which is why a 20B mixture-of-experts model outruns a dense 14B one despite being
larger on disk.

## What fits, and how fast

| model | size | fits in 31 GB | realistic speed | good for an agent loop? |
|---|---|---|---|---|
| qwen2.5:0.5b | 0.4 GB | yes | 60+ tok/s | no, and no tool calling |
| starcoder | 1.8 GB | yes | ~25 tok/s | no, completion only |
| qwen2.5-coder:3b | 1.9 GB | yes | ~20 tok/s | weak tool use; autocomplete and small edits |
| qwen2.5:7b | 4.7 GB | yes | ~8 tok/s | marginal |
| **gpt-oss:20b** | 13 GB | **yes** | **7 to 8 tok/s measured** | best local option, still slow |
| qwen2.5-coder:14b | 9 GB | yes | ~3.5 tok/s measured | too slow for agent loops |
| deepseek-r1:14b | 9 GB | yes | ~4 tok/s, and it thinks at length | painful |
| qwen3-coder:30b | 19 GB | tight | ~6 tok/s | not worth the disk |
| gpt-oss:120b | 65 GB | **no** | — | needs a GPU box or the cloud tier |
| the very large coding models | 600 GB+ | **no** | — | API only, always |

The two measured figures come from [health-and-throughput.md](health-and-throughput.md), which also
records the cold-load times: 134 seconds for the 20B and 87 seconds for the 14B. Cold load matters more
than you would expect, because on a box this size loading one model evicts another.

## The honest verdict

**Local is good for autocomplete, classification and one-shot questions.** The small models answer in
under a second, cost nothing, and never leave your network. If a job runs more than fifty times, it
belongs here.

**Local is not good for agent work.** One coding-agent task is twenty to sixty round trips, each reading
files and emitting tool calls. At 7 tokens per second with periodic two-minute reloads, a task the cloud
finishes in ninety seconds takes the better part of an hour. This is not a tuning problem; it is
arithmetic.

**So: local for the small stuff, cloud for the agent.** That split is exactly what the fallback chain in
`config.yaml` encodes, and it is why the job aliases exist.

## What to pull

1. `qwen2.5:0.5b` and `qwen2.5-coder:3b` — the job aliases run on these. Pull them regardless.
2. `nomic-embed-text` — 274 MB, embeddings for retrieval, free forever.
3. `gpt-oss:20b` — your local workhorse and the fallback when the cloud tier is unavailable, if you have
   16 GB free after the operating system.
4. Skip the 30B models and the reasoning-tuned 14B ones on CPU. They are not worth the disk.
5. For agent work itself, use the cloud tier: a flat-rate plan, or a per-token provider from
   [ollama-cloud-signup.md](ollama-cloud-signup.md).
