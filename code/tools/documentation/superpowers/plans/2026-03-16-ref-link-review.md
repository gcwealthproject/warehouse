# Ref Link Review Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a standalone Data Sources workflow that scans the full registry against live BibBase entry URLs, proposes `ref_link` additions, flags uncertain cases for manual review, and bulk-applies selected safe proposals without overwriting existing nonblank `ref_link` values.

**Architecture:** Keep the UI integration inside the existing inline HTML/CSS/JS in `code/tools/sources/ui_local.py`, but move the new scan/classify/apply rules into a small helper module so the matching logic is testable without starting the server. The UI server should expose one read-only scan endpoint and one explicit apply endpoint, with the apply path re-running proposal validation before mutating `metadata/sources/sources.yaml`, appending change-log entries, and rebuilding the standard Data Sources artifacts.

**Tech Stack:** Python 3, inline HTML/CSS/JavaScript in `code/tools/sources/ui_local.py`, `unittest`, JSON-backed registry files, existing local build flow in `build_sources_artifacts.py`, live BibBase HTTP fetches

---

## File Map

- Create: `code/tools/sources/ref_link_review.py`
  Responsibility: fetch and parse live BibBase data, compare registry records to per-entry BibBase URLs, classify proposal confidence, and revalidate/apply selected proposals against in-memory registry records.
- Create: `code/tools/sources/test_ref_link_review.py`
  Responsibility: unit-test scan classification, BibBase payload parsing, drift detection, and apply-time stale/overwrite protections with fixture strings instead of live network calls.
- Modify: `code/tools/sources/ui_local.py`
  Responsibility: expose new scan/apply endpoints, add the standalone `Review ref_link proposals` action, render the inline review panel, manage client-side selection/dismissal state, and wire apply confirmation into the existing artifact rebuild flow.
- Modify: `code/tools/sources/test_ui_local_html.py`
  Responsibility: lock in the new button, panel, and client-side wiring markers in the inline HTML document.
- Modify: `code/tools/sources/common.py`
  Responsibility: add canonical config defaults for the BibBase profile URL and timeout used by the new review feature.
- Modify: `metadata/sources/sources.yaml`
  Responsibility: seed the new config keys with the current Data Sources BibBase profile URL so the standalone scan works immediately.
- Modify: `documentation/workflow/sources/source_registry.md`
  Responsibility: document the standalone review action, the proposal buckets, and the explicit bulk-apply behavior.
- Review only: `metadata/sources/bibbase.local.json`
  Responsibility: confirm whether any local-only references need a note now that the canonical config moves into `sources.yaml`; do not expand scope into cleanup unless the implementation proves it necessary.

## Chunk 1: Build And Test The Backend Review Contract

### Task 1: Create a test harness for exact-key proposal generation

**Files:**
- Create: `code/tools/sources/test_ref_link_review.py`
- Create: `code/tools/sources/ref_link_review.py`
- Spec: `docs/superpowers/specs/2026-03-16-ref-link-review-design.md`

- [ ] **Step 1: Write the failing test**

Create `code/tools/sources/test_ref_link_review.py` with a direct-import harness and one high-confidence scan case:

```python
import importlib.util
import json
import pathlib
import sys
import unittest


def load_ref_link_review_module():
    path = pathlib.Path("code/tools/sources/ref_link_review.py").resolve()
    sys.path.insert(0, str(path.parent))
    spec = importlib.util.spec_from_file_location("ref_link_review", path)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


def make_show_payload(entry_key, bibbaseid):
    entry = {
        "key": entry_key,
        "bibbaseid": bibbaseid,
        "bibtex": f"@article{{{entry_key},\\n  title = {{Example Title}},\\n  year = {{2024}}\\n}}\\n",
        "title": "Example Title",
        "year": "2024",
        "author": [{"lastnames": ["Example"], "firstnames": ["Eve"], "suffixes": [], "propositions": []}],
    }
    inner = f'var bibbase = {{data: {json.dumps([entry])}, groups: []}};'
    outer = {"data": inner}
    return f"var bibbase_data = {json.dumps(outer)}; document.write(bibbase_data.data);"


class RefLinkReviewScanTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.mod = load_ref_link_review_module()

    def test_blank_exact_citekey_match_is_ready_to_apply(self):
        registry = {
            "config": {"bib_output": "documentation/BibTeX files/GCWealthProject_DataSourcesLibrary.bib"},
            "records": [
                {
                    "id": "src-example",
                    "source": "Example2024",
                    "citekey": "Example2024",
                    "ref_link": "",
                    "link": "https://example.org/source",
                    "bib": {"title": "Example Title", "author": "Example, Eve", "year": "2024"},
                }
            ],
        }
        scan = self.mod.scan_registry_ref_links(
            registry,
            show_payload_text=make_show_payload("Example2024", "example-exampletitle-2024"),
            hosted_bib_text="@article{Example2024,}\\n",
            local_bib_text="@article{Example2024,}\\n",
        )
        self.assertEqual(scan["summary"]["ready_to_apply"], 1)
        proposal = scan["ready_to_apply"][0]
        self.assertEqual(proposal["record_id"], "src-example")
        self.assertTrue(proposal["selected"])
        self.assertEqual(
            proposal["proposed_ref_link"],
            "https://bibbase.org/network/publication/example-exampletitle-2024",
        )
        self.assertIn("blank ref_link, exact citekey match", proposal["reason_flags"])
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 code/tools/sources/test_ref_link_review.py -v`
Expected: `FAIL` because `code/tools/sources/ref_link_review.py` does not exist yet.

