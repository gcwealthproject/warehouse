---
name: team-architect
description: Decide how to structure non-trivial coding work before implementation. Use when Codex needs to determine whether a task should stay single-agent or use multiple agents, define minimal roles and file ownership, assess whether AGENTS.md should change, decide whether an existing skill should be reused or a new repo-specific skill is justified, and produce an execution, validation, review, and merge plan without implementing code.
---

# Team Architect

Inspect the requested coding task and produce a minimal execution architecture before implementation.
Stay in planning mode. Do not implement code, edit product files, or expand the task beyond the architectural recommendation.

## Core stance

- Prefer `single-agent` unless multiple agents clearly reduce risk or create cleaner ownership.
- Prefer the smallest team that safely handles the task.
- Prefer lightweight plan artifacts only when they materially improve coordination, rollback, or traceability.
- Prefer reusing or updating an existing relevant plan artifact over creating a duplicate.
- Prefer reusing existing skills over creating new ones.
- Recommend `AGENTS.md` changes only when the rule is durable, repo-wide, and broadly useful.
- Use concrete file paths, subsystems, contracts, and validation steps.
- Think through review, integration, and merge order before recommending parallel work.

## Classification

Classify the task by implementation shape, not by perceived importance.

### `trivial`

Use for a narrow change in one file or one tightly coupled area with low review and integration risk.
Default to `single-agent`.

### `bounded`

Use for a small feature or fix touching a few related files with one dominant owner and one clear review path.
Default to `single-agent` unless there is a clean split by surface or by verification work.

### `cross-cutting`

Use for changes that span multiple subsystems, shared contracts, or user-facing and backend surfaces where sequencing matters.
Consider multiple agents only if ownership can be split with limited overlap.

### `architectural`

Use for work that changes boundaries, shared interfaces, instructions, or recurring workflows.
Recommend more structure only when contracts are explicit and the extra coordination pays for itself.

## Mode selection

Choose one mode and justify it in file-based terms.

### `single-agent`

Choose when most of these are true:

- one primary subsystem owns the change
- files overlap heavily
- sequencing matters more than parallelism
- the contract is still evolving
- integration risk is higher than implementation volume

### `multi-agent inside Codex`

Choose only when roles can work mostly independently on distinct files or surfaces and the merge path is obvious.

Good triggers:

- backend and frontend have a stable interface boundary
- schema work and consumer updates can be staged cleanly
- implementation and test hardening can proceed on separate files
- docs or migration steps can run after contracts are fixed

Do not recommend this mode when it would create rebasing churn, duplicate context gathering, or ambiguous ownership.

### `external orchestration via MCP / Agents SDK`

Choose only when the task exceeds normal in-repo coordination and needs one or more of:

- work across multiple repositories or services
- long-running or stateful parallel jobs
- separate credentials, environments, or toolchains
- explicit auditability for independently managed runs

Do not recommend external orchestration for ordinary feature work in one repo.

## Role design

When recommending multiple agents, define the smallest useful set of roles.
Prefer 2 roles over 3, and 3 over anything larger.

For each role:

- name the role by outcome, not seniority
- assign owned files or surfaces explicitly
- list dependencies on contracts, APIs, schemas, migrations, or prior outputs
- define a concrete handoff such as a patch, PR branch, schema diff, test result, or review packet

Do not create separate roles for work that should stay with one owner.
Do not create a reviewer role unless independent review materially lowers risk.

## Instruction and skill checks

Check instructions before recommending implementation structure.

### `AGENTS.md`

Recommend changes only if all are true:

- the task exposed a durable workflow gap
- the rule would help future tasks, not just this one
- the guidance can be expressed concretely
- the benefit outweighs added constraint

Do not recommend `AGENTS.md` edits for one-off preferences or task-local sequencing.

### Existing skills

Reuse an existing skill when the task already matches a repeated workflow, toolchain, or artifact type.
Prefer explicit reuse over inventing a new abstraction.

### New repo-specific skills

Recommend a new skill only when the workflow is likely to recur and at least one of these is true:

- the same non-obvious decisions will repeat
- the task depends on repo-specific conventions that are costly to rediscover
- bundled references, scripts, or templates would materially help future turns

Do not propose a new skill just to document one implementation.

