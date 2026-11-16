#!/usr/bin/env bash
# Worktree lifecycle for /deliver, so the orchestrator never hand-writes
# `rm`/`ln` with shell variables (agent safety checks block those and stall an
# unattended run).
#
#   worktree.sh integration <slug> [base]   create feat/<slug> in <parent>/<slug>,
#                                           from base (default: current branch),
#                                           and install dependencies once
#   worktree.sh add <NN>                    (run inside the integration worktree)
#                                           create feat/<slug>--NN in <integration>--NN
#                                           and link node_modules; reuses it if present
#   worktree.sh remove <NN>                 unlink node_modules, remove the worktree,
#                                           delete the branch if it is merged
#   worktree.sh path <NN>                   print a ticket worktree's path
#   worktree.sh close <slug> [--discard]    remove the integration worktree <parent>/<slug>
#                                           and any ticket worktree left; keeps feat/<slug>
#                                           (it lives on in the PR) unless --discard,
#                                           which also deletes feat/<slug> and its ticket
#                                           branches. Run it from another worktree.
#   worktree.sh repo <name>                 print the path of a related repo on this machine
#                                           (a sibling folder whose name or origin is <name>)
#   worktree.sh --repo <path> <command> ... run any command above in another repo. Its
#                                           integration worktree is <parent>/<repo>--<slug>
#                                           and is installed with its own package manager.
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
other_repo=""
if [ "${1:-}" = "--repo" ]; then
  other_repo="$(cd "${2:?repo path required}" && pwd)"
  shift 2
fi
cmd="${1:?usage: worktree.sh [--repo <path>] integration|add|remove|path|close|repo ...}"
here="$(git -C "${other_repo:-.}" rev-parse --show-toplevel)"
# The repo's main checkout: where untracked files such as .env live.
main_checkout="$(git -C "$here" worktree list --porcelain | sed -n '1s/^worktree //p')"

# Folder of a new integration worktree. This repo keeps <parent>/<slug>; another repo
# gets its name in front, so two repos with the same slug never share a folder.
integration_dest() {
  local slug="$1"
  if [ -n "$other_repo" ]; then
    echo "$(dirname "$main_checkout")/$(basename "$main_checkout")--$slug"
  else
    echo "$(dirname "$here")/$slug"
  fi
}

install_deps() {
  local dir="$1"
  [ -f "$dir/package.json" ] || return 0
  [ -d "$dir/node_modules" ] && return 0
  if [ -f "$dir/yarn.lock" ]; then set -- yarn install --frozen-lockfile --non-interactive
  elif [ -f "$dir/pnpm-lock.yaml" ]; then set -- pnpm install --frozen-lockfile
  elif ls "$dir"/bun.lock* >/dev/null 2>&1; then set -- bun install --frozen-lockfile
  else set -- npm ci
  fi
  (cd "$dir" && bash "$script_dir/heavy.sh" "$@")
}

# Untracked env files (.env, .env.local, .env.local-development, ...) from the main
# checkout, linked so a server started from the worktree has its config. Linked, never
# copied or edited.
link_env_files() {
  local dir="$1" f
  [ "$dir" = "$main_checkout" ] && return 0
  for f in "$main_checkout"/.env*; do
    [ -f "$f" ] || continue
    git -C "$main_checkout" ls-files --error-unmatch "$(basename "$f")" >/dev/null 2>&1 && continue
    [ -e "$dir/$(basename "$f")" ] || ln -s "$f" "$dir/$(basename "$f")"
  done
}

# Repos connected to the home repo get their skills and scripts as git-ignored links
# (.agents/home.sh link). A new worktree needs its own links.
home_links() {
  local dir="$1"
  # Run it from inside the worktree: home.sh links into the repo it is run from.
  if [ -f "$dir/.agents/home.sh" ]; then (cd "$dir" && bash .agents/home.sh "$2" >/dev/null 2>&1) || true; fi
}

