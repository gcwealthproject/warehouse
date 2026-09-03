#!/usr/bin/env python3
"""Validate canonical source registry and generated artifacts."""

import argparse
import json
import re
import shutil
import subprocess
import sys
import tempfile
from collections import defaultdict
from difflib import SequenceMatcher
from pathlib import Path
from urllib.parse import urlparse

from common import (
    load_json_yaml,
    load_registry,
    normalize_text,
    normalize_url,
    normalize_whitespace,
    read_sources_sheet,
    records_sorted,
    validate_xlsx_file,
)
from source_paths import (
    DEFAULT_ALIASES_PATH,
    DEFAULT_BOTH_BIB_PATH,
    DEFAULT_CHANGE_LOG_PATH,
    DEFAULT_DATA_BIB_PATH,
    DEFAULT_DICTIONARY_PATH,
    DEFAULT_REGISTRY_PATH,
    DEFAULT_SCHEMA_PATH,
    DEFAULT_WEALTH_BIB_PATH,
)

URL_RE = re.compile(r"^https?://", re.IGNORECASE)
DOI_RE = re.compile(r"^10\.\d{4,9}/[-._;()/:A-Z0-9]+$", re.IGNORECASE)
YEAR_RE = re.compile(r"^\d{4}$")


class ValidationError(Exception):
    pass


def validate_schema_shape(registry: dict, schema_path: Path) -> None:
    schema = load_json_yaml(schema_path)
    required = schema.get("required", [])
    for key in required:
        if key not in registry:
            raise ValidationError(f"Missing required top-level key in registry: {key}")

    for idx, rec in enumerate(registry.get("records", []), start=1):
        for field in schema.get("definitions", {}).get("record", {}).get("required", []):
            if not normalize_whitespace(str(rec.get(field, ""))):
                raise ValidationError(f"Record #{idx} missing required field: {field}")


def validate_records(registry: dict, strict: bool = False) -> list:
    records = records_sorted(registry.get("records", []))
    errors = []
    warns = []

    by_source = {}
    by_citekey = {}
    by_url = {}
    by_title_year = {}

    def intentional_shared(first: dict, current: dict) -> bool:
        first_citekey = normalize_whitespace(str(first.get("citekey", "")))
        current_citekey = normalize_whitespace(str(current.get("citekey", "")))
        first_group = normalize_whitespace(str(first.get("shared_citekey_group", "")))
        current_group = normalize_whitespace(str(current.get("shared_citekey_group", "")))
        return bool(first_citekey and first_citekey == current_citekey and first_group and first_group == current_group)

    for rec in records:
        rec_id = rec.get("id", "")
        source = normalize_whitespace(rec.get("source", ""))
        citekey = normalize_whitespace(rec.get("citekey", ""))
        link = normalize_whitespace(rec.get("link", ""))
        ref_link = normalize_whitespace(rec.get("ref_link", ""))
        bib = rec.get("bib", {}) or {}

        if not rec_id:
            errors.append("Record with missing id")
        if not source:
            errors.append(f"{rec_id}: missing source")
        if not citekey:
            errors.append(f"{rec_id}: missing citekey")
        if not link:
            errors.append(f"{rec_id}: missing link")

        if link and not URL_RE.match(link):
            msg = f"{rec_id}: invalid link URL: {link}"
            (errors if strict else warns).append(msg)
        if ref_link and not URL_RE.match(ref_link):
            msg = f"{rec_id}: invalid ref_link URL: {ref_link}"
            (errors if strict else warns).append(msg)

        year = str(bib.get("year", "")).strip()
        title = normalize_whitespace(str(bib.get("title", "")))
        author = normalize_whitespace(str(bib.get("author", "")))
        bib_url = normalize_whitespace(str(bib.get("url", "")))
        doi = normalize_whitespace(str(bib.get("doi", "")))
        keywords = normalize_whitespace(str(bib.get("keywords", "")))

        if not normalize_whitespace(str(bib.get("entry_type", ""))):
            errors.append(f"{rec_id}: bib.entry_type is required")
        if not title:
            errors.append(f"{rec_id}: bib.title is required")
        if not author:
            errors.append(f"{rec_id}: bib.author is required")
        if not year or not YEAR_RE.match(year):
            errors.append(f"{rec_id}: bib.year must be YYYY")
        if year and YEAR_RE.match(year):
            y = int(year)
            if y < 1600 or y > 2100:
                errors.append(f"{rec_id}: bib.year out of expected range: {y}")
        if bib_url and not URL_RE.match(bib_url):
            msg = f"{rec_id}: invalid bib.url: {bib_url}"
            (errors if strict else warns).append(msg)
        if doi and not DOI_RE.match(doi):
            msg = f"{rec_id}: invalid bib.doi: {doi}"
            (errors if strict else warns).append(msg)
        if not keywords:
            warns.append(f"{rec_id}: bib.keywords is missing (recommended but optional)")

        if source in by_source:
            errors.append(f"Exact duplicate source: {source} ({by_source[source]} and {rec_id})")
        else:
            by_source[source] = rec_id

        if citekey in by_citekey:
            first = by_citekey[citekey]
            first_group = normalize_whitespace(str(first.get("shared_citekey_group", "")))
            current_group = normalize_whitespace(str(rec.get("shared_citekey_group", "")))
            if not first_group or first_group != current_group:
                msg = f"Exact duplicate citekey: {citekey} ({first.get('id', '')} and {rec_id})"
                (errors if strict else warns).append(msg)
        else:
            by_citekey[citekey] = rec

        url_candidate = normalize_url(bib_url or link)
        if url_candidate:
            if url_candidate in by_url:
                first = by_url[url_candidate]
                if not intentional_shared(first, rec):
                    msg = f"Exact duplicate URL: {url_candidate} ({first.get('id', '')} and {rec_id}). Use edit mode."
                    (errors if strict else warns).append(msg)
            else:
                by_url[url_candidate] = rec

        if title and year:
            ty = (normalize_text(title), year)
            if ty in by_title_year:
                first = by_title_year[ty]
                if not intentional_shared(first, rec):
                    msg = f"Exact duplicate title/year: {title} ({year}) ({first.get('id', '')} and {rec_id}). Use edit mode."
                    (errors if strict else warns).append(msg)
            else:
                by_title_year[ty] = rec

    warns.extend(fuzzy_warnings(records))

    if errors:
        raise ValidationError("\n".join(errors))
    return warns


