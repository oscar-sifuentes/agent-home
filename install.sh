#!/usr/bin/env bash
# agent-home installer: create a home repo, or update one to the latest kit.
#
#   install.sh new <name> [--dir <parent>] [--host github|gitlab|bitbucket|none] [--owner <org>]...
#   install.sh update [<home repo path>]
#
# Run it from a clone of the kit, or straight from the web:
#   curl -fsSL https://raw.githubusercontent.com/oscar-sifuentes/agent-home/main/install.sh | bash -s -- new acme-home
set -euo pipefail

KIT_URL="${AGENT_HOME_KIT_URL:-https://github.com/oscar-sifuentes/agent-home.git}"
# Files and folders the kit owns: `update` replaces them, everything else in a home repo is the project's.
KIT_PATHS=(bin templates .agents/scripts .agents/models.json .claude/settings.json .claude/skills CLAUDE.md .gitattributes)

die() { echo "install.sh: $*" >&2; exit 1; }

kit_dir() {
  local here
  here="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"
  if [ -n "$here" ] && [ -x "$here/bin/home" ] && [ -d "$here/templates/connect" ]; then echo "$here"; return; fi
  local tmp; tmp="$(mktemp -d)"
  git clone --quiet --depth 1 "$KIT_URL" "$tmp/kit" || die "could not clone $KIT_URL"
  echo "$tmp/kit"
}

copy_kit_paths() {   # <kit> <target>
  local kit="$1" target="$2" p
  for p in "${KIT_PATHS[@]}"; do
    [ -e "$kit/$p" ] || [ -L "$kit/$p" ] || continue
    mkdir -p "$target/$(dirname "$p")"
    rm -rf "${target:?}/$p"
    cp -RP "$kit/$p" "$target/$p"
  done
  # skills and sub-agents: replace the kit's own, keep the project's
  local d
  for d in "$kit"/.agents/skills/*/; do
    d="${d%/}"; mkdir -p "$target/.agents/skills"
    rm -rf "$target/.agents/skills/$(basename "$d")"; cp -R "$d" "$target/.agents/skills/"
  done
  mkdir -p "$target/.claude/agents"
  cp "$kit"/.claude/agents/*.md "$target/.claude/agents/"
  # .gitignore: add the kit's lines that are missing
  touch "$target/.gitignore"
  while IFS= read -r line; do
    grep -qxF "$line" "$target/.gitignore" || echo "$line" >> "$target/.gitignore"
  done < "$kit/.gitignore"
}

kit_section() {   # print the kit section of the kit's AGENTS.md
  sed -n '/<!-- kit:start/,/<!-- kit:end -->/p' "$1/AGENTS.md"
}

cmd_new() {
  local name="${1:-}"; [ -n "$name" ] && [ "${name#--}" = "$name" ] || die "usage: install.sh new <name> [--dir <parent>] [--host H] [--owner O]..."
  shift
  local parent="$PWD" init_args=()
  while [ $# -gt 0 ]; do
    case "$1" in
      --dir) parent="$2"; shift 2 ;;
      --host|--owner) init_args+=("$1" "$2"); shift 2 ;;
      *) die "unknown option $1" ;;
    esac
  done
  local target; target="$(mkdir -p "$parent" && cd "$parent" && pwd)/$name"
  [ -e "$target" ] && die "$target already exists"
  local kit; kit="$(kit_dir)"
  mkdir -p "$target"/{wiki/{projects,repos,decisions,incidents,runbooks,rules,concepts,research},specs,raw}
  copy_kit_paths "$kit" "$target"
  cp "$kit/AGENTS.md" "$target/AGENTS.md"
  cp "$kit/repos.local.yaml.example" "$target/"
  for d in specs raw wiki/projects wiki/repos wiki/decisions wiki/incidents wiki/runbooks wiki/rules wiki/concepts wiki/research; do touch "$target/$d/.gitkeep"; done
  cat > "$target/README.md" <<README
# $name

Home repo for **$name** (agent-home kit): the repo map, the wiki, the specs and the shared agent skills.
Open your coding agent here, or in any connected repo. Rules for agents: [AGENTS.md](AGENTS.md).

\`\`\`bash
bin/home connect <path to a code repo>   # connect a repo (review and commit the files it writes)
bin/home repos                           # which repos are on this machine
\`\`\`
README
  git -C "$target" init --quiet -b main
  (cd "$target" && python3 bin/home init "$name" "${init_args[@]+"${init_args[@]}"}")
  git -C "$target" add -A
  git -C "$target" commit --quiet -m "Start $name from agent-home"
  echo
  echo "Created $target"
  echo "Next: add a private remote and push (git -C $target remote add origin <url>; git -C $target push -u origin main),"
  echo "then connect your repos: $target/bin/home connect <path>"
}

cmd_update() {
  local target; target="$(cd "${1:-.}" && pwd)"
  [ -x "$target/bin/home" ] && [ -f "$target/home.yaml" ] || die "$target is not a home repo (no bin/home or home.yaml)"
  local kit; kit="$(kit_dir)"
  copy_kit_paths "$kit" "$target"
  python3 - "$target/AGENTS.md" "$(kit_section "$kit")" <<'PY'
import re, sys
path, section = sys.argv[1], sys.argv[2]
text = open(path).read()
if "<!-- kit:start" in text:
    text = re.sub(r"<!-- kit:start.*?<!-- kit:end -->", lambda m: section.strip(), text, flags=re.S)
else:
    text = text.replace("\n", "\n\n" + section.strip() + "\n", 1)
open(path, "w").write(text)
PY
  (cd "$target" && bin/home pointers && bin/home index)
  echo "Updated the kit files in $target. Review with git diff, then: bin/home save \"kit: update\""
}

case "${1:-}" in
  new) shift; cmd_new "$@" ;;
  update) shift; cmd_update "$@" ;;
  *) sed -n '2,8p' "${BASH_SOURCE[0]:-$0}" 2>/dev/null || echo "usage: install.sh new <name> | update [<path>]"; exit 2 ;;
esac
