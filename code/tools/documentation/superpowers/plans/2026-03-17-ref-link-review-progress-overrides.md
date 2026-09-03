# Ref_link Review Progress/Override Upgrade Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add real scan progress, inline proposal overrides, lazy observation details, and session-only draggable columns to the ref_link review modal.

**Architecture:** Extend the existing local review helper and `ui_local.py` modal rather than introducing a separate subsystem. The backend will expose lightweight in-process scan jobs and richer row data, while the front end will manage temporary override/detail/column-width state inside the current session.

**Tech Stack:** Python `unittest`, embedded HTML/CSS/JavaScript in `ui_local.py`, local in-process HTTP handlers

---

## Chunk 1: Backend Guardrails

### Task 1: Add failing backend tests for scan progress and override application

**Files:**
- Modify: `code/tools/sources/test_ref_link_review.py`
- Test: `code/tools/sources/test_ref_link_review.py`

- [ ] **Step 1: Write failing tests for progress callbacks and richer row payload fields**
- [ ] **Step 2: Write a failing test for apply-time override usage and invalid override rejection**
- [ ] **Step 3: Run the focused backend tests and verify they fail for the intended reasons**

## Chunk 2: UI Guardrails

### Task 2: Add failing HTML tests for modal progress/details/override/resize hooks

**Files:**
- Modify: `code/tools/sources/test_ui_local_html.py`
- Test: `code/tools/sources/test_ui_local_html.py`

- [ ] **Step 1: Add failing HTML marker tests for progress UI, details toggles, override inputs, and resize handles**
- [ ] **Step 2: Run the focused HTML tests and verify they fail**

## Chunk 3: Backend Implementation

### Task 3: Add scan job progress and override-aware apply logic

**Files:**
- Modify: `code/tools/sources/ref_link_review.py`
- Modify: `code/tools/sources/ui_local.py`
- Test: `code/tools/sources/test_ref_link_review.py`

- [ ] **Step 1: Implement progress-aware scan helper output and richer row payloads**
- [ ] **Step 2: Add lightweight scan-job tracking endpoints in `ui_local.py`**
- [ ] **Step 3: Extend apply logic to use validated inline overrides**
- [ ] **Step 4: Run focused backend tests and verify they pass**

## Chunk 4: Modal Implementation

### Task 4: Add progress UI, lazy details, inline overrides, and draggable columns

**Files:**
- Modify: `code/tools/sources/ui_local.py`
- Test: `code/tools/sources/test_ui_local_html.py`

- [ ] **Step 1: Add modal scan-status UI and polling flow for scan/refresh**
- [ ] **Step 2: Add override, expanded-details, and column-width session state**
- [ ] **Step 3: Add row detail panels and override inputs**
- [ ] **Step 4: Add drag handles and width-update helpers for the compact columns**
- [ ] **Step 5: Run focused HTML tests and verify they pass**

## Chunk 5: Full Verification

### Task 5: Verify the upgraded review workflow

**Files:**
- Test: `code/tools/sources/test_ref_link_review.py`
- Test: `code/tools/sources/test_ui_local_html.py`

- [ ] **Step 1: Run `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s code/tools/sources -p 'test*.py' -v`**
- [ ] **Step 2: Do a local UI smoke check for scan progress and modal loading**
- [ ] **Step 3: Commit the finished implementation**
