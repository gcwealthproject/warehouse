#!/usr/bin/env python3
"""Generate dictionary Sources sheet and canonical digital_library.bib."""

import argparse
import sys
from pathlib import Path

from common import (
    build_digital_library_entries,
    load_registry,
    record_to_sources_sheet_rows,
    records_to_source_alias_sheet_rows,
    records_sorted,
    render_parsed_bib_entry,
    write_sources_sheet,
)
from source_paths import (
    DEFAULT_DIGITAL_BIB_PATH,
    DEFAULT_DICTIONARY_PATH,
    DEFAULT_REGISTRY_PATH,
)


def write_digital_library_bib(path: Path, records: list) -> dict:
    entries, report = build_digital_library_entries(records)
    rendered = [
        render_parsed_bib_entry(key, entries[key])
        for key in sorted(entries.keys(), key=lambda item: item.lower())
    ]
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n\n".join(rendered).strip() + "\n", encoding="utf-8")
    report["entry_count"] = len(entries)
    return report


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--registry", default=DEFAULT_REGISTRY_PATH, help="Path to canonical registry")
    parser.add_argument("--dictionary-template", default=None, help="Template dictionary.xlsx path")
    parser.add_argument("--dictionary-output", default=None, help="Output dictionary.xlsx path")
    parser.add_argument("--digital-bib-output", default=None, help="Output canonical digital library .bib path")
    parser.add_argument("--bib-output", default=None, help="Deprecated alias for --digital-bib-output")
    parser.add_argument("--wealth-bib-input", default=None, help="Deprecated; ignored because sources.yaml is the only input")
    parser.add_argument("--both-bib-output", default=None, help="Deprecated; ignored because split outputs are legacy")
    args = parser.parse_args()

    registry_path = Path(args.registry)
    reg = load_registry(registry_path)
    cfg = reg.get("config", {})

    dictionary_template = Path(args.dictionary_template or cfg.get("dictionary_template", DEFAULT_DICTIONARY_PATH))
    dictionary_output = Path(args.dictionary_output or cfg.get("dictionary_output", DEFAULT_DICTIONARY_PATH))
    digital_bib_output = Path(
        args.digital_bib_output
        or args.bib_output
        or cfg.get("digital_bib_output", DEFAULT_DIGITAL_BIB_PATH)
    )
    records = records_sorted(reg.get("records", []))
    rows = []
    for record in records:
        rows.extend(record_to_sources_sheet_rows(record))
    source_alias_rows = records_to_source_alias_sheet_rows(records)
    write_sources_sheet(dictionary_template, dictionary_output, rows, source_alias_rows)
    digital_report = write_digital_library_bib(digital_bib_output, records)

    print(f"Generated dictionary Sources sheet: {dictionary_output}")
    print(f"Generated dictionary SourceAliases rows: {len(source_alias_rows)}")
    print(f"Generated digital library bib: {digital_bib_output}")
    print(f"Records: {len(records)}")
    print(f"Digital library entries: {digital_report.get('entry_count', 0)}")
    if digital_report.get("bibliographic_conflicts"):
        print(f"Bibliographic conflicts reported: {len(digital_report['bibliographic_conflicts'])}")
    if digital_report.get("multi_data_source_keyword_exports"):
        print(f"Multi-category data-source exports reported: {len(digital_report['multi_data_source_keyword_exports'])}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (FileNotFoundError, RuntimeError) as exc:
        print(str(exc), file=sys.stderr)
        raise SystemExit(1)
