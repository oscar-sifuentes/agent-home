# AGENTS.md

<!-- kit:start (agent-home kit; `install.sh update` refreshes this part, write project notes outside it) -->
This is a **home repo** (agent-home kit). Any agent (Claude Code, Codex, Antigravity, Grok, Cursor) and any person starts here when the work spans repos or needs project knowledge. It holds:

- **the repo map** (`repos.yaml`, below): every repo of the project, where it is and how to get it;
- **the wiki** (`wiki/`): the project's shared memory: projects, repos, decisions, incidents, runbooks, rules;
- **specs** (`specs/`): every spec, its tickets and its review packet, with a visible status;
- **raw sources** (`raw/`): what the wiki is built from (notes, exports, transcripts). Never edited;
- **shared skills** (`.agents/skills/`) and the `bin/home` CLI. Settings in `home.yaml` (name, host, owners).

Each code repo keeps its own `AGENTS.md` (commands, conventions, risk zones, domain rules), hooks and CI. When you work inside a repo, its rules win for that repo; this file adds the shared context.

## Before you plan or decide anything

1. Read `wiki/index.md`, then only the pages you need (skill `wiki-query`). Don't ask the developer something the wiki answers.
2. Before planning a feature or fix, run the `overlap-check` skill: it may already exist in an open PR, a branch or the code.
3. The code is the source of truth. When a page and the code disagree, trust the code and fix the page.

## Keep the wiki alive (no one asks you to)

Whenever you learn something that will be needed again, write it down with the `wiki-ingest` skill and save it with `bin/home save "<message>"`. Don't ask for permission. Worth a page: a decision and why; a root cause and fix; an operational how-to (access, deploys, local setup); a fact someone had to ask for; an answer the developer gave you that a future agent would ask again. Not worth a page: routine commits, what the code or its README already says, anything that only matters to this session.

**Plans save themselves.** Every write under `specs/<slug>/` (grill notes, the spec, tickets, any status change) is followed in the same step by `bin/home save "<skill>: <slug> <what>"`, without asking. A power cut or a closed laptop then loses at most the last answer, and the next session (any agent) continues from the files: run the same skill again with the slug.

## Page format

One file per page, kebab-case. Decisions and incidents start with their date: `wiki/decisions/2026-01-15-use-postgres-for-jobs.md`.

```markdown
---
title: Background jobs run on Postgres, not Redis
type: decision          # project | repo | decision | incident | runbook | provider | rule | roadmap | concept
summary: One line. It becomes the line in wiki/index.md.
status: accepted        # decision: accepted | superseded; incident: open | resolved; others: active | draft
date: 2026-01-15
repos: [api]
projects: [shop]
sources: [https://github.com/acme/api/pull/42, api:src/jobs/queue.ts:10]
supersedes:             # relative path of the page this one replaces
superseded_by:          # set on the old page, together with status: superseded
---
```

- Link pages to each other with relative links (`[Login outage](../incidents/2026-01-20-login-outage.md)`). Every page needs at least one inbound link besides the index.
- Point `sources` at PRs, commits, `repo:path:line` or files in `raw/`, so anyone can check the claim.
- A new decision that changes an old one: write the new page with `supersedes`, and set `status: superseded` and `superseded_by` on the old one. Never leave two accepted decisions that contradict each other.
- Every `wiki/repos/<repo>.md` page has a **"Reuse before you write"** section: the repo's shared building blocks (utils, base services, guards, decorators, clients, hooks, common components), each with its path and one line. Agents read it and grep before writing a new piece, `risk-review` flags code that repeats one, and the ingest updates it when a merged PR adds or removes a shared piece. It is an index, not a copy: the code stays the source of truth.
- Short, plain English. Lead with what a reader needs; details after.
- `wiki/index.md` and `wiki/now.md` are generated (`bin/home index`, `bin/home now`). `wiki/log.md` is append-only (`bin/home log <type> <title>`).

## Never in this repo

Secrets, passwords, tokens, keys, connection strings with credentials, `.env` contents, or personal data (emails, names, ids tied to a person). Runbooks say **how** to get access; the credentials stay on each machine. Don't read `.env` or secret files to fill a page.

## Skills and connected repos

`.agents/skills/` holds the shared skills (Agent Skills format): planning and delivery (`grill-me`, `to-spec`, `to-tickets`, `deliver`, `quick`, `implement-ticket`, `tdd`, `verify`, `risk-review`, `code-review`, `e2e`, `review-packet`, `open-pr`, …) and the wiki skills. Scripts in `.agents/scripts/`, model tiers in `.agents/models.json`, Claude sub-agents in `.claude/agents/`. Add project-only skills next to them; `install.sh update` only replaces the kit's own skills.

In a skill, `<home>` means this repo's path. A code repo is **connected** when it has `.agents/home.sh`: at session start it links each shared skill, script and sub-agent into the repo (one git-ignored link per item, next to the repo's own ones) and lets Claude Code read this repo without a prompt. Connect one with `bin/home connect <path>` (writes the files; you commit them) or `bin/home connect <repo> --pr` (branch and PR/MR).

**Lanes.** **`/quick`** for anything the developer judges small, in any zone: one-screen page, one approval, then `/deliver` in quick mode runs alone to a draft PR. The full path (`research` when needed → `grill-me` → `to-spec` → `to-tickets` → `/deliver`) for big or cross-repo work. Trivial docs and typos go straight to a PR. The developer picks; every PR carries its risk zone.

**`/deliver` runs from here.** The spec lives in `specs/`; the orchestrator creates the worktrees in each repo of the spec's `Repos:` line. Workers read this repo and never write to it; the orchestrator writes the spec status, the review packet and what workers listed "For the wiki". Agents never merge or deploy.

## Specs

`specs/<slug>/` holds `spec.md`, `tickets/` and the review packet. The spec carries `status` (`draft → approved → building → pr-open → merged`, or `abandoned`), `owner` and `repos`; `bin/home now` shows it. Publish the spec when work starts.

## Commands

```bash
bin/home repos            # which repos are on this machine, where, on which branch (session hooks run --brief)
bin/home connect <path>   # connect a local checkout (adds it to repos.yaml)
bin/home where <repo>     # local path of a repo
bin/home clone <repo>     # clone it, only after the developer confirms
bin/home discover         # add repos the owners in home.yaml created since the last run
bin/home prs [repo]       # open pull/merge requests (GitHub, GitLab)
bin/home pr <repo> <base> <head> <title> <body> [labels]   # open a draft PR/MR on any host
bin/home now | branches | pending   # what is happening, from the host or plain git
bin/home index | check    # rebuild the wiki index, lint the wiki
bin/home save "<msg>"     # commit, rebase on main, push; a real conflict stops with the files to merge
bin/home save --continue  # after merging them (wiki-ingest > Conflicts)
```

Everyone works on `main` here, no branches: session hooks pull it, `save` pushes to it. Code changes go to branches and PRs in the code repos.

Repos don't have to share a folder: `bin/home` looks next to this repo, then finds a repo cloned anywhere under the usual folders of `$HOME` by its remote URL and remembers it in `repos.local.yaml` (per machine, git-ignored). A repo that isn't cloned: tell the developer, clone it only after they confirm.

Every `wiki/repos/<repo>.md` page has a **"Reuse before you write"** section: the repo's shared building blocks with their paths. Agents read it and grep before writing a new piece; the ingest keeps it current.
<!-- kit:end -->

## Project notes

(What every agent should know about this project: domain, environments, people. Keep it short; details go in the wiki.)

## Repo map
<!-- repos:start -->
<!-- repos:end -->
