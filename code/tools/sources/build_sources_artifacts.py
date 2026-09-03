#!/usr/bin/env python3
"""Generate dictionary Sources sheet and canonical .bib from code/tools metadata."""

import argparse
import sys
from collections import OrderedDict
from pathlib import Path

from common import (
    format_bib_value,
    load_registry,
    normalize_whitespace,
    parse_bib_entries,
    record_to_sources_sheet_row,
    records_sorted,
    render_bib_entry,
    write_sources_sheet,
)
from source_paths import (
    DEFAULT_BOTH_BIB_PATH,
    DEFAULT_DATA_BIB_PATH,
    DEFAULT_DICTIONARY_PATH,
    DEFAULT_REGISTRY_PATH,
    DEFAULT_WEALTH_BIB_PATH,
)

BIB_FIELD_ORDER = [
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
    "abstract",
    "keywords",
    "note",
]


def write_bib(path: Path, records: list) -> None:
    entries = []
    emitted_shared_keys = {}
    for rec in records:
        key = normalize_whitespace(rec.get("citekey", "")) or normalize_whitespace(rec.get("source", ""))
        if not key:
            continue
        shared_group = normalize_whitespace(rec.get("shared_citekey_group", ""))
        if shared_group and emitted_shared_keys.get(key) == shared_group:
            continue
        entries.append(render_bib_entry(key, rec))
        if shared_group:
            emitted_shared_keys[key] = shared_group
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n\n".join(entries).strip() + "\n", encoding="utf-8")


def render_parsed_bib_entry(key: str, entry: dict) -> str:
    entry_type = normalize_whitespace(str(entry.get("entry_type", "misc"))).lower() or "misc"
    source_fields = entry.get("fields", {}) or {}

    ordered_fields = OrderedDict()
    for field_name in BIB_FIELD_ORDER:
        value = normalize_whitespace(str(source_fields.get(field_name, "")))
        if value:
            ordered_fields[field_name] = value

    for field_name in sorted(source_fields.keys()):
        if field_name in ordered_fields or field_name in BIB_FIELD_ORDER:
            continue
        value = normalize_whitespace(str(source_fields.get(field_name, "")))
        if value:
            ordered_fields[field_name] = value

    lines = [f"@{entry_type}{{{key},"]
    last_idx = len(ordered_fields) - 1
    for idx, (name, value) in enumerate(ordered_fields.items()):
        tail = "," if idx != last_idx else ""
        lines.append(f"  {name} = {format_bib_value(value)}{tail}")
    lines.append("}")
    return "\n".join(lines)


def merge_bib_libraries(data_bib_path: Path, wealth_bib_path: Path, both_bib_output: Path) -> int:
    if not data_bib_path.exists():
        raise FileNotFoundError(f"DataSources bib is missing: {data_bib_path}")
    if not wealth_bib_path.exists():
        raise FileNotFoundError(f"WealthResearch bib is missing: {wealth_bib_path}")

    try:
        data_text = data_bib_path.read_text(encoding="utf-8")
    except OSError as exc:
        raise RuntimeError(f"Could not read DataSources bib ({data_bib_path}): {exc}") from exc

    try:
        wealth_text = wealth_bib_path.read_text(encoding="utf-8")
    except OSError as exc:
        raise RuntimeError(f"Could not read WealthResearch bib ({wealth_bib_path}): {exc}") from exc

    data_entries = parse_bib_entries(data_text)
    wealth_entries = parse_bib_entries(wealth_text)

    # Prefer DataSources on overlap; include all non-overlapping entries from both files.
    merged = dict(wealth_entries)
    merged.update(data_entries)

    combined_entries = [render_parsed_bib_entry(key, merged[key]) for key in sorted(merged.keys(), key=lambda k: k.lower())]
    both_bib_output.parent.mkdir(parents=True, exist_ok=True)
    both_bib_output.write_text("\n\n".join(combined_entries).strip() + "\n", encoding="utf-8")
    return len(merged)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--registry", default=DEFAULT_REGISTRY_PATH, help="Path to canonical registry")
    parser.add_argument("--dictionary-template", default=None, help="Template dictionary.xlsx path")
    parser.add_argument("--dictionary-output", default=None, help="Output dictionary.xlsx path")
    parser.add_argument("--bib-output", default=None, help="Output .bib path")
    parser.add_argument("--wealth-bib-input", default=None, help="Input wealth research .bib path")
    parser.add_argument("--both-bib-output", default=None, help="Output combined .bib path")
    args = parser.parse_args()

    registry_path = Path(args.registry)
    reg = load_registry(registry_path)
    cfg = reg.get("config", {})

    dictionary_template = Path(args.dictionary_template or cfg.get("dictionary_template", DEFAULT_DICTIONARY_PATH))
    dictionary_output = Path(args.dictionary_output or cfg.get("dictionary_output", DEFAULT_DICTIONARY_PATH))
    bib_output = Path(args.bib_output or cfg.get("bib_output", DEFAULT_DATA_BIB_PATH))
    wealth_bib_input = Path(
        args.wealth_bib_input or cfg.get("wealth_bib_input", DEFAULT_WEALTH_BIB_PATH)
    )
    both_bib_output = Path(args.both_bib_output or cfg.get("both_bib_output", DEFAULT_BOTH_BIB_PATH))

    records = records_sorted(reg.get("records", []))

    rows = [record_to_sources_sheet_row(r) for r in records]
    write_sources_sheet(dictionary_template, dictionary_output, rows)
    write_bib(bib_output, records)
    both_count = merge_bib_libraries(bib_output, wealth_bib_input, both_bib_output)

    print(f"Generated dictionary Sources sheet: {dictionary_output}")
    print(f"Generated DataSources bib: {bib_output}")
    print(f"Generated combined bib: {both_bib_output}")
    print(f"Records: {len(records)}")
    print(f"Combined bib entries: {both_count}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (FileNotFoundError, RuntimeError) as exc:
        print(str(exc), file=sys.stderr)
        raise SystemExit(1)
