## What this changes

## Why

## How it was checked

Run these locally; CI runs the same three:

```bash
for f in *.sh; do bash -n "$f"; done
shellcheck -S warning *.sh
cp .env.example .env && docker compose --env-file .env config -q; rm .env
```

- [ ] The commands above pass
- [ ] No secret, host, IP address or username is in the diff (`.env` and `.env.local` are git-ignored)
- [ ] Docs updated if behaviour changed, especially `docs/` if a known quirk moved
