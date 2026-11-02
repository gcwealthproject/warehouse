import contextlib
import importlib.util
import io
import json
import pathlib
import shutil
import sys
import tempfile
import unittest

SOURCE_DIR = pathlib.Path("code/tools/sources").resolve()
REPO_ROOT = SOURCE_DIR.parents[2]
SOURCE_WORKBOOK = REPO_ROOT / "handmade_tables/dictionary.xlsx"
if str(SOURCE_DIR) not in sys.path:
    sys.path.insert(0, str(SOURCE_DIR))

from common import read_source_alias_sheet  # noqa: E402


def load_module(name, relative_path):
    path = pathlib.Path(relative_path).resolve()
    sys.path.insert(0, str(path.parent))
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


class BuildSourcesArtifactsTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.build = load_module("build_sources_artifacts", "code/tools/sources/build_sources_artifacts.py")

    def test_main_generates_digital_library_without_primary_split_outputs(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            root = pathlib.Path(tmpdir)
            registry_path = root / "sources.json"
            template_path = root / "template.xlsx"
            dictionary_path = root / "dictionary.xlsx"
            digital_path = root / "digital_library.bib"
            old_data_path = root / "GCWealthProject_DataSourcesLibrary.bib"
            old_both_path = root / "BothLibraries.bib"
            shutil.copy2(SOURCE_WORKBOOK, template_path)
            registry_path.write_text(
                json.dumps(
                    {
                        "version": 1,
                        "config": {
                            "bib_output": str(old_data_path),
                            "both_bib_output": str(old_both_path),
                        },
                        "records": [
                            {
                                "id": "src-data",
                                "section": "Wealth Topography",
                                "aggsource": "Official statistics",
                                "legend": "Data (2026)",
                                "source": "Data2026",
                                "source_aliases": ["Data2026_ineq", "Data2026_topo"],
                                "citekey": "Data2026",
                                "link": "https://example.test/data",
                                "bib": {
                                    "entry_type": "misc",
                                    "title": "Data",
                                    "author": "Data Office",
                                    "year": "2026",
                                    "url": "https://example.test/data",
                                    "keywords": "Data Sources: Wealth Topography",
                                },
                            },
                            {
                                "id": "src-research",
                                "is_data_source": False,
                                "section": "",
                                "source": "",
                                "citekey": "Research2026",
                                "bib": {
                                    "entry_type": "article",
                                    "title": "Research",
                                    "author": "Researcher",
                                    "year": "2026",
                                    "keywords": "Wealth Taxation",
                                },
                            },
                        ],
                    },
                    indent=2,
                )
                + "\n",
                encoding="utf-8",
            )

            argv = [
                "build_sources_artifacts.py",
                "--registry",
                str(registry_path),
                "--dictionary-template",
                str(template_path),
                "--dictionary-output",
                str(dictionary_path),
                "--digital-bib-output",
                str(digital_path),
                "--both-bib-output",
                str(old_both_path),
            ]
            original_argv = sys.argv[:]
            try:
                sys.argv = argv
                with contextlib.redirect_stdout(io.StringIO()):
                    self.assertEqual(self.build.main(), 0)
            finally:
                sys.argv = original_argv

            self.assertTrue(dictionary_path.exists())
            self.assertTrue(digital_path.exists())
            self.assertEqual(
                read_source_alias_sheet(dictionary_path),
                [
                    {
                        "Alias": "Data2026_ineq",
                        "Source": "Data2026",
                        "Citekey": "Data2026",
                        "Record_ID": "src-data",
                        "Note": "Legacy dashboard/source-manager code mapped to canonical source code.",
                    },
                    {
                        "Alias": "Data2026_topo",
                        "Source": "Data2026",
                        "Citekey": "Data2026",
                        "Record_ID": "src-data",
                        "Note": "Legacy dashboard/source-manager code mapped to canonical source code.",
                    },
                ],
            )
            self.assertFalse(old_data_path.exists())
            self.assertFalse(old_both_path.exists())
            text = digital_path.read_text(encoding="utf-8")
            self.assertIn("@misc{Data2026,", text)
            self.assertIn("@article{Research2026,", text)


if __name__ == "__main__":
    unittest.main()
