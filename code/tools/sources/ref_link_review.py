import hashlib
import json
import re
import shutil
import subprocess
from pathlib import Path
from typing import Callable, Dict, List, Optional
from urllib.parse import urlencode
from urllib.request import Request, urlopen

from common import normalize_url, normalize_whitespace, now_utc
from source_paths import DEFAULT_DATA_BIB_PATH, DEFAULT_REGISTRY_PATH


OUTER_PAYLOAD_RE = re.compile(r"var bibbase_data = (.*); document\.write\(bibbase_data\.data\);?\s*$", re.S)
RECOVER_CITEKEY_RE = re.compile(r"^@\w+\{([^,]+),")
HTTP_URL_RE = re.compile(r"^https?://", re.IGNORECASE)


def parse_bibbase_show_payload(show_payload_text: str) -> List[dict]:
    match = OUTER_PAYLOAD_RE.search(show_payload_text)
    if not match:
        raise ValueError("Could not parse BibBase show payload.")
    outer = json.loads(match.group(1))
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
    if end is None:
        raise ValueError("Could not find BibBase entry array.")
    return json.loads(html[start:end])


def _recover_citekey(entry: dict) -> str:
    bibtex = normalize_whitespace((entry.get("bibtex") or "").replace("\n", " "))
    match = RECOVER_CITEKEY_RE.match(bibtex)
    if match:
        return normalize_whitespace(match.group(1))
    return normalize_whitespace(entry.get("key", ""))


def _proposal_id(record_id: str, proposed_ref_link: str) -> str:
    return hashlib.sha256(f"{record_id}|{proposed_ref_link}".encode("utf-8")).hexdigest()


