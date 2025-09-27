README — Programmatic onboarding for DoctorGPhD ruleset (non-blocking)

Purpose
-------
- Add stable check contexts so they appear in the Ruleset UI and can be selected.
- Patch the DoctorGPhD ruleset programmatically to include the new contexts while keeping enforcement unchanged (onboard non-blocking).

Summary of approach
1) Add the workflow file (`.github/workflows/onboard-status-checks.yml`) and open a Draft PR against `main` OR run it on an existing PR so the check contexts are created.
2) Once the workflow run is visible on the PR or commit, the check names will be selectable in Settings → Rulesets → DoctorGPhD.
3) If you want to perform the ruleset update programmatically, use the safe read-modify-write pattern below: read the existing ruleset JSON, append the contexts (unique), then PATCH the ruleset back. This ensures we do not accidentally change enforcement settings. Leave the "Require status checks to pass" toggle OFF in the UI (non-blocking) until you are ready to require success-only.

Step A — Create a branch + Draft PR to produce the checks
- Suggested branch: `feature/ruleset-onboard-checks`
- Suggested commit message: `chore(ci): add onboarding status-checks workflow for DoctorGPhD`
- Open a Draft PR targeting `main` (the workflow will run and create the check contexts).

Step B — Confirm check context names (once a run appears)
- Open the PR → Checks tab → expand the workflow run → note the exact names:
  - status: completed
  - status: expected
  - status: pending
  - status: queued
  - status: waiting
  These exact strings are what you will add to the ruleset.
Step C — Programmatic patch (safe read → merge → patch)
Prerequisites
- GitHub CLI (gh) v2+ authenticated as a user with repo admin or ruleset edit permissions.
- One of:
  - Linux/macOS: `jq` and `diff` installed, or
  - Windows (PowerShell): use the PowerShell commands below (no `jq` required), or run the helper script in `scripts/Update-Ruleset-Contexts.ps1`.

Important: In the current Ruleset API schema for this repository, required status checks live inside the `rules` array as a rule of type `required_status_checks` with parameters `{ strict, contexts }`. We must merge contexts into that rule (creating it if missing) without changing other rules or `enforcement`.

Option 1 — Linux/macOS (jq)

```bash
# 1) Identify the ruleset id
OWNER=electricgltd
REPO=P100-Electrical-Agent-Suite
RULESET_NAME="DoctorGPhD"
RULESET_ID=$(gh api repos/$OWNER/$REPO/rulesets --jq ".[] | select(.name==\"$RULESET_NAME\") | .id")
echo "Ruleset ID: $RULESET_ID"

# 2) Fetch current ruleset JSON
gh api repos/$OWNER/$REPO/rulesets/$RULESET_ID > ruleset-current.json

# 3) Merge contexts into the required_status_checks rule (create it if absent)
jq '
  # Ensure a required_status_checks rule exists
  if ([.rules[].type] | index("required_status_checks")) then .
  else .rules += [{"type":"required_status_checks","parameters":{"strict":false,"contexts":[]}}]
  end
  # Merge contexts uniquely into that rule
  | .rules = (.rules | map(
      if .type == "required_status_checks" then
        (.parameters.contexts |= ((. + [
          "status: completed",
          "status: expected",
          "status: pending",
          "status: queued",
          "status: waiting"
        ]) | unique))
      else . end
    ))
' ruleset-current.json > ruleset-updated.json

# 4) Review the patch
echo "----- DIFF -----"
diff -u ruleset-current.json ruleset-updated.json || true
echo "----- END DIFF -----"

# 5) Apply the patch
gh api \
  --method PATCH \
  -H "Content-Type: application/json" \
  repos/$OWNER/$REPO/rulesets/$RULESET_ID \
  --input ruleset-updated.json

# 6) Verify in the UI (see below)
```

Option 2 — Windows (PowerShell)

