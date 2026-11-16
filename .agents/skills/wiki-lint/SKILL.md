---
name: wiki-lint
description: Health check of the home repo's wiki (the "sleep" pass of an LLM wiki). Runs bin/home check, then looks for contradictions, stale claims, pages that no longer match the code, duplicates to merge, overlong pages, missing pages for repeated questions and open questions already answered; fixes what it can and saves. Use weekly, when the wiki feels noisy, or when asked to clean or audit the wiki.
---

# Wiki lint

1. `bin/home sync`, then `bin/home check`. Fix every mechanical problem: missing frontmatter, broken links, orphans (link them from their project, repo or provider page), `superseded_by` without `status: superseded`.
2. **Contradictions.** Read pages of the same topic together (all decisions of one module, a provider page and its incidents). Two accepted decisions that disagree: the later one supersedes the earlier one if it was meant to; if not, mark both `draft` and list them in the hand-over.
3. **Stale against code.** For pages that cite `repo:path:line` in repos cloned on this machine (`bin/home where <repo>`), check the file and symbol still exist on the default branch. Fix the page or mark it `draft` with a note.
4. **Open incidents.** For each `status: open` incident, check whether the fix was merged (`git log origin/<default> -i --grep "<term>"` in that repo, or the host's merged PRs). If so, mark it `resolved` with the PR.
5. **Duplicates and size.** Merge pages that cover the same thing into one and leave a link. Split a page over ~300 lines by subtopic.
6. **Gaps.** A term used on many pages without its own page (a provider, a module, an acronym) gets a page or a `wiki/concepts/glossary.md` entry.
7. Save: `bin/home log lint "<summary>"`, then `bin/home save "wiki: lint <date>"`. Report what changed and what needs a human (contradictions you couldn't settle).
