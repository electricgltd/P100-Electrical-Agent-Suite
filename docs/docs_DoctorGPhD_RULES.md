```markdown
# DoctorGPhD ruleset — guide & minimal schema

Purpose:
- DoctorGPhD is a ruleset name (not enabled by default). This document describes
  the minimal file layout and validations applied by the CI check.

Location:
- Place rule files under: agents/<agent>/rules/DoctorGPhD/
  Example: agents/DCA/rules/DoctorGPhD/my_rules.yml

Supported file types:
- YAML (.yml/.yaml) — single or multi-document
- JSON (.json)

Minimal rule shape (examples):

Single-rule YAML (document):
---
id: check_conn_01
name: Ensure connection type is valid
conditions:
  - field: connectionType
    in: [singlePhase, threePhase]
actions:
  - set: severity: warning

List of rules:
- id: rule_1
  name: First rule
  conditions:
    ...
  actions:
    ...

Map-of-rules (id => rule):
rule_1:
  name: First rule
  conditions: ...
  actions: ...

CI validation (what the workflow checks):
- Syntax parse (YAML/JSON). Parse errors fail the job.
- Minimal semantic checks:
  - Each rule must have 'id' (A-Za-z0-9_-), 'name' (non-empty), 'conditions' and 'actions' (list or mapping).
  - Rule ids must be unique across files in the DoctorGPhD folder.

How to run locally:
- Python 3.8+ and pyyaml installed.
- From repo root:
  python scripts/validate_doctorgphd.py

Notes:
- The validator is intentionally simple. If you want a stricter JSON Schema or
  additional domain checks (type checking for condition predicates, allowed actions),
  tell me which fields/structures you require and I will extend the validator.
```