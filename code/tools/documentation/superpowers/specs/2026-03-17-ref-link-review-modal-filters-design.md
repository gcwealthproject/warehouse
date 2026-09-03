# Ref_link Review Modal/Filter Upgrade Design

## Goal

Upgrade the Data Sources `Review ref_link proposals` experience so users can browse and act on proposals in a large modal workspace instead of the current cramped inline panel.

## Approved Interaction Changes

- Replace the inline review panel with a modal/overlay that takes most of the viewport.
- Keep the review flow independent from save/build.
- Make both `current ref_link` and `proposed ref_link` clickable, opening in a new tab.
- Add global multi-select filters for `confidence` and `reason`.
- Use OR semantics within each filter and AND semantics across filter types.
- Scope `Select all` / `Unselect all` behavior to the currently filtered rows only.
- Keep row selection by `proposal_id` so selection survives filtering.
- Keep dismissed proposals session-local only.
- Add a way to restore dismissed rows without rescanning.

## UI Shape

The modal should include:

- a sticky header with summary counts, stale-hosted warning, refresh/apply/close actions
- a sticky filter bar with confidence and reason controls plus `Clear filters`
- three bucket sections: `Ready to apply`, `Needs review`, `Dismissed`
- per-bucket actions such as `Select filtered`, `Unselect filtered`, and `Dismiss selected`
- `Restore selected` in the dismissed bucket
- wide, horizontally scrollable tables with truncated clickable URLs and full hover titles

## Implementation Boundaries

- Keep this change inside `code/tools/sources/ui_local.py`
- Extend `code/tools/sources/test_ui_local_html.py` with HTML/script presence regression tests
- Reuse the existing `ref_link_review_scan` and `ref_link_review_apply` endpoints
- Do not change the backend proposal format unless implementation proves it is strictly necessary

## Verification

- Add failing UI HTML tests first for modal hooks, filtering controls, and clickable link rendering markers
- Re-run the full `code/tools/sources` unittest suite after implementation
- Confirm the rendered page still parses and loads the review workflow cleanly
