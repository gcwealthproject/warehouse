#!/usr/bin/env python3
"""Migrate the source manager to one editable registry and one public BibTeX export."""

import argparse
import re
import shutil
from collections import defaultdict
from copy import deepcopy
from pathlib import Path
from typing import Dict, Iterable, List

from common import (
    BIB_FIELD_ORDER,
    BIB_EXPORT_BLOCKED_FIELDS,
    DIGITAL_LIBRARY_CONFLICT_FIELDS,
    RESEARCH_CATEGORY_KEYWORDS,
    build_digital_library_entries,
    canonical_data_source_keyword_for_section,
    data_source_keywords_from_value,
    format_keywords,
    load_registry,
    migrate_keywords_for_data_source_section,
    normalize_text,
    normalize_whitespace,
    now_utc,
    parse_bib_entries,
    record_is_data_source,
    records_sorted,
    research_category_keywords_from_value,
    save_registry,
    section_value_from_data_source_keywords,
    split_keywords,
    strip_data_source_keywords,
)
from source_paths import (
    DEFAULT_DIGITAL_BIB_PATH,
    DEFAULT_OLD_WEALTH_BIB_PATH,
    DEFAULT_REGISTRY_PATH,
    DEFAULT_UNIFIED_SOURCE_MANAGER_MIGRATION_REPORT_PATH,
    DEFAULT_WEALTH_BIB_PATH,
)


STANDARD_BIB_FIELDS = set(BIB_FIELD_ORDER) | {"entry_type"}


def markdown_escape(value: str) -> str:
    return normalize_whitespace(str(value)).replace("|", "\\|")


def markdown_list(title: str, rows: list, formatter) -> list:
    lines = [f"## {title}", ""]
    if not rows:
        lines.extend(["- None", ""])
        return lines
    for row in rows:
        lines.append(f"- {formatter(row)}")
    lines.append("")
    return lines


def _slug(value: str) -> str:
    slug = re.sub(r"[^A-Za-z0-9]+", "-", normalize_whitespace(value)).strip("-").lower()
    return slug or "reference"


def _unique_record_id(existing_ids: set, citekey: str) -> str:
    base = f"ref-{_slug(citekey)}"
    candidate = base
    idx = 2
    while candidate in existing_ids:
        candidate = f"{base}-{idx}"
        idx += 1
    existing_ids.add(candidate)
    return candidate


def _first_author_label(author: str) -> str:
    author = normalize_whitespace(author)
    if not author:
        return "Unknown"
    first = re.split(r"\s+and\s+", author, maxsplit=1, flags=re.IGNORECASE)[0].strip()
    first = first.strip("{}")
    if "," in first:
        return normalize_whitespace(first.split(",", 1)[0]) or "Unknown"
    parts = [part for part in first.split() if part]
    return parts[-1] if parts else "Unknown"


def _legend_from_bib(citekey: str, bib: dict) -> str:
    author = _first_author_label(str(bib.get("author", "")))
    year = normalize_whitespace(str(bib.get("year", ""))) or "n.d."
    if author == "Unknown" and normalize_whitespace(str(bib.get("title", ""))):
        title_words = normalize_whitespace(str(bib.get("title", ""))).split()
        author = " ".join(title_words[:4]) if title_words else "Unknown"
    return f"{author} ({year})" if author != "Unknown" else f"{citekey} ({year})"


def _normalized_field_value(field: str, value: str) -> str:
    if field in {"year", "doi"}:
        return normalize_whitespace(str(value)).lower()
    return normalize_text(str(value))


def _is_url_like_field(field_name: str) -> bool:
    name = normalize_whitespace(str(field_name)).lower()
    return (
        name == "url"
        or name.startswith("url_")
        or "file" in name
        or "appendix" in name
        or "replication" in name
        or "codebook" in name
        or "data" in name
    )


def _append_extra_field(extras: dict, field_name: str, value: str) -> str:
    name = normalize_whitespace(str(field_name)).lower()
    value = normalize_whitespace(str(value))
    if not name or not value:
        return ""
    existing_values = {normalize_whitespace(str(v)) for v in extras.values()}
    if value in existing_values:
        return ""
    idx = 2
    candidate = f"{name}_{idx}"
    while candidate in extras:
        idx += 1
        candidate = f"{name}_{idx}"
    extras[candidate] = value
    return candidate


