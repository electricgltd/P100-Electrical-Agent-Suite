P100 Electrical Agent Suite – Project Setup & ALM Guide
This guide standardises how we plan work (GitHub Projects), label issues (Agent/Area), and move our Dataverse solution through environments via GitHub Actions.

Single source of truth: GitHub Issues + Project
Documents/binaries: OneDrive (link from Issues/README)
Dataverse solution owner: DCA (Design & Costing Agent)
Solution folder: /solutions/DesignAndCosting (unpacked)


1) Planning Fields (Project #2)
Add these Project fields (single source for dates/effort/priority):

Priority (Single select): Critical, important, non-critical
Target date (Date)
Estimate (h) (Number)
Actual (h) (Number)


🎯 Priority order: Critical → important → non-critical
👤 No Assignee needed (solo workflow).


2) Views (Board / Table / Roadmap)
Use the matrix below to configure your Project views. (Board doesn’t support filters; use Table for filtered lists.)

## 2) Views (Board / Table / Roadmap)

Use the matrix below to configure your GitHub Project views.

| 📌 View              | Fields (columns to show)                                               | Grouped by | Sort by                | Field Sum                           | Slice by |
| ------------------- | ---------------------------------------------------------------------- | ---------- | ---------------------- | ----------------------------------- | -------- |
| **Board**           | Title, Status, Priority, Target date, Estimate (h), Actual (h), Labels | Status     | Target date ↑          | Estimate (h), Actual (h) per column | N/A      |
| **Table – Backlog** | Title, Status, Priority, Target date, Estimate (h), Actual (h), Labels | Priority   | Target date ↑, Title ↑ | Estimate (h), Actual (h) per group  | N/A      |
| **Roadmap**         | Title, Status, Priority, Target date, Labels                           | Priority   | Target date ↑          | N/A                                 | N/A      |

How to apply (click-paths)
Board

Project → Views → select Board (or + New view → Board).
Group by = Status.
Fields = tick all listed above.
Priority order: Fields → Priority → Reorder options → Critical, important, non-critical.
Sort = Target date (ascending).
Column ⋯ → Show sum → enable Estimate (h) and Actual (h) for each Status column you want totals on.

Table – Backlog

+ New view → Table → name Backlog.
Fields as above.
Group by = Priority.
Sort = Target date (asc), then Title (asc).
Filter (optional) = Status != Done.
Footer ⋯ → Show sum → enable Estimate (h) and Actual (h).

Roadmap

+ New view → Roadmap → name Roadmap.
Date field = Target date (top‑right of timeline).
Group by = Priority.
Sort = Target date (ascending).

3) Labelling Rules (Agent & Area)
Apply exactly one Agent label and one or more Area labels to every Issue.
Agent (who owns it)

agent:EA – Electrical Agent (parent)
agent:PA – Planning Agent
agent:DCA – Design & Costing Agent (owns Dataverse solution)

✅ Rule: Pick one Agent label per Issue.

Area (what it relates to)

area:Power Automate – Associated with Power Automate Flows
area:Cross Agent Orchestration – Cross Agent Orchestration and Structure
area:Grounding File – Associated with the grounding files
area:Dataverse – Power Platform: Dataverse
area:Emergency Lighting – Emergency Lighting Systems
area:Testing – Testing
area:Fault Finding – Fault Finding
area:Car Charger – Car Charging
area:Install – Installations
area:EICR – Electrical Installation Condition Report

✅ Rule: Apply one or more Area labels.
🚫 Do not duplicate Priority as labels—use the Priority field for planning/sorting.

Examples
| Issue Title                            | Agent Label | Area Labels                                              |
| -------------------------------------- | ----------- | -------------------------------------------------------- |
| Create ALM pipeline for Dataverse      | `agent:DCA` | `area:Power Automate`, `area:Dataverse`                  |
| Update grounding file for EA           | `agent:EA`  | `area:Grounding File`                                    |
| Plan EICR testing schedule             | `agent:PA`  | `area:EICR`, `area:Testing`                              |
| Fault finding on car charger install   | `agent:EA`  | `area:Fault Finding`, `area:Car Charger`, `area:Install` |
| Structure orchestration between agents | `agent:PA`  | `area:Cross Agent Orchestration`                         |

4) Charts (optional but useful)
Create a couple of Charts in the Project to get fast insights:

Items by Priority → Measure: Item count → Slice by: Priority
Effort by Priority → Measure: Estimate (h) → Slice by: Priority
Estimate vs Actual → Type: Stacked bar → Measures: Estimate (h) + Actual (h) → Slice by: Priority

