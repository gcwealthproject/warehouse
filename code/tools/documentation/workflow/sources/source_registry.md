# Source Registry Workflow

## Canonical Data

The source manager has one editable store:

- `code/tools/metadata/sources/sources.yaml`

Generated artifacts:

- `handmade_tables/dictionary.xlsx` (`Sources` sheet, data sources only)
- `handmade_tables/dictionary.xlsx` (`SourceAliases` sheet, legacy source-code aliases)
- `documentation/BibTeX files/digital_library.bib` (all exported library records)

Legacy split/input BibTeX files are archived for transition only:

- `documentation/BibTeX files/old/GCWealthProject_DataSourcesLibrary.bib`
- `documentation/BibTeX files/old/GCWealthProject_WealthResearchLibrary.bib`
- `documentation/BibTeX files/old/BothLibraries.bib`

The source manager no longer generates the old split BibTeX files as primary outputs, and Wealth Research entries are edited through `sources.yaml`.

## UI Tabs

- `Library`: the single editing surface for data-source and research records.
- `History`: active source-manager history plus readable legacy Wealth Research history.
- `Maintenance`: health checks, shared-citekey review, rebuild actions, and bulk label tools.

In the Library editor, the `This record is a data source` checkbox controls the form:

- Checked records show data-source-only fields and require at least one controlled data-source category.
- Unchecked records hide/disable data-source-only fields and strip all `Data Sources: ...` keywords.
- Research categories remain available to all records as controlled keyword selections.

## Classification

Public taxonomy is stored only in BibTeX `keywords`. Exported BibTeX must never include a `section` field.

Controlled data-source category keywords:

- `Data Sources: Wealth Topography`
- `Data Sources: Wealth Inequality`
- `Data Sources: Taxes on Wealth`
- `Data Sources: Inheritance Trends`
- `Data Sources: Supplementary Variables`
- `Data Sources: Unclassified`

Controlled research category keywords:

- `Cross-National Comparisons`
- `Determinants of Wealth and Wealth Inequality`
- `Estate Inheritance and Gift Taxes`
- `Impacts of Wealth Inequality`
- `Intergenerational Wealth`
- `Methods of Estimation of Wealth Inequality`
- `Trends in Aggregate Wealth and Wealth Inequality`
- `Wealth Taxation`

Do not add commas inside controlled machine keywords.

## Contributor Flow

1. Launch local UI:
   - Mac double-click: `code/tools/source_manager_mac.command`
   - Windows double-click: `code/tools/source_manager_win.bat`
   - Linux: `./code/tools/source_manager_linux.sh`
   - Or Terminal: `python3 code/tools/sources/ui_local.py`
2. Open the URL printed by the launcher or Terminal. The app prefers `http://127.0.0.1:8765`, but it may choose a fallback port if `8765` is busy.
3. Use the `Library` tab.
4. Choose `mode` = `add` or `edit`.
5. Fill `Your name` before saving or deleting.
6. Set `This record is a data source` only when the record should feed data-source workflows.
7. Select the controlled data-source and research categories that apply.
8. Optionally paste a full BibTeX entry and parse it into fields.
9. Validate in the UI. Errors must be fixed before save.
10. Save and regenerate artifacts locally.
11. When finished, use the app's explicit shutdown action or close the Terminal/command window. If left idle, the local server stops after 60 minutes.

Launching the UI does not change records or generated library files. Changes happen only after explicit save/apply actions inside the UI.

## Duplicate Rules

- Exact duplicates are blocked in intake for `source`, normalized URL, and normalized `(title, year)`.
- Duplicate citekeys are allowed only when marked with a shared citekey group.
- `digital_library.bib` is deduplicated primarily by citekey.
- Duplicate citekey keyword values are merged by union.
- Exact `_ineq`/`_topo` source-code pairs can be collapsed to one extensionless operational source, such as `LWS`, `CS`, `HFCS`, `ECB_DWA`, or `WID`.
- Non-`_ineq`/`_topo` duplicate-citekey records remain separate operational rows and are marked as intentional shared citekeys when appropriate.
- When duplicate records disagree on URL-like or warehouse-related fields, data-source values are preferred.
- Major bibliographic conflicts are reported for `title`, `author`, `year`, `journal`, `doi`, `publisher`, and `abstract`.
- Useful URL-like extras are preserved where possible, including file links, data files, appendices, replication packages, and codebooks.

## Field Semantics

