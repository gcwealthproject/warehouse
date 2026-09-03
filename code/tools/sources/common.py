#!/usr/bin/env python3
"""Common utilities for source registry tooling."""

import io
import json
import math
import re
import tempfile
import zipfile
from collections import OrderedDict
from copy import deepcopy
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Tuple
from urllib.parse import urlparse
import xml.etree.ElementTree as ET
from xml.sax.saxutils import escape

from source_paths import (
    DEFAULT_BOTH_BIB_PATH,
    DEFAULT_DATA_BIB_PATH,
    DEFAULT_DICTIONARY_PATH,
    DEFAULT_WEALTH_BIB_PATH,
    DEFAULT_WEALTH_CHANGE_LOG_PATH,
)

NS_MAIN = "http://schemas.openxmlformats.org/spreadsheetml/2006/main"
NS_REL = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
NS_PKG_REL = "http://schemas.openxmlformats.org/package/2006/relationships"
EXPECTED_SOURCES_SHEET_NAME = "Sources"
REQUIRED_XLSX_MEMBERS = ("xl/workbook.xml", "xl/_rels/workbook.xml.rels")
INVALID_SHEET_CHARS_RE = re.compile(r"[\[\]:*?/\\]")

SOURCES_HEADERS = [
    "Section",
    "AggSource",
    "Legend",
    "Source",
    "Data_Type",
    "Link",
    "Ref_link",
    "Citekey",
    "Inclusion_in_Warehouse",
    "Multigeo_Reference",
    "Metadata",
    "Metadatalink",
    "QcommentsforTA",
    "TAreply",
    "TAcomments",
    "ARJcomments",
    "ARJreplies",
    "SeeAggSourcelisthere",
]

CANONICAL_KEYS = [
    "id",
    "section",
    "aggsource",
    "legend",
    "source",
    "data_type",
    "link",
    "ref_link",
    "citekey",
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
    "bib",
    "created_at",
    "updated_at",
]

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

DEFAULT_REGISTRY = OrderedDict(
    [
        ("version", 1),
        (
            "config",
            OrderedDict(
                [
                    ("bib_output", DEFAULT_DATA_BIB_PATH),
                    ("wealth_bib_input", DEFAULT_WEALTH_BIB_PATH),
                    ("both_bib_output", DEFAULT_BOTH_BIB_PATH),
                    ("wealth_change_log", DEFAULT_WEALTH_CHANGE_LOG_PATH),
                    ("bibbase_profile_source_url", ""),
                    ("bibbase_timeout_seconds", 20),
                    ("online_bib_reference_url", ""),
                    ("online_bib_timeout_seconds", 20),
                    ("wealth_online_bib_reference_url", ""),
                    ("wealth_online_bib_timeout_seconds", 20),
                    ("dictionary_template", DEFAULT_DICTIONARY_PATH),
                    ("dictionary_output", DEFAULT_DICTIONARY_PATH),
                ]
            ),
        ),
        ("records", []),
    ]
)


def now_utc() -> str:
    return datetime.utcnow().replace(microsecond=0).isoformat() + "Z"


def normalize_whitespace(value: str) -> str:
    return re.sub(r"\s+", " ", (value or "").strip())


def normalize_text(value: str) -> str:
    return normalize_whitespace(value).lower()


def normalize_url(value: str) -> str:
    val = normalize_whitespace(value)
    if not val:
        return ""
    parsed = urlparse(val)
    path = re.sub(r"/+", "/", parsed.path).rstrip("/")
    netloc = parsed.netloc.lower()
    scheme = parsed.scheme.lower() if parsed.scheme else "https"
    rebuilt = f"{scheme}://{netloc}{path}"
    if parsed.query:
        rebuilt = f"{rebuilt}?{parsed.query}"
    if parsed.fragment:
        rebuilt = f"{rebuilt}#{parsed.fragment}"
    return rebuilt


def ensure_parent(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)


def sanitize_excel_string(value) -> str:
    if value is None:
        return ""
    text = str(value)
    return "".join(ch for ch in text if _is_valid_excel_xml_char(ord(ch)))