def _entry_to_bib(citekey: str, entry: dict, report: dict) -> dict:
    fields = entry.get("fields", {}) or {}
    bib = {field: normalize_whitespace(str(fields.get(field, ""))) for field in BIB_FIELD_ORDER}
    bib["entry_type"] = normalize_whitespace(str(entry.get("entry_type", ""))).lower() or "misc"
    bib["keywords"] = format_keywords(research_category_keywords_from_value(strip_data_source_keywords(bib.get("keywords", ""))))
    if not normalize_whitespace(bib.get("keywords", "")):
        bib["keywords"] = "Manual Review"
        report["unresolved_records"].append(
            {"citekey": citekey, "reason": "Imported Wealth Research entry had blank keywords; marked for manual review."}
        )
    if not normalize_whitespace(bib.get("title", "")):
        bib["title"] = citekey
        report["bibliographic_backfills"].append({"citekey": citekey, "field": "title", "value": citekey})
    if not normalize_whitespace(bib.get("author", "")):
        bib["author"] = "Unknown"
        report["bibliographic_backfills"].append({"citekey": citekey, "field": "author", "value": "Unknown"})
    if not normalize_whitespace(bib.get("year", "")):
        bib["year"] = "1900"
        report["bibliographic_backfills"].append({"citekey": citekey, "field": "year", "value": "1900"})

    extras = {}
    for field_name, value in sorted(fields.items(), key=lambda item: str(item[0]).lower()):
        name = normalize_whitespace(str(field_name)).lower()
        val = normalize_whitespace(str(value))
        if not name or not val or name in STANDARD_BIB_FIELDS or name in BIB_EXPORT_BLOCKED_FIELDS:
            continue
        extras[name] = val
    bib["extra_fields"] = extras
    return bib


def _entry_link(bib: dict) -> str:
    url = normalize_whitespace(str(bib.get("url", "")))
    if url:
        return url
    doi = normalize_whitespace(str(bib.get("doi", "")))
    return f"https://doi.org/{doi}" if doi else ""


def _new_research_record(citekey: str, entry: dict, existing_ids: set, report: dict, bib: dict = None) -> dict:
    if bib is None:
        bib = _entry_to_bib(citekey, entry, report)
    timestamp = now_utc()
    return {
        "id": _unique_record_id(existing_ids, citekey),
        "is_data_source": False,
        "section": "",
        "aggsource": "",
        "legend": _legend_from_bib(citekey, bib),
        "source": "",
        "data_type": "",
        "link": _entry_link(bib),
        "ref_link": "",
        "citekey": citekey,
        "inclusion_in_warehouse": "",
        "multigeo_reference": "",
        "metadata": "",
        "metadatalink": "",
        "qcommentsforta": "",
        "tareply": "",
        "tacomments": "",
        "arjcomments": "",
        "arjreplies": "",
        "seeaggsourcelisthere": "",
        "manual_review_required": not bool(research_category_keywords_from_value(bib.get("keywords", ""))),
        "bib": bib,
        "created_at": timestamp,
        "updated_at": timestamp,
        "created_by": "unified-migration",
        "updated_by": "unified-migration",
    }


def _merge_keywords(existing: str, incoming: str, *, keep_data_source_keywords: bool) -> str:
    incoming_value = incoming if keep_data_source_keywords else strip_data_source_keywords(incoming)
    return format_keywords(split_keywords(existing) + split_keywords(incoming_value))


