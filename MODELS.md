# What each model is actually good for

## The three small local models
None of these will drive a coding agent: their tool calling is weak or absent. They are still
the most useful part of a local box, because they are free, instant, and burn no cloud quota.
Use them for volume work.

### qwen2.5:0.5b  (397MB, 60+ tok/s)
Not a chat model. A text-shaped calculator. Give it one narrow job:
- classify / route: "is this file config, test, or source?" -> one word
- extract fields from logs, emails, invoices into JSON
- yes/no gates in a shell script or n8n flow
- git commit message from a diff
- rename suggestions, spelling/format fixes
- first-pass filter over 10,000 rows before a big model sees the 200 that matter
It is dumb. That is the point. Ask it one thing, get one answer, 100 times a second.

### qwen2.5-coder:3b  (1.9GB, ~20 tok/s)
The editor sidekick. Not for reasoning, good for shape-of-code.
- inline autocomplete in Continue.dev / Zed / VS Code
- write docstrings and type hints for an existing function
- generate unit-test skeletons
- one-liner regex / awk / jq / bash you forgot the syntax for
- explain what a 20-line function does
- convert JSON <-> YAML <-> TOML, small schema work

### starcoder:latest  (1.8GB)
FIM only - "fill in the middle". This is a completion model, NOT chat.
Its one real job: **tab-completion inside your editor.** Set it as the
autocomplete model in Continue.dev. Do not put it in a chat window,
do not point Claude Code at it. It will produce garbage there.

## The cloud models
| model | what makes it different | use it for |
|---|---|---|
| `gpt-oss:120b` | best tool-calling of the six | **Claude Code agent driver.** the main one |
| `gpt-oss:20b` | same family, lighter on quota | mid-size tasks, drafts, when 120b is overkill |
| `nemotron-3-super` | 120B MoE, only 12B active = fast | high-volume batch: review 50 files, generate docs |
| `nemotron-3-ultra` | reasoning-tuned | hard debugging, architecture calls, math/logic |
| `nemotron-3-nano:30b` | smallest cloud, cheapest on quota | summarize, route, cheap second opinion |
| `gemma4:31b` | **multimodal - it can SEE** | screenshots, diagrams, PDFs, UI mockups, OCR |

`gemma4:31b` is the only one with eyes. That is its whole reason to exist in your
lineup: paste a screenshot of a broken UI or a scanned compliance PDF and ask about it.
Weak at tool calls though - use it for looking, not for doing.

## Sensible division of labour
- **Agent work (Claude Code)** -> `gpt-oss:120b` cloud
- **Anything with a picture** -> `gemma4:31b` cloud
- **Hard thinking, one question** -> `nemotron-3-ultra` cloud
- **Bulk over many files** -> `nemotron-3-super` cloud, or `gpt-oss:20b` LOCAL if quota is tight
- **Editor autocomplete** -> `starcoder` local (free, instant, private)
- **Docstrings, small edits** -> `qwen2.5-coder:3b` local
- **Classify/extract/route at scale** -> `qwen2.5:0.5b` local
Rule of thumb: if the job runs more than 50 times, do it locally. Quota is for thinking,
not for grinding.