def sanitize_sheet_name(name, fallback: str = "Sheet1") -> str:
    text = INVALID_SHEET_CHARS_RE.sub(" ", sanitize_excel_string(name))
    text = normalize_whitespace(text).strip("'")
    if not text:
        text = INVALID_SHEET_CHARS_RE.sub(" ", sanitize_excel_string(fallback))
        text = normalize_whitespace(text).strip("'")
    return (text or "Sheet1")[:31]


def sanitize_excel_value(value) -> str:
    if value is None:
        return ""
    if isinstance(value, float) and (math.isnan(value) or math.isinf(value)):
        return ""
    return sanitize_excel_string(value)


def _is_valid_excel_xml_char(codepoint: int) -> bool:
    return codepoint in (0x9, 0xA, 0xD) or 0x20 <= codepoint <= 0xD7FF or 0xE000 <= codepoint <= 0xFFFD or 0x10000 <= codepoint <= 0x10FFFF


def _coerce_xlsx_payload(xlsx_source) -> Tuple[bytes, str]:
    if isinstance(xlsx_source, Path):
        return xlsx_source.read_bytes(), str(xlsx_source)
    if isinstance(xlsx_source, str):
        path = Path(xlsx_source)
        return path.read_bytes(), str(path)
    if isinstance(xlsx_source, io.BytesIO):
        return xlsx_source.getvalue(), "<memory>"
    if isinstance(xlsx_source, (bytes, bytearray)):
        return bytes(xlsx_source), "<memory>"
    raise TypeError(f"Unsupported xlsx source type: {type(xlsx_source)!r}")


def _openpyxl_validate_workbook(payload: bytes) -> None:
    load_workbook = _load_openpyxl_workbook()
    workbook = load_workbook(io.BytesIO(payload), read_only=True)
    try:
        _ = workbook.sheetnames
    finally:
        workbook.close()


def _load_openpyxl_workbook():
    try:
        from openpyxl import load_workbook
    except ModuleNotFoundError as exc:
        raise RuntimeError(
            "openpyxl is required for Excel validation. Install it with: python3 -m pip install openpyxl"
        ) from exc
    return load_workbook


def workbook_to_xlsx_bytes(workbook) -> bytes:
    workbook_buffer = io.BytesIO()
    workbook.save(workbook_buffer)
    return workbook_buffer.getvalue()


def validate_xlsx_file(xlsx_source) -> None:
    payload, label = _coerce_xlsx_payload(xlsx_source)
    try:
        with zipfile.ZipFile(io.BytesIO(payload), "r") as zf:
            bad_member = zf.testzip()
            if bad_member:
                raise RuntimeError(f"bad zip member: {bad_member}")
            for required in REQUIRED_XLSX_MEMBERS:
                if required not in zf.namelist():
                    raise RuntimeError(f"missing workbook member: {required}")
            sheet_path, _ = locate_sources_sheet(zf)
            ET.fromstring(zf.read(sheet_path))
        _openpyxl_validate_workbook(payload)
    except (zipfile.BadZipFile, KeyError, ET.ParseError, RuntimeError) as exc:
        raise RuntimeError(f"Generated dictionary workbook is invalid ({label}): {exc}") from exc


def load_json_yaml(path: Path) -> dict:
    if not path.exists():
        return {}
    text = path.read_text(encoding="utf-8").strip()
    if not text:
        return {}
    return json.loads(text)


def dump_json_yaml(path: Path, payload: dict) -> None:
    ensure_parent(path)
    path.write_text(json.dumps(payload, indent=2, ensure_ascii=False, sort_keys=False) + "\n", encoding="utf-8")


def load_registry(path: Path) -> dict:
    data = load_json_yaml(path)
    if not data:
        return deepcopy(DEFAULT_REGISTRY)
    return data


def save_registry(path: Path, data: dict) -> None:
    dump_json_yaml(path, data)


def column_name(idx: int) -> str:
    name = ""
    while idx > 0:
        idx, rem = divmod(idx - 1, 26)
        name = chr(65 + rem) + name
    return name


