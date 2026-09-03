#!/usr/bin/env python3
"""Bootstrap canonical source registry from dictionary Sources sheet and an optional bib file."""

import argparse
import re
from collections import OrderedDict
from pathlib import Path

from common import (
    DEFAULT_REGISTRY,
    dump_json_yaml,
    now_utc,
    parse_bib_entries,
    read_sources_sheet,
)
from source_paths import DEFAULT_DICTIONARY_PATH, DEFAULT_REGISTRY_PATH


def slugify(value: str) -> str:
    v = re.sub(r"[^A-Za-z0-9]+", "-", value.strip()).strip("-").lower()
    return v or "source"


def map_row(row: dict, bib_map: dict, idx: int) -> dict:
    source = (row.get("Source") or "").strip()
    citekey = (row.get("Citekey") or "").strip() or source
    key = citekey or source

    bib = bib_map.get(key, {"entry_type": "misc", "fields": OrderedDict()})
    fields = bib.get("fields", {})
    extra_fields = OrderedDict()
    for k, v in fields.items():
        if k not in {
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
        }:
            extra_fields[k] = v

    rid = f"src-{slugify(source or citekey)}"
    link = (row.get("Link") or "").strip() or fields.get("url", "").strip() or (row.get("Ref_link") or "").strip()
    record = {
        "id": rid,
        "section": (row.get("Section") or "").strip(),
        "aggsource": (row.get("AggSource") or "").strip(),
        "legend": (row.get("Legend") or "").strip(),
        "source": source,
        "data_type": (row.get("Data_Type") or "").strip(),
        "link": link,
        "ref_link": (row.get("Ref_link") or "").strip(),
        "citekey": citekey,
        "inclusion_in_warehouse": (row.get("Inclusion_in_Warehouse") or "").strip(),
        "multigeo_reference": (row.get("Multigeo_Reference") or "").strip(),
        "metadata": (row.get("Metadata") or "").strip(),
        "metadatalink": (row.get("Metadatalink") or "").strip(),
        "qcommentsforta": (row.get("QcommentsforTA") or "").strip(),
        "tareply": (row.get("TAreply") or "").strip(),
        "tacomments": (row.get("TAcomments") or "").strip(),
        "arjcomments": (row.get("ARJcomments") or "").strip(),
        "arjreplies": (row.get("ARJreplies") or "").strip(),
        "seeaggsourcelisthere": (row.get("SeeAggSourcelisthere") or "").strip(),
        "bib": {
            "entry_type": bib.get("entry_type", "misc"),
            "title": fields.get("title", row.get("Legend", "")).strip(),
            "author": fields.get("author", "Unknown").strip(),
            "year": fields.get("year", "1900").strip(),
            "month": fields.get("month", "").strip(),
            "journal": fields.get("journal", "").strip(),
            "booktitle": fields.get("booktitle", "").strip(),
            "volume": fields.get("volume", "").strip(),
            "number": fields.get("number", "").strip(),
            "pages": fields.get("pages", "").strip(),
            "institution": fields.get("institution", "").strip(),
            "publisher": fields.get("publisher", "").strip(),
            "doi": fields.get("doi", "").strip(),
            "url": fields.get("url", row.get("Link", "")).strip(),
            "urldate": fields.get("urldate", "").strip(),
            "abstract": fields.get("abstract", "").strip(),
            "keywords": fields.get("keywords", "Data Sources: Unclassified").strip(),
            "note": fields.get("note", "").strip(),
            "extra_fields": extra_fields,
        },
        "created_at": now_utc(),
        "updated_at": now_utc(),
    }
    return record


def dedupe_records(records: list) -> list:
    by_source = OrderedDict()
    for rec in records:
        src = rec.get("source", "")
        if not src:
            continue
        if src not in by_source:
            by_source[src] = rec
            continue
        # Prefer the one with citekey and ref_link populated.
        existing = by_source[src]
        score_existing = int(bool(existing.get("citekey"))) + int(bool(existing.get("ref_link")))
        score_new = int(bool(rec.get("citekey"))) + int(bool(rec.get("ref_link")))
        if score_new > score_existing:
            by_source[src] = rec
    return list(by_source.values())


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dictionary", default=DEFAULT_DICTIONARY_PATH)
    parser.add_argument("--bib", default="", help="Optional bib file path")
    parser.add_argument("--out", default=DEFAULT_REGISTRY_PATH)
    args = parser.parse_args()

    dictionary = Path(args.dictionary)
    out = Path(args.out)
    bib_map = {}

    if args.bib:
        bib_path = Path(args.bib)
        if bib_path.exists():
            bib_map = parse_bib_entries(bib_path.read_text(encoding="utf-8", errors="ignore"))

    rows = read_sources_sheet(dictionary)
    records = []
    for idx, row in enumerate(rows, start=1):
        source = (row.get("Source") or "").strip()
        if not source:
            continue
        records.append(map_row(row, bib_map, idx))

    records = dedupe_records(records)

    payload = OrderedDict(DEFAULT_REGISTRY)
    payload["records"] = sorted(records, key=lambda r: r.get("source", "").lower())
    dump_json_yaml(out, payload)

    print(f"Wrote {len(payload['records'])} canonical records to {out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