- [ ] **Step 3: Write minimal implementation**

Create `code/tools/sources/ref_link_review.py` with the smallest testable scan surface:

```python
import hashlib
import json
import re
from pathlib import Path
from typing import Dict, List

from common import normalize_url, normalize_whitespace, now_utc


def parse_bibbase_show_payload(show_payload_text: str) -> List[dict]:
    outer = json.loads(
        re.search(r"var bibbase_data = (.*); document\\.write\\(bibbase_data\\.data\\);?\\s*$", show_payload_text, re.S).group(1)
    )
    html = outer["data"]
    start = html.index("data:") + len("data:")
    while html[start].isspace():
        start += 1
    depth = 0
    in_string = False
    escaped = False
    end = None
    for idx in range(start, len(html)):
        ch = html[idx]
        if in_string:
            if escaped:
                escaped = False
            elif ch == "\\":
                escaped = True
            elif ch == '"':
                in_string = False
        else:
            if ch == '"':
                in_string = True
            elif ch == "[":
                depth += 1
            elif ch == "]":
                depth -= 1
                if depth == 0:
                    end = idx + 1
                    break
    return json.loads(html[start:end])


def _recover_citekey(entry: dict) -> str:
    bibtex = (entry.get("bibtex") or "").lstrip()
    match = re.match(r"^@\\w+\\{([^,]+),", bibtex)
    return normalize_whitespace(match.group(1) if match else entry.get("key", ""))


def _proposal_id(record_id: str, proposed_ref_link: str) -> str:
    return hashlib.sha256(f"{record_id}|{proposed_ref_link}".encode("utf-8")).hexdigest()


def scan_registry_ref_links(registry: dict, show_payload_text: str, hosted_bib_text: str, local_bib_text: str) -> dict:
    entries = parse_bibbase_show_payload(show_payload_text)
    by_citekey: Dict[str, List[str]] = {}
    for entry in entries:
        citekey = _recover_citekey(entry)
        candidate = normalize_url(f"https://bibbase.org/network/publication/{entry['bibbaseid']}")
        by_citekey.setdefault(citekey, [])
        if candidate not in by_citekey[citekey]:
            by_citekey[citekey].append(candidate)
    ready_to_apply = []
    needs_review = []
    for record in registry.get("records", []):
        citekey = normalize_whitespace(record.get("citekey", ""))
        current = normalize_url(record.get("ref_link", ""))
        candidates = by_citekey.get(citekey, [])
        if not candidates:
            continue
        if not current and len(candidates) == 1:
            ready_to_apply.append(
                {
                    "proposal_id": _proposal_id(record["id"], candidates[0]),
                    "record_id": record["id"],
                    "citekey": citekey,
                    "current_ref_link": current,
                    "proposed_ref_link": candidates[0],
                    "selected": True,
                    "confidence": "high",
                    "reason_flags": ["blank ref_link, exact citekey match"],
                }
            )
    return {
        "summary": {
            "ready_to_apply": len(ready_to_apply),
            "needs_review": len(needs_review),
            "dismissed": 0,
        },
        "ready_to_apply": ready_to_apply,
        "needs_review": needs_review,
        "scan_metadata": {"compared_at": now_utc(), "hosted_bib_matches_local": hosted_bib_text == local_bib_text},
    }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python3 code/tools/sources/test_ref_link_review.py -v`
