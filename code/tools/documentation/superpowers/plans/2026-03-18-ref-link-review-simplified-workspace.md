# Ref_link Review Simplified Workspace Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Simplify the ref_link review modal into one filtered workspace with one shared bulk-action row, native multi-select filters, explicit session-only benchmark control, and clearer instructional copy.

**Architecture:** Keep the feature inside the existing source-manager codepath. Extend the backend scan helper just enough to accept a session benchmark override and expose row-level status, then flatten the UI state in the single-file local app so one filtered table replaces the old three-bucket rendering. Preserve existing progress polling, apply validation, inline overrides, dismiss/restore semantics, and session-only column resizing.

**Tech Stack:** Python 3, `unittest`, embedded HTML/CSS/JavaScript in `code/tools/sources/ui_local.py`, source-registry helper logic in `code/tools/sources/ref_link_review.py`

---

## File Structure

### Files To Modify

- `code/tools/sources/ref_link_review.py`
  - Extend scan entry points to accept a session benchmark URL override
  - Validate that benchmark override locally
  - Add explicit row-level `status` values in proposal payloads
- `code/tools/sources/ui_local.py`
  - Update `/api/ref_link_review_scan` to accept and pass the session benchmark URL
  - Replace the three-group review modal rendering with one flattened filtered table
  - Replace bulky filter cards with native multi-select controls
  - Add clearer explanatory copy and a session-only benchmark input
- `code/tools/sources/test_ref_link_review.py`
  - Add TDD coverage for benchmark override handling and row-level status
- `code/tools/sources/test_ui_local_html.py`
  - Add TDD coverage for the new benchmark input, status filter, single shared action row, and explanatory copy

### Files To Create

- None

### Working Constraints

- Implementation must happen in a dedicated git worktree, not in the current `main` worktree, because the main repo already has unrelated local edits in source data and generated artifacts.
- Do not modify `metadata/sources/sources.yaml` for the benchmark input feature; the benchmark override is session-local only.
- Do not broaden scope beyond the source-registry subsystem.

---

## Chunk 1: Backend Scan Shape

### Task 1: Add failing backend tests for session benchmark override and row status

**Files:**
- Modify: `code/tools/sources/test_ref_link_review.py`
- Test: `code/tools/sources/test_ref_link_review.py`

- [ ] **Step 1: Write the failing test for benchmark override acceptance**

```python
def test_fetch_and_scan_registry_ref_links_uses_session_benchmark_override(self):
    registry = {
        "config": {
            "bib_output": "documentation/BibTeX files/GCWealthProject_DataSourcesLibrary.bib",
            "bibbase_profile_source_url": "https://bibbase.org/f/default/default.bib",
        },
        "records": [],
    }
    seen_urls = []

    def fake_fetch(url, timeout_seconds):
        seen_urls.append(url)
        return {"text": "var bibbase_data = {\"data\": \"var bibbase = {data: [], groups: []};\"}; document.write(bibbase_data.data);", "method": "fake"}

    self.mod.fetch_and_scan_registry_ref_links(
        registry,
        fetch_text=fake_fetch,
        benchmark_url_override="https://bibbase.org/f/session/override.bib",
    )

    self.assertEqual(seen_urls[0], "https://bibbase.org/f/session/override.bib")
```

- [ ] **Step 2: Write the failing test for invalid benchmark override rejection**

```python
def test_fetch_and_scan_registry_ref_links_rejects_invalid_session_benchmark_override(self):
    out = self.mod.fetch_and_scan_registry_ref_links(
        {"config": {"bib_output": "documentation/BibTeX files/GCWealthProject_DataSourcesLibrary.bib"}, "records": []},
        fetch_text=lambda *_args, **_kwargs: {"text": "", "method": "fake"},
        benchmark_url_override="not-a-url",
    )

    self.assertFalse(out["ok"])
    self.assertEqual(out["status"], "invalid_benchmark_url")
```

- [ ] **Step 3: Write the failing test for row-level status**

```python
def test_scan_registry_ref_links_includes_row_level_status(self):
    scan = self.mod.scan_registry_ref_links(
        registry,
        show_payload_text=make_show_payload("Example2024", "example-exampletitle-2024"),
        hosted_bib_text="@article{Example2024,}\n",
        local_bib_text="@article{Example2024,}\n",
    )

    self.assertEqual(scan["ready_to_apply"][0]["status"], "ready_to_apply")
```

- [ ] **Step 4: Run tests to verify they fail**

Run:

```bash
PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=code/tools/sources python3 -m unittest \
  test_ref_link_review.RefLinkReviewScanTests.test_fetch_and_scan_registry_ref_links_uses_session_benchmark_override \
  test_ref_link_review.RefLinkReviewScanTests.test_fetch_and_scan_registry_ref_links_rejects_invalid_session_benchmark_override \
  test_ref_link_review.RefLinkReviewScanTests.test_scan_registry_ref_links_includes_row_level_status -v
```

Expected:

- FAIL because `benchmark_url_override` is not accepted yet
- FAIL because invalid override handling does not exist yet
- FAIL because proposal rows do not yet include `status`

- [ ] **Step 5: Commit the red test state**

```bash
git add code/tools/sources/test_ref_link_review.py
git commit -m "test: cover ref_link review benchmark override shape"
```

### Task 2: Implement minimal backend support

**Files:**
- Modify: `code/tools/sources/ref_link_review.py`
- Test: `code/tools/sources/test_ref_link_review.py`

- [ ] **Step 1: Add the minimal scan-helper changes**

Implement:

- optional `benchmark_url_override` argument on `fetch_and_scan_registry_ref_links`
- HTTP(S) validation for the override
- use override when present instead of registry config
- `status` field on each proposal row via `_proposal_row(...)`

Minimal implementation sketch:

```python
benchmark_url = normalize_whitespace(benchmark_url_override or profile_source_url)
if benchmark_url_override and not HTTP_URL_RE.match(benchmark_url):
    return {
        "ok": False,
        "status": "invalid_benchmark_url",
        "message": "Benchmark URL must start with http:// or https://",
    }
```

```python
def _proposal_row(..., status: str) -> dict:
    return {
        ...,
        "status": status,
    }
```

- [ ] **Step 2: Update all `_proposal_row(...)` call sites with explicit status**

Use:

- `"ready_to_apply"` for safe adds
- `"needs_review"` for mismatches or stale-hosted cases

- [ ] **Step 3: Run focused backend tests to verify green**

Run:

```bash
PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=code/tools/sources python3 -m unittest \
  test_ref_link_review.RefLinkReviewScanTests.test_fetch_and_scan_registry_ref_links_uses_session_benchmark_override \
  test_ref_link_review.RefLinkReviewScanTests.test_fetch_and_scan_registry_ref_links_rejects_invalid_session_benchmark_override \
  test_ref_link_review.RefLinkReviewScanTests.test_scan_registry_ref_links_includes_row_level_status -v
```

Expected: PASS

- [ ] **Step 4: Run the full backend test file**

Run:

```bash
PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=code/tools/sources python3 -m unittest test_ref_link_review -v
```

Expected: all `test_ref_link_review.py` tests PASS

- [ ] **Step 5: Commit the backend implementation**

```bash
git add code/tools/sources/ref_link_review.py code/tools/sources/test_ref_link_review.py
git commit -m "feat: add ref_link review benchmark override support"
```

---

## Chunk 2: Modal Simplification

### Task 3: Add failing UI HTML tests for the simplified workspace

**Files:**
- Modify: `code/tools/sources/test_ui_local_html.py`
- Test: `code/tools/sources/test_ui_local_html.py`

- [ ] **Step 1: Write the failing HTML test for benchmark and status filter hooks**

```python
def test_ref_link_review_simplified_workspace_hooks_exist(self):
    for marker in [
        "ref_link_review_benchmark_url",
        "ref_link_review_status_filters",
        "Select visible",
        "Unselect visible",
        "Bulk actions apply only to the rows currently visible",
    ]:
        self.assertIn(marker, self.html)
```

- [ ] **Step 2: Write the failing assertion for removal of old repeated button labels**

```python
def test_ref_link_review_repeated_bucket_actions_are_removed(self):
    self.assertNotIn("Select filtered", self.html)
    self.assertNotIn("Unselect filtered", self.html)
```

- [ ] **Step 3: Run the focused UI tests to verify they fail**

Run:

```bash
PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=code/tools/sources python3 -m unittest \
  test_ui_local_html.UiLocalHtmlTests.test_ref_link_review_simplified_workspace_hooks_exist \
  test_ui_local_html.UiLocalHtmlTests.test_ref_link_review_repeated_bucket_actions_are_removed -v
```

Expected:

- FAIL because the current modal still renders the old filter and action structure

- [ ] **Step 4: Commit the red UI test state**

```bash
git add code/tools/sources/test_ui_local_html.py
git commit -m "test: cover simplified ref_link review workspace"
```

### Task 4: Implement the simplified modal state and markup

**Files:**
- Modify: `code/tools/sources/ui_local.py`
- Test: `code/tools/sources/test_ui_local_html.py`

