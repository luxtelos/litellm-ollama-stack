---
name: Bug report
about: Something in the stack does not behave as documented
labels: bug
---

**What happened**

**What you expected**

**Steps to reproduce**
1.
2.

**Environment**
- Box OS and CPU/RAM, and whether it has a GPU:
- Docker and Compose versions (`docker --version`, `docker compose version`):
- Ollama version (`ollama --version`):
- Which model alias (`agent`, `local`, `classify`, …):

**Relevant output**
Paste `docker compose logs --tail 50 litellm`, or the failing command and its output.
Redact any key: report its length or "set", never the value.

**Already checked**
- [ ] `ollama list` shows the model with a real size, not a cloud pointer
- [ ] `curl <box>:4000/health/liveliness` answers
- [ ] I read `docs/health-and-throughput.md` for the two known quirks
