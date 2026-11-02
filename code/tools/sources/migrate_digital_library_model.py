#!/usr/bin/env python3
"""Migrate source-manager metadata to the digital_library.bib export model."""

import argparse
from pathlib import Path

from common import (
    BIB_FIELD_ORDER,
    build_digital_library_entries,
    load_registry,
    migrate_keywords_for_data_source_section,
    normalize_whitespace,
    parse_bib_entries,
    records_sorted,
    save_registry,
    split_keywords,
    strip_data_source_keywords,
    write_parsed_bib_entries,
)
from source_paths import (
    DEFAULT_DIGITAL_BIB_PATH,
    DEFAULT_DIGITAL_LIBRARY_MIGRATION_REPORT_PATH,
    DEFAULT_REGISTRY_PATH,
    DEFAULT_WEALTH_BIB_PATH,
)


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


def migrate_registry(registry: dict) -> dict:
    changed = []
    backfilled = []
    multiple_before = []
    multiple_after = []
    uncertain = []

    for record in records_sorted(registry.get("records", [])):
        bib = record.get("bib")
        if not isinstance(bib, dict):
            bib = {}
            record["bib"] = bib
        before = normalize_whitespace(str(bib.get("keywords", "")))
        result = migrate_keywords_for_data_source_section(record.get("section", ""), before)
        if len(result["before_data_source_keywords"]) > 1:
            multiple_before.append(
                {
                    "id": record.get("id", ""),
                    "citekey": record.get("citekey", ""),
                    "section": record.get("section", ""),
                    "keywords": result["before_data_source_keywords"],
                }
            )
        if len(result["after_data_source_keywords"]) > 1:
            multiple_after.append(
                {
                    "id": record.get("id", ""),
                    "citekey": record.get("citekey", ""),
                    "section": record.get("section", ""),
                    "keywords": result["after_data_source_keywords"],
                }
            )
        if result["uncertain"]:
            uncertain.append(
                {
                    "id": record.get("id", ""),
                    "citekey": record.get("citekey", ""),
                    "section": record.get("section", ""),
                    "before_keywords": before,
                }
            )
        if result["changed"]:
            bib["keywords"] = result["after_keywords"]
            changed.append(
                {
                    "id": record.get("id", ""),
                    "citekey": record.get("citekey", ""),
                    "section": record.get("section", ""),
                    "before_keywords": before,
                    "after_keywords": result["after_keywords"],
                }
            )
            if result["backfilled"]:
                backfilled.append(changed[-1])

    cfg = registry.setdefault("config", {})
    if not normalize_whitespace(str(cfg.get("digital_bib_output", ""))):
        cfg["digital_bib_output"] = DEFAULT_DIGITAL_BIB_PATH
    for old_key in ["bib_output", "both_bib_output", "web_bib_output"]:
        cfg.pop(old_key, None)
    for key in ["online_bib_reference_url", "bibbase_profile_source_url"]:
        value = normalize_whitespace(str(cfg.get(key, "")))
        if "GCWealthProject_DataSourcesLibrary.bib" in value:
            cfg[key] = value.replace("GCWealthProject_DataSourcesLibrary.bib", "digital_library.bib")

    return {
        "changed": changed,
        "backfilled": backfilled,
        "multiple_before": multiple_before,
        "multiple_after": multiple_after,
        "uncertain": uncertain,
    }


def migrate_wealth_bib(wealth_entries: dict) -> dict:
    changed = []
    for key, entry in sorted(wealth_entries.items(), key=lambda item: item[0].lower()):
        fields = entry.get("fields", {}) or {}
        before = normalize_whitespace(str(fields.get("keywords", "")))
        after = strip_data_source_keywords(before)
        if before != after:
            fields["keywords"] = after
            changed.append(
                {
                    "citekey": key,
                    "before_keywords": before,
                    "after_keywords": after,
                    "removed_data_source_keywords": [
                        token for token in split_keywords(before) if token.startswith("Data Sources:")
                    ],
                }
            )
    return {"changed": changed}


