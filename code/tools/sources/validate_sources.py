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
    CANONICAL_DATA_SOURCE_KEYWORD_SET,
    DATA_SOURCE_KEYWORD_PREFIX,
    DIGITAL_LIBRARY_CONFLICT_FIELDS,
    RESEARCH_CATEGORY_KEYWORD_SET,
    build_digital_library_entries,
    canonical_data_source_keyword_for_section,
    canonical_data_source_keywords_for_sections,
    data_source_keywords_from_value,
    is_canonical_data_source_keyword,
    is_data_source_keyword,
    load_json_yaml,
    load_registry,
    normalize_text,
    normalize_url,
    normalize_whitespace,
    parse_bib_entries,
    record_is_data_source,
    read_source_alias_sheet,
    read_sources_sheet,
    records_sorted,
    research_category_keywords_from_value,
    split_section_labels,
    split_keywords,
    validate_xlsx_file,
)
from source_paths import (
    DEFAULT_ALIASES_PATH,
    DEFAULT_CHANGE_LOG_PATH,
    DEFAULT_DIGITAL_BIB_PATH,
    DEFAULT_DICTIONARY_PATH,
    DEFAULT_REGISTRY_PATH,
    DEFAULT_SCHEMA_PATH,
)

URL_RE = re.compile(r"^https?://", re.IGNORECASE)
DOI_RE = re.compile(r"^10\.\d{4,9}/[-._;()/:A-Z0-9]+$", re.IGNORECASE)
YEAR_RE = re.compile(r"^\d{4}$")
BIB_KEY_RE = re.compile(r"@\w+\s*\{\s*([^,\n]+)\s*,", re.IGNORECASE)


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
    by_alias = {}
    by_citekey = {}
    by_url = {}
    by_title_year = {}
    canonical_sources = {
        normalize_whitespace(str(rec.get("source", "")))
        for rec in records
        if normalize_whitespace(str(rec.get("source", "")))
    }

    def intentional_shared(first: dict, current: dict) -> bool:
        first_citekey = normalize_whitespace(str(first.get("citekey", "")))
        current_citekey = normalize_whitespace(str(current.get("citekey", "")))
        first_group = normalize_whitespace(str(first.get("shared_citekey_group", "")))
        current_group = normalize_whitespace(str(current.get("shared_citekey_group", "")))
        return bool(first_citekey and first_citekey == current_citekey and first_group and first_group == current_group)

    def conflicting_bibliographic_fields(first: dict, current: dict) -> list:
        first_bib = first.get("bib", {}) or {}
        current_bib = current.get("bib", {}) or {}
        conflicts = []
        for field in DIGITAL_LIBRARY_CONFLICT_FIELDS:
            first_value = normalize_whitespace(str(first_bib.get(field, "")))
            current_value = normalize_whitespace(str(current_bib.get(field, "")))
            if not first_value or not current_value:
                continue
            first_norm = first_value.lower() if field in {"year", "doi"} else normalize_text(first_value)
            current_norm = current_value.lower() if field in {"year", "doi"} else normalize_text(current_value)
            if first_norm != current_norm:
                conflicts.append(field)
        return conflicts

    for rec in records:
        rec_id = rec.get("id", "")
        source = normalize_whitespace(rec.get("source", ""))
        citekey = normalize_whitespace(rec.get("citekey", ""))
        section = normalize_whitespace(rec.get("section", ""))
        link = normalize_whitespace(rec.get("link", ""))
        ref_link = normalize_whitespace(rec.get("ref_link", ""))
        bib = rec.get("bib", {}) or {}
        is_data_source = record_is_data_source(rec)

        if not rec_id:
            errors.append("Record with missing id")
        if not citekey:
            errors.append(f"{rec_id}: missing citekey")
        if is_data_source and not source:
            errors.append(f"{rec_id}: data-source records must have source")
        if not is_data_source and source:
            errors.append(f"{rec_id}: non-data-source records must leave source blank; use citekey for the BibTeX key")
        if is_data_source and not link:
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
        keyword_tokens = split_keywords(keywords)
        data_source_tokens = [token for token in keyword_tokens if is_data_source_keyword(token)]
        canonical_data_source_tokens = [token for token in data_source_tokens if is_canonical_data_source_keyword(token)]
        noncanonical_data_source_tokens = [token for token in data_source_tokens if not is_canonical_data_source_keyword(token)]
        uncontrolled_tokens = [
            token
            for token in keyword_tokens
            if token not in RESEARCH_CATEGORY_KEYWORD_SET
            and not is_data_source_keyword(token)
        ]
        section_keywords = canonical_data_source_keywords_for_sections(section)
        unknown_sections = [
            label
            for label in split_section_labels(section)
            if not canonical_data_source_keyword_for_section(label)
        ]
        research_category_tokens = research_category_keywords_from_value(keywords)
        manual_review = bool(
            rec.get("manual_review")
            or rec.get("manual_review_required")
            or rec.get("needs_manual_review")
            or normalize_whitespace(str(rec.get("classification_review", ""))).lower() in {"manual_review", "manual review", "needs_review", "needs review"}
        )

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
            errors.append(f"{rec_id}: bib.keywords is required for digital_library.bib export")
        if noncanonical_data_source_tokens:
            errors.append(
                f"{rec_id}: noncanonical data-source keyword(s): {', '.join(noncanonical_data_source_tokens)}. "
                f"Allowed: {', '.join(sorted(CANONICAL_DATA_SOURCE_KEYWORD_SET))}"
            )
        if uncontrolled_tokens:
            errors.append(
                f"{rec_id}: uncontrolled keyword(s): {', '.join(uncontrolled_tokens)}. "
                "Use the controlled data-source and research category checkboxes."
            )
        if unknown_sections:
            errors.append(f"{rec_id}: unrecognized data-source section/category: {', '.join(unknown_sections)}")
        if is_data_source:
            if not canonical_data_source_tokens:
                errors.append(
                    f"{rec_id}: data-source records must have one or more controlled canonical {DATA_SOURCE_KEYWORD_PREFIX} keyword"
                )
            if section_keywords and set(canonical_data_source_tokens) != set(section_keywords):
                errors.append(
                    f"{rec_id}: section/category values must map to the selected data-source keyword(s)"
                )
        elif data_source_tokens:
            errors.append(f"{rec_id}: non-data-source records must not have {DATA_SOURCE_KEYWORD_PREFIX} keywords")
        elif not research_category_tokens and not manual_review:
            errors.append(
                f"{rec_id}: non-data-source records must have at least one controlled research category keyword "
                "or be explicitly marked for manual review"
            )

        for alias in rec.get("source_aliases", []) or []:
            alias = normalize_whitespace(str(alias))
            if alias and alias == source:
                errors.append(f"{rec_id}: source_aliases must not repeat canonical source {source}")
            if alias and alias in canonical_sources:
                errors.append(f"{rec_id}: source alias {alias} collides with an active source code")
            if alias and alias in by_alias and by_alias[alias][0] != source:
                errors.append(
                    f"{rec_id}: source alias {alias} maps to both {by_alias[alias][0]} and {source}"
                )
            elif alias:
                by_alias[alias] = (source, rec_id)

        if source and source in by_source:
            errors.append(f"Exact duplicate source: {source} ({by_source[source]} and {rec_id})")
        elif source:
            by_source[source] = rec_id

        if citekey in by_citekey:
            first = by_citekey[citekey]
            first_group = normalize_whitespace(str(first.get("shared_citekey_group", "")))
            current_group = normalize_whitespace(str(rec.get("shared_citekey_group", "")))
            if not first_group or first_group != current_group:
                msg = f"Exact duplicate citekey: {citekey} ({first.get('id', '')} and {rec_id})"
                conflict_fields = conflicting_bibliographic_fields(first, rec)
                if conflict_fields:
                    msg += f"; conflicting bibliographic fields: {', '.join(conflict_fields)}"
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
    digital_bib: Path,
) -> list:
    with tempfile.TemporaryDirectory() as td:
        tmp_dict = Path(td) / "dictionary.xlsx"
        tmp_digital_bib = Path(td) / "digital_library.bib"
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
            "--digital-bib-output",
            str(tmp_digital_bib),
        ]
        subprocess.run(cmd, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)

        if not digital_bib.exists():
            raise ValidationError(f"Digital library artifact missing: {digital_bib}")

        if tmp_digital_bib.read_text(encoding="utf-8") != digital_bib.read_text(encoding="utf-8"):
            raise ValidationError("digital_library.bib is out of date. Run build_sources_artifacts.py")

        validate_xlsx_file(tmp_dict)
        current_rows = read_sources_sheet(dictionary)
        rebuilt_rows = read_sources_sheet(tmp_dict)
        if json.dumps(current_rows, sort_keys=True) != json.dumps(rebuilt_rows, sort_keys=True):
            raise ValidationError("dictionary.xlsx Sources sheet is out of date. Run build_sources_artifacts.py")
        current_alias_rows = read_source_alias_sheet(dictionary)
        rebuilt_alias_rows = read_source_alias_sheet(tmp_dict)
        if json.dumps(current_alias_rows, sort_keys=True) != json.dumps(rebuilt_alias_rows, sort_keys=True):
            raise ValidationError("dictionary.xlsx SourceAliases sheet is out of date. Run build_sources_artifacts.py")

        return validate_digital_bib(digital_bib)


