# Canonical Source Registry

This folder is the canonical home for source metadata.

- `sources.yaml`: the only active editable source-manager store
- `schema.json`: schema contract
- `aliases.yaml`: old->new key mappings for breaking renames
- `change_log.yaml`: active source-manager audit entries
- `wealth_research_change_log.yaml`: legacy Wealth Research history, still readable in the History tab
- `documentation/BibTeX files/digital_library.bib`: generated canonical public bibliography artifact
- `reconciliation_report.md`: migration reconciliation report
- `unified_source_manager_migration_report.md`: Wealth Research import and single-registry migration report
- `digital_library_migration_report.md`: earlier data-source keyword migration report

Archived transition files live under `documentation/BibTeX files/old/`.

## Policy

- Do not edit `handmade_tables/dictionary.xlsx` manually.
- `handmade_tables/dictionary.xlsx` (`Sources` and `SourceAliases` sheets) and `digital_library.bib` are generated artifacts.
- Add/edit operations should go through the local Source Registry UI.
- `sources.yaml` is the active write target for data-source and research records.
- Comment-only dictionary columns are intentionally omitted from the UI and kept blank in generated outputs.
- Data-source classification is exported through the standard BibTeX `keywords` field.
- Exported BibTeX must not include a `section` field.
- Category keywords must come from the controlled data-source and research category lists.

## Commands

```bash
python3 code/tools/sources/build_sources_artifacts.py --registry code/tools/metadata/sources/sources.yaml
python3 code/tools/sources/validate_sources.py --registry code/tools/metadata/sources/sources.yaml --schema code/tools/metadata/sources/schema.json --aliases code/tools/metadata/sources/aliases.yaml --change-log code/tools/metadata/sources/change_log.yaml --check-generated --dictionary handmade_tables/dictionary.xlsx --digital-bib "documentation/BibTeX files/digital_library.bib"
python3 code/tools/sources/ui_local.py
```

## Running The UI

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

## UI Behavior Notes

- The UI has one editor tab: `Library`.
- `History` and `Maintenance` remain auxiliary tabs.
- Fields with `*` are mandatory.
- `keywords` is required for exported records.
- The `This record is a data source` checkbox controls whether data-source-only fields apply.
- Checked data-source records must have one or more controlled `Data Sources: ...` keywords:
  - `Data Sources: Wealth Topography`
  - `Data Sources: Wealth Inequality`
  - `Data Sources: Taxes on Wealth`
  - `Data Sources: Inheritance Trends`
  - `Data Sources: Supplementary Variables`
  - `Data Sources: Unclassified`
- Unchecked records must not have `Data Sources: ...` keywords.
- Research records should carry at least one controlled research category keyword unless explicitly marked for manual review:
  - `Cross-National Comparisons`
  - `Determinants of Wealth and Wealth Inequality`
  - `Estate Inheritance and Gift Taxes`
  - `Impacts of Wealth Inequality`
  - `Intergenerational Wealth`
  - `Methods of Estimation of Wealth Inequality`
  - `Trends in Aggregate Wealth and Wealth Inequality`
  - `Wealth Taxation`
- Legend suggestion in add mode uses citation style:
  - `Lastname (year)` for one author
  - `Lastname et al. (year)` for multiple authors
- `Edit target` and `Change reason` only appear in `edit` mode.
- In edit mode, **Load existing entry** and **Delete entry** are grouped under **Edit tools**.
- Key rename confirmation is prompted when you change a source code or citekey during edit.
- `citekey` is the BibTeX identifier and is required for every record exported to `digital_library.bib`.
- `source` is the operational warehouse/dictionary source code and is required only for data-source records.
- Non-data-source research records leave `source` blank; their bibliographic identity lives in `citekey`.
- Collapsed `_ineq`/`_topo` data-source records use one extensionless source code, such as `LWS` or `CS`, and keep the old suffixed codes in `source_aliases`.
- `dictionary.xlsx` writes those aliases to the `SourceAliases` sheet so downstream warehouse code can map legacy dashboard source codes without hard-coded drops.
- `code/mainstream/02a_append_dboards.do` keeps exact extensionless source names such as `LWS` and `WID`; it uses `SourceAliases` to canonicalize old suffixed names instead of deleting canonical rows.
- `Link` and bib `url` are kept as separate fields. In current data they are not always identical, so fusing them would lose information in some records.
- For new entries, the UI collects a single `URL / Link` field and writes that value to both `link` and bib `url`.
- For existing entries, `bib.url` can still be reviewed/adjusted separately when needed.
- `id` is internal and not shown in the form.
- `Your name` is required and saved in change logs; add/edit records also keep `created_by` / `updated_by`.
- BibTeX paste behavior:
  - Clicking **Parse BibTeX and fill fields** overwrites the mapped fields below.
  - Editing the paste box alone does nothing until Parse is clicked again.
  - After parsing, manual edits in fields below are the final values that will be saved.
- Button sequence is intentional:
  1. **Check entry (validation only, no save)**
  2. **Save entry + regenerate dictionary.xlsx and digital_library.bib**
- The status panel shows an explicit checklist with `PASS`/`FAIL` for each validation category.
- Validation also runs duplicate checks against generated artifacts:
  - `handmade_tables/dictionary.xlsx` (`Sources` sheet)
  - `handmade_tables/dictionary.xlsx` (`SourceAliases` sheet)
  - `documentation/BibTeX files/digital_library.bib`
- Save/delete responses list exactly which files were modified and include a per-file change summary.
- `Change reason` is required in edit mode during check and before save.
- On validation/save errors, the UI shows a popup window and detailed error text in the status panel.
