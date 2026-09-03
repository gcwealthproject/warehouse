# ADAM SSM Visual Refresh Design

## Summary

This spec covers a presentation-only refresh of the local source manager UI in [code/tools/sources/ui_local.py](/home/iflores/Documents/GitHub/warehouse/code/tools/sources/ui_local.py). The app will be renamed to `ADAM SSM - Sleepless Source Manager` and restyled with an editorial visual direction while preserving the current workflow, field set, validation behavior, and save/build actions.

The refresh is intentionally constrained to the source-registry subsystem and does not alter canonical data handling, endpoints, payload shapes, or any warehouse pipeline behavior.

## Goals

- Replace the generic admin-form look with a more polished editorial aesthetic.
- Improve perceived quality through typography, spacing, color, and surface treatment.
- Make the single-page UI easier to scan without changing the existing information architecture.
- Keep validation and save/build feedback readable while retaining detailed raw output.
- Preserve support for both `Data Sources` and `Wealth Research` branches, including current responsive behavior.

## Non-Goals

- No workflow redesign.
- No new fields, removed fields, or reordered user flows.
- No backend/API changes.
- No validation logic changes.
- No changes outside the source-registry UI unless required for the launcher title copy.

## Current State

The current UI is a single HTML document embedded in `ui_local.py` with inline CSS and client-side interaction logic. It is functional but visually plain:

- Default-looking system typography and neutral gray surfaces.
- Weak hierarchy between the app shell, section headers, helper text, and dense form content.
- Buttons and tabs feel utilitarian rather than intentional.
- The status area is readable but visually raw, especially when showing structured validation results or diffs.

Because the request is visual polish only, the implementation should treat the current DOM structure and JS behavior as the baseline and avoid opportunistic restructuring.

## Visual Direction

The approved direction is `Ledger Editorial`.

### Identity

- Rename the app heading to `ADAM SSM - Sleepless Source Manager`.
- Add or refine subtitle copy so the tool still clearly communicates that it validates and writes locally.
- Preserve the local/offline utility framing; the new identity should feel distinctive but still operationally serious.

### Mood

- Warm, paper-toned neutrals instead of default cool gray backgrounds.
- Restrained navy or ink-blue accents for tabs, buttons, and focus states.
- More deliberate contrast between the page background, panel surfaces, and inputs.
- A finished, research-tool feel rather than a generic internal admin screen.

### Typography

- Use a more expressive heading face or typographic treatment for the app title and section headings.
- Keep form text highly readable and practical.
- Strengthen hierarchy through size, weight, case, and spacing rather than decorative elements.
- Labels should be compact and disciplined, with better contrast and spacing above controls.

## Component Treatment

The page structure remains the same. The refresh applies visual system changes to existing components.

### App Shell

- Keep a centered content container, but make it feel more intentional through improved padding, radius, border treatment, and shadow restraint.
- Use a background treatment that frames the app rather than leaving it on a flat gray page.
- Ensure the shell still works on narrower screens introduced by the existing mobile pass.

### Branch Tabs

- Keep the two-branch toggle as-is: `Data Sources` and `Wealth Research`.
- Restyle it as a deliberate segmented control or tab system with clearer active/inactive states.
- Preserve current branch-switching behavior and JS hooks.

### Panels and Sections

- Existing logical areas such as `BibTeX Paste`, `Core Source Fields`, `Bib Fields`, `Actions`, `Status`, and search/edit helpers should read as distinct panels.
- Section headers should have stronger visual hierarchy and spacing.
- Panel styling should be consistent across both branches.

### Inputs and Form Controls

- Inputs, textareas, selects, and datalist-backed fields should receive quieter borders, warmer fills, and clearer focus styles.
- Required markers should remain obvious but visually integrated with the new palette.
- `details`/`summary` blocks should be styled so optional sections feel designed rather than browser-default.
- Dense grids should remain intact, but spacing should improve enough that the form feels less raw.

### Buttons

- Maintain the semantic distinction between standard, secondary, and destructive actions.
- Improve button sizing, radius, contrast, and hover/focus states so the action hierarchy is clear at a glance.
- Do not change current action labels unless necessary for the title/identity refresh.

### Search Results

- Keep the current search tables and filtering behavior.
- Improve table styling, row spacing, hover treatment, and overall readability.
- Avoid changing the structure enough to risk breaking current DOM-dependent behavior.

## Status and Feedback

The current status output remains detailed, but its presentation becomes more legible.

- Keep the `pre`-based output behavior and existing status-color semantics.
- Restyle the status container as an audit/review panel that fits the editorial shell.
- Preserve good readability for:
  - success/warning/failure summaries
  - validation check lists
  - git diff fragments
  - long multi-line technical output
- Keep helper copy around parsing and save/build actions, but refine tone and visual weight so it is less noisy.

## Motion and Interaction

- Limit motion to subtle CSS transitions for hover, focus, tab state, and section reveal where already present.
- Do not add animated flows, delayed loading sequences, or anything that could obscure form state.
- Hidden/expanded sections should feel smoother only if the change stays clearly presentation-only.

## Responsiveness

The existing responsive behavior must be preserved or improved.

- The single-page form must remain usable on narrower widths.
- Improved spacing cannot assume desktop-only widths.
- Search results, status output, and form grids must remain readable without horizontal overflow beyond what is already necessary for technical output.

## Implementation Boundaries

Expected primary file:

- Modify: [code/tools/sources/ui_local.py](/home/iflores/Documents/GitHub/warehouse/code/tools/sources/ui_local.py)

Possible supporting files only if needed for polish consistency:

- Review only: [code/tools/source_manager_linux.sh](/home/iflores/Documents/GitHub/warehouse/code/tools/source_manager_linux.sh)
- Review only: [code/tools/source_manager_mac.command](/home/iflores/Documents/GitHub/warehouse/code/tools/source_manager_mac.command)
- Review only: [code/tools/source_manager_win.bat](/home/iflores/Documents/GitHub/warehouse/code/tools/source_manager_win.bat)

No changes are expected in canonical metadata, generated bibliography artifacts, or broader warehouse code.

## Risks

- Styling the inline HTML/CSS inside a single large Python string can accidentally break DOM structure if edits are not tightly scoped.
- Over-polishing the page could unintentionally reduce readability for dense, operational tasks.
- Changes to status container styling must preserve readability for monospaced output and diff highlighting.
- Adjustments that look good in `Data Sources` must also be checked against `Wealth Research`, which shares some styling but differs in specific controls.

## Verification Requirements

Implementation should verify all of the following:

- The page title and visible app heading reflect `ADAM SSM - Sleepless Source Manager`.
- Both branches render correctly with the new styling.
- Add/edit mode toggles still show and hide the correct controls.
- BibTeX paste sections, optional `details` areas, and search panels remain functional.
- Status rendering remains readable for pass/warn/fail output and unified diffs.
- The layout remains usable on narrow screens.

## Planning Notes

The implementation plan should treat this as a presentation-only change and organize work around:

1. Test coverage or verification for the rendered HTML/CSS markers that define the new identity and styling.
2. Minimal CSS/markup updates inside `ui_local.py`.
3. Regression verification across both branches and key UI states.
