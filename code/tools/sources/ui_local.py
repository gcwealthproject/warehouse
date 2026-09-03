#!/usr/bin/env python3
"""Local web UI for adding/editing source records with guardrails.

Run:
  python3 code/tools/sources/ui_local.py
Then open http://127.0.0.1:8765
"""

import argparse
import contextlib
import hashlib
import io
import json
import re
import shlex
import shutil
import subprocess
import sys
import tempfile
import threading
import time
import uuid
import webbrowser
from difflib import unified_diff
from datetime import datetime
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Dict, List, Optional
from urllib.parse import parse_qs, unquote, urlparse
from urllib.request import Request, urlopen

from common import (
    BIB_FIELD_ORDER,
    load_json_yaml,
    load_registry,
    normalize_text,
    normalize_url,
    normalize_whitespace,
    parse_bib_entries,
    read_sources_sheet,
    save_registry,
    write_parsed_bib_entries,
)
from ref_link_review import apply_selected_ref_links, fetch_and_scan_registry_ref_links
from source_paths import (
    DEFAULT_ALIASES_PATH,
    DEFAULT_BOTH_BIB_PATH,
    DEFAULT_CHANGE_LOG_PATH,
    DEFAULT_DATA_BIB_PATH,
    DEFAULT_DICTIONARY_PATH,
    DEFAULT_REGISTRY_PATH,
    DEFAULT_WEALTH_BIB_PATH,
    DEFAULT_WEALTH_CHANGE_LOG_PATH,
    path_matches,
)

URL_RE = re.compile(r"^https?://", re.IGNORECASE)
DOI_RE = re.compile(r"^10\.\d{4,9}/[-._;()/:A-Z0-9]+$", re.IGNORECASE)
YEAR_RE = re.compile(r"^\d{4}$")
ONLINE_COMPARE_MAX_DIFF_LINES = 400
ONLINE_COMPARE_MAX_DIFF_CHARS = 60000
REPO_ROOT = Path(__file__).resolve().parents[3]
PORT_FALLBACK_MAX = 8785
RAW_BIB_KEY_RE = re.compile(r"@\w+\s*\{\s*([^,\n]+)\s*,", re.IGNORECASE)
WEALTH_ENTRY_TYPES = [
    "article",
    "book",
    "incollection",
    "inproceedings",
    "techreport",
    "misc",
    "unpublished",
    "mastersthesis",
    "phdthesis",
]
WEALTH_BIB_FIELDS = list(BIB_FIELD_ORDER)
DUPLICATE_ERROR_PREFIXES = ("Exact duplicate", "Dictionary duplicate", "Bib duplicate")
ARTIFACT_DUPLICATE_ERROR_PREFIXES = ("Dictionary duplicate", "Bib duplicate")
BULK_LABEL_FIELDS = [
    {"field": "section", "label": "Section"},
    {"field": "aggsource", "label": "Aggsource"},
    {"field": "data_type", "label": "Data type"},
    {"field": "inclusion_in_warehouse", "label": "Inclusion in warehouse"},
    {"field": "multigeo_reference", "label": "Multigeo reference"},
]
BULK_LABEL_FIELD_LABELS = {item["field"]: item["label"] for item in BULK_LABEL_FIELDS}
BULK_SECTION_KEYWORD_PREFIX = "Data Sources: "


def source_manager_url(host: str, port: int) -> str:
    return f"http://{host}:{port}"


def port_candidates(requested_port: int, max_port: int = PORT_FALLBACK_MAX) -> List[int]:
    if requested_port <= max_port:
        return list(range(requested_port, max_port + 1))
    return [requested_port]


def port_attempt_summary(requested_port: int, max_port: int = PORT_FALLBACK_MAX) -> str:
    if requested_port <= max_port:
        return f"{requested_port} through {max_port}"
    return str(requested_port)


def create_server_with_port_fallback(host: str, requested_port: int, handler_cls, max_port: int = PORT_FALLBACK_MAX):
    last_error = None
    for port in port_candidates(requested_port, max_port):
        try:
            return ThreadingHTTPServer((host, port), handler_cls), port
        except OSError as exc:
            last_error = exc
    if last_error is not None:
        raise OSError(
            f"could not bind {host} on port(s) {port_attempt_summary(requested_port, max_port)}"
        ) from last_error
    raise OSError(f"no candidate ports were available for {host}:{requested_port}")


def open_browser(url: str) -> bool:
    try:
        return bool(webbrowser.open(url, new=2))
    except Exception:
        return False


def now_utc() -> str:
    return datetime.utcnow().replace(microsecond=0).isoformat() + "Z"


def _data_bib_path(cfg: dict) -> Path:
    return Path(cfg.get("bib_output", DEFAULT_DATA_BIB_PATH))


def _dictionary_output_path(cfg: dict) -> Path:
    return Path(cfg.get("dictionary_output", DEFAULT_DICTIONARY_PATH))


def _wealth_bib_path(cfg: dict) -> Path:
    return Path(cfg.get("wealth_bib_input", DEFAULT_WEALTH_BIB_PATH))


def _both_bib_path(cfg: dict) -> Path:
    return Path(cfg.get("both_bib_output", DEFAULT_BOTH_BIB_PATH))


def _wealth_change_log_path(cfg: dict) -> Path:
    return Path(cfg.get("wealth_change_log", DEFAULT_WEALTH_CHANGE_LOG_PATH))


def _is_duplicate_error(msg: str) -> bool:
    return any(msg.startswith(prefix) for prefix in DUPLICATE_ERROR_PREFIXES)


def _is_artifact_duplicate_error(msg: str) -> bool:
    return any(msg.startswith(prefix) for prefix in ARTIFACT_DUPLICATE_ERROR_PREFIXES)


def _is_artifact_only_duplicate_failure(canonical_errors: List[str], artifact_errors: List[str]) -> bool:
    if canonical_errors or not artifact_errors:
        return False
    if any(not _is_duplicate_error(msg) for msg in artifact_errors):
        return False
    return all(_is_artifact_duplicate_error(msg) for msg in artifact_errors)


def _generated_data_artifact_paths(cfg: dict) -> List[Path]:
    return [_dictionary_output_path(cfg), _data_bib_path(cfg), _both_bib_path(cfg)]


def _stale_artifact_payload(registry: dict, registry_path: Path, artifact_errors: List[str]) -> dict:
    cfg = registry.get("config", {}) or {}
    stale_paths = [str(path) for path in _generated_data_artifact_paths(cfg)]
    unique_artifact_errors = sorted(set(artifact_errors))
    message = "Generated artifacts appear stale relative to the canonical registry. Rebuild artifacts, then retry."
    return {
        "error_code": "stale_artifacts",
        "message": message,
        "errors": [message],
        "artifact_duplicate_errors": unique_artifact_errors,
        "stale_artifact_paths": stale_paths,
        "rebuild_hint": f"python3 code/tools/sources/build_sources_artifacts.py --registry {registry_path}",
        "checks": [
            {
                "name": "Stale artifact guard",
                "passed": False,
                "detail": "Artifact duplicates were detected while canonical registry checks passed.",
            }
        ],
    }


def _read_bib_with_duplicate_detection(path: Path) -> dict:
    if not path.exists():
        raise FileNotFoundError(f"Bib artifact is missing: {path}")
    text = path.read_text(encoding="utf-8")
    parsed = parse_bib_entries(text)
    keys = [normalize_whitespace(k) for k in RAW_BIB_KEY_RE.findall(text)]
    counts: Dict[str, int] = {}
    for key in keys:
        counts[key] = counts.get(key, 0) + 1
    duplicates = sorted([k for k, v in counts.items() if v > 1], key=str.lower)
    entries: Dict[str, dict] = {}
    for key, entry in parsed.items():
        trimmed = normalize_whitespace(key)
        if trimmed:
            entries[trimmed] = entry
    return {"entries": entries, "duplicate_keys": duplicates}


def _wealth_entry_to_record(key: str, entry: dict) -> dict:
    fields = entry.get("fields", {}) or {}
    bib = {field: normalize_whitespace(str(fields.get(field, ""))) for field in WEALTH_BIB_FIELDS}
    extras = {}
    for field_name in sorted(fields.keys()):
        if field_name in WEALTH_BIB_FIELDS:
            continue
        val = normalize_whitespace(str(fields.get(field_name, "")))
        if val:
            extras[field_name] = val
    bib["extra_fields"] = extras
    return {
        "key": normalize_whitespace(key),
        "bib": {
            **bib,
            "entry_type": normalize_whitespace(str(entry.get("entry_type", ""))).lower() or "misc",
        },
    }


def _wealth_record_to_entry(record: dict) -> dict:
    key = normalize_whitespace(record.get("key", ""))
    bib = record.get("bib", {}) or {}
    entry_type = normalize_whitespace(str(bib.get("entry_type", ""))).lower() or "misc"
    fields: Dict[str, str] = {}
    for field in WEALTH_BIB_FIELDS:
        value = normalize_whitespace(str(bib.get(field, "")))
        if value:
            fields[field] = value
    extras = bib.get("extra_fields", {}) or {}
    for field_name, value in sorted(extras.items(), key=lambda x: str(x[0]).lower()):
        k = normalize_whitespace(str(field_name)).lower()
        v = normalize_whitespace(str(value))
        if not k or not v or k in fields:
            continue
        fields[k] = v
    return {"key": key, "entry_type": entry_type, "fields": fields}


def _wealth_search_rows(entries: Dict[str, dict]) -> List[dict]:
    rows: List[dict] = []
    for key in sorted(entries.keys(), key=str.lower):
        rec = _wealth_entry_to_record(key, entries[key])
        bib = rec.get("bib", {}) or {}
        rows.append(
            {
                "key": rec.get("key", ""),
                "entry_type": bib.get("entry_type", ""),
                "title": bib.get("title", ""),
                "author": bib.get("author", ""),
                "year": bib.get("year", ""),
            }
        )
    return rows


def _wealth_candidate_from_payload(payload: dict) -> dict:
    record = payload.get("record", {}) or {}
    bib = record.get("bib", {}) or {}
    bib_clean = {field: normalize_whitespace(str(bib.get(field, ""))) for field in WEALTH_BIB_FIELDS}
    entry_type = normalize_whitespace(str(bib.get("entry_type", ""))).lower()
    if entry_type:
        bib_clean["entry_type"] = entry_type
    else:
        bib_clean["entry_type"] = ""
    extra_fields = bib.get("extra_fields", {}) or {}
    bib_clean["extra_fields"] = {
        normalize_whitespace(str(k)).lower(): normalize_whitespace(str(v))
        for k, v in extra_fields.items()
        if normalize_whitespace(str(k)) and normalize_whitespace(str(v))
    }
    return {
        "key": normalize_whitespace(record.get("key", "")),
        "bib": bib_clean,
    }


def _validate_wealth_candidate(
    candidate: dict,
    mode: str,
    target: str,
    wealth_entries: Dict[str, dict],
    data_keys: set,
    duplicate_keys_in_file: List[str],
) -> Dict[str, List[str]]:
    errors: List[str] = []
    warnings: List[str] = []
    checks: List[dict] = []
    target_norm = normalize_whitespace(target)

    if duplicate_keys_in_file:
        errors.append(f"Reference library contains duplicate keys: {', '.join(duplicate_keys_in_file)}")
    checks.append(
        {
            "name": "Current file integrity",
            "passed": len(duplicate_keys_in_file) == 0,
            "detail": "No duplicate keys in reference library"
            if not duplicate_keys_in_file
            else f"Duplicate keys found: {', '.join(duplicate_keys_in_file)}",
        }
    )

    key = normalize_whitespace(candidate.get("key", ""))
    bib = candidate.get("bib", {}) or {}
    missing_required = []
    if not key:
        missing_required.append("key")
    for field in ["entry_type", "title", "author", "year"]:
        if not normalize_whitespace(str(bib.get(field, ""))):
            missing_required.append(f"bib.{field}")
    if missing_required:
        errors.extend([f"Missing required field: {name}" for name in missing_required])
    checks.append(
        {
            "name": "Required fields",
            "passed": len(missing_required) == 0,
            "detail": "All required fields present" if not missing_required else f"Missing: {', '.join(missing_required)}",
        }
    )

    year = normalize_whitespace(str(bib.get("year", "")))
    if year and not YEAR_RE.match(year):
        errors.append(f"Year must be YYYY: {year}")
    checks.append(
        {
            "name": "Year format",
            "passed": bool(year) and YEAR_RE.match(year) is not None,
            "detail": "Year uses YYYY" if bool(year) and YEAR_RE.match(year) is not None else "Year must be YYYY",
        }
    )

    url = normalize_whitespace(str(bib.get("url", "")))
    doi = normalize_whitespace(str(bib.get("doi", "")))
    if url and not URL_RE.match(url):
        errors.append(f"Invalid URL in bib.url: {url}")
    checks.append(
        {
            "name": "URL format",
            "passed": (not url) or URL_RE.match(url) is not None,
            "detail": "URL is empty or valid pattern" if (not url or URL_RE.match(url) is not None) else "Invalid bib.url",
        }
    )
    if doi and not DOI_RE.match(doi):
        warnings.append(f"DOI format looks unusual: {doi}")

    if mode not in {"add", "edit"}:
        errors.append("mode must be add or edit")
    if mode == "edit":
        if not target_norm:
            errors.append("Edit target is required in edit mode")
        elif target_norm not in wealth_entries:
            errors.append(f"Edit target not found: {target_norm}")
    checks.append(
        {
            "name": "Edit target resolution",
            "passed": mode == "add" or (target_norm in wealth_entries),
            "detail": "Not applicable for add mode"
            if mode == "add"
            else (f"Resolved to {target_norm}" if target_norm in wealth_entries else "Target not found"),
        }
    )

    has_wealth_dup = False
    if mode == "add":
        has_wealth_dup = bool(key and key in wealth_entries)
    elif mode == "edit":
        has_wealth_dup = bool(key and key != target_norm and key in wealth_entries)
    if has_wealth_dup:
        errors.append(f"Duplicate key: {key}")
    checks.append(
        {
            "name": "Key uniqueness",
            "passed": bool(key) and not has_wealth_dup,
            "detail": "No duplicate key detected" if (bool(key) and not has_wealth_dup) else "Duplicate key detected",
        }
    )

    if key and key in data_keys and (mode == "add" or key != target_norm):
        errors.append(f"Key conflicts with DataSources library: {key}. Choose a different key.")
    checks.append(
        {
            "name": "Cross-library key collision",
            "passed": not (key and key in data_keys and (mode == "add" or key != target_norm)),
            "detail": "No forbidden key collision with DataSources"
            if not (key and key in data_keys and (mode == "add" or key != target_norm))
            else "Collision detected",
        }
    )

    return {"errors": sorted(set(errors)), "warnings": sorted(set(warnings)), "checks": checks}


def _append_wealth_change(changelog_path: Path, op: str, rec_id: str, reason: str, actor: str) -> None:
    data = load_json_yaml(changelog_path) or {"changes": []}
    data.setdefault("changes", []).append(
        {
            "operation": op,
            "record_id": rec_id,
            "reason": reason,
            "actor": actor,
            "issue_number": "local-ui",
            "library": "wealth_research",
            "updated_at": now_utc(),
        }
    )
    changelog_path.parent.mkdir(parents=True, exist_ok=True)
    changelog_path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def _rebuild_both_bib(cfg: dict) -> int:
    from build_sources_artifacts import merge_bib_libraries  # pylint: disable=import-outside-toplevel

    return merge_bib_libraries(_data_bib_path(cfg), _wealth_bib_path(cfg), _both_bib_path(cfg))


def append_change(changelog_path: Path, op: str, rec_id: str, reason: str, actor: str) -> None:
    data = load_json_yaml(changelog_path) or {"changes": []}
    data.setdefault("changes", []).append(
        {
            "operation": op,
            "record_id": rec_id,
            "reason": reason,
            "actor": actor,
            "issue_number": "local-ui",
            "updated_at": now_utc(),
        }
    )
    changelog_path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def append_alias(aliases_path: Path, alias_type: str, old: str, new: str, reason: str) -> None:
    if not old or not new or old == new:
        return
    data = load_json_yaml(aliases_path) or {"aliases": []}
    data.setdefault("aliases", []).append(
        {
            "type": alias_type,
            "old": old,
            "new": new,
            "reason": reason,
            "updated_at": now_utc(),
        }
    )
    aliases_path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def _bulk_label_field(field: str) -> str:
    value = normalize_whitespace(str(field))
    if value not in BULK_LABEL_FIELD_LABELS:
        allowed = ", ".join(item["field"] for item in BULK_LABEL_FIELDS)
        raise ValueError(f"field must be one of: {allowed}")
    return value


def _bulk_label_values(records: List[dict]) -> Dict[str, List[dict]]:
    out: Dict[str, List[dict]] = {}
    for field in BULK_LABEL_FIELD_LABELS:
        counts: Dict[str, int] = {}
        for rec in records:
            value = normalize_whitespace(str(rec.get(field, "")))
            if value:
                counts[value] = counts.get(value, 0) + 1
        out[field] = [
            {"value": value, "count": count}
            for value, count in sorted(counts.items(), key=lambda item: item[0].lower())
        ]
    return out


def _bulk_section_keyword(label: str) -> str:
    return f"{BULK_SECTION_KEYWORD_PREFIX}{label}"


def _bulk_label_keyword_preview(rec: dict, field: str, old_label: str, new_label: str) -> dict:
    if field != "section":
        return {
            "keyword_mirror_update": False,
            "keywords_before": "",
            "keywords_after": "",
        }
    bib = rec.get("bib", {}) or {}
    keywords = normalize_whitespace(str(bib.get("keywords", "")))
    old_keywords = _bulk_section_keyword(old_label)
    if keywords != old_keywords:
        return {
            "keyword_mirror_update": False,
            "keywords_before": keywords,
            "keywords_after": keywords,
        }
    return {
        "keyword_mirror_update": True,
        "keywords_before": keywords,
        "keywords_after": _bulk_section_keyword(new_label),
    }


def _bulk_label_preview_row(rec: dict, field: str, old_label: str, new_label: str) -> dict:
    summary = record_summary(rec)
    keyword_preview = _bulk_label_keyword_preview(rec, field, old_label, new_label)
    return {
        **summary,
        "label_before": old_label,
        "label_after": new_label,
        **keyword_preview,
    }


def bulk_label_preview(registry: dict, field: str, old_label: str, new_label: str) -> dict:
    label_field = _bulk_label_field(field)
    old_value = normalize_whitespace(str(old_label))
    new_value = normalize_whitespace(str(new_label))
    if not old_value:
        raise ValueError("old_label is required")
    if not new_value:
        raise ValueError("new_label is required")
    if old_value == new_value:
        raise ValueError("new_label must be different from old_label")

    records = registry.get("records", [])
    rows = [
        _bulk_label_preview_row(rec, label_field, old_value, new_value)
        for rec in records
        if normalize_whitespace(str(rec.get(label_field, ""))) == old_value
    ]
    keyword_updates = sum(1 for row in rows if row.get("keyword_mirror_update"))
    return {
        "ok": True,
        "operation": "bulk_label_preview",
        "field": label_field,
        "field_label": BULK_LABEL_FIELD_LABELS[label_field],
        "old_label": old_value,
        "new_label": new_value,
        "total_matches": len(rows),
        "keyword_mirror_updates": keyword_updates,
        "records": rows,
        "message": f"Preview found {len(rows)} matching record(s).",
    }


def _selected_bulk_label_records(records: List[dict], field: str, old_label: str, record_ids: List[str]) -> List[dict]:
    requested_ids = []
    seen = set()
    for value in record_ids:
        record_id = normalize_whitespace(str(value))
        if record_id and record_id not in seen:
            requested_ids.append(record_id)
            seen.add(record_id)
    if not requested_ids:
        raise ValueError("record_ids is required")

    by_id = {normalize_whitespace(str(rec.get("id", ""))): rec for rec in records if normalize_whitespace(str(rec.get("id", "")))}
    stale_ids = []
    selected = []
    for record_id in requested_ids:
        rec = by_id.get(record_id)
        if not rec or normalize_whitespace(str(rec.get(field, ""))) != old_label:
            stale_ids.append(record_id)
            continue
        selected.append(rec)
    if stale_ids:
        raise ValueError(
            "Bulk label selection is stale for record(s): "
            + ", ".join(stale_ids)
            + ". Refresh the preview and try again."
        )
    return selected


def apply_bulk_label_update(registry: dict, payload: dict, changelog_path: Path) -> dict:
    field = _bulk_label_field(payload.get("field", ""))
    old_label = normalize_whitespace(str(payload.get("old_label", "")))
    new_label = normalize_whitespace(str(payload.get("new_label", "")))
    editor = normalize_whitespace(str(payload.get("editor_name", "")))
    if not old_label:
        raise ValueError("old_label is required")
    if not new_label:
        raise ValueError("new_label is required")
    if old_label == new_label:
        raise ValueError("new_label must be different from old_label")
    if not editor:
        raise ValueError("editor_name is required")

    records = registry.get("records", [])
    selected = _selected_bulk_label_records(records, field, old_label, payload.get("record_ids", []) or [])
    timestamp = now_utc()
    keyword_updates = 0
    changed_ids = []
    for rec in selected:
        rec[field] = new_label
        if field == "section":
            bib = rec.get("bib")
            if not isinstance(bib, dict):
                bib = {}
                rec["bib"] = bib
            if normalize_whitespace(str(bib.get("keywords", ""))) == _bulk_section_keyword(old_label):
                bib["keywords"] = _bulk_section_keyword(new_label)
                keyword_updates += 1
        rec["updated_at"] = timestamp
        rec["updated_by"] = editor
        changed_ids.append(normalize_whitespace(str(rec.get("id", ""))))

    changed_fields = [field]
    if keyword_updates:
        changed_fields.append("bib.keywords")
    record_id = f"{field}:{old_label}->{new_label}"
    reason = (
        f"Bulk label update via maintenance: {BULK_LABEL_FIELD_LABELS[field]} "
        f"'{old_label}' -> '{new_label}' ({len(changed_ids)} records)"
    )
    append_change(changelog_path, "bulk_label_update", record_id, reason, editor)
    return {
        "status": "ok",
        "operation": "bulk_label_update",
        "field": field,
        "field_label": BULK_LABEL_FIELD_LABELS[field],
        "old_label": old_label,
        "new_label": new_label,
        "record_id": record_id,
        "record_ids": changed_ids,
        "changed_fields": changed_fields,
        "keyword_mirror_updates": keyword_updates,
        "warnings": [],
        "errors": [],
        "checks": [
            {
                "name": "Bulk label selection",
                "passed": True,
                "detail": f"{len(changed_ids)} selected record(s) still matched the old label.",
            }
        ],
        "message": f"Updated {len(changed_ids)} record(s).",
    }


def suggested_options(records: List[dict]) -> Dict[str, object]:
    def uniq(key: str) -> List[str]:
        return sorted({normalize_whitespace(str(r.get(key, ""))) for r in records if normalize_whitespace(str(r.get(key, "")))})

    targets = sorted({normalize_whitespace(str(r.get("source", ""))) for r in records if normalize_whitespace(str(r.get("source", "")))})
    data_search_rows = []
    for rec in records:
        bib = rec.get("bib", {}) or {}
        data_search_rows.append(
            {
                "citekey": normalize_whitespace(str(rec.get("citekey", ""))),
                "source": normalize_whitespace(str(rec.get("source", ""))),
                "legend": normalize_whitespace(str(rec.get("legend", ""))),
                "year": normalize_whitespace(str(bib.get("year", ""))),
                "title": normalize_whitespace(str(bib.get("title", ""))),
                "author": normalize_whitespace(str(bib.get("author", ""))),
            }
        )
    data_search_rows = sorted(data_search_rows, key=lambda x: (x.get("citekey", "").lower(), x.get("source", "").lower()))
    return {
        "section": uniq("section"),
        "aggsource": uniq("aggsource"),
        "data_type": uniq("data_type"),
        "inclusion_in_warehouse": uniq("inclusion_in_warehouse"),
        "multigeo_reference": uniq("multigeo_reference"),
        "bulk_label_fields": BULK_LABEL_FIELDS,
        "bulk_label_values": _bulk_label_values(records),
        "targets": targets,
        "data_search_rows": data_search_rows,
    }


def find_target(records: List[dict], target: str) -> List[dict]:
    t = normalize_whitespace(target)
    hits = []
    for r in records:
        if r.get("id", "") == t or r.get("source", "") == t or r.get("citekey", "") == t:
            hits.append(r)
    return hits


def record_summary(rec: dict) -> dict:
    bib = rec.get("bib", {}) or {}
    return {
        "id": normalize_whitespace(str(rec.get("id", ""))),
        "source": normalize_whitespace(str(rec.get("source", ""))),
        "citekey": normalize_whitespace(str(rec.get("citekey", ""))),
        "legend": normalize_whitespace(str(rec.get("legend", ""))),
        "year": normalize_whitespace(str(bib.get("year", ""))),
        "title": normalize_whitespace(str(bib.get("title", ""))),
        "shared_citekey_group": normalize_whitespace(str(rec.get("shared_citekey_group", ""))),
        "shared_citekey_note": normalize_whitespace(str(rec.get("shared_citekey_note", ""))),
    }


def target_skip_values(records: List[dict], target: str) -> set:
    values = {normalize_whitespace(target)}
    hits = find_target(records, target)
    if len(hits) == 1:
        rec = hits[0]
        values.update(
            {
                normalize_whitespace(str(rec.get("id", ""))),
                normalize_whitespace(str(rec.get("source", ""))),
                normalize_whitespace(str(rec.get("citekey", ""))),
            }
        )
    return {value for value in values if value}


def shared_citekey_group(rec: dict) -> str:
    return normalize_whitespace(str(rec.get("shared_citekey_group", "")))


def shared_citekey_allowed(candidate: dict, rec: dict) -> bool:
    c_group = shared_citekey_group(candidate)
    r_group = shared_citekey_group(rec)
    return bool(c_group and r_group and c_group == r_group)


def validate_candidate(records: List[dict], candidate: dict, mode: str, target_id: str = "") -> Dict[str, List[str]]:
    errors: List[str] = []
    warnings: List[str] = []
    checks: List[dict] = []

    required = ["section", "aggsource", "legend", "source", "citekey", "link"]
    missing_required = [k for k in required if not normalize_whitespace(str(candidate.get(k, "")))]
    if missing_required:
        for k in missing_required:
            errors.append(f"Missing required field: {k}")
    checks.append({
        "name": "Required core fields",
        "passed": len(missing_required) == 0,
        "detail": "All required fields present" if not missing_required else f"Missing: {', '.join(missing_required)}",
    })

    source_matches_citekey = candidate.get("source", "") == candidate.get("citekey", "")
    if not source_matches_citekey:
        if mode == "add":
            errors.append("source and citekey must be the same value for new records")
        else:
            warnings.append("source and citekey differ; preserving legacy bibliography key")
    checks.append({
        "name": "Source/Citekey consistency",
        "passed": source_matches_citekey or mode == "edit",
        "detail": "source equals citekey" if source_matches_citekey else "legacy source/citekey mismatch preserved",
    })

    bib = candidate.get("bib", {}) or {}
    missing_bib_required = [k for k in ["entry_type", "title", "author", "year"] if not normalize_whitespace(str(bib.get(k, "")))]
    if missing_bib_required:
        for k in missing_bib_required:
            errors.append(f"Missing required bib field: {k}")
    checks.append({
        "name": "Required BibTeX fields",
        "passed": len(missing_bib_required) == 0,
        "detail": "Bib required fields present" if not missing_bib_required else f"Missing: {', '.join(missing_bib_required)}",
    })

    link = normalize_whitespace(candidate.get("link", ""))
    ref_link = normalize_whitespace(candidate.get("ref_link", ""))
    bib_url = normalize_whitespace(str(bib.get("url", "")))
    doi = normalize_whitespace(str(bib.get("doi", "")))
    year = normalize_whitespace(str(bib.get("year", "")))

    bad_urls: List[str] = []
    if link and not URL_RE.match(link):
        bad_urls.append(f"link={link}")
        errors.append(f"Invalid URL in link: {link}")
    if ref_link and not URL_RE.match(ref_link):
        bad_urls.append(f"ref_link={ref_link}")
        errors.append(f"Invalid URL in ref_link: {ref_link}")
    if bib_url and not URL_RE.match(bib_url):
        bad_urls.append(f"bib.url={bib_url}")
        errors.append(f"Invalid URL in bib.url: {bib_url}")
    if not link and not bib_url:
        errors.append("Missing URL: provide at least Link (or bib.url)")
    checks.append({
        "name": "URL checks",
        "passed": (not bad_urls) and bool(link or bib_url),
        "detail": "URL fields valid" if (not bad_urls) and bool(link or bib_url) else ("; ".join(bad_urls) if bad_urls else "Missing link/bib.url"),
    })
    if doi and not DOI_RE.match(doi):
        warnings.append(f"DOI format looks unusual: {doi}")
    checks.append({
        "name": "DOI format",
        "passed": not doi or DOI_RE.match(doi) is not None,
        "detail": "DOI is empty or valid pattern" if (not doi or DOI_RE.match(doi) is not None) else "Unusual DOI format (warning)",
    })
    if year and not YEAR_RE.match(year):
        errors.append(f"Year must be YYYY: {year}")
    checks.append({
        "name": "Year format",
        "passed": bool(year) and YEAR_RE.match(year) is not None,
        "detail": "Year uses YYYY" if bool(year) and YEAR_RE.match(year) is not None else "Year must be YYYY",
    })

    c_source = normalize_whitespace(candidate.get("source", ""))
    c_citekey = normalize_whitespace(candidate.get("citekey", ""))
    c_url = normalize_url(bib_url or link)
    c_title = normalize_text(str(bib.get("title", "")))
    c_year = normalize_whitespace(str(bib.get("year", "")))

    duplicate_errors: List[str] = []
    for rec in records:
        rid = rec.get("id", "")
        if mode == "edit" and target_id and rid == target_id:
            continue

        r_source = normalize_whitespace(rec.get("source", ""))
        r_citekey = normalize_whitespace(rec.get("citekey", ""))
        r_url = normalize_url(str((rec.get("bib", {}) or {}).get("url", "") or rec.get("link", "")))
        r_title = normalize_text(str((rec.get("bib", {}) or {}).get("title", "")))
        r_year = normalize_whitespace(str((rec.get("bib", {}) or {}).get("year", "")))

        if c_source and c_source == r_source:
            msg = f"Exact duplicate source found: {c_source} (record {rid})"
            duplicate_errors.append(msg)
            errors.append(msg)
        if c_citekey and c_citekey == r_citekey:
            if shared_citekey_allowed(candidate, rec):
                warnings.append(f"Shared citekey marked intentional: {c_citekey} (record {rid})")
            else:
                msg = f"Exact duplicate citekey found: {c_citekey} (record {rid})"
                duplicate_errors.append(msg)
                errors.append(msg)
        if c_url and c_url == r_url:
            if shared_citekey_allowed(candidate, rec) and c_citekey and c_citekey == r_citekey:
                warnings.append(f"Shared citekey also shares URL: {c_url} (record {rid})")
            else:
                msg = f"Exact duplicate URL found: {c_url} (record {rid})"
                duplicate_errors.append(msg)
                errors.append(msg)
        if c_title and c_year and c_title == r_title and c_year == r_year:
            if shared_citekey_allowed(candidate, rec) and c_citekey and c_citekey == r_citekey:
                warnings.append(f"Shared citekey also shares title/year: ({c_title}, {c_year}) (record {rid})")
            else:
                msg = f"Exact duplicate (title, year) found: ({c_title}, {c_year}) (record {rid})"
                duplicate_errors.append(msg)
                errors.append(msg)
    checks.append({
        "name": "Exact duplicate checks",
        "passed": len(duplicate_errors) == 0,
        "detail": "No exact duplicates found" if not duplicate_errors else "; ".join(sorted(set(duplicate_errors))),
    })

    return {"errors": sorted(set(errors)), "warnings": sorted(set(warnings)), "checks": checks}


def validate_candidate_against_artifacts(registry: dict, candidate: dict, mode: str, target: str = "") -> Dict[str, List[str]]:
    errors: List[str] = []
    warnings: List[str] = []
    checks: List[dict] = []
    cfg = registry.get("config", {}) or {}
    dictionary_path = _dictionary_output_path(cfg)
    bib_path = Path(cfg.get("bib_output", "documentation/BibTeX files/GCWealthProject_DataSourcesLibrary.bib"))
    target_norm = normalize_whitespace(target)
    skip_values = target_skip_values(registry.get("records", []), target) if mode == "edit" else set()

    c_source = normalize_whitespace(candidate.get("source", ""))
    c_citekey = normalize_whitespace(candidate.get("citekey", ""))
    for rec in registry.get("records", []):
        if c_citekey and c_citekey == normalize_whitespace(str(rec.get("citekey", ""))) and shared_citekey_allowed(candidate, rec):
            skip_values.update(
                {
                    normalize_whitespace(str(rec.get("id", ""))),
                    normalize_whitespace(str(rec.get("source", ""))),
                    normalize_whitespace(str(rec.get("citekey", ""))),
                }
            )
    skip_values = {value for value in skip_values if value}
    cbib = candidate.get("bib", {}) or {}
    c_url = normalize_url(str(cbib.get("url", "") or candidate.get("link", "")))
    c_title = normalize_text(str(cbib.get("title", "")))
    c_year = normalize_whitespace(str(cbib.get("year", "")))

    dict_checked = False
    dict_errors: List[str] = []
    if dictionary_path.exists():
        try:
            rows = read_sources_sheet(dictionary_path)
            dict_checked = True
            for row in rows:
                r_source = normalize_whitespace(str(row.get("Source", "")))
                r_citekey = normalize_whitespace(str(row.get("Citekey", "")))
                r_link = normalize_url(str(row.get("Link", "")))
                if mode == "edit" and (
                    (target_norm and (r_source == target_norm or r_citekey == target_norm))
                    or r_source in skip_values
                    or r_citekey in skip_values
                ):
                    continue
                if c_source and c_source == r_source:
                    dict_errors.append(f"Dictionary duplicate Source: {c_source}")
                if c_citekey and c_citekey == r_citekey:
                    dict_errors.append(f"Dictionary duplicate Citekey: {c_citekey}")
                if c_url and c_url == r_link:
                    dict_errors.append(f"Dictionary duplicate Link URL: {c_url}")
            errors.extend(dict_errors)
        except Exception as exc:  # pylint: disable=broad-except
            warnings.append(f"Dictionary check could not run: {exc}")
    else:
        warnings.append(f"Dictionary artifact not found: {dictionary_path}")
    checks.append({
        "name": "Dictionary artifact duplicate checks",
        "passed": dict_checked and len(dict_errors) == 0,
        "detail": "No exact duplicates in dictionary.xlsx Sources sheet"
        if dict_checked and not dict_errors
        else ("; ".join(sorted(set(dict_errors))) if dict_errors else "Dictionary check skipped"),
    })

    bib_checked = False
    bib_errors: List[str] = []
    if bib_path.exists():
        try:
            entries = parse_bib_entries(bib_path.read_text(encoding="utf-8"))
            bib_checked = True
            for key, entry in entries.items():
                k_norm = normalize_whitespace(key)
                if mode == "edit" and ((target_norm and k_norm == target_norm) or k_norm in skip_values):
                    continue
                if c_citekey and c_citekey == k_norm:
                    bib_errors.append(f"Bib duplicate key: {c_citekey}")
                fields = entry.get("fields", {}) or {}
                e_url = normalize_url(str(fields.get("url", "")))
                e_title = normalize_text(str(fields.get("title", "")))
                e_year = normalize_whitespace(str(fields.get("year", "")))
                if c_url and c_url == e_url:
                    bib_errors.append(f"Bib duplicate URL: {c_url} (key {key})")
                if c_title and c_year and c_title == e_title and c_year == e_year:
                    bib_errors.append(f"Bib duplicate (title, year): ({c_title}, {c_year}) (key {key})")
            errors.extend(bib_errors)
        except Exception as exc:  # pylint: disable=broad-except
            warnings.append(f"Bib artifact check could not run: {exc}")
    else:
        warnings.append(f"Bib artifact not found: {bib_path}")
    checks.append({
        "name": "Bib artifact duplicate checks",
        "passed": bib_checked and len(bib_errors) == 0,
        "detail": "No exact duplicates in generated .bib"
        if bib_checked and not bib_errors
        else ("; ".join(sorted(set(bib_errors))) if bib_errors else "Bib check skipped"),
    })

    return {"errors": sorted(set(errors)), "warnings": sorted(set(warnings)), "checks": checks}


def _run_build_sources_artifacts(
    registry_path: Path,
    *,
    dictionary_template: Optional[Path] = None,
    dictionary_output: Optional[Path] = None,
    bib_output: Optional[Path] = None,
    wealth_bib_input: Optional[Path] = None,
    both_bib_output: Optional[Path] = None,
    quiet: bool = False,
) -> None:
    from build_sources_artifacts import main as build_main  # pylint: disable=import-outside-toplevel

    argv = ["build_sources_artifacts.py", "--registry", str(registry_path)]
    optional_args = [
        ("--dictionary-template", dictionary_template),
        ("--dictionary-output", dictionary_output),
        ("--bib-output", bib_output),
        ("--wealth-bib-input", wealth_bib_input),
        ("--both-bib-output", both_bib_output),
    ]
    for flag, path_value in optional_args:
        if path_value is not None:
            argv.extend([flag, str(path_value)])

    argv_orig = sys.argv[:]
    try:
        sys.argv = argv
        if quiet:
            with contextlib.redirect_stdout(io.StringIO()):
                build_main()
        else:
            build_main()
    finally:
        sys.argv = argv_orig


