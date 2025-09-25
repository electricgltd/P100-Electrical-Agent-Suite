# MCP Server Security Plan (MVP)

Status: DRAFT

This document describes a minimal security plan for an MCP (Model Context Protocol) server used to provide controlled repository context, semantic search, and safe automation endpoints for developer tools and LLM agents.

## Purpose and scope
- Provide a read-only file and semantic search API for LLM agents and automation.
- Offer a small set of gated write actions (for example: label seeding, PR proposals) that require explicit approval.
- Keep sensitive secrets out of the MCP surface; prefer actions that return diffs/PRs rather than performing destructive changes.

This plan covers authentication, authorization, network, auditing, secrets, and operational recommendations for a production-ready MVP.

## Threat model (high level)
- Unauthorized access to repository contents or actions.
- Leakage of secrets used by the server (API keys, tokens, embedding keys).
- Malicious or buggy agent behavior initiating unwanted changes.
- Data exfiltration via semantic search or file endpoints.

Assumptions: the server runs in an environment you control (company VM or cloud account) and you can enforce network and identity controls.

## Authentication and identity
- Use a GitHub App for repository access instead of a personal access token (PAT) where possible. GitHub Apps support fine-grained permissions and install-level consent.
- If using tokens, prefer short-lived OAuth tokens (no long-lived PATs stored on the server). Rotate keys regularly.
- For human approval flows require interactive OAuth (a human must authenticate via browser) — do not allow unattended approval without a second factor.

Recommended scopes (principle: least privilege):
- Read-only file & metadata access: `contents:read` (or GitHub App equivalents).
- Create PRs: `pull_requests:write` only for the service principal if you need to create PRs.
- Labels: `issues:write` or equivalent (limit to specific repos).

## Authorization model
- Default to read-only endpoints. Write actions must require one of:
  - a) an explicit short-lived approval token issued by a human after reviewing the proposed change, or
  - b) GitHub checks/PR workflow that requires a human merge.
- Implement RBAC inside the MCP: different API keys or JWT claims for 'agent' clients vs 'human' clients. Agents get read-only.

## Network and deployment
- Run the MCP inside a private network or VPC if possible. Expose the service via a reverse proxy (NGINX) or API gateway.
- Use TLS everywhere (Let's Encrypt or managed certs); enforce TLS 1.2+.
- IP allow-listing for admin/human endpoints (optional, if feasible).

## Secrets management
- Do not store clear-text API keys in repo.
- Use a secrets manager: Azure Key Vault, AWS Secrets Manager, or HashiCorp Vault for production.
- Limit secrets to minimum scope and rotate on a schedule.

## Auditing and logging
- Log every request (authenticated principal, endpoint, params, timestamp) to an append-only log.
- Keep request/response bodies for a short retention period only, and scrub secrets from logs.
- Centralize logs (ELK, Splunk, or cloud logging) and enable alerts for suspicious patterns (e.g., large exports, repeated failed auth).

## Semantic data and privacy
- Optionally redact secrets and credentials from indexed files. The indexer should skip directories like `.azure`, `.aws`, `env`, or any `*.key`, `*.pem`, `.secret` files.
- Provide a denylist config that the indexer reads before ingestion.

## Safe action patterns
- For label seeding or repo changes, prefer these flows:
  1. Agent requests a proposed change (POST /actions/propose) with a labels YAML or patch file.
  2. Server returns a diff and opens a draft PR (or stores the diff) but does not apply changes.
  3. A human reviews and approves via a UI or issues comment; approval issues a short-lived apply token.
  4. Server then applies changes (only with approval token) and records audit entry.

## CI integration
- Re-index on push (GitHub Action triggers a webhook to MCP) but run embedding generation in a controlled environment (CI runner) to avoid exposing keys.
- Store embeddings as encrypted artifacts or in a privately hosted vector DB.

## Backup and recovery
- Periodically snapshot the index and metadata.
- Maintain infrastructure-as-code (Terraform/ARM/Bicep) for quick rebuilds.

## Minimal runtime checklist (pre-deploy)
1. Use a GitHub App or short-lived OAuth; do not use long-lived PAT in code.
2. Ensure TLS is enforced and a valid certificate is in place.
3. Confirm indexer denylist for files/directories.
4. Enable request logging and retention policy.
5. Operational alerting: high error rate, high export volume, or unauthorized attempts.

## Example API surface (MVP)
- GET /file?path=path/to/file — returns file content (read-only)
- POST /semantic_search — returns top N chunks with source refs
- POST /actions/propose — submit a YAML or patch to be reviewed
- POST /actions/apply — apply a previously-approved action (requires approval token)

## Runbook: approve-and-apply label rollout
1. Agent posts labels YAML to `/actions/propose`.
2. Server validates YAML, runs dry-run checks, and returns a patch + opens a draft PR on the repo.
3. Reviewer visits the draft PR, inspects changes, and comments `/approve` in the PR to authorize.
4. A separate process exchanges that PR comment for an apply token and calls `/actions/apply` to perform the change.

## Next steps
- I can scaffold a README and example FastAPI skeleton in this repo (dev-mode) that implements the read-only file endpoints and a propose workflow. This will be gated by a simple token in dev, and we will document how to exchange this for a GitHub App in production.

---
_Draft created automatically for your review. Update scopes and deployment details to match your infra policies before production._
