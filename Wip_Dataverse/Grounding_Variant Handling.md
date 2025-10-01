# Variant Handling — Variant Type Master & Variant Rules

Purpose
- Define a maintainable "Variant Type Master" pattern and rule model so the solution can generate and manage product/solution variants (electrical options) consistently.
- Provide clear acceptance criteria, execution semantics and minimal implementable rule schema for Dataverse + Power Automate (and agent logic).

Context / Goals
- One canonical entity ("Variant Type Master") holds variant-type metadata and JSON rule definitions.
- Rules are evaluated at runtime to produce variant records, set fields, and/or link options to the base product.
- Execution is deterministic, testable, and small-scope: manual-first, then automatable.

Acceptance Criteria (AC)
- AC‑1: A Variant Type Master entity schema is specified with fields required to author rules (id, name, base reference, JSON rules, matching mode, active).
- AC‑2: Rule model supports priority, condition, and actions (setFields, createRecords, tags).
- AC‑3: Rules can be evaluated using JSON logic (or Power Automate expressions) and support "first-match" and "all-match" modes.
- AC‑4: Example rules covering typical patterns (single-field match, range, composed conditions) are included for reviewers/testers.
- AC‑5: Implementation notes list where to change agents / flows (DCA / EA) and testing checklist.

Definition of Done (DoD)
- DoD‑1: grounding-files/variant-handling.md added to repo and reviewed.
- DoD‑2: schema_snapshots/variant_type_master.json committed as a dev snapshot matching the spec.
- DoD‑3: PR description references Issue #5 and maps each file to ACs above.
- DoD‑4: No secret values required; no changes outside allowed folders.

Design — high level
- Entity: p100_varianttypemaster (logical name used in snapshots)
  - Fields:
    - p100_varianttypemasterid (GUID)
    - p100_name (string)
    - p100_baseproduct (lookup to product entity)
    - p100_rules (multiline text; JSON array)
    - p100_matchingmode (option set): first-match | all-match
    - p100_isactive (boolean)
    - p100_description (string)
- Rule model (JSON):
  - id (string)
  - name (string)
  - priority (integer) — lower = evaluated earlier
  - condition (JSON Logic object / or plain Power Automate expression string)
  - actions (array): list of actions executed when condition true:
    - setFields: map field logical names -> values (supports tokens from base record)
    - createRecords: list of records to create (entityLogicalName + fieldMap)
    - tags: array of strings (metadata)
  - stopOnMatch (boolean) — optional; helpful in "first-match" scenarios

Execution semantics
- Load Variant Type Master record (active).
- Parse rules array, sort by priority ascending.
- For each rule:
  - Evaluate condition against context (base product + inputs).
  - If true: accumulate actions.
  - If matchingmode == "first-match" OR rule.stopOnMatch == true -> stop further rule processing.
- Apply actions in deterministic order:
  1) setFields on variant record
  2) createRecords
  3) attach metadata/tags
- Persist variant(s) and link to base product.

Condition language recommendation
- JSON Logic (https://jsonlogic.com) is compact and portable (Power Automate has implementations / custom functions).
- Alternatively, Power Automate expressions (less portable) — prefer JSON Logic for cross-agent reuse.

Examples
- Simple equality rule:
  {
    "id":"r1",
    "name":"High power option",
    "priority":100,
    "condition": { "==": [ { "var": "base.powerRating" }, "16A" ] },
    "actions": [{ "createRecords":[ { "entity":"p100_variant", "fields": { "p100_name":"16A variant", "p100_price": 40 } } ] }],
    "stopOnMatch": true
  }

Testing checklist (manual)
- Create a Variant Type Master record with sample rules.
- Create a base product record used for evaluation.
- Trigger a flow/agent to evaluate rules and assert:
  - Expected variant records created
  - Expected fields set
  - No unexpected variants created
- Edge tests: priority ordering, stopOnMatch, multiple matches in all-match mode.

Implementation notes (where to change)
- grounding-files: authors & reviewers update this file as spec evolves.
- schema_snapshots: add entity snapshot for Dataverse solution; pack to solution when accepted (DCA owner).
- flows: Power Automate flow will:
  - Load variant type master
  - Evaluate JSON logic (there are community connectors or use Azure function/inline expression)
  - Create/update records in Dataverse
- agents (EA/DCA): grounding updates so agents can call the flow and pass context (base product, environment).

Risk & rollback
- Risk: Malformed rules JSON could prevent processing. Mitigation: store a single `isActive` toggle and add validation step; evaluate in sandbox/dev first.
- Rollback: disable p100_varianttypemaster records (isActive=false) or remove the flow trigger.

Reference mapping (this file -> ACs)
- grounding-files/variant-handling.md -> AC‑1, AC‑2, AC‑3, AC‑4, AC‑5
