# Summary
- What changed (one slice), why now.
- Map changes to **Acceptance Criteria** (AC-1, AC-2, ...).

# Acceptance Criteria Mapping
- AC-1: …
- AC-2: …

# Definition of Done (DoD)
- Behavior verified (notes/screenshots/terminal output).
- Docs updated if behavior changed.

# Risks / Rollback
- Smallest rollback step: git revert <sha> or remove file X.
- Config/secret names referenced: (e.g., PAC_ENV_URL, PAC_TENANT_ID) — **no values**.

# Checks
- [ ] Conventional Commits used
- [ ] Touched only allowed folders for this slice
- [ ] CI green (or triaged with tiniest safe fix)

Closes #<issue-number-if-applicable>