- [ ] **Step 1: Add the benchmark input and explanatory copy to the modal header**

Update the embedded HTML so the modal header contains:

- short purpose text
- session-only benchmark input with id `ref_link_review_benchmark_url`
- helper note explaining it does not update `sources.yaml`

Markup target:

```html
<input id="ref_link_review_benchmark_url" ...>
<small>Session only. Changing this here does not update sources.yaml.</small>
```

- [ ] **Step 2: Replace the current filter cards with one compact filter row**

Use native multi-select controls with ids:

- `ref_link_review_status_filters`
- `ref_link_review_confidence_filters`
- `ref_link_review_reason_filters`

- [ ] **Step 3: Flatten review rows into one visible result set**

Implement a helper that combines:

```javascript
function allRefLinkReviewRows(){
  return [
    ...(refLinkReviewState.ready_to_apply || []),
    ...(refLinkReviewState.needs_review || []),
    ...(refLinkReviewState.dismissed || []),
  ];
}
```

Then update render flow so:

- the modal renders one filtered table
- row status comes from `row.status`
- there are no three bucket sections on screen anymore

- [ ] **Step 4: Replace repeated bucket action rows with one shared visible-row action row**

Render only:

- `Select visible`
- `Unselect visible`
- `Dismiss selected`
- `Restore selected` when dismissed rows are visible

Actions must operate on the current filtered result set only.

- [ ] **Step 5: Wire session-local benchmark behavior into scan start and refresh**

Update `scanRefLinkReview()` and refresh behavior to send:

```javascript
{
  benchmark_url: document.getElementById('ref_link_review_benchmark_url').value.trim()
}
```

Reject invalid benchmark URLs locally before the request.

- [ ] **Step 6: Update the server route to pass the benchmark URL into the scan helper**

In `/api/ref_link_review_scan`, read `benchmark_url` from JSON and pass it through to:

```python
fetch_and_scan_registry_ref_links(..., benchmark_url_override=benchmark_url)
```

- [ ] **Step 7: Run focused UI tests to verify green**

Run:

```bash
PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=code/tools/sources python3 -m unittest \
  test_ui_local_html.UiLocalHtmlTests.test_ref_link_review_simplified_workspace_hooks_exist \
  test_ui_local_html.UiLocalHtmlTests.test_ref_link_review_repeated_bucket_actions_are_removed -v
```

Expected: PASS

- [ ] **Step 8: Run the full UI HTML test file**

Run:

```bash
PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=code/tools/sources python3 -m unittest test_ui_local_html -v
```

Expected: all `test_ui_local_html.py` tests PASS

- [ ] **Step 9: Commit the modal simplification**

```bash
git add code/tools/sources/ui_local.py code/tools/sources/test_ui_local_html.py
git commit -m "feat: simplify ref_link review workspace"
```

---

## Chunk 3: End-To-End Verification

### Task 5: Run full verification and live smoke checks

**Files:**
- Modify: none expected
- Test: `code/tools/sources/test_ref_link_review.py`
- Test: `code/tools/sources/test_ui_local_html.py`

- [ ] **Step 1: Run the full source-manager unittest suite**

Run:

```bash
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s code/tools/sources -p 'test*.py' -v
```

Expected: all tests PASS

- [ ] **Step 2: Start the local UI server in the worktree**

Run:

```bash
python3 code/tools/sources/ui_local.py --host 127.0.0.1 --port 8768
```

Expected:

- the server starts cleanly
- the modal page loads

- [ ] **Step 3: Smoke-test the simplified workspace manually**

Check:

- the modal contains one result table, not three visible groups
- the benchmark field is visible and editable
- `Refresh scan` uses the session benchmark value
- the bulk-action row appears once
- visible-row actions affect only the currently filtered rows
- dismiss and restore still work through the filtered table

- [ ] **Step 4: Record any unexpected regressions before merge**

If anything breaks:

- capture the failing command
- add a test before fixing
- do not merge until the suite is green again

- [ ] **Step 5: Commit final verification-only adjustments if needed**

```bash
git add <files>
git commit -m "fix: polish simplified ref_link review flow"
```

Use this step only if verification uncovered code changes. Otherwise skip it.

---

## Execution Notes

- Use `superpowers:using-git-worktrees` first and create the implementation branch in `~/.config/superpowers/worktrees/warehouse/`
- Because the current `main` worktree is dirty in unrelated files, do not implement directly on `main`
- Keep edits ASCII-only unless an existing file already uses other characters
- Use `apply_patch` for all manual file edits
- Prefer focused test runs during red/green, then the full suite at the end