def parse_bib_entries(text: str) -> Dict[str, dict]:
    entries: Dict[str, dict] = {}
    i = 0
    while True:
        at = text.find("@", i)
        if at < 0:
            break
        brace = text.find("{", at)
        if brace < 0:
            break
        entry_type = text[at + 1 : brace].strip().lower()
        j = brace + 1
        depth = 1
        while j < len(text):
            ch = text[j]
            if ch == "{":
                depth += 1
            elif ch == "}":
                depth -= 1
                if depth == 0:
                    break
            j += 1
        raw = text[brace + 1 : j]
        if "," not in raw:
            i = j + 1
            continue
        key, fields_blob = raw.split(",", 1)
        key = key.strip()
        fields = parse_bib_fields(fields_blob)
        entries[key] = {"entry_type": entry_type, "fields": fields}
        i = j + 1
    return entries


def parse_bib_fields(blob: str) -> OrderedDict:
    fields = OrderedDict()
    p = 0
    n = len(blob)
    while p < n:
        while p < n and blob[p] in " \n\r\t,":
            p += 1
        if p >= n:
            break
        eq = blob.find("=", p)
        if eq < 0:
            break
        name = blob[p:eq].strip().lower()
        p = eq + 1
        while p < n and blob[p] in " \n\r\t":
            p += 1
        if p >= n:
            break

        if blob[p] == "{":
            depth = 1
            p += 1
            start = p
            while p < n and depth > 0:
                if blob[p] == "{":
                    depth += 1
                elif blob[p] == "}":
                    depth -= 1
                p += 1
            value = blob[start : p - 1]
        elif blob[p] == '"':
            p += 1
            start = p
            while p < n and blob[p] != '"':
                if blob[p] == "\\":
                    p += 1
                p += 1
            value = blob[start:p]
            p += 1
        else:
            start = p
            while p < n and blob[p] not in ",\n\r":
                p += 1
            value = blob[start:p].strip()

        fields[name] = value.strip()
        comma = blob.find(",", p)
        if comma < 0:
            break
        p = comma + 1
    return fields


def format_bib_value(value: str) -> str:
    return "{" + value.replace("\n", " ").strip() + "}"