def _merge_bib_into_record(record: dict, citekey: str, incoming_bib: dict, report: dict, incoming_source: str) -> None:
    bib = record.setdefault("bib", {})
    record_data_source = record_is_data_source(record)
    bib["keywords"] = _merge_keywords(
        normalize_whitespace(str(bib.get("keywords", ""))),
        normalize_whitespace(str(incoming_bib.get("keywords", ""))),
        keep_data_source_keywords=record_data_source,
    )

    for field in BIB_FIELD_ORDER:
        if field == "keywords":
            continue
        incoming_value = normalize_whitespace(str(incoming_bib.get(field, "")))
        if not incoming_value:
            continue
        existing_value = normalize_whitespace(str(bib.get(field, "")))
        if not existing_value:
            bib[field] = incoming_value
            continue
        if field == "author" and existing_value.lower() == "unknown" and incoming_value.lower() != "unknown":
            bib[field] = incoming_value
            continue
        if field == "year" and existing_value == "1900" and incoming_value != "1900":
            bib[field] = incoming_value
            continue
        if _normalized_field_value(field, existing_value) == _normalized_field_value(field, incoming_value):
            continue
        if field in DIGITAL_LIBRARY_CONFLICT_FIELDS:
            report["bibliographic_conflicts"].append(
                {
                    "citekey": citekey,
                    "field": field,
                    "kept": existing_value,
                    "other": incoming_value,
                    "incoming_source": incoming_source,
                    "record_id": record.get("id", ""),
                }
            )
            continue
        if _is_url_like_field(field):
            extras = bib.setdefault("extra_fields", {})
            preserved = _append_extra_field(extras, field, incoming_value)
            if preserved:
                report["preserved_url_like_fields"].append(
                    {"citekey": citekey, "field": field, "preserved_as": preserved, "source": incoming_source}
                )

    extras = bib.setdefault("extra_fields", {})
    incoming_extras = incoming_bib.get("extra_fields", {}) or {}
    for field_name, incoming_value in sorted(incoming_extras.items(), key=lambda item: str(item[0]).lower()):
        name = normalize_whitespace(str(field_name)).lower()
        value = normalize_whitespace(str(incoming_value))
        if not name or not value or name in BIB_EXPORT_BLOCKED_FIELDS:
            continue
        existing_value = normalize_whitespace(str(extras.get(name, "")))
        if not existing_value:
            extras[name] = value
            continue
        if existing_value == value:
            continue
        if _is_url_like_field(name):
            preserved = _append_extra_field(extras, name, value)
            if preserved:
                report["preserved_url_like_fields"].append(
                    {"citekey": citekey, "field": name, "preserved_as": preserved, "source": incoming_source}
                )
        else:
            report["bibliographic_conflicts"].append(
                {
                    "citekey": citekey,
                    "field": name,
                    "kept": existing_value,
                    "other": value,
                    "incoming_source": incoming_source,
                    "record_id": record.get("id", ""),
                }
            )

    if not normalize_whitespace(str(record.get("link", ""))):
        record["link"] = _entry_link(incoming_bib)
    if not normalize_whitespace(str(record.get("legend", ""))):
        record["legend"] = _legend_from_bib(citekey, incoming_bib)
    record["updated_at"] = now_utc()
    record["updated_by"] = "unified-migration"


def _merge_record_values(base: dict, incoming: dict) -> None:
    for field in [
        "aggsource",
        "legend",
        "data_type",
        "link",
        "ref_link",
        "inclusion_in_warehouse",
        "multigeo_reference",
        "metadata",
        "metadatalink",
        "qcommentsforta",
        "tareply",
        "tacomments",
        "arjcomments",
        "arjreplies",
        "seeaggsourcelisthere",
        "shared_citekey_group",
        "shared_citekey_note",
    ]:
        if not normalize_whitespace(str(base.get(field, ""))) and normalize_whitespace(str(incoming.get(field, ""))):
            base[field] = incoming.get(field, "")


def _record_major_conflicts(records: List[dict]) -> List[dict]:
    conflicts = []
    base = records[0].get("bib", {}) or {}
    for other in records[1:]:
        other_bib = other.get("bib", {}) or {}
        for field in DIGITAL_LIBRARY_CONFLICT_FIELDS:
            base_value = normalize_whitespace(str(base.get(field, "")))
            other_value = normalize_whitespace(str(other_bib.get(field, "")))
            if not base_value or not other_value:
                continue
            if _normalized_field_value(field, base_value) != _normalized_field_value(field, other_value):
                conflicts.append(
                    {
                        "citekey": records[0].get("citekey", ""),
                        "field": field,
                        "kept": base_value,
                        "other": other_value,
                        "incoming_source": other.get("id", ""),
                        "record_id": records[0].get("id", ""),
                    }
                )
    return conflicts


