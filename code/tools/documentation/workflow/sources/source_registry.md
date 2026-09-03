# Source Registry Workflow (Add/Edit)

## Canonical Data

Canonical records are stored in `code/tools/metadata/sources/sources.yaml`.
Generated artifacts:
- `handmade_tables/dictionary.xlsx` (`Sources` sheet)
- `documentation/BibTeX files/GCWealthProject_DataSourcesLibrary.bib`
- `documentation/BibTeX files/GCWealthProject_WealthResearchLibrary.bib` (edited directly in the Wealth Research branch)
- `documentation/BibTeX files/BothLibraries.bib` (combined with `GCWealthProject_WealthResearchLibrary.bib`)

## UI Branches

- `Data Sources` branch:
  - Canonical store: `code/tools/metadata/sources/sources.yaml`
  - Save regenerates `dictionary.xlsx`, `GCWealthProject_DataSourcesLibrary.bib`, and `BothLibraries.bib`
  - Audit files: `code/tools/metadata/sources/change_log.yaml` and `code/tools/metadata/sources/aliases.yaml`
  - Optional review action: `Review ref_link proposals`
    - Available without saving first
    - Scans the full Data Sources registry against live BibBase entries
    - Groups results into `Ready to apply`, `Needs review`, and `Dismissed`
    - `Apply selected` updates only `ref_link`, appends audit entries, and rebuilds Data Sources artifacts
- `Wealth Research` branch:
  - Canonical store: `documentation/BibTeX files/GCWealthProject_WealthResearchLibrary.bib`
  - Save regenerates only `BothLibraries.bib`
  - Audit file: `code/tools/metadata/sources/wealth_research_change_log.yaml`
  - Includes live browse/search panel by key/title/author/year in edit mode

## Contributor Flow

1. Launch local UI:
   - Mac double-click: `code/tools/source_manager_mac.command`
   - Windows double-click: `code/tools/source_manager_win.bat`
   - Linux: `./code/tools/source_manager_linux.sh`
   - Or Terminal: `python3 code/tools/sources/ui_local.py`
2. Open the URL printed by the launcher or Terminal. The app prefers `http://127.0.0.1:8765`, but it may choose a fallback port if `8765` is busy.
3. Choose branch: `Data Sources` or `Wealth Research`.
4. Choose `mode` = `add` or `edit`.
5. Fill `Your name` (required for save/delete).
6. For edit mode:
   - Data Sources: pick an existing source target and load it.
   - Wealth Research: use the search panel, pick a key, then load it.
7. Optionally paste a full BibTeX entry and parse it into fields.
8. Validate in the UI (errors must be fixed before save).
9. Save and regenerate artifacts locally.
10. When finished, use the app's explicit shutdown action or close the Terminal/command window. If left idle, the local server stops after 60 minutes.

Launching the UI does not change source records or generated library files. Changes happen only after explicit save/apply actions inside the UI.

## Duplicate Rules

- Exact duplicates are blocked in intake for:
  - `source`
  - `citekey`
  - normalized URL
  - normalized `(title, year)`
- Fuzzy similarities are surfaced as warnings for review.
- Existing values are suggested in the UI for:
  - `section`
  - `aggsource`
  - `data_type`
- Existing source keys are suggested for edit targets.
- Comment columns are not exposed in the UI.
- Wealth branch blocks key collisions with DataSources for new keys/renames.
  - Existing overlapping keys are grandfathered and can still be edited without renaming.

## Field Semantics

- `Source / Citekey` is collected once and stored as both `source` and `citekey`.
- For new entries, one `URL / Link` input populates both `link` and bib `url`.
- For existing entries, `link` and bib `url` can still be reviewed separately if needed.
- `id` is internal and not user-editable.
- Fields marked with `*` are mandatory.
- `keywords` is optional (recommended).
- Legend suggestion for add mode is citation-style:
  - `Lastname (year)` for single author
  - `Lastname et al. (year)` for multi-author entries
- `Edit target` and `Change reason` are edit-only controls.
- Source/Citekey renames trigger an explicit save-time confirmation, then aliases are tracked.
- UI tracks who made the change via `Your name`, stored in logs and record audit fields.

## BibTeX Paste Semantics

- Pasting BibTeX and clicking parse overwrites mapped fields below.
- Changing the paste textarea without parsing again does nothing.
- Manual edits in fields below always win and are what gets saved.

## Action Sequence

1. Check entry (validation only, no save).
2. Save entry and regenerate artifacts.
3. Review `ref_link` proposals (optional, available at any time in the Data Sources branch).
4. Apply selected `ref_link` proposals (optional, explicit write step).
Edit-only helper: Load existing entry.
If validation/save fails, the UI shows an error popup and full details in the status panel.
In edit mode, delete is available with a required confirmation prompt.

## Key Rename Tracking

When Source/Citekey is renamed and confirmed in edit mode:
- alias entries are recorded in `code/tools/metadata/sources/aliases.yaml`
- change record is appended to `code/tools/metadata/sources/change_log.yaml`

## Local Tooling

- Bootstrap registry from legacy files:
  - `python3 code/tools/sources/bootstrap_registry.py --dictionary handmade_tables/dictionary.xlsx --bib /path/to/file.bib --out code/tools/metadata/sources/sources.yaml`
- Build artifacts:
  - `python3 code/tools/sources/build_sources_artifacts.py --registry code/tools/metadata/sources/sources.yaml`
  - Optional overrides:
    - `--wealth-bib-input "documentation/BibTeX files/GCWealthProject_WealthResearchLibrary.bib"`
    - `--both-bib-output "documentation/BibTeX files/BothLibraries.bib"`
- Validate:
  - `python3 code/tools/sources/validate_sources.py --registry code/tools/metadata/sources/sources.yaml --schema code/tools/metadata/sources/schema.json --aliases code/tools/metadata/sources/aliases.yaml --change-log code/tools/metadata/sources/change_log.yaml --check-generated --dictionary handmade_tables/dictionary.xlsx --bib "documentation/BibTeX files/GCWealthProject_DataSourcesLibrary.bib" --wealth-bib-input "documentation/BibTeX files/GCWealthProject_WealthResearchLibrary.bib" --both-bib "documentation/BibTeX files/BothLibraries.bib"`
- Local UI:
  - `python3 code/tools/sources/ui_local.py`
- Migration reconciliation report:
  - `python3 code/tools/sources/reconcile_report.py --registry code/tools/metadata/sources/sources.yaml --bib "documentation/BibTeX files/GCWealthProject_DataSourcesLibrary.bib" --out code/tools/metadata/sources/reconciliation_report.md`