def render_bib_entry(key: str, record: dict) -> str:
    bib = record.get("bib", {})
    entry_type = bib.get("entry_type", "misc").strip().lower() or "misc"
    ordered_fields = [
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

    fields = OrderedDict()
    for f in ordered_fields:
        val = bib.get(f, "")
        if normalize_whitespace(str(val)):
            fields[f] = str(val)

    extras = bib.get("extra_fields", {}) or {}
    for k in sorted(extras.keys()):
        val = normalize_whitespace(str(extras[k]))
        if val:
            fields[k] = val

    lines = [f"@{entry_type}{{{key},"]
    last_index = len(fields) - 1
    for idx, (name, value) in enumerate(fields.items()):
        tail = "," if idx != last_index else ""
        lines.append(f"  {name} = {format_bib_value(value)}{tail}")
    lines.append("}")
    return "\n".join(lines)


def render_parsed_bib_entry(key: str, entry: dict, field_order: List[str] = None) -> str:
    order = field_order or BIB_FIELD_ORDER
    entry_type = normalize_whitespace(str(entry.get("entry_type", "misc"))).lower() or "misc"
    source_fields = entry.get("fields", {}) or {}

    ordered_fields = OrderedDict()
    for field_name in order:
        value = normalize_whitespace(str(source_fields.get(field_name, "")))
        if value:
            ordered_fields[field_name] = value

    for field_name in sorted(source_fields.keys()):
        if field_name in ordered_fields or field_name in order:
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


def write_parsed_bib_entries(path: Path, entries: Dict[str, dict], field_order: List[str] = None) -> None:
    rendered = []
    for key in sorted(entries.keys(), key=lambda k: k.lower()):
        rendered.append(render_parsed_bib_entry(key, entries[key], field_order=field_order))
    ensure_parent(path)
    path.write_text("\n\n".join(rendered).strip() + "\n", encoding="utf-8")


def records_sorted(records: List[dict]) -> List[dict]:
    return sorted(records, key=lambda r: (normalize_text(r.get("source", "")), normalize_text(r.get("citekey", ""))))


def get_cell_value(cell: ET.Element, shared: List[str], ns: Dict[str, str]) -> str:
    ctype = cell.attrib.get("t")
    if ctype == "inlineStr":
        node = cell.find("a:is/a:t", ns)
        return node.text if node is not None and node.text else ""
    v = cell.find("a:v", ns)
    if v is None:
        return ""
    raw = v.text or ""
    if ctype == "s" and raw.isdigit():
        idx = int(raw)
        return shared[idx] if idx < len(shared) else ""
    return raw


def locate_sources_sheet(zf: zipfile.ZipFile) -> Tuple[str, str]:
    workbook = ET.fromstring(zf.read("xl/workbook.xml"))
    rels = ET.fromstring(zf.read("xl/_rels/workbook.xml.rels"))
    rid_map = {r.attrib["Id"]: r.attrib["Target"] for r in rels.findall(f"{{{NS_PKG_REL}}}Relationship")}
    ns = {"a": NS_MAIN, "r": NS_REL}
    expected_sheet_name = sanitize_sheet_name(EXPECTED_SOURCES_SHEET_NAME)
    for sheet in workbook.findall("a:sheets/a:sheet", ns):
        if sanitize_sheet_name(sheet.attrib.get("name", "")) == expected_sheet_name:
            rid = sheet.attrib.get(f"{{{NS_REL}}}id")
            if rid:
                target = rid_map[rid]
                if target.startswith("/"):
                    target = target.lstrip("/")
                elif not target.startswith("xl/"):
                    target = "xl/" + target
                return target, sheet.attrib.get("sheetId", "")
    raise RuntimeError("Sources sheet not found in workbook")


def read_sources_sheet(xlsx_path: Path) -> List[dict]:
    with zipfile.ZipFile(xlsx_path, "r") as zf:
        sheet_path, _ = locate_sources_sheet(zf)
        shared = []
        ns = {"a": NS_MAIN}
        if "xl/sharedStrings.xml" in zf.namelist():
            root = ET.fromstring(zf.read("xl/sharedStrings.xml"))
            for si in root.findall("a:si", ns):
                text = "".join((t.text or "") for t in si.findall(".//a:t", ns))
                shared.append(text)

        ws = ET.fromstring(zf.read(sheet_path))
        sheet_data = ws.find("a:sheetData", ns)
        if sheet_data is None:
            return []

        headers = {}
        out = []
        for row in sheet_data.findall("a:row", ns):
            ridx = int(row.attrib.get("r", "0"))
            vals = {}
            for cell in row.findall("a:c", ns):
                ref = cell.attrib.get("r", "")
                col = re.match(r"[A-Z]+", ref)
                if not col:
                    continue
                vals[col.group(0)] = get_cell_value(cell, shared, ns)
            if ridx == 1:
                headers = vals
                continue

            if not headers:
                continue

            record = {}
            any_value = False
            for idx in range(1, len(SOURCES_HEADERS) + 1):
                col = column_name(idx)
                header = headers.get(col, SOURCES_HEADERS[idx - 1])
                val = vals.get(col, "")
                record[header] = val
                if normalize_whitespace(val):
                    any_value = True
            if any_value:
                out.append(record)
    return out


def xml_cell(col_idx: int, row_idx: int, value: str) -> str:
    col = column_name(col_idx)
    ref = f"{col}{row_idx}"
    escaped = escape(sanitize_excel_value(value))
    return f'<c r="{ref}" t="inlineStr"><is><t xml:space="preserve">{escaped}</t></is></c>'


def build_sources_sheet_xml(rows: List[dict]) -> bytes:
    header = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
    body = [
        '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">',
    ]
    max_row = len(rows) + 1
    body.append(f'<dimension ref="A1:R{max_row}"/>')
    body.append('<sheetViews><sheetView workbookViewId="0"/></sheetViews>')
    body.append('<sheetFormatPr defaultRowHeight="15"/>')
    body.append('<sheetData>')

    all_rows = [OrderedDict((h, h) for h in SOURCES_HEADERS)]
    for row in rows:
        ordered = OrderedDict()
        for h in SOURCES_HEADERS:
            ordered[h] = row.get(h, "")
        all_rows.append(ordered)

    for r_idx, row in enumerate(all_rows, start=1):
        body.append(f'<row r="{r_idx}">')
        for c_idx, h in enumerate(SOURCES_HEADERS, start=1):
            body.append(xml_cell(c_idx, r_idx, row.get(h, "")))
        body.append('</row>')

    body.append('</sheetData>')
    body.append(f'<autoFilter ref="A1:R{max_row}"/>')
    body.append('</worksheet>')
    return (header + "".join(body)).encode("utf-8")


def validate_xlsx_for_replace(xlsx_path: Path) -> None:
    validate_xlsx_file(xlsx_path)


def get_sources_worksheet(workbook):
    expected_sheet_name = sanitize_sheet_name(EXPECTED_SOURCES_SHEET_NAME)
    for worksheet in workbook.worksheets:
        if sanitize_sheet_name(worksheet.title) == expected_sheet_name:
            return worksheet
    raise RuntimeError("Sources sheet not found in workbook")


def populate_sources_worksheet(worksheet, rows: List[dict]) -> None:
    if worksheet.max_row > 1:
        worksheet.delete_rows(2, worksheet.max_row - 1)

    for c_idx, header in enumerate(SOURCES_HEADERS, start=1):
        worksheet.cell(row=1, column=c_idx, value=sanitize_excel_string(header))

    for r_idx, row in enumerate(rows, start=2):
        for c_idx, header in enumerate(SOURCES_HEADERS, start=1):
            worksheet.cell(row=r_idx, column=c_idx, value=sanitize_excel_value(row.get(header, "")))

    max_row = len(rows) + 1
    worksheet.auto_filter.ref = f"A1:R{max_row}"
    if worksheet.freeze_panes == "A1":
        worksheet.freeze_panes = None


def write_xlsx_atomic(output_xlsx: Path, payload: bytes) -> None:
    ensure_parent(output_xlsx)
    tmp_output = None
    try:
        with tempfile.NamedTemporaryFile(
            "wb",
            delete=False,
            dir=str(output_xlsx.parent),
            prefix=f".{output_xlsx.stem}.",
            suffix=output_xlsx.suffix,
        ) as handle:
            handle.write(payload)
            tmp_output = Path(handle.name)
        validate_xlsx_file(tmp_output)
        tmp_output.replace(output_xlsx)
    except Exception:
        if tmp_output is not None:
            try:
                tmp_output.unlink()
            except FileNotFoundError:
                pass
        raise


def write_sources_sheet(template_xlsx: Path, output_xlsx: Path, rows: List[dict]) -> None:
    load_workbook = _load_openpyxl_workbook()
    workbook = load_workbook(template_xlsx)
    try:
        worksheet = get_sources_worksheet(workbook)
        populate_sources_worksheet(worksheet, rows)
        workbook_bytes = workbook_to_xlsx_bytes(workbook)
    finally:
        workbook.close()

    validate_xlsx_file(workbook_bytes)
    write_xlsx_atomic(output_xlsx, workbook_bytes)


def normalize_record(raw: dict) -> dict:
    row = {k: raw.get(k, "") for k in CANONICAL_KEYS if k != "bib"}
    row["bib"] = raw.get("bib", {})
    row["source"] = normalize_whitespace(row.get("source", ""))
    row["citekey"] = normalize_whitespace(row.get("citekey", ""))
    row["section"] = normalize_whitespace(row.get("section", ""))
    row["aggsource"] = normalize_whitespace(row.get("aggsource", ""))
    row["legend"] = normalize_whitespace(row.get("legend", ""))
    row["link"] = normalize_whitespace(row.get("link", ""))
    row["ref_link"] = normalize_whitespace(row.get("ref_link", ""))
    return row


def record_to_sources_sheet_row(record: dict) -> dict:
    return {
        "Section": record.get("section", ""),
        "AggSource": record.get("aggsource", ""),
        "Legend": record.get("legend", ""),
        "Source": record.get("source", ""),
        "Data_Type": record.get("data_type", ""),
        "Link": record.get("link", ""),
        "Ref_link": record.get("ref_link", ""),
        "Citekey": record.get("citekey", ""),
        "Inclusion_in_Warehouse": record.get("inclusion_in_warehouse", ""),
        "Multigeo_Reference": record.get("multigeo_reference", ""),
        "Metadata": record.get("metadata", ""),
        "Metadatalink": record.get("metadatalink", ""),
        "QcommentsforTA": record.get("qcommentsforta", ""),
        "TAreply": record.get("tareply", ""),
        "TAcomments": record.get("tacomments", ""),
        "ARJcomments": record.get("arjcomments", ""),
        "ARJreplies": record.get("arjreplies", ""),
        "SeeAggSourcelisthere": record.get("seeaggsourcelisthere", ""),
    }