def generated_artifact_drift(registry_path: Path, cfg: dict) -> dict:
    dictionary_path = _dictionary_output_path(cfg)
    data_bib_path = _data_bib_path(cfg)
    wealth_bib_path = _wealth_bib_path(cfg)
    both_bib_path = _both_bib_path(cfg)
    stale_paths: List[str] = []
    errors: List[str] = []

    with tempfile.TemporaryDirectory() as tmpdir:
        tmp_root = Path(tmpdir)
        tmp_dict = tmp_root / "dictionary.xlsx"
        tmp_data_bib = tmp_root / "data.bib"
        tmp_both_bib = tmp_root / "both.bib"
        try:
            if not dictionary_path.exists():
                errors.append(f"Dictionary artifact missing: {dictionary_path}")
                return {"stale_artifact_paths": [str(dictionary_path)], "errors": errors}
            shutil.copy2(dictionary_path, tmp_dict)
            _run_build_sources_artifacts(
                registry_path,
                dictionary_template=tmp_dict,
                dictionary_output=tmp_dict,
                bib_output=tmp_data_bib,
                wealth_bib_input=wealth_bib_path,
                both_bib_output=tmp_both_bib,
                quiet=True,
            )

            if not data_bib_path.exists() or data_bib_path.read_text(encoding="utf-8") != tmp_data_bib.read_text(encoding="utf-8"):
                stale_paths.append(str(data_bib_path))
            if not both_bib_path.exists() or both_bib_path.read_text(encoding="utf-8") != tmp_both_bib.read_text(encoding="utf-8"):
                stale_paths.append(str(both_bib_path))
            try:
                current_rows = read_sources_sheet(dictionary_path)
                rebuilt_rows = read_sources_sheet(tmp_dict)
                if json.dumps(current_rows, sort_keys=True) != json.dumps(rebuilt_rows, sort_keys=True):
                    stale_paths.append(str(dictionary_path))
            except Exception as exc:  # pylint: disable=broad-except
                errors.append(f"Dictionary artifact check could not run: {exc}")
        except Exception as exc:  # pylint: disable=broad-except
            errors.append(f"Generated artifact drift check failed: {exc}")

    return {"stale_artifact_paths": sorted(set(stale_paths)), "errors": errors}


def build_maintenance_health(registry: dict, registry_path: Path) -> dict:
    records = registry.get("records", [])
    cfg = registry.get("config", {}) or {}
    issues: List[dict] = []

    for rec in records:
        source = normalize_whitespace(str(rec.get("source", "")))
        citekey = normalize_whitespace(str(rec.get("citekey", "")))
        if source and citekey and source != citekey:
            issues.append(
                {
                    "type": "source_citekey_mismatch",
                    "severity": "needs_review",
                    "record": record_summary(rec),
                    "message": f"Source {source} uses bibliography citekey {citekey}.",
                }
            )

    by_citekey: Dict[str, List[dict]] = {}
    for rec in records:
        citekey = normalize_whitespace(str(rec.get("citekey", "")))
        if citekey:
            by_citekey.setdefault(citekey, []).append(rec)
    for citekey, grouped in sorted(by_citekey.items(), key=lambda item: item[0].lower()):
        if len(grouped) <= 1:
            continue
        groups = {shared_citekey_group(rec) for rec in grouped}
        intentional = len(groups) == 1 and "" not in groups
        issues.append(
            {
                "type": "duplicate_citekey",
                "severity": "intentional" if intentional else "needs_review",
                "citekey": citekey,
                "records": [record_summary(rec) for rec in grouped],
                "message": (
                    f"Shared citekey {citekey} is marked intentional."
                    if intentional
                    else f"Citekey {citekey} is used by {len(grouped)} records and needs review."
                ),
            }
        )

    for label, path in [("Data Sources", _data_bib_path(cfg)), ("Combined", _both_bib_path(cfg))]:
        try:
            blob = _read_bib_with_duplicate_detection(path)
            duplicate_keys = blob.get("duplicate_keys", [])
            if duplicate_keys:
                issues.append(
                    {
                        "type": "artifact_duplicate_keys",
                        "severity": "needs_rebuild",
                        "artifact": str(path),
                        "library_label": label,
                        "duplicate_keys": duplicate_keys,
                        "message": f"{label} BibTeX artifact contains duplicate key(s): {', '.join(duplicate_keys)}.",
                    }
                )
        except Exception as exc:  # pylint: disable=broad-except
            issues.append(
                {
                    "type": "artifact_check_failed",
                    "severity": "needs_review",
                    "artifact": str(path),
                    "message": f"Could not inspect {label} BibTeX artifact: {exc}",
                }
            )

    drift = generated_artifact_drift(registry_path, cfg)
    if drift.get("stale_artifact_paths"):
        issues.append(
            {
                "type": "generated_artifacts_stale",
                "severity": "needs_rebuild",
                "stale_artifact_paths": drift.get("stale_artifact_paths", []),
                "message": "Generated artifacts differ from the canonical registry.",
            }
        )
    for err in drift.get("errors", []):
        issues.append({"type": "artifact_drift_check_failed", "severity": "needs_review", "message": err})

    summary = {
        "total": len(issues),
        "needs_review": sum(1 for issue in issues if issue.get("severity") == "needs_review"),
        "needs_rebuild": sum(1 for issue in issues if issue.get("severity") == "needs_rebuild"),
        "intentional": sum(1 for issue in issues if issue.get("severity") == "intentional"),
    }
    return {"ok": True, "summary": summary, "issues": issues}


def parse_bib_paste(text: str) -> dict:
    entries = parse_bib_entries(text)
    if not entries:
        raise ValueError("No BibTeX entry found")
    key = next(iter(entries.keys()))
    entry = entries[key]
    fields = entry.get("fields", {})
    return {
        "source_key": key,
        "bib": {
            "entry_type": normalize_whitespace(entry.get("entry_type", "")),
            "title": fields.get("title", ""),
            "author": fields.get("author", ""),
            "year": fields.get("year", ""),
            "month": fields.get("month", ""),
            "journal": fields.get("journal", ""),
            "booktitle": fields.get("booktitle", ""),
            "volume": fields.get("volume", ""),
            "number": fields.get("number", ""),
            "pages": fields.get("pages", ""),
            "institution": fields.get("institution", ""),
            "publisher": fields.get("publisher", ""),
            "doi": fields.get("doi", ""),
            "url": fields.get("url", ""),
            "urldate": fields.get("urldate", ""),
            "abstract": fields.get("abstract", ""),
            "keywords": fields.get("keywords", ""),
            "note": fields.get("note", ""),
            "extra_fields": {k: v for k, v in fields.items() if k not in {
                "title", "author", "year", "month", "journal", "booktitle", "volume", "number", "pages",
                "institution", "publisher", "doi", "url", "urldate", "abstract", "keywords", "note"
            }},
        },
    }


def make_candidate(payload: dict) -> dict:
    record = payload.get("record", {})
    mode = normalize_whitespace(payload.get("mode", "add")).lower()
    source_key = normalize_whitespace(record.get("source_key", ""))
    source_value = normalize_whitespace(record.get("source", ""))
    citekey_value = normalize_whitespace(record.get("citekey", ""))
    if mode == "add":
        source_value = source_key
        citekey_value = source_key
    else:
        source_value = source_value or source_key
        citekey_value = citekey_value or source_value or source_key
    bib = record.get("bib", {}) or {}
    link_value = normalize_whitespace(record.get("link", ""))
    bib_url_value = normalize_whitespace(bib.get("url", ""))
    if mode == "add":
        # For new entries, collect one URL field and mirror it to both link and bib.url.
        bib_url_value = link_value or bib_url_value
    editor_name = normalize_whitespace(payload.get("editor_name", "")) or normalize_whitespace(record.get("editor_name", ""))
    return {
        "section": normalize_whitespace(record.get("section", "")),
        "aggsource": normalize_whitespace(record.get("aggsource", "")),
        "legend": normalize_whitespace(record.get("legend", "")),
        "source": source_value,
        "citekey": citekey_value,
        "data_type": normalize_whitespace(record.get("data_type", "")),
        "link": link_value,
        "ref_link": normalize_whitespace(record.get("ref_link", "")),
        "inclusion_in_warehouse": normalize_whitespace(record.get("inclusion_in_warehouse", "")),
        "multigeo_reference": normalize_whitespace(record.get("multigeo_reference", "")),
        "metadata": normalize_whitespace(record.get("metadata", "")),
        "metadatalink": normalize_whitespace(record.get("metadatalink", "")),
        "shared_citekey_group": normalize_whitespace(record.get("shared_citekey_group", "")),
        "shared_citekey_note": normalize_whitespace(record.get("shared_citekey_note", "")),
        "editor_name": editor_name,
        "bib": {
            "entry_type": normalize_whitespace(bib.get("entry_type", "")),
            "title": normalize_whitespace(bib.get("title", "")),
            "author": normalize_whitespace(bib.get("author", "")),
            "year": normalize_whitespace(bib.get("year", "")),
            "month": normalize_whitespace(bib.get("month", "")),
            "journal": normalize_whitespace(bib.get("journal", "")),
            "booktitle": normalize_whitespace(bib.get("booktitle", "")),
            "volume": normalize_whitespace(bib.get("volume", "")),
            "number": normalize_whitespace(bib.get("number", "")),
            "pages": normalize_whitespace(bib.get("pages", "")),
            "institution": normalize_whitespace(bib.get("institution", "")),
            "publisher": normalize_whitespace(bib.get("publisher", "")),
            "doi": normalize_whitespace(bib.get("doi", "")),
            "url": bib_url_value,
            "urldate": normalize_whitespace(bib.get("urldate", "")),
            "abstract": normalize_whitespace(bib.get("abstract", "")),
            "keywords": normalize_whitespace(bib.get("keywords", "")),
            "note": normalize_whitespace(bib.get("note", "")),
            "extra_fields": bib.get("extra_fields", {}) or {},
        },
    }


ADD_RECORD_FIELDS = [
    "section",
    "aggsource",
    "legend",
    "source_key",
    "data_type",
    "link",
    "ref_link",
    "inclusion_in_warehouse",
    "multigeo_reference",
    "metadata",
    "metadatalink",
    "shared_citekey_group",
    "shared_citekey_note",
]
ADD_BIB_FIELDS = [
    "entry_type",
    "title",
    "author",
    "year",
    "month",
    "journal",
    "booktitle",
    "volume",
    "number",
    "pages",
    "institution",
    "publisher",
    "doi",
    "url",
    "urldate",
    "keywords",
    "note",
    "abstract",
]


def is_empty_add_payload(payload: dict) -> bool:
    mode = normalize_whitespace(payload.get("mode", "add")).lower()
    if mode != "add":
        return False
    record = payload.get("record", {}) or {}
    bib = record.get("bib", {}) or {}
    for key in ADD_RECORD_FIELDS:
        if normalize_whitespace(record.get(key, "")):
            return False
    for key in ADD_BIB_FIELDS:
        if normalize_whitespace(bib.get(key, "")):
            return False
    return True


def is_empty_wealth_add_payload(payload: dict) -> bool:
    mode = normalize_whitespace(payload.get("mode", "add")).lower()
    if mode != "add":
        return False
    record = payload.get("record", {}) or {}
    bib = record.get("bib", {}) or {}
    if normalize_whitespace(record.get("key", "")):
        return False
    required_scan = ["entry_type", "title", "author", "year", *WEALTH_BIB_FIELDS]
    seen = set()
    for key in required_scan:
        if key in seen:
            continue
        seen.add(key)
        if normalize_whitespace(bib.get(key, "")):
            return False
    extra_fields = bib.get("extra_fields", {}) or {}
    for _, value in extra_fields.items():
        if normalize_whitespace(str(value)):
            return False
    return True


SUMMARY_TOP_FIELDS = [
    "section", "aggsource", "legend", "source", "citekey", "data_type", "link", "ref_link",
    "inclusion_in_warehouse", "multigeo_reference", "metadata", "metadatalink",
    "shared_citekey_group", "shared_citekey_note",
]
SUMMARY_BIB_FIELDS = [
    "entry_type", "title", "author", "year", "month", "journal", "booktitle",
    "volume", "number", "pages", "institution", "publisher", "doi", "url",
    "urldate", "abstract", "keywords", "note",
]


def summarize_record_all_fields(rec: dict) -> List[str]:
    out: List[str] = []
    for key in SUMMARY_TOP_FIELDS:
        if normalize_whitespace(str(rec.get(key, ""))):
            out.append(key)
    bib = rec.get("bib", {}) or {}
    for key in SUMMARY_BIB_FIELDS:
        if normalize_whitespace(str(bib.get(key, ""))):
            out.append(f"bib.{key}")
    return out


def summarize_record_diff(before: dict, after: dict) -> List[str]:
    changed: List[str] = []
    for key in SUMMARY_TOP_FIELDS:
        if normalize_whitespace(str(before.get(key, ""))) != normalize_whitespace(str(after.get(key, ""))):
            changed.append(key)
    bbib = before.get("bib", {}) or {}
    abib = after.get("bib", {}) or {}
    for key in SUMMARY_BIB_FIELDS:
        if normalize_whitespace(str(bbib.get(key, ""))) != normalize_whitespace(str(abib.get(key, ""))):
            changed.append(f"bib.{key}")
    return changed


def build_file_change_summary(modified_files: List[str], operation: str, record_id: str, changed_fields: List[str], key_renamed: bool = False) -> List[dict]:
    summary: List[dict] = []
    for fp in modified_files:
        p = str(fp)
        if path_matches(p, DEFAULT_REGISTRY_PATH):
            if operation == "bulk_label_update":
                text = f"Bulk-updated {record_id}. Fields changed: {', '.join(changed_fields) if changed_fields else '(none detected)'}."
            elif operation == "edit":
                text = f"Updated record {record_id}. Fields changed: {', '.join(changed_fields) if changed_fields else '(none detected)'}."
            elif operation == "add":
                text = f"Added record {record_id}. Fields populated: {', '.join(changed_fields) if changed_fields else '(none detected)'}."
            elif operation == "delete":
                text = f"Deleted record {record_id}. Removed fields: {', '.join(changed_fields) if changed_fields else '(none detected)'}."
            elif operation == "build_only":
                text = "No source records changed. Build-only run."
            else:
                text = "Updated source registry."
            summary.append({"file": p, "summary": text})
            continue
        if path_matches(p, DEFAULT_CHANGE_LOG_PATH):
            summary.append({"file": p, "summary": f"Added {operation} history record for {record_id}."})
            continue
        if path_matches(p, DEFAULT_WEALTH_CHANGE_LOG_PATH):
            summary.append({"file": p, "summary": f"Added {operation} Wealth Research history record for {record_id}."})
            continue
        if path_matches(p, DEFAULT_ALIASES_PATH):
            if key_renamed:
                summary.append({"file": p, "summary": "Added Source/Citekey alias mappings for key rename."})
            else:
                summary.append({"file": p, "summary": "Aliases file touched."})
            continue
        if path_matches(p, DEFAULT_DICTIONARY_PATH):
            summary.append({"file": p, "summary": "Regenerated Sources sheet from canonical registry."})
            continue
        if p.endswith(".bib"):
            summary.append({"file": p, "summary": "Regenerated or published BibTeX artifact."})
            continue
        summary.append({"file": p, "summary": "File updated."})
    return summary


def build_ref_link_review_file_change_summary(modified_files: List[str], applied_ids: List[str]) -> List[dict]:
    count = len(applied_ids)
    summary: List[dict] = []
    for fp in modified_files:
        p = str(fp)
        if path_matches(p, DEFAULT_REGISTRY_PATH):
            summary.append({"file": p, "summary": f"Updated ref_link for {count} record(s)."})
            continue
        if path_matches(p, DEFAULT_CHANGE_LOG_PATH):
            summary.append({"file": p, "summary": f"Added {count} ref_link review history record{'s' if count != 1 else ''}."})
            continue
        if path_matches(p, DEFAULT_DICTIONARY_PATH):
            summary.append({"file": p, "summary": "Regenerated Sources sheet from canonical registry."})
            continue
        if p.endswith(".bib"):
            summary.append({"file": p, "summary": "Regenerated BibTeX artifact after ref_link updates."})
            continue
        summary.append({"file": p, "summary": "File updated."})
    return summary


def _history_action_label(operation: str, reason: str) -> str:
    op = normalize_whitespace(operation).lower()
    reason_text = normalize_whitespace(reason).lower()
    if "ref_link" in reason_text:
        return "Ref link review"
    labels = {
        "add": "Add",
        "edit": "Edit",
        "delete": "Delete",
        "build_only": "Build only",
        "bulk_label_update": "Bulk label update",
    }
    return labels.get(op, op.replace("_", " ").title() or "Change")


def _history_entry_summary(library: str, operation: str, record_id: str, reason: str) -> str:
    action = _history_action_label(operation, reason)
    record = normalize_whitespace(record_id) or "(no record id)"
    if library == "wealth_research":
        return f"{action} in Wealth Research for {record}."
    return f"{action} in Data Sources for {record}."


def _history_file_sort_key(path_value: str) -> tuple:
    if path_matches(path_value, DEFAULT_DICTIONARY_PATH):
        return (0, path_value)
    if str(path_value).endswith(".bib"):
        return (1, path_value)
    if path_matches(path_value, DEFAULT_REGISTRY_PATH):
        return (2, path_value)
    if (
        path_matches(path_value, DEFAULT_CHANGE_LOG_PATH)
        or path_matches(path_value, DEFAULT_WEALTH_CHANGE_LOG_PATH)
        or path_matches(path_value, DEFAULT_ALIASES_PATH)
    ):
        return (3, path_value)
    return (4, path_value)


def _history_file_descriptors(
    library: str,
    operation: str,
    reason: str,
    registry_path: Path,
    changelog_path: Path,
    aliases_path: Path,
    cfg: dict,
) -> List[dict]:
    descriptors: List[dict] = []

    def add_descriptor(path_value: Path, category: str, note: str, optional: bool = False):
        descriptors.append(
            {
                "path": str(path_value),
                "category": category,
                "note": note,
                "optional": optional,
            }
        )

    op = normalize_whitespace(operation).lower()
    reason_text = normalize_whitespace(reason).lower()

    if library == "wealth_research":
        add_descriptor(_wealth_bib_path(cfg), "canonical", "Primary Wealth Research bibliography store.")
        add_descriptor(changelog_path, "history", "Wealth Research history log.")
        if op in {"add", "edit", "delete", "build_only"}:
            add_descriptor(_both_bib_path(cfg), "generated", "Combined bibliography regenerated from both libraries.")
        return sorted(descriptors, key=lambda item: _history_file_sort_key(item.get("path", "")))

    add_descriptor(registry_path, "canonical", "Primary Data Sources registry.")
    add_descriptor(changelog_path, "history", "Data Sources history log.")
    if op in {"add", "edit", "delete", "build_only", "bulk_label_update"}:
        add_descriptor(_dictionary_output_path(cfg), "generated", "Sources sheet rebuilt from canonical registry.")
        add_descriptor(_data_bib_path(cfg), "generated", "Data Sources BibTeX library regenerated.")
        add_descriptor(_both_bib_path(cfg), "generated", "Combined bibliography regenerated from both libraries.")
    if op == "edit" and "ref_link" not in reason_text:
        add_descriptor(
            aliases_path,
            "compatibility",
            "Touched only when Source/Citekey was renamed and alias mappings were added.",
            optional=True,
        )
    return sorted(descriptors, key=lambda item: _history_file_sort_key(item.get("path", "")))


def _git_show_summary(commit: str, timeout_seconds: int = 5) -> dict:
    try:
        proc = _run_git(["show", "-s", "--format=%H%n%cI%n%s", commit], timeout_seconds)
        lines = proc.stdout.decode("utf-8", errors="replace").splitlines()
        return {
            "commit": lines[0] if len(lines) > 0 else commit,
            "committed_at": lines[1] if len(lines) > 1 else "",
            "subject": lines[2] if len(lines) > 2 else "",
        }
    except Exception:
        return {"commit": commit, "committed_at": "", "subject": ""}


def _history_git_context(updated_at: str) -> dict:
    base = getattr(_history_git_context, "_base_context", None)
    if base is None:
        base = {
            "available": False,
            "remote_url": "",
            "commit": "",
            "committed_at": "",
            "subject": "",
        }
        try:
            _run_git(["rev-parse", "--is-inside-work-tree"], 5)
            base["available"] = True
            for remote_name in ["upstream", "origin"]:
                try:
                    proc = _run_git(["remote", "get-url", remote_name], 5)
                    remote_url = normalize_whitespace(proc.stdout.decode("utf-8", errors="replace"))
                    if remote_url:
                        base["remote_url"] = remote_url
                        break
                except Exception:
                    continue
        except Exception:
            pass
        _history_git_context._base_context = base
        _history_git_context._commit_cache = {}

    context = dict(base)
    if not context.get("available") or not normalize_whitespace(updated_at):
        return context

    cache = getattr(_history_git_context, "_commit_cache", {})
    if updated_at not in cache:
        commit_context = {"commit": "", "committed_at": "", "subject": ""}
        try:
            proc = _run_git(["rev-list", "-1", f"--before={updated_at}", "--all"], 5)
            commit = normalize_whitespace(proc.stdout.decode("utf-8", errors="replace"))
            if commit:
                commit_context.update(_git_show_summary(commit, timeout_seconds=5))
        except Exception:
            pass
        cache[updated_at] = commit_context
        _history_git_context._commit_cache = cache
    context.update(cache.get(updated_at, {}))
    return context


def _build_history_entry(
    library: str,
    entry: dict,
    storage_index: int,
    registry_path: Path,
    changelog_path: Path,
    aliases_path: Path,
    cfg: dict,
) -> dict:
    operation = normalize_whitespace(entry.get("operation", ""))
    record_id = normalize_whitespace(entry.get("record_id", ""))
    reason = normalize_whitespace(entry.get("reason", ""))
    updated_at = normalize_whitespace(entry.get("updated_at", ""))
    actor = normalize_whitespace(entry.get("actor", ""))
    return {
        "history_id": f"{library}:{storage_index}",
        "storage_index": storage_index,
        "library": library,
        "branch_label": "Wealth Research" if library == "wealth_research" else "Data Sources",
        "operation": operation,
        "action_label": _history_action_label(operation, reason),
        "record_id": record_id,
        "reason": reason,
        "actor": actor,
        "updated_at": updated_at,
        "summary": _history_entry_summary(library, operation, record_id, reason),
        "affected_files": _history_file_descriptors(
            library,
            operation,
            reason,
            registry_path,
            changelog_path,
            aliases_path,
            cfg,
        ),
        "git_context": _history_git_context(updated_at),
    }


def build_history_feed(app, registry: dict) -> dict:
    cfg = registry.get("config", {}) or {}
    data_log = load_json_yaml(app.changelog_path) or {"changes": []}
    wealth_log_path = _wealth_change_log_path(cfg)
    wealth_log = load_json_yaml(wealth_log_path) or {"changes": []}
    entries: List[dict] = []

    for idx, entry in enumerate(data_log.get("changes", []) or []):
        entries.append(
            _build_history_entry(
                "data_sources",
                entry or {},
                idx,
                app.registry_path,
                app.changelog_path,
                app.aliases_path,
                cfg,
            )
        )

    for idx, entry in enumerate(wealth_log.get("changes", []) or []):
        entries.append(
            _build_history_entry(
                "wealth_research",
                entry or {},
                idx,
                app.registry_path,
                wealth_log_path,
                app.aliases_path,
                cfg,
            )
        )

    entries.sort(key=lambda item: (item.get("updated_at", ""), item.get("history_id", "")), reverse=True)
    latest = entries[0] if entries else {}
    summary = {
        "total": len(entries),
        "data_sources": sum(1 for item in entries if item.get("library") == "data_sources"),
        "wealth_research": sum(1 for item in entries if item.get("library") == "wealth_research"),
        "latest_updated_at": latest.get("updated_at", ""),
        "latest_summary": latest.get("summary", ""),
    }
    return {"entries": entries, "summary": summary}


def delete_history_entry(changelog_path: Path, storage_index: int) -> dict:
    data = load_json_yaml(changelog_path) or {"changes": []}
    changes = list(data.get("changes", []) or [])
    if storage_index < 0 or storage_index >= len(changes):
        raise ValueError(f"history entry not found at index {storage_index}")
    removed = changes.pop(storage_index)
    data["changes"] = changes
    changelog_path.parent.mkdir(parents=True, exist_ok=True)
    changelog_path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding='utf-8')
    return removed


def delete_history_entries_for_record(changelog_path: Path, record_id: str) -> List[dict]:
    record_key = normalize_whitespace(record_id)
    if not record_key:
        raise ValueError("record_id is required")
    data = load_json_yaml(changelog_path) or {"changes": []}
    changes = list(data.get("changes", []) or [])
    removed = [entry for entry in changes if normalize_whitespace((entry or {}).get("record_id", "")) == record_key]
    if not removed:
        raise ValueError(f"no history records found for {record_key}")
    data["changes"] = [entry for entry in changes if normalize_whitespace((entry or {}).get("record_id", "")) != record_key]
    changelog_path.parent.mkdir(parents=True, exist_ok=True)
    changelog_path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding='utf-8')
    return removed


def relaunch_local_ui(app, host: str, port: int) -> None:
    launch_cmd = [
        sys.executable,
        str(Path(__file__).resolve()),
        "--host",
        str(host),
        "--port",
        str(port),
        "--registry",
        str(app.registry_path),
        "--aliases",
        str(app.aliases_path),
        "--change-log",
        str(app.changelog_path),
    ]
    cmd_text = " ".join(shlex.quote(part) for part in launch_cmd)
    shell_cmd = f"sleep 2; cd {shlex.quote(str(REPO_ROOT))}; exec {cmd_text} >/tmp/source_manager_relaunch.log 2>&1"
    subprocess.Popen(
        ["/bin/bash", "-lc", shell_cmd],
        cwd=str(REPO_ROOT),
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True,
    )


def apply_payload(registry: dict, payload: dict, aliases_path: Path, changelog_path: Path) -> dict:
    records = registry.get("records", [])
    mode = normalize_whitespace(payload.get("mode", "add")).lower()
    target = normalize_whitespace(payload.get("target", ""))
    breaking = bool(payload.get("key_rename_confirmed", False))
    candidate = make_candidate(payload)
    editor_name = normalize_whitespace(candidate.get("editor_name", ""))

    if not editor_name:
        raise ValueError("editor_name is required")
    if mode not in {"add", "edit"}:
        raise ValueError("mode must be add or edit")

    if mode == "edit":
        reason = "Edited via local UI"
        hits = find_target(records, target)
        if len(hits) != 1:
            raise ValueError(f"Edit target must match exactly one record; got {len(hits)}")

        rec = hits[0]
        before_rec = json.loads(json.dumps(rec))
        before_source = rec.get("source", "")
        before_citekey = rec.get("citekey", "")

        updated = json.loads(json.dumps(rec))
        for k in [
            "section", "aggsource", "legend", "source", "citekey", "data_type", "link", "ref_link",
            "inclusion_in_warehouse", "multigeo_reference", "metadata", "metadatalink",
            "shared_citekey_group", "shared_citekey_note",
        ]:
            val = candidate.get(k, "")
            if val != "":
                updated[k] = val

        ubib = updated.get("bib", {})
        for k, v in candidate.get("bib", {}).items():
            if k == "extra_fields":
                continue
            if v != "":
                ubib[k] = v
        updated["bib"] = ubib
        updated["updated_at"] = now_utc()
        updated["updated_by"] = editor_name

        changed_key = before_source != updated.get("source", "") or before_citekey != updated.get("citekey", "")
        if changed_key and not breaking:
            raise ValueError("You changed Source/Citekey. Confirm key rename in the save confirmation prompt.")

        updated_for_validation = json.loads(json.dumps(updated))
        updated_for_validation["editor_name"] = editor_name
        check = validate_candidate(records, updated_for_validation, mode="edit", target_id=rec.get("id", ""))
        if check["errors"]:
            raise ValueError("\n".join(check["errors"]))

        rec.update(updated)

        if changed_key and breaking:
            if before_source != rec.get("source", ""):
                append_alias(aliases_path, "source", before_source, rec.get("source", ""), reason)
            if before_citekey != rec.get("citekey", ""):
                append_alias(aliases_path, "citekey", before_citekey, rec.get("citekey", ""), reason)

        append_change(changelog_path, "edit", rec.get("id", ""), reason, editor_name)
        return {
            "status": "ok",
            "operation": "edit",
            "warnings": check["warnings"],
            "checks": check["checks"],
            "record_id": rec.get("id", ""),
            "changed_fields": summarize_record_diff(before_rec, rec),
            "key_renamed": changed_key,
        }

    reason = "Added via local UI"

    newrec = {
        "id": f"src-{re.sub(r'[^A-Za-z0-9]+', '-', candidate.get('source', '').strip()).strip('-').lower()}",
        "section": candidate.get("section", ""),
        "aggsource": candidate.get("aggsource", ""),
        "legend": candidate.get("legend", ""),
        "source": candidate.get("source", ""),
        "data_type": candidate.get("data_type", ""),
        "link": candidate.get("link", ""),
        "ref_link": candidate.get("ref_link", ""),
        "citekey": candidate.get("citekey", ""),
        "inclusion_in_warehouse": candidate.get("inclusion_in_warehouse", ""),
        "multigeo_reference": candidate.get("multigeo_reference", ""),
        "metadata": candidate.get("metadata", ""),
        "metadatalink": candidate.get("metadatalink", ""),
        "shared_citekey_group": candidate.get("shared_citekey_group", ""),
        "shared_citekey_note": candidate.get("shared_citekey_note", ""),
        "qcommentsforta": "",
        "tareply": "",
        "tacomments": "",
        "arjcomments": "",
        "arjreplies": "",
        "seeaggsourcelisthere": "",
        "bib": candidate.get("bib", {}),
        "created_at": now_utc(),
        "updated_at": now_utc(),
        "created_by": editor_name,
        "updated_by": editor_name,
    }

    check = validate_candidate(records, candidate, mode="add")
    if check["errors"]:
        raise ValueError("\n".join(check["errors"]))

    records.append(newrec)
    append_change(changelog_path, "add", newrec.get("id", ""), reason, editor_name)
    return {
        "status": "ok",
        "operation": "add",
        "warnings": check["warnings"],
        "checks": check["checks"],
        "record_id": newrec.get("id", ""),
        "changed_fields": summarize_record_all_fields(newrec),
        "key_renamed": False,
    }


def _summarize_wealth_record_all_fields(record: dict) -> List[str]:
    out = ["key"]
    bib = record.get("bib", {}) or {}
    if normalize_whitespace(str(bib.get("entry_type", ""))):
        out.append("bib.entry_type")
    for field in WEALTH_BIB_FIELDS:
        if normalize_whitespace(str(bib.get(field, ""))):
            out.append(f"bib.{field}")
    extras = bib.get("extra_fields", {}) or {}
    for field_name, value in sorted(extras.items(), key=lambda x: str(x[0]).lower()):
        if normalize_whitespace(str(value)):
            out.append(f"bib.{field_name}")
    return out


def _summarize_wealth_record_diff(before: dict, after: dict) -> List[str]:
    changed: List[str] = []
    if normalize_whitespace(before.get("key", "")) != normalize_whitespace(after.get("key", "")):
        changed.append("key")
    bbib = before.get("bib", {}) or {}
    abib = after.get("bib", {}) or {}
    if normalize_whitespace(str(bbib.get("entry_type", ""))) != normalize_whitespace(str(abib.get("entry_type", ""))):
        changed.append("bib.entry_type")
    for field in WEALTH_BIB_FIELDS:
        if normalize_whitespace(str(bbib.get(field, ""))) != normalize_whitespace(str(abib.get(field, ""))):
            changed.append(f"bib.{field}")
    before_extras = bbib.get("extra_fields", {}) or {}
    after_extras = abib.get("extra_fields", {}) or {}
    for field_name in sorted(set(before_extras.keys()) | set(after_extras.keys()), key=str.lower):
        if normalize_whitespace(str(before_extras.get(field_name, ""))) != normalize_whitespace(str(after_extras.get(field_name, ""))):
            changed.append(f"bib.{field_name}")
    return changed


def _data_bib_keys(cfg: dict) -> set:
    data_path = _data_bib_path(cfg)
    if not data_path.exists():
        return set()
    text = data_path.read_text(encoding="utf-8")
    return {normalize_whitespace(k) for k in parse_bib_entries(text).keys() if normalize_whitespace(k)}