Expected: `OK`

- [ ] **Step 5: Commit**

```bash
git add code/tools/sources/ref_link_review.py code/tools/sources/test_ref_link_review.py
git commit -m "feat: scaffold ref_link review scan helper"
```

### Task 2: Classify mismatches and hosted BibBase drift as review-only cases

**Files:**
- Modify: `code/tools/sources/test_ref_link_review.py`
- Modify: `code/tools/sources/ref_link_review.py`
- Spec: `docs/superpowers/specs/2026-03-16-ref-link-review-design.md`

- [ ] **Step 1: Write the failing test**

Extend `code/tools/sources/test_ref_link_review.py` with mismatch and drift coverage:

```python
    def test_existing_ref_link_mismatch_stays_in_needs_review(self):
        registry = {
            "config": {"bib_output": "documentation/BibTeX files/GCWealthProject_DataSourcesLibrary.bib"},
            "records": [
                {
                    "id": "src-example",
                    "source": "Example2024",
                    "citekey": "Example2024",
                    "ref_link": "https://bibbase.org/network/publication/example-old-2023",
                    "link": "https://example.org/source",
                    "bib": {"title": "Example Title", "author": "Example, Eve", "year": "2024"},
                }
            ],
        }
        scan = self.mod.scan_registry_ref_links(
            registry,
            show_payload_text=make_show_payload("Example2024", "example-new-2024"),
            hosted_bib_text="@article{Example2024,}\\n",
            local_bib_text="@article{Example2024,}\\n",
        )
        self.assertEqual(scan["summary"]["ready_to_apply"], 0)
        self.assertEqual(scan["summary"]["needs_review"], 1)
        proposal = scan["needs_review"][0]
        self.assertEqual(proposal["confidence"], "medium")
        self.assertIn("stored ref_link differs from live BibBase", proposal["reason_flags"])
        self.assertFalse(proposal["selected"])

    def test_hosted_bibbase_drift_downgrades_exact_match_to_needs_review(self):
        registry = {
            "config": {"bib_output": "documentation/BibTeX files/GCWealthProject_DataSourcesLibrary.bib"},
            "records": [
                {
                    "id": "src-example",
                    "source": "Example2024",
                    "citekey": "Example2024",
                    "ref_link": "",
                    "link": "https://example.org/source",
                    "bib": {"title": "Example Title", "author": "Example, Eve", "year": "2024"},
                }
            ],
        }
        scan = self.mod.scan_registry_ref_links(
            registry,
            show_payload_text=make_show_payload("Example2024", "example-new-2024"),
            hosted_bib_text="@article{OldKey2023,}\\n",
            local_bib_text="@article{Example2024,}\\n",
        )
        self.assertTrue(scan["scan_metadata"]["hosted_bib_is_stale"])
        self.assertEqual(scan["summary"]["ready_to_apply"], 0)
        self.assertEqual(scan["summary"]["needs_review"], 1)
        self.assertIn("hosted BibBase may be stale", scan["needs_review"][0]["reason_flags"])
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 code/tools/sources/test_ref_link_review.py -v`
Expected: `FAIL` because the scan helper currently treats every exact citekey/blank case as ready-to-apply and does not emit review-only mismatch rows.

- [ ] **Step 3: Write minimal implementation**

Expand `scan_registry_ref_links()` in `code/tools/sources/ref_link_review.py` so it:

- computes `hosted_bib_is_stale = hosted_bib_text != local_bib_text`
- moves exact-citekey blank proposals into `needs_review` instead of `ready_to_apply` when hosted drift is present
- adds review-only proposals when a stored nonblank `ref_link` differs from the live candidate
- includes `selected = False` for all non-high-confidence rows

Concrete implementation target:

```python
    hosted_bib_is_stale = hosted_bib_text != local_bib_text
    ...
        if current and current != candidates[0]:
            needs_review.append(
                {
                    "proposal_id": _proposal_id(record["id"], candidates[0]),
                    "record_id": record["id"],
                    "citekey": citekey,
                    "current_ref_link": current,
                    "proposed_ref_link": candidates[0],
                    "selected": False,
                    "confidence": "medium",
                    "reason_flags": ["stored ref_link differs from live BibBase"],
                }
            )
            continue
        if not current and len(candidates) == 1:
            reason_flags = ["blank ref_link, exact citekey match"]
            if hosted_bib_is_stale:
                reason_flags.append("hosted BibBase may be stale")
                needs_review.append({... "selected": False, "confidence": "medium", "reason_flags": reason_flags})
            else:
                ready_to_apply.append({... "selected": True, "confidence": "high", "reason_flags": reason_flags})
```