```pwsh
$Owner = 'electricgltd'
$Repo = 'P100-Electrical-Agent-Suite'
$RulesetName = 'DoctorGPhD'
$Contexts = @('status: completed','status: expected','status: pending','status: queued','status: waiting')

# 1) Identify the ruleset id
$rulesets = (gh api "repos/$Owner/$Repo/rulesets") | ConvertFrom-Json
$ruleset = $rulesets | Where-Object { $_.name -eq $RulesetName }
if (-not $ruleset) { throw "Ruleset '$RulesetName' not found." }
$rulesetId = $ruleset.id
Write-Host "Ruleset ID: $rulesetId"

# 2) Fetch current ruleset JSON
$currentPath = "_temp/ruleset-current.json"
$updatedPath = "_temp/ruleset-updated.json"
New-Item -ItemType Directory -Force -Path (Split-Path $currentPath) | Out-Null
(gh api "repos/$Owner/$Repo/rulesets/$rulesetId") | Out-File -Encoding utf8 $currentPath
$json = Get-Content $currentPath -Raw | ConvertFrom-Json -Depth 100

# 3) Ensure a required_status_checks rule exists and merge contexts uniquely
$rsc = $json.rules | Where-Object { $_.type -eq 'required_status_checks' }
if (-not $rsc) {
  $rsc = [pscustomobject]@{
    type       = 'required_status_checks'
    parameters = [pscustomobject]@{
      strict   = $false
      contexts = @()
    }
  }
  $json.rules += $rsc
}
$merged = @($rsc.parameters.contexts + $Contexts) | Sort-Object -Unique
$rsc.parameters.contexts = $merged

# 4) Save updated JSON and show diff
$json | ConvertTo-Json -Depth 100 | Out-File -Encoding utf8 $updatedPath
Write-Host '----- DIFF (git diff --no-index) -----'
git --no-pager diff --no-index -- $currentPath $updatedPath 2>$null
Write-Host '----- END DIFF -----'

# 5) Apply the patch
gh api --method PATCH -H "Content-Type: application/json" "repos/$Owner/$Repo/rulesets/$rulesetId" --input $updatedPath

# 6) Verify in the UI (see below)
```

Option 3 — Windows PowerShell helper script (checked in)
- Run: `scripts/Update-Ruleset-Contexts.ps1 -Owner electricgltd -Repo P100-Electrical-Agent-Suite -RulesetName DoctorGPhD`
- Optional: pass `-Contexts` to override or extend the defaults.

Step D — Verify in the UI
- Go to Settings → Code and automation → Rulesets → DoctorGPhD → Edit.
- Under "Required status checks", the new contexts should be listed.
- Keep "Require status checks to pass before merging" OFF for onboarding (non-blocking).

When ready to make checks blocking (require success only)
- In the Ruleset UI (recommended), turn ON "Require status checks to pass before merging".
  This enforces that those contexts (when present on a PR) must complete with conclusion == success.

Notes, Risks, & Rollback
- Permissions: the ruleset API requires appropriate permissions (repo admin / ruleset editor). If you get 403, run the commands as a user with the necessary role.
- Non-blocking onboarding: we preserve the current enforcement settings and only add contexts. If you mistakenly enable "require checks to pass" and want to roll back: Settings → Rulesets → DoctorGPhD → Edit → remove the contexts or turn off the "Require status checks to pass before merging" toggle.
- Semantics: the rule system enforces conclusion == success; you cannot make the ruleset treat "queued/pending" as passing.

If you want me to
- Create the branch and open the Draft PR that will trigger the workflow, say "Please open the draft PR" and I will prepare the branch name and PR body (I will not push without your go‑ahead). Otherwise run:

```pwsh
git checkout -b feature/ruleset-onboard-checks
git add .github/workflows/onboard-status-checks.yml .github/README-ruleset-doctorgphd.md
git commit -m "chore(ci): add onboarding status-checks workflow for DoctorGPhD"
git push --set-upstream origin feature/ruleset-onboard-checks
gh pr create --title "chore(ci): onboarding checks for DoctorGPhD" --body "Add noop workflow to emit stable check contexts for DoctorGPhD onboarding. Onboard non-blocking first." --draft
```

DoD / Acceptance mapping
- Creates branch `feature/ruleset-onboard-checks`.
- Adds files under `.github` only (workflow + README).
- Opens Draft PR against `main` with Conventional Commit style commit.
- Leaves enforcement OFF (non-blocking onboarding).

Please open the Draft PR and run the onboarding workflow so the check contexts become selectable in Settings → Rulesets → DoctorGPhD.

Onboarding PR prepared by automation on 2025-09-27.

Patch the ruleset programmatically using the safe read→merge→PATCH process above (requires a user with repo admin/ruleset edit permission). I can run those steps for you if you’d like (I’ll need authenticated gh CLI permissions to call the Rulesets API), or I can provide the exact commands to run locally.
