#!/usr/bin/env bash
# Connects this repo to its home repo (__HOME_NAME__, __HOME_URL__): the shared
# skills, scripts, specs and wiki. Managed by the home repo (agent-home kit); update it with
# `bin/home connect <repo>` there, not by hand.
#
#   home.sh path     print the the home repo path (exit 1 if not found)
#   home.sh link     link each shared skill, script and Claude sub-agent into this
#                    worktree, one link per item, next to the repo's own ones (a real
#                    file or folder of the repo always wins). Links are excluded from
#                    git locally (.git/info/exclude), never committed. Also lets Claude
#                    Code (.claude/settings.local.json) and Antigravity (a read_file rule in
#                    ~/.gemini/antigravity-cli/settings.json) read the home repo without a prompt.
#   home.sh unlink   remove those links (worktree.sh runs it before removing a worktree)
#   home.sh sync     pull the home repo (fast-forward only), then link. Session hooks run it.
#                    If the home repo isn't on this machine, it clones it next to this repo
#                    first (with the developer's own git access; no access = no-op).
#
# Where the home repo is: $AGENT_HOME, else the path it recorded in
# ~/.config/agent-home/__HOME_NAME__ (so repos cloned in different folders share one home), else
# next to this repo's main checkout, else next to this worktree.
set -euo pipefail
HOME_NAME="__HOME_NAME__"
HOME_URL="__HOME_URL__"

top="$(git rev-parse --show-toplevel)"
main_checkout="$(git -C "$top" worktree list --porcelain | sed -n '1s/^worktree //p')"
exclude="$(git -C "$top" rev-parse --git-common-dir)/info/exclude"
case "$exclude" in /*) ;; *) exclude="$top/$exclude" ;; esac

find_home() {
  local c
  for c in "${AGENT_HOME:-}" "$(cat "$HOME/.config/agent-home/$HOME_NAME" 2>/dev/null || true)" \
           "$(dirname "$main_checkout")/$HOME_NAME" "$(dirname "$top")/$HOME_NAME"; do
    if [ -n "$c" ] && [ -f "$c/bin/home" ]; then (cd "$c" && pwd); return 0; fi
  done
  echo "home.sh: $HOME_NAME not found; clone $HOME_URL next to $(basename "$main_checkout") or set AGENT_HOME" >&2
  return 1
}

exclude_path() {
  mkdir -p "$(dirname "$exclude")"
  touch "$exclude"
  grep -qxF "/$1" "$exclude" || echo "/$1" >> "$exclude"
}

# Link every entry of <home>/<src> into <repo>/<dest>/, skipping names the repo already has.
link_each() {
  local home="$1" src="$2" dest="$3" item name
  [ -d "$home/$src" ] || return 0
  if [ -L "$top/$dest" ]; then return 0; fi  # the repo links the whole folder itself
  mkdir -p "$top/$dest"
  for item in "$home/$src"/*; do
    [ -e "$item" ] || continue
    name="$(basename "$item")"
    if [ -e "$top/$dest/$name" ] && [ ! -L "$top/$dest/$name" ]; then continue; fi
    ln -sfn "$item" "$top/$dest/$name"
    exclude_path "$dest/$name"
  done
}

allow_read() {
  local home="$1" f="$top/.claude/settings.local.json"
  command -v python3 >/dev/null || return 0
  mkdir -p "$top/.claude"
  python3 - "$f" "$home" <<'PY'
import json, os, sys
path, home = sys.argv[1], sys.argv[2]
data = {}
if os.path.exists(path):
    try:
        data = json.load(open(path))
    except ValueError:
        sys.exit(0)  # leave a file we can't parse alone
dirs = data.setdefault("permissions", {}).setdefault("additionalDirectories", [])
if home not in dirs:
    dirs.append(home)
    json.dump(data, open(path, "w"), indent=2)
PY
  exclude_path ".claude/settings.local.json"
  # Antigravity (agy) in headless mode denies reads outside the workspace unless allowed.
  local agy="$HOME/.gemini/antigravity-cli/settings.json"
  if [ -f "$agy" ]; then
    python3 - "$agy" "$home" <<'PY'
import json, sys
path, home = sys.argv[1], sys.argv[2]
try:
    data = json.load(open(path))
except ValueError:
    sys.exit(0)
rule = f"read_file({home})"
allow = data.setdefault("permissions", {}).setdefault("allow", [])
if rule not in allow:
    allow.append(rule)
    json.dump(data, open(path, "w"), indent=2)
PY
  fi
}

do_link() {
  local home
  home="$(find_home)"
  link_each "$home" ".agents/skills" ".agents/skills"
  link_each "$home" ".agents/skills" ".claude/skills"
  link_each "$home" ".agents/scripts" ".agents/scripts"
  link_each "$home" ".claude/agents" ".claude/agents"
  if [ ! -e "$top/.agents/models.json" ] || [ -L "$top/.agents/models.json" ]; then
    ln -sfn "$home/.agents/models.json" "$top/.agents/models.json"
    exclude_path ".agents/models.json"
  fi
  allow_read "$home"
}

do_unlink() {
  local l
  for l in "$top"/.agents/skills/* "$top"/.claude/skills/* "$top"/.agents/scripts/* "$top"/.claude/agents/* "$top/.agents/models.json"; do
    if [ -L "$l" ] && case "$(readlink "$l")" in *"/$HOME_NAME/"*) true ;; *) false ;; esac; then unlink "$l"; fi
  done
}

case "${1:-}" in
  path) find_home ;;
  link) do_link ;;
  unlink) do_unlink ;;
  sync)
    if ! home="$(find_home 2>/dev/null)"; then
      git clone --quiet "$HOME_URL" "$(dirname "$main_checkout")/$HOME_NAME" 2>/dev/null || exit 0
      home="$(find_home)" || exit 0
      bash "$home/bin/home" setup --quiet >/dev/null 2>&1 || true
    fi
    if [ -n "$(git -C "$home" remote)" ]; then git -C "$home" pull --ff-only --quiet || true; fi
    do_link ;;
  *) echo "usage: home.sh path|link|unlink|sync" >&2; exit 2 ;;
esac
