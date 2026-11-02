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


class ValidateSourcesTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.validate = load_module("validate_sources", "code/tools/sources/validate_sources.py")

    def _record(
        self,
        record_id="src-a",
        source="A",
        citekey="A",
        section="Wealth Topography",
        keywords="Data Sources: Wealth Topography",
        title="A",
        is_data_source=True,
    ):
        return {
            "id": record_id,
            "is_data_source": is_data_source,
            "section": section,
            "source": source,
            "citekey": citekey,
            "link": f"https://example.test/{record_id}",
            "bib": {
                "entry_type": "misc",
                "title": title,
                "author": "Example",
                "year": "2026",
                "url": f"https://example.test/{record_id}",
                "keywords": keywords,
            },
        }

    def test_registry_rejects_noncanonical_data_source_keyword(self):
        registry = {
            "records": [
                self._record(
                    keywords="Data Sources: Estate Inheritance and Gift Taxes,Taxation",
                )
            ]
        }

        with self.assertRaisesRegex(self.validate.ValidationError, "noncanonical data-source keyword"):
            self.validate.validate_records(registry, strict=True)

    def test_registry_rejects_missing_export_keywords(self):
        registry = {"records": [self._record(keywords="", section="")]}

        with self.assertRaisesRegex(self.validate.ValidationError, "bib.keywords is required"):
            self.validate.validate_records(registry, strict=True)

    def test_research_record_keywords_are_independent_from_data_source_keywords(self):
        registry = {
            "records": [
                self._record(
                    source="",
                    section="",
                    keywords="Estate Inheritance and Gift Taxes,Wealth Taxation",
                    is_data_source=False,
                )
            ]
        }

        self.assertEqual(self.validate.validate_records(registry, strict=True), [])

    def test_registry_rejects_uncontrolled_research_keyword(self):
        registry = {
            "records": [
                self._record(
                    source="",
                    section="",
                    keywords="Estate Inheritance and Gift Taxes,Tax Incidence",
                    is_data_source=False,
                )
            ]
        }

        with self.assertRaisesRegex(self.validate.ValidationError, "uncontrolled keyword"):
            self.validate.validate_records(registry, strict=True)

    def test_non_data_source_record_rejects_data_source_keywords(self):
        registry = {
            "records": [
                self._record(
                    source="",
                    section="",
                    keywords="Data Sources: Taxes on Wealth,Wealth Taxation",
                    is_data_source=False,
                )
            ]
        }

        with self.assertRaisesRegex(self.validate.ValidationError, "non-data-source records must not have"):
            self.validate.validate_records(registry, strict=True)

    def test_non_data_source_record_rejects_source_code(self):
        registry = {
            "records": [
                self._record(
                    source="Research2026",
                    citekey="Research2026",
                    section="",
                    keywords="Wealth Taxation",
                    is_data_source=False,
                )
            ]
        }

        with self.assertRaisesRegex(self.validate.ValidationError, "non-data-source records must leave source blank"):
            self.validate.validate_records(registry, strict=True)

    def test_research_record_allows_blank_source_with_citekey(self):
        registry = {
            "records": [
                self._record(
                    source="",
                    citekey="Research2026",
                    section="",
                    keywords="Wealth Taxation",
                    is_data_source=False,
                )
            ]
        }

        self.assertEqual(self.validate.validate_records(registry, strict=True), [])

    def test_registry_allows_multi_category_data_source_record(self):
        registry = {
            "records": [
                self._record(
                    section="Wealth Topography; Wealth Inequality",
                    keywords="Data Sources: Wealth Topography,Data Sources: Wealth Inequality",
                )
            ]
        }

        self.assertEqual(self.validate.validate_records(registry, strict=True), [])

    def test_duplicate_citekey_conflict_is_reported_clearly(self):
        registry = {
            "records": [
                self._record(record_id="src-a", source="A", citekey="SharedKey", title="First Title"),
                self._record(record_id="src-b", source="B", citekey="SharedKey", title="Second Title"),
            ]
        }

        warnings = self.validate.validate_records(registry, strict=False)

        self.assertTrue(any("Exact duplicate citekey: SharedKey" in warning for warning in warnings))
        self.assertTrue(any("conflicting bibliographic fields: title" in warning for warning in warnings))

    def test_source_alias_validation_rejects_active_source_collision(self):
        registry = {
            "records": [
                {**self._record(record_id="src-a", source="Canonical"), "source_aliases": ["Other"]},
                self._record(record_id="src-b", source="Other", citekey="OtherKey"),
            ]
        }

        with self.assertRaisesRegex(self.validate.ValidationError, "source alias Other collides"):
            self.validate.validate_records(registry, strict=True)

    def test_exported_bib_rejects_section_field(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            path = pathlib.Path(tmpdir) / "digital_library.bib"
            path.write_text(
                "@misc{Example2026,\n"
                "  title = {Example},\n"
                "  keywords = {Data Sources: Wealth Topography},\n"
                "  section = {Wealth Topography}\n"
                "}\n",
                encoding="utf-8",
            )

            with self.assertRaisesRegex(self.validate.ValidationError, "must not include section"):
                self.validate.validate_digital_bib(path)

    def test_exported_bib_allows_controlled_multi_category_data_source_keywords(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            path = pathlib.Path(tmpdir) / "digital_library.bib"
            path.write_text(
                "@misc{Shared2026,\n"
                "  title = {Shared},\n"
                "  keywords = {Data Sources: Wealth Topography,Data Sources: Wealth Inequality}\n"
                "}\n",
                encoding="utf-8",
            )

            warnings = self.validate.validate_digital_bib(path)

        self.assertEqual(warnings, [])

    def test_exported_bib_rejects_duplicate_citekeys(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            path = pathlib.Path(tmpdir) / "digital_library.bib"
            path.write_text(
                "@misc{Shared2026,\n"
                "  keywords = {Data Sources: Wealth Topography}\n"
                "}\n\n"
                "@misc{Shared2026,\n"
                "  keywords = {Data Sources: Wealth Inequality}\n"
                "}\n",
                encoding="utf-8",
            )

            with self.assertRaisesRegex(self.validate.ValidationError, "duplicate citekey"):
                self.validate.validate_digital_bib(path)


if __name__ == "__main__":
    unittest.main()