def _base_source_for_ineq_topo_pair(records: List[dict]) -> str:
    if len(records) != 2:
        return ""
    suffixes = {}
    for record in records:
        source = normalize_whitespace(str(record.get("source", "")))
        match = re.match(r"^(.+)_(ineq|topo)$", source, flags=re.IGNORECASE)
        if not match:
            return ""
        base = match.group(1)
        suffix = match.group(2).lower()
        suffixes[suffix] = base
    if set(suffixes) == {"ineq", "topo"} and suffixes["ineq"].lower() == suffixes["topo"].lower():
        return suffixes["ineq"]
    return ""


def migrate_existing_registry_records(registry: dict, report: dict) -> None:
    for record in registry.get("records", []):
        bib = record.setdefault("bib", {})
        before_keywords = normalize_whitespace(str(bib.get("keywords", "")))
        before_section = normalize_whitespace(str(record.get("section", "")))
        was_data_source = record_is_data_source(record) or bool(canonical_data_source_keyword_for_section(before_section))
        record["is_data_source"] = was_data_source
        if was_data_source:
            before_data_source_keywords = data_source_keywords_from_value(before_keywords)
            section_keyword = canonical_data_source_keyword_for_section(before_section)
            if len(before_data_source_keywords) > 1:
                selected_keywords = list(before_data_source_keywords)
                if section_keyword and section_keyword not in selected_keywords:
                    selected_keywords.insert(0, section_keyword)
                bib["keywords"] = format_keywords(selected_keywords + split_keywords(strip_data_source_keywords(before_keywords)))
                record["section"] = section_value_from_data_source_keywords(bib["keywords"])
                if bib["keywords"] != before_keywords:
                    report["category_backfills"].append(
                        {
                            "id": record.get("id", ""),
                            "citekey": record.get("citekey", ""),
                            "before_keywords": before_keywords,
                            "after_keywords": bib.get("keywords", ""),
                        }
                    )
            else:
                result = migrate_keywords_for_data_source_section(before_section, before_keywords)
                if result["canonical_keyword"]:
                    bib["keywords"] = result["after_keywords"]
                    record["section"] = section_value_from_data_source_keywords(bib["keywords"])
                elif data_source_keywords_from_value(before_keywords):
                    bib["keywords"] = format_keywords(data_source_keywords_from_value(before_keywords) + split_keywords(strip_data_source_keywords(before_keywords)))
                    record["section"] = section_value_from_data_source_keywords(bib["keywords"])
                if result.get("changed"):
                    report["category_backfills"].append(
                        {
                            "id": record.get("id", ""),
                            "citekey": record.get("citekey", ""),
                            "before_keywords": before_keywords,
                            "after_keywords": bib.get("keywords", ""),
                        }
                    )
        else:
            after_keywords = strip_data_source_keywords(before_keywords)
            if after_keywords != before_keywords:
                bib["keywords"] = after_keywords
                report["category_backfills"].append(
                    {
                        "id": record.get("id", ""),
                        "citekey": record.get("citekey", ""),
                        "before_keywords": before_keywords,
                        "after_keywords": after_keywords,
                    }
                )
                bib["keywords"] = after_keywords
            record["section"] = ""
            if not research_category_keywords_from_value(bib.get("keywords", "")):
                record["manual_review_required"] = True