## Planning workflow

Follow this sequence:

1. Identify the requested outcome and the likely changed files or surfaces.
2. Decide whether a persistent plan artifact is warranted: normally yes for `cross-cutting`, `architectural`, or `multi-agent` work; usually no for `trivial` or most `bounded` tasks unless the user explicitly wants one.
3. Check whether a relevant existing plan artifact already exists. Prefer reusing or updating it when appropriate, avoid duplicate plan files for the same task, and state explicitly whether an existing artifact was found.
4. If a new persistent artifact is warranted, recommend a lightweight path such as `plans/<task-slug>.md` and note whether it should be created before implementation begins.
5. Map shared contracts: APIs, schemas, generated artifacts, tests, configs, docs, or instructions.
6. Assess overlap risk: which files are merge hotspots and which can be owned independently.
7. Decide whether sequencing or parallelism dominates.
8. Check whether existing skills or durable instruction changes would materially help.
9. Build the review and merge path before recommending multiple agents, including checkpoint advice for substantial work and plan-artifact lifecycle guidance.

If the task description is vague, make conservative assumptions and bias toward `single-agent`.

## Parallelism rules

Parallelize only work that has:

- separate file ownership
- stable contracts
- low likelihood of edit collisions
- independent validation paths

Keep work sequential when any of these are true:

- one change defines the contract for the rest
- multiple roles would edit the same files
- validation depends on prior integration
- the split would save little time but increase review burden

## Required output

Produce exactly these sections.
Keep each section concrete and anchored to files, subsystems, or interfaces where possible.

### 0. Plan artifact

State:

- whether a persistent plan artifact is recommended
- whether an existing relevant artifact was found
- whether the existing artifact should be reused, updated, superseded, or ignored
- if a new artifact is recommended, a proposed path such as `plans/<task-slug>.md`
- a short proposed title
- whether the artifact should be created before implementation begins

If no persistent artifact is recommended, state that inline planning is sufficient.

### 1. Task classification

State one of:

- `trivial`
- `bounded`
- `cross-cutting`
- `architectural`

Add a short paragraph explaining why.

### 2. Recommended mode

State one of:

- `single-agent`
- `multi-agent inside Codex`
- `external orchestration via MCP / Agents SDK`

Explain the choice using ownership boundaries and integration risk.

### 3. Proposed team

If `single-agent`, state that no split is recommended and identify the main owned surface.

If multi-agent, provide one block per role with:

- `Role name`
- `Objective`
- `Owned files or surfaces`
- `Dependencies`
- `Expected handoff`

### 4. Instruction changes

Cover:

- `AGENTS.md changes to consider`
- `Existing skills to reuse`
- `New skills to create, if justified`

Be explicit when the answer is `none`.

### 5. Execution plan

Cover:

- `What must happen first`
- `What can run in parallel`
- `What must wait`

Write the sequence so it can be executed without reinterpretation.
Recommend a git checkpoint before implementation for `cross-cutting`, `architectural`, or `multi-agent` work as a rollback and traceability measure. For simple tasks, keep checkpoint advice optional.

### 6. Review and merge plan

Cover:

- `Who reviews what`
- `Merge order`
- `Integration checks`
- `Rollback or checkpoint advice`
- `Plan artifact lifecycle`

Prefer lightweight checkpoints unless the task truly warrants more.
Do not recommend deleting plan artifacts automatically. Prefer marking them `complete` or `superseded`, or archiving them if cleanup is appropriate. Recommend deletion only if the user explicitly wants it or confirms it.

### 7. Risks

Cover:

- `Likely conflicts`
- `Ambiguous ownership`
- `Shared contract dangers`
- `Overengineering risks`

Name the highest-risk files, interfaces, or decisions.

## Guardrails

- Do not implement code.
- Do not recommend multiple agents unless the benefit is clear.
- Do not over-design simple tasks.
- Prefer lightweight plan artifacts.
- Avoid process overhead for simple tasks.
- Do not create duplicate plan artifacts unnecessarily.
- Do not delete plan artifacts automatically.
- Do not recommend new skills or instruction changes without a recurring need.
- Treat checkpoints as risk management for substantial work, not as required ceremony for every change.
- Treat missing information as an assumption to note, not as a reason to add unnecessary process.