def fuzzy_warnings(records: list) -> list:
    warns = set()

    # Compare titles only within coarse buckets to keep runtime bounded.
    title_buckets = defaultdict(list)
    for rec in records:
        title = normalize_text(str((rec.get("bib", {}) or {}).get("title", "")))
        if title:
            bucket_key = title[:12]
            title_buckets[bucket_key].append((rec, title))

    for bucket in title_buckets.values():
        if len(bucket) < 2:
            continue
        for i in range(len(bucket)):
            a, a_title = bucket[i]
            for j in range(i + 1, len(bucket)):
                b, b_title = bucket[j]
                if a_title == b_title:
                    continue
                sim = SequenceMatcher(None, a_title, b_title).ratio()
                if sim >= 0.93:
                    warns.add(f"Fuzzy title match ({sim:.2f}): {a.get('id','')} ~ {b.get('id','')}")

    # Author+year near matches.
    ay_buckets = defaultdict(list)
    for rec in records:
        bib = rec.get("bib", {}) or {}
        year = str(bib.get("year", "")).strip()
        author = normalize_text(str(bib.get("author", "")))
        if year and author:
            ay_buckets[year].append((rec, author))

    for bucket in ay_buckets.values():
        if len(bucket) < 2:
            continue
        for i in range(len(bucket)):
            a, a_author = bucket[i]
            for j in range(i + 1, len(bucket)):
                b, b_author = bucket[j]
                if a_author == b_author:
                    continue
                asim = SequenceMatcher(None, a_author, b_author).ratio()
                if asim >= 0.92:
                    warns.add(f"Fuzzy author+year match ({asim:.2f}): {a.get('id','')} ~ {b.get('id','')}")

    # URL near matches within same domain.
    domain_buckets = defaultdict(list)
    for rec in records:
        url = normalize_url(str((rec.get("bib", {}) or {}).get("url", "") or rec.get("link", "")))
        if not url:
            continue
        parsed = urlparse(url)
        if parsed.netloc:
            domain_buckets[parsed.netloc].append((rec, parsed.path))

    for bucket in domain_buckets.values():
        if len(bucket) < 2:
            continue
        for i in range(len(bucket)):
            a, a_path = bucket[i]
            for j in range(i + 1, len(bucket)):
                b, b_path = bucket[j]
                if not a_path or not b_path or a_path == b_path:
                    continue
                psim = SequenceMatcher(None, a_path, b_path).ratio()
                if psim >= 0.9:
                    warns.add(f"Fuzzy URL path match ({psim:.2f}): {a.get('id','')} ~ {b.get('id','')}")
    return sorted(warns)


def validate_aliases(aliases_path: Path) -> None:
    data = load_json_yaml(aliases_path)
    if not data:
        return
    if not isinstance(data, dict) or "aliases" not in data:
        raise ValidationError("aliases.yaml must contain an 'aliases' array")
    for idx, entry in enumerate(data.get("aliases", []), start=1):
        for req in ["type", "old", "new", "reason", "updated_at"]:
            if not normalize_whitespace(str(entry.get(req, ""))):
                raise ValidationError(f"aliases.yaml entry #{idx} missing field: {req}")