def collapse_duplicate_registry_records(registry: dict, report: dict) -> None:
    records = registry.get("records", [])
    by_citekey: Dict[str, List[dict]] = defaultdict(list)
    for record in records:
        citekey = normalize_whitespace(str(record.get("citekey", "")))
        if citekey:
            by_citekey[citekey].append(record)

    remove_ids = set()
    for citekey, grouped in sorted(by_citekey.items(), key=lambda item: item[0].lower()):
        if len(grouped) <= 1:
            continue
        base_source = _base_source_for_ineq_topo_pair(grouped)
        if not base_source:
            group = f"shared-{re.sub(r'[^A-Za-z0-9]+', '-', citekey).strip('-').lower()}"
            note = "Intentional shared BibTeX citekey; operational source rows remain distinct."
            for record in grouped:
                record["shared_citekey_group"] = normalize_whitespace(str(record.get("shared_citekey_group", ""))) or group
                record["shared_citekey_note"] = normalize_whitespace(str(record.get("shared_citekey_note", ""))) or note
            report["unresolved_records"].append(
                {
                    "citekey": citekey,
                    "reason": "Duplicate registry records do not form an exact _ineq/_topo source-code pair; kept as distinct operational rows.",
                    "record_ids": [record.get("id", "") for record in grouped],
                }
            )
            continue
        conflicts = _record_major_conflicts(grouped)
        if conflicts:
            report["bibliographic_conflicts"].extend(conflicts)
            report["unresolved_records"].append(
                {
                    "citekey": citekey,
                    "reason": "Duplicate registry records have conflicting bibliographic metadata; not collapsed.",
                    "record_ids": [record.get("id", "") for record in grouped],
                }
            )
            continue

        base = deepcopy(grouped[0])
        base["is_data_source"] = any(record_is_data_source(record) for record in grouped)
        for other in grouped[1:]:
            _merge_record_values(base, other)
            _merge_bib_into_record(
                base,
                citekey,
                other.get("bib", {}) or {},
                report,
                f"registry:{other.get('id', '')}",
            )
            remove_ids.add(other.get("id", ""))
        if base.get("is_data_source"):
            base["section"] = section_value_from_data_source_keywords((base.get("bib", {}) or {}).get("keywords", ""))
        base["source_aliases"] = [
            normalize_whitespace(str(record.get("source", "")))
            for record in grouped
            if normalize_whitespace(str(record.get("source", "")))
            and normalize_whitespace(str(record.get("source", ""))) != base_source
        ]
        base["source"] = base_source
        idx = records.index(grouped[0])
        records[idx] = base
        report["collapsed_duplicate_registry_records"].append(
            {
                "citekey": citekey,
                "kept_id": base.get("id", ""),
                "merged_ids": [record.get("id", "") for record in grouped[1:]],
                "keywords": (base.get("bib", {}) or {}).get("keywords", ""),
            }
        )

    if remove_ids:
        registry["records"] = [record for record in records if record.get("id", "") not in remove_ids]


def import_wealth_research_entries(registry: dict, wealth_entries: dict, report: dict) -> None:
    records = registry.setdefault("records", [])
    existing_ids = {normalize_whitespace(str(record.get("id", ""))) for record in records}
    by_citekey: Dict[str, dict] = {}
    for record in records:
        citekey = normalize_whitespace(str(record.get("citekey", "")))
        if citekey and citekey not in by_citekey:
            by_citekey[citekey] = record

    for citekey, entry in sorted(wealth_entries.items(), key=lambda item: item[0].lower()):
        clean_citekey = normalize_whitespace(citekey)
        incoming_bib = _entry_to_bib(clean_citekey, entry, report)
        existing = by_citekey.get(clean_citekey)
        if existing:
            before_keywords = normalize_whitespace(str((existing.get("bib", {}) or {}).get("keywords", "")))
            _merge_bib_into_record(existing, clean_citekey, incoming_bib, report, "wealth_research")
            existing["is_data_source"] = record_is_data_source(existing)
            if existing["is_data_source"]:
                existing["section"] = section_value_from_data_source_keywords((existing.get("bib", {}) or {}).get("keywords", ""))
            report["merged_entries"].append(
                {
                    "citekey": clean_citekey,
                    "record_id": existing.get("id", ""),
                    "before_keywords": before_keywords,
                    "after_keywords": (existing.get("bib", {}) or {}).get("keywords", ""),
                }
            )
            continue
        record = _new_research_record(clean_citekey, entry, existing_ids, report, incoming_bib)
        records.append(record)
        by_citekey[clean_citekey] = record
        report["imported_entries"].append(
            {
                "citekey": clean_citekey,
                "record_id": record.get("id", ""),
                "keywords": (record.get("bib", {}) or {}).get("keywords", ""),
            }
        )


def duplicate_citekeys(records: Iterable[dict]) -> list:
    grouped: Dict[str, List[str]] = defaultdict(list)
    for record in records:
        citekey = normalize_whitespace(str(record.get("citekey", "")))
        if citekey:
            grouped[citekey].append(normalize_whitespace(str(record.get("id", ""))))
    return [
        {"citekey": citekey, "record_ids": ids}
        for citekey, ids in sorted(grouped.items(), key=lambda item: item[0].lower())
        if len(ids) > 1
    ]