def build_bibbase_show_url(profile_source_url: str) -> str:
    return "https://bibbase.org/show?" + urlencode(
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


def _fetch_text(reference_url: str, timeout_seconds: int) -> dict:
    req = Request(reference_url, headers={"User-Agent": "SourceRegistryUI/1.0"})
    try:
        with urlopen(req, timeout=timeout_seconds) as response:
            text = response.read().decode("utf-8", errors="replace")
        return {"text": text, "method": "python-urllib"}
    except Exception as exc:  # pylint: disable=broad-except
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
                raise RuntimeError(f"{exc}. curl fallback failed: {curl_exc}") from curl_exc
        raise


def fetch_and_scan_registry_ref_links(
    registry: dict,
    fetch_text=None,
    progress_callback: Optional[Callable[[int, int, str], None]] = None,
    stage_callback: Optional[Callable[[str, str], None]] = None,
    benchmark_url_override: str = "",
) -> dict:
    cfg = registry.get("config", {}) or {}
    profile_source_url = normalize_whitespace(cfg.get("bibbase_profile_source_url", ""))
    benchmark_source_url = normalize_whitespace(benchmark_url_override or profile_source_url)
    timeout_seconds = int(cfg.get("bibbase_timeout_seconds", 20) or 20)
    if benchmark_url_override and not HTTP_URL_RE.match(benchmark_source_url):
        return {
            "ok": False,
            "status": "invalid_benchmark_url",
            "message": "Benchmark URL must start with http:// or https://.",
        }
    if not benchmark_source_url:
        return {
            "ok": False,
            "status": "not_configured",
            "message": f"bibbase_profile_source_url is not configured in {DEFAULT_REGISTRY_PATH}.",
        }
    local_bib_path = Path(cfg.get("bib_output", DEFAULT_DATA_BIB_PATH))
    local_bib_text = local_bib_path.read_text(encoding="utf-8")
    fetch_impl = fetch_text or _fetch_text
    if stage_callback:
        stage_callback("fetching_live_bibbase", "Fetching live BibBase...")
    hosted_bib = fetch_impl(benchmark_source_url, timeout_seconds)
    show_payload = fetch_impl(build_bibbase_show_url(benchmark_source_url), timeout_seconds)
    if stage_callback:
        total = len(registry.get("records", []))
        stage_callback("comparing_registry", f"Comparing registry records (0 / {total})")
    scan = scan_registry_ref_links(
        registry,
        show_payload["text"],
        hosted_bib["text"],
        local_bib_text,
        progress_callback=progress_callback,
    )
    scan["scan_metadata"]["profile_source_url"] = benchmark_source_url
    scan["scan_metadata"]["fetch_method"] = hosted_bib.get("method", "")
    return {"ok": True, "status": "ok", **scan}


def apply_selected_ref_links(registry: dict, proposals: List[dict], selected_ids, overrides=None) -> dict:
    proposal_map = {proposal["proposal_id"]: proposal for proposal in proposals if proposal.get("proposal_id")}
    records_by_id = {record.get("id", ""): record for record in registry.get("records", [])}
    overrides = overrides or {}
    applied_ids = []
    skipped_ids = []
    stale_ids = []
    missing_proposal_ids = []
    invalid_override_ids = []
    for proposal_id in selected_ids:
        proposal = proposal_map.get(proposal_id)
        if not proposal:
            missing_proposal_ids.append(proposal_id)
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
        override_value = normalize_whitespace(overrides.get(proposal_id, ""))
        if override_value:
            if not HTTP_URL_RE.match(override_value):
                invalid_override_ids.append(proposal_id)
                continue
            next_ref_link = normalize_url(override_value)
        else:
            next_ref_link = proposal["proposed_ref_link"]
        record["ref_link"] = next_ref_link
        applied_ids.append(record["id"])
    return {
        "applied_ids": sorted(applied_ids),
        "skipped_ids": sorted(skipped_ids),
        "stale_ids": sorted(stale_ids),
        "missing_proposal_ids": sorted(missing_proposal_ids),
        "invalid_override_ids": sorted(invalid_override_ids),
    }


def _proposal_row(
    record: dict,
    current: str,
    proposed: str,
    selected: bool,
    confidence: str,
    reason_flags: List[str],
    status: str,
) -> dict:
    bib = record.get("bib", {}) or {}
    return {
        "proposal_id": _proposal_id(record["id"], proposed),
        "record_id": record["id"],
        "status": status,
        "citekey": normalize_whitespace(record.get("citekey", "")),
        "legend": normalize_whitespace(record.get("legend", "")),
        "title": normalize_whitespace(bib.get("title", "")),
        "author": normalize_whitespace(bib.get("author", "")),
        "year": normalize_whitespace(str(bib.get("year", ""))),
        "current_ref_link": current,
        "proposed_ref_link": proposed,
        "selected": selected,
        "confidence": confidence,
        "reason_flags": reason_flags,
    }


def scan_registry_ref_links(
    registry: dict,
    show_payload_text: str,
    hosted_bib_text: str,
    local_bib_text: str,
    progress_callback: Optional[Callable[[int, int, str], None]] = None,
) -> dict:
    hosted_bib_is_stale = hosted_bib_text != local_bib_text
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
    records = list(registry.get("records", []))
    total_records = len(records)
    for idx, record in enumerate(records, start=1):
        citekey = normalize_whitespace(record.get("citekey", ""))
        current = normalize_url(record.get("ref_link", ""))
        candidates = by_citekey.get(citekey, [])
        if not candidates:
            if progress_callback:
                progress_callback(idx, total_records, record.get("id", ""))
            continue
        if current and current != candidates[0]:
            reason_flags = ["stored ref_link differs from live BibBase"]
            if hosted_bib_is_stale:
                reason_flags.append("hosted BibBase may be stale")
            needs_review.append(
                _proposal_row(
                    record,
                    current,
                    candidates[0],
                    False,
                    "medium",
                    reason_flags,
                    "needs_review",
                )
            )
            if progress_callback:
                progress_callback(idx, total_records, record.get("id", ""))
            continue
        if not current and len(candidates) == 1:
            reason_flags = ["blank ref_link, exact citekey match"]
            bucket = ready_to_apply
            selected = True
            confidence = "high"
            if hosted_bib_is_stale:
                reason_flags.append("hosted BibBase may be stale")
                bucket = needs_review
                selected = False
                confidence = "medium"
            bucket.append(
                _proposal_row(
                    record,
                    current,
                    candidates[0],
                    selected,
                    confidence,
                    reason_flags,
                    "ready_to_apply" if bucket is ready_to_apply else "needs_review",
                )
            )
        if progress_callback:
            progress_callback(idx, total_records, record.get("id", ""))

    return {
        "summary": {
            "ready_to_apply": len(ready_to_apply),
            "needs_review": len(needs_review),
            "dismissed": 0,
        },
        "ready_to_apply": ready_to_apply,
        "needs_review": needs_review,
        "scan_metadata": {
            "compared_at": now_utc(),
            "hosted_bib_matches_local": not hosted_bib_is_stale,
            "hosted_bib_is_stale": hosted_bib_is_stale,
        },
    }