def render_report(registry_report: dict, wealth_report: dict, digital_report: dict) -> str:
    lines = [
        "# Digital Library Migration Report",
        "",
        "## Summary",
        "",
        f"- Registry records changed: {len(registry_report['changed'])}",
        f"- Blank registry keywords backfilled: {len(registry_report['backfilled'])}",
        f"- Registry records with multiple data-source keywords before migration: {len(registry_report['multiple_before'])}",
        f"- Registry records with multiple data-source keywords after migration: {len(registry_report['multiple_after'])}",
        f"- Registry records not confidently classified: {len(registry_report['uncertain'])}",
        f"- Wealth Research entries with stale data-source keywords removed: {len(wealth_report['changed'])}",
        f"- Duplicate citekeys seen during digital-library merge: {len(digital_report.get('duplicate_citekeys', []))}",
        f"- Bibliographic metadata conflicts: {len(digital_report.get('bibliographic_conflicts', []))}",
        f"- Multi-category data-source exports after deduplication: {len(digital_report.get('multi_data_source_keyword_exports', []))}",
        "",
    ]

    lines.extend(
        markdown_list(
            "Registry Records Changed",
            registry_report["changed"],
            lambda row: (
                f"`{markdown_escape(row['id'])}` / `{markdown_escape(row['citekey'])}` "
                f"({markdown_escape(row['section'])}): "
                f"`{markdown_escape(row['before_keywords'])}` -> `{markdown_escape(row['after_keywords'])}`"
            ),
        )
    )
    lines.extend(
        markdown_list(
            "Blank Keywords Backfilled",
            registry_report["backfilled"],
            lambda row: f"`{markdown_escape(row['id'])}` / `{markdown_escape(row['citekey'])}` -> `{markdown_escape(row['after_keywords'])}`",
        )
    )
    lines.extend(
        markdown_list(
            "Multiple Data-Source Keywords Before Migration",
            registry_report["multiple_before"],
            lambda row: f"`{markdown_escape(row['id'])}` / `{markdown_escape(row['citekey'])}`: {', '.join(row['keywords'])}",
        )
    )
    lines.extend(
        markdown_list(
            "Multiple Data-Source Keywords After Migration",
            registry_report["multiple_after"],
            lambda row: f"`{markdown_escape(row['id'])}` / `{markdown_escape(row['citekey'])}`: {', '.join(row['keywords'])}",
        )
    )
    lines.extend(
        markdown_list(
            "Could Not Confidently Classify",
            registry_report["uncertain"],
            lambda row: f"`{markdown_escape(row['id'])}` / `{markdown_escape(row['citekey'])}` section=`{markdown_escape(row['section'])}`",
        )
    )
    lines.extend(
        markdown_list(
            "Wealth Research Stale Data-Source Keywords Removed",
            wealth_report["changed"],
            lambda row: (
                f"`{markdown_escape(row['citekey'])}` removed "
                f"{', '.join(row['removed_data_source_keywords'])}; kept `{markdown_escape(row['after_keywords'])}`"
            ),
        )
    )
    lines.extend(
        markdown_list(
            "Duplicate Citekeys",
            digital_report.get("duplicate_citekeys", []),
            lambda row: f"`{markdown_escape(row['citekey'])}`: {', '.join(markdown_escape(value) for value in row.get('sources', []))}",
        )
    )
    lines.extend(
        markdown_list(
            "Bibliographic Metadata Conflicts",
            digital_report.get("bibliographic_conflicts", []),
            lambda row: (
                f"`{markdown_escape(row.get('citekey', ''))}` field `{markdown_escape(row.get('field', ''))}`; "
                f"kept `{markdown_escape(row.get('kept', ''))}`; other `{markdown_escape(row.get('other', ''))}`; "
                f"incoming `{markdown_escape(row.get('incoming_source', ''))}`"
            ),
        )
    )
    lines.extend(
        markdown_list(
            "Multi-Category Data-Source Exports",
            digital_report.get("multi_data_source_keyword_exports", []),
            lambda row: f"`{markdown_escape(row.get('citekey', ''))}` -> {', '.join(row.get('keywords', []))}",
        )
    )

    return "\n".join(lines).rstrip() + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--registry", default=DEFAULT_REGISTRY_PATH)
    parser.add_argument("--wealth-bib-input", default=DEFAULT_WEALTH_BIB_PATH)
    parser.add_argument("--report", default=DEFAULT_DIGITAL_LIBRARY_MIGRATION_REPORT_PATH)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    registry_path = Path(args.registry)
    wealth_path = Path(args.wealth_bib_input)
    report_path = Path(args.report)

    registry = load_registry(registry_path)
    wealth_entries = parse_bib_entries(wealth_path.read_text(encoding="utf-8"))

    registry_report = migrate_registry(registry)
    wealth_report = migrate_wealth_bib(wealth_entries)
    _, digital_report = build_digital_library_entries(records_sorted(registry.get("records", [])))
    report_text = render_report(registry_report, wealth_report, digital_report)

    if not args.dry_run:
        save_registry(registry_path, registry)
        write_parsed_bib_entries(wealth_path, wealth_entries, field_order=BIB_FIELD_ORDER)
        report_path.parent.mkdir(parents=True, exist_ok=True)
        report_path.write_text(report_text, encoding="utf-8")

    print(report_text)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
