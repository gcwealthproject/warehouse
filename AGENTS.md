# AGENTS.md

## Purpose

This repository contains the GC Wealth Project data warehouse and its supporting tooling.

For agent work, the default and intended scope in this repository is the **source registry workflow**: the canonical source metadata, bibliography generation, validation, and the local source-management UI.

In short: this repo is large, but agents should work only on the source-registry subsystem unless the user explicitly says otherwise.

## Default Scope

Agents should limit changes to the source-registry area:

- `metadata/sources/`
- `code/tools/sources/`
- `documentation/workflow/sources/`
- `code/tools/source_manager_mac.command`
- `code/tools/source_manager_win.bat`
- `code/tools/source_manager_linux.sh`
- `.github/workflows/sources-*`

Generated artifacts may also be updated when required by source-registry work:

- `documentation/BibTeX files/GCWealthProject_DataSourcesLibrary.bib`
- `documentation/BibTeX files/GCWealthProject_WealthResearchLibrary.bib`
- `documentation/BibTeX files/BothLibraries.bib`
- `handmade_tables/dictionary.xlsx`
- `metadata/sources/reconciliation_report.md`

## Out Of Scope By Default

Unless the user explicitly requests it, do **not** modify:

- `code/mainstream/`
- `code/dashboards/`
- Stata pipeline logic
- warehouse exports under `output/`
- non-source-registry documentation
- unrelated metadata, tables, logos, or research assets

Do not make opportunistic cleanup changes outside the source-registry subsystem.

## Working Rules

- Prefer the canonical registry workflow over ad hoc edits.
- Treat `metadata/sources/sources.yaml` as the canonical store for Data Sources.
- Treat generated files as derived artifacts, not primary editing targets, unless the workflow specifically requires them.
- Prefer using the local source-registry tools and validation scripts in `code/tools/sources/`.
- If a request would require touching both the source registry and the broader warehouse pipeline, stop and ask for explicit confirmation before expanding scope.

## Workflow selection

- For trivial or clearly bounded tasks, use a standard single-agent plan-and-implement workflow.
- For non-trivial, cross-cutting, architectural, or multi-file tasks, invoke the `team-architect` skill before implementation.
- Prefer the smallest workflow that safely handles the task.
- Once a workflow is chosen, follow it rather than expanding scope mid-task.

## Summary

The source-registry subsystem exists to manage source metadata in a controlled way and generate the dictionary and bibliography artifacts used by the GC Wealth Project. Agent work in this repository should stay focused on that subsystem and leave the rest of the warehouse untouched unless the user clearly instructs otherwise.
