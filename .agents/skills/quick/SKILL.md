---
name: quick
argument-hint: '<what to change> [repo]'
description: The short path for a change the developer judges small, in any zone (even red, e.g. a small migration). A few questions only if something is unclear, then a one-screen page (what, scope, how it's checked, zone, risks) that the developer approves once; after that everything runs alone through /deliver in quick mode (one worker, verify, automatic fresh risk-review in yellow and red, e2e when there is behaviour to test, wiki, draft PR labelled with its zone). Use when the developer runs /quick or asks for a quick change; the developer decides the lane, not the agent.
disable-model-invocation: true
---

# Quick

The developer chose the short path. Respect that: no tickets, no long interview, one approval. Quick lightens the process before the PR, never the review after it: the PR still carries its zone, and a red PR still needs a person to read the whole diff.

## 1. Understand

1. Run `overlap-check` (fast version: `wiki/now.md`, open PRs, the default branch). If someone already has it, say so before anything else.
2. Read what the change touches: the code, the module README, `AGENTS.md` of the repo, and the wiki pages of that area (`wiki-query`), including the repo page's "Reuse before you write" list, so the page can say what it will reuse. Settle with the code what the code can answer.
3. **Ask only what is still unclear**, one question per message, each with your recommended answer so a word accepts it. Usually zero to three questions. No question about how to implement.

## 2. Write the page

Pick a short kebab-case slug and write `<home>/specs/<slug>/spec.md`. It must fit on one screen: a developer approves it in under a minute.

```markdown
# <Title>

- **Kind:** quick
- **Owner:** <git user.name>
- **Repos:** <one repo>
- **Zone:** 🟢 | 🟡 | 🔴 (by the files it will touch, with AGENTS.md's rules; one line on why)
- **Status:** draft

## What and why
Two or three sentences.

## In / out
- In: …
- Out: … (what this deliberately doesn't do)

## How we check it
- [ ] <check 1: a test, a command, an API call or a UI step, and what proves it>
- [ ] <check 2>
- e2e: <the scenario to run through the API or the browser, or "none: no runtime behaviour">

## Risks
Who calls what changes, what could break next to it, and for red: the money/auth rule at stake (e.g. "migration has a full down; no lock on a large table").
```

Publish it right away (`<home>/bin/home save "spec: <slug> quick draft"`), show it to the developer, and wait for their **ok**. That is the only time the flow waits. A change they ask for: edit the page, show it again.

## 3. Hand over to /deliver

On "ok": set `Status: approved`, save, and run the `deliver` skill for `<slug>`. It sees `Kind: quick` and runs its quick mode on its own: one worker builds it, `verify`, a fresh `risk-review` in yellow and red, the e2e when the page names one (it starts the local environment if needed and stops what it started), the wiki, and a draft PR labelled with the zone. Running `/quick` authorizes pushing that branch and opening that draft PR, never merging it.

## Trivial changes

A typo, a doc or a comment (green, no behaviour) doesn't need a page: change it, run `verify`, open the PR with a three-line description and the `risk:green` label, and add a line to `wiki/log.md` if the team should know.