- `citekey` is the BibTeX identifier and is required for every record exported to `digital_library.bib`.
- `source` is the operational warehouse/dictionary source code and is required only for records marked as data sources.
- Non-data-source research records must leave `source` blank; their BibTeX identity lives in `citekey`.
- The Library editor shows `Source code` only for data-source records and shows `BibTeX citekey` for all records.
- Collapsed `_ineq`/`_topo` data sources keep their extensionless `source` and list old source codes under `source_aliases`.
- Generated `dictionary.xlsx` writes those aliases to a `SourceAliases` sheet so mainstream code can map legacy dashboard codes to canonical source codes.
- For new entries, one `URL / Link` input populates both `link` and bib `url`.
- For existing entries, `link` and bib `url` can still be reviewed separately.
- `id` is internal and not user-editable.
- Fields marked with `*` are mandatory.
- `keywords` is required for exported records.
- Data-source category selection is UI-facing editing metadata mirrored into controlled `Data Sources: ...` keywords.
- Research category selection is mirrored into controlled research keywords.
- Legend suggestion for add mode is citation-style: `Lastname (year)` or `Lastname et al. (year)`.
- Source-code or citekey changes trigger an explicit save-time confirmation, then aliases are tracked where needed.
- UI tracks who made the change via `Your name`, stored in logs and record audit fields.

## BibTeX Paste Semantics

- Pasting BibTeX and clicking parse overwrites mapped fields below.
- Changing the paste textarea without parsing again does nothing.
- Manual edits in fields below always win and are what gets saved.
- Pasted `section` fields are treated as blocked export fields and are not emitted.
- Pasted noncanonical `Data Sources:` keywords are stripped unless selected through the controlled data-source category field.

## Action Sequence

1. Check entry (validation only, no save).
2. Save entry and regenerate artifacts.
3. Review `ref_link` proposals for data-source records (optional, available at any time).
4. Apply selected `ref_link` proposals (optional, explicit write step).

Edit-only helper: Load existing entry.

If validation/save fails, the UI shows an error popup and full details in the status panel. In edit mode, delete is available with a required confirmation prompt.

## Key Rename Tracking

When a source code or citekey is renamed and confirmed in edit mode:

- alias entries are recorded in `code/tools/metadata/sources/aliases.yaml`
- change records are appended to `code/tools/metadata/sources/change_log.yaml`

## Local Tooling

- Build artifacts:
  - `python3 code/tools/sources/build_sources_artifacts.py --registry code/tools/metadata/sources/sources.yaml`
  - Optional override:
    - `--digital-bib-output "documentation/BibTeX files/digital_library.bib"`
- Validate:
  - `python3 code/tools/sources/validate_sources.py --registry code/tools/metadata/sources/sources.yaml --schema code/tools/metadata/sources/schema.json --aliases code/tools/metadata/sources/aliases.yaml --change-log code/tools/metadata/sources/change_log.yaml --check-generated --dictionary handmade_tables/dictionary.xlsx --digital-bib "documentation/BibTeX files/digital_library.bib"`
- One-shot unified migration:
  - `python3 code/tools/sources/migrate_unified_source_manager.py`
- Local UI:
  - `python3 code/tools/sources/ui_local.py`
- Migration reconciliation report:
  - `python3 code/tools/sources/reconcile_report.py --registry code/tools/metadata/sources/sources.yaml --bib "documentation/BibTeX files/digital_library.bib" --out code/tools/metadata/sources/reconciliation_report.md`

## Implementation Note

Data-source classification now works through an explicit `is_data_source` flag plus controlled BibTeX `keywords`. The Library editor maps selected data-source categories to `Data Sources: ...` keywords and maps selected research categories to the eight controlled research-topic keywords.

`digital_library.bib` is generated from `sources.yaml` only. The generator deduplicates by citekey, unions keywords, strips blocked fields such as `section`, preserves useful URL-like extra fields, and prefers data-source values for data-source links and warehouse metadata. `handmade_tables/dictionary.xlsx` is generated from data-source records only; multi-category data sources produce one `Sources` row per selected data-source category and one `SourceAliases` row per legacy source code.

Manual review is still required for reported conflicts in `title`, `author`, `year`, `journal`, `doi`, `publisher`, and `abstract`, plus any records listed as unresolved in `code/tools/metadata/sources/unified_source_manager_migration_report.md`.

Downstream website work should consume `documentation/BibTeX files/digital_library.bib` and filter using BibTeX `keywords`. The website should not depend on a BibTeX `section` field; public label mapping for controlled keywords can be handled on the website side later. Downstream warehouse code reads `SourceAliases` through `code/mainstream/auxiliar/harmonize_source_aliases.do`; `02a_append_dboards.do` no longer drops exact `WID`/`LWS` rows, `02b_prepare_metadata.do` canonicalizes topography metadata before export, and `03a_export_warehouses.do` canonicalizes both topography metadata and warehouse rows before source-based joins.
