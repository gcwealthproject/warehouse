# Canonical Source Registry

This folder is the canonical home for source metadata.

- `sources.yaml`: canonical source records (JSON-compatible YAML)
- `schema.json`: schema contract
- `aliases.yaml`: old->new key mappings for breaking renames
- `change_log.yaml`: intake audit entries
- `wealth_research_change_log.yaml`: Wealth Research branch audit entries
- `documentation/BibTeX files/GCWealthProject_DataSourcesLibrary.bib`: generated bibliography artifact
- `documentation/BibTeX files/GCWealthProject_WealthResearchLibrary.bib`: Wealth Research canonical bibliography (edited directly by UI branch)
- `reconciliation_report.md`: migration reconciliation report

## Policy

- Do not edit `handmade_tables/dictionary.xlsx` manually.
- `handmade_tables/dictionary.xlsx` (`Sources` sheet) and `.bib` are generated artifacts.
- Add/edit operations should go through the local Source Registry UI.
- Comment-only dictionary columns are intentionally omitted from the UI and kept blank in generated outputs.
- Wealth Research branch saves rebuild `BothLibraries.bib` only.

## Commands

```bash
python3 code/tools/sources/build_sources_artifacts.py --registry code/tools/metadata/sources/sources.yaml
python3 code/tools/sources/validate_sources.py --registry code/tools/metadata/sources/sources.yaml --schema code/tools/metadata/sources/schema.json --aliases code/tools/metadata/sources/aliases.yaml --change-log code/tools/metadata/sources/change_log.yaml --check-generated --dictionary handmade_tables/dictionary.xlsx --bib "documentation/BibTeX files/GCWealthProject_DataSourcesLibrary.bib"
python3 code/tools/sources/ui_local.py
```

## Running The UI (Beginner-Friendly)

### Option 1 (Mac, double-click)

1. In Finder, open this repository folder.
2. Open `code/tools`.
3. Double-click `source_manager_mac.command`.
4. Your browser should open automatically. If port `8765` is busy, the Terminal prints the fallback URL to use.
5. Keep the Terminal window open while using the UI.
6. When finished, use the app's explicit shutdown action or close the Terminal window. If left idle, the local server stops after 60 minutes.

If macOS blocks the file the first time:
1. Right-click `source_manager_mac.command`.
2. Click `Open`.
3. Confirm `Open` in the dialog.

### Option 2 (Windows, double-click)

1. Open this repository folder in File Explorer.
2. Open `code/tools`.
3. Double-click `source_manager_win.bat`.
4. Your browser should open automatically. If port `8765` is busy, the command window prints the fallback URL to use.
5. Keep the command window open while using the UI.
6. When finished, use the app's explicit shutdown action or close the command window. If left idle, the local server stops after 60 minutes.

### Option 3 (Terminal)

1. Open Terminal.
2. Go to the repository folder:
   - `cd /path/to/warehouse`
3. Run:
   - `python3 code/tools/sources/ui_local.py`
4. Open the URL printed in Terminal. The app prefers `http://127.0.0.1:8765`, but it may print a fallback URL if that port is busy.

These launch instructions only start the local source-management UI. They do not change source records or generated library files unless you save changes inside the UI.

### If Python is missing

Run:
- `python3 --version`

If that fails, install Python 3 from:
- https://www.python.org/downloads/

## UI Behavior Notes

- The UI has two branches at the top:
  - `Data Sources` (current registry workflow)
  - `Wealth Research` (direct `.bib` editing with search/browse panel)
- Fields with `*` are mandatory.
- `keywords` is optional (recommended).
- Legend suggestion in add mode uses citation style:
  - `Lastname (year)` for one author
  - `Lastname et al. (year)` for multiple authors
- `Edit target` and `Change reason` only appear in `edit` mode.
- In edit mode, **Load existing entry** and **Delete entry** are grouped under **Edit tools**.
- Key rename confirmation is now prompted only when you actually change `Source / Citekey` during edit.
- `Source / Citekey` is entered once in the UI and saved to both:
  - `Source` (dictionary context)
  - `citekey` (BibTeX context)
- `Link` and bib `url` are kept as separate fields. In current data they are not always identical, so fusing them would lose information in some records.
- For **new entries**, the UI collects a single `URL / Link` field and writes that value to both `link` and bib `url`.
- For **existing entries (edit mode)**, `bib.url` can still be reviewed/adjusted separately when needed.
- `id` is internal and not shown in the form.
- `Your name` is required and saved in change logs; add/edit records also keep `created_by` / `updated_by`.
- Wealth Research branch requires `Your name` for save/delete and writes to `wealth_research_change_log.yaml`.
- Wealth Research branch blocks new/renamed keys that collide with DataSources keys (existing overlaps are grandfathered if key is unchanged).
- BibTeX paste behavior:
  - Clicking **Parse BibTeX and fill fields** overwrites the mapped fields below.
  - Editing the paste box alone does nothing until Parse is clicked again.
  - After parsing, manual edits in fields below are the final values that will be saved.
- Button sequence is intentional:
  1. **Check entry (validation only, no save)**
  2. **Save entry + regenerate dictionary.xlsx and .bib**
- The status panel now shows an explicit checklist with `PASS`/`FAIL` for each validation category.
- Validation now also runs duplicate checks against generated artifacts:
  - `handmade_tables/dictionary.xlsx` (`Sources` sheet)
  - `documentation/BibTeX files/GCWealthProject_DataSourcesLibrary.bib`
- Save/delete responses now list exactly which files were modified and include a per-file change summary.
- `Change reason` is required in edit mode during check and before save.
- Edit-only helper:
  - **Load existing entry into form**
- On validation/save errors, the UI shows a popup window and detailed error text in the status panel.
- In edit mode, you can delete an entry. The UI always asks for confirmation before deleting.
