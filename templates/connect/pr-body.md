## Why

This connects the repo to its home repo, which keeps the shared agent setup in one place: the agent skills (`/quick`, `grill-me`, `to-spec`, `/deliver`, `verify`, `risk-review`, `e2e`, the wiki skills…), the specs of every piece of work, and a wiki of decisions, runbooks, incidents and what is in progress. Without it, an agent that starts here can't see any of that.

## What it changes

Only agent configuration. **No app code, build, CI or deploy changes.**

- `.agents/home.sh`: finds the home repo and links each shared skill, script and sub-agent into `.agents/` and `.claude/`, one link per item, next to this repo's own ones (never replacing them). The links are git-ignored locally (`.git/info/exclude`).
- `AGENTS.md` (and `CLAUDE.md` when it doesn't import `AGENTS.md`): a marked section with the home repo's rules. This repo's own rules still come first.
- `.claude/settings.json`: a `SessionStart` hook that runs `bash .agents/home.sh sync`.
