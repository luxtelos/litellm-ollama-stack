# Cloud backends: sign-up and pricing

The cloud tier is optional. Everything local works without any of this. You want a cloud key when you
need tool-calling agent work at a usable speed, which a CPU-only box cannot deliver (see
[verdict.md](verdict.md)).

Each provider is the same three steps: sign up, copy an API key, paste it into `.env` on the box and
uncomment its block in `config.yaml`.

## Providers

| provider | sign up | API keys page | pricing model |
|---|---|---|---|
| **Ollama Cloud** | <https://ollama.com/signup> | <https://ollama.com/settings/keys> | flat monthly subscription |
| **DeepInfra** | <https://deepinfra.com/dash> | <https://deepinfra.com/dash/api_keys> | per token, among the cheapest |
| **Novita** | <https://novita.ai/user/login> | <https://novita.ai/settings/key-management> | per token |
| **Baseten** | <https://app.baseten.co/signup> | <https://app.baseten.co/settings/api_keys> | per token |
| **Groq** | <https://console.groq.com> | <https://console.groq.com/keys> | per token, generous free tier, rate limited |
| **Together** | <https://api.together.ai> | <https://api.together.ai/settings/api-keys> | per token |
| **Fireworks** | <https://fireworks.ai> | <https://fireworks.ai/account/api-keys> | per token |

Most give free trial credit, so you can measure before committing. Prices move often enough that quoting
them here would only mislead; check the provider's own page.

## Flat rate or per token?

The deciding number is how many tokens an agent session actually burns, and it is larger than people
expect. Ollama Cloud does no prompt caching, so every turn resends the entire context. A small three-turn
task measured about 54,000 tokens. A long working session runs into the hundreds of thousands.

**A flat-rate subscription** makes that irrelevant, which is its real appeal: you stop thinking about
token counts. The limits are concurrency and a session quota rather than money. A paid tier also unlocks
the larger coding models.

**Per-token billing** is cheaper for intermittent use and has no concurrency cap, which matters if you
fan out parallel agents. At the low end of the market, even a session in the hundreds of thousands of
tokens costs a few cents.

A practical arrangement is both: a flat-rate plan as the primary tier and a per-token provider as
overflow. `add-deepinfra.sh` sets exactly this up, adding `burst` aliases and rewriting the fallback
chain so requests spend the flat-rate quota first, spill to metered when it runs out, and land on the
free local models rather than hard-failing.

## Where the key goes

Put it in `.env` on the box:

```
OLLAMA_API_KEY=...
DEEPINFRA_API_KEY=...
```

Then recreate the container:

```bash
docker compose up -d --force-recreate litellm
```

Never put a key in `config.yaml`. Every entry there references `os.environ/NAME`, which keeps secrets out
of the file you commit.