Update `scan_metadata` accordingly:

```python
"scan_metadata": {
    "compared_at": now_utc(),
    "hosted_bib_matches_local": not hosted_bib_is_stale,
    "hosted_bib_is_stale": hosted_bib_is_stale,
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python3 code/tools/sources/test_ref_link_review.py -v`
Expected: `OK`

- [ ] **Step 5: Commit**

```bash
git add code/tools/sources/ref_link_review.py code/tools/sources/test_ref_link_review.py
git commit -m "feat: classify ref_link review mismatches and drift"
```

### Task 3: Add apply-time stale protection and blank-only writes

**Files:**
- Modify: `code/tools/sources/test_ref_link_review.py`
- Modify: `code/tools/sources/ref_link_review.py`
- Spec: `docs/superpowers/specs/2026-03-16-ref-link-review-design.md`

- [ ] **Step 1: Write the failing test**

Extend `code/tools/sources/test_ref_link_review.py` with apply semantics:

```python
    def test_apply_selected_ref_links_updates_only_blank_records(self):
        registry = {
            "records": [
                {"id": "src-a", "citekey": "A2024", "ref_link": "", "source": "A2024", "bib": {"title": "A", "year": "2024"}},
                {"id": "src-b", "citekey": "B2024", "ref_link": "https://bibbase.org/network/publication/b-old", "source": "B2024", "bib": {"title": "B", "year": "2024"}},
            ]
        }
        proposals = [
            {
                "proposal_id": "p-a",
                "record_id": "src-a",
                "current_ref_link": "",
                "proposed_ref_link": "https://bibbase.org/network/publication/a-new",
                "selected": True,
            },
            {
                "proposal_id": "p-b",
                "record_id": "src-b",
                "current_ref_link": "https://bibbase.org/network/publication/b-old",
                "proposed_ref_link": "https://bibbase.org/network/publication/b-new",
                "selected": True,
            },
        ]
        out = self.mod.apply_selected_ref_links(registry, proposals, {"p-a", "p-b"})
        self.assertEqual(out["applied_ids"], ["src-a"])
        self.assertEqual(out["skipped_ids"], ["src-b"])
        self.assertEqual(registry["records"][0]["ref_link"], "https://bibbase.org/network/publication/a-new")
        self.assertEqual(registry["records"][1]["ref_link"], "https://bibbase.org/network/publication/b-old")

    def test_apply_selected_ref_links_skips_stale_proposals(self):
        registry = {
            "records": [
                {"id": "src-a", "citekey": "A2024", "ref_link": "https://bibbase.org/network/publication/already-set", "source": "A2024", "bib": {"title": "A", "year": "2024"}},
            ]
        }
        proposals = [
            {
                "proposal_id": "p-a",
                "record_id": "src-a",
                "current_ref_link": "",
                "proposed_ref_link": "https://bibbase.org/network/publication/a-new",
                "selected": True,
            }
        ]
        out = self.mod.apply_selected_ref_links(registry, proposals, {"p-a"})
        self.assertEqual(out["applied_ids"], [])
        self.assertEqual(out["stale_ids"], ["src-a"])
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 code/tools/sources/test_ref_link_review.py -v`
Expected: `FAIL` because there is no apply helper yet.

- [ ] **Step 3: Write minimal implementation**

Add an apply helper in `code/tools/sources/ref_link_review.py`:

```python
def apply_selected_ref_links(registry: dict, proposals: List[dict], selected_ids: set[str]) -> dict:
    proposal_map = {proposal["proposal_id"]: proposal for proposal in proposals if proposal.get("proposal_id")}
    records_by_id = {record.get("id", ""): record for record in registry.get("records", [])}
    applied_ids = []
    skipped_ids = []
    stale_ids = []
    for proposal_id in selected_ids:
        proposal = proposal_map.get(proposal_id)
        if not proposal:
            continue
        record = records_by_id.get(proposal.get("record_id", ""))
        if not record:
            continue
        current_ref_link = normalize_url(record.get("ref_link", ""))
        expected_current = normalize_url(proposal.get("current_ref_link", ""))
        if current_ref_link != expected_current:
            stale_ids.append(record["id"])
            continue
        if current_ref_link:
            skipped_ids.append(record["id"])
            continue
        record["ref_link"] = proposal["proposed_ref_link"]
        applied_ids.append(record["id"])
    return {
        "applied_ids": sorted(applied_ids),
        "skipped_ids": sorted(skipped_ids),
        "stale_ids": sorted(stale_ids),
    }
```

Also add `updated_at` / `updated_by` handling later from the UI endpoint, not in this pure helper.

- [ ] **Step 4: Run test to verify it passes**

Run: `python3 code/tools/sources/test_ref_link_review.py -v`
Expected: `OK`

- [ ] **Step 5: Commit**

```bash
git add code/tools/sources/ref_link_review.py code/tools/sources/test_ref_link_review.py
git commit -m "feat: add ref_link review apply helper"
```

## Chunk 2: Wire The Feature Into The Local UI And API

### Task 4: Add canonical config keys for the BibBase profile scan

**Files:**
- Modify: `code/tools/sources/common.py`
- Modify: `metadata/sources/sources.yaml`
- Review only: `metadata/sources/bibbase.local.json`
- Spec: `docs/superpowers/specs/2026-03-16-ref-link-review-design.md`

- [ ] **Step 1: Write the failing test**

Extend `code/tools/sources/test_ref_link_review.py` with a config-default expectation:

```python
    def test_default_registry_exposes_bibbase_review_config(self):
        from common import DEFAULT_REGISTRY
        config = DEFAULT_REGISTRY["config"]
        self.assertIn("bibbase_profile_source_url", config)
        self.assertIn("bibbase_timeout_seconds", config)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 code/tools/sources/test_ref_link_review.py -v`
Expected: `FAIL` because `common.DEFAULT_REGISTRY["config"]` does not yet expose these keys.

- [ ] **Step 3: Write minimal implementation**

Update `code/tools/sources/common.py`:

```python
                    ("bibbase_profile_source_url", ""),
                    ("bibbase_timeout_seconds", 20),
```

Then seed `metadata/sources/sources.yaml` with the current profile URL:

```json
"bibbase_profile_source_url": "https://bibbase.org/f/nKAPSyp34A9azBzJd/GCWealthProject_DataSourcesLibrary.bib",
"bibbase_timeout_seconds": 20,
```

Keep `online_bib_reference_url` unchanged for the existing file-level compare.

- [ ] **Step 4: Run test to verify it passes**

Run: `python3 code/tools/sources/test_ref_link_review.py -v`
Expected: `OK`

- [ ] **Step 5: Commit**

```bash
git add code/tools/sources/common.py metadata/sources/sources.yaml code/tools/sources/test_ref_link_review.py
git commit -m "feat: add canonical BibBase ref_link review config"
```

### Task 5: Lock in the standalone action and review panel markers in the inline UI

**Files:**
- Modify: `code/tools/sources/test_ui_local_html.py`
- Modify: `code/tools/sources/ui_local.py`
- Spec: `docs/superpowers/specs/2026-03-16-ref-link-review-design.md`

- [ ] **Step 1: Write the failing test**

Extend `code/tools/sources/test_ui_local_html.py` with the new workflow markers:

```python
    def test_ref_link_review_action_and_panel_hooks_exist(self):
        for marker in [
            "Review ref_link proposals",
            "ref_link_review_panel",
            "Apply selected",
            "Select all ready",
            "Dismiss selected",
            "/api/ref_link_review_scan",
            "/api/ref_link_review_apply",
        ]:
            self.assertIn(marker, self.html)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 code/tools/sources/test_ui_local_html.py -v`
Expected: `FAIL` because the existing inline HTML has no standalone review action or panel hooks.

- [ ] **Step 3: Write minimal implementation**

Update the Data Sources Actions section in `code/tools/sources/ui_local.py` so it includes a new always-available action row and a hidden inline panel container:

