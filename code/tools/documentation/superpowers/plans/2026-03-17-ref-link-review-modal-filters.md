# Ref_link Review Modal/Filter Upgrade Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the inline ref_link review panel with a large modal workspace that supports clickable URLs, multi-select filters, and filtered-scope bulk selection controls.

**Architecture:** Keep the work inside the existing embedded HTML/CSS/JS in `ui_local.py`. Extend the existing front-end state object to track modal visibility, filters, and filtered selection helpers while reusing the current scan/apply endpoints.

**Tech Stack:** Python `unittest`, embedded HTML/CSS/JavaScript in `ui_local.py`

---

## Chunk 1: UI Test Guardrails

### Task 1: Add failing HTML regression tests

**Files:**
- Modify: `code/tools/sources/test_ui_local_html.py`
- Test: `code/tools/sources/test_ui_local_html.py`

- [ ] **Step 1: Write failing tests for the new modal/filter UI markers**
- [ ] **Step 2: Run the focused HTML tests and verify they fail for the missing hooks**
- [ ] **Step 3: Commit the failing-test checkpoint if useful**

## Chunk 2: Modal Review Workspace

### Task 2: Replace the inline panel with a modal overlay shell

**Files:**
- Modify: `code/tools/sources/ui_local.py`
- Test: `code/tools/sources/test_ui_local_html.py`

- [ ] **Step 1: Add modal markup and CSS hooks**
- [ ] **Step 2: Add modal open/close/render helpers**
- [ ] **Step 3: Run the focused HTML tests and verify the modal hooks now pass**

### Task 3: Add filtering, filtered bulk actions, and clickable URL rendering

**Files:**
- Modify: `code/tools/sources/ui_local.py`
- Test: `code/tools/sources/test_ui_local_html.py`

- [ ] **Step 1: Extend review state with confidence/reason filters**
- [ ] **Step 2: Add filtered-row helpers and per-bucket bulk actions**
- [ ] **Step 3: Render current/proposed URLs as anchors with safe truncation**
- [ ] **Step 4: Run focused tests and verify the new hooks pass**

## Chunk 3: Full Verification

### Task 4: Run the source-manager regression suite

**Files:**
- Test: `code/tools/sources/test_ref_link_review.py`
- Test: `code/tools/sources/test_ui_local_html.py`

- [ ] **Step 1: Run `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s code/tools/sources -p 'test*.py' -v`**
- [ ] **Step 2: Confirm zero failures and note any pre-existing warnings**
- [ ] **Step 3: Commit the finished implementation**
