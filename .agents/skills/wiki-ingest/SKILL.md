---
name: wiki-ingest
description: Turn a source (a merged PR, a review packet, a finished spec, a debugging session, an answer from the developer, a document or transcript in raw/) into wiki pages in the home repo, updating existing pages instead of duplicating them, marking replaced decisions as superseded, then saving and pushing without asking. Use after fixing a non-obvious bug, making or learning a decision, finding how to do something operational, getting an answer a future agent would need, finishing /deliver, or when asked to ingest a source.
---

# Wiki ingest

Write what the team will need again, in the place they will look, without asking anyone. Read `AGENTS.md` in the home repo for the page format first.

## 1. Read the source and pick what is worth keeping

Worth a page or an update: a decision and its reason; a root cause and its fix; an operational how-to; a fact about a project, repo, provider, environment or person's area; a rule; an answer the developer had to give. Skip routine changes and anything the code or its README already says clearly.

Never write secrets, credentials, `.env` values, connection strings, tokens or personal data. Say how to get access, not the access itself.

## 2. Find what already exists

Read `wiki/index.md` and grep for the key terms (`grep -ril "<term>" wiki/`). Prefer updating a page over adding one. One source usually touches several pages: a merged fix updates its incident, the provider page and maybe a runbook.

## 3. Write

- **New page:** in the right folder, with the frontmatter from `AGENTS.md`. Decisions and incidents are named `YYYY-MM-DD-<slug>.md`. Lead with what a reader needs.
- **Update:** edit the relevant section, update `date` or add `updated: YYYY-MM-DD`, add the new source to `sources`.
- **Contradiction:** the newer, verified fact wins. For decisions, write the new page with `supersedes: <old page>` and set `status: superseded` + `superseded_by:` on the old one. For other pages, rewrite the stale part and mention what changed. If you can't tell which is right, keep both claims, mark the page `status: draft`, and say so in the hand-over.
- **Links:** link the new page from at least one related page (its project, repo, provider or incident), and link back. A page nobody links to is an orphan.
- **Sources:** PR URL, commit, `repo:path:line`, or the `raw/` file.
- **Raw sources:** a document, transcript or note you ingest goes to `raw/<kind>/YYYY-MM-DD-<slug>.md` unchanged, with a small frontmatter (source, url, date). Never edit a raw file afterwards.

## From the host (what the team merged)

Run this when the session hook says there are merged PRs to ingest, or when asked to catch the wiki up with GitHub. It works with the developer's own host login (`gh`, `glab`) or, without one, from git history; no token or CI needed.

1. `bin/home pending` lists the merged work since the last ingest, across every repo in `repos.yaml`. `bin/home branches` regenerates `wiki/branches.md` (deploy branches against the default branch, active branches with their latest commits), and `bin/home now` regenerates `wiki/now.md`.
2. Skip promotion PRs ("Master to Prod", "Staging to Prod") and version bumps unless they tell you something new. For the rest, read the description: `gh pr view <n> --repo <org/repo> --json title,body,files,commits`. When the description is empty, the files and commit messages say what changed. Read the diff only for money, auth or contract changes.
3. Write what the team needs: a decision, a fix and its cause, a new endpoint or contract rule, a new provider or module, a process change (how a repo releases, how a team works). Update the project, repo and provider pages ("Recent" sections) rather than creating one page per PR. When a PR adds, renames or removes a shared piece (a util, base service, guard, decorator, client, hook or common component used by more than one module), update the "Reuse before you write" list of that repo's page: name, path, one line on what it does. Flag anything that contradicts a rule or decision (for example a guard that fails open) on the relevant page.
4. Use the branches page to say who is working on what (the people table in the main project page) and what is deployed where (`wiki/runbooks/release-flow.md`).
5. `bin/home pending --done` marks everything up to now as ingested, then log and save as below.

## 4. Log and save

```bash
bin/home log ingest "<what you ingested>"
bin/home check            # fix what it reports in the pages you touched
bin/home save "wiki: <what changed>"
```

`save` rebuilds the index, commits, rebases on the latest `main` and pushes. If it touched a protected path (`wiki/rules/`, skills, `AGENTS.md`), it opens a PR instead; mention the PR link in your hand-over. Don't ask the developer before saving; tell them in one line what you added.

### Conflicts

Everyone works on `main`, so `save` may find that someone changed the same lines since your last pull. Regenerated files (`index.md`, `now.md`, `branches.md`, `ingest-state.json`) resolve on their own. For any other file, `save` stops (exit 3) and lists the files to merge; the rebase stays open and `bin/home sync` reminds the next session of it. Merge them yourself, don't ask the developer:

1. In each file, between `<<<<<<<` and `>>>>>>>`, the first side is the team's `main` and the second is your change.
2. Keep what each side adds. Two facts that contradict each other: keep the one you can verify against the code (or the newer one for a decision, with `supersedes`); if you can't tell, keep both, mark the page `status: draft` and say so in the hand-over.
3. Remove every marker, then run `bin/home save --continue`.
