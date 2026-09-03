# Ref Link Review Design

Date: 2026-03-16

## Summary

Add a new Data Sources review workflow in the local source manager that scans the full source registry against live BibBase entry URLs, proposes `ref_link` additions, flags uncertain cases for manual review, and lets users bulk-apply safe proposals with a single explicit confirmation.

This workflow must be independently runnable. Users do not need to save or build first in order to run the scan.

## Context

The current Data Sources UI already supports:

- validating a single entry
- saving a single entry and rebuilding local artifacts
- comparing the local generated `.bib` file to the hosted online `.bib`

That existing online compare is file-level only. It does not review record-level `ref_link` values, does not surface candidate BibBase per-entry URLs, and does not let users apply proposed `ref_link` updates back into `metadata/sources/sources.yaml`.

The new feature adds that missing record-level workflow.

## Goals

- Let users scan the full Data Sources registry for missing or outdated `ref_link` values.
- Make the scan available at any time from the Data Sources UI.
- Keep user validation light by preselecting only high-confidence additions.
- Surface lower-confidence or conflicting cases clearly for manual review.
- Support bulk acceptance of safe proposals.
- Let users remove unwanted proposals from the current session before applying.
- Keep writes explicit and auditable.

## Non-goals

- Do not require users to review every row manually.
- Do not silently overwrite existing nonblank `ref_link` values in bulk.
- Do not modify `link`, `bib.url`, or unrelated metadata as part of this workflow.
- Do not replace the existing file-level online `.bib` compare.
- Do not depend on the currently edited form state.

## Users and Scope

Primary surface:

- `code/tools/sources/ui_local.py`

Canonical data written:

- `metadata/sources/sources.yaml`
- `metadata/sources/change_log.yaml`

Derived artifacts rebuilt after apply:

- `handmade_tables/dictionary.xlsx`
- `documentation/BibTeX files/GCWealthProject_DataSourcesLibrary.bib`
- `documentation/BibTeX files/BothLibraries.bib`

The feature applies to the Data Sources branch only.

## Current State

The Data Sources actions currently include:

1. `Check entry`
2. `Save and build`
3. `Compare` for file-level online `.bib` comparison

The new workflow should not be gated on step 2. It should be available as its own action in the same Actions area.

## Proposed User Workflow

### Entry point

Add a new action in the Data Sources Actions panel:

- `Review ref_link proposals`

This action is always available. It does not require a prior save.

After a successful save, the UI may also call attention to the same action in the status or success area, but that is only a convenience affordance. It is not a prerequisite.

### Scan flow

When the user clicks `Review ref_link proposals`:

1. The UI requests a full-registry scan.
2. The server compares all Data Sources records against live BibBase entry URLs.
3. The UI opens an inline review panel below the Actions area.
4. Results are grouped into:
   - `Ready to apply`
   - `Needs review`
   - `Dismissed`

### Review flow

`Ready to apply`

- Contains high-confidence additions only.
- Rows are preselected by default.
- Intended for fast bulk acceptance.

`Needs review`

- Contains mismatches, ambiguous cases, duplicate BibBase variants, hosted/local drift signals, or lower-confidence fallback matches.
- Rows are never preselected by default.

`Dismissed`

- Contains rows the user removed from the current review session.
- Dismissal is session-local only.

### Bulk actions

Panel-level actions:

- `Apply selected`
- `Select all ready`
- `Clear selection`
- `Dismiss selected`
- `Refresh scan`

### Row-level actions

Each row shows:

- record identifier
- source / citekey
- current `ref_link`
- proposed live BibBase URL
- confidence badge
- reason flag
- selection control
- dismiss control

### Apply flow

When the user clicks `Apply selected`:

1. The UI shows one confirmation dialog summarizing:
   - number of selected rows
   - number of skipped or dismissed rows
   - files that will be modified
2. On confirmation, the server applies only still-valid selected proposals.
3. The server rebuilds derived artifacts.
4. The review panel refreshes with updated counts and remaining issues.

## Matching Strategy

### Primary match path

The scan should match records to BibBase entries by recovered BibTeX key first.

Implementation rule:

1. Fetch the live BibBase rendered payload for the Data Sources library.
2. Recover the original BibTeX key from each entry's embedded `bibtex`, not only from the displayed BibBase key.
3. Match the registry record `citekey` to that recovered key.

This is the safest path and should drive all high-confidence proposals.

### Fallback match path

If no exact citekey match exists, the scan may try a cautious fallback for review-only proposals:

- normalized title exact match
- same year
- some author surname overlap or stable institutional author stem

Fallback matches must never be preselected. They are review-only.

### Ambiguity handling

If fallback matching yields multiple plausible candidates:

- do not pick one automatically
- mark the case as ambiguous
- show it under `Needs review`

If no credible candidate exists:

- show no proposal

## Confidence Model

### High confidence

Requirements:

