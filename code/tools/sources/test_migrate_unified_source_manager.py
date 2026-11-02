import importlib.util
import pathlib
import sys
import tempfile
import unittest

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


class UnifiedSourceManagerMigrationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.migration = load_module(
            "migrate_unified_source_manager",
            "code/tools/sources/migrate_unified_source_manager.py",
        )

    def test_imports_wealth_research_entries_as_non_data_source_records(self):
        registry = {"config": {}, "records": []}
        wealth_entries = {
            "Research2026": {
                "entry_type": "article",
                "fields": {
                    "title": "Research Title",
                    "author": "Researcher, Riley",
                    "year": "2026",
                    "url": "https://example.test/research",
                    "keywords": "Wealth Taxation,Custom Topic",
                },
            }
        }

        report = self.migration.migrate_registry_to_unified_model(registry, wealth_entries)

        self.assertEqual(len(registry["records"]), 1)
        record = registry["records"][0]
        self.assertFalse(record["is_data_source"])
        self.assertEqual(record["section"], "")
        self.assertEqual(record["source"], "")
        self.assertEqual(record["citekey"], "Research2026")
        self.assertEqual(record["bib"]["keywords"], "Wealth Taxation")
        self.assertEqual([row["citekey"] for row in report["imported_entries"]], ["Research2026"])

    def test_existing_citekey_merge_unions_keywords_and_preserves_url_like_fields(self):
        registry = {
            "config": {},
            "records": [
                {
                    "id": "src-shared",
                    "is_data_source": True,
                    "section": "Wealth Topography",
                    "source": "Shared2026",
                    "citekey": "Shared2026",
                    "link": "https://example.test/data",
                    "bib": {
                        "entry_type": "misc",
                        "title": "Shared Title",
                        "author": "Data Office",
                        "year": "2026",
                        "url": "https://example.test/data",
                        "keywords": "Data Sources: Wealth Topography",
                    },
                }
            ],
        }
        wealth_entries = {
            "Shared2026": {
                "entry_type": "article",
                "fields": {
                    "title": "Shared Title",
                    "author": "Data Office",
                    "year": "2026",
                    "keywords": "Wealth Taxation,Intergenerational Wealth",
                    "replication_package": "https://example.test/replication",
                },
            }
        }

        report = self.migration.migrate_registry_to_unified_model(registry, wealth_entries)

        self.assertEqual(len(registry["records"]), 1)
        record = registry["records"][0]
        self.assertTrue(record["is_data_source"])
        self.assertEqual(
            record["bib"]["keywords"],
            "Data Sources: Wealth Topography,Wealth Taxation,Intergenerational Wealth",
        )
        self.assertEqual(record["bib"]["extra_fields"]["replication_package"], "https://example.test/replication")
        self.assertEqual([row["citekey"] for row in report["merged_entries"]], ["Shared2026"])
        self.assertEqual(report["duplicate_citekeys_after"], [])

    def test_duplicate_registry_records_collapse_to_multi_category_data_source(self):
        base_bib = {
            "entry_type": "misc",
            "title": "Shared Dataset",
            "author": "Data Office",
            "year": "2026",
        }
        registry = {
            "config": {},
            "records": [
                {
                    "id": "src-topography",
                    "is_data_source": True,
                    "section": "Wealth Topography",
                    "source": "SharedData_topo",
                    "citekey": "SharedData2026",
                    "link": "https://example.test/topography",
                    "bib": {**base_bib, "keywords": "Data Sources: Wealth Topography"},
                },
                {
                    "id": "src-inequality",
                    "is_data_source": True,
                    "section": "Wealth Inequality",
                    "source": "SharedData_ineq",
                    "citekey": "SharedData2026",
                    "link": "https://example.test/inequality",
                    "bib": {**base_bib, "keywords": "Data Sources: Wealth Inequality,Wealth Taxation"},
                },
            ],
        }

        report = self.migration.migrate_registry_to_unified_model(registry, {})

        self.assertEqual(len(registry["records"]), 1)
        record = registry["records"][0]
        self.assertEqual(record["source"], "SharedData")
        self.assertEqual(record["source_aliases"], ["SharedData_topo", "SharedData_ineq"])
        self.assertEqual(record["section"], "Wealth Topography; Wealth Inequality")
        self.assertEqual(
            record["bib"]["keywords"],
            "Data Sources: Wealth Topography,Data Sources: Wealth Inequality,Wealth Taxation",
        )
        self.assertEqual([row["citekey"] for row in report["collapsed_duplicate_registry_records"]], ["SharedData2026"])

    def test_duplicate_registry_records_without_ineq_topo_pair_remain_distinct(self):
        base_bib = {
            "entry_type": "misc",
            "title": "Shared Dataset",
            "author": "Data Office",
            "year": "2026",
        }
        registry = {
            "config": {},
            "records": [
                {
                    "id": "src-a",
                    "is_data_source": True,
                    "section": "Wealth Topography",
                    "source": "SharedDataA",
                    "citekey": "SharedData2026",
                    "link": "https://example.test/a",
                    "bib": {**base_bib, "keywords": "Data Sources: Wealth Topography"},
                },
                {
                    "id": "src-b",
                    "is_data_source": True,
                    "section": "Wealth Inequality",
                    "source": "SharedDataB",
                    "citekey": "SharedData2026",
                    "link": "https://example.test/b",
                    "bib": {**base_bib, "keywords": "Data Sources: Wealth Inequality"},
                },
            ],
        }

        report = self.migration.migrate_registry_to_unified_model(registry, {})

        self.assertEqual(len(registry["records"]), 2)
        self.assertEqual(report["collapsed_duplicate_registry_records"], [])
        self.assertEqual(report["duplicate_citekeys_after"][0]["citekey"], "SharedData2026")
        self.assertTrue(all(record.get("shared_citekey_group") == "shared-shareddata2026" for record in registry["records"]))
        self.assertTrue(any("do not form an exact _ineq/_topo" in row["reason"] for row in report["unresolved_records"]))

    def test_archive_file_moves_wealth_bib_input_to_old_folder(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            root = pathlib.Path(tmpdir)
            source = root / "GCWealthProject_WealthResearchLibrary.bib"
            archive = root / "old" / "GCWealthProject_WealthResearchLibrary.bib"
            source.write_text("@article{Research2026,}\n", encoding="utf-8")
            report = {"archived_files": []}

            self.migration.archive_file(source, archive, report)

            self.assertFalse(source.exists())
            self.assertEqual(archive.read_text(encoding="utf-8"), "@article{Research2026,}\n")
            self.assertEqual(report["archived_files"][0]["status"], "archived")


if __name__ == "__main__":
    unittest.main()