def clean_config(registry: dict) -> None:
    cfg = registry.setdefault("config", {})
    cfg["digital_bib_output"] = normalize_whitespace(str(cfg.get("digital_bib_output", ""))) or DEFAULT_DIGITAL_BIB_PATH
    for key in [
        "bib_output",
        "both_bib_output",
        "web_bib_output",
        "wealth_bib_input",
        "wealth_change_log",
        "wealth_online_bib_reference_url",
        "wealth_online_bib_timeout_seconds",
    ]:
        cfg.pop(key, None)
    for key in ["online_bib_reference_url", "bibbase_profile_source_url"]:
        value = normalize_whitespace(str(cfg.get(key, "")))
        if "GCWealthProject_DataSourcesLibrary.bib" in value:
            cfg[key] = value.replace("GCWealthProject_DataSourcesLibrary.bib", "digital_library.bib")
        if "GCWealthProject_WealthResearchLibrary.bib" in value:
            cfg[key] = value.replace("GCWealthProject_WealthResearchLibrary.bib", "digital_library.bib")


def migrate_registry_to_unified_model(registry: dict, wealth_entries: dict) -> dict:
    report = {
        "imported_entries": [],
        "merged_entries": [],
        "collapsed_duplicate_registry_records": [],
        "category_backfills": [],
        "bibliographic_conflicts": [],
        "preserved_url_like_fields": [],
        "unresolved_records": [],
        "bibliographic_backfills": [],
        "duplicate_citekeys_after": [],
        "digital_library_report": {},
        "archived_files": [],
    }
    migrate_existing_registry_records(registry, report)
    collapse_duplicate_registry_records(registry, report)
    import_wealth_research_entries(registry, wealth_entries, report)
    collapse_duplicate_registry_records(registry, report)
    clean_config(registry)
    registry["records"] = records_sorted(registry.get("records", []))
    report["duplicate_citekeys_after"] = duplicate_citekeys(registry.get("records", []))
    _, digital_report = build_digital_library_entries(registry.get("records", []))
    report["digital_library_report"] = digital_report
    return report


def render_report(report: dict) -> str:
    digital_report = report.get("digital_library_report", {}) or {}
    lines = [
        "# Unified Source Manager Migration Report",
        "",
        "## Summary",
        "",
        f"- Wealth Research entries imported into sources.yaml: {len(report['imported_entries'])}",
        f"- Wealth Research entries merged into existing registry records: {len(report['merged_entries'])}",
        f"- Duplicate registry record groups collapsed: {len(report['collapsed_duplicate_registry_records'])}",
        f"- Category keyword backfills/cleanups: {len(report['category_backfills'])}",
        f"- Bibliographic metadata conflicts: {len(report['bibliographic_conflicts']) + len(digital_report.get('bibliographic_conflicts', []))}",
        f"- Preserved URL-like fields: {len(report['preserved_url_like_fields']) + len(digital_report.get('preserved_url_like_fields', []))}",
        f"- Records requiring manual review: {len(report['unresolved_records'])}",
        f"- Duplicate citekeys remaining in sources.yaml: {len(report['duplicate_citekeys_after'])}",
        f"- Archived files: {len(report['archived_files'])}",
        "",
    ]

    lines.extend(
        markdown_list(
            "Imported Wealth Research Entries",
            report["imported_entries"],
            lambda row: f"`{markdown_escape(row['citekey'])}` -> `{markdown_escape(row['record_id'])}` keywords=`{markdown_escape(row['keywords'])}`",
        )
    )
    lines.extend(
        markdown_list(
            "Merged Wealth Research Entries",
            report["merged_entries"],
            lambda row: (
                f"`{markdown_escape(row['citekey'])}` -> `{markdown_escape(row['record_id'])}` "
                f"`{markdown_escape(row['before_keywords'])}` -> `{markdown_escape(row['after_keywords'])}`"
            ),
        )
    )
    lines.extend(
        markdown_list(
            "Collapsed Duplicate Registry Records",
            report["collapsed_duplicate_registry_records"],
            lambda row: (
                f"`{markdown_escape(row['citekey'])}` kept `{markdown_escape(row['kept_id'])}`, "
                f"merged {', '.join(markdown_escape(value) for value in row.get('merged_ids', []))}; "
                f"keywords=`{markdown_escape(row.get('keywords', ''))}`"
            ),
        )
    )
    lines.extend(
        markdown_list(
            "Category Backfills And Cleanups",
            report["category_backfills"],
            lambda row: (
                f"`{markdown_escape(row.get('id', ''))}` / `{markdown_escape(row.get('citekey', ''))}` "
                f"`{markdown_escape(row.get('before_keywords', ''))}` -> `{markdown_escape(row.get('after_keywords', ''))}`"
            ),
        )
    )
    lines.extend(
        markdown_list(
            "Bibliographic Metadata Conflicts",
            report["bibliographic_conflicts"] + digital_report.get("bibliographic_conflicts", []),
            lambda row: (
                f"`{markdown_escape(row.get('citekey', ''))}` field `{markdown_escape(row.get('field', ''))}`; "
                f"kept `{markdown_escape(row.get('kept', ''))}`; other `{markdown_escape(row.get('other', ''))}`; "
                f"incoming `{markdown_escape(row.get('incoming_source', ''))}`"
            ),
        )
    )
    lines.extend(
        markdown_list(
            "Bibliographic Backfills",
            report["bibliographic_backfills"],
            lambda row: f"`{markdown_escape(row.get('citekey', ''))}` `{markdown_escape(row.get('field', ''))}` -> `{markdown_escape(row.get('value', ''))}`",
        )
    )
    lines.extend(
        markdown_list(
            "Unresolved Records",
            report["unresolved_records"],
            lambda row: (
                f"`{markdown_escape(row.get('citekey', ''))}` {markdown_escape(row.get('reason', ''))} "
                f"{', '.join(markdown_escape(value) for value in row.get('record_ids', []))}"
            ),
        )
    )
    lines.extend(
        markdown_list(
            "Duplicate Citekeys Remaining",
            report["duplicate_citekeys_after"],
            lambda row: f"`{markdown_escape(row.get('citekey', ''))}`: {', '.join(markdown_escape(value) for value in row.get('record_ids', []))}",
        )
    )
    lines.extend(
        markdown_list(
            "Archived Files",
            report["archived_files"],
            lambda row: f"`{markdown_escape(row.get('source', ''))}` -> `{markdown_escape(row.get('archive', ''))}` ({markdown_escape(row.get('status', ''))})",
        )
    )
    return "\n".join(lines).rstrip() + "\n"