- exact citekey match
- local `ref_link` is blank
- exactly one normalized live BibBase per-entry URL candidate after deduping

Behavior:

- show in `Ready to apply`
- preselect by default

### Medium confidence

Examples:

- exact citekey match but stored `ref_link` differs from the live BibBase URL
- exact citekey match but BibBase renders duplicate variants for the same underlying key
- exact citekey match but the hosted BibBase library appears stale relative to the local generated `.bib`

Behavior:

- show in `Needs review`
- do not preselect

### Low confidence

Examples:

- no exact citekey match, but a plausible fallback candidate exists by title and year

Behavior:

- show in `Needs review`
- do not preselect
- add a stronger warning label

## Reason Flags

Each proposal should include a reason flag such as:

- `blank ref_link, exact citekey match`
- `stored ref_link differs from live BibBase`
- `duplicate BibBase variants for citekey`
- `hosted BibBase may be stale`
- `title/year fallback only`
- `ambiguous multiple candidates`
- `no candidate found`

These flags are part of the user-facing review UI and part of the scan response payload.

## Apply Semantics

The scan is read-only. No files are modified during scan.

The apply action is the only write step.

### Apply rules

For each selected row:

- resolve the target by canonical record `id`
- revalidate that the proposal is still current
- write only the `ref_link` field

### Overwrite protection

Bulk apply must not overwrite an existing nonblank `ref_link`.

If a selected row now has a nonblank `ref_link`, or if the live candidate changed between scan and apply:

- skip the row
- report it as stale or skipped

Rows with existing-but-different `ref_link` values remain manual-review cases.

## Audit and Logging

Applying selected proposals should:

- append one change-log entry per modified record
- use the current editor name
- use a machine-readable reason such as `Applied ref_link proposal from local UI review`

The response should summarize:

- applied count
- skipped count
- stale count
- failed count
- modified files

## API Design

Keep this workflow separate from normal save behavior.

Add:

- `POST /api/ref_link_review_scan`
- `POST /api/ref_link_review_apply`

### `POST /api/ref_link_review_scan`

Behavior:

- scans the full Data Sources registry
- fetches live BibBase data
- returns grouped proposals and summary counts
- does not write files

Suggested response shape:

- `summary`
- `ready_to_apply`
- `needs_review`
- `dismissed` (client-managed session state may also be acceptable)
- `scan_metadata`

### `POST /api/ref_link_review_apply`

Behavior:

- accepts selected proposal identifiers
- revalidates them
- applies only still-valid updates
- rebuilds artifacts
- returns updated summary plus file modification data

Suggested request inputs:

- editor name
- selected proposal ids
- scan token or proposal fingerprint for stale-detection

## UI Design Notes

- Reuse the existing Actions + Status page structure.
- Do not render this as a large modal. Keep it inline and persistent while reviewing.
- Keep the existing file-level online compare feature unchanged.
- Allow users to run the scan even when the current entry form is dirty, since the workflow is registry-wide and independent from the form.
- After apply, keep the panel open so users can continue reviewing unresolved rows.

## Suggested Data Model for Proposals

Each proposal row should have a stable identifier and enough data to revalidate safely at apply time.

Suggested fields:

- proposal id
- record id
- citekey
- current `ref_link`
- proposed `ref_link`
- confidence
- reason flag
- matching method
- scan fingerprint

## Risks and Mitigations

### Live BibBase drift

Risk:

- the hosted BibBase library may lag behind the local generated `.bib`

Mitigation:

- expose a drift flag in scan results
- downgrade affected rows out of auto-selected high-confidence apply

### Duplicate or suffixed BibBase keys

Risk:

- BibBase may render duplicate display keys with suffixes such as `-1`

Mitigation:

- recover the original BibTeX key from embedded `bibtex`
- dedupe candidates by normalized per-entry URL

### User overload

Risk:

- a full-registry scan may return many rows

Mitigation:

- group rows into confidence buckets
- preselect only safe rows
- support bulk select, clear, dismiss, and filter-by-section behaviors

## Acceptance Criteria

- Users can run `Review ref_link proposals` without saving first.
- The scan covers the full Data Sources registry.
- High-confidence blank `ref_link` fills are preselected.
- Lower-confidence or conflicting cases are visible but not preselected.
- Users can bulk-apply selected proposals with one explicit confirmation.
- Bulk apply never overwrites existing nonblank `ref_link` values.
- Apply writes only `ref_link`, logs changes, and rebuilds artifacts.
- Users can dismiss proposals for the current review session without writing files.

## Open Implementation Questions

- Whether the review panel should default to all buckets expanded or open only `Ready to apply` first.
- Whether section-based filters should be included in the first version or added later if scan results are large.

## Recommendation

Implement the first version with:

- standalone scan action
- inline review panel
- three buckets
- exact-key-based safe preselection
- explicit bulk apply
- session-local dismissal

This is the lowest-friction workflow that still protects users from silent incorrect writes.