HTML = """<!doctype html>
<html>
<head>
<meta charset='utf-8' />
<title>ADAM SSM - Sleepless Source Manager</title>
<style>
:root {
  --bg-page: #efe6d6;
  --bg-panel: #fffdf8;
  --bg-input: #fffaf2;
  --accent-ink: #17324d;
  --accent-soft: #d7c5a4;
  --border-soft: #d8d1c3;
  --text-main: #1f2933;
  --text-muted: #5f6772;
}
* { box-sizing: border-box; }
body { font-family: "Iowan Old Style", "Palatino Linotype", "Book Antiqua", Georgia, serif; margin: 24px; background: radial-gradient(circle at top, #f7f1e7 0%, var(--bg-page) 58%, #e7ddcc 100%); color: var(--text-main); }
.wrap { max-width: 1180px; margin: 0 auto; background: var(--bg-panel); border: 1px solid var(--border-soft); border-radius: 10px; padding: 20px; }
.app-shell { box-shadow: 0 22px 60px rgba(41, 37, 30, 0.12); }
.app-header { display: flex; justify-content: space-between; align-items: flex-start; gap: 16px; margin-bottom: 20px; }
.app-header-main { min-width: 0; }
.app-header-actions { display: flex; gap: 10px; flex-wrap: wrap; justify-content: flex-end; }
.grid3 { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 18px; }
label { font-size: 12px; color: var(--text-muted); font-weight: 600; display: block; margin-bottom: 6px; letter-spacing: 0.03em; text-transform: uppercase; }
input, textarea, select { width: 100%; padding: 10px; border: 1px solid var(--border-soft); border-radius: 10px; font-size: 13px; background: var(--bg-input); color: var(--text-main); font-family: "Avenir Next", "Segoe UI", sans-serif; transition: border-color 120ms ease, box-shadow 120ms ease, background 120ms ease; }
input:focus, textarea:focus, select:focus { outline: none; border-color: var(--accent-ink); box-shadow: 0 0 0 3px rgba(23, 50, 77, 0.12); background: #fffdf8; }
textarea { min-height: 86px; }
.row { margin-bottom: 16px; }
button { background: var(--accent-ink); color: white; border: 0; border-radius: 999px; padding: 11px 16px; font-size: 13px; font-weight: 600; letter-spacing: 0.02em; cursor: pointer; font-family: "Avenir Next", "Segoe UI", sans-serif; transition: transform 120ms ease, opacity 120ms ease, box-shadow 120ms ease; box-shadow: 0 10px 18px rgba(23, 50, 77, 0.16); }
button:hover { transform: translateY(-1px); }
button.secondary { background: #5c6670; box-shadow: 0 10px 18px rgba(73, 81, 89, 0.14); }
button.warn { background: #8e4520; box-shadow: 0 10px 18px rgba(142, 69, 32, 0.14); }
h1, h2, h3 { font-family: "Avenir Next Condensed", "Gill Sans", "Trebuchet MS", sans-serif; color: var(--accent-ink); letter-spacing: 0.01em; }
h1 { margin: 0 0 6px; font-size: 2.1rem; line-height: 1.05; }
small { color: var(--text-muted); }
.app-subtitle { margin: 0 0 20px; font-size: 0.95rem; color: var(--text-muted); }
.panel { margin-bottom: 18px; padding: 18px; border: 1px solid rgba(109, 95, 74, 0.18); border-radius: 20px; background: linear-gradient(180deg, rgba(255, 253, 248, 0.96) 0%, rgba(250, 245, 236, 0.92) 100%); box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.7); }
.section-heading { margin: 0 0 14px; font-size: 1.15rem; letter-spacing: 0.06em; text-transform: uppercase; }
pre { background: linear-gradient(180deg, #1d242d 0%, #131920 100%); color: #e8efe8; padding: 16px; border-radius: 16px; overflow: auto; border: 1px solid rgba(132, 145, 160, 0.2); box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.05); }
#status, #wealth_status { white-space: pre-wrap; line-height: 1.5; font-family: "SFMono-Regular", Consolas, "Liberation Mono", monospace; font-size: 12px; }
#status .status-ok, #wealth_status .status-ok { color: #8fd28f; font-weight: 600; }
#status .status-fail, #wealth_status .status-fail { color: #ff9da4; font-weight: 600; }
#status .status-warn, #wealth_status .status-warn { color: #f0c674; font-weight: 600; }
#status .git-file, #wealth_status .git-file { color: #8ab4f8; }
#status .git-hunk, #wealth_status .git-hunk { color: #c792ea; }
#status .git-add, #wealth_status .git-add { color: #8fd28f; }
#status .git-del, #wealth_status .git-del { color: #ff9da4; }
.help { background: rgba(248, 243, 233, 0.95); border: 1px solid rgba(109, 95, 74, 0.18); padding: 12px; border-radius: 14px; color: #4b5662; font-size: 12px; line-height: 1.55; }
.req { color: #ad2b2b; }
.step { font-weight: 700; color: var(--accent-ink); margin-bottom: 6px; letter-spacing: 0.04em; text-transform: uppercase; font-size: 0.78rem; }
.hidden { display: none; }
.branch-tabs { display: inline-flex; gap: 8px; margin-bottom: 20px; padding: 6px; border-radius: 999px; background: rgba(23, 50, 77, 0.08); border: 1px solid rgba(23, 50, 77, 0.08); }
.branch-tab { background: transparent; color: var(--accent-ink); box-shadow: none; }
.branch-tab.active { background: var(--accent-ink); color: #fff; }
.search-panel { border: 1px solid rgba(109, 95, 74, 0.18); border-radius: 16px; padding: 14px; background: rgba(255, 251, 244, 0.84); }
.search-results { max-height: 280px; overflow: auto; border: 1px solid rgba(109, 95, 74, 0.18); border-radius: 12px; margin-top: 10px; background: rgba(255, 253, 248, 0.94); }
.search-results table { width: 100%; border-collapse: collapse; font-size: 12px; }
.search-results th, .search-results td { border-bottom: 1px solid rgba(109, 95, 74, 0.12); padding: 10px 8px; text-align: left; vertical-align: top; }
.search-results th { font-family: "Avenir Next", "Segoe UI", sans-serif; font-size: 11px; letter-spacing: 0.05em; text-transform: uppercase; color: var(--text-muted); background: rgba(239, 230, 214, 0.48); position: sticky; top: 0; }
.search-results tr:hover { background: rgba(23, 50, 77, 0.06); }
.search-btn { background: transparent; color: var(--accent-ink); border: 0; padding: 0; cursor: pointer; text-align: left; font-size: 12px; box-shadow: none; border-radius: 0; }
.ref-link-review-modal { position: fixed; inset: 0; z-index: 999; background: rgba(16, 23, 31, 0.62); padding: 24px; overflow: auto; }
.ref-link-review-dialog { position: relative; width: min(96vw, 1500px); max-height: 92vh; margin: 0 auto; border-radius: 24px; border: 1px solid rgba(109, 95, 74, 0.18); background: linear-gradient(180deg, rgba(255, 253, 248, 0.99) 0%, rgba(247, 240, 227, 0.98) 100%); box-shadow: 0 28px 90px rgba(17, 23, 31, 0.28); display: flex; flex-direction: column; overflow: hidden; }
.ref-link-review-sticky { position: sticky; top: 0; z-index: 2; background: linear-gradient(180deg, rgba(255, 253, 248, 0.99) 0%, rgba(247, 240, 227, 0.98) 100%); }
.ref-link-review-topbar { display: flex; justify-content: space-between; gap: 14px; align-items: center; padding: 12px 18px 10px; border-bottom: 1px solid rgba(109, 95, 74, 0.14); }
.ref-link-review-topbar-summary { display: flex; flex-wrap: wrap; gap: 8px 14px; align-items: center; min-width: 0; }
.ref-link-review-title-line { margin: 0; font-size: 0.98rem; letter-spacing: 0.05em; }
.ref-link-review-tray-toggle { display: inline-flex; }
.ref-link-review-header { display: flex; justify-content: space-between; gap: 16px; align-items: flex-start; padding: 16px 18px 8px; border-bottom: 1px solid rgba(109, 95, 74, 0.14); }
.ref-link-review-header-actions { display: flex; gap: 10px; flex-wrap: wrap; justify-content: flex-end; }
.ref-link-review-scan-status { margin-top: 0; padding: 6px 8px; border-radius: 12px; border: 1px solid rgba(109, 95, 74, 0.14); background: rgba(255, 251, 244, 0.84); min-width: min(260px, 100%); }
.ref-link-review-scan-status-compact { display: grid; gap: 4px; }
.ref-link-review-scan-status.loading { background: rgba(255, 248, 234, 0.92); }
.ref-link-review-scan-status.failed { background: rgba(255, 241, 237, 0.94); border-color: rgba(160, 69, 32, 0.22); }
.ref-link-review-scan-status.complete { background: rgba(248, 252, 247, 0.94); }
.ref-link-review-scan-meta { display: flex; justify-content: space-between; gap: 10px; align-items: center; flex-wrap: wrap; }
.ref-link-review-scan-progress { height: 6px; margin-top: 0; border-radius: 999px; overflow: hidden; background: rgba(23, 50, 77, 0.10); }
.ref-link-review-scan-progress-fill { height: 100%; width: 0; background: linear-gradient(90deg, #234a74 0%, #b4692d 100%); transition: width 0.18s ease; }
.ref-link-review-scan-progress-label { margin-top: 0; color: var(--text-muted); font-size: 12px; }
.ref-link-review-toolbar { display: flex; flex-direction: column; gap: 8px; padding: 10px 18px 12px; border-bottom: 1px solid rgba(109, 95, 74, 0.14); }
.ref-link-review-toolbar-note { color: var(--text-muted); font-size: 12px; line-height: 1.45; }
.ref-link-review-benchmark-panel { display: grid; gap: 10px; padding: 10px 12px; border: 1px solid rgba(109, 95, 74, 0.14); border-radius: 14px; background: rgba(255, 251, 244, 0.88); }
.ref-link-review-benchmark-panel label { margin: 0; }
.ref-link-review-benchmark-inputs { display: grid; gap: 8px; }
.ref-link-review-benchmark-actions { display: flex; justify-content: flex-start; }
.ref-link-review-benchmark-inputs button { width: auto; max-width: 100%; align-self: start; white-space: normal; }
.ref-link-review-benchmark-meta { color: var(--text-muted); font-size: 12px; line-height: 1.4; }
.ref-link-review-toolbar-row { display: grid; grid-template-columns: minmax(0, 1fr) auto; gap: 10px; align-items: start; }
.ref-link-review-toolbar-actions { display: flex; gap: 10px; flex-wrap: wrap; align-items: flex-end; justify-content: flex-end; }
.ref-link-review-filters { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 12px; }
.ref-link-review-filter-group { border: 1px solid rgba(109, 95, 74, 0.14); border-radius: 14px; padding: 8px 10px; background: rgba(255, 251, 244, 0.86); }
.ref-link-review-filter-group label { margin-bottom: 6px; }
.ref-link-review-filter-group select { min-height: 78px; padding: 6px 8px; background: #fffdf8; border-radius: 12px; }
.ref-link-review-toolbar-summary { color: var(--text-muted); font-size: 12px; line-height: 1.4; }
.ref-link-review-visible-summary { margin: 0; }
.ref-link-review-body { padding: 12px 18px 18px; overflow: auto; }
.ref-link-review-layout { display: grid; grid-template-columns: minmax(0, 1fr) 12px minmax(260px, 320px); gap: 0; align-items: start; }
.ref-link-review-main { min-width: 0; }
.ref-link-review-tray-resize-handle { position: relative; cursor: col-resize; border-radius: 999px; }
.ref-link-review-tray-resize-handle::after { content: ""; position: absolute; top: 24px; bottom: 24px; left: 50%; width: 3px; transform: translateX(-50%); border-radius: 999px; background: rgba(23, 50, 77, 0.18); }
.ref-link-review-tray { margin-left: 8px; padding: 10px; border: 1px solid rgba(109, 95, 74, 0.14); border-radius: 18px; background: rgba(255, 251, 244, 0.84); }
.ref-link-review-tray-sections { display: grid; gap: 10px; }
.ref-link-review-tray-section { border: 1px solid rgba(109, 95, 74, 0.14); border-radius: 14px; padding: 10px; background: rgba(255, 253, 248, 0.92); }
.ref-link-review-tray-section-header { width: 100%; display: flex; align-items: center; justify-content: space-between; gap: 10px; padding: 0; border: 0; background: transparent; color: var(--accent-ink); box-shadow: none; border-radius: 0; text-align: left; }
.ref-link-review-tray-section-header:hover { transform: none; }
.ref-link-review-tray-section-heading { display: block; color: var(--text-muted); font-size: 11px; letter-spacing: 0.05em; text-transform: uppercase; }
.ref-link-review-tray-section-summary { color: var(--text-muted); font-size: 12px; font-weight: 500; }
.ref-link-review-tray-section-body { margin-top: 10px; }
.ref-link-review-tray-section.collapsed .ref-link-review-tray-section-body { display: none; }
.ref-link-review-topbar-status-line { color: var(--text-muted); font-size: 12px; line-height: 1.4; }
.ref-link-review-filter-row { display: grid; grid-template-columns: repeat(auto-fit, minmax(132px, 1fr)); gap: 8px; align-items: start; }
.ref-link-review-filter-popover-wrap { position: relative; min-width: 0; }
.ref-link-review-filter-trigger { width: 100%; justify-content: space-between; border-radius: 10px; padding: 9px 10px; background: #fffdf8; color: var(--text-main); border: 1px solid rgba(109, 95, 74, 0.14); box-shadow: none; }
.ref-link-review-filter-trigger:hover { transform: none; }
.ref-link-review-filter-trigger.active { border-color: rgba(23, 50, 77, 0.28); background: rgba(255, 251, 244, 0.96); }
.ref-link-review-filter-popover { position: absolute; top: calc(100% + 6px); right: 0; z-index: 3; width: max-content; min-width: max(100%, 240px); max-width: min(420px, calc(100vw - 80px), calc(100% + 240px)); padding: 10px; border: 1px solid rgba(109, 95, 74, 0.14); border-radius: 12px; background: rgba(255, 253, 248, 0.98); box-shadow: 0 10px 24px rgba(17, 23, 31, 0.12); }
.ref-link-review-filter-popover.hidden { display: none; }
.ref-link-review-filter-list { display: grid; gap: 6px; max-height: 176px; overflow: auto; padding: 2px 2px 2px 0; }
.ref-link-review-filter-option { display: flex; align-items: flex-start; gap: 8px; font-family: "Avenir Next", "Segoe UI", sans-serif; font-size: 12px; line-height: 1.35; color: var(--text-main); min-width: 0; }
.ref-link-review-filter-option input { width: auto; margin-top: 1px; }
.ref-link-review-filter-option-text { min-width: 0; white-space: normal; word-break: normal; overflow-wrap: normal; }
.ref-link-review-filter-popover-actions { display: flex; justify-content: flex-end; margin-top: 8px; }
.ref-link-review-dialog-resize-handle { position: absolute; right: 12px; bottom: 10px; width: 18px; height: 18px; cursor: nwse-resize; }
.ref-link-review-dialog-resize-handle::before,
.ref-link-review-dialog-resize-handle::after { content: ""; position: absolute; right: 0; bottom: 0; background: rgba(23, 50, 77, 0.28); border-radius: 999px; }
.ref-link-review-dialog-resize-handle::before { width: 2px; height: 16px; transform: rotate(45deg); transform-origin: bottom right; }
.ref-link-review-dialog-resize-handle::after { width: 2px; height: 11px; right: 5px; bottom: 1px; transform: rotate(45deg); transform-origin: bottom right; }
.ref-link-review-bucket { margin-bottom: 18px; padding: 16px; border: 1px solid rgba(109, 95, 74, 0.16); border-radius: 18px; background: rgba(255, 253, 248, 0.84); }
.ref-link-review-bucket-header { display: flex; justify-content: space-between; gap: 12px; align-items: baseline; margin-bottom: 10px; }
.ref-link-review-actions { display: flex; gap: 10px; flex-wrap: wrap; margin-bottom: 12px; }
.ref-link-review-table-summary { display: flex; justify-content: space-between; gap: 12px; align-items: baseline; margin-bottom: 12px; }
.ref-link-review-table-wrap { border: 1px solid rgba(109, 95, 74, 0.16); border-radius: 14px; overflow: auto; background: rgba(255, 253, 248, 0.96); }
.ref-link-review-table-wrap table { min-width: 1280px; width: max(100%, 1280px); table-layout: fixed; }
.ref-link-review-table-wrap th,
.ref-link-review-table-wrap td { overflow: hidden; text-overflow: ellipsis; }
.ref-link-review-table-wrap th { position: relative; padding-right: 18px; }
.ref-link-review-cell { white-space: normal; overflow-wrap: anywhere; }
.ref-link-review-proposed-cell small { display: block; margin-top: 4px; color: var(--text-muted); }
.ref-link-review-details-row td { background: rgba(247, 240, 227, 0.62); }
.ref-link-review-details { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 14px 18px; padding: 10px 2px 2px; }
.ref-link-review-detail-block { min-width: 0; }
.ref-link-review-detail-label { display: block; margin-bottom: 4px; color: var(--text-muted); font-size: 11px; letter-spacing: 0.05em; text-transform: uppercase; }
.ref-link-review-detail-value { white-space: normal; overflow-wrap: anywhere; }
.ref-link-review-override-wrap { grid-column: 1 / -1; }
.ref-link-review-override-input { width: 100%; }
.ref-link-review-override-input.invalid { border-color: #a04520; background: rgba(255, 241, 237, 0.9); }
.ref-link-review-override-help { margin-top: 6px; color: var(--text-muted); font-size: 12px; }
.ref-link-review-inline-warning { display: block; margin-top: 6px; color: #a04520; font-size: 12px; }
.ref-link-review-resize-handle { position: absolute; top: 0; right: 0; width: 12px; height: 100%; cursor: col-resize; }
.ref-link-review-resize-handle::after { content: ""; position: absolute; top: 22%; right: 4px; width: 2px; height: 56%; border-radius: 999px; background: rgba(23, 50, 77, 0.20); }
.ref-link-review-link { color: var(--accent-ink); text-decoration: underline; text-underline-offset: 2px; }
.ref-link-review-empty { color: var(--text-muted); font-style: italic; }
.ref-link-review-status { display: inline-flex; align-items: center; padding: 4px 8px; border-radius: 999px; font-family: "Avenir Next", "Segoe UI", sans-serif; font-size: 11px; font-weight: 600; letter-spacing: 0.03em; text-transform: uppercase; }
.ref-link-review-status.ready-to-apply { background: rgba(45, 115, 76, 0.12); color: #21583c; }
.ref-link-review-status.needs-review { background: rgba(180, 105, 45, 0.12); color: #8e4520; }
.ref-link-review-status.dismissed { background: rgba(92, 102, 112, 0.14); color: #4b5662; }
.ref-link-review-reasons { display: flex; flex-wrap: wrap; gap: 6px; }
.ref-link-review-reason { display: inline-flex; align-items: center; padding: 4px 8px; border-radius: 999px; background: rgba(142, 69, 32, 0.10); color: #7d3918; font-family: "Avenir Next", "Segoe UI", sans-serif; font-size: 11px; }
body.modal-open { overflow: hidden; }
details { border: 1px solid rgba(109, 95, 74, 0.18); border-radius: 16px; background: rgba(255, 251, 244, 0.82); padding: 14px 16px; }
summary { cursor: pointer; font-family: "Avenir Next Condensed", "Gill Sans", "Trebuchet MS", sans-serif; color: var(--accent-ink); letter-spacing: 0.05em; text-transform: uppercase; }
.history-shell { display: grid; gap: 18px; }
.history-summary-strip { display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: 12px; }
.history-kpi { padding: 14px 16px; border: 1px solid rgba(109, 95, 74, 0.18); border-radius: 16px; background: rgba(255, 251, 244, 0.88); }
.history-kpi-label { display: block; margin-bottom: 6px; color: var(--text-muted); font-size: 11px; letter-spacing: 0.05em; text-transform: uppercase; }
.history-kpi-value { font-family: "Avenir Next Condensed", "Gill Sans", "Trebuchet MS", sans-serif; color: var(--accent-ink); font-size: 1.1rem; line-height: 1.2; }
.history-toolbar { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 12px; align-items: end; }
.history-filter-actions { display: flex; gap: 10px; flex-wrap: wrap; }
.history-layout { display: grid; grid-template-columns: minmax(320px, 0.92fr) minmax(0, 1.08fr); gap: 18px; align-items: start; }
.history-list { max-height: 640px; overflow: auto; display: grid; gap: 10px; padding-right: 2px; }
.history-day-group { display: grid; gap: 8px; }
.history-day-heading { margin: 0; color: var(--text-muted); font-size: 12px; letter-spacing: 0.05em; text-transform: uppercase; }
.history-item { width: 100%; padding: 14px; border: 1px solid rgba(109, 95, 74, 0.16); border-radius: 16px; background: rgba(255, 253, 248, 0.94); color: var(--text-main); box-shadow: none; text-align: left; display: grid; gap: 8px; }
.history-item:hover { transform: translateY(-1px); }
.history-item.active { border-color: rgba(23, 50, 77, 0.28); box-shadow: 0 14px 28px rgba(23, 50, 77, 0.10); }
.history-item-top { display: flex; justify-content: space-between; gap: 10px; align-items: flex-start; }
.history-item-time { color: var(--accent-ink); font-family: "Avenir Next", "Segoe UI", sans-serif; font-size: 12px; font-weight: 600; }
.history-item-meta { color: var(--text-muted); font-size: 12px; line-height: 1.45; }
.history-badges { display: flex; flex-wrap: wrap; gap: 6px; }
.history-badge { display: inline-flex; align-items: center; padding: 4px 8px; border-radius: 999px; font-family: "Avenir Next", "Segoe UI", sans-serif; font-size: 11px; font-weight: 600; letter-spacing: 0.03em; text-transform: uppercase; }
.history-badge.library { background: rgba(23, 50, 77, 0.10); color: var(--accent-ink); }
.history-badge.action { background: rgba(180, 105, 45, 0.12); color: #8e4520; }
.history-record { font-family: "Avenir Next", "Segoe UI", sans-serif; font-size: 13px; font-weight: 600; color: var(--accent-ink); }
.history-summary { color: var(--text-main); font-size: 13px; line-height: 1.45; }
.history-files-count { color: var(--text-muted); font-size: 12px; }
.history-detail-empty { color: var(--text-muted); font-style: italic; }
.history-detail-grid { display: grid; gap: 14px; }
.history-detail-card { padding: 14px 16px; border: 1px solid rgba(109, 95, 74, 0.16); border-radius: 16px; background: rgba(255, 251, 244, 0.86); }
.history-detail-card h4 { margin: 0 0 10px; font-size: 0.95rem; }
.history-meta-grid { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 10px 14px; }
.history-meta-block { min-width: 0; }
.history-meta-label { display: block; margin-bottom: 4px; color: var(--text-muted); font-size: 11px; letter-spacing: 0.05em; text-transform: uppercase; }
.history-meta-value { color: var(--text-main); font-size: 13px; line-height: 1.45; overflow-wrap: anywhere; }
.history-files { list-style: none; margin: 0; padding: 0; display: grid; gap: 10px; }
.history-file-row { padding: 10px 12px; border: 1px solid rgba(109, 95, 74, 0.14); border-radius: 14px; background: rgba(255, 253, 248, 0.94); }
.history-file-path { display: block; font-family: "SFMono-Regular", Consolas, "Liberation Mono", monospace; font-size: 12px; color: var(--accent-ink); word-break: break-word; }
.history-file-note { margin-top: 4px; color: var(--text-muted); font-size: 12px; line-height: 1.4; }
.history-file-tag { display: inline-flex; margin-bottom: 6px; padding: 3px 8px; border-radius: 999px; background: rgba(92, 102, 112, 0.12); color: #4b5662; font-family: "Avenir Next", "Segoe UI", sans-serif; font-size: 10px; font-weight: 600; letter-spacing: 0.04em; text-transform: uppercase; }
.history-file-tag.optional { background: rgba(180, 105, 45, 0.12); color: #8e4520; }
.history-guidance-grid { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 12px; }
.history-guidance-card { padding: 14px 16px; border: 1px solid rgba(109, 95, 74, 0.16); border-radius: 16px; background: rgba(255, 253, 248, 0.94); }
.history-guidance-card h5 { margin: 0 0 8px; font-size: 0.9rem; }
.history-guidance-card p { margin: 0 0 8px; color: var(--text-main); font-size: 13px; line-height: 1.45; }
.history-guidance-card small { display: block; line-height: 1.45; }
.history-cleanup-note { color: #8e4520; font-size: 12px; line-height: 1.5; }
#history_status { white-space: pre-wrap; line-height: 1.5; font-family: "SFMono-Regular", Consolas, "Liberation Mono", monospace; font-size: 12px; }
@media (max-width: 960px) {
  body { margin: 14px; }
  .wrap { padding: 16px; }
  .grid3 { grid-template-columns: 1fr; gap: 12px; }
  .panel { padding: 14px; border-radius: 16px; }
  .app-header { flex-direction: column; }
  .app-header-actions { width: 100%; justify-content: flex-start; }
  .branch-tabs { display: flex; width: 100%; }
  .branch-tab { flex: 1; justify-content: center; }
  .ref-link-review-modal { padding: 12px; }
  .ref-link-review-dialog { width: 100%; max-height: 92vh; }
  .ref-link-review-topbar, .ref-link-review-header, .ref-link-review-toolbar, .ref-link-review-body { padding-left: 14px; padding-right: 14px; }
  .ref-link-review-topbar { align-items: flex-start; }
  .ref-link-review-topbar-summary { display: grid; }
  .ref-link-review-tray-toggle { display: inline-flex; }
  .ref-link-review-layout { grid-template-columns: 1fr; }
  .ref-link-review-tray-resize-handle { display: none; }
  .ref-link-review-tray { margin-left: 0; margin-top: 12px; }
  .ref-link-review-filter-row { grid-template-columns: 1fr; }
  .ref-link-review-filter-popover { position: static; margin-top: 6px; }
  .ref-link-review-toolbar-row { grid-template-columns: 1fr; }
  .ref-link-review-benchmark-panel { grid-template-columns: 1fr; }
  .ref-link-review-benchmark-panel label { white-space: normal; }
  .ref-link-review-toolbar-actions { justify-content: flex-start; }
  .ref-link-review-filters { grid-template-columns: 1fr; }
  .ref-link-review-details { grid-template-columns: 1fr; }
  .history-toolbar, .history-layout, .history-guidance-grid, .history-meta-grid { grid-template-columns: 1fr; }
}
</style>
</head>
<body>
<div class='wrap app-shell'>
  <div class='app-header'>
    <div class='app-header-main'>
      <h1>ADAM SSM - Sleepless Source Manager</h1>
      <p class='app-subtitle'><small>This UI validates and writes locally.</small></p>
    </div>
    <div class='app-header-actions'>
      <button id='relaunch_app_button' class='secondary' onclick='relaunchApp()'>Relaunch App</button>
      <button id='shutdown_app_button' class='warn' onclick='shutdownApp()'>Stop Server</button>
    </div>
  </div>
  <div class='branch-tabs'>
    <button id='branch_data_tab' class='branch-tab active' onclick="switchBranch('data')">Data Sources</button>
    <button id='branch_wealth_tab' class='branch-tab' onclick="switchBranch('wealth')">Wealth Research</button>
    <button id='branch_history_tab' class='branch-tab' onclick="switchBranch('history')">History</button>
    <button id='branch_maintenance_tab' class='branch-tab' onclick="switchBranch('maintenance')">Maintenance</button>
  </div>

  <div id='branch_data'>
  <div class='grid3 row panel'>
    <div>
      <label>Mode <span class='req'>*</span></label>
      <select id='mode' onchange='onModeChange()'>
        <option value='add'>add (new source)</option>
        <option value='edit'>edit (existing source)</option>
      </select>
    </div>
    <div id='editTargetWrap' class='hidden'>
      <label>Edit target (existing Source/Citekey) <span class='req'>*</span></label>
      <input id='target' list='target_opts' placeholder='Start typing an existing source'>
    </div>
  </div>

  <div id='dataSearchWrap' class='row hidden panel'>
    <div class='step'>Browse and search existing references</div>
    <div class='search-panel'>
      <label>Search by citekey/source/legend/title/author/year</label>
      <input id='data_search' placeholder='Type to filter...' oninput='dataRenderSearchResults()'>
      <div class='search-results' id='data_search_results'></div>
    </div>
  </div>

  <div id='editToolsWrap' class='row hidden panel'>
    <div class='step'>Edit tools</div>
    <div style='display:flex; gap:10px; flex-wrap:wrap;'>
      <button id='loadBtn' onclick='loadTarget()'>Load existing entry into form</button>
      <button class='warn' onclick='deleteEntry()'>Delete entry</button>
    </div>
  </div>

  <div id='dataBibPasteWrap' class='panel'>
  <details open>
    <summary><b>BibTeX Paste</b></summary>
    <div class='help' style='margin-top:8px;'>
      Paste a full BibTeX entry here (for example, from Google Scholar), then click <b>Parse BibTeX and fill fields</b>.
      Parsing copies data into the fields below and <b>overwrites those target fields</b>.
      Editing the paste box alone does nothing until Parse is clicked again.
      After parsing, any manual edits in the fields below are what will be saved.
    </div>
    <div class='row' style='margin-top:8px;'>
      <textarea id='bib_paste' placeholder='@article{Key, ...}'></textarea>
      <button class='secondary' onclick='parseBib()'>Parse BibTeX and fill fields</button>
    </div>
  </details>
  </div>

  <div class='panel'>
  <h3 class='section-heading'>Core Source Fields</h3>
  <div class='grid3'>
    <div class='row'><label>Section <span class='req'>*</span></label><input id='section' list='section_opts'></div>
    <div class='row'><label>Aggsource <span class='req'>*</span></label><input id='aggsource' list='aggsource_opts'></div>
    <div class='row'><label>Legend <span class='req'>*</span></label><input id='legend'></div>
    <div class='row' id='row_source_key'><label>Source / Citekey <span class='req'>*</span></label><input id='source_key' placeholder='Same value used as Source and citekey'></div>
    <div class='row hidden' id='row_source_value'><label>Source <span class='req'>*</span></label><input id='source_value'></div>
    <div class='row hidden' id='row_citekey_value'><label>Citekey <span class='req'>*</span></label><input id='citekey_value'></div>
    <div class='row'><label>URL / Link <span class='req'>*</span></label><input id='link'></div>
  </div>
  </div>

  <div class='panel'>
  <h3 class='section-heading'>Bib Fields</h3>
  <div class='grid3'>
    <div class='row'>
      <label>entry_type <span class='req'>*</span></label>
      <select id='bib_entry_type' onchange='onEntryTypeChange()'>
        <option value=''>select entry type</option>
        <option value='article'>article</option>
        <option value='book'>book</option>
        <option value='incollection'>incollection</option>
        <option value='inproceedings'>inproceedings</option>
        <option value='techreport'>techreport</option>
        <option value='misc'>misc</option>
        <option value='unpublished'>unpublished</option>
      </select>
    </div>
    <div class='row'><label>author <span class='req'>*</span></label><input id='bib_author' oninput='trySuggestLegend()'></div>
    <div class='row'><label>year <span class='req'>*</span></label><input id='bib_year' oninput='trySuggestLegend()'></div>
  </div>
  <div class='row'><label>title <span class='req'>*</span></label><input id='bib_title'></div>

  <details>
    <summary><b>More fields</b> (optional)</summary>
    <div class='grid3' style='margin-top:10px;'>
      <div class='row'><label>Data_type</label><input id='data_type' list='data_type_opts'></div>
      <div class='row'><label>Ref_link</label><input id='ref_link'></div>
      <div class='row'><label>Shared citekey group</label><input id='shared_citekey_group'></div>
      <div class='row'><label>Shared citekey note</label><input id='shared_citekey_note'></div>
      <div class='row'><label>Inclusion_in_Warehouse</label><input id='inclusion_in_warehouse' list='inclusion_in_warehouse_opts'></div>
      <div class='row'><label>Multigeo_Reference</label><input id='multigeo_reference'></div>
      <div class='row'><label>Metadatalink</label><input id='metadatalink'></div>
      <div class='row'><label>month</label><input id='bib_month'></div>
      <div class='row' id='row_bib_journal'><label>journal</label><input id='bib_journal'></div>
      <div class='row' id='row_bib_booktitle'><label>booktitle</label><input id='bib_booktitle'></div>
      <div class='row'><label>volume</label><input id='bib_volume'></div>
      <div class='row'><label>number</label><input id='bib_number'></div>
      <div class='row'><label>pages</label><input id='bib_pages'></div>
      <div class='row' id='row_bib_institution'><label>institution</label><input id='bib_institution'></div>
      <div class='row' id='row_bib_publisher'><label>publisher</label><input id='bib_publisher'></div>
      <div class='row'><label>doi</label><input id='bib_doi'></div>
      <div class='row hidden' id='row_bib_url'><label>bib.url</label><input id='bib_url'></div>
      <div class='row'><label>urldate</label><input id='bib_urldate'></div>
      <div class='row'><label>keywords</label><input id='bib_keywords'></div>
      <div class='row'><label>note</label><input id='bib_note'></div>
    </div>
    <div class='row'><label>Metadata</label><textarea id='metadata'></textarea></div>
    <div class='row'><label>abstract</label><textarea id='bib_abstract'></textarea></div>
  </details>
  </div>

  <div class='panel'>
  <h3 class='section-heading'>Actions</h3>
  <div class='row'>
    <div class='step'>Step 1: Check entry (validation only, no save)</div>
    <button class='secondary' onclick='validateOnly()'>Check entry</button>
  </div>
  <div class='row'>
    <div class='step'>Step 2: Save and build files locally</div>
    <small>dictionary.xlsx, GCWealthProject_DataSourcesLibrary.bib, BothLibraries.bib</small>
    <div class='row' style='max-width:420px; margin-bottom:8px;'>
      <input id='editor_name' placeholder='your name'>
    </div>
    <button class='warn' onclick='applyAndBuild()'>Save and build</button>
  </div>
  <div class='row'>
    <div class='step'>Step 3: Compare with online reference (optional)</div>
    <button class='secondary' onclick='compareOnlineBib()'>Compare</button>
  </div>
  <div class='row'>
    <div class='step'>Step 4: Review full-registry ref_link proposals (optional)</div>
    <button class='secondary' onclick='scanRefLinkReview()'>Review ref_link proposals</button>
  </div>
  </div>
  <datalist id='section_opts'></datalist>
  <datalist id='aggsource_opts'></datalist>
  <datalist id='data_type_opts'></datalist>
  <datalist id='target_opts'></datalist>
  <datalist id='inclusion_in_warehouse_opts'></datalist>

  <div class='panel'>
  <h3 class='section-heading'>Status</h3>
  <pre id='status'></pre>
  </div>
  </div>

  <div id='branch_maintenance' class='hidden'>
    <div class='panel'>
      <h3 class='section-heading'>Registry Health</h3>
      <div class='row'>
        <div style='display:flex; gap:10px; flex-wrap:wrap;'>
          <button class='secondary' onclick='maintenanceLoad()'>Refresh health scan</button>
          <button class='secondary' onclick='maintenanceRebuildArtifacts()'>Rebuild generated artifacts</button>
        </div>
      </div>
      <div id='maintenance_summary' class='help'></div>
      <div class='search-results' id='maintenance_issues'></div>
    </div>
    <div class='panel'>
      <h3 class='section-heading'>Bulk Label Update</h3>
      <div class='grid3'>
        <div class='row'>
          <label>Field</label>
          <select id='bulk_label_field' onchange='bulkLabelOnFieldChange()'>
            <option value='section'>Section</option>
            <option value='aggsource'>Aggsource</option>
            <option value='data_type'>Data type</option>
            <option value='inclusion_in_warehouse'>Inclusion in warehouse</option>
            <option value='multigeo_reference'>Multigeo reference</option>
          </select>
        </div>
        <div class='row'>
          <label>Old label</label>
          <select id='bulk_label_old' onchange='bulkLabelResetPreview()'></select>
        </div>
        <div class='row'>
          <label>New label</label>
          <input id='bulk_label_new' list='bulk_label_new_opts' oninput='bulkLabelResetPreview()'>
        </div>
      </div>
      <div class='row'>
        <div style='display:flex; gap:10px; flex-wrap:wrap;'>
          <button class='secondary' onclick='maintenanceBulkLabelPreview()'>Preview label update</button>
          <button class='secondary' onclick='maintenanceBulkLabelSelectAll(true)'>Select all</button>
          <button class='secondary' onclick='maintenanceBulkLabelSelectAll(false)'>Unselect all</button>
          <button class='warn' onclick='maintenanceBulkLabelApply()'>Apply selected label update</button>
        </div>
      </div>
      <datalist id='bulk_label_new_opts'></datalist>
      <div id='bulk_label_summary' class='help'></div>
      <div class='search-results' id='bulk_label_preview_results'></div>
    </div>
    <div class='panel'>
      <h3 class='section-heading'>Maintenance Status</h3>
      <pre id='maintenance_status'></pre>
    </div>
  </div>

  <div id='branch_wealth' class='hidden'>
    <div class='grid3 row panel'>
      <div>
        <label>Mode <span class='req'>*</span></label>
        <select id='wealth_mode' onchange='wealthOnModeChange()'>
          <option value='add'>add (new reference)</option>
          <option value='edit'>edit (existing reference)</option>
        </select>
      </div>
      <div id='wealthEditTargetWrap' class='hidden'>
        <label>Edit target (existing key) <span class='req'>*</span></label>
        <input id='wealth_target' list='wealth_target_opts' placeholder='Choose from search results below'>
      </div>
    </div>

    <div id='wealthSearchWrap' class='row hidden panel'>
      <div class='step'>Browse and search existing references</div>
      <div class='search-panel'>
        <label>Search by key/title/author/year</label>
        <input id='wealth_search' placeholder='Type to filter...' oninput='wealthRenderSearchResults()'>
        <div class='search-results' id='wealth_search_results'></div>
      </div>
    </div>

    <div id='wealthEditToolsWrap' class='row hidden panel'>
      <div class='step'>Edit tools</div>
      <div style='display:flex; gap:10px; flex-wrap:wrap;'>
        <button id='wealthLoadBtn' onclick='wealthLoadTarget()'>Load selected entry into form</button>
        <button class='warn' onclick='wealthDeleteEntry()'>Delete entry</button>
      </div>
    </div>

    <div id='wealthBibPasteWrap' class='panel'>
    <details open>
      <summary><b>BibTeX Paste</b></summary>
      <div class='help' style='margin-top:8px;'>
        Paste a full BibTeX entry, then click <b>Parse BibTeX and fill fields</b>.
        Parsed values overwrite fields below.
      </div>
      <div class='row' style='margin-top:8px;'>
        <textarea id='wealth_bib_paste' placeholder='@article{Key, ...}'></textarea>
        <button class='secondary' onclick='wealthParseBib()'>Parse BibTeX and fill fields</button>
      </div>
    </details>
    </div>

    <div class='panel'>
    <h3 class='section-heading'>Bib Fields</h3>
    <div class='grid3'>
      <div class='row'><label>Key <span class='req'>*</span></label><input id='wealth_key' placeholder='BibTeX key'></div>
      <div class='row'>
        <label>entry_type <span class='req'>*</span></label>
        <select id='wealth_entry_type' onchange='wealthOnEntryTypeChange()'>
          <option value=''>select entry type</option>
          <option value='article'>article</option>
          <option value='book'>book</option>
          <option value='incollection'>incollection</option>
          <option value='inproceedings'>inproceedings</option>
          <option value='techreport'>techreport</option>
          <option value='misc'>misc</option>
          <option value='unpublished'>unpublished</option>
          <option value='mastersthesis'>mastersthesis</option>
          <option value='phdthesis'>phdthesis</option>
        </select>
      </div>
      <div class='row'><label>author <span class='req'>*</span></label><input id='wealth_author'></div>
      <div class='row'><label>year <span class='req'>*</span></label><input id='wealth_year'></div>
      <div class='row'><label>title <span class='req'>*</span></label><input id='wealth_title'></div>
      <div class='row'><label>month</label><input id='wealth_month'></div>
      <div class='row hidden' id='wealth_row_journal'><label>journal</label><input id='wealth_journal'></div>
      <div class='row hidden' id='wealth_row_booktitle'><label>booktitle</label><input id='wealth_booktitle'></div>
      <div class='row'><label>volume</label><input id='wealth_volume'></div>
      <div class='row'><label>number</label><input id='wealth_number'></div>
      <div class='row'><label>pages</label><input id='wealth_pages'></div>
      <div class='row hidden' id='wealth_row_institution'><label>institution</label><input id='wealth_institution'></div>
      <div class='row hidden' id='wealth_row_publisher'><label>publisher</label><input id='wealth_publisher'></div>
      <div class='row'><label>doi</label><input id='wealth_doi'></div>
      <div class='row'><label>url</label><input id='wealth_url'></div>
      <div class='row'><label>urldate</label><input id='wealth_urldate'></div>
      <div class='row'><label>keywords</label><input id='wealth_keywords'></div>
      <div class='row'><label>note</label><input id='wealth_note'></div>
    </div>
    <div class='row'><label>abstract</label><textarea id='wealth_abstract'></textarea></div>
    </div>
    <input id='wealth_extra_fields' type='hidden' value='{}'>

    <div class='panel'>
    <h3 class='section-heading'>Actions</h3>
    <div class='row'>
      <div class='step'>Step 1: Check entry (validation only, no save)</div>
      <button class='secondary' onclick='wealthValidateOnly()'>Check entry</button>
    </div>
    <div class='row'>
      <div class='step'>Step 2: Save and build files locally</div>
      <small>GCWealthProject_WealthResearchLibrary.bib, BothLibraries.bib</small>
      <div class='row' style='max-width:420px; margin-bottom:8px;'>
        <input id='wealth_editor_name' placeholder='your name'>
      </div>
      <button class='warn' onclick='wealthApplyAndBuild()'>Save entry and rebuild</button>
    </div>
    <div class='row'>
      <div class='step'>Step 3: Compare with online reference (optional)</div>
      <button class='secondary' onclick='wealthCompareOnlineBib()'>Compare</button>
    </div>
    </div>

    <div class='panel'>
    <h3 class='section-heading'>Status</h3>
    <pre id='wealth_status'></pre>
    </div>
    <datalist id='wealth_target_opts'></datalist>
  </div>

  <div id='branch_history' class='hidden'>
    <div class='panel'>
      <h3 class='section-heading'>History</h3>
      <div class='help'>Browse history, identify the point before a change, and use external file history in GitHub or Dropbox to restore earlier versions. Recommended: keep history intact. Remove history records only for testing or development cleanup.</div>
    </div>

    <div id='history_summary_strip' class='history-summary-strip'></div>

    <div class='panel'>
      <div class='history-toolbar'>
        <div>
          <label>Show Changes Up To</label>
          <input id='history_show_before' type='datetime-local' onchange='renderHistoryView()'>
        </div>
        <div>
          <label>Branch</label>
          <select id='history_branch_filter' onchange='renderHistoryView()'>
            <option value=''>All branches</option>
            <option value='data_sources'>Data Sources</option>
            <option value='wealth_research'>Wealth Research</option>
          </select>
        </div>
        <div>
          <label>Action</label>
          <select id='history_action_filter' onchange='renderHistoryView()'>
            <option value=''>All actions</option>
            <option value='Add'>Add</option>
            <option value='Edit'>Edit</option>
            <option value='Delete'>Delete</option>
            <option value='Ref link review'>Ref link review</option>
          </select>
        </div>
        <div>
          <label>Search</label>
          <input id='history_search' placeholder='record id, actor, reason, file path' oninput='renderHistoryView()'>
        </div>
      </div>
      <div class='history-filter-actions' style='margin-top:12px;'>
        <button class='secondary' onclick='historyClearFilters()'>Clear filters</button>
        <button class='secondary' onclick='historyLoad()'>Refresh history</button>
      </div>
    </div>

    <div class='history-layout'>
      <div class='panel'>
        <h3 class='section-heading'>Timeline</h3>
        <div id='history_list' class='history-list'></div>
      </div>
      <div class='panel'>
        <h3 class='section-heading'>Change Detail</h3>
        <div id='history_detail' class='history-detail-empty'>Select a history record to inspect the affected files and restore guidance.</div>
      </div>
    </div>

    <div class='panel'>
      <h3 class='section-heading'>Status</h3>
      <pre id='history_status'></pre>
    </div>
  </div>
</div>

<div id='ref_link_review_modal' class='ref-link-review-modal hidden' onclick='if (event.target === this) closeRefLinkReviewModal()'>
  <div class='ref-link-review-dialog' role='dialog' aria-modal='true' aria-labelledby='ref_link_review_title'>
    <div class='ref-link-review-sticky'>
      <div id='ref_link_review_topbar' class='ref-link-review-topbar'>
        <div id='ref_link_review_topbar_summary' class='ref-link-review-topbar-summary'>
          <h3 id='ref_link_review_title' class='section-heading ref-link-review-title-line'>Ref_link review</h3>
          <div id='ref_link_review_summary'></div>
          <div id='ref_link_review_topbar_status_line' class='ref-link-review-topbar-status-line'></div>
          <div id='ref_link_review_scan_status' class='ref-link-review-scan-status'>
            <div class='ref-link-review-scan-meta'>
              <div class='step'>Scan status</div>
              <small id='ref_link_review_scan_progress_label'>Run a scan to review ref_link proposals.</small>
            </div>
            <div id='ref_link_review_scan_progress' class='ref-link-review-scan-progress'>
              <div id='ref_link_review_scan_progress_fill' class='ref-link-review-scan-progress-fill'></div>
            </div>
          </div>
        </div>
        <div class='ref-link-review-header-actions'>
          <button id='ref_link_review_tray_toggle_button' class='secondary ref-link-review-tray-toggle' onclick='toggleRefLinkReviewTrayOpen()'>Tools</button>
          <button id='ref_link_review_refresh_button' class='secondary' onclick='scanRefLinkReview()'>Refresh scan</button>
          <button id='ref_link_review_apply_button' class='warn' onclick='applySelectedRefLinkReview()'>Apply selected</button>
          <button id='ref_link_review_close' class='secondary' onclick='closeRefLinkReviewModal()'>Close</button>
        </div>
      </div>
    </div>
    <div id='ref_link_review_panel' class='ref-link-review-body'>
      <div class='ref-link-review-layout'>
        <div class='ref-link-review-main'>
          <div id='ref_link_review_workspace'></div>
        </div>
        <div id='ref_link_review_tray_resize_handle' class='ref-link-review-tray-resize-handle' onmousedown='beginRefLinkReviewTrayResize(event)'></div>
        <aside id='ref_link_review_tray' class='ref-link-review-tray'>
          <div id='ref_link_review_tray_sections' class='ref-link-review-tray-sections'>
            <section id='ref_link_review_tray_section_filters' class='ref-link-review-tray-section'>
              <button id='ref_link_review_tray_section_header_filters' class='ref-link-review-tray-section-header' onclick='toggleRefLinkReviewTraySection("filters")'>
                <span class='ref-link-review-tray-section-heading'>Filters</span>
                <span id='ref_link_review_tray_section_summary_filters' class='ref-link-review-tray-section-summary'></span>
              </button>
              <div id='ref_link_review_tray_section_body_filters' class='ref-link-review-tray-section-body'>
                <div class='ref-link-review-filter-row'>
                  <div class='ref-link-review-filter-popover-wrap'>
                    <button id='ref_link_review_filter_button_status' class='secondary ref-link-review-filter-trigger' onclick='toggleRefLinkReviewFilterPopover("status")'>Status</button>
                    <div id='ref_link_review_filter_popover_status' class='ref-link-review-filter-popover hidden'></div>
                  </div>
                  <div class='ref-link-review-filter-popover-wrap'>
                    <button id='ref_link_review_filter_button_confidence' class='secondary ref-link-review-filter-trigger' onclick='toggleRefLinkReviewFilterPopover("confidence")'>Confidence</button>
                    <div id='ref_link_review_filter_popover_confidence' class='ref-link-review-filter-popover hidden'></div>
                  </div>
                  <div class='ref-link-review-filter-popover-wrap'>
                    <button id='ref_link_review_filter_button_reason' class='secondary ref-link-review-filter-trigger' onclick='toggleRefLinkReviewFilterPopover("reason")'>Reason</button>
                    <div id='ref_link_review_filter_popover_reason' class='ref-link-review-filter-popover hidden'></div>
                  </div>
                </div>
                <div id='ref_link_review_visible_summary' class='ref-link-review-toolbar-summary ref-link-review-visible-summary'></div>
              </div>
            </section>
            <section id='ref_link_review_tray_section_benchmark' class='ref-link-review-tray-section'>
              <button id='ref_link_review_tray_section_header_benchmark' class='ref-link-review-tray-section-header' onclick='toggleRefLinkReviewTraySection("benchmark")'>
                <span class='ref-link-review-tray-section-heading'>Benchmark</span>
                <span id='ref_link_review_tray_section_summary_benchmark' class='ref-link-review-tray-section-summary'></span>
              </button>
              <div id='ref_link_review_tray_section_body_benchmark' class='ref-link-review-tray-section-body'>
                <div class='ref-link-review-toolbar-note'>
                  This window compares stored registry <b>ref_link</b> values against a benchmark BibBase profile.
                </div>
                <div class='ref-link-review-benchmark-panel'>
                  <label for='ref_link_review_benchmark_url'>Benchmark URL</label>
                  <div class='ref-link-review-benchmark-inputs'>
                    <input
                      id='ref_link_review_benchmark_url'
                      placeholder='https://bibbase.org/f/.../GCWealthProject_DataSourcesLibrary.bib'
                      oninput='updateRefLinkReviewBenchmarkUrl(this.value)'
                      onchange='renderRefLinkReviewPanel()'
                    >
                    <div class='ref-link-review-benchmark-actions'>
                      <button class='secondary' onclick='resetRefLinkReviewBenchmarkUrl()'>Use configured benchmark</button>
                    </div>
                  </div>
                  <div id='ref_link_review_benchmark_note' class='ref-link-review-benchmark-meta'></div>
                </div>
              </div>
            </section>
            <section id='ref_link_review_tray_section_actions' class='ref-link-review-tray-section'>
              <button id='ref_link_review_tray_section_header_actions' class='ref-link-review-tray-section-header' onclick='toggleRefLinkReviewTraySection("actions")'>
                <span class='ref-link-review-tray-section-heading'>Bulk actions</span>
                <span id='ref_link_review_tray_section_summary_actions' class='ref-link-review-tray-section-summary'></span>
              </button>
              <div id='ref_link_review_tray_section_body_actions' class='ref-link-review-tray-section-body'>
                <div class='ref-link-review-toolbar-note'>Bulk actions apply only to the rows currently visible.</div>
                <div class='ref-link-review-toolbar-actions'>
                  <button class='secondary' onclick='clearRefLinkReviewFilters()'>Clear filters</button>
                  <button id='ref_link_review_select_visible_button' class='secondary' onclick='selectVisibleRefLinkReview()'>Select visible</button>
                  <button id='ref_link_review_unselect_visible_button' class='secondary' onclick='unselectVisibleRefLinkReview()'>Unselect visible</button>
                  <button id='ref_link_review_dismiss_button' class='secondary' onclick='dismissSelectedRefLinkReview()'>Dismiss selected</button>
                  <button id='ref_link_review_restore_button' class='secondary' onclick='restoreSelectedRefLinkReview()'>Restore selected</button>
                </div>
              </div>
            </section>
            <section id='ref_link_review_tray_section_help' class='ref-link-review-tray-section'>
              <button id='ref_link_review_tray_section_header_help' class='ref-link-review-tray-section-header' onclick='toggleRefLinkReviewTraySection("help")'>
                <span class='ref-link-review-tray-section-heading'>Help</span>
                <span id='ref_link_review_tray_section_summary_help' class='ref-link-review-tray-section-summary'></span>
              </button>
              <div id='ref_link_review_tray_section_body_help' class='ref-link-review-tray-section-body'>
                <div class='ref-link-review-toolbar-summary'>Use the tray to adjust filters, benchmark settings, and bulk actions without taking height away from the review table.</div>
              </div>
            </section>
          </div>
        </aside>
      </div>
    </div>
    <div id='ref_link_review_modal_resize_handle' class='ref-link-review-dialog-resize-handle' onmousedown='beginRefLinkReviewModalResize(event)'></div>
  </div>
</div>

<script>
function v(id){ return document.getElementById(id).value || ''; }
function setStatus(obj, targetId='status'){
  const el = document.getElementById(targetId);
  if (!el) return;
  el.textContent = typeof obj === 'string' ? obj : JSON.stringify(obj, null, 2);
}
function wv(id){ return document.getElementById(id).value || ''; }
function escapeHtml(s){
  return String(s || '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}
function statusClassForLine(line){
  if (line.startsWith('Overall result: PASSED') || line.startsWith('- Status: up_to_date')) return 'status-ok';
  if (line.startsWith('Overall result: FAILED') || line.startsWith('- Status: unavailable') || line.startsWith('- Status: not_configured')) return 'status-fail';
  if (line.startsWith('- Status: different')) return 'status-warn';
  return '';
}
function diffClassForLine(line){
  if (line.startsWith('+++') || line.startsWith('---') || line.startsWith('diff --git')) return 'git-file';
  if (line.startsWith('@@')) return 'git-hunk';
  if (line.startsWith('+') && !line.startsWith('+++')) return 'git-add';
  if (line.startsWith('-') && !line.startsWith('---')) return 'git-del';
  return '';
}
function setStatusColored(text, targetId='status'){
  const el = document.getElementById(targetId);
  if (!el) return;
  const lines = String(text || '').split('\\n');
  let inUnifiedDiff = false;
  el.innerHTML = lines.map((line) => {
    if (line.startsWith('Unified diff (online -> local):')) {
      inUnifiedDiff = true;
    }
    const cls = inUnifiedDiff ? diffClassForLine(line) : statusClassForLine(line);
    const body = escapeHtml(line);
    return cls ? `<span class=\"${cls}\">${body}</span>` : body;
  }).join('\\n');
}
function showErrorWindow(msg){
  alert(`There are validation errors:\\n\\n${msg}`);
}
let activeBranch = 'data';
let dirty = false;
let loadedSourceKey = '';
let loadedSourceValue = '';
let loadedCitekeyValue = '';
function markDirty(){ dirty = true; }
function clearDirty(){ dirty = false; }
let wealthDirty = false;
let wealthLoadedKey = '';
let wealthEntries = [];
let dataEntries = [];
let historyEntries = [];
let historySummary = {};
let historySelectedId = '';
let historyCleanupReason = '';
let maintenanceIssues = [];
let bulkLabelState = {values: {}, preview: null, selectedIds: new Set()};
let isRelaunching = false;
const REF_LINK_REVIEW_STORAGE_PREFIX = 'adam-ssm-ref-link-review';
function defaultRefLinkReviewColumnWidths(){
  return {
    select: 68,
    citekey: 150,
    status: 130,
    current_ref_link: 190,
    proposed_ref_link: 200,
    confidence: 120,
    reason: 250,
    action: 160,
  };
}
function defaultRefLinkReviewScanStatus(){
  return {
    stage: 'idle',
    checked: 0,
    total: 0,
    message: 'Run a scan to review ref_link proposals.',
    error: '',
  };
}
function refLinkReviewStorageKey(suffix){
  return `${REF_LINK_REVIEW_STORAGE_PREFIX}-${suffix}`;
}
function refLinkReviewReadStorage(key, fallbackValue){
  try {
    const raw = window.localStorage.getItem(refLinkReviewStorageKey(key));
    return raw === null ? fallbackValue : raw;
  } catch (err) {
    return fallbackValue;
  }
}
function refLinkReviewWriteStorage(key, value){
  try {
    if (value === null || value === undefined || value === '') {
      window.localStorage.removeItem(refLinkReviewStorageKey(key));
      return;
    }
    window.localStorage.setItem(refLinkReviewStorageKey(key), String(value));
  } catch (err) {
    // Ignore storage failures in the local UI.
  }
}
function emptyRefLinkReviewState(previousState){
  const previous = previousState || {};
  return {
    ready_to_apply: [],
    needs_review: [],
    dismissed: [],
    summary: {},
    scan_metadata: {},
    selected: new Set(),
    filters: {
      status: new Set(),
      confidence: new Set(),
      reason: new Set(),
    },
    overrides: {},
    expanded: new Set(),
    modal_open: false,
    scan_id: '',
    scan_status: defaultRefLinkReviewScanStatus(),
    column_widths: {
      ...defaultRefLinkReviewColumnWidths(),
      ...(previous.column_widths || {}),
    },
    benchmark_url: String(previous.benchmark_url || previous.default_benchmark_url || ''),
    default_benchmark_url: String(previous.default_benchmark_url || ''),
    tray_width: Number(previous.tray_width || refLinkReviewReadStorage('tray-width', 320)),
    active_tray_section: String(previous.active_tray_section || refLinkReviewReadStorage('active-tray-section', 'filters')),
    tray_open: previous.tray_open !== false && refLinkReviewReadStorage('tray-open', '1') !== '0',
    active_filter_popover: String(previous.active_filter_popover || ''),
    modal_width: Number(previous.modal_width || refLinkReviewReadStorage('modal-width', 1500)),
    modal_height: Number(previous.modal_height || refLinkReviewReadStorage('modal-height', 0)),
  };
}
let refLinkReviewState = emptyRefLinkReviewState();
let refLinkReviewResizeState = null;
let refLinkReviewTrayResizeState = null;
let refLinkReviewModalResizeState = null;
function markWealthDirty(){ wealthDirty = true; }
function clearWealthDirty(){ wealthDirty = false; }

function allRefLinkReviewRows(){
  return [
    ...(refLinkReviewState.ready_to_apply || []),
    ...(refLinkReviewState.needs_review || []),
    ...(refLinkReviewState.dismissed || []),
  ];
}

function refLinkReviewStatusLabel(status){
  const value = String(status || '').trim();
  if (value === 'ready_to_apply') return 'Ready to apply';
  if (value === 'needs_review') return 'Needs review';
  if (value === 'dismissed') return 'Dismissed';
  return value || 'Unknown';
}

function refLinkReviewReasonLabel(reason){
  const value = String(reason || '').trim();
  if (!value) return 'Unknown';
  return value
    .replace(/[_-]+/g, ' ')
    .toLowerCase()
    .replace(/\b([a-z])/g, (match, chr) => chr.toUpperCase());
}

function refLinkReviewStatusClass(status){
  const value = String(status || '').trim();
  if (value === 'ready_to_apply') return 'ready-to-apply';
  if (value === 'needs_review') return 'needs-review';
  if (value === 'dismissed') return 'dismissed';
  return '';
}

function normalizeRefLinkReviewScanStatus(payload){
  const total = Math.max(0, Number(payload && payload.total ? payload.total : 0));
  const checkedRaw = Math.max(0, Number(payload && payload.checked ? payload.checked : 0));
  const checked = total ? Math.min(checkedRaw, total) : checkedRaw;
  return {
    stage: String((payload && payload.stage) || 'idle'),
    checked,
    total,
    message: String((payload && payload.message) || ''),
    error: String((payload && payload.error) || ''),
  };
}

function refLinkReviewIsScanning(){
  const stage = String((refLinkReviewState.scan_status || {}).stage || '');
  return stage === 'fetching_live_bibbase' || stage === 'comparing_registry';
}

function refLinkReviewOverrideLooksValid(value){
  const trimmed = String(value || '').trim();
  return !trimmed || /^https?:\/\//i.test(trimmed);
}

function refLinkReviewCurrentOverride(proposalId){
  if (!proposalId) return '';
  if (!Object.prototype.hasOwnProperty.call(refLinkReviewState.overrides || {}, proposalId)) return '';
  return String(refLinkReviewState.overrides[proposalId] || '');
}

function refLinkReviewCurrentBenchmarkUrl(){
  return String(
    ((refLinkReviewState.scan_metadata || {}).profile_source_url) ||
    refLinkReviewState.default_benchmark_url ||
    refLinkReviewState.benchmark_url ||
    ''
  ).trim();
}

function toggleRefLinkReviewTraySection(section){
  const nextSection = String(section || '').trim() || 'filters';
  refLinkReviewState.active_tray_section = nextSection;
  refLinkReviewWriteStorage('active-tray-section', nextSection);
  renderRefLinkReviewPanel();
}

function toggleRefLinkReviewFilterPopover(kind){
  const nextKind = String(kind || '').trim();
  refLinkReviewState.active_filter_popover = refLinkReviewState.active_filter_popover === nextKind ? '' : nextKind;
  renderRefLinkReviewPanel();
}

function refLinkReviewTrayIsPinned(){
  return window.innerWidth > 960;
}

function refLinkReviewClampTrayWidth(width){
  return Math.max(260, Math.min(520, Number(width || 320)));
}

function refLinkReviewClampModalWidth(width){
  return Math.max(980, Math.min(window.innerWidth - 24, Number(width || 1500)));
}

function refLinkReviewClampModalHeight(height){
  if (!height) return 0;
  return Math.max(560, Math.min(window.innerHeight - 24, Number(height || 0)));
}

function beginRefLinkReviewTrayResize(event){
  if (!refLinkReviewTrayIsPinned() || !event) return;
  event.preventDefault();
  refLinkReviewTrayResizeState = {
    startX: Number(event.clientX || 0),
    startWidth: refLinkReviewClampTrayWidth(refLinkReviewState.tray_width || 320),
  };
}

function beginRefLinkReviewModalResize(event){
  if (!event) return;
  event.preventDefault();
  const dialogEl = document.querySelector('.ref-link-review-dialog');
  const rect = dialogEl ? dialogEl.getBoundingClientRect() : {width: refLinkReviewClampModalWidth(refLinkReviewState.modal_width), height: refLinkReviewClampModalHeight(refLinkReviewState.modal_height || window.innerHeight * 0.92)};
  refLinkReviewModalResizeState = {
    startX: Number(event.clientX || 0),
    startY: Number(event.clientY || 0),
    startWidth: Number(rect.width || refLinkReviewClampModalWidth(refLinkReviewState.modal_width)),
    startHeight: Number(rect.height || refLinkReviewClampModalHeight(refLinkReviewState.modal_height || window.innerHeight * 0.92)),
  };
}

function applyRefLinkReviewTrayWidth(){
  const layoutEl = document.querySelector('.ref-link-review-layout');
  const trayEl = document.getElementById('ref_link_review_tray');
  const resizeHandleEl = document.getElementById('ref_link_review_tray_resize_handle');
  if (!layoutEl || !trayEl || !resizeHandleEl) return;
  if (!refLinkReviewTrayIsPinned() || !refLinkReviewState.tray_open) {
    layoutEl.style.gridTemplateColumns = '1fr';
    trayEl.style.display = refLinkReviewState.tray_open ? '' : 'none';
    resizeHandleEl.style.display = 'none';
    return;
  }
  const width = refLinkReviewClampTrayWidth(refLinkReviewState.tray_width || 320);
  refLinkReviewState.tray_width = width;
  layoutEl.style.gridTemplateColumns = `minmax(0, 1fr) 12px ${width}px`;
  trayEl.style.display = '';
  resizeHandleEl.style.display = '';
}

function applyRefLinkReviewModalSize(){
  const dialogEl = document.querySelector('.ref-link-review-dialog');
  if (!dialogEl) return;
  const width = refLinkReviewClampModalWidth(refLinkReviewState.modal_width || 1500);
  const height = refLinkReviewClampModalHeight(refLinkReviewState.modal_height || Math.round(window.innerHeight * 0.92));
  dialogEl.style.width = `min(96vw, ${width}px)`;
  dialogEl.style.height = `${height}px`;
  dialogEl.style.maxHeight = `${height}px`;
}

function toggleRefLinkReviewTrayOpen(){
  refLinkReviewState.tray_open = !refLinkReviewState.tray_open;
  refLinkReviewWriteStorage('tray-open', refLinkReviewState.tray_open ? '1' : '0');
  renderRefLinkReviewPanel();
}

function hydrateRefLinkReviewState(review, previousState){
  const ready = (Array.isArray(review.ready_to_apply) ? review.ready_to_apply : []).map((row) => ({
    ...row,
    status: String((row && row.status) || 'ready_to_apply'),
  }));
  const needs = (Array.isArray(review.needs_review) ? review.needs_review : []).map((row) => ({
    ...row,
    status: String((row && row.status) || 'needs_review'),
  }));
  const selected = new Set();
  [...ready, ...needs].forEach((row) => {
    if (row && row.selected && row.proposal_id) selected.add(row.proposal_id);
  });
  const next = emptyRefLinkReviewState(previousState);
  next.ready_to_apply = ready;
  next.needs_review = needs;
  next.summary = review.summary || {};
  next.scan_metadata = review.scan_metadata || {};
  next.selected = selected;
  next.modal_open = true;
  next.benchmark_url = String(((next.scan_metadata || {}).profile_source_url) || next.benchmark_url || '');
  return next;
}

function startRefLinkReviewScanState(scanPayload){
  const next = emptyRefLinkReviewState(refLinkReviewState);
  next.modal_open = true;
  next.scan_id = String((scanPayload && scanPayload.scan_id) || '');
  next.scan_status = normalizeRefLinkReviewScanStatus(scanPayload || defaultRefLinkReviewScanStatus());
  refLinkReviewState = next;
}

function applyRefLinkReviewScanStatus(statusPayload){
  if (!statusPayload) return;
  const scanId = String(statusPayload.scan_id || '');
  if (scanId && refLinkReviewState.scan_id && scanId !== refLinkReviewState.scan_id) return;
  const nextStatus = normalizeRefLinkReviewScanStatus(statusPayload);
  if (statusPayload.review) {
    const hydrated = hydrateRefLinkReviewState(statusPayload.review, refLinkReviewState);
    hydrated.scan_id = scanId || refLinkReviewState.scan_id;
    hydrated.scan_status = nextStatus;
    refLinkReviewState = hydrated;
  } else {
    refLinkReviewState.scan_id = scanId || refLinkReviewState.scan_id;
    refLinkReviewState.scan_status = nextStatus;
  }
}

function openRefLinkReviewModal(){
  refLinkReviewState.modal_open = true;
  const modal = document.getElementById('ref_link_review_modal');
  if (modal) modal.classList.remove('hidden');
  document.body.classList.add('modal-open');
}

function closeRefLinkReviewModal(){
  refLinkReviewState.modal_open = false;
  const modal = document.getElementById('ref_link_review_modal');
  if (modal) modal.classList.add('hidden');
  document.body.classList.remove('modal-open');
}

function setRefLinkReviewMultiSelectValues(selectEl, values){
  if (!selectEl) return;
  const selectedValues = values instanceof Set ? values : new Set(values || []);
  Array.from(selectEl.options || []).forEach((option) => {
    option.selected = selectedValues.has(String(option.value || ''));
  });
}

function refLinkReviewFilterValues(kind){
  if (kind === 'status') {
    const present = new Set(
      allRefLinkReviewRows()
        .map((row) => String((row && row.status) || '').trim())
        .filter(Boolean)
    );
    return ['ready_to_apply', 'needs_review', 'dismissed'].filter((status) => present.has(status));
  }
  const values = new Set();
  allRefLinkReviewRows().forEach((row) => {
    if (!row) return;
    if (kind === 'confidence') {
      const value = String(row.confidence || '').trim();
      if (value) values.add(value);
      return;
    }
    const flags = Array.isArray(row.reason_flags) ? row.reason_flags : [];
    flags.forEach((flag) => {
      const value = String(flag || '').trim();
      if (value) values.add(value);
    });
  });
  return [...values].sort((a, b) => String(a).localeCompare(String(b)));
}

function rowMatchesRefLinkReviewFilters(row){
  if (!row) return false;
  const statusFilters = refLinkReviewState.filters.status || new Set();
  const rowStatus = String(row.status || '').trim();
  if (statusFilters.size && !statusFilters.has(rowStatus)) return false;
  const confidenceFilters = refLinkReviewState.filters.confidence || new Set();
  const rowConfidence = String(row.confidence || '').trim();
  if (confidenceFilters.size && !confidenceFilters.has(rowConfidence)) return false;
  const reasonFilters = refLinkReviewState.filters.reason || new Set();
  if (reasonFilters.size) {
    const flags = new Set(
      (Array.isArray(row.reason_flags) ? row.reason_flags : [])
        .map((flag) => String(flag || '').trim())
        .filter(Boolean)
    );
    let matched = false;
    reasonFilters.forEach((flag) => {
      if (flags.has(flag)) matched = true;
    });
    if (!matched) return false;
  }
  return true;
}

function filteredRefLinkReviewRows(){
  return allRefLinkReviewRows().filter((row) => rowMatchesRefLinkReviewFilters(row));
}

function pruneRefLinkReviewSelectionToVisible(){
  const visibleIds = new Set(
    filteredRefLinkReviewRows()
      .map((row) => String((row && row.proposal_id) || ''))
      .filter(Boolean)
  );
  [...refLinkReviewState.selected].forEach((proposalId) => {
    if (!visibleIds.has(proposalId)) refLinkReviewState.selected.delete(proposalId);
  });
}

function updateRefLinkReviewFilterFromSelect(kind, selectEl){
  if (!refLinkReviewState.filters[kind] || !selectEl) return;
  refLinkReviewState.filters[kind] = new Set(
    Array.from(selectEl.selectedOptions || [])
      .map((option) => String(option.value || '').trim())
      .filter(Boolean)
  );
  pruneRefLinkReviewSelectionToVisible();
  renderRefLinkReviewPanel();
}

function updateRefLinkReviewFilterOption(kind, value, checked){
  const filters = refLinkReviewState.filters[kind];
  const nextValue = String(value || '').trim();
  if (!filters || !nextValue) return;
  if (checked) filters.add(nextValue);
  else filters.delete(nextValue);
  pruneRefLinkReviewSelectionToVisible();
  renderRefLinkReviewPanel();
}

function clearRefLinkReviewFilters(){
  refLinkReviewState.filters.status.clear();
  refLinkReviewState.filters.confidence.clear();
  refLinkReviewState.filters.reason.clear();
  pruneRefLinkReviewSelectionToVisible();
  renderRefLinkReviewPanel();
}

function toggleRefLinkReviewSelection(proposalId, checked){
  if (!proposalId) return;
  if (checked) refLinkReviewState.selected.add(proposalId);
  else refLinkReviewState.selected.delete(proposalId);
  renderRefLinkReviewPanel();
}

function selectVisibleRefLinkReview(){
  filteredRefLinkReviewRows().forEach((row) => {
    if (row && row.proposal_id) refLinkReviewState.selected.add(row.proposal_id);
  });
  renderRefLinkReviewPanel();
}

function unselectVisibleRefLinkReview(){
  filteredRefLinkReviewRows().forEach((row) => {
    if (row && row.proposal_id) refLinkReviewState.selected.delete(row.proposal_id);
  });
  renderRefLinkReviewPanel();
}

function dismissRefLinkReviewProposal(proposalId, rerender=true){
  if (!proposalId) return;
  const buckets = ['ready_to_apply', 'needs_review'];
  for (const bucket of buckets) {
    const rows = refLinkReviewState[bucket] || [];
    const idx = rows.findIndex((row) => row.proposal_id === proposalId);
    if (idx >= 0) {
      const [row] = rows.splice(idx, 1);
      row.dismissed_from = row.dismissed_from || row.status || bucket;
      row.status = 'dismissed';
      refLinkReviewState.dismissed.push(row);
      refLinkReviewState.selected.delete(proposalId);
      break;
    }
  }
  if (rerender) renderRefLinkReviewPanel();
}

function restoreRefLinkReviewProposal(proposalId, rerender=true){
  if (!proposalId) return;
  const rows = refLinkReviewState.dismissed || [];
  const idx = rows.findIndex((row) => row.proposal_id === proposalId);
  if (idx >= 0) {
    const [row] = rows.splice(idx, 1);
    const bucket = row.dismissed_from || 'needs_review';
    delete row.dismissed_from;
    row.status = bucket;
    refLinkReviewState[bucket] = refLinkReviewState[bucket] || [];
    refLinkReviewState[bucket].push(row);
  }
  if (rerender) renderRefLinkReviewPanel();
}

function dismissSelectedRefLinkReview(){
  const ids = filteredRefLinkReviewRows()
    .filter((row) => row && row.status !== 'dismissed' && row.proposal_id && refLinkReviewState.selected.has(row.proposal_id))
    .map((row) => row.proposal_id);
  ids.forEach((proposalId) => dismissRefLinkReviewProposal(proposalId, false));
  renderRefLinkReviewPanel();
}

function restoreSelectedRefLinkReview(){
  const ids = filteredRefLinkReviewRows()
    .filter((row) => row && row.status === 'dismissed' && row.proposal_id && refLinkReviewState.selected.has(row.proposal_id))
    .map((row) => row.proposal_id);
  ids.forEach((proposalId) => restoreRefLinkReviewProposal(proposalId, false));
  renderRefLinkReviewPanel();
}

function toggleRefLinkReviewDetails(proposalId){
  if (!proposalId) return;
  if (refLinkReviewState.expanded.has(proposalId)) refLinkReviewState.expanded.delete(proposalId);
  else refLinkReviewState.expanded.add(proposalId);
  renderRefLinkReviewPanel();
}

function updateRefLinkReviewOverride(proposalId, value){
  if (!proposalId) return;
  const nextValue = String(value || '').trim();
  if (nextValue) refLinkReviewState.overrides[proposalId] = nextValue;
  else delete refLinkReviewState.overrides[proposalId];
}

function updateRefLinkReviewBenchmarkUrl(value){
  refLinkReviewState.benchmark_url = String(value || '');
}

function resetRefLinkReviewBenchmarkUrl(){
  refLinkReviewState.benchmark_url = String(refLinkReviewState.default_benchmark_url || '');
  renderRefLinkReviewPanel();
}

function shortenRefLinkReviewUrl(url){
  const value = String(url || '').replace(/^https?:\/\//i, '');
  if (value.length <= 72) return value;
  return `${value.slice(0, 48)}...${value.slice(-18)}`;
}

function renderRefLinkReviewUrl(url){
  const value = String(url || '').trim();
  if (!value) return '<span class="ref-link-review-empty">(blank)</span>';
  if (!/^https?:\/\//i.test(value)) return `<span class="ref-link-review-empty">${escapeHtml(value)}</span>`;
  const safeValue = escapeHtml(value);
  return `<a class="ref_link_review_link ref-link-review-link" href="${safeValue}" target="_blank" rel="noopener noreferrer" title="${safeValue}">${escapeHtml(shortenRefLinkReviewUrl(value))}</a>`;
}

function renderRefLinkReviewReasonFlags(reasonFlags){
  const flags = (Array.isArray(reasonFlags) ? reasonFlags : []).filter(Boolean);
  if (!flags.length) return '<span class="ref-link-review-empty">None</span>';
  return `<div class="ref-link-review-reasons">${flags.map((flag) => `<span class="ref-link-review-reason">${escapeHtml(flag)}</span>`).join('')}</div>`;
}

function renderRefLinkReviewDetailBlock(label, valueHtml){
  return `
    <div class="ref-link-review-detail-block">
      <span class="ref-link-review-detail-label">${escapeHtml(label)}</span>
      <div class="ref-link-review-detail-value">${valueHtml || '<span class="ref-link-review-empty">(blank)</span>'}</div>
    </div>
  `;
}

function refLinkReviewEffectiveProposal(row){
  const override = refLinkReviewCurrentOverride(row && row.proposal_id);
  return override || String((row && row.proposed_ref_link) || '');
}

function renderRefLinkReviewProposedCell(row){
  const override = refLinkReviewCurrentOverride(row && row.proposal_id);
  const effective = refLinkReviewEffectiveProposal(row);
  let note = '';
  if (override) {
    note = refLinkReviewOverrideLooksValid(override)
      ? '<small>Edited in this session</small>'
      : '<small>Edited in this session, but the override is not a valid HTTP(S) URL yet.</small>';
  }
  return `<div class="ref-link-review-proposed-cell">${renderRefLinkReviewUrl(effective)}${note}</div>`;
}

function refLinkReviewColumnMinWidth(column){
  const mins = {
    select: 64,
    citekey: 120,
    status: 110,
    current_ref_link: 150,
    proposed_ref_link: 165,
    confidence: 110,
    reason: 210,
    action: 150,
  };
  return mins[column] || 120;
}

function refLinkReviewColumnStyle(column){
  const width = Number((refLinkReviewState.column_widths || {})[column] || refLinkReviewColumnMinWidth(column));
  return `style="width:${width}px; min-width:${width}px;"`;
}

function applyRefLinkReviewColumnWidths(){
  Object.keys(refLinkReviewState.column_widths || {}).forEach((column) => {
    const width = Number(refLinkReviewState.column_widths[column] || refLinkReviewColumnMinWidth(column));
    document.querySelectorAll(`[data-ref-link-review-col="${column}"]`).forEach((el) => {
      el.style.width = `${width}px`;
      el.style.minWidth = `${width}px`;
    });
  });
}

function beginRefLinkReviewColumnResize(column, event){
  if (!column || !event) return;
  event.preventDefault();
  const startWidth = Number((refLinkReviewState.column_widths || {})[column] || refLinkReviewColumnMinWidth(column));
  refLinkReviewResizeState = {
    column,
    startX: Number(event.clientX || 0),
    startWidth,
  };
}

function renderRefLinkReviewHeaderCell(label, column){
  return `
    <th data-ref-link-review-col="${escapeHtml(column)}" ${refLinkReviewColumnStyle(column)}>
      <span>${escapeHtml(label)}</span>
      <span class="ref_link_review_resize_handle ref-link-review-resize-handle" onmousedown='beginRefLinkReviewColumnResize(${JSON.stringify(column)}, event)'></span>
    </th>
  `;
}

function renderRefLinkReviewStatus(status){
  const label = refLinkReviewStatusLabel(status);
  const statusClass = refLinkReviewStatusClass(status);
  return `<span class="ref-link-review-status ${statusClass}">${escapeHtml(label)}</span>`;
}

function renderRefLinkReviewFilterSummary(kind, values){
  const selectedCount = (refLinkReviewState.filters[kind] || new Set()).size;
  if (!values.length) return 'No values available in this scan.';
  if (selectedCount) return `${selectedCount} selected. Hold Command/Ctrl to change multiple selections.`;
  return 'Showing all values. Hold Command/Ctrl to select multiple values.';
}

function renderRefLinkReviewSelectOptions(selectEl, kind, values, formatter){
  if (!selectEl) return;
  const activeValues = refLinkReviewState.filters[kind] || new Set();
  const availableValues = new Set(values);
  [...activeValues].forEach((value) => {
    if (!availableValues.has(value)) activeValues.delete(value);
  });
  if (!values.length) {
    activeValues.clear();
    selectEl.disabled = true;
    selectEl.innerHTML = '<option value="" disabled>(No values available)</option>';
    selectEl.size = 4;
    return;
  }
  selectEl.disabled = false;
  selectEl.innerHTML = values
    .map((value) => `<option value="${escapeHtml(value)}">${escapeHtml(formatter ? formatter(value) : value)}</option>`)
    .join('');
  setRefLinkReviewMultiSelectValues(selectEl, activeValues);
  selectEl.size = Math.max(4, Math.min(7, values.length));
}

function renderRefLinkReviewFilterChecklist(containerEl, kind, values, formatter){
  if (!containerEl) return;
  const activeValues = refLinkReviewState.filters[kind] || new Set();
  const availableValues = new Set(values);
  [...activeValues].forEach((value) => {
    if (!availableValues.has(value)) activeValues.delete(value);
  });
  if (!values.length) {
    activeValues.clear();
    containerEl.innerHTML = '<small>No values available.</small>';
    return;
  }
  containerEl.innerHTML = values.map((value, idx) => {
    const checked = activeValues.has(value) ? 'checked' : '';
    const label = escapeHtml(formatter ? formatter(value) : value);
    const inputId = `ref_link_review_filter_${escapeHtml(kind)}_${idx}`;
    return `
      <label class="ref-link-review-filter-option" for="${inputId}">
        <input
          id="${inputId}"
          type="checkbox"
          ${checked}
          onchange='updateRefLinkReviewFilterOption(${JSON.stringify(kind)}, ${JSON.stringify(value)}, this.checked)'
        >
        <span class="ref-link-review-filter-option-text">${label}</span>
      </label>
    `;
  }).join('');
}

function renderRefLinkReviewFilterPopover(containerEl, kind, values, formatter, label){
  if (!containerEl) return;
  const activeValues = refLinkReviewState.filters[kind] || new Set();
  const selectedCount = activeValues.size;
  const buttonLabel = selectedCount ? `${label} (${selectedCount})` : label;
  const open = refLinkReviewState.active_filter_popover === kind;
  containerEl.classList.toggle('hidden', !open);
  renderRefLinkReviewFilterChecklist(containerEl, kind, values, formatter);
  containerEl.innerHTML = `
    <div class="ref-link-review-filter-list">${containerEl.innerHTML}</div>
    <div class="ref-link-review-filter-popover-actions">
      <button class="secondary" onclick='toggleRefLinkReviewFilterPopover(${JSON.stringify(kind)})'>Done</button>
    </div>
  `;
  const triggerEl = document.getElementById(`ref_link_review_filter_button_${kind}`);
  if (triggerEl) {
    triggerEl.textContent = buttonLabel;
    triggerEl.classList.toggle('active', open);
    triggerEl.setAttribute('aria-expanded', open ? 'true' : 'false');
  }
}

function renderRefLinkReviewWorkspace(){
  const visibleRows = filteredRefLinkReviewRows();
  const totalRows = allRefLinkReviewRows().length;
  const selectedVisibleCount = visibleRows.filter((row) => row && row.proposal_id && refLinkReviewState.selected.has(row.proposal_id)).length;
  if (!visibleRows.length) {
    return `
      <section class="ref-link-review-bucket">
        <div class="step">Review workspace</div>
        <small>No proposals match the current filters. Adjust the tray filters to change what you see.</small>
      </section>
    `;
  }
  const body = visibleRows.map((row) => {
    const checked = row.proposal_id && refLinkReviewState.selected.has(row.proposal_id) ? 'checked' : '';
    const isExpanded = row.proposal_id && refLinkReviewState.expanded.has(row.proposal_id);
    const overrideValue = refLinkReviewCurrentOverride(row.proposal_id);
    const overrideClass = refLinkReviewOverrideLooksValid(overrideValue) ? '' : 'invalid';
    const actionButton = row.status === 'dismissed'
      ? `<button class="search-btn" onclick='restoreRefLinkReviewProposal(${JSON.stringify(row.proposal_id || "")})'>Restore</button>`
      : `<button class="search-btn" onclick='dismissRefLinkReviewProposal(${JSON.stringify(row.proposal_id || "")})'>Dismiss</button>`;
    const detailsRow = isExpanded
      ? `
        <tr class="ref-link-review-details-row">
          <td colspan="8">
            <div class="ref-link-review-details">
              ${renderRefLinkReviewDetailBlock('Record ID', escapeHtml(row.record_id || ''))}
              ${renderRefLinkReviewDetailBlock('Legend', escapeHtml(row.legend || ''))}
              ${renderRefLinkReviewDetailBlock('Title', escapeHtml(row.title || ''))}
              ${renderRefLinkReviewDetailBlock('Author', escapeHtml(row.author || ''))}
              ${renderRefLinkReviewDetailBlock('Year', escapeHtml(row.year || ''))}
              ${renderRefLinkReviewDetailBlock('Reason flags', renderRefLinkReviewReasonFlags(row.reason_flags))}
              ${renderRefLinkReviewDetailBlock('Current ref_link', renderRefLinkReviewUrl(row.current_ref_link || ''))}
              ${renderRefLinkReviewDetailBlock('Original proposal', renderRefLinkReviewUrl(row.proposed_ref_link || ''))}
              <div class="ref-link-review-detail-block ref-link-review-override-wrap">
                <span class="ref-link-review-detail-label">Override proposed ref_link</span>
                <input
                  class="ref_link_review_override_input ref-link-review-override-input ${overrideClass}"
                  value="${escapeHtml(overrideValue)}"
                  placeholder="Paste a replacement HTTP(S) URL if you want to override this proposal"
                  oninput='updateRefLinkReviewOverride(${JSON.stringify(row.proposal_id || "")}, this.value); this.classList.toggle("invalid", !refLinkReviewOverrideLooksValid(this.value));'
                  onchange='renderRefLinkReviewPanel()'
                >
                <div class="ref-link-review-override-help">Leave blank to keep the scanned proposal. The edited value is used when you apply selected rows.</div>
                ${overrideValue && !refLinkReviewOverrideLooksValid(overrideValue) ? '<span class="ref-link-review-inline-warning">Override must start with http:// or https:// to be applied.</span>' : ''}
              </div>
            </div>
          </td>
        </tr>
      `
      : '';
    return `
      <tr>
        <td class="ref-link-review-cell" data-ref-link-review-col="select" ${refLinkReviewColumnStyle('select')}><input type="checkbox" ${checked} onchange='toggleRefLinkReviewSelection(${JSON.stringify(row.proposal_id || "")}, this.checked)'></td>
        <td class="ref-link-review-cell" data-ref-link-review-col="citekey" ${refLinkReviewColumnStyle('citekey')}>${escapeHtml(row.citekey || row.record_id || '')}</td>
        <td class="ref-link-review-cell" data-ref-link-review-col="status" ${refLinkReviewColumnStyle('status')}>${renderRefLinkReviewStatus(row.status || '')}</td>
        <td class="ref-link-review-cell" data-ref-link-review-col="current_ref_link" ${refLinkReviewColumnStyle('current_ref_link')}>${renderRefLinkReviewUrl(row.current_ref_link || '')}</td>
        <td class="ref-link-review-cell" data-ref-link-review-col="proposed_ref_link" ${refLinkReviewColumnStyle('proposed_ref_link')}>${renderRefLinkReviewProposedCell(row)}</td>
        <td class="ref-link-review-cell" data-ref-link-review-col="confidence" ${refLinkReviewColumnStyle('confidence')}>${escapeHtml(row.confidence || '')}</td>
        <td class="ref-link-review-cell" data-ref-link-review-col="reason" ${refLinkReviewColumnStyle('reason')}>${renderRefLinkReviewReasonFlags(row.reason_flags)}</td>
        <td class="ref-link-review-cell" data-ref-link-review-col="action" ${refLinkReviewColumnStyle('action')}>
          <button class="search-btn" onclick='toggleRefLinkReviewDetails(${JSON.stringify(row.proposal_id || "")})'>${isExpanded ? 'Hide details' : 'Show details'}</button><br>
          ${actionButton}
        </td>
      </tr>
      ${detailsRow}
    `;
  }).join('');
  return `
    <section class="ref-link-review-bucket">
      <div class="ref-link-review-table-summary">
        <div>
          <div class="step">Review workspace</div>
          <small>Showing ${visibleRows.length} of ${totalRows} observation(s) after filtering.</small>
        </div>
        <small>Selected visible: ${selectedVisibleCount}</small>
      </div>
      <div class="ref-link-review-table-wrap search-results">
        <table>
          <thead>
            <tr>
              ${renderRefLinkReviewHeaderCell('Select', 'select')}
              ${renderRefLinkReviewHeaderCell('Citekey', 'citekey')}
              ${renderRefLinkReviewHeaderCell('Status', 'status')}
              ${renderRefLinkReviewHeaderCell('Current ref_link', 'current_ref_link')}
              ${renderRefLinkReviewHeaderCell('Proposed ref_link', 'proposed_ref_link')}
              ${renderRefLinkReviewHeaderCell('Confidence', 'confidence')}
              ${renderRefLinkReviewHeaderCell('Reason', 'reason')}
              ${renderRefLinkReviewHeaderCell('Action', 'action')}
            </tr>
          </thead>
          <tbody>${body}</tbody>
        </table>
      </div>
    </section>
  `;
}

function renderRefLinkReviewPanel(){
  const modal = document.getElementById('ref_link_review_modal');
  const panel = document.getElementById('ref_link_review_panel');
  const summaryEl = document.getElementById('ref_link_review_summary');
  const topbarStatusLineEl = document.getElementById('ref_link_review_topbar_status_line');
  const scanStatusEl = document.getElementById('ref_link_review_scan_status');
  const workspaceEl = document.getElementById('ref_link_review_workspace');
  const benchmarkInput = document.getElementById('ref_link_review_benchmark_url');
  const benchmarkNoteEl = document.getElementById('ref_link_review_benchmark_note');
  const visibleSummaryEl = document.getElementById('ref_link_review_visible_summary');
  const statusFilterEl = document.getElementById('ref_link_review_filter_popover_status');
  const confidenceEl = document.getElementById('ref_link_review_filter_popover_confidence');
  const reasonEl = document.getElementById('ref_link_review_filter_popover_reason');
  const filtersSectionEl = document.getElementById('ref_link_review_tray_section_filters');
  const benchmarkSectionEl = document.getElementById('ref_link_review_tray_section_benchmark');
  const actionsSectionEl = document.getElementById('ref_link_review_tray_section_actions');
  const helpSectionEl = document.getElementById('ref_link_review_tray_section_help');
  const filtersSummaryEl = document.getElementById('ref_link_review_tray_section_summary_filters');
  const benchmarkSummaryEl = document.getElementById('ref_link_review_tray_section_summary_benchmark');
  const actionsSummaryEl = document.getElementById('ref_link_review_tray_section_summary_actions');
  const helpSummaryEl = document.getElementById('ref_link_review_tray_section_summary_help');
  const filtersHeaderEl = document.getElementById('ref_link_review_tray_section_header_filters');
  const benchmarkHeaderEl = document.getElementById('ref_link_review_tray_section_header_benchmark');
  const actionsHeaderEl = document.getElementById('ref_link_review_tray_section_header_actions');
  const helpHeaderEl = document.getElementById('ref_link_review_tray_section_header_help');
  const refreshButton = document.getElementById('ref_link_review_refresh_button');
  const applyButton = document.getElementById('ref_link_review_apply_button');
  const trayToggleButton = document.getElementById('ref_link_review_tray_toggle_button');
  const selectVisibleButton = document.getElementById('ref_link_review_select_visible_button');
  const unselectVisibleButton = document.getElementById('ref_link_review_unselect_visible_button');
  const dismissButton = document.getElementById('ref_link_review_dismiss_button');
  const restoreButton = document.getElementById('ref_link_review_restore_button');
  if (!modal || !panel || !summaryEl || !topbarStatusLineEl || !scanStatusEl || !workspaceEl || !benchmarkInput || !benchmarkNoteEl || !visibleSummaryEl || !statusFilterEl || !confidenceEl || !reasonEl) return;
  if (!refLinkReviewState.modal_open) {
    closeRefLinkReviewModal();
    return;
  }
  const statusValues = refLinkReviewFilterValues('status');
  const confidenceValues = refLinkReviewFilterValues('confidence');
  const reasonValues = refLinkReviewFilterValues('reason');
  renderRefLinkReviewFilterPopover(statusFilterEl, 'status', statusValues, refLinkReviewStatusLabel, 'Status');
  renderRefLinkReviewFilterPopover(confidenceEl, 'confidence', confidenceValues, null, 'Confidence');
  renderRefLinkReviewFilterPopover(reasonEl, 'reason', reasonValues, refLinkReviewReasonLabel, 'Reason');
  pruneRefLinkReviewSelectionToVisible();
  const readyCount = (refLinkReviewState.ready_to_apply || []).length;
  const reviewCount = (refLinkReviewState.needs_review || []).length;
  const dismissedCount = (refLinkReviewState.dismissed || []).length;
  const selectedCount = refLinkReviewState.selected.size;
  const visibleRows = filteredRefLinkReviewRows();
  const visibleSelectedRows = visibleRows.filter((row) => row && row.proposal_id && refLinkReviewState.selected.has(row.proposal_id));
  const actionableSelectedVisibleCount = visibleSelectedRows.filter((row) => row && row.status !== 'dismissed').length;
  const restorableSelectedVisibleCount = visibleSelectedRows.filter((row) => row && row.status === 'dismissed').length;
  const confidenceFilters = refLinkReviewState.filters.confidence.size;
  const reasonFilters = refLinkReviewState.filters.reason.size;
  const statusFilters = refLinkReviewState.filters.status.size;
  const scanStatus = refLinkReviewState.scan_status || defaultRefLinkReviewScanStatus();
  const isScanning = refLinkReviewIsScanning();
  const stage = String(scanStatus.stage || 'idle');
  const percent = stage === 'complete'
    ? 100
    : (stage === 'comparing_registry' && scanStatus.total > 0)
      ? Math.round((scanStatus.checked / scanStatus.total) * 100)
      : 0;
  const progressLabel = stage === 'fetching_live_bibbase'
    ? 'Fetching live BibBase...'
    : (stage === 'comparing_registry'
      ? `${scanStatus.checked} / ${scanStatus.total} checked`
      : (stage === 'complete'
        ? `${scanStatus.checked} / ${scanStatus.total} checked`
        : (stage === 'failed'
          ? (scanStatus.error || scanStatus.message || 'Ref_link review scan failed.')
          : (scanStatus.message || 'Run a scan to review ref_link proposals.'))));
  const scanClasses = ['ref-link-review-scan-status'];
  if (stage === 'failed') scanClasses.push('failed');
  else if (stage === 'complete') scanClasses.push('complete');
  else if (isScanning) scanClasses.push('loading');
  const staleText = refLinkReviewState.scan_metadata && refLinkReviewState.scan_metadata.hosted_bib_is_stale
    ? '<br><small>Hosted BibBase appears stale relative to the local generated .bib.</small>'
    : '';
  const currentBenchmarkValue = String(refLinkReviewState.benchmark_url || '').trim();
  const lastScanBenchmark = String((refLinkReviewState.scan_metadata || {}).profile_source_url || '').trim();
  const defaultBenchmark = String(refLinkReviewState.default_benchmark_url || '').trim();
  benchmarkInput.value = currentBenchmarkValue;
  const benchmarkDisplayValue = currentBenchmarkValue || defaultBenchmark || lastScanBenchmark;
  let benchmarkNote = `Benchmark: ${renderRefLinkReviewUrl(benchmarkDisplayValue)}`;
  if (lastScanBenchmark && benchmarkDisplayValue && lastScanBenchmark !== benchmarkDisplayValue) {
    benchmarkNote += ` &bull; Last scan used: ${renderRefLinkReviewUrl(lastScanBenchmark)}`;
  }
  benchmarkNote += ' &bull; Session only. Refresh scan after editing the URL.';
  if (currentBenchmarkValue && lastScanBenchmark && currentBenchmarkValue !== lastScanBenchmark) {
    benchmarkNote += ' <span class="ref-link-review-inline-warning">Refresh scan to use the edited URL.</span>';
  }
  benchmarkNoteEl.innerHTML = benchmarkNote;
  summaryEl.innerHTML =
    `<div class="ref-link-review-toolbar-summary">Ready ${readyCount} | Review ${reviewCount} | Dismissed ${dismissedCount}${staleText}</div>`;
  topbarStatusLineEl.innerHTML = `Visible ${visibleRows.length} | Selected ${selectedCount} | Filters ${statusFilters + confidenceFilters + reasonFilters}`;
  scanStatusEl.className = scanClasses.join(' ');
  scanStatusEl.innerHTML = `
    <div class="ref-link-review-scan-status-compact">
      <div class="ref-link-review-scan-meta">
        <small id="ref_link_review_scan_progress_label">${escapeHtml(stage === 'failed' ? `Failed: ${progressLabel}` : progressLabel)}</small>
      </div>
      <div id="ref_link_review_scan_progress" class="ref-link-review-scan-progress" title="${escapeHtml(scanStatus.message || progressLabel)}">
        <div id="ref_link_review_scan_progress_fill" class="ref-link-review-scan-progress-fill" style="width:${percent}%"></div>
      </div>
    </div>
  `;
  if (refreshButton) refreshButton.disabled = false;
  if (applyButton) {
    applyButton.disabled = isScanning || actionableSelectedVisibleCount === 0;
    applyButton.textContent = actionableSelectedVisibleCount ? `Apply selected (${actionableSelectedVisibleCount})` : 'Apply selected';
  }
  if (trayToggleButton) {
    trayToggleButton.textContent = refLinkReviewState.tray_open ? 'Hide tools' : 'Show tools';
  }
  if (selectVisibleButton) selectVisibleButton.disabled = visibleRows.length === 0;
  if (unselectVisibleButton) unselectVisibleButton.disabled = visibleSelectedRows.length === 0;
  if (dismissButton) dismissButton.disabled = actionableSelectedVisibleCount === 0;
  if (restoreButton) restoreButton.disabled = restorableSelectedVisibleCount === 0;
  visibleSummaryEl.innerHTML = `Showing ${visibleRows.length} row(s); ${visibleSelectedRows.length} visible selected.`;
  if (filtersSummaryEl) filtersSummaryEl.textContent = `${statusFilters + confidenceFilters + reasonFilters} active`;
  if (benchmarkSummaryEl) benchmarkSummaryEl.textContent = currentBenchmarkValue ? 'Custom' : 'Default';
  if (actionsSummaryEl) actionsSummaryEl.textContent = `${visibleSelectedRows.length} selected`;
  if (helpSummaryEl) helpSummaryEl.textContent = 'Tips';
  const activeSection = String(refLinkReviewState.active_tray_section || 'filters');
  [
    ['filters', filtersSectionEl, filtersHeaderEl],
    ['benchmark', benchmarkSectionEl, benchmarkHeaderEl],
    ['actions', actionsSectionEl, actionsHeaderEl],
    ['help', helpSectionEl, helpHeaderEl],
  ].forEach(([name, sectionEl, headerEl]) => {
    if (sectionEl) sectionEl.classList.toggle('collapsed', activeSection !== name);
    if (headerEl) headerEl.setAttribute('aria-expanded', activeSection === name ? 'true' : 'false');
  });
  if (!readyCount && !reviewCount && !dismissedCount) {
    const emptyMessage = isScanning
      ? 'Scan in progress. Results will appear here when the comparison finishes.'
      : (stage === 'complete'
        ? 'No ref_link proposals were found for this scan.'
        : 'Run a scan to review ref_link proposals.');
    workspaceEl.innerHTML = `
      <section class="ref-link-review-bucket">
        <div class="step">Review workspace</div>
        <small>${escapeHtml(emptyMessage)}</small>
      </section>
    `;
  } else {
    workspaceEl.innerHTML = renderRefLinkReviewWorkspace();
  }
  openRefLinkReviewModal();
  applyRefLinkReviewModalSize();
  applyRefLinkReviewTrayWidth();
  applyRefLinkReviewColumnWidths();
}

document.addEventListener('mousemove', (event) => {
  if (refLinkReviewResizeState) {
    const minWidth = refLinkReviewColumnMinWidth(refLinkReviewResizeState.column);
    const delta = Number(event.clientX || 0) - refLinkReviewResizeState.startX;
    refLinkReviewState.column_widths[refLinkReviewResizeState.column] = Math.max(minWidth, refLinkReviewResizeState.startWidth + delta);
    applyRefLinkReviewColumnWidths();
  }
  if (refLinkReviewTrayResizeState) {
    const deltaTray = Number(event.clientX || 0) - refLinkReviewTrayResizeState.startX;
    refLinkReviewState.tray_width = refLinkReviewClampTrayWidth(refLinkReviewTrayResizeState.startWidth - deltaTray);
    refLinkReviewWriteStorage('tray-width', refLinkReviewState.tray_width);
    applyRefLinkReviewTrayWidth();
  }
  if (refLinkReviewModalResizeState) {
    const deltaX = Number(event.clientX || 0) - refLinkReviewModalResizeState.startX;
    const deltaY = Number(event.clientY || 0) - refLinkReviewModalResizeState.startY;
    refLinkReviewState.modal_width = refLinkReviewClampModalWidth(refLinkReviewModalResizeState.startWidth + deltaX);
    refLinkReviewState.modal_height = refLinkReviewClampModalHeight(refLinkReviewModalResizeState.startHeight + deltaY);
    refLinkReviewWriteStorage('modal-width', refLinkReviewState.modal_width);
    refLinkReviewWriteStorage('modal-height', refLinkReviewState.modal_height);
    applyRefLinkReviewModalSize();
  }
});

document.addEventListener('mouseup', () => {
  refLinkReviewResizeState = null;
  refLinkReviewTrayResizeState = null;
  refLinkReviewModalResizeState = null;
});

window.addEventListener('resize', () => {
  if (refLinkReviewState.modal_open) renderRefLinkReviewPanel();
});

function historyIsoToLocalInput(value){
  const date = new Date(String(value || ''));
  if (Number.isNaN(date.getTime())) return '';
  const pad = (num) => String(num).padStart(2, '0');
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}T${pad(date.getHours())}:${pad(date.getMinutes())}`;
}

function historyFormatDate(value){
  const date = new Date(String(value || ''));
  if (Number.isNaN(date.getTime())) return String(value || 'Unknown time');
  return date.toLocaleString([], {year: 'numeric', month: 'short', day: '2-digit', hour: '2-digit', minute: '2-digit'});
}

function historyDayLabel(value){
  const date = new Date(String(value || ''));
  if (Number.isNaN(date.getTime())) return 'Unknown date';
  return date.toLocaleDateString([], {year: 'numeric', month: 'long', day: 'numeric'});
}

function historyGetEntryById(historyId, entries){
  const pool = Array.isArray(entries) ? entries : historyEntries;
  return pool.find((entry) => entry && entry.history_id === historyId) || null;
}

function historyEntriesForRecord(entry){
  if (!entry || !entry.record_id) return [];
  return historyEntries.filter((item) => item && item.library === entry.library && item.record_id === entry.record_id);
}

function historyApplyCleanupReason(reason){
  historyCleanupReason = String(reason || '');
  const input = document.getElementById('history_cleanup_reason');
  if (input) input.value = historyCleanupReason;
}

function historyClearFilters(){
  document.getElementById('history_show_before').value = '';
  document.getElementById('history_branch_filter').value = '';
  document.getElementById('history_action_filter').value = '';
  document.getElementById('history_search').value = '';
  renderHistoryView();
}

function historyUseSelectedTime(){
  const entry = historyGetEntryById(historySelectedId);
  if (!entry) return;
  document.getElementById('history_show_before').value = historyIsoToLocalInput(entry.updated_at);
  renderHistoryView();
}

function historyMatches(entry){
  if (!entry) return false;
  const showBefore = v('history_show_before').trim();
  if (showBefore) {
    const boundary = new Date(showBefore);
    const changeDate = new Date(String(entry.updated_at || ''));
    if (!Number.isNaN(boundary.getTime()) && !Number.isNaN(changeDate.getTime()) && changeDate.getTime() > boundary.getTime()) {
      return false;
    }
  }
  const branchFilter = v('history_branch_filter').trim();
  if (branchFilter && String(entry.library || '') !== branchFilter) return false;
  const actionFilter = v('history_action_filter').trim();
  if (actionFilter && String(entry.action_label || '') !== actionFilter) return false;
  const query = v('history_search').trim().toLowerCase();
  if (!query) return true;
  const files = Array.isArray(entry.affected_files) ? entry.affected_files : [];
  const haystack = [
    entry.record_id,
    entry.actor,
    entry.reason,
    entry.summary,
    entry.branch_label,
    entry.action_label,
    ...files.map((item) => item.path),
  ].join(' ').toLowerCase();
  return haystack.includes(query);
}

function filteredHistoryEntries(){
  return historyEntries.filter((entry) => historyMatches(entry));
}

function renderHistorySummaryStrip(entries){
  const strip = document.getElementById('history_summary_strip');
  if (!strip) return;
  const cards = [
    {label: 'Latest change', value: historySummary.latest_updated_at ? historyFormatDate(historySummary.latest_updated_at) : 'No history yet'},
    {label: 'Visible rows', value: String((entries || []).length)},
    {label: 'Data Sources rows', value: String(historySummary.data_sources || 0)},
    {label: 'Wealth Research rows', value: String(historySummary.wealth_research || 0)},
  ];
  strip.innerHTML = cards.map((card) => `
    <div class="history-kpi">
      <span class="history-kpi-label">${escapeHtml(card.label)}</span>
      <div class="history-kpi-value">${escapeHtml(card.value)}</div>
    </div>
  `).join('');
}

function renderHistoryList(entries){
  const listEl = document.getElementById('history_list');
  if (!listEl) return;
  if (!entries.length) {
    listEl.innerHTML = '<small>No history records match the current filters.</small>';
    return;
  }
  const groups = [];
  entries.forEach((entry) => {
    const label = historyDayLabel(entry.updated_at);
    const lastGroup = groups[groups.length - 1];
    if (!lastGroup || lastGroup.label !== label) {
      groups.push({label, entries: [entry]});
    } else {
      lastGroup.entries.push(entry);
    }
  });
  listEl.innerHTML = groups.map((group) => `
    <div class="history-day-group">
      <div class="history-day-heading">${escapeHtml(group.label)}</div>
      ${group.entries.map((entry) => {
        const active = entry.history_id === historySelectedId ? ' active' : '';
        const files = Array.isArray(entry.affected_files) ? entry.affected_files.length : 0;
        return `
          <button class="history-item${active}" onclick='historySelect(${JSON.stringify(entry.history_id)})'>
            <div class="history-item-top">
              <div class="history-badges">
                <span class="history-badge library">${escapeHtml(entry.branch_label || '')}</span>
                <span class="history-badge action">${escapeHtml(entry.action_label || '')}</span>
              </div>
              <div class="history-item-time">${escapeHtml(historyFormatDate(entry.updated_at))}</div>
            </div>
            <div class="history-record">${escapeHtml(entry.record_id || '(no record id)')}</div>
            <div class="history-summary">${escapeHtml(entry.summary || '')}</div>
            <div class="history-item-meta">${escapeHtml(entry.actor || 'Unknown actor')}</div>
            <div class="history-files-count">${files} affected file${files === 1 ? '' : 's'}</div>
          </button>
        `;
      }).join('')}
    </div>
  `).join('');
}

function renderHistoryDetail(entry){
  const detailEl = document.getElementById('history_detail');
  if (!detailEl) return;
  if (!entry) {
    detailEl.innerHTML = '<div class="history-detail-empty">Select a history record to inspect the affected files and restore guidance.</div>';
    return;
  }
  const files = Array.isArray(entry.affected_files) ? entry.affected_files : [];
  const filesHtml = files.length ? files.map((item) => `
    <li class="history-file-row">
      <span class="history-file-path">${escapeHtml(item.path || '')}</span>
      <div class="history-file-note">${escapeHtml(item.note || '')}</div>
    </li>
  `).join('') : '<div class="history-detail-empty">No affected files were inferred for this history record.</div>';
  const git = entry.git_context || {};
  const gitSummary = !git.available
    ? 'Local git context was not available in this workspace.'
    : (git.commit
        ? `Nearest local commit before this change: ${git.commit.slice(0, 12)}${git.subject ? ` (${git.subject})` : ''}.`
        : 'Local git repository detected for this workspace.');
  const gitRemoteNote = git.remote_url ? `<small>Remote: ${escapeHtml(git.remote_url)}</small>` : '';
  const gitCommitNote = git.committed_at ? `<small>Nearest commit time: ${escapeHtml(historyFormatDate(git.committed_at))}</small>` : '';
  detailEl.innerHTML = `
    <div class="history-detail-grid">
      <div class="history-detail-card">
        <h4>Change Snapshot</h4>
        <div class="history-summary" style="margin-bottom:12px;">${escapeHtml(entry.summary || '')}</div>
        <div class="history-meta-grid">
          <div class="history-meta-block">
            <span class="history-meta-label">When</span>
            <div class="history-meta-value">${escapeHtml(historyFormatDate(entry.updated_at))}</div>
          </div>
          <div class="history-meta-block">
            <span class="history-meta-label">Action</span>
            <div class="history-meta-value">${escapeHtml(entry.action_label || '')}</div>
          </div>
          <div class="history-meta-block">
            <span class="history-meta-label">Record</span>
            <div class="history-meta-value">${escapeHtml(entry.record_id || '(no record id)')}</div>
          </div>
          <div class="history-meta-block">
            <span class="history-meta-label">Actor</span>
            <div class="history-meta-value">${escapeHtml(entry.actor || 'Unknown actor')}</div>
          </div>
        </div>
        <div class="history-meta-block" style="margin-top:12px;">
          <span class="history-meta-label">Reason</span>
          <div class="history-meta-value">${escapeHtml(entry.reason || '(no reason recorded)')}</div>
        </div>
      </div>
      <div class="history-detail-card">
        <h4>Restore Guidance</h4>
        <div class="history-guidance-grid">
          <div class="history-guidance-card">
            <h5>GitHub / Git</h5>
            <p>Restore the affected files to a version from just before ${escapeHtml(historyFormatDate(entry.updated_at))}.</p>
            <small>${escapeHtml(gitSummary)}</small>
            ${gitRemoteNote}
            ${gitCommitNote}
          </div>
          <div class="history-guidance-card">
            <h5>Dropbox</h5>
            <p>If this folder is Dropbox-synced, open version history for the affected files and restore versions from just before ${escapeHtml(historyFormatDate(entry.updated_at))}.</p>
            <small>Dropbox sync status is not detected automatically in this UI.</small>
          </div>
        </div>
      </div>
      <details>
        <summary><b>Files affected</b> (${files.length})</summary>
        <div style="margin-top:12px;">
          <ul class="history-files">${filesHtml}</ul>
        </div>
      </details>
      <details>
        <summary><b>History cleanup</b></summary>
        <div style="margin-top:12px;">
          <div class="history-cleanup-note">Recommended: keep history intact. Removes history records only. Source records and generated files are not changed.</div>
          <div class="row" style="margin-top:12px;">
            <label>Cleanup reason</label>
            <input id="history_cleanup_reason" list="history_cleanup_reason_suggestions" placeholder="test entry, development trial, duplicate noise" value="${escapeHtml(historyCleanupReason)}" oninput="historyCleanupReason = this.value">
            <datalist id="history_cleanup_reason_suggestions">
              <option value="testing noise"></option>
              <option value="development trial"></option>
              <option value="duplicate noise"></option>
              <option value="local rehearsal"></option>
            </datalist>
          </div>
          <div class="history-filter-actions" style="margin-bottom:10px;">
            <button class="secondary" onclick="historyApplyCleanupReason('testing noise')">Testing noise</button>
            <button class="secondary" onclick="historyApplyCleanupReason('development trial')">Development trial</button>
            <button class="secondary" onclick="historyApplyCleanupReason('duplicate noise')">Duplicate noise</button>
            <button class="secondary" onclick="historyApplyCleanupReason('local rehearsal')">Local rehearsal</button>
          </div>
          <div class="history-filter-actions">
            <button class="secondary" onclick="historyUseSelectedTime()">Filter to this time</button>
            <button class="warn" onclick="historyDeleteSelected()">Remove History Record</button>
            <button class="warn" onclick="historyDeleteForRecord()">Remove History Records For This Source</button>
          </div>
        </div>
      </details>
    </div>
  `;
}

function renderHistoryView(){
  const entries = filteredHistoryEntries();
  renderHistorySummaryStrip(entries);
  if (historySelectedId && !entries.some((entry) => entry.history_id === historySelectedId)) {
    historySelectedId = entries[0] ? entries[0].history_id : '';
  }
  if (!historySelectedId && entries[0]) historySelectedId = entries[0].history_id;
  renderHistoryList(entries);
  renderHistoryDetail(historyGetEntryById(historySelectedId, entries));
}

function historySelect(historyId){
  historySelectedId = historyId;
  renderHistoryView();
}

function activeStatusTarget(){
  if (activeBranch === 'wealth') return 'wealth_status';
  if (activeBranch === 'history') return 'history_status';
  return 'status';
}

function pollForRelaunch(attempt=0){
  const maxAttempts = 18;
  window.setTimeout(async () => {
    try {
      const resp = await fetch('/api/ping', {cache: 'no-store'});
      if (resp.ok) {
        window.location.reload();
        return;
      }
    } catch (err) {
      // Wait for the replacement server process.
    }
    if (attempt < maxAttempts) pollForRelaunch(attempt + 1);
  }, attempt === 0 ? 900 : 1200);
}

async function relaunchApp(){
  try {
    const msg = 'Relaunch the local source manager? This is equivalent to closing and starting the app again.';
    if (!confirm(msg)) return;
    isRelaunching = true;
    const out = await req('/api/relaunch', {});
    const statusTarget = activeStatusTarget();
    setStatus(out, statusTarget);
    pollForRelaunch();
  } catch (err) {
    isRelaunching = false;
    setStatus({ok:false, error:String(err)}, activeStatusTarget());
    showErrorWindow(String(err));
  }
}

async function shutdownApp(){
  try {
    const unsaved = dirty || wealthDirty;
    const msg = unsaved
      ? 'Stop the local source manager? Unsaved form changes will remain only in this browser tab.'
      : 'Stop the local source manager?';
    if (!confirm(msg)) return;
    const out = await req('/api/shutdown', {});
    setStatus(out, activeStatusTarget());
  } catch (err) {
    setStatus({ok:false, error:String(err)}, activeStatusTarget());
    showErrorWindow(String(err));
  }
}

async function historyLoad(preserveSelection=true){
  try {
    const out = await reqGetJson('/api/history');
    historyEntries = Array.isArray(out.entries) ? out.entries : [];
    historySummary = out.summary || {};
    if (!preserveSelection || !historyEntries.some((entry) => entry.history_id === historySelectedId)) {
      historySelectedId = historyEntries[0] ? historyEntries[0].history_id : '';
    }
    renderHistoryView();
    setStatus({ok: true, entries: historyEntries.length, latest: historySummary.latest_updated_at || ''}, 'history_status');
  } catch (err) {
    setStatus({ok:false, error:String(err)}, 'history_status');
    renderHistoryView();
  }
}

async function historyDeleteSelected(){
  try {
    const entry = historyGetEntryById(historySelectedId);
    if (!entry) throw new Error('Select a history record first.');
    const cleanupReason = (v('history_cleanup_reason') || '').trim();
    historyCleanupReason = cleanupReason;
    if (!cleanupReason) throw new Error('Cleanup reason is required to remove a history record.');
    const visibleEntries = filteredHistoryEntries();
    const currentIndex = Math.max(0, visibleEntries.findIndex((item) => item && item.history_id === historySelectedId));
    const msg =
      `Remove this history record?

` +
      `${entry.summary || 'Selected history record'}
` +
      `Time: ${historyFormatDate(entry.updated_at)}

` +
      `Removes history records only.
Source records are not changed.
Generated files are not changed.

` +
      `Use only for testing or development cleanup.`;
    if (!confirm(msg)) return;
    const out = await req('/api/history/delete_entry', {
      library: entry.library,
      cleanup_scope: 'entry',
      storage_index: entry.storage_index,
      cleanup_reason: cleanupReason,
    });
    await historyLoad(false);
    const nextVisible = filteredHistoryEntries()[Math.min(currentIndex, Math.max(filteredHistoryEntries().length - 1, 0))];
    historySelectedId = nextVisible ? nextVisible.history_id : '';
    renderHistoryView();
    setStatus(out, 'history_status');
  } catch (err) {
    setStatus({ok:false, error:String(err)}, 'history_status');
    showErrorWindow(String(err));
  }
}

async function historyDeleteForRecord(){
  try {
    const entry = historyGetEntryById(historySelectedId);
    if (!entry) throw new Error('Select a history record first.');
    if (!entry.record_id) throw new Error('This history record has no source or key identifier to clean up.');
    const cleanupReason = (v('history_cleanup_reason') || '').trim();
    historyCleanupReason = cleanupReason;
    if (!cleanupReason) throw new Error('Cleanup reason is required to remove history records for a source.');
    const matchingRows = historyEntriesForRecord(entry);
    const msg =
      `Remove all ${matchingRows.length} history record(s) for ${entry.record_id}?

` +
      `Removes history records only for this source or key in ${entry.branch_label}.
Source records are not changed.
Generated files are not changed.`;
    if (!confirm(msg)) return;
    const out = await req('/api/history/delete_entry', {
      library: entry.library,
      cleanup_scope: 'record',
      record_id: entry.record_id,
      cleanup_reason: cleanupReason,
    });
    await historyLoad(false);
    renderHistoryView();
    setStatus(out, 'history_status');
  } catch (err) {
    setStatus({ok:false, error:String(err)}, 'history_status');
    showErrorWindow(String(err));
  }
}

function switchBranch(branch){
  activeBranch = branch === 'wealth' ? 'wealth' : (branch === 'history' ? 'history' : (branch === 'maintenance' ? 'maintenance' : 'data'));
  const isData = activeBranch === 'data';
  const isWealth = activeBranch === 'wealth';
  const isHistory = activeBranch === 'history';
  const isMaintenance = activeBranch === 'maintenance';
  document.getElementById('branch_data').classList.toggle('hidden', !isData);
  document.getElementById('branch_wealth').classList.toggle('hidden', !isWealth);
  document.getElementById('branch_history').classList.toggle('hidden', !isHistory);
  document.getElementById('branch_maintenance').classList.toggle('hidden', !isMaintenance);
  document.getElementById('branch_data_tab').classList.toggle('active', isData);
  document.getElementById('branch_wealth_tab').classList.toggle('active', isWealth);
  document.getElementById('branch_history_tab').classList.toggle('active', isHistory);
  document.getElementById('branch_maintenance_tab').classList.toggle('active', isMaintenance);
  if (isWealth) {
    closeRefLinkReviewModal();
    wealthOnModeChange();
    wealthOnEntryTypeChange();
    wealthLoadOptions().catch((err) => setStatus({ok:false, error:String(err)}, 'wealth_status'));
  } else if (isHistory) {
    closeRefLinkReviewModal();
    historyLoad().catch((err) => setStatus({ok:false, error:String(err)}, 'history_status'));
  } else if (isMaintenance) {
    closeRefLinkReviewModal();
    maintenanceLoad().catch((err) => setStatus({ok:false, error:String(err)}, 'maintenance_status'));
  } else {
    onModeChange();
    onEntryTypeChange();
  }
}

function onModeChange(){
  const mode = v('mode');
  const isEdit = mode === 'edit';
  for (const id of ['editTargetWrap','editToolsWrap','dataSearchWrap']) {
    document.getElementById(id).classList.toggle('hidden', !isEdit);
  }
  document.getElementById('dataBibPasteWrap').classList.toggle('hidden', isEdit);
  document.getElementById('loadBtn').disabled = !isEdit;
  document.getElementById('row_bib_url').classList.toggle('hidden', !isEdit);
  document.getElementById('row_source_key').classList.toggle('hidden', isEdit);
  document.getElementById('row_source_value').classList.toggle('hidden', !isEdit);
  document.getElementById('row_citekey_value').classList.toggle('hidden', !isEdit);
  if (!isEdit) {
    loadedSourceKey = '';
    loadedSourceValue = '';
    loadedCitekeyValue = '';
    document.getElementById('target').value = '';
    document.getElementById('source_value').value = '';
    document.getElementById('citekey_value').value = '';
    // In add mode we keep a single URL field and mirror it to bib.url on save.
    document.getElementById('bib_url').value = '';
  }
}

function firstAuthorLastName(authorText){
  const s = (authorText || '').trim();
  if(!s) return '';
  const first = s.split(/\s+and\s+/i)[0].trim();
  if(first.includes(',')) return first.split(',')[0].trim();
  const parts = first.split(/\s+/).filter(Boolean);
  return parts.length ? parts[parts.length - 1] : '';
}

function trySuggestLegend(){
  if(v('mode') !== 'add') return;
  const legendEl = document.getElementById('legend');
  if(legendEl.dataset.userEdited === '1') return;
  if((legendEl.value || '').trim() !== '') return;
  const authorText = (v('bib_author') || '').trim();
  const ln = firstAuthorLastName(authorText);
  if(!ln) return;
  const yr = (v('bib_year') || '').trim() || 'n.d.';
  const multi = /\sand\s/i.test(authorText);
  legendEl.value = multi ? `${ln} et al. (${yr})` : `${ln} (${yr})`;
}

function onEntryTypeChange(){
  const t = v('bib_entry_type');
  const show = (id, flag) => document.getElementById(id).classList.toggle('hidden', !flag);
  const isEdit = v('mode') === 'edit';
  show('row_bib_url', isEdit);
  show('row_bib_journal', t === 'article');
  show('row_bib_booktitle', t === 'incollection' || t === 'inproceedings');
  show('row_bib_publisher', t === 'book' || t === 'incollection' || t === 'inproceedings');
  show('row_bib_institution', t === 'techreport');
}

function getPayload(){
  return {
    mode: v('mode'),
    editor_name: v('editor_name'),
    target: v('target'),
    key_rename_confirmed: false,
    record: {
      section: v('section'), aggsource: v('aggsource'), legend: v('legend'), source_key: v('source_key'),
      source: v('source_value'), citekey: v('citekey_value'),
      data_type: v('data_type'), link: v('link'), ref_link: v('ref_link'), inclusion_in_warehouse: v('inclusion_in_warehouse'),
      multigeo_reference: v('multigeo_reference'), metadata: v('metadata'), metadatalink: v('metadatalink'),
      shared_citekey_group: v('shared_citekey_group'), shared_citekey_note: v('shared_citekey_note'),
      bib: {
        entry_type: v('bib_entry_type'), title: v('bib_title'), author: v('bib_author'), year: v('bib_year'), month: v('bib_month'),
        journal: v('bib_journal'), booktitle: v('bib_booktitle'), volume: v('bib_volume'), number: v('bib_number'), pages: v('bib_pages'),
        institution: v('bib_institution'), publisher: v('bib_publisher'), doi: v('bib_doi'), url: v('bib_url'), urldate: v('bib_urldate'),
        keywords: v('bib_keywords'), note: v('bib_note'), abstract: v('bib_abstract')
      }
    }
  }
}

function isEmptyAddPayload(payload){
  const mode = String(payload.mode || '').trim().toLowerCase();
  if (mode !== 'add') return false;
  const record = payload.record || {};
  const bib = record.bib || {};
  const recordFields = [
    'section', 'aggsource', 'legend', 'source_key', 'data_type', 'link',
    'ref_link', 'inclusion_in_warehouse', 'multigeo_reference', 'metadata', 'metadatalink',
    'shared_citekey_group', 'shared_citekey_note'
  ];
  const bibFields = [
    'entry_type', 'title', 'author', 'year', 'month', 'journal', 'booktitle',
    'volume', 'number', 'pages', 'institution', 'publisher', 'doi', 'url',
    'urldate', 'keywords', 'note', 'abstract'
  ];
  for (const key of recordFields) {
    if (String(record[key] || '').trim() !== '') return false;
  }
  for (const key of bibFields) {
    if (String(bib[key] || '').trim() !== '') return false;
  }
  return true;
}

function capitalizeFirst(text){
  if (!text) return '';
  return text.charAt(0).toUpperCase() + text.slice(1);
}

async function ensureEditorName(actionLabel){
  let name = (v('editor_name') || '').trim();
  if (name) return name;
  const entered = prompt(`Enter your name to ${actionLabel}.`);
  if (entered === null) {
    throw new Error(`${capitalizeFirst(actionLabel)} cancelled. Name was not provided.`);
  }
  name = entered.trim();
  if (!name) {
    throw new Error('Your name is required to continue.');
  }
  document.getElementById('editor_name').value = name;
  return name;
}

function formatChecks(out){
  const checks = out.checks || [];
  if (!checks.length) return '';
  const lines = ['Checks performed:'];
  checks.forEach(ch => {
    const tag = ch.passed ? 'PASS' : 'FAIL';
    const detail = ch.detail ? ` - ${ch.detail}` : '';
    lines.push(`- [${tag}] ${ch.name}${detail}`);
  });
  return lines.join('\\n');
}

function buildDuplicateGuidance(out){
  const errors = out.errors || [];
  const dup = errors.filter(e =>
    e.includes('Exact duplicate') ||
    e.includes('Dictionary duplicate') ||
    e.includes('Bib duplicate')
  );
  if (!dup.length) return '';
  const fieldHints = [];
  if (dup.some(e => e.toLowerCase().includes('source'))) fieldHints.push('Source / Citekey');
  if (dup.some(e => e.toLowerCase().includes('citekey') || e.toLowerCase().includes('key'))) fieldHints.push('Source / Citekey');
  if (dup.some(e => e.toLowerCase().includes('url') || e.toLowerCase().includes('link'))) fieldHints.push('URL / Link');
  if (dup.some(e => e.toLowerCase().includes('title'))) fieldHints.push('bib.title');
  if (dup.some(e => e.toLowerCase().includes('year'))) fieldHints.push('bib.year');
  const uniqueHints = [...new Set(fieldHints)];
  const lines = [
    'A record with similar information already exists.',
    'Please switch to edit mode if you want to modify an existing entry, or choose different values for:',
  ];
  if (uniqueHints.length) {
    lines.push(`- ${uniqueHints.join('\\n- ')}`);
  } else {
    lines.push('- Source / Citekey');
    lines.push('- URL / Link');
    lines.push('- bib.title / bib.year');
  }
  return lines.join('\\n');
}

function buildStaleArtifactGuidance(out){
  if (!out || out.error_code !== 'stale_artifacts') return '';
  const lines = [
    'Generated artifacts are out of sync with the canonical registry.',
    'Use the Maintenance tab -> Rebuild generated artifacts, then retry the save.',
  ];
  if (out.rebuild_hint) lines.push(`Rebuild command: ${out.rebuild_hint}`);
  const files = Array.isArray(out.stale_artifact_paths) ? out.stale_artifact_paths : [];
  if (files.length) {
    lines.push('Files to refresh:');
    lines.push(`- ${files.join('\\n- ')}`);
  }
  if (out.artifact_duplicate_errors && out.artifact_duplicate_errors.length) {
    lines.push(`Duplicate hits in artifacts:\\n- ${out.artifact_duplicate_errors.join('\\n- ')}`);
  }
  return lines.join('\\n');
}

function formatOnlineCompare(onlineCompare){
  if (!onlineCompare) return '';
  const lines = ['Online .bib comparison:'];
  if (onlineCompare.library_label) lines.push(`- Library: ${onlineCompare.library_label}`);
  lines.push(`- Status: ${onlineCompare.status || 'unknown'}`);
  if (onlineCompare.message) lines.push(`- Message: ${onlineCompare.message}`);
  if (onlineCompare.reference_url) lines.push(`- Online reference: ${onlineCompare.reference_url}`);
  if (onlineCompare.local_bib_path) lines.push(`- Local bib: ${onlineCompare.local_bib_path}`);
  if (onlineCompare.diff_preview) lines.push(`Unified diff (online -> local):\\n${onlineCompare.diff_preview}`);
  return lines.join('\\n');
}

function setStatusWithChecks(out, heading, opts={}){
  const targetId = opts.targetId || 'status';
  const modeValue = opts.modeValue || v('mode');
  const includeOnlineCompare = opts.includeOnlineCompare !== false;
  const includeDuplicateGuidance = opts.includeDuplicateGuidance !== false;
  const nextMessage = opts.nextMessage || '';
  const lines = [];
  if (heading) lines.push(heading);
  const summary = (out.ok || out.status === 'ok') ? 'Overall result: PASSED' : 'Overall result: FAILED';
  lines.push(summary);
  if (out.message) lines.push(`Message: ${out.message}`);
  if (nextMessage) lines.push(nextMessage);
  const checkText = formatChecks(out);
  if (checkText) lines.push(checkText);
  if (includeDuplicateGuidance && modeValue === 'add') {
    const dupGuidance = buildDuplicateGuidance(out);
    if (dupGuidance) lines.push(dupGuidance);
  }
  const staleGuidance = buildStaleArtifactGuidance(out);
  if (staleGuidance) lines.push(staleGuidance);
  if (out.warnings && out.warnings.length) lines.push(`Warnings:\\n- ${out.warnings.join('\\n- ')}`);
  if (out.errors && out.errors.length) lines.push(`Errors:\\n- ${out.errors.join('\\n- ')}`);
  if (out.file_change_summary && out.file_change_summary.length) {
    const details = out.file_change_summary.map(x => `- ${x.file}: ${x.summary}`);
    lines.push(`Modification summary by file:\\n${details.join('\\n')}`);
  }
  if (includeOnlineCompare) {
    const onlineText = formatOnlineCompare(out.online_compare);
    if (onlineText) lines.push(onlineText);
  }
  setStatusColored(lines.join('\\n\\n'), targetId);
}

async function req(path, payload){
  let r;
  try {
    r = await fetch(path, {method:'POST', headers:{'Content-Type':'application/json'}, body: JSON.stringify(payload || {})});
  } catch (err) {
    throw new Error(`Could not reach local server while calling ${path}. The UI server may have stopped.`);
  }
  let j = {};
  try {
    j = await r.json();
  } catch (err) {
    throw new Error(`Server returned an unreadable response for ${path} (HTTP ${r.status}).`);
  }
  if(!r.ok){
    const messageLines = [j.error || ('HTTP ' + r.status)];
    if (j.error_code === 'stale_artifacts') {
      if (j.rebuild_hint) messageLines.push(`Rebuild command: ${j.rebuild_hint}`);
      const files = Array.isArray(j.stale_artifact_paths) ? j.stale_artifact_paths : [];
      if (files.length) {
        messageLines.push(`Files to refresh:\\n- ${files.join('\\n- ')}`);
      }
    }
    const err = new Error(messageLines.join('\\n\\n'));
    if (j && typeof j === 'object') {
      Object.assign(err, j);
    }
    throw err;
  }
  return j;
}

async function reqGetJson(path){
  let r;
  try {
    r = await fetch(path);
  } catch (err) {
    throw new Error(`Could not reach local server while calling ${path}. The UI server may have stopped.`);
  }
  let j = {};
  try {
    j = await r.json();
  } catch (err) {
    throw new Error(`Server returned an unreadable response for ${path} (HTTP ${r.status}).`);
  }
  if(!r.ok){
    const err = new Error(j.error || ('HTTP ' + r.status));
    if (j && typeof j === 'object') {
      Object.assign(err, j);
    }
    throw err;
  }
  return j;
}

async function loadOptions(){
  let r;
  try {
    r = await fetch('/api/options');
  } catch (err) {
    throw new Error('Could not reach local server for options refresh. The save may have succeeded; reload the page and check status.');
  }
  const j = await r.json();
  for (const k of ['section','aggsource','data_type','target','inclusion_in_warehouse']) {
    const dl = document.getElementById((k === 'target' ? 'target' : k) + '_opts');
    const vals = (k === 'target') ? (j.targets || []) : (j[k] || []);
    dl.innerHTML = '';
    vals.forEach(val => { const opt = document.createElement('option'); opt.value = val; dl.appendChild(opt); });
  }
  bulkLabelState.values = j.bulk_label_values || {};
  renderBulkLabelControls();
  dataEntries = j.data_search_rows || [];
  const nextDefaultBenchmark = String(j.ref_link_review_benchmark_url || '');
  const previousDefaultBenchmark = String(refLinkReviewState.default_benchmark_url || '');
  refLinkReviewState.default_benchmark_url = nextDefaultBenchmark;
  if (!String(refLinkReviewState.benchmark_url || '').trim() || String(refLinkReviewState.benchmark_url || '') === previousDefaultBenchmark) {
    refLinkReviewState.benchmark_url = nextDefaultBenchmark;
  }
  dataRenderSearchResults();
  if (refLinkReviewState.modal_open) renderRefLinkReviewPanel();
}

function dataRenderSearchResults(){
  const holder = document.getElementById('data_search_results');
  const q = (v('data_search') || '').trim().toLowerCase();
  const filtered = dataEntries.filter((row) => {
    if (!q) return true;
    return [row.citekey, row.source, row.legend, row.year, row.title, row.author]
      .map(x => String(x || '').toLowerCase())
      .some(x => x.includes(q));
  }).slice(0, 250);

  if (!filtered.length) {
    holder.innerHTML = '<small>No entries match your search.</small>';
    return;
  }
  const rows = filtered.map((row) => `
    <tr>
      <td><button class='search-btn' data-key="${escapeHtml(row.source || row.citekey || '')}">${escapeHtml(row.citekey || '')}</button></td>
      <td>${escapeHtml(row.source || '')}</td>
      <td>${escapeHtml(row.legend || '')}</td>
      <td>${escapeHtml(row.year || '')}</td>
      <td>${escapeHtml(String(row.title || '').slice(0, 120))}</td>
    </tr>
  `).join('');
  holder.innerHTML = `
    <table>
      <thead><tr><th>Citekey</th><th>Source</th><th>Legend</th><th>Year</th><th>Title</th></tr></thead>
      <tbody>${rows}</tbody>
    </table>
  `;
  holder.querySelectorAll('button[data-key]').forEach((btn) => {
    btn.addEventListener('click', () => {
      const key = btn.getAttribute('data-key') || '';
      document.getElementById('target').value = key;
      loadTarget().catch((err) => {
        setStatus({ok:false, error:String(err)});
        showErrorWindow(String(err));
      });
    });
  });
}

function bulkLabelFieldLabel(field){
  const labels = {
    section: 'Section',
    aggsource: 'Aggsource',
    data_type: 'Data type',
    inclusion_in_warehouse: 'Inclusion in warehouse',
    multigeo_reference: 'Multigeo reference'
  };
  return labels[field] || field || '';
}

function bulkLabelValuesForField(field){
  return (bulkLabelState.values || {})[field] || [];
}

function renderBulkLabelControls(){
  const fieldEl = document.getElementById('bulk_label_field');
  const oldEl = document.getElementById('bulk_label_old');
  const newOptsEl = document.getElementById('bulk_label_new_opts');
  if (!fieldEl || !oldEl || !newOptsEl) return;
  const field = fieldEl.value || 'section';
  const values = bulkLabelValuesForField(field);
  const previousOld = oldEl.value || '';
  oldEl.innerHTML = '<option value="">select label</option>';
  values.forEach((item) => {
    const opt = document.createElement('option');
    opt.value = item.value || '';
    opt.textContent = `${item.value || ''} (${item.count || 0})`;
    oldEl.appendChild(opt);
  });
  if (previousOld && values.some((item) => item.value === previousOld)) {
    oldEl.value = previousOld;
  }
  newOptsEl.innerHTML = '';
  values.forEach((item) => {
    const opt = document.createElement('option');
    opt.value = item.value || '';
    newOptsEl.appendChild(opt);
  });
  if (!bulkLabelState.preview) {
    const summaryEl = document.getElementById('bulk_label_summary');
    if (summaryEl) summaryEl.textContent = '';
  }
}

function bulkLabelResetPreview(){
  bulkLabelState.preview = null;
  bulkLabelState.selectedIds = new Set();
  const summaryEl = document.getElementById('bulk_label_summary');
  const holder = document.getElementById('bulk_label_preview_results');
  if (summaryEl) summaryEl.textContent = '';
  if (holder) holder.innerHTML = '';
}

function bulkLabelOnFieldChange(){
  bulkLabelResetPreview();
  renderBulkLabelControls();
}

function bulkLabelPayload(){
  return {
    field: v('bulk_label_field'),
    old_label: v('bulk_label_old'),
    new_label: v('bulk_label_new')
  };
}

function bulkLabelSelectedCount(){
  const preview = bulkLabelState.preview || {};
  const rows = preview.records || [];
  return rows.filter((row) => bulkLabelState.selectedIds.has(row.id)).length;
}

function renderBulkLabelSummary(){
  const summaryEl = document.getElementById('bulk_label_summary');
  if (!summaryEl) return;
  const preview = bulkLabelState.preview;
  if (!preview) {
    summaryEl.textContent = '';
    return;
  }
  const selectedCount = bulkLabelSelectedCount();
  const keywordText = preview.keyword_mirror_updates
    ? ` | Bib keywords mirrored: ${preview.keyword_mirror_updates}`
    : '';
  summaryEl.textContent =
    `${bulkLabelFieldLabel(preview.field)}: '${preview.old_label}' -> '${preview.new_label}' | ` +
    `Selected: ${selectedCount} of ${preview.total_matches || 0}${keywordText}`;
}

function renderBulkLabelPreview(){
  renderBulkLabelSummary();
  const holder = document.getElementById('bulk_label_preview_results');
  const preview = bulkLabelState.preview;
  if (!holder) return;
  if (!preview) {
    holder.innerHTML = '';
    return;
  }
  const rows = preview.records || [];
  if (!rows.length) {
    holder.innerHTML = '<small>No records match this old label.</small>';
    return;
  }
  holder.innerHTML = `
    <table>
      <thead><tr><th>Use</th><th>Source</th><th>Citekey</th><th>Legend</th><th>Keyword mirror</th></tr></thead>
      <tbody>
        ${rows.map((row) => {
          const checked = bulkLabelState.selectedIds.has(row.id) ? 'checked' : '';
          const keywordText = row.keyword_mirror_update ? `${row.keywords_before || ''} -> ${row.keywords_after || ''}` : '';
          return `
            <tr>
              <td><input type="checkbox" class="bulk-label-record" data-id="${escapeHtml(row.id || '')}" ${checked}></td>
              <td>${escapeHtml(row.source || '')}</td>
              <td>${escapeHtml(row.citekey || '')}</td>
              <td>${escapeHtml(row.legend || '')}</td>
              <td>${escapeHtml(keywordText)}</td>
            </tr>
          `;
        }).join('')}
      </tbody>
    </table>
  `;
  holder.querySelectorAll('input.bulk-label-record').forEach((checkbox) => {
    checkbox.addEventListener('change', () => {
      const recordId = checkbox.getAttribute('data-id') || '';
      if (checkbox.checked) bulkLabelState.selectedIds.add(recordId);
      else bulkLabelState.selectedIds.delete(recordId);
      renderBulkLabelSummary();
    });
  });
}

async function maintenanceBulkLabelPreview(){
  try {
    const out = await req('/api/maintenance/bulk_label_preview', bulkLabelPayload());
    bulkLabelState.preview = out;
    bulkLabelState.selectedIds = new Set((out.records || []).map((row) => row.id).filter(Boolean));
    renderBulkLabelPreview();
    setStatusWithChecks(out, 'Bulk label preview complete.', {targetId: 'maintenance_status', includeDuplicateGuidance: false, includeOnlineCompare: false});
  } catch (err) {
    setStatus({ok:false, error:String(err)}, 'maintenance_status');
    showErrorWindow(String(err));
  }
}

function maintenanceBulkLabelSelectAll(selected){
  const preview = bulkLabelState.preview;
  if (!preview) return;
  const ids = (preview.records || []).map((row) => row.id).filter(Boolean);
  bulkLabelState.selectedIds = selected ? new Set(ids) : new Set();
  renderBulkLabelPreview();
}

async function maintenanceBulkLabelApply(){
  try {
    const preview = bulkLabelState.preview;
    if (!preview) throw new Error('Preview the label update before applying it.');
    const recordIds = (preview.records || [])
      .map((row) => row.id)
      .filter((recordId) => bulkLabelState.selectedIds.has(recordId));
    if (!recordIds.length) throw new Error('Select at least one record to update.');
    const ok = confirm(
      `Apply bulk label update?\\n\\n` +
      `${bulkLabelFieldLabel(preview.field)}: '${preview.old_label}' -> '${preview.new_label}'\\n` +
      `Records: ${recordIds.length} of ${preview.total_matches || 0}`
    );
    if (!ok) return;
    const editor = await ensureEditorName('apply this bulk label update');
    const out = await req('/api/maintenance/bulk_label_apply', {
      field: preview.field,
      old_label: preview.old_label,
      new_label: preview.new_label,
      record_ids: recordIds,
      editor_name: editor
    });
    if (out.health) renderMaintenanceHealth(out.health);
    setStatusWithChecks(out, 'Bulk label update complete.', {targetId: 'maintenance_status', includeDuplicateGuidance: false, includeOnlineCompare: false});
    bulkLabelResetPreview();
    await loadOptions();
  } catch (err) {
    setStatus({ok:false, error:String(err)}, 'maintenance_status');
    showErrorWindow(String(err));
  }
}

function maintenancePrimaryRecord(issue){
  if (!issue) return null;
  if (issue.record) return issue.record;
  if (Array.isArray(issue.records) && issue.records.length) return issue.records[0];
  return null;
}

function maintenanceIssueActions(issue, index){
  const actions = [];
  const rec = maintenancePrimaryRecord(issue);
  if (rec) actions.push(`<button class='secondary maintenance-action' data-action='load' data-index='${index}'>Load</button>`);
  if (issue.type === 'source_citekey_mismatch' && rec) {
    actions.push(`<button class='secondary maintenance-action' data-action='normalize' data-index='${index}'>Normalize citekey</button>`);
  }
  if (issue.type === 'duplicate_citekey' && issue.severity !== 'intentional') {
    actions.push(`<button class='secondary maintenance-action' data-action='mark_shared' data-index='${index}'>Mark shared</button>`);
  }
  if (issue.type === 'generated_artifacts_stale' || issue.type === 'artifact_duplicate_keys') {
    actions.push(`<button class='secondary maintenance-action' data-action='rebuild' data-index='${index}'>Rebuild</button>`);
  }
  return actions.join(' ');
}

function renderMaintenanceHealth(out){
  const summary = out.summary || {};
  maintenanceIssues = out.issues || [];
  document.getElementById('maintenance_summary').textContent =
    `Total issues: ${summary.total || 0} | Needs review: ${summary.needs_review || 0} | Needs rebuild: ${summary.needs_rebuild || 0} | Intentional shared citekeys: ${summary.intentional || 0}`;
  const holder = document.getElementById('maintenance_issues');
  if (!maintenanceIssues.length) {
    holder.innerHTML = '<small>No maintenance issues detected.</small>';
    return;
  }
  const rows = maintenanceIssues.slice(0, 300).map((issue, index) => {
    const rec = maintenancePrimaryRecord(issue) || {};
    const target = rec.id ? `${rec.id} / ${rec.source || ''} / ${rec.citekey || ''}` : (issue.citekey || issue.artifact || '');
    return `
      <tr>
        <td>${escapeHtml(issue.severity || '')}</td>
        <td>${escapeHtml(issue.type || '')}</td>
        <td>${escapeHtml(target)}</td>
        <td>${escapeHtml(issue.message || '')}</td>
        <td>${maintenanceIssueActions(issue, index)}</td>
      </tr>
    `;
  }).join('');
  const omitted = maintenanceIssues.length > 300 ? `<p><small>${maintenanceIssues.length - 300} additional issue(s) omitted from this view.</small></p>` : '';
  holder.innerHTML = `
    <table>
      <thead><tr><th>Severity</th><th>Type</th><th>Target</th><th>Message</th><th>Actions</th></tr></thead>
      <tbody>${rows}</tbody>
    </table>
    ${omitted}
  `;
  holder.querySelectorAll('button.maintenance-action').forEach((btn) => {
    btn.addEventListener('click', () => {
      const index = Number(btn.getAttribute('data-index') || '0');
      const action = btn.getAttribute('data-action') || '';
      if (action === 'load') maintenanceLoadRecord(index);
      if (action === 'normalize') maintenanceNormalizeCitekey(index);
      if (action === 'mark_shared') maintenanceMarkSharedCitekey(index);
      if (action === 'rebuild') maintenanceRebuildArtifacts();
    });
  });
}

async function maintenanceLoad(){
  const out = await reqGetJson('/api/maintenance/health');
  renderMaintenanceHealth(out);
  setStatus({ok:true, message:'Maintenance health scan complete.'}, 'maintenance_status');
  return out;
}

async function maintenanceLoadRecord(index){
  const issue = maintenanceIssues[index];
  const rec = maintenancePrimaryRecord(issue);
  if (!rec) return;
  switchBranch('data');
  document.getElementById('mode').value = 'edit';
  onModeChange();
  document.getElementById('target').value = rec.source || rec.citekey || rec.id || '';
  await loadTarget();
}

async function maintenanceRebuildArtifacts(){
  try {
    const out = await req('/api/maintenance/rebuild_artifacts', {});
    if (out.health) renderMaintenanceHealth(out.health);
    setStatusWithChecks(out, 'Maintenance rebuild complete.', {targetId: 'maintenance_status', includeDuplicateGuidance: false, includeOnlineCompare: false});
  } catch (err) {
    setStatus({ok:false, error:String(err)}, 'maintenance_status');
    showErrorWindow(String(err));
  }
}

async function maintenanceNormalizeCitekey(index){
  try {
    const issue = maintenanceIssues[index];
    const rec = maintenancePrimaryRecord(issue);
    if (!rec) throw new Error('No record is attached to this issue.');
    const ok = confirm(`Normalize citekey to source for ${rec.id}?\\n\\n${rec.citekey} -> ${rec.source}`);
    if (!ok) return;
    const editor = await ensureEditorName('normalize this citekey');
    const out = await req('/api/maintenance/normalize_citekey', {target: rec.id || rec.source || rec.citekey, editor_name: editor});
    if (out.health) renderMaintenanceHealth(out.health);
    setStatusWithChecks(out, 'Maintenance normalization complete.', {targetId: 'maintenance_status', includeDuplicateGuidance: false, includeOnlineCompare: false});
  } catch (err) {
    setStatus({ok:false, error:String(err)}, 'maintenance_status');
    showErrorWindow(String(err));
  }
}

async function maintenanceMarkSharedCitekey(index){
  try {
    const issue = maintenanceIssues[index];
    if (!issue || issue.type !== 'duplicate_citekey') throw new Error('Select a duplicate citekey issue.');
    const citekey = issue.citekey || '';
    const defaultGroup = citekey ? `shared-${citekey}` : 'shared-citekey';
    const group = (prompt('Shared citekey group:', defaultGroup) || '').trim();
    if (!group) throw new Error('Shared citekey group is required.');
    const note = (prompt('Shared citekey note:', 'Intentional shared bibliography item') || '').trim();
    const editor = await ensureEditorName('mark this shared citekey');
    const recordIds = (issue.records || []).map((rec) => rec.id).filter(Boolean);
    const out = await req('/api/maintenance/mark_shared_citekey', {
      citekey,
      record_ids: recordIds,
      shared_citekey_group: group,
      shared_citekey_note: note,
      editor_name: editor
    });
    if (out.health) renderMaintenanceHealth(out.health);
    setStatusWithChecks(out, 'Shared citekey marked.', {targetId: 'maintenance_status', includeDuplicateGuidance: false, includeOnlineCompare: false});
  } catch (err) {
    setStatus({ok:false, error:String(err)}, 'maintenance_status');
    showErrorWindow(String(err));
  }
}

async function parseBib(){
  try{
    const j = await req('/api/parse_bib', {text: document.getElementById('bib_paste').value});
    const b = j.bib || {};
    document.getElementById('bib_entry_type').value = b.entry_type || '';
    document.getElementById('bib_title').value = b.title || '';
    document.getElementById('bib_author').value = b.author || '';
    document.getElementById('bib_year').value = b.year || '';
    document.getElementById('bib_month').value = b.month || '';
    document.getElementById('bib_journal').value = b.journal || '';
    document.getElementById('bib_booktitle').value = b.booktitle || '';
    document.getElementById('bib_volume').value = b.volume || '';
    document.getElementById('bib_number').value = b.number || '';
    document.getElementById('bib_pages').value = b.pages || '';
    document.getElementById('bib_institution').value = b.institution || '';
    document.getElementById('bib_publisher').value = b.publisher || '';
    document.getElementById('bib_doi').value = b.doi || '';
    document.getElementById('bib_url').value = b.url || '';
    if (!v('link') && b.url) document.getElementById('link').value = b.url;
    document.getElementById('bib_urldate').value = b.urldate || '';
    document.getElementById('bib_keywords').value = b.keywords || '';
    document.getElementById('bib_note').value = b.note || '';
    document.getElementById('bib_abstract').value = b.abstract || '';
    if (!v('source_key') && j.source_key) document.getElementById('source_key').value = j.source_key;
    onEntryTypeChange();
    trySuggestLegend();
    markDirty();
    setStatus({ok:true, message:'BibTeX parsed. Fields were overwritten with parsed values.'});
  }catch(err){ setStatus({ok:false, error:String(err)}); }
}

async function loadTarget(){
  try{
    if (!v('target').trim()) {
      throw new Error('Please select an existing entry in Edit target first.');
    }
    let r;
    try {
      r = await fetch('/api/record?target=' + encodeURIComponent(v('target')));
    } catch (err) {
      throw new Error('Could not reach local server while loading the target entry.');
    }
    const j = await r.json();
    if(!r.ok) {
      const matchLines = (j.matches || []).map((m) => `${m.id}: source=${m.source}, citekey=${m.citekey}, legend=${m.legend}, year=${m.year}`);
      throw new Error((j.error || `Load failed (HTTP ${r.status}).`) + (matchLines.length ? `\\n\\nMatches:\\n- ${matchLines.join('\\n- ')}` : ''));
    }
    const rec = j.record || {};
    document.getElementById('section').value = rec.section || '';
    document.getElementById('aggsource').value = rec.aggsource || '';
    document.getElementById('legend').value = rec.legend || '';
    document.getElementById('source_key').value = rec.source || rec.citekey || '';
    document.getElementById('source_value').value = rec.source || '';
    document.getElementById('citekey_value').value = rec.citekey || rec.source || '';
    loadedSourceKey = rec.source || rec.citekey || '';
    loadedSourceValue = rec.source || '';
    loadedCitekeyValue = rec.citekey || rec.source || '';
    document.getElementById('data_type').value = rec.data_type || '';
    document.getElementById('link').value = rec.link || '';
    document.getElementById('ref_link').value = rec.ref_link || '';
    document.getElementById('inclusion_in_warehouse').value = rec.inclusion_in_warehouse || '';
    document.getElementById('multigeo_reference').value = rec.multigeo_reference || '';
    document.getElementById('metadata').value = rec.metadata || '';
    document.getElementById('metadatalink').value = rec.metadatalink || '';
    document.getElementById('shared_citekey_group').value = rec.shared_citekey_group || '';
    document.getElementById('shared_citekey_note').value = rec.shared_citekey_note || '';
    const b = rec.bib || {};
    document.getElementById('bib_entry_type').value = b.entry_type || '';
    document.getElementById('bib_title').value = b.title || '';
    document.getElementById('bib_author').value = b.author || '';
    document.getElementById('bib_year').value = b.year || '';
    document.getElementById('bib_month').value = b.month || '';
    document.getElementById('bib_journal').value = b.journal || '';
    document.getElementById('bib_booktitle').value = b.booktitle || '';
    document.getElementById('bib_volume').value = b.volume || '';
    document.getElementById('bib_number').value = b.number || '';
    document.getElementById('bib_pages').value = b.pages || '';
    document.getElementById('bib_institution').value = b.institution || '';
    document.getElementById('bib_publisher').value = b.publisher || '';
    document.getElementById('bib_doi').value = b.doi || '';
    document.getElementById('bib_url').value = b.url || '';
    document.getElementById('bib_urldate').value = b.urldate || '';
    document.getElementById('bib_keywords').value = b.keywords || '';
    document.getElementById('bib_note').value = b.note || '';
    document.getElementById('bib_abstract').value = b.abstract || '';
    onEntryTypeChange();
    clearDirty();
    setStatus({ok:true, loaded: rec.id || v('target')});
  }catch(err){
    setStatus({ok:false, error:String(err)});
    showErrorWindow(String(err));
  }
}

async function validateOnly(){
  try{
    const out = await req('/api/validate_entry', getPayload());
    setStatusWithChecks(out, 'Validation run complete.');
    if (!out.ok || (out.errors && out.errors.length)) {
      showErrorWindow((out.errors || []).join('\\n') || 'Validation failed.');
    }
  }
  catch(err){
    if (err && err.error_code === 'stale_artifacts') {
      setStatusWithChecks(err, 'Validation failed.');
    } else {
      setStatus({ok:false, error:String(err)});
    }
    showErrorWindow(String(err));
  }
}

function resetDataAddFormAfterSave(){
  const ids = [
    'bib_paste',
    'target',
    'section',
    'aggsource',
    'legend',
    'source_key',
    'source_value',
    'citekey_value',
    'link',
    'data_type',
    'ref_link',
    'inclusion_in_warehouse',
    'multigeo_reference',
    'metadatalink',
    'metadata',
    'shared_citekey_group',
    'shared_citekey_note',
    'bib_entry_type',
    'bib_title',
    'bib_author',
    'bib_year',
    'bib_month',
    'bib_journal',
    'bib_booktitle',
    'bib_volume',
    'bib_number',
    'bib_pages',
    'bib_institution',
    'bib_publisher',
    'bib_doi',
    'bib_url',
    'bib_urldate',
    'bib_keywords',
    'bib_note',
    'bib_abstract'
  ];
  ids.forEach((id) => {
    const el = document.getElementById(id);
    if (el) el.value = '';
  });
  loadedSourceKey = '';
  loadedSourceValue = '';
  loadedCitekeyValue = '';
  delete document.getElementById('legend').dataset.userEdited;
  onEntryTypeChange();
  clearDirty();
  const next = document.getElementById('bib_paste');
  if (next) next.focus();
}

async function applyAndBuild(){
  try{
    const payload = getPayload();
    const emptyAddPayload = isEmptyAddPayload(payload);
    if (payload.mode === 'edit') {
      const beforeSource = (loadedSourceValue || '').trim();
      const beforeCitekey = (loadedCitekeyValue || '').trim();
      const afterSource = (v('source_value') || '').trim();
      const afterCitekey = (v('citekey_value') || '').trim();
      if ((beforeSource && afterSource && beforeSource !== afterSource) || (beforeCitekey && afterCitekey && beforeCitekey !== afterCitekey)) {
        const ok = confirm(
          `You are changing Source/Citekey identifiers.\\n\\n` +
          `Source: '${beforeSource}' -> '${afterSource}'\\n` +
          `Citekey: '${beforeCitekey}' -> '${afterCitekey}'\\n\\n` +
          `This is a compatibility change and will add alias mapping for changed keys. Continue?`
        );
        if (!ok) {
          throw new Error('Save cancelled. Key rename was not confirmed.');
        }
        payload.key_rename_confirmed = true;
      }
    }
    if (!emptyAddPayload) {
      payload.editor_name = await ensureEditorName('save this entry');
    }
    const out = await req('/api/apply_and_build', payload);
    const addReadyMessage = (payload.mode === 'add' && !emptyAddPayload) ? 'Next: The form was cleared and is ready for another entry.' : '';
    setStatusWithChecks(out, 'Save complete.', {nextMessage: addReadyMessage});
    try {
      await loadOptions();
    } catch (optErr) {
      const current = document.getElementById('status').textContent || '';
      setStatus(`${current}\\n\\nWarning: ${String(optErr)}`);
    }
    if (payload.mode === 'add' && !emptyAddPayload) {
      resetDataAddFormAfterSave();
    } else {
      if (payload.mode === 'edit') {
        loadedSourceValue = v('source_value');
        loadedCitekeyValue = v('citekey_value');
        loadedSourceKey = loadedSourceValue || loadedCitekeyValue;
      }
      clearDirty();
    }
  }
  catch(err){
    if (err && err.error_code === 'stale_artifacts') {
      setStatusWithChecks(err, 'Save failed.');
    } else {
      setStatus({ok:false, error:String(err)});
    }
    showErrorWindow(String(err));
  }
}

async function compareOnlineBib(){
  try{
    const out = await req('/api/compare_online_bib', {});
    setStatusWithChecks(out, 'Online comparison complete.');
  } catch (err) {
    setStatus({ok:false, error:String(err)});
    showErrorWindow(String(err));
  }
}

async function wealthCompareOnlineBib(){
  try{
    const out = await req('/api/wealth/compare_online_bib', {});
    setStatusWithChecks(out, 'Online comparison complete.', {
      targetId: 'wealth_status',
      modeValue: wv('wealth_mode'),
      includeDuplicateGuidance: false
    });
  } catch (err) {
    setStatus({ok:false, error:String(err)}, 'wealth_status');
    showErrorWindow(String(err));
  }
}

async function pollRefLinkReviewScanStatus(scanId){
  while (scanId && refLinkReviewState.scan_id === scanId) {
    const out = await reqGetJson(`/api/ref_link_review_scan_status?scan_id=${encodeURIComponent(scanId)}`);
    if (refLinkReviewState.scan_id !== scanId) return null;
    applyRefLinkReviewScanStatus(out);
    renderRefLinkReviewPanel();
    if (out.stage === 'complete') return out;
    if (out.stage === 'failed') {
      throw new Error(out.error || out.message || 'Ref_link review scan failed.');
    }
    await new Promise((resolve) => window.setTimeout(resolve, 350));
  }
  return null;
}

async function scanRefLinkReview(){
  try {
    const benchmarkUrl = String(refLinkReviewState.benchmark_url || '').trim();
    if (benchmarkUrl && !/^https?:\/\//i.test(benchmarkUrl)) {
      throw new Error('Benchmark URL must start with http:// or https://.');
    }
    startRefLinkReviewScanState({stage: 'fetching_live_bibbase', message: 'Starting ref_link review scan...'});
    renderRefLinkReviewPanel();
    const out = await req('/api/ref_link_review_scan', {benchmark_url: benchmarkUrl});
    startRefLinkReviewScanState(out);
    renderRefLinkReviewPanel();
    const final = await pollRefLinkReviewScanStatus(out.scan_id);
    if (final && final.review) {
      setStatusWithChecks(final.review, 'Ref_link review scan complete.', { includeOnlineCompare: false });
    }
  } catch (err) {
    refLinkReviewState.modal_open = true;
    refLinkReviewState.scan_status = {
      stage: 'failed',
      checked: Number((refLinkReviewState.scan_status || {}).checked || 0),
      total: Number((refLinkReviewState.scan_status || {}).total || 0),
      message: String(err),
      error: String(err),
    };
    renderRefLinkReviewPanel();
    setStatus({ok:false, error:String(err)});
    showErrorWindow(String(err));
  }
}

async function applySelectedRefLinkReview(){
  try {
    const selectedProposalIds = allRefLinkReviewRows()
      .filter((row) => row && row.status !== 'dismissed' && row.proposal_id && refLinkReviewState.selected.has(row.proposal_id))
      .map((row) => row.proposal_id);
    if (!selectedProposalIds.length) {
      throw new Error('Select at least one proposal to apply.');
    }
    const dismissedCount = (refLinkReviewState.dismissed || []).length;
    const overrides = {};
    selectedProposalIds.forEach((proposalId) => {
      const overrideValue = refLinkReviewCurrentOverride(proposalId);
      if (overrideValue) overrides[proposalId] = overrideValue;
    });
    const overrideCount = Object.keys(overrides).length;
    const benchmarkUsedForApply = refLinkReviewCurrentBenchmarkUrl();
    const currentBenchmarkInput = String(refLinkReviewState.benchmark_url || '').trim();
    const benchmarkChangedAfterScan = currentBenchmarkInput && benchmarkUsedForApply && currentBenchmarkInput !== benchmarkUsedForApply;
    const fileList = [
      'code/tools/metadata/sources/sources.yaml',
      'code/tools/metadata/sources/change_log.yaml',
      'handmade_tables/dictionary.xlsx',
      'documentation/BibTeX files/GCWealthProject_DataSourcesLibrary.bib',
      'documentation/BibTeX files/BothLibraries.bib',
    ];
    const msg =
      `Apply ${selectedProposalIds.length} selected ref_link proposal(s)?\n\n` +
      `Dismissed this session: ${dismissedCount}\n\n` +
      `Manual overrides in selection: ${overrideCount}\n\n` +
      (benchmarkChangedAfterScan
        ? `The benchmark field changed after the last scan. Apply will use the last scanned benchmark until you refresh.\n\n`
        : '') +
      `This will modify:\n- ${fileList.join('\\n- ')}`;
    if (!confirm(msg)) return;
    const editorName = await ensureEditorName('apply selected ref_link proposals');
    const out = await req('/api/ref_link_review_apply', {
      selected_proposal_ids: selectedProposalIds,
      editor_name: editorName,
      overrides,
      benchmark_url: benchmarkUsedForApply,
    });
    const next = hydrateRefLinkReviewState(out, refLinkReviewState);
    const remainingTotal = (next.ready_to_apply || []).length + (next.needs_review || []).length;
    next.scan_status = {
      stage: 'complete',
      checked: remainingTotal,
      total: remainingTotal,
      message: String(out.message || 'Ref_link proposals applied.'),
      error: '',
    };
    next.scan_id = refLinkReviewState.scan_id;
    refLinkReviewState = next;
    renderRefLinkReviewPanel();
    setStatusWithChecks(out, 'Ref_link proposals applied.', { includeOnlineCompare: false });
  } catch (err) {
    setStatus({ok:false, error:String(err)});
    showErrorWindow(String(err));
  }
}

async function deleteEntry(){
  try{
    if (v('mode') !== 'edit') throw new Error('Delete is available only in edit mode.');
    if (!v('target').trim()) throw new Error('Select an entry in Edit target before deleting.');
    const preview = await req('/api/delete_preview', {target: v('target')});
    const files = Array.isArray(preview.would_modify_files) ? preview.would_modify_files : [];
    const resolved = preview.record_id ? `Resolved record: ${preview.record_id}\\n\\n` : '';
    const fileList = files.length ? `- ${files.join('\\n- ')}` : '- (no files reported)';
    const msg =
      `Delete entry '${v('target')}'?\\n\\n` +
      `${resolved}` +
      `This will modify:\\n${fileList}\\n\\n` +
      `This action cannot be undone.`;
    if (!confirm(msg)) return;

    const out = await req('/api/delete_entry', {
      target: v('target'),
      editor_name: await ensureEditorName('delete this entry')
    });
    setStatusWithChecks(out, 'Delete complete.');
    await loadOptions();
    clearDirty();
  }catch(err){
    setStatus({ok:false, error:String(err)});
    showErrorWindow(String(err));
  }
}

function wealthOnModeChange(){
  const mode = wv('wealth_mode');
  const isEdit = mode === 'edit';
  for (const id of ['wealthEditTargetWrap', 'wealthEditToolsWrap', 'wealthSearchWrap']) {
    document.getElementById(id).classList.toggle('hidden', !isEdit);
  }
  document.getElementById('wealthBibPasteWrap').classList.toggle('hidden', isEdit);
  document.getElementById('wealthLoadBtn').disabled = !isEdit;
  if (!isEdit) {
    wealthLoadedKey = '';
    document.getElementById('wealth_target').value = '';
    document.getElementById('wealth_extra_fields').value = '{}';
  }
}

function wealthOnEntryTypeChange(){
  const t = wv('wealth_entry_type');
  const show = (id, flag) => document.getElementById(id).classList.toggle('hidden', !flag);
  show('wealth_row_journal', t === 'article');
  show('wealth_row_booktitle', t === 'incollection' || t === 'inproceedings');
  show('wealth_row_publisher', t === 'book' || t === 'incollection' || t === 'inproceedings');
  show('wealth_row_institution', t === 'techreport');
}

function wealthGetPayload(){
  let extraFields = {};
  try {
    extraFields = JSON.parse(wv('wealth_extra_fields') || '{}') || {};
  } catch (err) {
    extraFields = {};
  }
  return {
    mode: wv('wealth_mode'),
    target: wv('wealth_target'),
    editor_name: wv('wealth_editor_name'),
    key_rename_confirmed: false,
    record: {
      key: wv('wealth_key'),
      bib: {
        entry_type: wv('wealth_entry_type'),
        title: wv('wealth_title'),
        author: wv('wealth_author'),
        year: wv('wealth_year'),
        month: wv('wealth_month'),
        journal: wv('wealth_journal'),
        booktitle: wv('wealth_booktitle'),
        volume: wv('wealth_volume'),
        number: wv('wealth_number'),
        pages: wv('wealth_pages'),
        institution: wv('wealth_institution'),
        publisher: wv('wealth_publisher'),
        doi: wv('wealth_doi'),
        url: wv('wealth_url'),
        urldate: wv('wealth_urldate'),
        keywords: wv('wealth_keywords'),
        note: wv('wealth_note'),
        abstract: wv('wealth_abstract'),
        extra_fields: extraFields
      }
    }
  };
}

function wealthIsEmptyAddPayload(payload){
  const mode = String(payload.mode || '').trim().toLowerCase();
  if (mode !== 'add') return false;
  const record = payload.record || {};
  const bib = record.bib || {};
  if (String(record.key || '').trim() !== '') return false;
  const fields = [
    'entry_type', 'title', 'author', 'year', 'month', 'journal', 'booktitle',
    'volume', 'number', 'pages', 'institution', 'publisher', 'doi', 'url',
    'urldate', 'keywords', 'note', 'abstract'
  ];
  for (const key of fields) {
    if (String(bib[key] || '').trim() !== '') return false;
  }
  return true;
}

async function wealthEnsureEditorName(actionLabel){
  let name = (wv('wealth_editor_name') || '').trim();
  if (name) return name;
  const entered = prompt(`Enter your name to ${actionLabel}.`);
  if (entered === null) {
    throw new Error(`${capitalizeFirst(actionLabel)} cancelled. Name was not provided.`);
  }
  name = entered.trim();
  if (!name) {
    throw new Error('Your name is required to continue.');
  }
  document.getElementById('wealth_editor_name').value = name;
  return name;
}

async function wealthLoadOptions(){
  let r;
  try {
    r = await fetch('/api/wealth/options');
  } catch (err) {
    throw new Error('Could not reach local server for wealth options refresh.');
  }
  const j = await r.json();
  if (!r.ok) throw new Error(j.error || `Failed to load wealth options (HTTP ${r.status}).`);
  wealthEntries = j.entries || [];
  const citekeys = j.citekeys || wealthEntries.map(x => x.key).filter(Boolean);
  const dl = document.getElementById('wealth_target_opts');
  dl.innerHTML = '';
  [...new Set(citekeys)].sort((a, b) => String(a).localeCompare(String(b))).forEach((val) => {
    const opt = document.createElement('option');
    opt.value = val;
    dl.appendChild(opt);
  });
  wealthRenderSearchResults();
}

function wealthRenderSearchResults(){
  const holder = document.getElementById('wealth_search_results');
  const q = (wv('wealth_search') || '').trim().toLowerCase();
  const filtered = wealthEntries.filter((row) => {
    if (!q) return true;
    return [row.key, row.title, row.author, row.year, row.entry_type]
      .map(x => String(x || '').toLowerCase())
      .some(x => x.includes(q));
  }).slice(0, 250);

  if (!filtered.length) {
    holder.innerHTML = '<small>No entries match your search.</small>';
    return;
  }
  const rows = filtered.map((row) => `
    <tr>
      <td><button class='search-btn' data-key="${escapeHtml(row.key)}">${escapeHtml(row.key)}</button></td>
      <td>${escapeHtml(row.year || '')}</td>
      <td>${escapeHtml(row.author || '')}</td>
      <td>${escapeHtml(row.title || '')}</td>
      <td>${escapeHtml(row.entry_type || '')}</td>
    </tr>
  `).join('');
  holder.innerHTML = `
    <table>
      <thead><tr><th>Key</th><th>Year</th><th>Author</th><th>Title</th><th>Type</th></tr></thead>
      <tbody>${rows}</tbody>
    </table>
  `;
  holder.querySelectorAll('button[data-key]').forEach((btn) => {
    btn.addEventListener('click', () => {
      const key = btn.getAttribute('data-key') || '';
      document.getElementById('wealth_target').value = key;
      wealthLoadTarget().catch((err) => {
        setStatus({ok:false, error:String(err)}, 'wealth_status');
        showErrorWindow(String(err));
      });
    });
  });
}

async function wealthParseBib(){
  try {
    const j = await req('/api/parse_bib', {text: document.getElementById('wealth_bib_paste').value});
    const b = j.bib || {};
    document.getElementById('wealth_entry_type').value = b.entry_type || '';
    document.getElementById('wealth_title').value = b.title || '';
    document.getElementById('wealth_author').value = b.author || '';
    document.getElementById('wealth_year').value = b.year || '';
    document.getElementById('wealth_month').value = b.month || '';
    document.getElementById('wealth_journal').value = b.journal || '';
    document.getElementById('wealth_booktitle').value = b.booktitle || '';
    document.getElementById('wealth_volume').value = b.volume || '';
    document.getElementById('wealth_number').value = b.number || '';
    document.getElementById('wealth_pages').value = b.pages || '';
    document.getElementById('wealth_institution').value = b.institution || '';
    document.getElementById('wealth_publisher').value = b.publisher || '';
    document.getElementById('wealth_doi').value = b.doi || '';
    document.getElementById('wealth_url').value = b.url || '';
    document.getElementById('wealth_urldate').value = b.urldate || '';
    document.getElementById('wealth_keywords').value = b.keywords || '';
    document.getElementById('wealth_note').value = b.note || '';
    document.getElementById('wealth_abstract').value = b.abstract || '';
    document.getElementById('wealth_extra_fields').value = JSON.stringify(b.extra_fields || {});
    if (!wv('wealth_key') && j.source_key) document.getElementById('wealth_key').value = j.source_key;
    wealthOnEntryTypeChange();
    markWealthDirty();
    setStatus({ok:true, message:'BibTeX parsed for entry.'}, 'wealth_status');
  } catch (err) {
    setStatus({ok:false, error:String(err)}, 'wealth_status');
  }
}

async function wealthLoadTarget(){
  if (!wv('wealth_target').trim()) {
    throw new Error('Please choose a target key from search results or type one.');
  }
  let r;
  try {
    r = await fetch('/api/wealth/record?target=' + encodeURIComponent(wv('wealth_target')));
  } catch (err) {
    throw new Error('Could not reach local server while loading entry.');
  }
  const j = await r.json();
  if (!r.ok) throw new Error(j.error || `Load failed (HTTP ${r.status}).`);
  const rec = j.record || {};
  const b = rec.bib || {};
  document.getElementById('wealth_key').value = rec.key || '';
  wealthLoadedKey = rec.key || '';
  document.getElementById('wealth_entry_type').value = b.entry_type || '';
  document.getElementById('wealth_title').value = b.title || '';
  document.getElementById('wealth_author').value = b.author || '';
  document.getElementById('wealth_year').value = b.year || '';
  document.getElementById('wealth_month').value = b.month || '';
  document.getElementById('wealth_journal').value = b.journal || '';
  document.getElementById('wealth_booktitle').value = b.booktitle || '';
  document.getElementById('wealth_volume').value = b.volume || '';
  document.getElementById('wealth_number').value = b.number || '';
  document.getElementById('wealth_pages').value = b.pages || '';
  document.getElementById('wealth_institution').value = b.institution || '';
  document.getElementById('wealth_publisher').value = b.publisher || '';
  document.getElementById('wealth_doi').value = b.doi || '';
  document.getElementById('wealth_url').value = b.url || '';
  document.getElementById('wealth_urldate').value = b.urldate || '';
  document.getElementById('wealth_keywords').value = b.keywords || '';
  document.getElementById('wealth_note').value = b.note || '';
  document.getElementById('wealth_abstract').value = b.abstract || '';
  document.getElementById('wealth_extra_fields').value = JSON.stringify(b.extra_fields || {});
  wealthOnEntryTypeChange();
  clearWealthDirty();
  setStatus({ok:true, loaded: rec.key || ''}, 'wealth_status');
}

async function wealthValidateOnly(){
  try {
    const out = await req('/api/wealth/validate_entry', wealthGetPayload());
    setStatusWithChecks(out, 'Validation run complete.', {
      targetId: 'wealth_status',
      modeValue: wv('wealth_mode'),
      includeDuplicateGuidance: false,
      includeOnlineCompare: false
    });
    if (!out.ok || (out.errors && out.errors.length)) {
      showErrorWindow((out.errors || []).join('\\n') || 'Validation failed.');
    }
  } catch (err) {
    setStatus({ok:false, error:String(err)}, 'wealth_status');
    showErrorWindow(String(err));
  }
}

function resetWealthAddFormAfterSave(){
  const ids = [
    'wealth_bib_paste',
    'wealth_target',
    'wealth_key',
    'wealth_entry_type',
    'wealth_title',
    'wealth_author',
    'wealth_year',
    'wealth_month',
    'wealth_journal',
    'wealth_booktitle',
    'wealth_volume',
    'wealth_number',
    'wealth_pages',
    'wealth_institution',
    'wealth_publisher',
    'wealth_doi',
    'wealth_url',
    'wealth_urldate',
    'wealth_keywords',
    'wealth_note',
    'wealth_abstract'
  ];
  ids.forEach((id) => {
    const el = document.getElementById(id);
    if (el) el.value = '';
  });
  document.getElementById('wealth_extra_fields').value = '{}';
  wealthLoadedKey = '';
  wealthOnEntryTypeChange();
  clearWealthDirty();
  const next = document.getElementById('wealth_bib_paste');
  if (next) next.focus();
}

async function wealthApplyAndBuild(){
  try {
    const payload = wealthGetPayload();
    const emptyAddPayload = wealthIsEmptyAddPayload(payload);
    if (payload.mode === 'edit') {
      const before = (wealthLoadedKey || '').trim();
      const after = (wv('wealth_key') || '').trim();
      if (before && after && before !== after) {
        const ok = confirm(
          `You are renaming key from '${before}' to '${after}'.\\n\\n` +
          `This affects the bibliography key. Continue?`
        );
        if (!ok) {
          throw new Error('Save cancelled. Key rename was not confirmed.');
        }
        payload.key_rename_confirmed = true;
      }
    }
    if (!emptyAddPayload) {
      payload.editor_name = await wealthEnsureEditorName('save this entry');
    }
    const out = await req('/api/wealth/apply_and_build', payload);
    const addReadyMessage = (payload.mode === 'add' && !emptyAddPayload) ? 'Next: The form was cleared and is ready for another entry.' : '';
    setStatusWithChecks(out, 'Save complete.', {
      targetId: 'wealth_status',
      modeValue: wv('wealth_mode'),
      includeDuplicateGuidance: false,
      nextMessage: addReadyMessage
    });
    try {
      await wealthLoadOptions();
    } catch (optErr) {
      const current = document.getElementById('wealth_status').textContent || '';
      setStatus(`${current}\\n\\nWarning: ${String(optErr)}`, 'wealth_status');
    }
    if (payload.mode === 'add' && !emptyAddPayload) {
      resetWealthAddFormAfterSave();
    } else {
      clearWealthDirty();
    }
  } catch (err) {
    setStatus({ok:false, error:String(err)}, 'wealth_status');
    showErrorWindow(String(err));
  }
}

async function wealthDeleteEntry(){
  try{
    if (wv('wealth_mode') !== 'edit') throw new Error('Delete is available only in edit mode.');
    if (!wv('wealth_target').trim()) throw new Error('Select an entry target before deleting.');
    const msg = `Delete entry '${wv('wealth_target')}'?\\n\\nThis action cannot be undone.`;
    if (!confirm(msg)) return;

    const out = await req('/api/wealth/delete_entry', {
      target: wv('wealth_target'),
      editor_name: await wealthEnsureEditorName('delete this entry')
    });
    setStatusWithChecks(out, 'Delete complete.', {
      targetId: 'wealth_status',
      modeValue: wv('wealth_mode'),
      includeDuplicateGuidance: false
    });
    await wealthLoadOptions();
    clearWealthDirty();
  }catch(err){
    setStatus({ok:false, error:String(err)}, 'wealth_status');
    showErrorWindow(String(err));
  }
}

loadOptions();
onModeChange();
onEntryTypeChange();
wealthOnModeChange();
wealthOnEntryTypeChange();
switchBranch('data');
document.getElementById('legend').addEventListener('input', () => { document.getElementById('legend').dataset.userEdited = '1'; });
document.querySelectorAll('input, textarea, select').forEach(el => {
  if ((el.id || '').startsWith('wealth_')) {
    el.addEventListener('input', markWealthDirty);
    el.addEventListener('change', markWealthDirty);
  } else {
    el.addEventListener('input', markDirty);
    el.addEventListener('change', markDirty);
  }
});
window.addEventListener('beforeunload', (e) => {
  if (isRelaunching) return;
  if (!dirty && !wealthDirty) return;
  e.preventDefault();
  e.returnValue = '';
});
setInterval(() => { fetch('/api/ping').catch(() => {}); }, 2000);
</script>
</body></html>"""


