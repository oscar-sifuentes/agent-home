---
name: dev-env
description: Find or start the local test environment before an end-to-end test. Detects which APIs, fronts and infrastructure are already running and uses them; if what the test needs is down, starts it from the project's runbook, records what it started and stops exactly that at the end. Use before /e2e, or when asked to check, find or start the local environment.
---

# Dev env

**Inside `/deliver`** this skill only checks the infrastructure (database, cache, queues). The orchestrator starts the apps from the integration worktrees with `.agents/scripts/servers.sh`, so the e2e tests the branch's code; see "Run from a worktree" in the repo's `AGENTS.md`.

Use what is running. When what the test needs is down, start it yourself, following `<home>/wiki/runbooks/local-environment.md` (or the repo's README or `HOW_TO_RUN.md` when the wiki has no runbook yet), and stop what you started when the test ends. Never point a test at production.

## 1. Detect what is running

The ports, health URLs and start commands come from the runbook or the repo's `AGENTS.md`. Probe them with short timeouts, one call each:

```bash
for p in <ports from the runbook>; do nc -z 127.0.0.1 $p 2>/dev/null && echo "$p up"; done
curl -s -m 5 -o /dev/null -w '%{http_code}\n' http://localhost:<port>/<health path>
docker compose ps --format '{{.Name}} {{.State}}' 2>/dev/null
```

When the runbook doesn't list them yet, find them in `package.json` scripts, `docker-compose*.yml` and `.env.example`, and propose the runbook page (`wiki-ingest`) at the end.

## 2. Decide

- **Something answers.** Use it. Report which APIs and fronts are up and what serves them.
- **What the change needs is down.** Start it, without asking, as the runbook says. It is a heavy command: run it alone, never next to tests or builds. Wait until it answers, up to a few minutes.
- **Record what you started**, one line each, in `.review/<branch>/started-by-agent.txt` (what, and the command that stops it). At the end of the e2e, even when it failed, stop exactly those (`docker compose stop <services>`, `servers.sh stop`), never `down -v`, and never something you found already running.
- **It can't start** (Docker missing, a port taken, a dump missing): mark the e2e as pending with the reason and go on.

## 3. Find out which database it writes to

Say which one it is: local (Docker or a local server), a shared test database, or unknown. If anything suggests a production database, stop and say so. Never run tests against production.

## 4. Rules for a shared test database

Other people use it too:

- Use the test accounts the runbook names, or create new ones with an `e2e-` prefix. Never touch other people's data.
- Never run migrations against it without asking.
- Nothing destructive: no `TRUNCATE`, no bulk `DELETE`/`UPDATE`, no schema changes.

## Output

One short block: the API URLs, the front URLs, the database (local / shared test / unknown), and anything missing for the e2e that follows.
