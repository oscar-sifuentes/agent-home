---
name: wiki-query
description: Answer a question from the project wiki (the home repo's wiki/) before asking the developer or digging through code. Reads wiki/index.md first, opens only the pages it needs, follows links, skips superseded pages, cites what it used, and files a missing answer back into the wiki. Use whenever you need context about a project, repo, integration, decision, past incident, runbook (cloud access, databases, deploys, local setup) or team rule; and before asking the developer a question.
---

# Wiki query

The wiki is the team's memory. Asking the developer something the wiki already answers wastes their time; that is the failure this skill prevents.

1. **Find the wiki.** It is `wiki/` in the home repo. From a connected repo: `bash .agents/home.sh path`. If it isn't there, say so once and continue without it.
2. **Read `wiki/index.md` first.** One line per page. Pick the pages whose title or summary matches the question; usually 1 to 5.
3. **Read those pages, then follow their links** one or two levels when the answer needs more (a decision links its incident, a project links its repos and runbooks).
4. **Status matters.** Skip pages with `status: superseded` unless the question is about history; follow `superseded_by` instead. An `open` incident is still a live problem.
5. **Check before you rely on it.** A page that names code (`repo:path:line`) can be stale. When the answer drives a code change, open that code. If the code disagrees, the code wins: fix the page with `wiki-ingest`.
6. **Nothing in the index?** Search the text: `grep -ril "<term>" wiki/ raw/`. `raw/` holds sources (transcripts, notes, exported memories) that may have the fact before anyone wrote a page.
7. **Answer and cite** the pages you used (`wiki/decisions/...`).
8. **File the gap.** If the wiki didn't have the answer and you got it from the developer, the code or a source, write it down with `wiki-ingest` right away, without asking. The next agent must not have to ask again.

What's in `wiki/now.md`: active specs, open PRs and recent merges across all repos. Read it when the question is "who is working on what" or before starting new work (see `overlap-check`).