def validate_change_log(changelog_path: Path) -> None:
    data = load_json_yaml(changelog_path)
    if not data:
        return
    if not isinstance(data, dict) or "changes" not in data:
        raise ValidationError("change_log.yaml must contain a 'changes' array")
    for idx, entry in enumerate(data.get("changes", []), start=1):
        for req in ["operation", "record_id", "reason", "updated_at"]:
            if not normalize_whitespace(str(entry.get(req, ""))):
                raise ValidationError(f"change_log.yaml entry #{idx} missing field: {req}")


def check_generated_artifacts(
    registry_path: Path,
    dictionary: Path,
    bib: Path,
    wealth_bib_input: Path,
    both_bib_output: Path,
) -> None:
    with tempfile.TemporaryDirectory() as td:
        tmp_dict = Path(td) / "dictionary.xlsx"
        tmp_bib = Path(td) / "data.bib"
        tmp_both_bib = Path(td) / "both.bib"
        validate_xlsx_file(dictionary)
        shutil.copy2(dictionary, tmp_dict)
        cmd = [
            sys.executable,
            str(Path(__file__).parent / "build_sources_artifacts.py"),
            "--registry",
            str(registry_path),
            "--dictionary-template",
            str(dictionary),
            "--dictionary-output",
            str(tmp_dict),
            "--bib-output",
            str(tmp_bib),
            "--wealth-bib-input",
            str(wealth_bib_input),
            "--both-bib-output",
            str(tmp_both_bib),
        ]
        subprocess.run(cmd, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)

        if not bib.exists():
            raise ValidationError(f"Bib artifact missing: {bib}")
        if not both_bib_output.exists():
            raise ValidationError(f"Combined bib artifact missing: {both_bib_output}")

        if tmp_bib.read_text(encoding="utf-8") != bib.read_text(encoding="utf-8"):
            raise ValidationError("Generated bib is out of date. Run build_sources_artifacts.py")
        if tmp_both_bib.read_text(encoding="utf-8") != both_bib_output.read_text(encoding="utf-8"):
            raise ValidationError("Generated combined bib is out of date. Run build_sources_artifacts.py")

        validate_xlsx_file(tmp_dict)
        current_rows = read_sources_sheet(dictionary)
        rebuilt_rows = read_sources_sheet(tmp_dict)
        if json.dumps(current_rows, sort_keys=True) != json.dumps(rebuilt_rows, sort_keys=True):
            raise ValidationError("dictionary.xlsx Sources sheet is out of date. Run build_sources_artifacts.py")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--registry", default=DEFAULT_REGISTRY_PATH)
    parser.add_argument("--schema", default=DEFAULT_SCHEMA_PATH)
    parser.add_argument("--aliases", default=DEFAULT_ALIASES_PATH)
    parser.add_argument("--change-log", default=DEFAULT_CHANGE_LOG_PATH)
    parser.add_argument("--check-generated", action="store_true")
    parser.add_argument("--dictionary", default=DEFAULT_DICTIONARY_PATH)
    parser.add_argument("--bib", default=DEFAULT_DATA_BIB_PATH)
    parser.add_argument("--wealth-bib-input", default=DEFAULT_WEALTH_BIB_PATH)
    parser.add_argument("--both-bib", default=DEFAULT_BOTH_BIB_PATH)
    parser.add_argument("--strict", action="store_true", help="Fail on duplicate citekey/url/title-year and URL/DOI format issues")
    args = parser.parse_args()

    registry_path = Path(args.registry)
    schema_path = Path(args.schema)
    aliases_path = Path(args.aliases)
    changelog_path = Path(args.change_log)

    reg = load_registry(registry_path)
    validate_schema_shape(reg, schema_path)
    warnings = validate_records(reg, strict=args.strict)
    validate_aliases(aliases_path)
    validate_change_log(changelog_path)

    if args.check_generated:
        check_generated_artifacts(
            registry_path,
            Path(args.dictionary),
            Path(args.bib),
            Path(args.wealth_bib_input),
            Path(args.both_bib),
        )

    if warnings:
        print(f"Warnings (non-blocking unless --strict is used): {len(warnings)}")
        limit = 20
        for w in warnings[:limit]:
            print(f" - {w}")
        if len(warnings) > limit:
            print(f" - ... {len(warnings) - limit} additional warnings omitted")

    print("Validation passed")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except ValidationError as exc:
        print(str(exc), file=sys.stderr)
        raise SystemExit(1)
