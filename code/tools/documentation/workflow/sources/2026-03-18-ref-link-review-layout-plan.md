# Ref_link Review Layout Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refactor the `ref_link` review modal so the table is the primary surface, the top bar is compact, and secondary controls move into a pinned resizable right-side tray.

**Architecture:** Keep all behavior inside the existing `ui_local.py` HTML/JS bundle and preserve current API semantics. Reorganize the modal into a compact sticky header plus a resizable tray, replace the tall top-area filter controls with denser tray-based controls, and persist client-only UI state such as tray width and last-open tray section.

**Tech Stack:** Python-generated HTML, inline CSS, inline JavaScript state management, `unittest` HTML-string tests

---

## File Map

- Modify: `code/tools/sources/ui_local.py`
  - Update modal markup
  - Update modal CSS
  - Add tray layout state and persistence helpers
  - Replace top-area filter layout with tray-based sections
  - Add tray resize behavior and responsive logic
- Modify: `code/tools/sources/test_ui_local_html.py`
  - Update string-based HTML/UI assertions for the new layout hooks
- Reference: `code/tools/documentation/workflow/sources/2026-03-18-ref-link-review-layout-design.md`

## Chunk 1: State and Shell Refactor

### Task 1: Add failing HTML-hook tests for the tray layout

**Files:**
- Modify: `code/tools/sources/test_ui_local_html.py`
- Reference: `code/tools/documentation/workflow/sources/2026-03-18-ref-link-review-layout-design.md`

- [ ] **Step 1: Write failing test assertions for the new shell hooks**
  - Add assertions for:
    - tray container hook
    - tray section header hooks
    - tray resize handle hook
    - compact top-bar summary hooks
    - removal of obsolete tall top-area filter layout markers where appropriate

- [ ] **Step 2: Run the targeted test to verify it fails**

Run:
```bash
python3 -m unittest code/tools/sources/test_ui_local_html.py -v
```

Expected:
- FAIL on missing tray layout markers

- [ ] **Step 3: Add minimal shell/state scaffolding in `ui_local.py`**
  - Extend `emptyRefLinkReviewState()` with:
    - tray width
    - active tray section
    - responsive tray-open state if needed for narrow screens
  - Add local-storage helpers for tray width and active section
  - Add modal markup hooks for:
    - compact top bar
    - tray container
    - tray sections
    - tray resize divider

- [ ] **Step 4: Re-run the targeted test to verify it passes**

Run:
```bash
python3 -m unittest code/tools/sources/test_ui_local_html.py -v
```

Expected:
- PASS for the new hook assertions

- [ ] **Step 5: Commit shell/state scaffolding**

```bash
git add code/tools/sources/ui_local.py code/tools/sources/test_ui_local_html.py
git commit -m "refactor: add ref_link review tray shell"
```

## Chunk 2: Tray Interactions and Filter Refactor

### Task 2: Add failing tests for compact tray interactions

**Files:**
- Modify: `code/tools/sources/test_ui_local_html.py`
- Modify: `code/tools/sources/ui_local.py`

- [ ] **Step 1: Add failing assertions for interaction hooks**
  - Add assertions for:
    - active tray section markers
    - tray section toggle handler
    - compact filter controls
    - narrow-layout tools entry point if introduced

- [ ] **Step 2: Run the targeted test to verify it fails**

Run:
```bash
python3 -m unittest code/tools/sources/test_ui_local_html.py -v
```

Expected:
- FAIL on missing tray interaction markers

- [ ] **Step 3: Implement the tray interaction refactor**
  - Move benchmark UI into the tray
  - Move bulk actions into the tray
  - Replace top-area tall filter boxes with denser tray filter groups
  - Add section-toggle behavior so one tray section is expanded at a time
  - Replace permanent explanatory text with compact help affordances
  - Keep counts, scan state, `Refresh scan`, and `Apply selected` in the compact top bar

- [ ] **Step 4: Re-run the targeted test to verify it passes**

Run:
```bash
python3 -m unittest code/tools/sources/test_ui_local_html.py -v
```

Expected:
- PASS for the updated interaction assertions

- [ ] **Step 5: Commit tray interaction refactor**

```bash
git add code/tools/sources/ui_local.py code/tools/sources/test_ui_local_html.py
git commit -m "refactor: move ref_link review controls into tray"
```

## Chunk 3: Resize, Responsiveness, and Verification

### Task 3: Add failing tests for resize and responsive hooks

**Files:**
- Modify: `code/tools/sources/test_ui_local_html.py`
- Modify: `code/tools/sources/ui_local.py`

- [ ] **Step 1: Add failing assertions for resize and responsive hooks**
  - Add assertions for:
    - tray resize state helpers
    - width persistence hooks
    - narrow-layout tray/toggle hooks

- [ ] **Step 2: Run the targeted test to verify it fails**

Run:
```bash
python3 -m unittest code/tools/sources/test_ui_local_html.py -v
```

Expected:
- FAIL on missing resize/responsive markers

- [ ] **Step 3: Implement resize and responsive behavior**
  - Add tray divider drag behavior with min/max bounds
  - Persist tray width across reloads
  - Keep desktop tray pinned on wide screens
  - Collapse tray behind a narrow-screen entry point on smaller layouts
  - Ensure compact top bar still shows counts and scan state without expanding the tray

- [ ] **Step 4: Run focused verification**

Run:
```bash
python3 -m unittest code/tools/sources/test_ui_local_html.py -v
```

Expected:
- PASS with all `UiLocalHtmlTests` green

- [ ] **Step 5: Run broader verification**

Run:
```bash
python3 -m unittest code/tools/sources/test_ref_link_review.py -v
python3 -m unittest code/tools/sources/test_ui_local_html.py -v
```

Expected:
- PASS with no regressions in ref-link review logic tests or UI HTML tests

- [ ] **Step 6: Commit resize and responsive behavior**

```bash
git add code/tools/sources/ui_local.py code/tools/sources/test_ui_local_html.py
git commit -m "refactor: compact ref_link review layout"
```

## Execution Notes

- Do not change backend API contracts unless strictly required for client layout state.
- Keep selection, dismissal, restore, override, and apply behavior intact.
- Prefer narrow, literal labels over decorative or “productized” copy.
- Keep edits scoped to the source-registry subsystem.

## Final Verification Checklist

- [ ] The top bar is visibly shorter than the current implementation.
- [ ] The review table appears immediately below the top bar.
- [ ] The tray is pinned on wide screens and resizable by drag.
- [ ] Filters, benchmark, bulk actions, and help live in the tray.
- [ ] The top bar still shows counts and scan state.
- [ ] Existing tests pass after the refactor.
