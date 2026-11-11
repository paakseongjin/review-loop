#!/usr/bin/env bash
# Install the review-loop skill into a project.
# Usage: bash install.sh /path/to/project [claude|cursor|both]   (default: both)
# - claude: copies skills/review-loop -> <project>/.claude/skills/review-loop
# - cursor: copies skills/review-loop -> <project>/.cursor/skills/review-loop
#           and cursor/review-loop-guardrails.mdc -> <project>/.cursor/rules/
# Nothing outside the target project is touched. Existing installs are
# backed up to <name>.bak-YYYYMMDD-HHMMSS inside the target.
set -eu
SRC="$(cd "$(dirname "$0")" && pwd)"
TARGET="${1:?usage: install.sh /path/to/project [claude|cursor|both]}"
MODE="${2:-both}"
STAMP="$(date +%Y%m%d-%H%M%S)"
case "$MODE" in claude|cursor|both) ;; *) echo "Invalid mode: $MODE" >&2; exit 2 ;; esac
[ -d "$TARGET" ] || { echo "Target directory does not exist: $TARGET" >&2; exit 2; }
backup() {
  local path="$1" candidate="$1.bak-$STAMP" n=0
  while [ -e "$candidate" ]; do n=$((n+1)); candidate="$path.bak-$STAMP-$n"; done
  mv "$path" "$candidate"
  echo "backed up existing: $candidate"
}

install_skill() {
  local dest="$1"
  if [ -e "$dest" ]; then backup "$dest"; fi
  mkdir -p "$(dirname "$dest")"
  cp -R "$SRC/skills/review-loop" "$dest"
  echo "installed skill -> $dest"
}

case "$MODE" in
  claude|both) install_skill "$TARGET/.claude/skills/review-loop" ;;
esac
case "$MODE" in
  cursor|both)
    install_skill "$TARGET/.cursor/skills/review-loop"
    mkdir -p "$TARGET/.cursor/rules"
    if [ -e "$TARGET/.cursor/rules/review-loop-guardrails.mdc" ]; then
      backup "$TARGET/.cursor/rules/review-loop-guardrails.mdc"
    fi
    cp "$SRC/cursor/review-loop-guardrails.mdc" "$TARGET/.cursor/rules/review-loop-guardrails.mdc"
    echo "installed cursor rule -> $TARGET/.cursor/rules/review-loop-guardrails.mdc"
    ;;
esac
echo "done. In Claude Code run /review-loop, in Cursor run /review-loop in Agent chat."
