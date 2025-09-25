# Power Automate Flows

This directory contains Power Automate flow definitions for the P100 Electrical Agent Suite project.

## GitHub to Microsoft Planner Integration

### Flow Files

| File | Purpose | Trigger |
|------|---------|---------|
| `github-to-planner-sync.json` | **Primary Flow** - Creates Planner tasks when issues are labeled "Ready Now" | Issue labeled + Issue opened |
| `github-to-planner-simple.json` | **Simple Flow** - Creates Planner tasks for all new issues | Issue opened |
| `github-to-planner-updates.json` | **Update Flow** - Updates existing Planner tasks when issues change | Issue edited/labeled/milestoned |

### Quick Start

1. **Choose your approach:**
   - **Label-based** (recommended): Import `github-to-planner-sync.json`
   - **All issues**: Import `github-to-planner-simple.json`
   - **With updates**: Import both sync + `github-to-planner-updates.json`

2. **Configure parameters:**
   ```json
   {
     "planId": "YOUR_PLANNER_PLAN_ID",
     "bucketId": "YOUR_PLANNER_BUCKET_ID"
   }
   ```

3. **Set up connections:**
   - GitHub (OAuth or PAT)
   - Microsoft Planner (Office 365)

### Features

✅ **Idempotency** - No duplicate tasks created  
✅ **Error Handling** - GitHub comments on failures  
✅ **Priority Mapping** - Critical/Important/Non-Critical → Planner priorities  
✅ **Due Date Sync** - From GitHub milestones  
✅ **Rich Task Notes** - Issue URL, labels, description excerpt  
✅ **Update Support** - Title, priority, and due date changes  

### Field Mappings

| GitHub | Planner | Notes |
|--------|---------|--------|
| Issue Title | Task Title | Direct copy |
| Critical/Important/Non-Critical labels | Urgent/Important/Low priority | Mapped values |
| Milestone due date | Task due date | ISO 8601 format |
| Issue URL + body + labels | Task notes | Formatted with 500-char excerpt |

### Documentation

See `/docs/power-automate-flows.md` for comprehensive setup instructions, troubleshooting, and configuration details.

### Legacy Flows

- `GPT5_to_Loop_Flow.json` - Example flow for Copilot Notebook to Loop integration

---

🔗 **Links:**
- [Microsoft Planner](https://tasks.office.com)
- [Power Automate](https://flow.microsoft.com)
- [GitHub API Documentation](https://docs.github.com/en/rest)