# Ref_link Review Simplified Workspace Design

## Summary

The current ref_link review modal solves the comparison problem but still behaves like three separate review buckets. That makes the action model noisy: repeated `Select filtered`, `Unselect filtered`, and `Dismiss selected` controls appear in multiple places, and the filter UI is heavier than it needs to be.

This change simplifies the review flow into a single filtered workspace. Users see one result table, one shared bulk-action row, clearer explanatory copy, and an explicit session-only benchmark URL field that controls which live BibBase source is used for scans.

## Goals

- Remove repeated bulk-action buttons from the modal
- Replace the bulky filter blocks with a compact row of native multi-select controls
- Make the benchmark source explicit and editable for the current session only
- Clarify what the modal does and how its actions behave
- Keep the existing scan/apply protections, progress states, overrides, and lazy row details

## Non-goals

- Writing benchmark URL changes back to `metadata/sources/sources.yaml`
- Changing the underlying ref_link matching heuristic
- Reworking apply semantics beyond the existing selected-row model
- Adding persistent user preferences for filters or benchmark selection

## User Experience

### Modal structure

The modal remains the dedicated review workspace, but its content becomes a single table-based workflow instead of three stacked sections.

The top of the modal contains:

- title: `Ref_link review`
- a short explanatory paragraph describing that the window compares stored `ref_link` values against a live BibBase benchmark, and that visible rows are controlled by filters
- scan status and progress
- a benchmark URL panel
- header actions: `Refresh scan`, `Apply selected`, `Close`

### Benchmark panel

The benchmark panel makes the source of truth for the scan explicit.

It contains:

- label: `Live BibBase source used for this scan`
- a text input prefilled with the default benchmark URL from registry config
- a note: `Session only. Changing this here does not update sources.yaml.`

Behavior:

- editing the field does not trigger a scan immediately
- `Refresh scan` uses the current field value
- the benchmark override exists only for the browser session
- page reload resets the field back to the registry default
- invalid benchmark URLs block scan start locally with a clear error

### Filters

The current chip/filter-card layout is replaced with a single compact control row.

Controls:

- `status` native multi-select
- `confidence` native multi-select
- `reason` native multi-select
- `Clear filters`

Filter semantics:

- within each control, any selected value matches
- across controls, filters combine with AND semantics
- if a control has no selected values, it is unrestricted

Status values:

- `Ready to apply`
- `Needs review`
- `Dismissed`

### Results table

The modal shows one result table containing only rows that match the active filters.

Each row still supports:

- clickable current and proposed URLs
- inline proposal override via details expansion
- lazy-loaded details toggle
- session-only dismiss/restore behavior
- session-only column resizing

Each result row carries a UI-visible `status` value derived from its current bucket.

### Bulk actions

There is one shared bulk-action row above the single result table.

Buttons:

- `Select visible`
- `Unselect visible`
- `Dismiss selected`
- `Restore selected` only when dismissed rows are in view

Behavior:

- actions apply only to the rows currently visible after filtering
- no duplicated per-bucket action rows remain in the modal
- `Apply selected` remains in the modal header and uses the current selected rows

### Copy refresh

Add short helper text to make purpose and behavior clearer.

Suggested modal help text:

`Review proposed ref_link values by comparing stored links to a live BibBase benchmark. Filter the observations, inspect details, and apply selected additions or overrides. Bulk actions apply only to the rows currently visible.`

## Data Model And API Changes

### Session-local benchmark override

`/api/ref_link_review_scan` should accept an optional benchmark URL parameter. The backend scan helper should use that value when present instead of reading only `bibbase_profile_source_url` from registry config.

This override is request-scoped and does not mutate registry config.

### Flattened row status

The scan output should expose a row-level `status` field so the client can flatten `ready_to_apply`, `needs_review`, and `dismissed` rows into one rendered table without reconstructing status client-side from bucket origin.

Accepted values:

- `ready_to_apply`
- `needs_review`
- `dismissed`

The backend can continue returning the existing grouped arrays for compatibility, but each proposal row should include its status explicitly.

## Implementation Notes

### Backend

Update `code/tools/sources/ref_link_review.py` to:

- accept an optional benchmark URL override in the scan entry point
- validate that override as an HTTP(S) URL
- include row-level status in proposal payloads

Update `code/tools/sources/ui_local.py` server routes to:

- pass the session benchmark URL from scan requests into the scan helper
- keep existing scan-status polling flow intact

### Frontend

Update `code/tools/sources/ui_local.py` HTML/CSS/JS to:

- replace the three-group render path with one filtered row list
- add a benchmark input and clearer help copy
- replace filter cards with native multi-select controls
- remove repeated per-bucket action blocks
- add one shared `visible rows` action row
- keep existing progress, override, dismiss, restore, and resize behavior

## Testing

### Backend tests

Add coverage for:

- benchmark override accepted for scan requests
- invalid benchmark override rejected safely
- proposal payload includes row-level status

### UI tests

Add or update HTML tests to assert:

- benchmark input hook exists
- status multi-select exists
- explanatory help text exists
- `Select visible` and `Unselect visible` appear
- old repeated group action text is no longer required multiple times

### Verification

Run:

- focused failing tests first for the new scan/session/status behavior
- full `python3 -m unittest discover -s code/tools/sources -p 'test*.py' -v`
- local UI smoke check for benchmark input, refresh scan, and simplified bulk actions