def raw_bib_duplicate_keys(text: str) -> list:
    keys = [normalize_whitespace(match.group(1)) for match in BIB_KEY_RE.finditer(text)]
    counts = defaultdict(int)
    for key in keys:
        if key:
            counts[key] += 1
    return sorted([key for key, count in counts.items() if count > 1], key=str.lower)


def validate_digital_bib(path: Path) -> list:
    text = path.read_text(encoding="utf-8")
    duplicate_keys = raw_bib_duplicate_keys(text)
    if duplicate_keys:
        raise ValidationError(f"digital_library.bib contains duplicate citekey(s): {', '.join(duplicate_keys)}")
    entries = parse_bib_entries(text)
    errors = []
    warns = []
    for key, entry in entries.items():
        fields = entry.get("fields", {}) or {}
        if "section" in fields:
            errors.append(f"{key}: exported BibTeX must not include section field")
        keywords = normalize_whitespace(str(fields.get("keywords", "")))
        if not keywords:
            errors.append(f"{key}: exported BibTeX keywords are required")
            continue
        data_source_tokens = data_source_keywords_from_value(keywords, canonical_only=False)
        bad_data_source_tokens = [token for token in data_source_tokens if not is_canonical_data_source_keyword(token)]
        if bad_data_source_tokens:
            errors.append(f"{key}: noncanonical exported data-source keyword(s): {', '.join(bad_data_source_tokens)}")
        uncontrolled_tokens = [
            token
            for token in split_keywords(keywords)
            if token not in RESEARCH_CATEGORY_KEYWORD_SET
            and not is_data_source_keyword(token)
        ]
        if uncontrolled_tokens:
            errors.append(f"{key}: uncontrolled exported keyword(s): {', '.join(uncontrolled_tokens)}")
    if errors:
        raise ValidationError("\n".join(errors))
    return warns