class App:
    def __init__(self, registry: Path, aliases: Path, changelog: Path):
        self.registry_path = registry
        self.aliases_path = aliases
        self.changelog_path = changelog
        self.last_ping = time.time()
        self.idle_timeout_seconds = 60 * 60
        self.stop_reason = "server stopped"
        self.ref_link_review_scans: Dict[str, dict] = {}
        self.ref_link_review_scan_lock = threading.Lock()

    @property
    def registry(self):
        return load_registry(self.registry_path)

    def save(self, reg: dict):
        save_registry(self.registry_path, reg)

    def artifact_paths(self, reg: dict) -> List[Path]:
        cfg = reg.get("config", {}) or {}
        dictionary_output = _dictionary_output_path(cfg)
        bib_output = _data_bib_path(cfg)
        both_bib_output = _both_bib_path(cfg)
        return [self.registry_path, self.changelog_path, self.aliases_path, dictionary_output, bib_output, both_bib_output]

    def delete_preview_paths(self, reg: dict) -> List[Path]:
        cfg = reg.get("config", {}) or {}
        return [self.registry_path, self.changelog_path, _dictionary_output_path(cfg), _data_bib_path(cfg), _both_bib_path(cfg)]

    def wealth_artifact_paths(self, reg: dict) -> List[Path]:
        cfg = reg.get("config", {}) or {}
        return [_wealth_bib_path(cfg), _both_bib_path(cfg), _wealth_change_log_path(cfg)]

    def _cleanup_ref_link_review_scans(self):
        cutoff = time.time() - 900
        with self.ref_link_review_scan_lock:
            stale_ids = [
                scan_id
                for scan_id, scan in self.ref_link_review_scans.items()
                if scan.get("updated_at", 0) < cutoff
            ]
            for scan_id in stale_ids:
                self.ref_link_review_scans.pop(scan_id, None)

    def _set_ref_link_review_scan(self, scan_id: str, **updates):
        with self.ref_link_review_scan_lock:
            scan = self.ref_link_review_scans.get(scan_id)
            if not scan:
                return
            scan.update(updates)
            scan["updated_at"] = time.time()

    def start_ref_link_review_scan(self, benchmark_url: str = "") -> dict:
        self._cleanup_ref_link_review_scans()
        registry = self.registry
        total = len(registry.get("records", []))
        scan_id = uuid.uuid4().hex
        initial = {
            "scan_id": scan_id,
            "stage": "fetching_live_bibbase",
            "checked": 0,
            "total": total,
            "message": "Fetching live BibBase...",
            "review": None,
            "error": "",
            "updated_at": time.time(),
        }
        with self.ref_link_review_scan_lock:
            self.ref_link_review_scans[scan_id] = initial

        def run_scan():
            try:
                def stage_callback(stage: str, message: str):
                    self._set_ref_link_review_scan(scan_id, stage=stage, message=message)

                def progress_callback(checked: int, total_count: int, _record_id: str):
                    self._set_ref_link_review_scan(
                        scan_id,
                        stage="comparing_registry",
                        checked=checked,
                        total=total_count,
                        message=f"Comparing registry records ({checked} / {total_count})",
                    )

                review = fetch_and_scan_registry_ref_links(
                    registry,
                    progress_callback=progress_callback,
                    stage_callback=stage_callback,
                    benchmark_url_override=benchmark_url,
                )
                if not review.get("ok"):
                    self._set_ref_link_review_scan(
                        scan_id,
                        stage="failed",
                        error=review.get("message", "Ref_link proposal scan failed."),
                        message=review.get("message", "Ref_link proposal scan failed."),
                        review=None,
                    )
                    return
                self._set_ref_link_review_scan(
                    scan_id,
                    stage="complete",
                    checked=total,
                    total=total,
                    message="Ref_link proposal scan complete.",
                    review={
                        **review,
                        "operation": "ref_link_review_scan",
                        "checks": [
                            {
                                "name": "Registry-wide ref_link review scan",
                                "passed": True,
                                "detail": (
                                    f"Ready to apply: {review.get('summary', {}).get('ready_to_apply', 0)}, "
                                    f"Needs review: {review.get('summary', {}).get('needs_review', 0)}"
                                ),
                            }
                        ],
                        "warnings": [],
                        "errors": [],
                        "message": "Ref_link proposal scan complete.",
                    },
                    error="",
                )
            except Exception as exc:  # pylint: disable=broad-except
                self._set_ref_link_review_scan(
                    scan_id,
                    stage="failed",
                    error=str(exc),
                    message=f"Ref_link proposal scan failed: {exc}",
                    review=None,
                )

        threading.Thread(target=run_scan, daemon=True).start()
        return dict(initial)

    def get_ref_link_review_scan(self, scan_id: str) -> dict:
        self._cleanup_ref_link_review_scans()
        with self.ref_link_review_scan_lock:
            scan = self.ref_link_review_scans.get(scan_id)
            if not scan:
                raise KeyError(scan_id)
            return dict(scan)


