#!/usr/bin/env python3
"""Validate the review-loop package structure.
Checks: required files exist, SKILL.md frontmatter (name/description,
name matches folder, body < 500 lines), plugin/marketplace JSON parses,
internal markdown references resolve, gate.sh is syntactically valid bash.
Exit 0 = all pass."""
import json, re, shutil, subprocess, sys, os
from pathlib import Path

ROOT = Path(__file__).resolve().parent
errors, notes = [], []

required = [
    "README.md", "install.sh", "install.ps1",
    ".claude-plugin/plugin.json", ".claude-plugin/marketplace.json",
    "skills/review-loop/SKILL.md",
    "skills/review-loop/references/lenses.md",
    "skills/review-loop/references/loop-engineering.md",
    "skills/review-loop/references/evaluation-cases.md",
    "skills/review-loop/references/evidence-and-severity.md",
    "skills/review-loop/references/mechanical-gates.md",
    "skills/review-loop/templates/review-report.md",
    "skills/review-loop/templates/spec-invariants.md",
    "skills/review-loop/templates/fix-loop-log.md",
    "skills/review-loop/templates/project-guardrails.md",
    "skills/review-loop/scripts/gate.sh",
    "cursor/review-loop-guardrails.mdc",
    "examples/example-report.md",
]
for rel in required:
    if not (ROOT / rel).is_file():
        errors.append(f"missing file: {rel}")

skill = ROOT / "skills/review-loop/SKILL.md"
if skill.is_file():
    text = skill.read_text(encoding="utf-8")
    m = re.match(r"^---\n(.*?)\n---\n", text, re.S)
    if not m:
        errors.append("SKILL.md: frontmatter block not found at top")
    else:
        fm = m.group(1)
        name = re.search(r"^name:\s*(\S+)\s*$", fm, re.M)
        desc = re.search(r"^description:\s*(.+)$", fm, re.M)
        if not name or name.group(1) != "review-loop":
            errors.append("SKILL.md: frontmatter name must be 'review-loop'")
        if not desc or len(desc.group(1)) < 40:
            errors.append("SKILL.md: description missing or too short")
        if not re.fullmatch(r"[a-z0-9-]+", name.group(1) if name else ""):
            errors.append("SKILL.md: name must be lowercase letters, digits, hyphens")
    lines = text.count("\n") + 1
    notes.append(f"SKILL.md lines: {lines} (limit 500)")
    if lines >= 500:
        errors.append("SKILL.md: must stay under 500 lines")
    # internal references like `references/x.md`, `templates/x.md`, `scripts/x.sh`
    for ref in sorted(set(re.findall(r"`((?:references|templates|scripts)/[\w.\-]+)`", text))):
        if not (skill.parent / ref).is_file():
            errors.append(f"SKILL.md references missing file: {ref}")

for jf in [".claude-plugin/plugin.json", ".claude-plugin/marketplace.json"]:
    p = ROOT / jf
    if p.is_file():
        try:
            data = json.loads(p.read_text(encoding="utf-8"))
            if jf.endswith("plugin.json") and data.get("name") != "review-loop":
                errors.append("plugin.json: name must be 'review-loop'")
            if jf.endswith("marketplace.json"):
                names = [pl.get("name") for pl in data.get("plugins", [])]
                if "review-loop" not in names:
                    errors.append("marketplace.json: plugins[] must include review-loop")
        except json.JSONDecodeError as e:
            errors.append(f"{jf}: invalid JSON: {e}")

mdc = ROOT / "cursor/review-loop-guardrails.mdc"
if mdc.is_file():
    t = mdc.read_text(encoding="utf-8")
    if "alwaysApply: true" not in t:
        errors.append("cursor rule: expected 'alwaysApply: true' in frontmatter")

bash = shutil.which("bash")
if not bash and os.name == "nt":
    candidate = Path(os.environ.get("ProgramFiles", r"C:\Program Files")) / "Git/bin/bash.exe"
    if candidate.is_file():
        bash = str(candidate)
if not bash:
    errors.append("bash not found: shell syntax checks could not be run")

gate = ROOT / "skills/review-loop/scripts/gate.sh"
if gate.is_file() and bash:
    r = subprocess.run([bash, "-n", str(gate)], capture_output=True, text=True)
    if r.returncode != 0:
        errors.append(f"gate.sh: bash syntax error: {r.stderr.strip()}")

inst = ROOT / "install.sh"
if inst.is_file() and bash:
    r = subprocess.run([bash, "-n", str(inst)], capture_output=True, text=True)
    if r.returncode != 0:
        errors.append(f"install.sh: bash syntax error: {r.stderr.strip()}")

for n in notes:
    print(f"note: {n}")
if errors:
    print("VALIDATION FAILED")
    for e in errors:
        print(f" - {e}")
    sys.exit(1)
print("VALIDATION PASSED: all required files, frontmatter, JSON, references, and shell syntax OK")
