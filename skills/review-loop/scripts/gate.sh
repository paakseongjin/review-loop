#!/usr/bin/env bash
# review-loop mechanical gate.
# Auto-detects the stack and runs only checks whose tools already exist.
# A check whose tool is missing is reported SKIPPED — never PASS.
# This script installs nothing. Tests and builds may modify files or use network access.
# Usage: bash gate.sh [project-dir]   (default: current directory)
# Exit code: 0 if no FAIL, 1 if any check FAILed. SKIPPED does not fail.

set -u
cd "${1:-.}" || exit 2

PASS=0; FAIL=0; SKIP=0
declare -a ROWS=()

run_check() {
  local name="$1"; shift
  local cmd_str="$1"; shift
  if ! command -v "$1" >/dev/null 2>&1; then
    ROWS+=("| $name | SKIPPED | - | tool not found: $1 |")
    SKIP=$((SKIP+1)); return
  fi
  local out rc
  out="$("$@" 2>&1)"; rc=$?
  if [ $rc -eq 0 ]; then
    ROWS+=("| $name | PASS | $rc | \`$cmd_str\` |")
    PASS=$((PASS+1))
  else
    ROWS+=("| $name | FAIL | $rc | \`$cmd_str\` |")
    FAIL=$((FAIL+1))
    echo "FAIL: $name (output suppressed; it may contain secrets)."
  fi
}

echo "== review-loop gate: $(pwd) =="

if [ -f package.json ]; then
  if command -v node >/dev/null 2>&1; then
    PM="npm"; [ -f pnpm-lock.yaml ] && PM="pnpm"; [ -f yarn.lock ] && PM="yarn"; { [ -f bun.lockb ] || [ -f bun.lock ]; } && PM="bun"
    if node -e "process.exit((require('./package.json').scripts||{}).test?0:1)" 2>/dev/null; then
      run_check "tests" "$PM test" $PM test
    else
      ROWS+=("| tests | SKIPPED | - | no test script in package.json |"); SKIP=$((SKIP+1))
    fi
    if [ -d node_modules/typescript ]; then
      run_check "types" "npx tsc --noEmit" npx tsc --noEmit
    else
      ROWS+=("| types | SKIPPED | - | local TypeScript not found |"); SKIP=$((SKIP+1))
    fi
    if node -e "process.exit((require('./package.json').scripts||{}).lint?0:1)" 2>/dev/null; then
      run_check "lint" "$PM run lint" $PM run lint
    else
      ROWS+=("| lint | SKIPPED | - | no lint script in package.json |"); SKIP=$((SKIP+1))
    fi
    if node -e "process.exit((require('./package.json').scripts||{}).build?0:1)" 2>/dev/null; then
      run_check "build" "$PM run build" $PM run build
    else
      ROWS+=("| build | SKIPPED | - | no build script in package.json |"); SKIP=$((SKIP+1))
    fi
    [ "$PM" = "npm" ] && run_check "deps-audit" "npm audit --audit-level=high" npm audit --audit-level=high
    [ "$PM" = "pnpm" ] && run_check "deps-audit" "pnpm audit --audit-level high" pnpm audit --audit-level high
    if [ "$PM" = "yarn" ] || [ "$PM" = "bun" ]; then
      ROWS+=("| deps-audit | SKIPPED | - | audit not configured for $PM |"); SKIP=$((SKIP+1))
    fi
  else
    ROWS+=("| node | SKIPPED | - | node not found |"); SKIP=$((SKIP+1))
  fi
fi

if [ -f pyproject.toml ] || [ -f requirements.txt ] || [ -f setup.py ]; then
  run_check "tests" "pytest -q" pytest -q
  run_check "lint" "ruff check ." ruff check .
  run_check "deps-audit" "pip-audit" pip-audit
fi

if [ -f go.mod ]; then
  run_check "tests" "go test ./..." go test ./...
  run_check "vet" "go vet ./..." go vet ./...
  run_check "build" "go build ./..." go build ./...
fi

if [ -f Cargo.toml ]; then
  run_check "tests" "cargo test" cargo test
  run_check "build" "cargo build" cargo build
fi

# Stack-independent checks (only if the tools are already installed)
run_check "secrets" "gitleaks detect --no-banner --redact" gitleaks detect --no-banner --redact
run_check "sast-semgrep" "semgrep --config auto --error" semgrep --config auto --error

echo
echo "| Check | Result | Exit | Command |"
echo "|---|---|---|---|"
for r in "${ROWS[@]}"; do echo "$r"; done
echo
echo "Summary: PASS=$PASS FAIL=$FAIL SKIPPED=$SKIP"
echo "Exit 0 means no check failed; skipped or undetected checks are not passes."
[ $FAIL -eq 0 ]