```html
  <div class='row'>
    <div class='step'>Step 3: Review full-registry ref_link proposals (optional)</div>
    <button class='secondary' onclick='scanRefLinkReview()'>Review ref_link proposals</button>
  </div>
  <div id='ref_link_review_panel' class='panel hidden'>
    <h3 class='section-heading'>Ref_link review</h3>
    <div id='ref_link_review_summary'></div>
    <div class='row actions-row'>
      <button class='secondary' onclick='selectAllReadyRefLinkReview()'>Select all ready</button>
      <button class='secondary' onclick='clearRefLinkReviewSelection()'>Clear selection</button>
      <button class='secondary' onclick='dismissSelectedRefLinkReview()'>Dismiss selected</button>
      <button class='warn' onclick='applySelectedRefLinkReview()'>Apply selected</button>
    </div>
    <div id='ref_link_review_groups'></div>
  </div>
```

Also add placeholder JS function shells for:

```javascript
async function scanRefLinkReview(){ /* wired in next task */ }
async function applySelectedRefLinkReview(){ /* wired in next task */ }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python3 code/tools/sources/test_ui_local_html.py -v`
Expected: `OK`

- [ ] **Step 5: Commit**

```bash
git add code/tools/sources/test_ui_local_html.py code/tools/sources/ui_local.py
git commit -m "feat: add ref_link review UI shell"
```

### Task 6: Add the scan/apply endpoints and client-side review state

**Files:**
- Modify: `code/tools/sources/ui_local.py`
- Modify: `code/tools/sources/ref_link_review.py`
- Modify: `code/tools/sources/test_ref_link_review.py`
- Spec: `docs/superpowers/specs/2026-03-16-ref-link-review-design.md`

- [ ] **Step 1: Write the failing test**

Add one more unit test in `code/tools/sources/test_ref_link_review.py` that exercises proposal ids plus selection filtering:

```python
    def test_scan_proposals_have_stable_ids_for_apply_roundtrip(self):
        registry = {
            "config": {"bib_output": "documentation/BibTeX files/GCWealthProject_DataSourcesLibrary.bib"},
            "records": [
                {
                    "id": "src-example",
                    "source": "Example2024",
                    "citekey": "Example2024",
                    "ref_link": "",
                    "link": "https://example.org/source",
                    "bib": {"title": "Example Title", "author": "Example, Eve", "year": "2024"},
                }
            ],
        }
        scan = self.mod.scan_registry_ref_links(
            registry,
            show_payload_text=make_show_payload("Example2024", "example-new-2024"),
            hosted_bib_text="@article{Example2024,}\\n",
            local_bib_text="@article{Example2024,}\\n",
        )
        proposal = scan["ready_to_apply"][0]
        out = self.mod.apply_selected_ref_links(registry, scan["ready_to_apply"], {proposal["proposal_id"]})
        self.assertEqual(out["applied_ids"], ["src-example"])
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 code/tools/sources/test_ref_link_review.py -v`
Expected: `FAIL` if proposal ids or apply filtering are still inconsistent with the scan output shape.

- [ ] **Step 3: Write minimal implementation**

Wire the server and client in `code/tools/sources/ui_local.py`:

1. Import the helper module near the top:

```python
from ref_link_review import apply_selected_ref_links, fetch_and_scan_registry_ref_links
```

2. Add a thin network wrapper inside `code/tools/sources/ref_link_review.py`:

```python
from urllib.error import URLError
from urllib.request import urlopen
from urllib.parse import urlencode
from pathlib import Path


def build_bibbase_show_url(profile_source_url: str) -> str:
    query = urlencode(
        {
            "bib": profile_source_url,
            "sort": "author_short",
            "theme": "default",
            "showSearch": "true",
            "urlLabel": "link",
            "titleLinks": "true",
            "jsonp": "1",
        }
    )
    return f"https://bibbase.org/show?{query}"


def fetch_and_scan_registry_ref_links(registry: dict) -> dict:
    cfg = registry.get("config", {}) or {}
    profile_source_url = normalize_whitespace(cfg.get("bibbase_profile_source_url", ""))
    timeout_seconds = int(cfg.get("bibbase_timeout_seconds", 20) or 20)
    if not profile_source_url:
        return {
            "ok": False,
            "status": "not_configured",
            "message": "bibbase_profile_source_url is not configured in metadata/sources/sources.yaml.",
        }
    local_bib_path = cfg.get("bib_output", "documentation/BibTeX files/GCWealthProject_DataSourcesLibrary.bib")
    local_bib_text = Path(local_bib_path).read_text(encoding="utf-8")
    hosted_bib_text = urlopen(profile_source_url, timeout=timeout_seconds).read().decode("utf-8")
    show_payload_text = urlopen(build_bibbase_show_url(profile_source_url), timeout=timeout_seconds).read().decode("utf-8")
    scan = scan_registry_ref_links(registry, show_payload_text, hosted_bib_text, local_bib_text)
    return {"ok": True, "status": "ok", **scan}
```

