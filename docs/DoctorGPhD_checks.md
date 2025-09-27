# DoctorGPhD Ruleset Validation

This document describes the automated validation checks for the DoctorGPhD ruleset in the P100 Electrical Agent Suite.

## Overview

The DoctorGPhD ruleset validation ensures that ruleset files follow the correct schema and structure before being enabled in the system. This provides early feedback and prevents runtime issues.

## Validation Checks

### File Location

The validator looks for the DoctorGPhD ruleset at the following locations (in order of preference):

1. `agents/DCA/rulesets/DoctorGPhD.yml`
2. `agents/DCA/rulesets/DoctorGPhD.yaml`
3. `agents/DCA/rulesets/DoctorGPhD.json`

### Schema Validation

When a ruleset file is found, the validator checks for:

#### Required Top-Level Fields

- **`name`** (string): Name of the ruleset, must be non-empty
- **`version`** (string): Semantic version following semver format (e.g., "1.0.0", "2.1.3-beta")
- **`rules`** (array): List of rule definitions

#### Rule Structure

Each rule in the `rules` array must contain:

- **`id`** (string): Unique identifier for the rule, must be non-empty
- **`condition`** (string): Rule condition logic, must be non-empty  
- **`action`** (string): Action to take when rule matches, must be non-empty

### Example Valid Ruleset

```yaml
name: "DoctorGPhD Electrical Rules"
version: "1.0.0"
rules:
  - id: "emergency-lighting-check"
    condition: "system.type == 'emergency_lighting'"
    action: "validate_emergency_requirements"
  - id: "eicr-compliance"
    condition: "inspection.type == 'EICR'"
    action: "check_compliance_standards"
```

## Current State

Currently, no DoctorGPhD ruleset file exists in the repository. This is expected and the validation will:

- ✅ Pass CI checks (exit code 1 indicates "not found" which is acceptable)
- 📝 Display clear message about expected file locations
- 🔧 Provide guidance on how to enable the ruleset

## How to Enable the Ruleset

To enable DoctorGPhD ruleset validation:

1. Create the directory structure:
   ```bash
   mkdir -p agents/DCA/rulesets
   ```

2. Create the ruleset file at `agents/DCA/rulesets/DoctorGPhD.yml` with valid content following the schema above

3. Commit and push the changes - CI will automatically validate the new ruleset

## CI Integration

The validation runs automatically on:
- All pull requests
- Pushes to the main branch

### Exit Codes

- **0**: Ruleset found and valid
- **1**: Ruleset not found (expected when disabled - CI passes)
- **2**: Invalid YAML/JSON format (CI fails)
- **3**: Schema validation failed (CI fails)

## Troubleshooting

### Invalid Format Errors

If you see YAML/JSON parsing errors, check:
- File encoding (should be UTF-8)
- YAML indentation (use spaces, not tabs)
- JSON syntax (proper quotes, brackets, commas)

### Schema Validation Errors

Common issues:
- Missing required fields (`name`, `version`, `rules`)
- Invalid version format (must follow semver: `major.minor.patch`)
- Empty or non-string field values
- Rules missing required fields (`id`, `condition`, `action`)

### Getting Help

- Check the validation output for specific line numbers and error details
- Refer to the example ruleset structure above
- Review existing YAML files in the repository for formatting reference