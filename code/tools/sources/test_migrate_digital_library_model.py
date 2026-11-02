import importlib.util
import pathlib
import sys
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


class DigitalLibraryMigrationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.migration = load_module("migrate_digital_library_model", "code/tools/sources/migrate_digital_library_model.py")

    def test_registry_migration_maps_sections_to_controlled_keywords(self):
        registry = {
            "config": {
                "bib_output": "documentation/BibTeX files/GCWealthProject_DataSourcesLibrary.bib",
                "both_bib_output": "documentation/BibTeX files/BothLibraries.bib",
                "online_bib_reference_url": "https://example.test/GCWealthProject_DataSourcesLibrary.bib",
                "bibbase_profile_source_url": "https://bibbase.org/f/example/GCWealthProject_DataSourcesLibrary.bib",
            },
            "records": [
                {
                    "id": "src-tax",
                    "section": "Taxes on Wealth",
                    "citekey": "Tax2026",
                    "bib": {
                        "keywords": "Data Sources: Estate Inheritance and Gift Taxes,Estate Inheritance and Gift Taxes",
                    },
                },
                {
                    "id": "src-inheritance",
                    "section": "Inheritance Trends",
                    "citekey": "Inheritance2026",
                    "bib": {"keywords": ""},
                },
                {
                    "id": "src-multiple",
                    "section": "Wealth Topography",
                    "citekey": "Topography2026",
                    "bib": {
                        "keywords": "Data Sources: Wealth Inequality,Data Sources: Taxes on Wealth,Survey Data",
                    },
                },
                {
                    "id": "src-uncertain",
                    "section": "Mystery",
                    "citekey": "Mystery2026",
                    "bib": {"keywords": "Research Topic"},
                },
            ],
        }

        report = self.migration.migrate_registry(registry)

        self.assertEqual(
            registry["records"][0]["bib"]["keywords"],
            "Data Sources: Taxes on Wealth,Estate Inheritance and Gift Taxes",
        )
        self.assertEqual(registry["records"][1]["bib"]["keywords"], "Data Sources: Inheritance Trends")
        self.assertEqual(
            registry["records"][2]["bib"]["keywords"],
            "Data Sources: Wealth Topography,Survey Data",
        )
        self.assertEqual(registry["records"][3]["bib"]["keywords"], "Research Topic")
        self.assertIn("digital_bib_output", registry["config"])
        self.assertNotIn("bib_output", registry["config"])
        self.assertNotIn("both_bib_output", registry["config"])
        self.assertIn("digital_library.bib", registry["config"]["online_bib_reference_url"])
        self.assertEqual([row["id"] for row in report["backfilled"]], ["src-inheritance"])
        self.assertEqual([row["id"] for row in report["multiple_before"]], ["src-multiple"])
        self.assertEqual([row["id"] for row in report["uncertain"]], ["src-uncertain"])
        self.assertEqual(report["multiple_after"], [])

    def test_wealth_bib_migration_removes_only_data_source_machine_keywords(self):
        entries = {
            "Wealth2026": {
                "entry_type": "article",
                "fields": {
                    "keywords": "Estate Inheritance and Gift Taxes,Data Sources: Estate Inheritance and Gift Taxes,Taxation",
                },
            }
        }

        report = self.migration.migrate_wealth_bib(entries)

        self.assertEqual(entries["Wealth2026"]["fields"]["keywords"], "Estate Inheritance and Gift Taxes,Taxation")
        self.assertEqual([row["citekey"] for row in report["changed"]], ["Wealth2026"])

    def test_report_lists_required_manual_review_sections(self):
        text = self.migration.render_report(
            {
                "changed": [],
                "backfilled": [],
                "multiple_before": [],
                "multiple_after": [],
                "uncertain": [],
            },
            {"changed": []},
            {
                "duplicate_citekeys": [],
                "bibliographic_conflicts": [],
                "multi_data_source_keyword_exports": [],
            },
        )

        for heading in [
            "## Registry Records Changed",
            "## Blank Keywords Backfilled",
            "## Multiple Data-Source Keywords Before Migration",
            "## Multiple Data-Source Keywords After Migration",
            "## Could Not Confidently Classify",
            "## Duplicate Citekeys",
            "## Bibliographic Metadata Conflicts",
        ]:
            self.assertIn(heading, text)


if __name__ == "__main__":
    unittest.main()