def digital_library_merge_warnings(registry: dict) -> list:
    _, report = build_digital_library_entries(records_sorted(registry.get("records", [])))
    warnings = []
    for conflict in report.get("bibliographic_conflicts", []):
        warnings.append(
            "Digital library duplicate citekey conflict: "
            f"{conflict.get('citekey', '')} field={conflict.get('field', '')} "
            f"incoming={conflict.get('incoming_source', '')}"
        )
    for item in report.get("multi_data_source_keyword_exports", []):
        warnings.append(
            "Digital library merged multi-category data-source entry: "
            f"{item.get('citekey', '')} -> {', '.join(item.get('keywords', []))}"
        )
    return warnings


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--registry", default=DEFAULT_REGISTRY_PATH)
    parser.add_argument("--schema", default=DEFAULT_SCHEMA_PATH)
    parser.add_argument("--aliases", default=DEFAULT_ALIASES_PATH)
    parser.add_argument("--change-log", default=DEFAULT_CHANGE_LOG_PATH)
    parser.add_argument("--check-generated", action="store_true")
    parser.add_argument("--dictionary", default=DEFAULT_DICTIONARY_PATH)
    parser.add_argument("--digital-bib", default=None)
    parser.add_argument("--bib", default=None, help="Deprecated alias for --digital-bib")
    parser.add_argument("--wealth-bib-input", default=None, help="Deprecated; ignored because sources.yaml is the only input")
    parser.add_argument("--both-bib", default=None, help="Deprecated; ignored because split outputs are legacy")
    parser.add_argument("--strict", action="store_true", help="Fail on duplicate citekey/url/title-year and URL/DOI format issues")
    args = parser.parse_args()

    registry_path = Path(args.registry)
    schema_path = Path(args.schema)
    aliases_path = Path(args.aliases)
    changelog_path = Path(args.change_log)

    reg = load_registry(registry_path)
    validate_schema_shape(reg, schema_path)
    warnings = validate_records(reg, strict=args.strict)
    warnings.extend(digital_library_merge_warnings(reg))
    validate_aliases(aliases_path)
    validate_change_log(changelog_path)

    if args.check_generated:
        warnings.extend(check_generated_artifacts(
            registry_path,
            Path(args.dictionary),
            Path(args.digital_bib or args.bib or DEFAULT_DIGITAL_BIB_PATH),
        ))

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
