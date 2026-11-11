# Mechanical Gates by Stack

Rule: use the project's own scripts/configs when they exist
(`package.json` scripts, `Makefile`, CI config). The table is a
fallback for discovering what to run. Record every command and exit
code. A tool that is not installed is SKIPPED, not PASS.

## Node / TypeScript

| Check | Command (first that exists) |
|---|---|
| Tests | `npm test` / `pnpm test` / `yarn test` / `bun test` |
| Types | `npx tsc --noEmit` (if typescript is a dependency) |
| Lint | `npm run lint` or `npx eslint .` |
| Build | `npm run build` (if a build script exists) |
| Deps audit | `npm audit --audit-level=high` / `pnpm audit` |
| Secrets | `gitleaks detect --no-banner --redact` (if installed) |
| SAST | `semgrep --config auto` (if installed) |

## Python

| Check | Command |
|---|---|
| Tests | `pytest -q` |
| Types | `mypy .` or `pyright` (if configured) |
| Lint | `ruff check .` or `flake8` (if configured) |
| Deps audit | `pip-audit` (if installed) |
| Secrets | `gitleaks detect --no-banner --redact` |
| SAST | `bandit -r .` or `semgrep --config auto` (if installed) |

## Go

| Check | Command |
|---|---|
| Tests | `go test ./...` |
| Vet | `go vet ./...` |
| Build | `go build ./...` |
| Deps audit | `govulncheck ./...` (if installed) |
| SAST | `gosec ./...` or `semgrep` (if installed) |

## Rust

| Check | Command |
|---|---|
| Tests | `cargo test` |
| Lint | `cargo clippy -- -D warnings` |
| Build | `cargo build` |
| Deps audit | `cargo audit` (if installed) |

## Any stack

- **Baseline comparison:** run the same gate on the base ref
  (e.g. `git stash` is forbidden — use a worktree or
  `git checkout <base>` in a scratch clone). Failures that exist on
  base are pre-existing: report them separately. They still prevent
  an unconditional deployable verdict until resolved or explicitly
  covered by a documented condition.
- **Database checks** (when a DB is reachable in the environment):
  list constraints on tables the change writes to
  (UNIQUE / CHECK / FK / NOT NULL) and confirm Lens 2 invariants are
  enforced in the schema, not only in code.
- **E2E smoke** (when Playwright/Cypress exists): run the existing
  e2e suite; a missing e2e suite on a `public`/`critical` tier is a
  Minor finding plus an UNVERIFIED note on user-flow coverage.