def file_mtimes(paths: List[Path]) -> Dict[str, int]:
    out: Dict[str, int] = {}
    for p in paths:
        try:
            out[str(p)] = p.stat().st_mtime_ns
        except FileNotFoundError:
            out[str(p)] = -1
    return out


def modified_paths(before: Dict[str, int], after: Dict[str, int]) -> List[str]:
    return sorted([p for p in after.keys() if before.get(p, -1) != after.get(p, -1)])


def _coerce_timeout_seconds(value, default: int = 20) -> int:
    try:
        timeout = int(value)
    except (TypeError, ValueError):
        timeout = default
    return max(1, min(120, timeout))


def _trim_diff_preview(lines: List[str], max_lines: int = ONLINE_COMPARE_MAX_DIFF_LINES, max_chars: int = ONLINE_COMPARE_MAX_DIFF_CHARS) -> Dict[str, object]:
    shown: List[str] = []
    total_chars = 0
    truncated = False
    for idx, line in enumerate(lines):
        if idx >= max_lines:
            truncated = True
            break
        next_chars = total_chars + len(line) + 1
        if next_chars > max_chars:
            truncated = True
            break
        shown.append(line)
        total_chars = next_chars
    if truncated:
        shown.append(f"... [diff truncated: showing {len(shown)} of {len(lines)} lines]")
    return {"preview": "\n".join(shown), "truncated": truncated}


