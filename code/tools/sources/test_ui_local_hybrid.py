import importlib.util
import pathlib
import sys
import tempfile
import unittest
from unittest import mock

SOURCE_DIR = pathlib.Path("code/tools/sources").resolve()
if str(SOURCE_DIR) not in sys.path:
    sys.path.insert(0, str(SOURCE_DIR))


def load_module(name, relative_path):
    path = pathlib.Path(relative_path).resolve()
    sys.path.insert(0, str(path.parent))
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


class HybridSourceCitekeyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.ui = load_module("ui_local", "code/tools/sources/ui_local.py")
        cls.build = load_module("build_sources_artifacts", "code/tools/sources/build_sources_artifacts.py")
        cls.validate = load_module("validate_sources", "code/tools/sources/validate_sources.py")

    def test_add_research_candidate_uses_citekey_without_source(self):
        candidate = self.ui.make_candidate(
            {
                "mode": "add",
                "record": {
                    "source_key": "Example2026",
                    "link": "https://example.test/source",
                    "bib": {"entry_type": "misc", "title": "Example", "author": "Example", "year": "2026"},
                },
            }
        )

        self.assertEqual(candidate["source"], "")
        self.assertEqual(candidate["citekey"], "Example2026")

    def test_add_data_source_candidate_keeps_distinct_source_and_citekey(self):
        candidate = self.ui.make_candidate(
            {
                "mode": "add",
                "record": {
                    "is_data_source": True,
                    "section": "Wealth Inequality",
                    "source": "Example_ineq",
                    "citekey": "ExampleBibliography2026",
                    "link": "https://example.test/source",
                    "bib": {
                        "entry_type": "misc",
                        "title": "Example",
                        "author": "Example",
                        "year": "2026",
                    },
                },
            }
        )

        self.assertEqual(candidate["source"], "Example_ineq")
        self.assertEqual(candidate["citekey"], "ExampleBibliography2026")
        self.assertEqual(candidate["bib"]["keywords"], "Data Sources: Wealth Inequality")

    def test_add_candidate_can_infer_data_source_from_pasted_canonical_keyword(self):
        candidate = self.ui.make_candidate(
            {
                "mode": "add",
                "record": {
                    "source_key": "ExampleData",
                    "link": "https://example.test/source",
                    "bib": {
                        "entry_type": "misc",
                        "title": "Example",
                        "author": "Example",
                        "year": "2026",
                        "keywords": "Data Sources: Wealth Topography,Wealth Taxation",
                    },
                },
            }
        )

        self.assertTrue(candidate["is_data_source"])
        self.assertEqual(candidate["source"], "ExampleData")
        self.assertEqual(candidate["section"], "Wealth Topography")
        self.assertEqual(candidate["bib"]["keywords"], "Data Sources: Wealth Topography,Wealth Taxation")

    def test_edit_candidate_preserves_legacy_source_citekey_split(self):
        candidate = self.ui.make_candidate(
            {
                "mode": "edit",
                "record": {
                    "is_data_source": True,
                    "section": "Wealth Inequality",
                    "source": "DHS_ineq",
                    "citekey": "dhs_various",
                    "link": "https://dhsprogram.com/data/",
                    "bib": {
                        "entry_type": "misc",
                        "title": "DHS",
                        "author": "Unknown",
                        "year": "1900",
                        "keywords": "Data Sources: Wealth Inequality",
                    },
                },
            }
        )

        self.assertEqual(candidate["source"], "DHS_ineq")
        self.assertEqual(candidate["citekey"], "dhs_various")

    def test_unchecked_data_source_candidate_strips_data_source_fields_and_preserves_research_keywords(self):
        candidate = self.ui.make_candidate(
            {
                "mode": "add",
                "record": {
                    "is_data_source": False,
                    "section": "Taxes on Wealth",
                    "aggsource": "Official statistics",
                    "source_key": "Research2026",
                    "legend": "Research (2026)",
                    "link": "https://example.test/research",
                    "ref_link": "https://bibbase.org/network/publication/example",
                    "metadata": "Data-source-only note",
                    "bib": {
                        "entry_type": "article",
                        "title": "Research paper",
                        "author": "Researcher",
                        "year": "2026",
                        "keywords": "Data Sources: Taxes on Wealth,Wealth Taxation",
                    },
                },
            }
        )

        self.assertFalse(candidate["is_data_source"])
        self.assertEqual(candidate["section"], "")
        self.assertEqual(candidate["aggsource"], "")
        self.assertEqual(candidate["ref_link"], "")
        self.assertEqual(candidate["metadata"], "")
        self.assertEqual(candidate["bib"]["keywords"], "Wealth Taxation")

    def test_checked_data_source_candidate_maps_section_to_canonical_keyword(self):
        candidate = self.ui.make_candidate(
            {
                "mode": "add",
                "record": {
                    "is_data_source": True,
                    "section": "Inheritance Trends",
                    "aggsource": "Official statistics",
                    "source_key": "Inheritance2026",
                    "legend": "Inheritance (2026)",
                    "link": "https://example.test/inheritance",
                    "bib": {
                        "entry_type": "misc",
                        "title": "Inheritance data",
                        "author": "Archive",
                        "year": "2026",
                        "keywords": "Estate Tax,Data Sources: Taxes on Wealth",
                    },
                },
            }
        )

        self.assertEqual(candidate["bib"]["keywords"], "Data Sources: Inheritance Trends")

    def test_validate_edit_allows_distinct_source_and_citekey_without_warning(self):
        record = {
            "id": "src-dhs-ineq",
            "section": "Wealth Inequality",
            "aggsource": "Cross-national official statistics",
            "is_data_source": True,
            "legend": "DHS",
            "source": "DHS_ineq",
            "citekey": "dhs_various",
            "link": "https://dhsprogram.com/data/",
            "bib": {
                "entry_type": "misc",
                "title": "DHS",
                "author": "Unknown",
                "year": "1900",
                "keywords": "Data Sources: Wealth Inequality",
            },
        }
        candidate = dict(record)

        out = self.ui.validate_candidate([record], candidate, mode="edit", target_id="src-dhs-ineq")

        self.assertEqual(out["errors"], [])
        self.assertEqual(out["warnings"], [])

    def test_apply_edit_preserves_legacy_citekey_for_non_key_change(self):
        registry = {
            "records": [
                {
                    "id": "src-dhs-ineq",
                    "section": "Wealth Inequality",
                    "aggsource": "Cross-national official statistics",
                    "legend": "DHS",
                    "source": "DHS_ineq",
                    "citekey": "dhs_various",
                    "link": "https://dhsprogram.com/data/",
                    "bib": {"entry_type": "misc", "title": "DHS", "author": "Unknown", "year": "1900"},
                }
            ]
        }
        payload = {
            "mode": "edit",
            "target": "DHS_ineq",
            "editor_name": "Matteo",
            "record": {
                "section": "Wealth Inequality",
                "aggsource": "Cross-national official survey data",
                "legend": "DHS",
                "source": "DHS_ineq",
                "citekey": "dhs_various",
                "link": "https://dhsprogram.com/data/",
                "bib": {"entry_type": "misc", "title": "DHS", "author": "Unknown", "year": "1900"},
            },
        }
        with tempfile.TemporaryDirectory() as tmpdir:
            aliases = pathlib.Path(tmpdir) / "aliases.json"
            changelog = pathlib.Path(tmpdir) / "change_log.json"
            aliases.write_text('{"aliases": []}\n', encoding="utf-8")
            changelog.write_text('{"changes": []}\n', encoding="utf-8")

            self.ui.apply_payload(registry, payload, aliases, changelog)

        record = registry["records"][0]
        self.assertEqual(record["aggsource"], "Cross-national official survey data")
        self.assertEqual(record["source"], "DHS_ineq")
        self.assertEqual(record["citekey"], "dhs_various")

    def test_artifact_check_skips_edited_record_current_citekey(self):
        record = {
            "id": "src-dhs-ineq",
            "source": "DHS_ineq",
            "citekey": "dhs_various",
            "link": "https://dhsprogram.com/data/",
            "bib": {
                "entry_type": "misc",
                "title": "Demographic and Health Surveys (own estimates)",
                "author": "Unknown",
                "year": "1900",
                "url": "https://dhsprogram.com/data/",
            },
        }
        with tempfile.TemporaryDirectory() as tmpdir:
            bib_path = pathlib.Path(tmpdir) / "data.bib"
            bib_path.write_text(
                "@misc{dhs_various,\n"
                "  title = {Demographic and Health Surveys (own estimates)},\n"
                "  author = {Unknown},\n"
                "  year = {1900},\n"
                "  url = {https://dhsprogram.com/data/}\n"
                "}\n",
                encoding="utf-8",
            )
            registry = {"config": {"digital_bib_output": str(bib_path)}, "records": [record]}

            out = self.ui.validate_candidate_against_artifacts(registry, record, mode="edit", target="DHS_ineq")

        self.assertEqual(out["errors"], [])

    def test_shared_citekey_group_allows_duplicate_citekey_validation(self):
        existing = {
            "id": "src-a",
            "section": "Wealth Topography",
            "source": "A",
            "citekey": "SharedKey",
            "shared_citekey_group": "shared-key",
            "link": "https://example.test/shared",
            "bib": {
                "entry_type": "misc",
                "title": "Shared",
                "author": "A",
                "year": "2026",
                "keywords": "Data Sources: Wealth Topography",
            },
        }
        candidate = {
            "id": "src-b",
            "section": "Wealth Topography",
            "aggsource": "Official statistics",
            "is_data_source": True,
            "legend": "B",
            "source": "B",
            "citekey": "SharedKey",
            "shared_citekey_group": "shared-key",
            "link": "https://example.test/shared",
            "bib": {
                "entry_type": "misc",
                "title": "Shared",
                "author": "B",
                "year": "2026",
                "keywords": "Data Sources: Wealth Topography",
            },
        }

        out = self.ui.validate_candidate([existing], candidate, mode="edit", target_id="src-b")

        self.assertEqual(out["errors"], [])
        self.assertTrue(any("Shared citekey marked intentional" in warn for warn in out["warnings"]))

    def test_maintenance_health_classifies_marked_shared_citekey(self):
        registry = {
            "config": {"digital_bib_output": "/tmp/missing-data.bib"},
            "records": [
                {"id": "src-a", "source": "A", "citekey": "SharedKey", "shared_citekey_group": "g", "bib": {}},
                {"id": "src-b", "source": "B", "citekey": "SharedKey", "shared_citekey_group": "g", "bib": {}},
            ],
        }

        with mock.patch.object(self.ui, "generated_artifact_drift", return_value={"stale_artifact_paths": [], "errors": []}):
            health = self.ui.build_maintenance_health(registry, pathlib.Path("code/tools/metadata/sources/sources.yaml"))
        duplicate = [issue for issue in health["issues"] if issue.get("type") == "duplicate_citekey"]

        self.assertEqual(len(duplicate), 1)
        self.assertEqual(duplicate[0]["severity"], "intentional")

    def test_bulk_label_preview_matches_exact_normalized_label(self):
        registry = {
            "records": [
                {
                    "id": "src-a",
                    "section": " Wealth Topography ",
                    "source": "A",
                    "citekey": "A",
                    "legend": "A",
                    "bib": {"keywords": "Data Sources: Wealth Topography"},
                },
                {
                    "id": "src-b",
                    "section": "Wealth Topography",
                    "source": "B",
                    "citekey": "B",
                    "legend": "B",
                    "bib": {"keywords": "Custom,Data Sources: Wealth Topography"},
                },
                {
                    "id": "src-c",
                    "section": "Taxes on Wealth",
                    "source": "C",
                    "citekey": "C",
                    "legend": "C",
                    "bib": {"keywords": "Data Sources: Taxes on Wealth"},
                },
            ]
        }

        out = self.ui.bulk_label_preview(registry, "section", "Wealth Topography", "Supplementary Variables")

        self.assertEqual(out["total_matches"], 2)
        self.assertEqual([row["id"] for row in out["records"]], ["src-a", "src-b"])
        self.assertEqual(out["keyword_mirror_updates"], 2)
        self.assertTrue(out["records"][0]["keyword_mirror_update"])
        self.assertTrue(out["records"][1]["keyword_mirror_update"])
        self.assertEqual(out["records"][1]["keywords_after"], "Data Sources: Supplementary Variables,Custom")

    def test_bulk_label_apply_updates_selected_records_and_one_history_entry(self):
        registry = {
            "records": [
                {"id": "src-a", "data_type": "Wealth Survey", "source": "A", "citekey": "A", "bib": {}},
                {"id": "src-b", "data_type": "Wealth Survey", "source": "B", "citekey": "B", "bib": {}},
                {"id": "src-c", "data_type": "Other", "source": "C", "citekey": "C", "bib": {}},
            ]
        }
        with tempfile.TemporaryDirectory() as tmpdir:
            changelog = pathlib.Path(tmpdir) / "change_log.json"
            changelog.write_text('{"changes": []}\n', encoding="utf-8")

            out = self.ui.apply_bulk_label_update(
                registry,
                {
                    "field": "data_type",
                    "old_label": "Wealth Survey",
                    "new_label": "Household Survey",
                    "record_ids": ["src-a"],
                    "editor_name": "Francesca",
                },
                changelog,
            )

            data = self.ui.load_json_yaml(changelog)

        self.assertEqual(out["record_ids"], ["src-a"])
        self.assertEqual(registry["records"][0]["data_type"], "Household Survey")
        self.assertEqual(registry["records"][0]["updated_by"], "Francesca")
        self.assertEqual(registry["records"][1]["data_type"], "Wealth Survey")
        self.assertEqual(len(data["changes"]), 1)
        self.assertEqual(data["changes"][0]["operation"], "bulk_label_update")
        self.assertIn("Wealth Survey", data["changes"][0]["reason"])

    def test_bulk_label_apply_rejects_stale_selected_record(self):
        registry = {
            "records": [
                {"id": "src-a", "aggsource": "Official survey data", "source": "A", "citekey": "A", "bib": {}},
                {"id": "src-b", "aggsource": "Academic research", "source": "B", "citekey": "B", "bib": {}},
            ]
        }
        with tempfile.TemporaryDirectory() as tmpdir:
            changelog = pathlib.Path(tmpdir) / "change_log.json"
            changelog.write_text('{"changes": []}\n', encoding="utf-8")

            with self.assertRaisesRegex(ValueError, "stale"):
                self.ui.apply_bulk_label_update(
                    registry,
                    {
                        "field": "aggsource",
                        "old_label": "Official survey data",
                        "new_label": "Official statistics",
                        "record_ids": ["src-b"],
                        "editor_name": "Francesca",
                    },
                    changelog,
                )
            data = self.ui.load_json_yaml(changelog)

        self.assertEqual(registry["records"][1]["aggsource"], "Academic research")
        self.assertEqual(data["changes"], [])

    def test_bulk_label_apply_updates_only_exact_section_keyword_mirrors(self):
        registry = {
            "records": [
                {
                    "id": "src-a",
                    "section": "Wealth Topography",
                    "source": "A",
                    "citekey": "A",
                    "bib": {"keywords": "Data Sources: Wealth Topography"},
                },
                {
                    "id": "src-b",
                    "section": "Wealth Topography",
                    "source": "B",
                    "citekey": "B",
                    "bib": {"keywords": "Data Sources: Wealth Topography,Methods"},
                },
            ]
        }
        with tempfile.TemporaryDirectory() as tmpdir:
            changelog = pathlib.Path(tmpdir) / "change_log.json"
            changelog.write_text('{"changes": []}\n', encoding="utf-8")

            out = self.ui.apply_bulk_label_update(
                registry,
                {
                    "field": "section",
                    "old_label": "Wealth Topography",
                    "new_label": "Wealth Inequality",
                    "record_ids": ["src-a", "src-b"],
                    "editor_name": "Francesca",
                },
                changelog,
            )

        self.assertEqual(out["keyword_mirror_updates"], 2)
        self.assertIn("bib.keywords", out["changed_fields"])
        self.assertEqual(registry["records"][0]["bib"]["keywords"], "Data Sources: Wealth Inequality")
        self.assertEqual(registry["records"][1]["bib"]["keywords"], "Data Sources: Wealth Inequality,Methods")

    def test_marked_shared_citekey_writes_one_bib_entry(self):
        records = [
            {
                "source": "A",
                "citekey": "SharedKey",
                "shared_citekey_group": "g",
                "section": "Wealth Topography",
                "bib": {
                    "entry_type": "misc",
                    "title": "A",
                    "author": "A",
                    "year": "2026",
                    "keywords": "Data Sources: Wealth Topography",
                },
            },
            {
                "source": "B",
                "citekey": "SharedKey",
                "shared_citekey_group": "g",
                "section": "Wealth Topography",
                "bib": {
                    "entry_type": "misc",
                    "title": "B",
                    "author": "B",
                    "year": "2026",
                    "keywords": "Data Sources: Wealth Topography",
                },
            },
        ]
        with tempfile.TemporaryDirectory() as tmpdir:
            out_path = pathlib.Path(tmpdir) / "digital_library.bib"
            self.build.write_digital_library_bib(out_path, records)
            text = out_path.read_text(encoding="utf-8")

        self.assertEqual(text.count("@misc{SharedKey,"), 1)

    def test_batch_validator_accepts_marked_shared_citekey(self):
        registry = {
            "records": [
                {
                    "id": "src-a",
                    "source": "A",
                    "citekey": "SharedKey",
                    "shared_citekey_group": "g",
                    "link": "https://example.test/shared",
                    "section": "Wealth Topography",
                    "bib": {
                        "entry_type": "misc",
                        "title": "Shared",
                        "author": "A",
                        "year": "2026",
                        "url": "https://example.test/shared",
                        "keywords": "Data Sources: Wealth Topography",
                    },
                },
                {
                    "id": "src-b",
                    "source": "B",
                    "citekey": "SharedKey",
                    "shared_citekey_group": "g",
                    "link": "https://example.test/shared",
                    "section": "Wealth Topography",
                    "bib": {
                        "entry_type": "misc",
                        "title": "Shared",
                        "author": "B",
                        "year": "2026",
                        "url": "https://example.test/shared",
                        "keywords": "Data Sources: Wealth Topography",
                    },
                },
            ]
        }

        warnings = self.validate.validate_records(registry, strict=True)

        self.assertEqual(warnings, [])


if __name__ == "__main__":
    unittest.main()