For Agent/Area analysis, use Slice by = Labels and select agent:* or the relevant area:*.

5) ALM (Dataverse) via GitHub Actions
We keep the unpacked solution under /solutions/DesignAndCosting.
Workflows use GitHub Secrets (no secrets in repo).
Secrets to add (Repo → Settings → Secrets and variables → Actions → New repository secret)

Use the canonical names below. Keep values secret — do not store them in the repo.

- PP_TENANT_ID — Azure AD tenant id (GUID)
- PP_APP_ID — Azure AD application (service principal) id
- PP_CLIENT_SECRET — Client secret for the Azure AD app
- PP_DEV_URL — Dev environment URL (e.g. https://orgabc.crm11.dynamics.com)
- PP_TEST_URL — Test environment URL (optional for single‑env projects)
- PP_ENVIRONMENT — (optional) set to `Dev` or `Test` to control which URL is used by workflows

 

ℹ️ SOLUTION_NAME below is set to DesignAndCosting to match your folder. This must be your solution’s unique name (not display name).

Workflow A – Sync Dev to Git (Export + Unpack)
Save as: .github/workflows/alm-sync-dev.yml

name: ALM • Sync Dev → Git (export & unpack)

on:
  workflow_dispatch:
  push:
    branches: [ "main" ]   # or "dev" if you prefer a dev branch

env:
  SOLUTION_NAME: DesignAndCosting

jobs:
  export_and_unpack:
    runs-on: windows-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Export solution (unmanaged) from Dev
        uses: microsoft/powerplatform-actions/export-solution@v1
        with:
          environment-url: ${{ secrets.PPAC_DEV_URL }}
          app-id: ${{ secrets.PPAC_CLIENT_ID }}
          client-secret: ${{ secrets.PPAC_CLIENT_SECRET }}
          tenant-id: ${{ secrets.PPAC_TENANT_ID }}
          solution-name: ${{ env.SOLUTION_NAME }}
          solution-output-file: out/${{ env.SOLUTION_NAME }}.zip
          managed: false

      - name: Unpack solution to /solutions/DesignAndCosting
        uses: microsoft/powerplatform-actions/unpack-solution@v1
        with:
          solution-file: out/${{ env.SOLUTION_NAME }}.zip
          solution-folder: solutions/${{ env.SOLUTION_NAME }}
          solution-type: Unmanaged
          overwrite-files: true

      - name: Commit unpacked changes
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
          git add solutions/${{ env.SOLUTION_NAME }}
          git diff --cached --quiet || git commit -m "chore(alm): unpack ${{ env.SOLUTION_NAME }} from Dev"
          git push


Workflow B – Release to Test (Pack Managed + Import)
Save as: .github/workflows/alm-release-test.yml

name: ALM • Release → Test (pack managed & import)

on:
  workflow_dispatch:
  push:
    tags:
      - "release-*"

env:
  SOLUTION_NAME: DesignAndCosting

jobs:
  pack_and_import_test:
    runs-on: windows-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Pack managed solution from /solutions/DesignAndCosting
        uses: microsoft/powerplatform-actions/pack-solution@v1
        with:
          solution-folder: solutions/${{ env.SOLUTION_NAME }}
          solution-file: out/${{ env.SOLUTION_NAME }}_managed.zip
          solution-type: Managed

      - name: Import managed solution to Test
        uses: microsoft/powerplatform-actions/import-solution@v1
        with:
          environment-url: ${{ secrets.PPAC_TEST_URL }}
          app-id: ${{ secrets.PPAC_CLIENT_ID }}
          client-secret: ${{ secrets.PPAC_CLIENT_SECRET }}
          tenant-id: ${{ secrets.PPAC_TENANT_ID }}
          solution-input-file: out/${{ env.SOLUTION_NAME }}_managed.zip
          publish-changes: true
          skip-dependency-check: false
          overwrite-unmanaged-customizations: false

📝 Notes

Dev → Git workflow keeps /solutions/DesignAndCosting in sync.
Release → Test builds a Managed package and imports it.
Add a similar job for Prod later by duplicating the Test job and swapping PPAC_TEST_URL for PPAC_PROD_URL.

 

6) Architecture (Mermaid)
```mermaid
flowchart TB
  GH_Issues[GitHub Issues]
  GH_Project[GitHub Project #2]
  Repo[Repo: P100‑Electrical‑Agent‑Suite]
  GH_Actions[GitHub Actions]
  OD_Docs[OneDrive: Grounding files]
  Solution[Solution: DesignAndCosting (/solutions)]
  Dataverse[(Dataverse)]
  Flows[Power Automate Flows]
  EA[EA: Electrical Agent]
  PA[PA: Planning Agent]
  DCA[DCA: Design & Costing Agent]

  GH_Issues --> GH_Project
  Repo --- GH_Project
  OD_Docs -. links -. GH_Issues

  Repo -->|/solutions/DesignAndCosting| Solution
  Solution --> Dataverse
  Solution --> Flows

  Repo --> GH_Actions --> Solution

  EA --> PA
  EA --> DCA
  DCA --> Solution
  PA --> GH_Project
```

