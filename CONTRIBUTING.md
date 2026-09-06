# Contributing

Contributions are welcome. This is a small, practical repository, so the bar is "does it work on a real
box and is it clear to the next person".

## Before you open a pull request

**Never commit secrets.** `.env` and `.env.local` are git-ignored for a reason. Check your diff before
pushing. If a key ever lands in a commit, say so immediately in the pull request so it can be rotated,
rather than quietly force-pushing over it.

**Check the shell scripts.** Every script must parse and, where the tool is available, pass shellcheck:

```bash
for f in *.sh; do bash -n "$f"; done
shellcheck -S warning *.sh
```

**Check the compose file** still resolves with the template values:

```bash
cp .env.example .env && docker compose --env-file .env config -q; rm .env
```

**Keep the scripts parameterised.** No hostname, IP address, username, home directory or API key belongs
in a tracked file. The target box comes from `BOX_HOST`, `BOX_USER`, `BOX_SSH_KEY` and `BOX_DEST`; the
proxy key comes from `LITELLM_VIRTUAL_KEY`. A script that cannot find what it needs should exit non-zero
and name the missing variable.

## Proposing a model or a job alias

Job aliases are the useful part of this repository, and a good one is a job rather than a model. Open an
issue or a pull request that says:

- The alias name and the job it does, in one line. `classify`, `commit` and `gate` are the pattern to
  follow: a caller should never have to think about which model answers.
- The model behind it and why that model rather than a smaller one.
- Its `litellm_params`: `temperature`, `max_tokens` and `timeout` all matter. Tiny models need tight
  limits or they ramble past the answer.
- Where it belongs in `router_settings.fallbacks`, so it degrades sensibly when its tier is unavailable.
- Roughly how it performs on CPU. "Answers in under a second on a 4-core box" is worth more than a
  benchmark table.

Local models keep `input_cost_per_token: 0` and `output_cost_per_token: 0` so that budget limits never
block a free request.

## Documentation

If a change alters behaviour someone would be surprised by, update the relevant file in `docs/`. The
measured numbers in `docs/health-and-throughput.md` come from a real box: if you replace them, say what
hardware produced yours.

## Style

Match the surrounding file. Scripts use `set -euo pipefail` and read `.env.local` from their own
directory. Prose is plain and says what to do.