3. Add POST routes in `Handler.do_POST()`:

```python
            if self.path == "/api/ref_link_review_scan":
                reg = self.app.registry
                review = fetch_and_scan_registry_ref_links(reg)
                self._send_json(review if review.get("ok") else review, 200 if review.get("ok") else 400)
                return

            if self.path == "/api/ref_link_review_apply":
                data = self._read_json()
                reg = self.app.registry
                selected_ids = set(data.get("selected_proposal_ids", []))
                editor = normalize_whitespace(data.get("editor_name", ""))
                if not editor:
                    raise ValueError("editor_name is required")
                review = fetch_and_scan_registry_ref_links(reg)
                if not review.get("ok"):
                    raise ValueError(review.get("message", "Could not refresh ref_link proposals."))
                proposals = list(review.get("ready_to_apply", [])) + list(review.get("needs_review", []))
                tracked_paths = self.app.artifact_paths(reg)
                before = file_mtimes(tracked_paths)
                apply_out = apply_selected_ref_links(reg, proposals, selected_ids)
                for record_id in apply_out["applied_ids"]:
                    record = next(rec for rec in reg.get("records", []) if rec.get("id") == record_id)
                    record["updated_at"] = now_utc()
                    record["updated_by"] = editor
                    append_change(self.app.changelog_path, "edit", record_id, "Applied ref_link proposal from local UI review", editor)
                self.app.save(reg)
                from build_sources_artifacts import main as build_main
                ...
                refreshed = fetch_and_scan_registry_ref_links(reg)
                after = file_mtimes(tracked_paths)
                self._send_json(
                    {
                        "ok": True,
                        "operation": "ref_link_review_apply",
                        "applied_ids": apply_out["applied_ids"],
                        "skipped_ids": apply_out["skipped_ids"],
                        "stale_ids": apply_out["stale_ids"],
                        "modified_files": modified_paths(before, after),
                        "file_change_summary": build_file_change_summary(
                            modified_paths(before, after),
                            "edit",
                            ", ".join(apply_out["applied_ids"]),
                            ["ref_link"],
                            False,
                        ),
                        **refreshed,
                    }
                )
                return
```

4. Replace the placeholder JS with real client-side state and rendering:

```javascript
let refLinkReviewState = { ready_to_apply: [], needs_review: [], dismissed: [], selected: new Set() };

function hydrateRefLinkReviewState(review){
  const selected = new Set();
  for (const row of [...(review.ready_to_apply || []), ...(review.needs_review || [])]) {
    if (row.selected) selected.add(row.proposal_id);
  }
  return { ...review, dismissed: [], selected };
}

async function scanRefLinkReview(){
  const out = await req('/api/ref_link_review_scan', {});
  refLinkReviewState = hydrateRefLinkReviewState(out);
  renderRefLinkReviewPanel();
}

async function applySelectedRefLinkReview(){
  const selectedProposalIds = [...refLinkReviewState.selected];
  if (!selectedProposalIds.length) throw new Error('Select at least one proposal to apply.');
  const editorName = await ensureEditorName('apply selected ref_link proposals');
  const out = await req('/api/ref_link_review_apply', { selected_proposal_ids: selectedProposalIds, editor_name: editorName });
  refLinkReviewState = hydrateRefLinkReviewState(out);
  setStatusWithChecks(out, 'Ref_link proposals applied.', { includeOnlineCompare: true });
  renderRefLinkReviewPanel();
}
```

Keep dismissal client-side only:

```javascript
function dismissSelectedRefLinkReview(){
  ...
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python3 code/tools/sources/test_ref_link_review.py -v`
Expected: `OK`

- [ ] **Step 5: Commit**

```bash
git add code/tools/sources/ref_link_review.py code/tools/sources/test_ref_link_review.py code/tools/sources/ui_local.py
git commit -m "feat: wire standalone ref_link review scan and apply flow"
```

## Chunk 3: Document And Verify The Full Workflow

### Task 7: Document the standalone review flow in the source workflow guide