7) One Copy‑Paste Block (PowerShell)
Use this once to verify fields, link Project, and seed your labels (idempotent: safe to re-run).

If you’re already logged in with gh, you can skip gh auth login and keep gh auth refresh.

# --- Auth & Project link ---
gh auth login
gh auth refresh -s project

# Open Project #2 (sanity check)
gh project view 2 --owner electricgltd --web

# Link repo to Project #2 (safe if already linked)
gh project link 2 --owner electricgltd --repo electricgltd/P100-Electrical-Agent-Suite

# Ensure planning fields exist (ignore "already exists" messages)
gh project field-create 2 --owner electricgltd --name "Target date"  --data-type DATE           2>$null
gh project field-create 2 --owner electricgltd --name "Estimate (h)" --data-type NUMBER         2>$null
gh project field-create 2 --owner electricgltd --name "Actual (h)"   --data-type NUMBER         2>$null
gh project field-create 2 --owner electricgltd --name "Priority"     --data-type SINGLE_SELECT --options "Critical,important,non-critical" 2>$null

# --- Labels (exact names; safe to re-run) ---
# Agent
gh api repos/electricgltd/P100-Electrical-Agent-Suite/labels -f name='agent:EA' -f color='1f77b4' -f description='Electrical Agent (EA)' || true
gh api repos/electricgltd/P100-Electrical-Agent-Suite/labels -f name='agent:PA' -f color='2ca02c' -f description='Planning Agent (PA)'   || true
gh api repos/electricgltd/P100-Electrical-Agent-Suite/labels -f name='agent:DCA' -f color='ff7f0e' -f description='Design & Costing Agent (DCA)' || true

# Area
gh api repos/electricgltd/P100-Electrical-Agent-Suite/labels -f name='area:Power Automate'            -f color='17becf' -f description='Associated with Power Automate Flows' || true
gh api repos/electricgltd/P100-Electrical-Agent-Suite/labels -f name='area:Cross Agent Orchestration' -f color='9467bd' -f description='Cross Agent Orchestration and Structure' || true
gh api repos/electricgltd/P100-Electrical-Agent-Suite/labels -f name='area:Grounding File'            -f color='7f7f7f' -f description='Associated with the grounding files' || true
gh api repos/electricgltd/P100-Electrical-Agent-Suite/labels -f name='area:Dataverse'                 -f color='1f9c9c' -f description='Power Platform: Dataverse' || true
gh api repos/electricgltd/P100-Electrical-Agent-Suite/labels -f name='area:Emergency Lighting'        -f color='e377c2' -f description='Emergency Lighting Systems' || true
gh api repos/electricgltd/P100-Electrical-Agent-Suite/labels -f name='area:Testing'                   -f color='bcbd22' -f description='Testing' || true
gh api repos/electricgltd/P100-Electrical-Agent-Suite/labels -f name='area:Fault Finding'             -f color='8c564b' -f description='Fault Finding' || true
gh api repos/electricgltd/P100-Electrical-Agent-Suite/labels -f name='area:Car Charger'               -f color='aec7e8' -f description='Car Charging' || true
gh api repos/electricgltd/P100-Electrical-Agent-Suite/labels -f name='area:Install'                   -f color='c49c94' -f description='Installations' || true
gh api repos/electricgltd/P100-Electrical-Agent-Suite/labels -f name='area:EICR'                      -f color='d62728' -f description='Electrical Installation Condition Report' || true

# Final open
gh project view 2 --owner electricgltd --web

8) Workflow Checklists
Workflows (Project → ⋯ → Workflows)

✅ Auto‑add items from electricgltd/P100-Electrical-Agent-Suite
✅ When Issue closes → Status = Done
✅ Auto‑archive Done after N days

Saved Views

✅ Board (group by Status)
✅ Backlog (Table; group by Priority; filter Status != Done)
✅ Roadmap (Target date; group by Priority)

9) Conventions

Keep Issues short and actionable; use checklists for sub‑steps.
Put doc links (OneDrive) and acceptance notes in the Issue body.
Keep time data in fields (Target date, Estimate/Actual)—not in titles.