integration_slug() {
  local branch
  branch="$(git -C "$here" branch --show-current)"
  case "$branch" in
    feat/*) echo "${branch#feat/}" ;;
    *) echo "worktree.sh: run '$cmd' inside the integration worktree (branch feat/<slug>), not '$branch'" >&2; exit 2 ;;
  esac
}

case "$cmd" in
  integration)
    slug="${2:?slug required}"
    base="${3:-$(git -C "$here" branch --show-current)}"
    dest="$(integration_dest "$slug")"
    if git -C "$here" show-ref --quiet "refs/heads/feat/$slug"; then
      [ -d "$dest" ] || git -C "$here" worktree add "$dest" "feat/$slug" >&2
    else
      git -C "$here" worktree add -b "feat/$slug" "$dest" "$base" >&2
    fi
    install_deps "$dest"
    link_env_files "$dest"
    home_links "$dest" link
    echo "$dest"
    ;;
  add)
    nn="${2:?ticket number required}"
    slug="$(integration_slug)"
    dest="$here--$nn"
    branch="feat/$slug--$nn"
    if [ ! -d "$dest" ]; then
      if git -C "$here" show-ref --quiet "refs/heads/$branch"; then
        git -C "$here" worktree add "$dest" "$branch" >&2
      else
        git -C "$here" worktree add -b "$branch" "$dest" "feat/$slug" >&2
      fi
    fi
    if [ -d "$here/node_modules" ] && [ ! -e "$dest/node_modules" ]; then
      ln -s "$here/node_modules" "$dest/node_modules"
    fi
    home_links "$dest" link
    echo "$dest"
    ;;
  remove)
    nn="${2:?ticket number required}"
    slug="$(integration_slug)"
    dest="$here--$nn"
    branch="feat/$slug--$nn"
    if [ -L "$dest/node_modules" ]; then unlink "$dest/node_modules"; fi
    home_links "$dest" unlink
    if [ -d "$dest" ]; then git -C "$here" worktree remove "$dest"; fi
    if git -C "$here" branch --merged HEAD | grep -qx "  $branch"; then
      git -C "$here" branch -d "$branch" >/dev/null
    fi
    echo "removed $dest"
    ;;
  path)
    echo "$here--${2:?ticket number required}"
    ;;
  close)
    slug="${2:?slug required}"
    discard="${3:-}"
    dest="$(integration_dest "$slug")"
    if [ "$here" = "$dest" ]; then
      echo "worktree.sh: run 'close' from another worktree, not from $dest itself" >&2; exit 2
    fi
    for wt in "$dest"--*; do
      [ -d "$wt" ] || continue
      if [ -L "$wt/node_modules" ]; then unlink "$wt/node_modules"; fi
      home_links "$wt" unlink
      for f in "$wt"/.env*; do if [ -L "$f" ]; then unlink "$f"; fi; done
      git -C "$here" worktree remove --force "$wt"
    done
    for f in "$dest"/.env*; do if [ -L "$f" ]; then unlink "$f"; fi; done
    home_links "$dest" unlink
    if [ -d "$dest" ]; then git -C "$here" worktree remove "$dest"; fi
    git -C "$here" worktree prune
    if [ "$discard" = "--discard" ]; then
      git -C "$here" for-each-ref --format='%(refname:short)' "refs/heads/feat/$slug" "refs/heads/feat/$slug--*" |
        while read -r b; do git -C "$here" branch -D "$b" >/dev/null; echo "deleted branch $b"; done
    fi
    echo "closed $dest"
    ;;
  repo)
    name="${2:?repo name required}"
    # Ask the home repo first: it knows every mapped repo wherever it is cloned.
    brain="$(cd "$(dirname "$(readlink -f "$0" 2>/dev/null || echo "$0")")/../.." 2>/dev/null && pwd)"
    if [ -x "$brain/bin/home" ] && dir="$("$brain/bin/home" where "$name" 2>/dev/null)"; then
      git -C "$dir" worktree list --porcelain | sed -n '1s/^worktree //p'
      exit 0
    fi
    # Otherwise look next to this repo's main checkout and next to the current worktree.
    for parent in "$(dirname "$main_checkout")" "$(dirname "$here")"; do
      for dir in "$parent"/*/; do
        dir="${dir%/}"
        [ -e "$dir/.git" ] || continue
        origin="$(git -C "$dir" remote get-url origin 2>/dev/null || true)"
        origin="$(basename "${origin%.git}")"
        if [ "$(basename "$dir")" = "$name" ] || [ "$origin" = "$name" ]; then
          git -C "$dir" worktree list --porcelain | sed -n '1s/^worktree //p'
          exit 0
        fi
      done
    done
    echo "worktree.sh: no repo named '$name' next to $(dirname "$main_checkout")" >&2
    exit 3
    ;;
  *)
    echo "worktree.sh: unknown command '$cmd'" >&2; exit 2 ;;
esac