def _normalize_github_repo_url(url: str) -> str:
    raw = normalize_whitespace(url)
    if not raw:
        return ""
    if raw.startswith("git@github.com:"):
        raw = "https://github.com/" + raw[len("git@github.com:") :]
    if raw.startswith("ssh://git@github.com/"):
        raw = "https://github.com/" + raw[len("ssh://git@github.com/") :]
    raw = raw.rstrip("/")
    if raw.endswith(".git"):
        raw = raw[: -len(".git")]
    return raw.lower()


def _parse_github_raw_reference(reference_url: str) -> Dict[str, str]:
    parsed = urlparse(reference_url)
    if parsed.netloc.lower() != "raw.githubusercontent.com":
        return {}
    parts = [p for p in parsed.path.split("/") if p]
    if len(parts) < 4:
        return {}
    owner = parts[0]
    repo = parts[1]
    branch = parts[2]
    path = unquote("/".join(parts[3:]))
    if not owner or not repo or not branch or not path:
        return {}
    return {"owner": owner, "repo": repo, "branch": branch, "path": path}


def _run_git(args: List[str], timeout_seconds: int) -> subprocess.CompletedProcess:
    return subprocess.run(
        ["git"] + args,
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        timeout=timeout_seconds,
        cwd=str(REPO_ROOT),
    )


