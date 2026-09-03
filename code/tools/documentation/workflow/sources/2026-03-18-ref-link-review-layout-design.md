# Ref_link Review Layout Design

Date: 2026-03-18
Area: `code/tools/sources/ui_local.py`
Scope: source-registry local UI only

## Goal

Reduce unnecessary vertical space in the `ref_link` review window and make the review table the primary surface.

The current review window works functionally, but the sticky top area consumes too much height through stacked explanatory text, the benchmark block, and three tall filter boxes. The redesign should simplify the UI, remove visual bulk, and preserve the existing review workflow.

## Chosen Direction

Adopt the table-first layout with a pinned right-side tray on wide screens.

This corresponds to the approved "option 3" direction:

- compact top bar
- main review table as the dominant visual area
- pinned right-side tray on wide screens
- draggable divider so the user can resize the tray width
- tray sections grouped into compact collapsible blocks

## Goals

- reclaim vertical space above the review table
- keep key review status visible without opening secondary panels
- move secondary controls out of the top area
- simplify explanations and reduce decorative UI treatment
- preserve current workflows and existing backend behavior

## Non-Goals

- no change to scan logic
- no change to filter semantics
- no change to selection, dismiss, restore, override, or apply semantics
- no change to API endpoints or data model
- no broader redesign outside the `ref_link` review window

## Layout

The modal is reorganized into two main regions:

1. A shallow sticky top bar
2. A table-first body with a right-side tools tray

### Top Bar

The top bar remains sticky and always visible, but is compressed into a single shallow row.

It keeps only:

- window title
- `Ready / Review / Dismissed` counts
- scan state
- `Refresh scan`
- `Apply selected`

It removes from the top area:

- long instructional text
- benchmark editing controls
- bulk row actions
- the three filter boxes

Explanatory copy should be replaced by a small info affordance, such as an `i` icon with tooltip or hover text.

### Main Body

The review table becomes the dominant surface. The table should appear immediately below the top bar with minimal framing.

The right-side tray holds secondary controls and is visually subordinate to the table.

### Right-Side Tray

On wide screens, the tray is pinned open by default.

The tray contains four sections:

- `Filters`
- `Benchmark`
- `Bulk actions`
- `Help`

The tray is resizable by dragging the divider between the table and the tray.

Width rules:

- enforce a minimum width so controls remain usable
- enforce a maximum width so the table remains useful
- persist tray width in local storage
- restore stored width on desktop layouts when it still fits

## Tray Behavior

Tray sections are compact and collapsible.

Recommended default behavior:

- `Filters` is expanded the first time the modal opens
- only one tray section is expanded at a time by default
- clicking a section header expands it and collapses the previously open section

Section headers should show concise status text, for example:

- `Filters (3 active)`
- `Benchmark (custom)`
- `Bulk actions`
- `Help`

`Help` should stay minimal. It should not reintroduce large prose blocks into the tray.

## Filter Design

The current tall multi-select boxes should be replaced with denser controls inside the expanded `Filters` section.

Requirements:

- reduce vertical height significantly relative to the current design
- allow scrolling inside filter groups when there are many values
- preserve multi-select behavior
- preserve current filter categories: `status`, `confidence`, and `reason`

Acceptable implementations include:

- compact checkbox lists with internal scroll
- denser token/chip-style selections
- searchable compact list controls

The implementation should prefer clarity and compactness over styling.

## Benchmark Controls

Benchmark controls move fully into the tray.

The main view should no longer dedicate a full-width benchmark block in the sticky top area.

Inside the `Benchmark` tray section:

- show the current benchmark URL or summary
- keep the existing reset behavior
- preserve session-scoped benchmark override behavior
- surface benchmark-specific explanation through concise text or tooltip-level help

## Bulk Actions

Bulk actions move from the top area into the `Bulk actions` tray section.

This section keeps:

- `Select visible`
- `Unselect visible`
- `Dismiss selected`
- `Restore selected`

Any explanation that these actions apply only to visible rows should be delivered through concise help, not a permanent paragraph in the main sticky area.

## Scan Status

Scan state remains visible in the top bar because it is operationally important.

The current separate scan-status card should be compressed into a simpler status line or compact progress area. It should convey the same information more efficiently:

- in progress
- complete
- failed
- progress count where applicable

The scan state should remain understandable without opening the tray.

## Responsive Behavior

### Wide Screens

- tray pinned open
- divider visible
- divider draggable
- stored tray width restored if valid

### Narrow Screens

- tray collapses behind a `Tools` or `Filters` entry point
- divider is hidden when the tray is no longer pinned
- stored desktop tray width should not force broken narrow layouts

The narrow layout should prioritize keeping the table accessible and avoiding wasted vertical space.

## Persistence

Persist the following client-side preferences where reasonable:

- tray width
- last expanded tray section

Persistence should be resilient to screen-size changes and ignore stale values that no longer fit the available layout.

## Accessibility and Usability Notes

- keep labels explicit even if the layout is more compact
- ensure drag handle is visually discoverable
- keep button labels plain and literal
- use hover or tooltip help sparingly and only for explanatory text
- avoid decorative graphics or heavy visual treatment

## Verification

Verification should confirm that the refactor preserves all current review capabilities:

- scan can still run and update status correctly
- counts remain visible in the top bar
- filters still work across `status`, `confidence`, and `reason`
- bulk actions still operate on the intended visible rows
- benchmark override behavior remains intact
- row review and apply workflows still function
- tray resizing respects min/max bounds
- tray width persists across reloads where appropriate
- narrow layout does not break table access

## Implementation Boundary

This is a layout and interaction refactor only. The implementation should stay inside the source-registry local UI and should not alter server-side review behavior except where required to support client-side layout state.