def archive_file(source: Path, archive: Path, report: dict) -> None:
    if not source.exists():
        status = "already archived" if archive.exists() else "source missing"
        report["archived_files"].append({"source": str(source), "archive": str(archive), "status": status})
        return
    archive.parent.mkdir(parents=True, exist_ok=True)
    if archive.exists():
        if source.read_text(encoding="utf-8", errors="ignore") == archive.read_text(encoding="utf-8", errors="ignore"):
            source.unlink()
            status = "removed duplicate active copy"
        else:
            status = "archive already existed; active copy left in place"
        report["archived_files"].append({"source": str(source), "archive": str(archive), "status": status})
        return
    shutil.move(str(source), str(archive))
    report["archived_files"].append({"source": str(source), "archive": str(archive), "status": "archived"})


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--registry", default=DEFAULT_REGISTRY_PATH)
    parser.add_argument("--wealth-bib-input", default=DEFAULT_WEALTH_BIB_PATH)
    parser.add_argument("--wealth-bib-archive", default=DEFAULT_OLD_WEALTH_BIB_PATH)
    parser.add_argument("--report", default=DEFAULT_UNIFIED_SOURCE_MANAGER_MIGRATION_REPORT_PATH)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--no-archive", action="store_true")
    args = parser.parse_args()

    registry_path = Path(args.registry)
    wealth_path = Path(args.wealth_bib_input)
    archive_path = Path(args.wealth_bib_archive)
    report_path = Path(args.report)

    registry = load_registry(registry_path)
    wealth_entries = parse_bib_entries(wealth_path.read_text(encoding="utf-8")) if wealth_path.exists() else {}
    report = migrate_registry_to_unified_model(registry, wealth_entries)

    if not args.dry_run:
        save_registry(registry_path, registry)
        if not args.no_archive:
            archive_file(wealth_path, archive_path, report)
        report_path.parent.mkdir(parents=True, exist_ok=True)
        report_path.write_text(render_report(report), encoding="utf-8")

    print(render_report(report))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
