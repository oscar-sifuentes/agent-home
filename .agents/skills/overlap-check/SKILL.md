---
name: overlap-check
description: Before planning or building a feature or fix, check whether a teammate is already building it, whether it already exists in an open PR or an unmerged branch, or whether the code already has it, across every repo in repos.yaml. Then publish your own spec or claim so others see it. Use at the start of /grill-me, /to-spec, the quick lane, or any "let's implement X".
---

# Overlap check

Duplicate work is the most expensive mistake a team of agents makes. Spend two minutes here before planning.

1. **Name it.** Write 3 to 6 search terms for the work: domain words and likely code names (e.g. "rate limit", "throttle", "RateLimiter").
2. **Specs in flight.** `bin/home sync`, read `wiki/now.md`, and grep `specs/*/spec.md` for the terms. A spec with status `approved`, `building` or `pr-open` on the same thing is an overlap.
3. **Open PRs in every repo:**
   ```bash
   <home>/bin/home prs | grep -i "<term>"     # open PRs/MRs of every repo, on any host with an adapter
   ```
4. **Unmerged branches** in the repos the work touches (`bin/home where <repo>`):
   ```bash
   git -C <repo> fetch --quiet origin
   git -C <repo> log --all --remotes --not origin/<default> --oneline -i --grep "<term>" | head
   git -C <repo> log --all --remotes --not origin/<default> --oneline -S "<codeName>" | head
   ```
   `-S` finds commits that add or remove that symbol, even if the message doesn't mention it.
5. **Already in the code.** Search the default branch of those repos (`git -C <repo> grep -n "<codeName>" origin/<default>`) and the wiki (`grep -ril "<term>" wiki/`).
6. **Report** in a few lines: what exists, where (spec, PR, branch with commit, file), who owns it, and your recommendation: reuse it, wait for its merge, coordinate with its owner, or go ahead. Example: "A `formatMoney` helper exists on `feat/checkout` (commit 1a2b3c4, Ana), not on `main`. Reuse it: base your branch on it or wait for its PR."
7. **Claim your work** once you go ahead: create `specs/<slug>/spec.md` (status `draft`, `owner`, `repos`), or for a small change a one-paragraph `specs/<slug>/spec.md` with `status: building`, and `bin/home save "spec: claim <slug>"`. Others' overlap checks will now find you.
