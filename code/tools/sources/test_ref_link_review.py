import importlib.util
import json
import pathlib
import sys
import tempfile
import unittest
from unittest import mock

from common import DEFAULT_REGISTRY


def load_ref_link_review_module():
    path = pathlib.Path("code/tools/sources/ref_link_review.py").resolve()
    sys.path.insert(0, str(path.parent))
    spec = importlib.util.spec_from_file_location("ref_link_review", path)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


def make_show_payload(entry_key, bibbaseid):
    entry = {
        "key": entry_key,
        "bibbaseid": bibbaseid,
        "bibtex": f"@article{{{entry_key},\n  title = {{Example Title}},\n  year = {{2024}}\n}}\n",
        "title": "Example Title",
        "year": "2024",
        "author": [{"lastnames": ["Example"], "firstnames": ["Eve"], "suffixes": [], "propositions": []}],
    }
    inner = f'var bibbase = {{data: {json.dumps([entry])}, groups: []}};'
    outer = {"data": inner}
    return f"var bibbase_data = {json.dumps(outer)}; document.write(bibbase_data.data);"


class RefLinkReviewScanTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.mod = load_ref_link_review_module()

    def test_blank_exact_citekey_match_is_ready_to_apply(self):
        registry = {
            "config": {"bib_output": "documentation/BibTeX files/GCWealthProject_DataSourcesLibrary.bib"},
            "records": [
                {
                    "id": "src-example",
                    "source": "Example2024",
                    "citekey": "Example2024",
                    "ref_link": "",
                    "link": "https://example.org/source",
                    "bib": {"title": "Example Title", "author": "Example, Eve", "year": "2024"},
                }
            ],
        }
        scan = self.mod.scan_registry_ref_links(
            registry,
            show_payload_text=make_show_payload("Example2024", "example-exampletitle-2024"),
            hosted_bib_text="@article{Example2024,}\n",
            local_bib_text="@article{Example2024,}\n",
        )
        self.assertEqual(scan["summary"]["ready_to_apply"], 1)
        proposal = scan["ready_to_apply"][0]
        self.assertEqual(proposal["record_id"], "src-example")
        self.assertTrue(proposal["selected"])
        self.assertEqual(
            proposal["proposed_ref_link"],
            "https://bibbase.org/network/publication/example-exampletitle-2024",
        )
        self.assertIn("blank ref_link, exact citekey match", proposal["reason_flags"])

    def test_existing_ref_link_mismatch_stays_in_needs_review(self):
        registry = {
            "config": {"bib_output": "documentation/BibTeX files/GCWealthProject_DataSourcesLibrary.bib"},
            "records": [
                {
                    "id": "src-example",
                    "source": "Example2024",
                    "citekey": "Example2024",
                    "ref_link": "https://bibbase.org/network/publication/example-old-2023",
                    "link": "https://example.org/source",
                    "bib": {"title": "Example Title", "author": "Example, Eve", "year": "2024"},
                }
            ],
        }
        scan = self.mod.scan_registry_ref_links(
            registry,
            show_payload_text=make_show_payload("Example2024", "example-new-2024"),
            hosted_bib_text="@article{Example2024,}\n",
            local_bib_text="@article{Example2024,}\n",
        )
        self.assertEqual(scan["summary"]["ready_to_apply"], 0)
        self.assertEqual(scan["summary"]["needs_review"], 1)
        proposal = scan["needs_review"][0]
        self.assertEqual(proposal["confidence"], "medium")
        self.assertIn("stored ref_link differs from live BibBase", proposal["reason_flags"])
        self.assertFalse(proposal["selected"])

    def test_hosted_bibbase_drift_downgrades_exact_match_to_needs_review(self):
        registry = {
            "config": {"bib_output": "documentation/BibTeX files/GCWealthProject_DataSourcesLibrary.bib"},
            "records": [
                {
                    "id": "src-example",
                    "source": "Example2024",
                    "citekey": "Example2024",
                    "ref_link": "",
                    "link": "https://example.org/source",
                    "bib": {"title": "Example Title", "author": "Example, Eve", "year": "2024"},
                }
            ],
        }
        scan = self.mod.scan_registry_ref_links(
            registry,
            show_payload_text=make_show_payload("Example2024", "example-new-2024"),
            hosted_bib_text="@article{OldKey2023,}\n",
            local_bib_text="@article{Example2024,}\n",
        )
        self.assertTrue(scan["scan_metadata"]["hosted_bib_is_stale"])
        self.assertEqual(scan["summary"]["ready_to_apply"], 0)
        self.assertEqual(scan["summary"]["needs_review"], 1)
        self.assertIn("hosted BibBase may be stale", scan["needs_review"][0]["reason_flags"])

    def test_scan_registry_ref_links_reports_progress_and_identity_fields(self):
        registry = {
            "config": {"bib_output": "documentation/BibTeX files/GCWealthProject_DataSourcesLibrary.bib"},
            "records": [
                {
                    "id": "src-example",
                    "source": "Example2024",
                    "citekey": "Example2024",
                    "legend": "Example (2024)",
                    "ref_link": "",
                    "link": "https://example.org/source",
                    "bib": {"title": "Example Title", "author": "Example, Eve", "year": "2024"},
                }
            ],
        }
        progress = []

        scan = self.mod.scan_registry_ref_links(
            registry,
            show_payload_text=make_show_payload("Example2024", "example-exampletitle-2024"),
            hosted_bib_text="@article{Example2024,}\n",
            local_bib_text="@article{Example2024,}\n",
            progress_callback=lambda checked, total, record_id: progress.append((checked, total, record_id)),
        )

        self.assertEqual(progress, [(1, 1, "src-example")])
        proposal = scan["ready_to_apply"][0]
        self.assertEqual(proposal["title"], "Example Title")
        self.assertEqual(proposal["author"], "Example, Eve")
        self.assertEqual(proposal["year"], "2024")
        self.assertEqual(proposal["legend"], "Example (2024)")

    def test_apply_selected_ref_links_updates_only_blank_records(self):
        registry = {
            "records": [
                {"id": "src-a", "citekey": "A2024", "ref_link": "", "source": "A2024", "bib": {"title": "A", "year": "2024"}},
                {
                    "id": "src-b",
                    "citekey": "B2024",
                    "ref_link": "https://bibbase.org/network/publication/b-old",
                    "source": "B2024",
                    "bib": {"title": "B", "year": "2024"},
                },
            ]
        }
        proposals = [
            {
                "proposal_id": "p-a",
                "record_id": "src-a",
                "current_ref_link": "",
                "proposed_ref_link": "https://bibbase.org/network/publication/a-new",
                "selected": True,
            },
            {
                "proposal_id": "p-b",
                "record_id": "src-b",
                "current_ref_link": "https://bibbase.org/network/publication/b-old",
                "proposed_ref_link": "https://bibbase.org/network/publication/b-new",
                "selected": True,
            },
        ]
        out = self.mod.apply_selected_ref_links(registry, proposals, {"p-a", "p-b"})
        self.assertEqual(out["applied_ids"], ["src-a"])
        self.assertEqual(out["skipped_ids"], ["src-b"])
        self.assertEqual(registry["records"][0]["ref_link"], "https://bibbase.org/network/publication/a-new")
        self.assertEqual(registry["records"][1]["ref_link"], "https://bibbase.org/network/publication/b-old")

    def test_apply_selected_ref_links_skips_stale_proposals(self):
        registry = {
            "records": [
                {
                    "id": "src-a",
                    "citekey": "A2024",
                    "ref_link": "https://bibbase.org/network/publication/already-set",
                    "source": "A2024",
                    "bib": {"title": "A", "year": "2024"},
                }
            ]
        }
        proposals = [
            {
                "proposal_id": "p-a",
                "record_id": "src-a",
                "current_ref_link": "",
                "proposed_ref_link": "https://bibbase.org/network/publication/a-new",
                "selected": True,
            }
        ]
        out = self.mod.apply_selected_ref_links(registry, proposals, {"p-a"})
        self.assertEqual(out["applied_ids"], [])
        self.assertEqual(out["stale_ids"], ["src-a"])

    def test_apply_selected_ref_links_uses_valid_override_url(self):
        registry = {
            "records": [
                {"id": "src-a", "citekey": "A2024", "ref_link": "", "source": "A2024", "bib": {"title": "A", "year": "2024"}}
            ]
        }
        proposals = [
            {
                "proposal_id": "p-a",
                "record_id": "src-a",
                "current_ref_link": "",
                "proposed_ref_link": "https://bibbase.org/network/publication/a-new",
                "selected": True,
            }
        ]
        out = self.mod.apply_selected_ref_links(
            registry,
            proposals,
            {"p-a"},
            overrides={"p-a": "https://override.example/ref-link"},
        )
        self.assertEqual(out["applied_ids"], ["src-a"])
        self.assertEqual(registry["records"][0]["ref_link"], "https://override.example/ref-link")

    def test_apply_selected_ref_links_rejects_invalid_override_url(self):
        registry = {
            "records": [
                {"id": "src-a", "citekey": "A2024", "ref_link": "", "source": "A2024", "bib": {"title": "A", "year": "2024"}}
            ]
        }
        proposals = [
            {
                "proposal_id": "p-a",
                "record_id": "src-a",
                "current_ref_link": "",
                "proposed_ref_link": "https://bibbase.org/network/publication/a-new",
                "selected": True,
            }
        ]
        out = self.mod.apply_selected_ref_links(
            registry,
            proposals,
            {"p-a"},
            overrides={"p-a": "not-a-valid-url"},
        )
        self.assertEqual(out["applied_ids"], [])
        self.assertEqual(out["invalid_override_ids"], ["p-a"])
        self.assertEqual(registry["records"][0]["ref_link"], "")

    def test_default_registry_exposes_bibbase_review_config(self):
        config = DEFAULT_REGISTRY["config"]
        self.assertIn("bibbase_profile_source_url", config)
        self.assertIn("bibbase_timeout_seconds", config)

    def test_fetch_and_scan_registry_ref_links_uses_profile_source_url(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            local_bib_path = pathlib.Path(tmpdir) / "local.bib"
            local_bib_path.write_text("@article{Example2024,}\n", encoding="utf-8")
            profile_source_url = "https://bibbase.org/f/example/GCWealthProject_DataSourcesLibrary.bib"
            registry = {
                "config": {
                    "bib_output": str(local_bib_path),
                    "bibbase_profile_source_url": profile_source_url,
                    "bibbase_timeout_seconds": 7,
                },
                "records": [
                    {
                        "id": "src-example",
                        "source": "Example2024",
                        "citekey": "Example2024",
                        "ref_link": "",
                        "link": "https://example.org/source",
                        "bib": {"title": "Example Title", "author": "Example, Eve", "year": "2024"},
                    }
                ],
            }
            show_url = self.mod.build_bibbase_show_url(profile_source_url)
            responses = {
                profile_source_url: "@article{Example2024,}\n",
                show_url: make_show_payload("Example2024", "example-exampletitle-2024"),
            }

            def fake_fetch(url, timeout_seconds):
                self.assertEqual(timeout_seconds, 7)
                return {"text": responses[url], "method": "fake"}

            out = self.mod.fetch_and_scan_registry_ref_links(registry, fetch_text=fake_fetch)
            self.assertTrue(out["ok"])
            self.assertEqual(out["summary"]["ready_to_apply"], 1)
            self.assertEqual(out["scan_metadata"]["profile_source_url"], profile_source_url)
            self.assertEqual(out["scan_metadata"]["fetch_method"], "fake")

    def test_fetch_and_scan_registry_ref_links_uses_session_benchmark_override(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            local_bib_path = pathlib.Path(tmpdir) / "local.bib"
            local_bib_path.write_text("@article{Example2024,}\n", encoding="utf-8")
            default_source_url = "https://bibbase.org/f/default/GCWealthProject_DataSourcesLibrary.bib"
            override_source_url = "https://bibbase.org/f/session/GCWealthProject_DataSourcesLibrary.bib"
            registry = {
                "config": {
                    "bib_output": str(local_bib_path),
                    "bibbase_profile_source_url": default_source_url,
                    "bibbase_timeout_seconds": 7,
                },
                "records": [
                    {
                        "id": "src-example",
                        "source": "Example2024",
                        "citekey": "Example2024",
                        "ref_link": "",
                        "link": "https://example.org/source",
                        "bib": {"title": "Example Title", "author": "Example, Eve", "year": "2024"},
                    }
                ],
            }
            show_url = self.mod.build_bibbase_show_url(override_source_url)
            seen_urls = []
            responses = {
                override_source_url: "@article{Example2024,}\n",
                show_url: make_show_payload("Example2024", "example-exampletitle-2024"),
            }

            def fake_fetch(url, timeout_seconds):
                seen_urls.append((url, timeout_seconds))
                return {"text": responses[url], "method": "fake"}

            out = self.mod.fetch_and_scan_registry_ref_links(
                registry,
                fetch_text=fake_fetch,
                benchmark_url_override=override_source_url,
            )

            self.assertTrue(out["ok"])
            self.assertEqual(seen_urls[0], (override_source_url, 7))
            self.assertEqual(out["scan_metadata"]["profile_source_url"], override_source_url)

    def test_fetch_and_scan_registry_ref_links_rejects_invalid_session_benchmark_override(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            local_bib_path = pathlib.Path(tmpdir) / "local.bib"
            local_bib_path.write_text("@article{Example2024,}\n", encoding="utf-8")
            registry = {
                "config": {
                    "bib_output": str(local_bib_path),
                    "bibbase_profile_source_url": "https://bibbase.org/f/default/GCWealthProject_DataSourcesLibrary.bib",
                    "bibbase_timeout_seconds": 7,
                },
                "records": [],
            }

            out = self.mod.fetch_and_scan_registry_ref_links(
                registry,
                fetch_text=lambda *_args, **_kwargs: self.fail("fetch_text should not be called"),
                benchmark_url_override="not-a-url",
            )

            self.assertFalse(out["ok"])
            self.assertEqual(out["status"], "invalid_benchmark_url")

    def test_scan_registry_ref_links_includes_row_level_status(self):
        registry = {
            "config": {"bib_output": "documentation/BibTeX files/GCWealthProject_DataSourcesLibrary.bib"},
            "records": [
                {
                    "id": "src-example",
                    "source": "Example2024",
                    "citekey": "Example2024",
                    "ref_link": "",
                    "link": "https://example.org/source",
                    "bib": {"title": "Example Title", "author": "Example, Eve", "year": "2024"},
                }
            ],
        }
        scan = self.mod.scan_registry_ref_links(
            registry,
            show_payload_text=make_show_payload("Example2024", "example-exampletitle-2024"),
            hosted_bib_text="@article{Example2024,}\n",
            local_bib_text="@article{Example2024,}\n",
        )
        self.assertEqual(scan["ready_to_apply"][0]["status"], "ready_to_apply")

    def test_apply_selected_ref_links_reports_missing_proposals_as_stale(self):
        registry = {
            "records": [
                {"id": "src-a", "citekey": "A2024", "ref_link": "", "source": "A2024", "bib": {"title": "A", "year": "2024"}}
            ]
        }
        out = self.mod.apply_selected_ref_links(registry, [], {"missing-proposal"})
        self.assertEqual(out["applied_ids"], [])
        self.assertEqual(out["missing_proposal_ids"], ["missing-proposal"])

    def test_fetch_text_falls_back_to_curl_when_urllib_fails(self):
        class FakeCompletedProcess:
            stdout = b"fetched-via-curl"
            stderr = b""

        with mock.patch.object(self.mod, "urlopen", side_effect=RuntimeError("ssl boom")), \
             mock.patch.object(self.mod.shutil, "which", return_value="/usr/bin/curl"), \
             mock.patch.object(self.mod.subprocess, "run", return_value=FakeCompletedProcess()):
            out = self.mod._fetch_text("https://example.org/data.bib", 9)
        self.assertEqual(out["text"], "fetched-via-curl")
        self.assertEqual(out["method"], "curl-system-trust")


if __name__ == "__main__":
    unittest.main()
