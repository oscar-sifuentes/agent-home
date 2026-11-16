# agent-home

A starter kit for a **home repo**: one repo that every coding agent (Claude Code, Codex, Grok, Antigravity, Cursor) and every person starts from. It gives a project, or a client, four things:

- **a wiki agents read and keep up to date** (based on Andrej Karpathy's "LLM wiki"): decisions, runbooks, incidents, what each repo is, and a "reuse before you write" list per repo;
- **shared agent skills** for any repo and stack: `/quick` for small changes, a full path (`grill-me` → `to-spec` → `to-tickets` → `/deliver`) for big ones, plus `verify`, `risk-review`, `e2e` and more;
- **a map of the project's repos**, found wherever they are cloned;
- **specs with a visible status**, and an overlap check before planning.

Works with **GitHub** (`gh`), **GitLab** (`glab`) and **Bitbucket** (plain git; pull requests opened from a printed link). Without a host CLI, everything that reads merged work falls back to git history.

## Quick start

```bash
# 1. Create a home repo (one per client or project; this one is for "acme")
curl -fsSL https://raw.githubusercontent.com/oscar-sifuentes/agent-home/main/install.sh | bash -s -- new acme-home --host github --owner acme-org

# 2. Give it a private remote on any host, then push
cd acme-home
git remote add origin git@github.com:acme-org/acme-home.git   # or GitLab / Bitbucket
git push -u origin main

# 3. Connect each code repo (writes 4 small files; review and commit them)
bin/home connect ~/code/acme-api
bin/home connect ~/code/acme-web
```

Then open your agent in the home repo (or in any connected repo) and work: `/quick add rate limiting to the login endpoint`.

`new` options: `--dir <parent folder>` (default: current folder), `--host github|gitlab|bitbucket|none`, `--owner <org, group or workspace>` (repeat it; new repos there join the map on their own).

## Keep it up to date

```bash
curl -fsSL https://raw.githubusercontent.com/oscar-sifuentes/agent-home/main/install.sh | bash -s -- update ~/code/acme-home
```

`update` replaces only the kit's files (skills, scripts, `bin/home`, templates and the kit section of `AGENTS.md`). The wiki, specs, `repos.yaml`, `home.yaml`, your own skills and your project notes stay as they are.

## Daily wiki ingest (optional)

`new` installs a CI job for the host: GitHub Actions, GitLab CI or Bitbucket Pipelines. Each file says which secrets it needs (a token that can read the repos, and a Claude token). Without it, the wiki still learns: agents save what they learn, and each session start lists merged work not yet ingested.

## What stays private

This kit holds no project data. Each home repo is yours to keep private: it holds the wiki and specs of that project. Never put secrets or personal data in it; runbooks say how to get access, not the access itself.