def _remote_candidates(owner: str, repo: str, timeout_seconds: int) -> List[str]:
    target = f"https://github.com/{owner}/{repo}".lower()
    names: List[str] = []
    try:
        proc = _run_git(["remote", "-v"], timeout_seconds)
    except Exception:
        return []
    for line in proc.stdout.decode("utf-8", errors="replace").splitlines():
        parts = line.split()
        if len(parts) < 3 or parts[2] != "(fetch)":
            continue
        name, remote_url = parts[0], parts[1]
        if _normalize_github_repo_url(remote_url) == target:
            names.append(name)
    # Prefer upstream first for canonical repo, then origin.
    ordered = sorted(set(names), key=lambda x: (0 if x == "upstream" else 1 if x == "origin" else 2, x))
    return ordered


def _fetch_github_raw_via_git(reference_url: str, timeout_seconds: int) -> Dict[str, str]:
    ref = _parse_github_raw_reference(reference_url)
    if not ref:
        raise RuntimeError("URL is not a supported raw.githubusercontent.com path.")
    owner = ref["owner"]
    repo = ref["repo"]
    branch = ref["branch"]
    path = ref["path"]

    remotes = _remote_candidates(owner, repo, timeout_seconds)
    if not remotes:
        raise RuntimeError(f"No git remote matched github.com/{owner}/{repo}.")

    errors: List[str] = []
    for remote in remotes:
        spec = f"{remote}/{branch}:{path}"
        try:
            proc = _run_git(["show", spec], timeout_seconds)
            return {"text": proc.stdout.decode("utf-8", errors="replace"), "method": f"git-remote:{remote}/{branch}"}
        except Exception as show_exc:  # pylint: disable=broad-except
            errors.append(f"{remote} show failed: {show_exc}")

        # Try to refresh the remote branch, then retry show.
        try:
            _run_git(["fetch", "--quiet", remote, branch], timeout_seconds)
            proc = _run_git(["show", spec], timeout_seconds)
            return {"text": proc.stdout.decode("utf-8", errors="replace"), "method": f"git-fetch:{remote}/{branch}"}
        except Exception as fetch_exc:  # pylint: disable=broad-except
            errors.append(f"{remote} fetch/show failed: {fetch_exc}")

    raise RuntimeError("; ".join(errors) if errors else "git fallback failed")


def _fetch_url_text(reference_url: str, timeout_seconds: int) -> Dict[str, str]:
    req = Request(reference_url, headers={"User-Agent": "SourceRegistryUI/1.0"})
    try:
        with urlopen(req, timeout=timeout_seconds) as resp:  # nosec B310 (URL is user-configured reference)
            remote_raw = resp.read()
            charset = resp.headers.get_content_charset() or "utf-8"
        return {"text": remote_raw.decode(charset, errors="replace"), "method": "python-urllib"}
    except Exception as exc:  # pylint: disable=broad-except
        msg = str(exc)
        curl_error = "curl not available"
        curl_bin = shutil.which("curl")
        if curl_bin:
            try:
                proc = subprocess.run(
                    [
                        curl_bin,
                        "--fail",
                        "--location",
                        "--silent",
                        "--show-error",
                        "--max-time",
                        str(timeout_seconds),
                        reference_url,
                    ],
                    check=True,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                )
                return {"text": proc.stdout.decode("utf-8", errors="replace"), "method": "curl-system-trust"}
            except Exception as curl_exc:  # pylint: disable=broad-except
                curl_error = str(curl_exc)

        try:
            git_fetched = _fetch_github_raw_via_git(reference_url, timeout_seconds)
            return git_fetched
        except Exception as git_exc:  # pylint: disable=broad-except
            raise RuntimeError(
                f"{msg}. curl fallback failed: {curl_error}. git fallback also failed: {git_exc}"
            ) from git_exc


def _online_bib_compare_config(registry: dict, library: str) -> dict:
    cfg = registry.get("config", {}) or {}
    if library == "wealth_research":
        return {
            "library": "wealth_research",
            "library_label": "Wealth Research",
            "local_bib_path": _wealth_bib_path(cfg),
            "reference_url": normalize_whitespace(str(cfg.get("wealth_online_bib_reference_url", ""))),
            "reference_url_key": "wealth_online_bib_reference_url",
            "timeout_seconds": _coerce_timeout_seconds(
                cfg.get("wealth_online_bib_timeout_seconds", 20),
                default=20,
            ),
        }
    return {
        "library": "data_sources",
        "library_label": "Data Sources",
        "local_bib_path": _data_bib_path(cfg),
        "reference_url": normalize_whitespace(str(cfg.get("online_bib_reference_url", ""))),
        "reference_url_key": "online_bib_reference_url",
        "timeout_seconds": _coerce_timeout_seconds(cfg.get("online_bib_timeout_seconds", 20), default=20),
    }


def compare_local_bib_with_online(registry: dict, library: str = "data_sources") -> dict:
    compare_cfg = _online_bib_compare_config(registry, library)
    bib_path = compare_cfg["local_bib_path"]
    reference_url = compare_cfg["reference_url"]
    timeout_seconds = compare_cfg["timeout_seconds"]
    base = {
        "library": compare_cfg["library"],
        "library_label": compare_cfg["library_label"],
        "reference_url": reference_url,
        "local_bib_path": str(bib_path),
        "timeout_seconds": timeout_seconds,
        "local_hash": "",
        "remote_hash": "",
        "diff_preview": "",
        "diff_line_count": 0,
        "truncated": False,
        "fetch_method": "",
        "compared_at": now_utc(),
    }

    if not reference_url:
        return {
            **base,
            "ok": False,
            "status": "not_configured",
            "message": f"{compare_cfg['reference_url_key']} is not configured in {DEFAULT_REGISTRY_PATH}.",
        }
    if not bib_path.exists():
        return {
            **base,
            "ok": False,
            "status": "unavailable",
            "message": f"Local bib artifact is missing: {bib_path}",
        }

    try:
        local_text = bib_path.read_text(encoding="utf-8")
    except Exception as exc:  # pylint: disable=broad-except
        return {
            **base,
            "ok": False,
            "status": "unavailable",
            "message": f"Could not read local bib artifact: {exc}",
        }

    local_hash = hashlib.sha256(local_text.encode("utf-8")).hexdigest()
    base["local_hash"] = local_hash

    try:
        fetched = _fetch_url_text(reference_url, timeout_seconds)
        remote_text = fetched.get("text", "")
        base["fetch_method"] = fetched.get("method", "")
    except Exception as exc:  # pylint: disable=broad-except
        return {
            **base,
            "ok": False,
            "status": "unavailable",
            "message": f"Could not fetch online reference: {exc}",
        }

    remote_hash = hashlib.sha256(remote_text.encode("utf-8")).hexdigest()
    base["remote_hash"] = remote_hash

    if local_text == remote_text:
        return {
            **base,
            "ok": True,
            "status": "up_to_date",
            "message": "Local .bib matches the online reference.",
        }

    diff_lines = list(
        unified_diff(
            remote_text.splitlines(),
            local_text.splitlines(),
            fromfile=f"online:{reference_url}",
            tofile=f"local:{bib_path}",
            lineterm="",
        )
    )
    trimmed = _trim_diff_preview(diff_lines)
    preview = str(trimmed.get("preview", ""))
    truncated = bool(trimmed.get("truncated", False))
    message = "Local .bib differs from the online reference."
    if truncated:
        message = message + " Diff preview was truncated."

    return {
        **base,
        "ok": True,
        "status": "different",
        "message": message,
        "diff_preview": preview,
        "diff_line_count": len(diff_lines),
        "truncated": truncated,
    }


