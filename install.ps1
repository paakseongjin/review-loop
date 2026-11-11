# Install the review-loop skill into a project (Windows).
# Usage: .\install.ps1 C:\path\to\project [claude|cursor|both]   (default: both)
param(
  [Parameter(Mandatory=$true)][string]$Target,
  [ValidateSet("claude", "cursor", "both")][string]$Mode = "both"
)
$ErrorActionPreference = "Stop"
$Src = Split-Path -Parent $MyInvocation.MyCommand.Path
$Stamp = Get-Date -Format "yyyyMMdd-HHmmss"
if (-not (Test-Path -LiteralPath $Target -PathType Container)) { throw "Target directory does not exist: $Target" }

function Backup-Item([string]$Path) {
  $Candidate = "$Path.bak-$Stamp"
  $Index = 0
  while (Test-Path -LiteralPath $Candidate) {
    $Index++
    $Candidate = "$Path.bak-$Stamp-$Index"
  }
  Move-Item -LiteralPath $Path -Destination $Candidate
  Write-Host "backed up existing: $Candidate"
}

function Install-Skill([string]$Dest) {
  if (Test-Path $Dest) {
    Backup-Item $Dest
  }
  New-Item -ItemType Directory -Force -Path (Split-Path $Dest) | Out-Null
  Copy-Item -Recurse (Join-Path $Src "skills\review-loop") $Dest
  Write-Host "installed skill -> $Dest"
}

if ($Mode -eq "claude" -or $Mode -eq "both") {
  Install-Skill (Join-Path $Target ".claude\skills\review-loop")
}
if ($Mode -eq "cursor" -or $Mode -eq "both") {
  Install-Skill (Join-Path $Target ".cursor\skills\review-loop")
  $RulesDir = Join-Path $Target ".cursor\rules"
  New-Item -ItemType Directory -Force -Path $RulesDir | Out-Null
  $RuleDest = Join-Path $RulesDir "review-loop-guardrails.mdc"
  if (Test-Path $RuleDest) { Backup-Item $RuleDest }
  Copy-Item (Join-Path $Src "cursor\review-loop-guardrails.mdc") $RuleDest
  Write-Host "installed cursor rule -> $RuleDest"
}
Write-Host "done. In Claude Code run /review-loop, in Cursor run /review-loop in Agent chat."
