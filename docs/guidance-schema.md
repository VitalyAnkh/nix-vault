# Guidance Schema

This document defines the canonical high-level structure expected by the repository's `AGENTS.md`
guidance.

## Required Sections

### 1. Role & Intent

- Title and opening paragraphs describing the agent's role in the repository.
- High-level objective and expected collaboration style.

### 2. Operating Principles

- Short, stable principles that guide trade-offs.
- Prefer principles that remain valid across tooling/runtime overlays.

### 3. Execution Protocol

- Delegation rules.
- Model routing or agent-role selection.
- Agent catalog or equivalent capability map.
- Skill/workflow invocation rules.
- Team/pipeline sequencing when applicable.

### 4. Constraints & Safety

- Keyword detection or mode-switch rules.
- Cancellation rules.
- State-management expectations.
- Any repository-specific safety boundaries.

### 5. Verification & Completion

- Evidence standards for declaring success.
- Verification loop guidance.
- Continuation checks before concluding work.

### 6. Recovery & Lifecycle Overlays

- Runtime or team overlays appended by automation must be additive.
- Marker contracts should remain stable so tooling can update bounded sections safely.

## Marker Contracts

When runtime overlays are used, preserve these exact markers:

- `<!-- OMX:RUNTIME:START --> ... <!-- OMX:RUNTIME:END -->`
- `<!-- OMX:TEAM:WORKER:START --> ... <!-- OMX:TEAM:WORKER:END -->`

## Repository Notes

- Keep schema-level guidance generic enough for automation to consume.
- Put repository-specific operational details in `AGENTS.md` sections that map onto the schema
  above.
- If the schema changes, update this file before updating references to it elsewhere.
