# Security policy

## Reporting a vulnerability

Report suspected vulnerabilities privately through GitHub's
[private vulnerability reporting](https://docs.github.com/en/code-security/security-advisories/guidance-on-reporting-and-writing-information-about-vulnerabilities/privately-reporting-a-security-vulnerability)
on this repository, rather than opening a public issue. Please include what you did, what happened, and
what you expected.

This is a small volunteer project. Expect an acknowledgement within a week.

## What this stack does not protect you from

This repository ships a deployment recipe, not a hardened appliance. The defaults suit a trusted LAN.
Read this section before putting it anywhere else.

**Ollama has no authentication at all.** Ollama does not support API keys or any other access control.
Whoever can reach port 11434 can run any model you have pulled, read every prompt passing through it,
and consume all your RAM. Out of the box, Ollama's systemd unit commonly binds `0.0.0.0`, which means
every device on your network.

The fix is a firewall rule, not a loopback bind:

```bash
sudo ufw allow from 172.16.0.0/12 to any port 11434   # Docker bridges only
sudo ufw deny 11434
```

Do not set `OLLAMA_HOST=127.0.0.1`. The LiteLLM container reaches the host through
`host.docker.internal`, which resolves to the Docker bridge gateway rather than to loopback, so a
loopback bind severs the proxy's path to Ollama while appearing to be the safer choice.

**Port 4000 is the whole proxy.** Anyone who reaches it with the master key has admin over your keys,
spend and configuration. Keep it on the LAN. If you need it from outside, put it behind TLS with the
included Caddy profile and a firewall, or reach it over an SSH tunnel. Confirm your router is not
forwarding the port and that any tunnel you run does not publish it.

**The master key is admin access.** Generate it with `openssl rand -hex 24`, never reuse a memorable
string, and issue virtual keys from the UI for every client. Virtual keys carry their own budgets and
can be revoked individually. Rotating the master key does not invalidate them.

**Two values must never change after first start.** `LITELLM_SALT_KEY` encrypts stored provider keys,
and `POSTGRES_PASSWORD` is written into the database volume when it initialises. Changing either one
later makes stored keys unreadable or locks you out of your own database.

**`.env` holds every secret in plaintext.** It is git-ignored here; keep it `chmod 600` on the box and
never commit it. If you think a key has leaked, rotate it rather than hoping.

## Scope

Vulnerabilities in LiteLLM, Ollama, Postgres, Redis or Caddy belong upstream with those projects. Issues
in this repository's configuration, scripts or documented defaults belong here.
