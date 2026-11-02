import pathlib
import unittest


REPO_ROOT = pathlib.Path(__file__).resolve().parents[3]


class MainstreamSourceAliasTests(unittest.TestCase):
    def read(self, relative_path: str) -> str:
        return (REPO_ROOT / relative_path).read_text(encoding="utf-8")

    def test_source_alias_helper_is_registered(self):
        text = self.read("code/mainstream/auxiliar/all_paths.do")

        self.assertIn(
            "global harmonize_source_aliases code/mainstream/auxiliar/harmonize_source_aliases.do",
            text,
        )

    def test_append_step_harmonizes_aliases_without_dropping_extensionless_sources(self):
        text = self.read("code/mainstream/02a_append_dboards.do")

        self.assertIn("run $harmonize_source_aliases", text)
        self.assertNotIn('drop if inlist(source, "WID", "LWS")', text)

    def test_topography_metadata_is_canonicalized_before_export(self):
        text = self.read("code/mainstream/02b_prepare_metadata.do")

        self.assertLess(
            text.index("run $harmonize_source_aliases"),
            text.index('export excel "output/metadata/metadata_topo.xlsx"'),
        )

    def test_export_step_canonicalizes_both_topo_metadata_and_warehouse_sources(self):
        text = self.read("code/mainstream/03a_export_warehouses.do")

        self.assertGreaterEqual(text.count("run $harmonize_source_aliases"), 2)
        self.assertLess(
            text.index("run $harmonize_source_aliases"),
            text.index("tempfile tf_topo"),
        )
        self.assertLess(
            text.index('"raw_data/taxw/intermediary_files/warehouse_ar.csv"'),
            text.rindex("run $harmonize_source_aliases"),
        )
        self.assertNotIn("tempfile tf_source_aliases", text)

    def test_helper_reads_generated_source_aliases_sheet(self):
        text = self.read("code/mainstream/auxiliar/harmonize_source_aliases.do")

        self.assertIn('sheet("`alias_sheet\'") firstrow clear case(lower)', text)
        self.assertIn("SourceAliases", text)
        self.assertIn("canonical_source", text)


if __name__ == "__main__":
    unittest.main()