class Handler(BaseHTTPRequestHandler):
    app: App = None

    def _send_json(self, payload: dict, status: int = 200):
        data = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def _send_html(self, html: str):
        data = html.encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def _read_json(self):
        n = int(self.headers.get("Content-Length", "0"))
        raw = self.rfile.read(n) if n > 0 else b"{}"
        return json.loads(raw.decode("utf-8"))

    def do_GET(self):
        self.app.last_ping = time.time()
        parsed = urlparse(self.path)
        if parsed.path == "/":
            self._send_html(HTML)
            return

        if parsed.path == "/api/options":
            reg = self.app.registry
            cfg = reg.get("config", {}) or {}
            self._send_json(
                {
                    **suggested_options(reg.get("records", [])),
                    "ref_link_review_benchmark_url": normalize_whitespace(cfg.get("bibbase_profile_source_url", "")),
                }
            )
            return

        if parsed.path == "/api/wealth/options":
            try:
                reg = self.app.registry
                cfg = reg.get("config", {}) or {}
                wealth_blob = _read_bib_with_duplicate_detection(_wealth_bib_path(cfg))
                self._send_json(
                    {
                        "entries": _wealth_search_rows(wealth_blob.get("entries", {})),
                        "citekeys": sorted(wealth_blob.get("entries", {}).keys(), key=str.lower),
                        "entry_types": WEALTH_ENTRY_TYPES,
                        "duplicate_keys": wealth_blob.get("duplicate_keys", []),
                    }
                )
            except Exception as exc:  # pylint: disable=broad-except
                self._send_json({"error": str(exc)}, 400)
            return

        if parsed.path == "/api/ping":
            self.app.last_ping = time.time()
            self._send_json({"ok": True})
            return

        if parsed.path == "/api/history":
            reg = self.app.registry
            self._send_json({"ok": True, **build_history_feed(self.app, reg)})
            return

        if parsed.path == "/api/maintenance/health":
            reg = self.app.registry
            self._send_json(build_maintenance_health(reg, self.app.registry_path))
            return

        if parsed.path == "/api/ref_link_review_scan_status":
            qs = parse_qs(parsed.query)
            scan_id = normalize_whitespace((qs.get("scan_id") or [""])[0])
            if not scan_id:
                self._send_json({"error": "scan_id is required"}, 400)
                return
            try:
                scan = self.app.get_ref_link_review_scan(scan_id)
            except KeyError:
                self._send_json({"error": f"Unknown scan_id: {scan_id}"}, 404)
                return
            self._send_json(
                {
                    "ok": scan.get("stage") != "failed",
                    "scan_id": scan.get("scan_id", scan_id),
                    "stage": scan.get("stage", ""),
                    "checked": scan.get("checked", 0),
                    "total": scan.get("total", 0),
                    "message": scan.get("message", ""),
                    "error": scan.get("error", ""),
                    "review": scan.get("review"),
                }
            )
            return

        if parsed.path == "/api/record":
            reg = self.app.registry
            qs = parse_qs(parsed.query)
            target = (qs.get("target") or [""])[0]
            hits = find_target(reg.get("records", []), target)
            if len(hits) != 1:
                self._send_json(
                    {
                        "error": f"target must match exactly one record; got {len(hits)}",
                        "matches": [record_summary(rec) for rec in hits],
                    },
                    400,
                )
                return
            self._send_json({"record": hits[0]})
            return

        if parsed.path == "/api/wealth/record":
            try:
                reg = self.app.registry
                cfg = reg.get("config", {}) or {}
                qs = parse_qs(parsed.query)
                target = normalize_whitespace((qs.get("target") or [""])[0])
                wealth_blob = _read_bib_with_duplicate_detection(_wealth_bib_path(cfg))
                entries = wealth_blob.get("entries", {})
                if target not in entries:
                    self._send_json({"error": f"target must match exactly one wealth record; got 0"}, 400)
                    return
                self._send_json({"record": _wealth_entry_to_record(target, entries[target])})
            except Exception as exc:  # pylint: disable=broad-except
                self._send_json({"error": str(exc)}, 400)
            return

        self._send_json({"error": "Not found"}, 404)

    def do_POST(self):
        self.app.last_ping = time.time()
        try:
            if self.path == "/api/parse_bib":
                data = self._read_json()
                out = parse_bib_paste(data.get("text", ""))
                self._send_json(out)
                return

            if self.path == "/api/maintenance/rebuild_artifacts":
                reg = self.app.registry
                tracked_paths = self.app.artifact_paths(reg)
                before = file_mtimes(tracked_paths)
                _run_build_sources_artifacts(self.app.registry_path)
                after = file_mtimes(tracked_paths)
                changed_files = modified_paths(before, after)
                self._send_json(
                    {
                        "ok": True,
                        "operation": "maintenance_rebuild_artifacts",
                        "modified_files": changed_files,
                        "file_change_summary": build_file_change_summary(changed_files, "build_only", "", [], False),
                        "health": build_maintenance_health(self.app.registry, self.app.registry_path),
                        "message": "Generated artifacts rebuilt.",
                    }
                )
                return

            if self.path == "/api/maintenance/bulk_label_preview":
                data = self._read_json()
                reg = self.app.registry
                out = bulk_label_preview(
                    reg,
                    data.get("field", ""),
                    data.get("old_label", ""),
                    data.get("new_label", ""),
                )
                self._send_json(out)
                return

            if self.path == "/api/maintenance/bulk_label_apply":
                data = self._read_json()
                reg = self.app.registry
                tracked_paths = self.app.artifact_paths(reg)
                before = file_mtimes(tracked_paths)
                out = apply_bulk_label_update(reg, data, self.app.changelog_path)
                self.app.save(reg)
                _run_build_sources_artifacts(self.app.registry_path)
                after = file_mtimes(tracked_paths)
                changed_files = modified_paths(before, after)
                self._send_json(
                    {
                        "ok": True,
                        **out,
                        "modified_files": changed_files,
                        "file_change_summary": build_file_change_summary(
                            changed_files,
                            out.get("operation", "bulk_label_update"),
                            out.get("record_id", ""),
                            out.get("changed_fields", []),
                            False,
                        ),
                        "health": build_maintenance_health(reg, self.app.registry_path),
                    }
                )
                return

            if self.path == "/api/maintenance/mark_shared_citekey":
                data = self._read_json()
                reg = self.app.registry
                records = reg.get("records", [])
                citekey = normalize_whitespace(data.get("citekey", ""))
                record_ids = [normalize_whitespace(str(value)) for value in data.get("record_ids", []) if normalize_whitespace(str(value))]
                group = normalize_whitespace(data.get("shared_citekey_group", ""))
                note = normalize_whitespace(data.get("shared_citekey_note", ""))
                editor = normalize_whitespace(data.get("editor_name", ""))
                if not citekey:
                    raise ValueError("citekey is required")
                if not group:
                    raise ValueError("shared_citekey_group is required")
                if not editor:
                    raise ValueError("editor_name is required")

                selected = [
                    rec
                    for rec in records
                    if normalize_whitespace(str(rec.get("citekey", ""))) == citekey
                    and (not record_ids or normalize_whitespace(str(rec.get("id", ""))) in record_ids)
                ]
                if len(selected) < 2:
                    raise ValueError("At least two matching records are required to mark a shared citekey")

                tracked_paths = self.app.artifact_paths(reg)
                before = file_mtimes(tracked_paths)
                timestamp = now_utc()
                changed_ids = []
                for rec in selected:
                    rec["shared_citekey_group"] = group
                    rec["shared_citekey_note"] = note
                    rec["updated_at"] = timestamp
                    rec["updated_by"] = editor
                    changed_ids.append(normalize_whitespace(str(rec.get("id", ""))))
                    append_change(self.app.changelog_path, "edit", rec.get("id", ""), "Marked shared citekey via maintenance", editor)
                self.app.save(reg)
                _run_build_sources_artifacts(self.app.registry_path)
                after = file_mtimes(tracked_paths)
                changed_files = modified_paths(before, after)
                self._send_json(
                    {
                        "ok": True,
                        "operation": "maintenance_mark_shared_citekey",
                        "citekey": citekey,
                        "record_ids": changed_ids,
                        "modified_files": changed_files,
                        "file_change_summary": build_file_change_summary(changed_files, "edit", citekey, ["shared_citekey_group", "shared_citekey_note"], False),
                        "health": build_maintenance_health(reg, self.app.registry_path),
                        "message": f"Marked {len(changed_ids)} record(s) as intentionally sharing {citekey}.",
                    }
                )
                return

            if self.path == "/api/maintenance/normalize_citekey":
                data = self._read_json()
                reg = self.app.registry
                records = reg.get("records", [])
                target = normalize_whitespace(data.get("target", ""))
                editor = normalize_whitespace(data.get("editor_name", ""))
                if not target:
                    raise ValueError("target is required")
                if not editor:
                    raise ValueError("editor_name is required")
                hits = find_target(records, target)
                if len(hits) != 1:
                    self._send_json(
                        {
                            "ok": False,
                            "error": f"target must match exactly one record; got {len(hits)}",
                            "matches": [record_summary(rec) for rec in hits],
                        },
                        400,
                    )
                    return
                rec = hits[0]
                before_rec = json.loads(json.dumps(rec))
                source = normalize_whitespace(str(rec.get("source", "")))
                old_citekey = normalize_whitespace(str(rec.get("citekey", "")))
                if not source:
                    raise ValueError("target record has no source")
                tracked_paths = self.app.artifact_paths(reg)
                before = file_mtimes(tracked_paths)
                reason = "Normalized citekey to source via maintenance"
                if old_citekey != source:
                    rec["citekey"] = source
                    rec["updated_at"] = now_utc()
                    rec["updated_by"] = editor
                    append_alias(self.app.aliases_path, "citekey", old_citekey, source, reason)
                    append_change(self.app.changelog_path, "edit", rec.get("id", ""), reason, editor)
                    self.app.save(reg)
                    _run_build_sources_artifacts(self.app.registry_path)
                after = file_mtimes(tracked_paths)
                changed_files = modified_paths(before, after)
                self._send_json(
                    {
                        "ok": True,
                        "operation": "maintenance_normalize_citekey",
                        "record_id": rec.get("id", ""),
                        "changed_fields": summarize_record_diff(before_rec, rec),
                        "key_renamed": old_citekey != source,
                        "modified_files": changed_files,
                        "file_change_summary": build_file_change_summary(changed_files, "edit", rec.get("id", ""), summarize_record_diff(before_rec, rec), old_citekey != source),
                        "health": build_maintenance_health(reg, self.app.registry_path),
                        "message": "Citekey normalized to source." if old_citekey != source else "Citekey already matched source.",
                    }
                )
                return

            if self.path == "/api/wealth/validate_entry":
                data = self._read_json()
                reg = self.app.registry
                cfg = reg.get("config", {}) or {}
                mode = normalize_whitespace(data.get("mode", "add")).lower()
                target = normalize_whitespace(data.get("target", ""))

                if mode == "add" and is_empty_wealth_add_payload(data):
                    self._send_json(
                        {
                            "ok": True,
                            "errors": [],
                            "warnings": [],
                            "checks": [
                                {
                                    "name": "Empty add form",
                                    "passed": True,
                                    "detail": "No changes made. Fill fields to validate a new entry.",
                                }
                            ],
                            "message": "No changes made.",
                        }
                    )
                    return

                wealth_blob = _read_bib_with_duplicate_detection(_wealth_bib_path(cfg))
                candidate = _wealth_candidate_from_payload(data)
                out = _validate_wealth_candidate(
                    candidate,
                    mode,
                    target,
                    wealth_blob.get("entries", {}),
                    _data_bib_keys(cfg),
                    wealth_blob.get("duplicate_keys", []),
                )
                self._send_json({"ok": len(out.get("errors", [])) == 0, **out})
                return

            if self.path == "/api/wealth/apply_and_build":
                data = self._read_json()
                reg = self.app.registry
                cfg = reg.get("config", {}) or {}
                tracked_paths = self.app.wealth_artifact_paths(reg)
                before = file_mtimes(tracked_paths)
                mode = normalize_whitespace(data.get("mode", "add")).lower()
                target = normalize_whitespace(data.get("target", ""))
                editor = normalize_whitespace(data.get("editor_name", ""))
                key_rename_confirmed = bool(data.get("key_rename_confirmed", False))

                if mode == "add" and is_empty_wealth_add_payload(data):
                    _rebuild_both_bib(cfg)
                    after = file_mtimes(tracked_paths)
                    changed_files = modified_paths(before, after)
                    online_compare = compare_local_bib_with_online(reg, "wealth_research")
                    self._send_json(
                        {
                            "ok": True,
                            "status": "ok",
                            "operation": "build_only",
                            "record_id": "",
                            "changed_fields": [],
                            "warnings": [],
                            "errors": [],
                            "checks": [
                                {
                                    "name": "Empty add form",
                                    "passed": True,
                                    "detail": "No record changes applied. BothLibraries.bib was rebuilt.",
                                }
                            ],
                            "modified_files": changed_files,
                            "online_compare": online_compare,
                            "file_change_summary": build_file_change_summary(changed_files, "build_only", "", [], False),
                            "message": "No changes made. BothLibraries.bib rebuilt.",
                        }
                    )
                    return

                if not editor:
                    raise ValueError("editor_name is required")

                wealth_path = _wealth_bib_path(cfg)
                wealth_log_path = _wealth_change_log_path(cfg)
                wealth_blob = _read_bib_with_duplicate_detection(wealth_path)
                wealth_entries = wealth_blob.get("entries", {})
                candidate = _wealth_candidate_from_payload(data)

                validation = _validate_wealth_candidate(
                    candidate,
                    mode,
                    target,
                    wealth_entries,
                    _data_bib_keys(cfg),
                    wealth_blob.get("duplicate_keys", []),
                )
                if validation.get("errors"):
                    raise ValueError("\n".join(validation["errors"]))

                out: dict = {"status": "ok", "warnings": validation.get("warnings", []), "checks": validation.get("checks", [])}
                if mode == "add":
                    new_entry = _wealth_record_to_entry(candidate)
                    new_key = new_entry.get("key", "")
                    wealth_entries[new_key] = {"entry_type": new_entry.get("entry_type", "misc"), "fields": new_entry.get("fields", {})}
                    write_parsed_bib_entries(wealth_path, wealth_entries, field_order=WEALTH_BIB_FIELDS)
                    _append_wealth_change(wealth_log_path, "add", new_key, "Added via local UI", editor)
                    out.update(
                        {
                            "operation": "add",
                            "record_id": new_key,
                            "changed_fields": _summarize_wealth_record_all_fields(
                                _wealth_entry_to_record(new_key, wealth_entries[new_key])
                            ),
                            "key_renamed": False,
                        }
                    )
                elif mode == "edit":
                    if target not in wealth_entries:
                        raise ValueError(f"Edit target must match exactly one record; got 0")
                    new_entry = _wealth_record_to_entry(candidate)
                    new_key = new_entry.get("key", "")
                    changed_key = target != new_key
                    if changed_key and not key_rename_confirmed:
                        raise ValueError("You changed key. Confirm key rename in the save confirmation prompt.")

                    before_rec = _wealth_entry_to_record(target, wealth_entries[target])
                    if changed_key:
                        del wealth_entries[target]
                    wealth_entries[new_key] = {"entry_type": new_entry.get("entry_type", "misc"), "fields": new_entry.get("fields", {})}
                    write_parsed_bib_entries(wealth_path, wealth_entries, field_order=WEALTH_BIB_FIELDS)
                    _append_wealth_change(wealth_log_path, "edit", new_key, "Edited via local UI", editor)
                    after_rec = _wealth_entry_to_record(new_key, wealth_entries[new_key])
                    out.update(
                        {
                            "operation": "edit",
                            "record_id": new_key,
                            "changed_fields": _summarize_wealth_record_diff(before_rec, after_rec),
                            "key_renamed": changed_key,
                        }
                    )
                else:
                    raise ValueError("mode must be add or edit")

                _rebuild_both_bib(cfg)
                after = file_mtimes(tracked_paths)
                changed = modified_paths(before, after)
                online_compare = compare_local_bib_with_online(reg, "wealth_research")
                self._send_json(
                    {
                        "ok": True,
                        **out,
                        "modified_files": changed,
                        "online_compare": online_compare,
                        "file_change_summary": build_file_change_summary(
                            changed,
                            out.get("operation", mode),
                            out.get("record_id", ""),
                            out.get("changed_fields", []),
                            out.get("key_renamed", False),
                        ),
                        "message": "Entry saved and BothLibraries.bib rebuilt",
                    }
                )
                return

            if self.path == "/api/wealth/delete_entry":
                data = self._read_json()
                reg = self.app.registry
                cfg = reg.get("config", {}) or {}
                target = normalize_whitespace(data.get("target", ""))
                editor = normalize_whitespace(data.get("editor_name", ""))
                if not target:
                    raise ValueError("target is required")
                if not editor:
                    raise ValueError("editor_name is required")

                tracked_paths = self.app.wealth_artifact_paths(reg)
                before = file_mtimes(tracked_paths)
                wealth_path = _wealth_bib_path(cfg)
                wealth_log_path = _wealth_change_log_path(cfg)
                wealth_blob = _read_bib_with_duplicate_detection(wealth_path)
                if wealth_blob.get("duplicate_keys"):
                    raise ValueError(f"Reference library contains duplicate keys: {', '.join(wealth_blob['duplicate_keys'])}")
                wealth_entries = wealth_blob.get("entries", {})
                if target not in wealth_entries:
                    raise ValueError("Delete target must match exactly one record; got 0")

                before_rec = _wealth_entry_to_record(target, wealth_entries[target])
                deleted_fields = _summarize_wealth_record_all_fields(before_rec)
                del wealth_entries[target]
                write_parsed_bib_entries(wealth_path, wealth_entries, field_order=WEALTH_BIB_FIELDS)
                _append_wealth_change(wealth_log_path, "delete", target, "Deleted via local UI", editor)
                _rebuild_both_bib(cfg)

                after = file_mtimes(tracked_paths)
                changed = modified_paths(before, after)
                online_compare = compare_local_bib_with_online(reg, "wealth_research")
                self._send_json(
                    {
                        "ok": True,
                        "record_id": target,
                        "operation": "delete",
                        "changed_fields": deleted_fields,
                        "checks": [{"name": "Delete target resolution", "passed": True, "detail": f"Deleted {target}"}],
                        "modified_files": changed,
                        "online_compare": online_compare,
                        "file_change_summary": build_file_change_summary(changed, "delete", target, deleted_fields, False),
                        "message": "Entry deleted and BothLibraries.bib rebuilt",
                    }
                )
                return

            if self.path == "/api/wealth/compare_online_bib":
                reg = self.app.registry
                online_compare = compare_local_bib_with_online(reg, "wealth_research")
                self._send_json({
                    "ok": True,
                    "operation": "wealth_compare_online_bib",
                    "checks": [],
                    "warnings": [],
                    "errors": [],
                    "online_compare": online_compare,
                    "message": "Online comparison complete",
                })
                return

            if self.path == "/api/compare_online_bib":
                reg = self.app.registry
                online_compare = compare_local_bib_with_online(reg, "data_sources")
                self._send_json({
                    "ok": True,
                    "operation": "compare_online_bib",
                    "checks": [],
                    "warnings": [],
                    "errors": [],
                    "online_compare": online_compare,
                    "message": "Online comparison complete",
                })
                return

            if self.path == "/api/ref_link_review_scan":
                data = self._read_json()
                benchmark_url = normalize_whitespace(data.get("benchmark_url", ""))
                scan = self.app.start_ref_link_review_scan(benchmark_url=benchmark_url)
                self._send_json({"ok": True, "operation": "ref_link_review_scan", **scan})
                return

            if self.path == "/api/ref_link_review_apply":
                data = self._read_json()
                selected_ids = set(data.get("selected_proposal_ids", []))
                editor = normalize_whitespace(data.get("editor_name", ""))
                overrides = data.get("overrides", {}) or {}
                benchmark_url = normalize_whitespace(data.get("benchmark_url", ""))
                if not selected_ids:
                    raise ValueError("selected_proposal_ids is required")
                if not editor:
                    raise ValueError("editor_name is required")

                reg = self.app.registry
                review = fetch_and_scan_registry_ref_links(reg, benchmark_url_override=benchmark_url)
                if not review.get("ok"):
                    self._send_json(review, 400)
                    return
                proposals = list(review.get("ready_to_apply", [])) + list(review.get("needs_review", []))
                tracked_paths = self.app.artifact_paths(reg)
                before = file_mtimes(tracked_paths)
                apply_out = apply_selected_ref_links(reg, proposals, selected_ids, overrides=overrides)
                if apply_out["applied_ids"]:
                    records_by_id = {rec.get("id", ""): rec for rec in reg.get("records", [])}
                    timestamp = now_utc()
                    for record_id in apply_out["applied_ids"]:
                        record = records_by_id.get(record_id)
                        if not record:
                            continue
                        record["updated_at"] = timestamp
                        record["updated_by"] = editor
                        append_change(
                            self.app.changelog_path,
                            "edit",
                            record_id,
                            "Applied ref_link proposal from local UI review",
                            editor,
                        )
                    self.app.save(reg)

                    from build_sources_artifacts import main as build_main  # pylint: disable=import-outside-toplevel
                    import sys  # pylint: disable=import-outside-toplevel

                    argv_orig = sys.argv[:]
                    try:
                        sys.argv = ["build_sources_artifacts.py", "--registry", str(self.app.registry_path)]
                        build_main()
                    finally:
                        sys.argv = argv_orig

                after = file_mtimes(tracked_paths)
                try:
                    refreshed = fetch_and_scan_registry_ref_links(reg, benchmark_url_override=benchmark_url)
                except Exception:  # pylint: disable=broad-except
                    refreshed = review
                modified = modified_paths(before, after)
                invalid_override_ids = apply_out.get("invalid_override_ids", [])
                errors = []
                if invalid_override_ids:
                    errors.append(f"Invalid override URL for proposal(s): {', '.join(invalid_override_ids)}")
                self._send_json(
                    {
                        **refreshed,
                        "ok": True,
                        "operation": "ref_link_review_apply",
                        "applied_ids": apply_out["applied_ids"],
                        "skipped_ids": apply_out["skipped_ids"],
                        "stale_ids": apply_out["stale_ids"],
                        "missing_proposal_ids": apply_out["missing_proposal_ids"],
                        "invalid_override_ids": invalid_override_ids,
                        "checks": [
                            {
                                "name": "Selected proposal count",
                                "passed": True,
                                "detail": f"Selected {len(selected_ids)} proposal(s).",
                            },
                            {
                                "name": "Apply selected ref_link proposals",
                                "passed": True,
                                "detail": (
                                    f"Applied {len(apply_out['applied_ids'])}, "
                                    f"skipped {len(apply_out['skipped_ids'])}, "
                                    f"stale {len(apply_out['stale_ids']) + len(apply_out['missing_proposal_ids'])}, "
                                    f"invalid overrides {len(invalid_override_ids)}."
                                ),
                            },
                        ],
                        "warnings": [],
                        "errors": errors,
                        "modified_files": modified,
                        "file_change_summary": build_ref_link_review_file_change_summary(modified, apply_out["applied_ids"]),
                        "message": (
                            "Ref_link proposals applied."
                            if apply_out["applied_ids"]
                            else "No ref_link proposals were applied."
                        ),
                    }
                )
                return

            if self.path == "/api/validate_entry":
                data = self._read_json()
                reg = self.app.registry
                mode = normalize_whitespace(data.get("mode", "add")).lower()
                target = normalize_whitespace(data.get("target", ""))
                records = reg.get("records", [])

                if mode == "add" and is_empty_add_payload(data):
                    self._send_json({
                        "ok": True,
                        "errors": [],
                        "warnings": [],
                        "checks": [
                            {
                                "name": "Empty add form",
                                "passed": True,
                                "detail": "No changes made. Fill fields to validate a new entry.",
                            }
                        ],
                        "message": "No changes made.",
                    })
                    return

                candidate = make_candidate(data)
                target_id = ""
                target_check = {"name": "Edit target resolution", "passed": True, "detail": "Not applicable for add mode"}
                if mode == "edit":
                    hits = find_target(records, target)
                    if len(hits) != 1:
                        self._send_json({
                            "ok": False,
                            "errors": [f"Edit target must match exactly one record; got {len(hits)}"],
                            "warnings": [],
                            "matches": [record_summary(rec) for rec in hits],
                            "checks": [{"name": "Edit target resolution", "passed": False, "detail": f"Matches found: {len(hits)}"}],
                        })
                        return
                    target_id = hits[0].get("id", "")
                    target_check = {"name": "Edit target resolution", "passed": True, "detail": f"Resolved to {target_id}"}
                out = validate_candidate(records, candidate, mode, target_id)
                out.setdefault("checks", []).insert(0, target_check)
                artifact_out = validate_candidate_against_artifacts(reg, candidate, mode, target)
                canonical_errors = out.get("errors", [])
                artifact_errors = artifact_out.get("errors", [])
                if _is_artifact_only_duplicate_failure(canonical_errors, artifact_errors):
                    stale = _stale_artifact_payload(reg, self.app.registry_path, artifact_errors)
                    self._send_json(
                        {
                            "ok": False,
                            "error_code": stale["error_code"],
                            "message": stale["message"],
                            "errors": stale["errors"],
                            "artifact_duplicate_errors": stale["artifact_duplicate_errors"],
                            "stale_artifact_paths": stale["stale_artifact_paths"],
                            "rebuild_hint": stale["rebuild_hint"],
                            "warnings": sorted(set(out.get("warnings", []) + artifact_out.get("warnings", []))),
                            "checks": (
                                out.get("checks", [])
                                + artifact_out.get("checks", [])
                                + stale.get("checks", [])
                            ),
                        }
                    )
                    return
                out["errors"] = sorted(set(out.get("errors", []) + artifact_out.get("errors", [])))
                out["warnings"] = sorted(set(out.get("warnings", []) + artifact_out.get("warnings", [])))
                out.setdefault("checks", []).extend(artifact_out.get("checks", []))
                self._send_json({"ok": len(out["errors"]) == 0, **out})
                return

            if self.path == "/api/apply_and_build":
                data = self._read_json()
                reg = self.app.registry
                tracked_paths = self.app.artifact_paths(reg)
                before = file_mtimes(tracked_paths)
                mode = normalize_whitespace(data.get("mode", "add")).lower()
                target = normalize_whitespace(data.get("target", ""))
                if mode == "add" and is_empty_add_payload(data):
                    from build_sources_artifacts import main as build_main  # pylint: disable=import-outside-toplevel
                    import sys  # pylint: disable=import-outside-toplevel

                    argv_orig = sys.argv[:]
                    try:
                        sys.argv = ["build_sources_artifacts.py", "--registry", str(self.app.registry_path)]
                        build_main()
                    finally:
                        sys.argv = argv_orig

                    after = file_mtimes(tracked_paths)
                    changed_files = modified_paths(before, after)
                    online_compare = compare_local_bib_with_online(reg)
                    self._send_json({
                        "ok": True,
                        "status": "ok",
                        "operation": "build_only",
                        "record_id": "",
                        "changed_fields": [],
                        "warnings": [],
                        "errors": [],
                        "checks": [
                            {
                                "name": "Empty add form",
                                "passed": True,
                                "detail": "No record changes applied. Artifacts were rebuilt.",
                            }
                        ],
                        "modified_files": changed_files,
                        "online_compare": online_compare,
                        "file_change_summary": build_file_change_summary(
                            changed_files,
                            "build_only",
                            "",
                            [],
                            False,
                        ),
                        "message": "No changes made. Artifacts rebuilt.",
                    })
                    return

                candidate = make_candidate(data)
                artifact_out = validate_candidate_against_artifacts(reg, candidate, mode, target)
                if artifact_out.get("errors"):
                    records = reg.get("records", [])
                    target_id = ""
                    if mode == "edit":
                        hits = find_target(records, target)
                        if len(hits) == 1:
                            target_id = hits[0].get("id", "")
                    canonical_out = validate_candidate(records, candidate, mode, target_id)
                    if _is_artifact_only_duplicate_failure(canonical_out.get("errors", []), artifact_out["errors"]):
                        stale = _stale_artifact_payload(reg, self.app.registry_path, artifact_out["errors"])
                        self._send_json(
                            {
                                "error": stale["message"],
                                "error_code": stale["error_code"],
                                "errors": stale["errors"],
                                "artifact_duplicate_errors": stale["artifact_duplicate_errors"],
                                "stale_artifact_paths": stale["stale_artifact_paths"],
                                "rebuild_hint": stale["rebuild_hint"],
                                "checks": (
                                    canonical_out.get("checks", [])
                                    + artifact_out.get("checks", [])
                                    + stale.get("checks", [])
                                ),
                            },
                            status=409,
                        )
                        return
                    raise ValueError("\n".join(artifact_out["errors"]))
                out = apply_payload(reg, data, self.app.aliases_path, self.app.changelog_path)
                self.app.save(reg)

                from build_sources_artifacts import main as build_main  # pylint: disable=import-outside-toplevel
                import sys  # pylint: disable=import-outside-toplevel

                argv_orig = sys.argv[:]
                try:
                    sys.argv = ["build_sources_artifacts.py", "--registry", str(self.app.registry_path)]
                    build_main()
                finally:
                    sys.argv = argv_orig

                after = file_mtimes(tracked_paths)
                online_compare = compare_local_bib_with_online(reg)
                self._send_json({
                    "ok": True,
                    **out,
                    "checks": (out.get("checks", []) + artifact_out.get("checks", [])),
                    "modified_files": modified_paths(before, after),
                    "online_compare": online_compare,
                    "file_change_summary": build_file_change_summary(
                        modified_paths(before, after),
                        out.get("operation", mode),
                        out.get("record_id", ""),
                        out.get("changed_fields", []),
                        out.get("key_renamed", False),
                    ),
                    "message": "Record saved and artifacts regenerated",
                })
                return

            if self.path == "/api/delete_preview":
                data = self._read_json()
                target = normalize_whitespace(data.get("target", ""))
                if not target:
                    raise ValueError("target is required")

                reg = self.app.registry
                records = reg.get("records", [])
                hits = find_target(records, target)
                if len(hits) != 1:
                    raise ValueError(f"Delete target must match exactly one record; got {len(hits)}")

                rec = hits[0]
                self._send_json(
                    {
                        "ok": True,
                        "operation": "delete_preview",
                        "record_id": rec.get("id", ""),
                        "resolved_target": normalize_whitespace(rec.get("source", "")) or normalize_whitespace(rec.get("citekey", "")),
                        "checks": [{"name": "Delete target resolution", "passed": True, "detail": f"Resolved to {rec.get('id', '')}"}],
                        "would_modify_files": [str(path) for path in self.app.delete_preview_paths(reg)],
                        "message": "Delete will remove this record and regenerate Data Sources artifacts.",
                    }
                )
                return

            if self.path == "/api/delete_entry":
                data = self._read_json()
                target = normalize_whitespace(data.get("target", ""))
                editor = normalize_whitespace(data.get("editor_name", ""))
                reason = "Deleted via local UI"
                if not target:
                    raise ValueError("target is required")
                if not editor:
                    raise ValueError("editor_name is required")

                reg = self.app.registry
                records = reg.get("records", [])
                tracked_paths = self.app.delete_preview_paths(reg)
                before = file_mtimes(tracked_paths)
                hits = find_target(records, target)
                if len(hits) != 1:
                    raise ValueError(f"Delete target must match exactly one record; got {len(hits)}")
                rec = hits[0]
                rec_id = rec.get("id", "")
                deleted_fields = summarize_record_all_fields(rec)
                records.remove(rec)
                append_change(self.app.changelog_path, "delete", rec_id, reason, editor)
                self.app.save(reg)

                from build_sources_artifacts import main as build_main  # pylint: disable=import-outside-toplevel
                import sys  # pylint: disable=import-outside-toplevel

                argv_orig = sys.argv[:]
                try:
                    sys.argv = ["build_sources_artifacts.py", "--registry", str(self.app.registry_path)]
                    build_main()
                finally:
                    sys.argv = argv_orig

                after = file_mtimes(tracked_paths)
                online_compare = compare_local_bib_with_online(reg)
                self._send_json({
                    "ok": True,
                    "record_id": rec_id,
                    "operation": "delete",
                    "changed_fields": deleted_fields,
                    "checks": [{"name": "Delete target resolution", "passed": True, "detail": f"Deleted {rec_id}"}],
                    "modified_files": modified_paths(before, after),
                    "online_compare": online_compare,
                    "file_change_summary": build_file_change_summary(
                        modified_paths(before, after),
                        "delete",
                        rec_id,
                        deleted_fields,
                        False,
                    ),
                    "message": "Entry deleted and artifacts regenerated",
                })
                return

            if self.path == "/api/history/delete_entry":
                data = self._read_json()
                library = normalize_whitespace(data.get("library", ""))
                cleanup_reason = normalize_whitespace(data.get("cleanup_reason", ""))
                cleanup_scope = normalize_whitespace(data.get("cleanup_scope", "entry")) or "entry"
                if library not in {"data_sources", "wealth_research"}:
                    raise ValueError("library must be data_sources or wealth_research")
                if cleanup_scope not in {"entry", "record"}:
                    raise ValueError("cleanup_scope must be entry or record")
                if not cleanup_reason:
                    raise ValueError("cleanup_reason is required")

                reg = self.app.registry
                cfg = reg.get("config", {}) or {}
                changelog_path = self.app.changelog_path if library == "data_sources" else _wealth_change_log_path(cfg)
                if cleanup_scope == "record":
                    record_id = normalize_whitespace(data.get("record_id", ""))
                    removed_rows = delete_history_entries_for_record(changelog_path, record_id)
                    self._send_json(
                        {
                            "ok": True,
                            "library": library,
                            "cleanup_scope": cleanup_scope,
                            "record_id": record_id,
                            "removed_count": len(removed_rows),
                            "removed_history_records": len(removed_rows),
                            "source_records_changed": False,
                            "generated_files_changed": False,
                            "modified_files": [str(changelog_path)],
                            "removed": removed_rows,
                            "message": "History records removed. Source records and generated files were not changed.",
                        }
                    )
                    return

                try:
                    storage_index = int(data.get("storage_index", -1))
                except (TypeError, ValueError):
                    raise ValueError("storage_index must be an integer")
                removed = delete_history_entry(changelog_path, storage_index)
                self._send_json(
                    {
                        "ok": True,
                        "library": library,
                        "cleanup_scope": cleanup_scope,
                        "storage_index": storage_index,
                        "removed_count": 1,
                        "removed_history_records": 1,
                        "source_records_changed": False,
                        "generated_files_changed": False,
                        "modified_files": [str(changelog_path)],
                        "removed": removed,
                        "message": "History record removed. Source records and generated files were not changed.",
                    }
                )
                return

            if self.path == "/api/relaunch":
                host, port = self.server.server_address[:2]
                relaunch_local_ui(self.app, host, int(port))
                self._send_json({"ok": True, "message": "Relaunching app. This page will reconnect automatically."})
                self.app.stop_reason = "explicit relaunch"
                threading.Thread(target=self.server.shutdown, daemon=True).start()
                return

            if self.path == "/api/shutdown":
                self._send_json({"ok": True, "message": "Shutting down"})
                self.app.stop_reason = "explicit shutdown"
                threading.Thread(target=self.server.shutdown, daemon=True).start()
                return

            self._send_json({"error": "Not found"}, 404)
        except Exception as exc:  # pylint: disable=broad-except
            self._send_json({"error": str(exc)}, 400)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8765)
    parser.add_argument("--registry", default=DEFAULT_REGISTRY_PATH)
    parser.add_argument("--aliases", default=DEFAULT_ALIASES_PATH)
    parser.add_argument("--change-log", default=DEFAULT_CHANGE_LOG_PATH)
    parser.add_argument("--open-browser", action="store_true", help="Open the browser after the server binds.")
    args = parser.parse_args()

    app = App(Path(args.registry), Path(args.aliases), Path(args.change_log))
    Handler.app = app

    try:
        httpd, selected_port = create_server_with_port_fallback(args.host, args.port, Handler)
    except OSError as exc:
        print(f"ADAM SSM - Sleepless Source Manager could not start: {exc}", flush=True)
        print(f"No ports were available for {port_attempt_summary(args.port)}.", flush=True)
        print("Close another local server or run again with SOURCE_MANAGER_PORT or --port set to another port.", flush=True)
        return 1

    url = source_manager_url(args.host, selected_port)

    def idle_guard():
        while True:
            time.sleep(1)
            if time.time() - app.last_ping > app.idle_timeout_seconds:
                app.stop_reason = "idle timeout after 60 minutes"
                try:
                    httpd.shutdown()
                except Exception:
                    pass
                return

    threading.Thread(target=idle_guard, daemon=True).start()

    print("ADAM SSM - Sleepless Source Manager starting", flush=True)
    print(f"Python: {sys.executable}", flush=True)
    print(f"Python version: {sys.version.split()[0]}", flush=True)
    print(f"Host: {args.host}", flush=True)
    print(f"Requested port: {args.port}", flush=True)
    print(f"Selected port: {selected_port}", flush=True)
    print(f"URL: {url}", flush=True)
    if selected_port != args.port:
        print(f"Port {args.port} was unavailable, so the app is using port {selected_port}.", flush=True)
    print("Close this terminal or use the app's explicit shutdown action to stop the server.", flush=True)
    if args.open_browser:
        if open_browser(url):
            print("Browser open: requested", flush=True)
        else:
            print("Browser open failed. Paste this URL into your browser:", flush=True)
            print(url, flush=True)
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        app.stop_reason = "keyboard interrupt"
    except Exception as exc:
        app.stop_reason = f"server error: {exc}"
        raise
    finally:
        if hasattr(httpd, "server_close"):
            httpd.server_close()
        print(f"Final stop reason: {app.stop_reason}", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
