# Where each model can live

This stack puts LiteLLM in front of whatever serves your models. That backend can be the box itself, a
GPU machine you own or rent, or a per-token API. This file is about choosing between those, because the
choice is usually driven by policy rather than by performance.

Prices move constantly. Treat every figure here as an order of magnitude and check the provider's own
page before budgeting.

## What it takes to self-host

| model class | open weights | roughly what it needs to self-host |
|---|---|---|
| 0.5B to 3B | yes | any CPU; runs on the box alongside everything else |
| 14B dense | yes | a 16 GB GPU, or CPU at a few tokens per second |
| 27B to 30B | yes | one 24 GB to 48 GB GPU |
| 120B mixture-of-experts | often | one 80 GB GPU, quantised. The practical sweet spot |
| 400B | sometimes | four 80 GB GPUs. Only at serious volume |
| 1T | occasionally | hundreds of GB even quantised. Effectively API-only |

The pattern: a mixture-of-experts model in the 100B class fits on a single large GPU once quantised, and
is the largest thing most teams can realistically run themselves. Above that you are renting a cluster.

Note that a mixture-of-experts model activates only a fraction of its parameters per token, so it runs
considerably faster than a dense model of the same size on disk. That is why the 120B class is viable at
all on one GPU.

## Option A: fully in-house

Nothing leaves your network. Run one dedicated GPU machine with vLLM and point LiteLLM at it.

This is the only arrangement where prompts never touch equipment you do not control, which is the whole
argument for it. It is also the most expensive per token unless the machine stays busy: a rented 80 GB
GPU running continuously costs well over a thousand dollars a month, and owning the hardware trades that
for a large one-off cost plus power and maintenance.

Choose this when a policy requires it, not to save money.

## Option B: per-token API

Sign up, copy the key into `.env` on the box, uncomment the provider's block in `config.yaml`. Live in
minutes, no servers. Providers and links are in [docs/ollama-cloud-signup.md](docs/ollama-cloud-signup.md).

Cost scales with use and nothing sits idle. At the cheap end of the market a 120B-class model runs a few
cents per million input tokens, so one developer's daily agent use typically lands in single dollars.
Verify current rates yourself; this is the fastest-moving number here.

The trade is that prompts leave your network. Read the provider's retention and training terms, and if
that matters to your organisation, get the commitment in a contract rather than from a marketing page.

## Option C: flat-rate subscription

A fixed monthly fee with limits expressed as concurrency and session quota rather than tokens. Its real
appeal is that you stop counting tokens, which matters more than it sounds: agent sessions resend their
whole context every turn, so token counts climb quickly and unpredictably.

Fastest to try. Same data-handling question as Option B.

## A reasonable progression

1. **Start on a free tier or flat-rate plan.** Prove that open models plus your tooling actually do the
   work before optimising anything.
2. **Move to per-token if volume is real and bursty.** It is usually cheaper than a subscription at low
   volume and has no concurrency cap, which matters when you run agents in parallel.
3. **Bring it in-house only if policy demands it**, and budget for a GPU sitting idle between requests.

Keep LiteLLM in front of all three. Switching backends is then a change to `config.yaml` rather than a
change to every client, and the fallback chain means one tier going down degrades instead of failing.
