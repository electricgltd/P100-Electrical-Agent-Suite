# Power Automate Flows Documentation

## GitHub Issues to Microsoft Planner Sync

### Overview

The GitHub-to-Planner sync flow automatically creates Microsoft Planner tasks when GitHub issues are labeled "Ready Now" or when new issues are opened. This maintains a hybrid backlog where GitHub remains the source of truth while providing visibility in Microsoft Planner.

### Flow Configurations

This implementation provides three complementary flows to handle different scenarios:

#### 1. Primary Flow: `github-to-planner-sync.json`
- **Trigger**: GitHub issue labeled with "Ready Now" OR issue opened
- **Purpose**: Create Planner tasks with intelligent handling of updates
- **Features**: Advanced idempotency, conditional updates

#### 2. Simple Flow: `github-to-planner-simple.json`
- **Trigger**: GitHub issue opened (Option A from requirements)
- **Purpose**: Straightforward task creation for all new issues
- **Features**: Basic duplicate prevention, simpler logic

#### 3. Update Flow: `github-to-planner-updates.json`
- **Trigger**: GitHub issue edited, labeled, or milestone changed
- **Purpose**: Update existing Planner tasks when issue changes
- **Features**: Field synchronization, change notifications

#### Key Features

1. **Idempotency**: Prevents duplicate tasks by checking for existing tasks with the same issue URL
2. **Field Mapping**: Maps GitHub issue fields to Planner task properties
3. **Error Handling**: Adds comments to GitHub issues when sync fails
4. **Update Support**: Updates existing tasks when issue properties change

#### Field Mappings

| GitHub Field | Planner Field | Transformation |
|-------------|---------------|----------------|
| Issue Title | Task Title | Direct copy |
| Issue URL + Repository + Labels + Body | Task Notes | Formatted text block with excerpt (max 500 chars) |
| Milestone Due Date | Task Due Date | ISO 8601 format conversion |
| Priority Labels | Task Priority | See priority mapping below |

#### Priority Mapping

| GitHub Label | Planner Priority | Numeric Value | Description |
|-------------|------------------|---------------|-------------|
| Critical | Urgent | 1 | Highest priority |
| Important | Important | 3 | High priority |
| Non-Critical | Low | 9 | Lower priority |
| (default) | Normal | 5 | Standard priority |

#### Parameters Configuration

Before importing the flow, configure these parameters:

```json
{
  "planId": "YOUR_PLANNER_PLAN_ID",
  "bucketId": "YOUR_PLANNER_BUCKET_ID"
}
```

To find your Plan and Bucket IDs:
1. Navigate to [Microsoft Planner](https://tasks.office.com)
2. Open your plan
3. Check the URL: `https://tasks.office.com/{tenant}/Home/PlanViews/{planId}`
4. For Bucket ID, use developer tools to inspect the bucket elements

#### Connection Configuration

The flow requires two API connections:

1. **GitHub Connection**
   - Connector: GitHub
   - Authentication: OAuth or Personal Access Token
   - Permissions: Read issues, Write issue comments

2. **Planner Connection**
   - Connector: Microsoft Planner
   - Authentication: Office 365 credentials
   - Permissions: Read/Write tasks in the specified plan

### Installation Steps

#### Option 1: Complete Setup (Recommended)
Install all three flows for full functionality:

1. **Import the Primary Flow**
   - Open Power Automate
   - Go to "My flows" → "Import"
   - Upload `flows/github-to-planner-sync.json`
   - Name: "GitHub to Planner - Create Tasks"

2. **Import the Update Flow**
   - Upload `flows/github-to-planner-updates.json`
   - Name: "GitHub to Planner - Update Tasks"

#### Option 2: Simple Setup
For basic functionality, import only the simple flow:

1. **Import the Simple Flow**
   - Upload `flows/github-to-planner-simple.json`
   - Name: "GitHub to Planner - Simple Sync"

#### Common Configuration Steps

1. **Configure Connections**
   - Set up GitHub connection with appropriate permissions
   - Set up Planner connection with access to your plan

2. **Set Parameters**
   - Update `planId` with your Planner Plan ID
   - Update `bucketId` with your target bucket ID (not needed for update flow)

3. **Test the Flow**
   - Create a test GitHub issue
   - Add the "Ready Now" label (primary flow) or just open it (simple flow)
   - Verify task creation in Planner

#### Flow Selection Guide

| Use Case | Recommended Flow | Triggers |
|----------|-----------------|----------|
| Label-based sync only | Primary Flow | "Ready Now" label + issue opened |
| All issues auto-sync | Simple Flow | Issue opened |
| Need task updates | Add Update Flow | Issue edited/labeled/milestoned |
| Complete integration | All three flows | Full event coverage |

### Error Handling

When the flow encounters errors:

1. **GitHub Issue Comment**: Automatically adds a comment with error details
2. **Retry Instructions**: Provides clear steps to retry the sync
3. **Error Details**: Includes technical error information for troubleshooting

Example error comment:
```markdown
❌ **Planner Sync Failed**

There was an error syncing this issue to Microsoft Planner:

```
Invalid bucket ID provided
```

**To retry:** Remove and re-add the `Ready Now` label to trigger sync again.

_Please contact your administrator if this issue persists._
```

### Success Confirmation

When a task is successfully created:

```markdown
✅ **Planner Task Created**

This issue has been automatically synced to Microsoft Planner.

**Planner Task ID:** `task-id-here`
**Plan:** plan-id-here
**Bucket:** bucket-id-here

_This task will be updated automatically when the issue title, priority labels, or milestone due date changes._
```

### Task Notes Format

Created Planner tasks include formatted notes with:

```
GitHub Issue: https://github.com/electricgltd/P100-Electrical-Agent-Suite/issues/123

Repository: electricgltd/P100-Electrical-Agent-Suite

Labels: Ready Now, Critical, Agent: DCA

Description:
[First 500 characters of issue body]...
```

### Maintenance and Updates

#### Adding New Priority Labels
To add new priority mappings:
1. Update the `Map_Priority_Label` compose action
2. Modify the expression to include new label conditions
3. Save and test the flow

#### Changing Target Plan/Bucket
1. Update the `planId` and `bucketId` parameters
2. Ensure the connection has access to the new plan
3. Test with a sample issue

### Troubleshooting

#### Common Issues

1. **Tasks Not Created**
   - Verify GitHub webhook is configured
   - Check connection permissions
   - Ensure "Ready Now" label exists

2. **Duplicate Tasks**
   - The flow includes idempotency checks
   - If duplicates occur, check the URL matching logic

3. **Missing Priority**
   - Ensure priority labels match exactly: "Critical", "Important", "Non-Critical"
   - Check for case sensitivity

4. **Date Format Issues**
   - Milestone due dates must be in ISO 8601 format
   - GitHub API provides dates in correct format automatically

#### Flow History
Monitor flow runs in Power Automate:
- Go to "My flows" → "GitHub to Planner Sync"
- Check "Run history" for detailed execution logs
- Review failed runs for troubleshooting

### Future Enhancements

Potential Phase 2 improvements:
- Two-way sync (Planner → GitHub)
- Assignment mapping
- Checklist synchronization
- Status/bucket updates based on GitHub issue state
- Custom field synchronization from GitHub Projects

### Security Considerations

- API connections use OAuth for secure authentication
- No sensitive data is stored in the flow definition
- GitHub webhook URLs are automatically generated and secured
- Planner access is limited to specified plans and buckets

This flow provides a solid foundation for GitHub-Planner integration while maintaining security and reliability standards.