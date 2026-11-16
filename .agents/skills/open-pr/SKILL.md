---
name: open-pr
description: Open the pull request for a branch the developer has already reviewed. Pushes the branch, opens a draft PR (or merge request) to the default branch with the review packet as its description, on GitHub, GitLab or Bitbucket, and walks the staging deploy, the staging e2e and the switch to ready for review. Use when the developer says the branch is reviewed and asks to open the PR.
disable-model-invocation: true
---

# Open PR

Running `/open-pr` authorizes pushing this branch and opening a draft PR. `/deliver` in quick mode runs it without waiting, because `/quick` already authorized that. It never authorizes a merge or a push to the default branch or any deploy branch.

## 1. Check

- The developer has reviewed the branch (they ran this command for that reason). If `REVIEW.md` is missing or older than the last commit, run the `review-packet` skill first.
- The `verify` skill passes on the branch. Run it if the branch changed since the last run.
- The working tree is clean.

## 2. Push and open as draft

```bash
git push -u origin <branch>
<home>/bin/home pr <repo> <default branch> <branch> "<zone emoji> <type>(<area>): <spec title>" <body file> risk:<red|yellow|green>
```

`bin/home pr` opens it on the repo's host (GitHub with `gh`, GitLab with `glab`; on Bitbucket or without an adapter it prints the link to open it by hand). The body is the repo's PR template (when it has one) filled in from `.review/<branch>/REVIEW.md`: the zone, the "Must read" list, the invariants table, the decisions, the e2e results and the deploy notes. Add the attribution line the session uses at the end.

**Always show the zone**, for quick and full changes alike: start the title with it (`🔴 fix(payments): …`) and pass the `risk:<zone>` label (skipped when the host or repo has no such label). The zone decides how much human review the PR needs: red means a person reads the whole diff.

### Related repos

When `deliver-log.md` has `REPO` lines, open **one draft PR per repo**, each from its integration worktree against that repo's default branch, with the part of the packet for that repo. Open the API's PR first, then add a "Related PRs" line with every other PR's link to each description. Merge order goes in the deploy notes: usually the API first, then the fronts.

### Tell the team

Set the spec's status to `pr-open`, add the PR links to its "Repos" line or a `- **PRs:**` line, and publish: `<home>/bin/home save "spec: <slug> pr-open"`.

## 3. Staging

The PR's checks run while it is a draft. Then, with the developer:

1. Deploy the branch to the test environment, the way the project's runbook says (ask the developer when it doesn't). Never deploy to production.
2. Call the `e2e` skill with `--target <that environment>`.
3. Update the PR's E2E section with the result (`gh pr edit --body-file`, `glab mr update --description`, or by hand).

## 4. Ready for review

When the checks pass and the staging e2e passes, regenerate the review page with that result (the `render-html` skill, `review <branch>` mode).

For the reviewer, the PR description stays the source (the host renders it). If the agent can publish a page (a claude.ai artifact from Claude Code), offer to publish `review.html` as a private page and add its link at the top of the PR description; the developer shares it with the lead. Otherwise the developer can send the file. Never publish without the developer's yes: the page describes unreleased code.

Then mark it ready (`gh pr ready`, `glab mr update --ready`, or by hand). Any CI review the repo has runs then, and a person does the final review.

## 5. Close the integration worktree

Once the PR is ready for review, the local worktree has done its job: the branch lives on in the PR. From another worktree (the base's, for example), run:

```bash
bash .agents/scripts/worktree.sh close <slug>
```

It removes `<parent>/<slug>` and any ticket worktree left over, and keeps `feat/<slug>`. For each related repo, also `bash .agents/scripts/worktree.sh --repo <repo path> close <slug>`. To review or fix the PR later, check the branch out again (`git worktree add <path> feat/<slug>`). Copy `.review/feat-<slug>/` somewhere first if you want to keep the local evidence; it is git-ignored and goes with the worktree.

If the developer drops the delivery instead of opening a PR, use `close <slug> --discard`, which also deletes `feat/<slug>` and its ticket branches. Only on their word.

Report the PR URL and what is still pending.