**Files:**
- Modify: `documentation/workflow/sources/source_registry.md`
- Spec: `docs/superpowers/specs/2026-03-16-ref-link-review-design.md`

- [ ] **Step 1: Write the docs change**

Update the Data Sources branch section in `documentation/workflow/sources/source_registry.md` so it documents:

- `Review ref_link proposals` as an independent action in the local UI
- that the scan covers the full Data Sources registry
- that safe proposals are preselected under `Ready to apply`
- that `Needs review` contains mismatches, ambiguity, or hosted-drift cases
- that `Apply selected` writes only `ref_link`, updates audit logs, and rebuilds artifacts

Concrete implementation target:

```markdown
- Optional review action: `Review ref_link proposals`
  - Available without saving first
  - Scans the full Data Sources registry against live BibBase entries
  - Groups results into `Ready to apply`, `Needs review`, and `Dismissed`
  - `Apply selected` updates only `ref_link`, appends audit entries, and rebuilds Data Sources artifacts
```

- [ ] **Step 2: Review the docs diff**

Run: `git diff -- documentation/workflow/sources/source_registry.md`
Expected: only the new review-flow guidance is added; no unrelated documentation churn.

- [ ] **Step 3: Commit**

```bash
git add documentation/workflow/sources/source_registry.md
git commit -m "docs: add ref_link review workflow guidance"
```

### Task 8: Run focused tests and one manual UI verification pass

**Files:**
- Modify as needed based on failures: `code/tools/sources/ref_link_review.py`
- Modify as needed based on failures: `code/tools/sources/test_ref_link_review.py`
- Modify as needed based on failures: `code/tools/sources/test_ui_local_html.py`
- Modify as needed based on failures: `code/tools/sources/ui_local.py`
- Spec: `docs/superpowers/specs/2026-03-16-ref-link-review-design.md`

- [ ] **Step 1: Run the helper unit tests**

Run: `python3 code/tools/sources/test_ref_link_review.py -v`
Expected: `OK`

- [ ] **Step 2: Run the inline HTML regression tests**

Run: `python3 code/tools/sources/test_ui_local_html.py -v`
Expected: `OK`

- [ ] **Step 3: Run a combined discovery pass for the sources tool tests**

Run: `python3 -m unittest discover -s code/tools/sources -p 'test*.py' -v`
Expected: all discovered tests pass with no import errors.

- [ ] **Step 4: Verify the standalone scan manually in the local UI**

Run: `python3 code/tools/sources/ui_local.py`
Expected: the server starts on `http://127.0.0.1:8765`

Manual checks in the browser:

- open the Data Sources branch without saving anything
- click `Review ref_link proposals`
- confirm the review panel opens and shows grouped results
- confirm high-confidence rows are preselected
- confirm `Needs review` rows are visible but unselected
- dismiss one proposal and verify it moves to `Dismissed` without changing files

- [ ] **Step 5: Verify apply behavior manually**

With the same UI session:

- click `Apply selected`
- confirm the single summary confirmation appears
- confirm only selected blank `ref_link` rows are updated
- confirm `metadata/sources/sources.yaml`, `metadata/sources/change_log.yaml`, `handmade_tables/dictionary.xlsx`, `documentation/BibTeX files/GCWealthProject_DataSourcesLibrary.bib`, and `documentation/BibTeX files/BothLibraries.bib` are modified
- rerun `Review ref_link proposals` and confirm applied rows disappear from `Ready to apply`

- [ ] **Step 6: Commit the verified implementation**

```bash
git status --short
git add code/tools/sources/ref_link_review.py \
        code/tools/sources/test_ref_link_review.py \
        code/tools/sources/test_ui_local_html.py \
        code/tools/sources/ui_local.py \
        code/tools/sources/common.py \
        metadata/sources/sources.yaml \
        documentation/workflow/sources/source_registry.md
git commit -m "feat: add standalone ref_link review workflow"
```

## Review Notes

- Keep the first implementation exact-key-first. Do not let title/year fallback expand beyond review-only suggestions.
- Do not auto-apply any non-high-confidence proposal.
- Do not overwrite any existing nonblank `ref_link` through the bulk apply path.
- Keep dismissal client-side/session-local only in version 1.
- If endpoint wiring starts to bloat `ui_local.py`, add small local helper functions, but avoid a broad refactor of the existing inline UI architecture.
