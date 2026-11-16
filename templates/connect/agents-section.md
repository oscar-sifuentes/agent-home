<!-- agent-home:start (managed by the home repo's `bin/home connect`; edit it there) -->
## Home repo: __HOME_NAME__

Shared agent skills, specs and the project wiki live in the home repo **__HOME_NAME__** (__HOME_URL__), cloned on this machine. `<home>` in any skill means its path; `bash .agents/home.sh path` prints it.

- **Read `<home>/wiki/index.md` before deciding anything** (skill `wiki-query`). Don't ask the developer what the wiki answers.
- **Small change? `/quick <what>`:** a one-screen page, one approval, then it runs alone to a draft PR. Big or cross-repo work: `grill-me` → `to-spec` → `to-tickets` → `/deliver`. The developer picks the lane.
- **Run `overlap-check` before planning:** the work may already exist in an open PR, a branch or the code.
- **Reuse before you write:** check the repo's "Reuse before you write" list in `<home>/wiki/repos/` and grep before adding a helper, service or component.
- **Save what will be needed again** (a decision, a root cause, a how-to) with `wiki-ingest` and `<home>/bin/home save`, without asking.
- Shared skills, scripts and sub-agents appear in `.agents/skills`, `.claude/skills`, `.agents/scripts` and `.claude/agents` as local links (never committed). Any agent without session hooks: run `bash .agents/home.sh sync` if one is missing. Change shared skills in the home repo, never through a link.
- This repo's own rules in this file come first for work in this repo.
<!-- agent-home:end -->
