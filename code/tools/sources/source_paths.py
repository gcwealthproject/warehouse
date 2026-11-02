#!/usr/bin/env python3
"""Shared path contract for the source registry tooling."""

from pathlib import PurePosixPath

DEFAULT_REGISTRY_PATH = "code/tools/metadata/sources/sources.yaml"
DEFAULT_SCHEMA_PATH = "code/tools/metadata/sources/schema.json"
DEFAULT_ALIASES_PATH = "code/tools/metadata/sources/aliases.yaml"
DEFAULT_CHANGE_LOG_PATH = "code/tools/metadata/sources/change_log.yaml"
DEFAULT_WEALTH_CHANGE_LOG_PATH = "code/tools/metadata/sources/wealth_research_change_log.yaml"
DEFAULT_RECONCILIATION_REPORT_PATH = "code/tools/metadata/sources/reconciliation_report.md"
DEFAULT_DIGITAL_LIBRARY_MIGRATION_REPORT_PATH = "code/tools/metadata/sources/digital_library_migration_report.md"
DEFAULT_UNIFIED_SOURCE_MANAGER_MIGRATION_REPORT_PATH = "code/tools/metadata/sources/unified_source_manager_migration_report.md"

DEFAULT_DIGITAL_BIB_PATH = "documentation/BibTeX files/digital_library.bib"
DEFAULT_DATA_BIB_PATH = "documentation/BibTeX files/GCWealthProject_DataSourcesLibrary.bib"
DEFAULT_WEALTH_BIB_PATH = "documentation/BibTeX files/GCWealthProject_WealthResearchLibrary.bib"
DEFAULT_BOTH_BIB_PATH = "documentation/BibTeX files/BothLibraries.bib"
DEFAULT_OLD_DATA_BIB_PATH = "documentation/BibTeX files/old/GCWealthProject_DataSourcesLibrary.bib"
DEFAULT_OLD_WEALTH_BIB_PATH = "documentation/BibTeX files/old/GCWealthProject_WealthResearchLibrary.bib"
DEFAULT_OLD_BOTH_BIB_PATH = "documentation/BibTeX files/old/BothLibraries.bib"
DEFAULT_DICTIONARY_PATH = "handmade_tables/dictionary.xlsx"


def normalize_repo_path_text(path_value) -> str:
    return PurePosixPath(str(path_value).replace("\\", "/")).as_posix()


def path_matches(path_value, repo_relative_path: str) -> bool:
    candidate = normalize_repo_path_text(path_value)
    target = normalize_repo_path_text(repo_relative_path)
    return candidate == target or candidate.endswith("/" + target)
