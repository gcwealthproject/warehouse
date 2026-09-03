# Ref_link Review Progress/Override Upgrade Design

## Goal

Extend the ref_link review modal so users can:

- resize cramped columns during the current modal session
- override a proposed `ref_link` inline before applying it
- expand an observation on demand to verify identity details
- see meaningful scan/refresh progress while review data is loading

## Approved Interaction Design

- Keep the existing review modal and add session-only draggable column widths.
- Keep `current ref_link` and `proposed ref_link` clickable.
- Allow inline override of the proposed URL inside the modal; `Apply selected` should write the edited value when present.
- Keep extra identity information hidden by default and reveal it only when the user expands an observation.
- Use real scan progress:
  - stage message while fetching live BibBase
  - progress bar and checked/total counts during registry comparison
- `Refresh scan` clears selections, dismissals, overrides, filters, and expanded-detail state before rebuilding from the new scan.

## Backend Shape

- Extend `ref_link_review.py` to support scan progress callbacks and richer row payloads.
- Add lightweight in-process scan jobs to the local UI server:
  - `POST /api/ref_link_review_scan` starts a scan and returns a `scan_id`
  - `GET /api/ref_link_review_scan_status?scan_id=...` returns stage/progress/final results
- Extend `/api/ref_link_review_apply` to accept an `overrides` map keyed by `proposal_id`.
- Row payload should include:
  - `title`
  - `author`
  - `year`
  - `legend`
  - existing URL/confidence/reason fields

## UI Shape

- Add a modal scan-status block with stage text, progress bar, checked count, total count, and completion/failure message.
- Add drag handles on the key column headers so the user can resize widths for the current session only.
- Add a `Show details` toggle per row and render the extra identity information only when opened.
- Add an editable proposed-link input tied to override state.

## Verification

- Add failing backend tests first for progress reporting, richer row payloads, and override application.
- Add failing HTML tests for progress hooks, details hooks, override hooks, and column-resize hooks.
- Re-run the full `code/tools/sources` unittest suite after implementation.
- Do a live local UI smoke check that scan starts, progress updates, and the modal still loads.
