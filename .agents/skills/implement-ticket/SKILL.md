---
name: implement-ticket
description: Build one ticket from <home>/specs/<slug>/tickets/ test-first on its own ticket branch, verify it, commit it locally, write the report file and signal the /deliver orchestrator, which reviews and merges it. Run by each worker, whatever the agent (Claude, Codex, Grok, Antigravity) and whatever the runner (Orca, Herdr, sub-agent). Never pushes, merges or opens a PR.
---

You build exactly one ticket, as a worker of the `/deliver` orchestrator. Your brief gives you:

- the spec path and the ticket path
- the integration branch (`feat/<slug>`) and your ticket branch (`feat/<slug>--NN`)
- your worktree (you are already in it)
- the **report file** (an absolute path) and **how to signal** the orchestrator (the runner)

You never merge into `feat/<slug>`: you finish, report, and the orchestrator reviews and merges.

## A quick spec instead of a ticket

When your brief names a quick spec (`Kind: quick`) instead of a ticket, the spec's "How we check it" list is your acceptance criteria and there is no ticket status to set. Write tests only where they add value: a migration or a one-line fix may have none, but say in the report how each check was proven. Report each check with its proof under "Invariant tests". If the work turns out bigger than the page (another repo, a decision the page doesn't settle, a higher-zone file), stop and report `RESULT: question` instead of going on.

## A ticket in another repo

When your brief names a **repo** other than the primary one, your worktree is in that repo, and the spec, the ticket and these skills stay where the brief says (absolute paths).

- Read that repo's `AGENTS.md`, `CLAUDE.md` or `README.md`, whichever exist, for code style. If it has none, copy how its code is already written. The primary repo's security rules (money, auth, data) still apply to anything that touches them.
- Its commands come from its own `package.json` (lint, typecheck, tests) and its lockfile's package manager. Run only the checks of the files you changed, through the `heavy.sh` path in your brief.
- Don't edit the ticket file: the orchestrator sets its status. Docs upkeep applies only if that repo has a `CHANGELOG.md` or a README for what you changed.
- Everything else (branch, report file, signal, never push) is the same.

## Asking the orchestrator

Ask only when the answer can move money, change auth or access, or expose data, and the spec, the ticket, the code and `AGENTS.md` don't settle it. For anything else, pick the option the codebase already follows (or the simplest one), note it under "Decisions not in the spec" in your report, and keep going: the run is unattended. Use the runner's channel from your brief:

| Runner | How to ask |
|---|---|
| Orca | `orca orchestration ask --question "<question + your recommended answer>"`, then end your turn; Orca wakes you with the answer |
| Herdr | `hc send <orchestrator> "QUESTION NN: <question + your recommended answer>"`, then end your turn; the answer arrives as your next message |
| Sub-agent | write the report file with `RESULT: question`, then stop |

## Before writing code

1. Check that your worktree is on your ticket branch, created from the tip of the integration branch. If not, stop and report it; don't create worktrees yourself.
2. Read `AGENTS.md`, the spec (including its "Docs checked" table), your ticket, and the README of every module you will touch.
3. Read the team wiki for what you touch (`wiki-query`, read-only): `<home>/wiki/index.md`, then the pages of the module, provider, brand or flow (past decisions, incidents, gotchas). `<home>` is in your brief, or `bash .agents/home.sh path`. Never write to `<home>` yourself.
4. Set the ticket's status to `in-progress`.

## Build

- Run the `tdd` skill (`.agents/skills/tdd/SKILL.md`). Start with the ticket's invariant tests, then its acceptance criteria.
- Follow `AGENTS.md`: the money rules, the code style, the module layout. For structure, copy how the touched module (or a similar one) already does it, and check NestJS and TypeORM APIs with Context7.
- **Reuse before you write.** Before you add a helper, service, guard, decorator, DTO, hook or component, read the "Reuse before you write" section of the repo's wiki page (`<home>/wiki/repos/<repo>.md`) and grep the repo for similar names (`git grep -n -i <word>`). Use what exists, or extend it; write a new one only when nothing fits, and say why under "Decisions not in the spec". A new shared piece (used by more than one module) goes under "For the wiki", so the list stays current.
- **Library APIs come from the docs.** Before you use an external library API that this repo doesn't already use the same way (a new decorator, query builder method, validator, config option), look it up with Context7 for the version in `package.json`, as `AGENTS.md` describes. Copying a usage that already exists in the repo needs no lookup.
- Stay inside the ticket and inside your worktree. Don't start other agents.
- Run heavy commands through `bash .agents/scripts/heavy.sh <cmd>`, so only one runs at a time on the machine.

## Finish

1. Docs upkeep from `AGENTS.md`: one `CHANGELOG.md` bullet, plus the README of each module whose behaviour changed.
2. Run the `verify` skill (`.agents/skills/verify/SKILL.md`), using the integration branch as the base. Fix what fails in your code. Stop after 3 failed attempts and report `failed`.
3. Commit on your ticket branch (local only): `<type>(<module>): <ticket title>`. Running under /deliver authorizes these local commits; never push.
4. Merge the integration branch tip into your branch, so the orchestrator's merge is clean. Re-run the tests of your files if the merge brought changes.
5. Set the ticket's status to `done` and tick its criteria.

## Write the report file

Write it to the exact path in your brief: `.review/worker-report.md` inside your worktree (git-ignored, never committed). It is the source of truth: the orchestrator reads it, not your screen.

```markdown
# NN <ticket title>

- Branch: feat/<slug>--NN
- Commit: <full SHA of HEAD>
- Agent: <your agent and model>

## Files
- path — zone

## Invariant tests
- Invariant <n> → `file:line` → passing

## Decisions not in the spec
## Context7 lookups
- library @ version → what for
## For the wiki
(What the team should know later: a new shared piece others should reuse (name, path, what it does), a gotcha, a root cause, a decision you took that others will meet again, a wiki page that turned out wrong. One line each, with file:line. "none" is fine. The orchestrator writes them to the wiki.)

## Open questions / not tested

RESULT: done | failed | question
```

The last line must be exactly `RESULT: done`, `RESULT: failed` (say why above) or `RESULT: question` (the question above).

## Signal the orchestrator

| Runner | Signal |
|---|---|
| Orca | `orca orchestration send --type worker_done --outcome succeeded --subject "NN <title>: ready to merge" --body "<report file path>"` (`--outcome failed` when `RESULT: failed`). Omit `--to`; use the `--from`, `--task-id` and `--dispatch-id` values from Orca's injected preamble when it gives them |
| Herdr | `hc send <orchestrator> "DONE NN: <report file path>"` (or `FAILED NN: ...`) |
| Sub-agent | your final message: the report file path and its `RESULT` line |

Then stop. Don't start another ticket, and don't merge.
