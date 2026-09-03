import importlib.util
import json
import pathlib
import sys
import tempfile
import unittest
from unittest import mock

SOURCE_DIR = pathlib.Path("code/tools/sources").resolve()
if str(SOURCE_DIR) not in sys.path:
    sys.path.insert(0, str(SOURCE_DIR))

from source_paths import (
    DEFAULT_ALIASES_PATH,
    DEFAULT_CHANGE_LOG_PATH,
    DEFAULT_DATA_BIB_PATH,
    DEFAULT_DICTIONARY_PATH,
    DEFAULT_REGISTRY_PATH,
    DEFAULT_WEALTH_BIB_PATH,
    DEFAULT_WEALTH_CHANGE_LOG_PATH,
)
from common import DEFAULT_REGISTRY


def load_ui_local_module():
    path = pathlib.Path("code/tools/sources/ui_local.py").resolve()
    sys.path.insert(0, str(path.parent))
    spec = importlib.util.spec_from_file_location("ui_local", path)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


def extract_js_function(html, name):
    start = html.index(f"function {name}(")
    open_paren = html.index("(", start)
    paren_depth = 0
    close_paren = -1
    for idx in range(open_paren, len(html)):
        char = html[idx]
        if char == "(":
            paren_depth += 1
        elif char == ")":
            paren_depth -= 1
            if paren_depth == 0:
                close_paren = idx
                break
    if close_paren == -1:
        raise AssertionError(f"Could not find JavaScript function parameters: {name}")
    brace = html.index("{", close_paren)
    depth = 0
    for idx in range(brace, len(html)):
        char = html[idx]
        if char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return html[start : idx + 1]
    raise AssertionError(f"Could not extract JavaScript function: {name}")


class UiLocalHtmlTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.mod = load_ui_local_module()
        cls.html = cls.mod.HTML

    def js_function(self, name):
        return extract_js_function(self.html, name)

    def test_adam_ssm_branding_is_present(self):
        self.assertIn("ADAM SSM - Sleepless Source Manager", self.html)
        self.assertIn("<title>ADAM SSM - Sleepless Source Manager</title>", self.html)

    def test_beforeunload_dirty_warning_remains_without_unload_shutdown(self):
        self.assertIn("window.addEventListener('beforeunload'", self.html)
        self.assertIn("e.returnValue = '';", self.html)
        self.assertNotIn("window.addEventListener('unload'", self.html)
        self.assertNotIn("navigator.sendBeacon('/api/shutdown'", self.html)
        self.assertIn("id='shutdown_app_button'", self.html)
        self.assertIn("async function shutdownApp()", self.html)
        self.assertIn("await req('/api/shutdown', {})", self.html)
        self.assertIn('self.path == "/api/shutdown"', pathlib.Path("code/tools/sources/ui_local.py").read_text(encoding="utf-8"))

    def test_port_candidates_use_requested_port_then_fallback_range(self):
        self.assertEqual(self.mod.port_candidates(8765, 8767), [8765, 8766, 8767])
        self.assertEqual(self.mod.port_candidates(8770, 8772), [8770, 8771, 8772])
        self.assertEqual(self.mod.port_candidates(8790, 8785), [8790])

    def test_create_server_with_port_fallback_uses_requested_port_when_free(self):
        fake_server = object()
        with mock.patch.object(self.mod, "ThreadingHTTPServer", return_value=fake_server) as server_factory:
            server, port = self.mod.create_server_with_port_fallback("127.0.0.1", 8765, object, 8767)

        self.assertIs(server, fake_server)
        self.assertEqual(port, 8765)
        server_factory.assert_called_once_with(("127.0.0.1", 8765), object)

    def test_create_server_with_port_fallback_scans_upward(self):
        fake_server = object()
        with mock.patch.object(
            self.mod,
            "ThreadingHTTPServer",
            side_effect=[OSError("busy"), fake_server],
        ) as server_factory:
            server, port = self.mod.create_server_with_port_fallback("127.0.0.1", 8765, object, 8766)

        self.assertIs(server, fake_server)
        self.assertEqual(port, 8766)
        self.assertEqual(
            server_factory.call_args_list,
            [
                mock.call(("127.0.0.1", 8765), object),
                mock.call(("127.0.0.1", 8766), object),
            ],
        )

    def test_create_server_with_port_fallback_reports_no_available_ports(self):
        with mock.patch.object(self.mod, "ThreadingHTTPServer", side_effect=OSError("busy")):
            with self.assertRaisesRegex(OSError, "8765 through 8766"):
                self.mod.create_server_with_port_fallback("127.0.0.1", 8765, object, 8766)

    def test_open_browser_main_path_waits_until_after_bind(self):
        events = []

        class FakeServer:
            def serve_forever(self):
                events.append("serve")

        def fake_create_server(host, port, handler_cls):
            events.append(("bind", host, port, handler_cls.__name__))
            return FakeServer(), port

        def fake_open_browser(url):
            events.append(("open", url))
            return True

        argv = [
            "ui_local.py",
            "--host",
            "127.0.0.1",
            "--port",
            "8765",
            "--open-browser",
        ]
        with mock.patch.object(self.mod.sys, "argv", argv), \
             mock.patch.object(self.mod, "create_server_with_port_fallback", side_effect=fake_create_server), \
             mock.patch.object(self.mod, "open_browser", side_effect=fake_open_browser):
            self.assertEqual(self.mod.main(), 0)

        self.assertEqual(events[0][:3], ("bind", "127.0.0.1", 8765))
        self.assertEqual(events[1], ("open", "http://127.0.0.1:8765"))
        self.assertEqual(events[2], "serve")

    def test_editorial_theme_tokens_are_defined(self):
        self.assertIn("--bg-page:", self.html)
        self.assertIn("--bg-panel:", self.html)
        self.assertIn("--accent-ink:", self.html)
        self.assertIn("--border-soft:", self.html)
        self.assertIn(".app-shell", self.html)
        self.assertIn(".app-subtitle", self.html)

    def test_shared_component_classes_exist(self):
        for marker in [
            ".branch-tabs",
            ".branch-tab.active",
            ".panel",
            ".section-heading",
            ".help",
            "details",
            "summary",
            "button.secondary",
            "button.warn",
        ]:
            self.assertIn(marker, self.html)

    def test_status_search_and_responsive_hooks_exist(self):
        for marker in [
            ".search-panel",
            ".search-results",
            "#status",
            "#wealth_status",
            ".status-ok",
            ".status-fail",
            ".status-warn",
            "@media (max-width:",
        ]:
            self.assertIn(marker, self.html)

    def test_wealth_online_compare_hooks_exist(self):
        for marker in [
            "onclick='wealthCompareOnlineBib()'",
            "async function wealthCompareOnlineBib()",
            "/api/wealth/compare_online_bib",
            "targetId: 'wealth_status'",
        ]:
            self.assertIn(marker, self.html)

    def test_status_renderer_supports_post_save_next_message(self):
        body = self.js_function("setStatusWithChecks")
        self.assertIn("const nextMessage = opts.nextMessage || '';", body)
        self.assertIn("if (nextMessage) lines.push(nextMessage);", body)

    def test_data_add_save_resets_entry_fields_but_preserves_editor(self):
        body = self.js_function("resetDataAddFormAfterSave")
        for marker in [
            "'bib_paste'",
            "'section'",
            "'aggsource'",
            "'legend'",
            "'source_key'",
            "'link'",
            "'metadata'",
            "'bib_entry_type'",
            "'bib_abstract'",
            "loadedSourceKey = ''",
            "delete document.getElementById('legend').dataset.userEdited",
            "onEntryTypeChange()",
            "clearDirty()",
            "next.focus()",
        ]:
            self.assertIn(marker, body)
        self.assertNotIn("'editor_name'", body)

    def test_data_add_save_reset_only_runs_after_non_empty_add_success(self):
        body = self.js_function("applyAndBuild")
        self.assertIn("const emptyAddPayload = isEmptyAddPayload(payload);", body)
        self.assertIn("const out = await req('/api/apply_and_build', payload);", body)
        self.assertIn(
            "const addReadyMessage = (payload.mode === 'add' && !emptyAddPayload) ? 'Next: The form was cleared and is ready for another entry.' : '';",
            body,
        )
        self.assertIn("setStatusWithChecks(out, 'Save complete.', {nextMessage: addReadyMessage});", body)
        self.assertIn("if (payload.mode === 'add' && !emptyAddPayload) {", body)
        self.assertIn("resetDataAddFormAfterSave();", body)
        self.assertIn("loadedSourceValue = v('source_value');", body)
        self.assertIn("loadedCitekeyValue = v('citekey_value');", body)
        self.assertIn("clearDirty();", body)

    def test_wealth_add_save_resets_entry_fields_but_preserves_editor(self):
        body = self.js_function("resetWealthAddFormAfterSave")
        for marker in [
            "'wealth_bib_paste'",
            "'wealth_target'",
            "'wealth_key'",
            "'wealth_entry_type'",
            "'wealth_title'",
            "'wealth_author'",
            "'wealth_year'",
            "'wealth_abstract'",
            "document.getElementById('wealth_extra_fields').value = '{}';",
            "wealthLoadedKey = ''",
            "wealthOnEntryTypeChange()",
            "clearWealthDirty()",
            "next.focus()",
        ]:
            self.assertIn(marker, body)
        self.assertNotIn("'wealth_editor_name'", body)

    def test_wealth_add_save_reset_only_runs_after_non_empty_add_success(self):
        body = self.js_function("wealthApplyAndBuild")
        self.assertIn("const emptyAddPayload = wealthIsEmptyAddPayload(payload);", body)
        self.assertIn("const out = await req('/api/wealth/apply_and_build', payload);", body)
        self.assertIn(
            "const addReadyMessage = (payload.mode === 'add' && !emptyAddPayload) ? 'Next: The form was cleared and is ready for another entry.' : '';",
            body,
        )
        self.assertIn("nextMessage: addReadyMessage", body)
        self.assertIn("if (payload.mode === 'add' && !emptyAddPayload) {", body)
        self.assertIn("resetWealthAddFormAfterSave();", body)
        self.assertIn("} else {\n      clearWealthDirty();\n    }", body)

    def test_default_registry_contains_wealth_online_compare_config(self):
        cfg = DEFAULT_REGISTRY["config"]
        self.assertIn("online_bib_reference_url", cfg)
        self.assertIn("online_bib_timeout_seconds", cfg)
        self.assertIn("wealth_online_bib_reference_url", cfg)
        self.assertIn("wealth_online_bib_timeout_seconds", cfg)

    def test_online_compare_uses_selected_library_config(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            root = pathlib.Path(tmpdir)
            data_path = root / DEFAULT_DATA_BIB_PATH
            wealth_path = root / DEFAULT_WEALTH_BIB_PATH
            data_path.parent.mkdir(parents=True, exist_ok=True)
            data_path.write_text("@misc{data,\n  title = {Data}\n}\n", encoding="utf-8")
            wealth_path.write_text("@article{wealth,\n  title = {Wealth}\n}\n", encoding="utf-8")
            registry = {
                "config": {
                    "bib_output": str(data_path),
                    "wealth_bib_input": str(wealth_path),
                    "online_bib_reference_url": "https://example.test/data.bib",
                    "online_bib_timeout_seconds": 3,
                    "wealth_online_bib_reference_url": "https://example.test/wealth.bib",
                    "wealth_online_bib_timeout_seconds": 4,
                }
            }
            calls = []

            def fake_fetch(url, timeout_seconds):
                calls.append((url, timeout_seconds))
                if url.endswith("/wealth.bib"):
                    return {"text": wealth_path.read_text(encoding="utf-8"), "method": "test"}
                return {"text": data_path.read_text(encoding="utf-8"), "method": "test"}

            original_fetch = self.mod._fetch_url_text
            self.mod._fetch_url_text = fake_fetch
            try:
                data_out = self.mod.compare_local_bib_with_online(registry)
                wealth_out = self.mod.compare_local_bib_with_online(registry, "wealth_research")
            finally:
                self.mod._fetch_url_text = original_fetch

            self.assertEqual(data_out["library"], "data_sources")
            self.assertEqual(data_out["library_label"], "Data Sources")
            self.assertEqual(data_out["local_bib_path"], str(data_path))
            self.assertEqual(data_out["reference_url"], "https://example.test/data.bib")
            self.assertEqual(data_out["timeout_seconds"], 3)
            self.assertEqual(data_out["status"], "up_to_date")
            self.assertEqual(wealth_out["library"], "wealth_research")
            self.assertEqual(wealth_out["library_label"], "Wealth Research")
            self.assertEqual(wealth_out["local_bib_path"], str(wealth_path))
            self.assertEqual(wealth_out["reference_url"], "https://example.test/wealth.bib")
            self.assertEqual(wealth_out["timeout_seconds"], 4)
            self.assertEqual(wealth_out["status"], "up_to_date")
            self.assertEqual(
                calls,
                [
                    ("https://example.test/data.bib", 3),
                    ("https://example.test/wealth.bib", 4),
                ],
            )

    def test_ref_link_review_action_and_panel_hooks_exist(self):
        for marker in [
            "Review ref_link proposals",
            "ref_link_review_modal",
            "ref_link_review_panel",
            "Apply selected",
            "Refresh scan",
            "Dismiss selected",
            "/api/ref_link_review_scan",
            "/api/ref_link_review_apply",
        ]:
            self.assertIn(marker, self.html)

    def test_ref_link_review_apply_message_keeps_escaped_newlines(self):
        self.assertIn("fileList.join('\\n- ')", self.html)
        self.assertNotIn("fileList.join('\n- ')", self.html)
        self.assertIn(DEFAULT_REGISTRY_PATH, self.html)
        self.assertIn(DEFAULT_CHANGE_LOG_PATH, self.html)

    def test_ref_link_review_simplified_workspace_hooks_exist(self):
        for marker in [
            "ref_link_review_modal",
            "ref_link_review_close",
            "ref_link_review_benchmark_url",
            "ref_link_review_filter_button_status",
            "ref_link_review_filter_button_confidence",
            "ref_link_review_filter_button_reason",
            "Clear filters",
            "Select visible",
            "Unselect visible",
            "Bulk actions apply only to the rows currently visible",
            "Restore selected",
            "setRefLinkReviewMultiSelectValues",
            "filteredRefLinkReviewRows",
            "renderRefLinkReviewUrl",
        ]:
            self.assertIn(marker, self.html)

    def test_ref_link_review_repeated_bucket_actions_are_removed(self):
        self.assertNotIn("Select filtered", self.html)
        self.assertNotIn("Unselect filtered", self.html)

    def test_ref_link_review_progress_details_override_and_resize_hooks_exist(self):
        for marker in [
            "ref_link_review_scan_status",
            "ref_link_review_scan_progress",
            "ref_link_review_scan_progress_label",
            "ref_link_review_scan_progress_fill",
            "toggleRefLinkReviewDetails",
            "updateRefLinkReviewOverride",
            "ref_link_review_override_input",
            "beginRefLinkReviewColumnResize",
            "ref_link_review_resize_handle",
            "/api/ref_link_review_scan_status",
        ]:
            self.assertIn(marker, self.html)

    def test_ref_link_review_compact_benchmark_and_toolbar_hooks_exist(self):
        for marker in [
            "ref-link-review-toolbar-note",
            "ref-link-review-benchmark-meta",
            "ref-link-review-benchmark-actions",
            "ref-link-review-toolbar-summary",
            "Benchmark:",
            "Last scan used:",
        ]:
            self.assertIn(marker, self.html)
        self.assertNotIn("Configured default:", self.html)

    def test_ref_link_review_tray_shell_hooks_exist(self):
        for marker in [
            "ref_link_review_topbar",
            "ref_link_review_topbar_summary",
            "ref_link_review_tray",
            "ref_link_review_tray_resize_handle",
            "ref_link_review_tray_sections",
            "ref_link_review_tray_section_filters",
            "ref_link_review_tray_section_benchmark",
            "ref_link_review_tray_section_actions",
            "ref_link_review_tray_section_help",
        ]:
            self.assertIn(marker, self.html)

    def test_ref_link_review_tray_interaction_hooks_exist(self):
        for marker in [
            "toggleRefLinkReviewTraySection",
            "ref_link_review_tray_section_header_filters",
            "ref_link_review_tray_section_header_benchmark",
            "ref_link_review_tray_section_header_actions",
            "ref_link_review_tray_section_header_help",
            "toggleRefLinkReviewFilterPopover",
            "ref_link_review_filter_popover_status",
            "ref_link_review_filter_popover_confidence",
            "ref_link_review_filter_popover_reason",
            "ref-link-review-filter-popover",
            "refLinkReviewReasonLabel",
            "ref-link-review-topbar-status-line",
        ]:
            self.assertIn(marker, self.html)

    def test_ref_link_review_tray_resize_and_responsive_hooks_exist(self):
        for marker in [
            "beginRefLinkReviewTrayResize",
            "applyRefLinkReviewTrayWidth",
            "refLinkReviewClampTrayWidth",
            "toggleRefLinkReviewTrayOpen",
            "ref_link_review_tray_toggle_button",
            "beginRefLinkReviewModalResize",
            "applyRefLinkReviewModalSize",
            "ref_link_review_modal_resize_handle",
        ]:
            self.assertIn(marker, self.html)

    def test_history_tab_restore_guidance_and_cleanup_hooks_exist(self):
        for marker in [
            "branch_history_tab",
            "Show Changes Up To",
            "Restore Guidance",
            "Remove History Record",
            "Filter to this time",
            "Removes history records only. Source records and generated files are not changed.",
            "/api/history",
            "/api/history/delete_entry",
            "history_summary_strip",
            "history_cleanup_reason",
            "history_cleanup_reason_suggestions",
            "historyApplyCleanupReason('testing noise')",
            "Remove History Records For This Source",
            "cleanup_scope",
            "Relaunch App",
            "/api/relaunch",
            "relaunchApp()",
        ]:
            self.assertIn(marker, self.html)

    def test_maintenance_tab_and_hybrid_key_hooks_exist(self):
        for marker in [
            "branch_maintenance_tab",
            "branch_maintenance",
            "source_value",
            "citekey_value",
            "shared_citekey_group",
            "shared_citekey_note",
            "/api/maintenance/health",
            "/api/maintenance/rebuild_artifacts",
            "/api/maintenance/normalize_citekey",
            "/api/maintenance/mark_shared_citekey",
            "/api/maintenance/bulk_label_preview",
            "/api/maintenance/bulk_label_apply",
            "maintenanceLoad()",
            "maintenanceNormalizeCitekey",
            "maintenanceMarkSharedCitekey",
            "Bulk Label Update",
            "bulk_label_field",
            "bulk_label_old",
            "bulk_label_new",
            "bulk_label_preview_results",
            "maintenanceBulkLabelPreview",
            "maintenanceBulkLabelApply",
            "maintenanceBulkLabelSelectAll",
        ]:
            self.assertIn(marker, self.html)

    def test_ref_link_review_compact_topbar_scan_hooks_exist(self):
        for marker in [
            "ref-link-review-scan-status-compact",
            "ref-link-review-title-line",
            "height = refLinkReviewClampModalHeight",
            "repeat(auto-fit, minmax(132px, 1fr))",
            "min-width: max(100%, 240px)",
        ]:
            self.assertIn(marker, self.html)

    def test_build_file_change_summary_matches_new_metadata_paths(self):
        summary = self.mod.build_file_change_summary(
            [
                f"/tmp/{DEFAULT_REGISTRY_PATH}",
                f"/tmp/{DEFAULT_CHANGE_LOG_PATH}",
                f"/tmp/{DEFAULT_ALIASES_PATH}",
                "handmade_tables/dictionary.xlsx",
            ],
            "edit",
            "src-example",
            ["source", "bib.title"],
            key_renamed=True,
        )
        summaries = {entry["file"]: entry["summary"] for entry in summary}
        self.assertIn("Updated record src-example.", summaries[f"/tmp/{DEFAULT_REGISTRY_PATH}"])
        self.assertIn("Added edit history record", summaries[f"/tmp/{DEFAULT_CHANGE_LOG_PATH}"])
        self.assertEqual(
            summaries[f"/tmp/{DEFAULT_ALIASES_PATH}"],
            "Added Source/Citekey alias mappings for key rename.",
        )
        self.assertEqual(
            summaries["handmade_tables/dictionary.xlsx"],
            "Regenerated Sources sheet from canonical registry.",
        )

    def test_build_file_change_summary_reports_bulk_label_update(self):
        summary = self.mod.build_file_change_summary(
            [f"/tmp/{DEFAULT_REGISTRY_PATH}", f"/tmp/{DEFAULT_CHANGE_LOG_PATH}"],
            "bulk_label_update",
            "data_type:Old->New",
            ["data_type"],
        )
        summaries = {entry["file"]: entry["summary"] for entry in summary}
        self.assertIn("Bulk-updated data_type:Old->New.", summaries[f"/tmp/{DEFAULT_REGISTRY_PATH}"])
        self.assertIn("Added bulk_label_update history record", summaries[f"/tmp/{DEFAULT_CHANGE_LOG_PATH}"])

    def test_build_file_change_summary_matches_new_wealth_log_path(self):
        summary = self.mod.build_file_change_summary(
            [f"/tmp/{DEFAULT_WEALTH_CHANGE_LOG_PATH}"],
            "delete",
            "wealth-key",
            [],
        )
        self.assertEqual(
            summary[0]["summary"],
            "Added delete Wealth Research history record for wealth-key.",
        )

    def test_build_ref_link_review_summary_matches_new_metadata_paths(self):
        summary = self.mod.build_ref_link_review_file_change_summary(
            [f"/tmp/{DEFAULT_REGISTRY_PATH}", f"/tmp/{DEFAULT_CHANGE_LOG_PATH}"],
            ["src-a", "src-b"],
        )
        summaries = {entry["file"]: entry["summary"] for entry in summary}
        self.assertEqual(
            summaries[f"/tmp/{DEFAULT_REGISTRY_PATH}"],
            "Updated ref_link for 2 record(s).",
        )
        self.assertEqual(
            summaries[f"/tmp/{DEFAULT_CHANGE_LOG_PATH}"],
            "Added 2 ref_link review history records.",
        )

    def test_history_file_descriptors_cover_data_registry_and_cleanup_paths(self):
        files = self.mod._history_file_descriptors(
            "data_sources",
            "edit",
            "Edited via local UI",
            pathlib.Path(DEFAULT_REGISTRY_PATH),
            pathlib.Path(DEFAULT_CHANGE_LOG_PATH),
            pathlib.Path(DEFAULT_ALIASES_PATH),
            {},
        )
        indexed = {entry["path"]: entry for entry in files}
        ordered_paths = [entry["path"] for entry in files]
        self.assertIn(DEFAULT_REGISTRY_PATH, indexed)
        self.assertIn(DEFAULT_CHANGE_LOG_PATH, indexed)
        self.assertIn(DEFAULT_ALIASES_PATH, indexed)
        self.assertTrue(indexed[DEFAULT_ALIASES_PATH]["optional"])
        self.assertEqual(ordered_paths[0], self.mod.DEFAULT_DICTIONARY_PATH)
        self.assertTrue(ordered_paths[1].endswith('.bib'))
        self.assertTrue(ordered_paths[2].endswith('.bib'))

    def test_delete_history_entry_removes_selected_row(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            log_path = pathlib.Path(tmpdir) / "change_log.json"
            log_path.write_text(
                json.dumps(
                    {
                        "changes": [
                            {"operation": "add", "record_id": "src-a", "reason": "test", "updated_at": "2026-03-24T10:00:00Z"},
                            {"operation": "edit", "record_id": "src-b", "reason": "test", "updated_at": "2026-03-24T11:00:00Z"},
                        ]
                    },
                    indent=2,
                )
                + "\n",
                encoding="utf-8",
            )
            removed = self.mod.delete_history_entry(log_path, 0)
            remaining = json.loads(log_path.read_text(encoding="utf-8"))
            self.assertEqual(removed["record_id"], "src-a")
            self.assertEqual(len(remaining["changes"]), 1)
            self.assertEqual(remaining["changes"][0]["record_id"], "src-b")


    def test_delete_history_entries_for_record_only_updates_history_log(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            root = pathlib.Path(tmpdir)
            log_path = root / "change_log.json"
            source_path = root / DEFAULT_REGISTRY_PATH
            dictionary_path = root / DEFAULT_DICTIONARY_PATH
            bib_path = root / "documentation/BibTeX files/GCWealthProject_DataSourcesLibrary.bib"
            for path, content in [
                (
                    log_path,
                    json.dumps(
                        {
                            "changes": [
                                {"operation": "add", "record_id": "src-a", "reason": "test", "updated_at": "2026-03-24T10:00:00Z"},
                                {"operation": "edit", "record_id": "src-a", "reason": "test", "updated_at": "2026-03-24T11:00:00Z"},
                                {"operation": "delete", "record_id": "src-b", "reason": "test", "updated_at": "2026-03-24T12:00:00Z"},
                            ]
                        },
                        indent=2,
                    )
                    + "\n",
                ),
                (source_path, '{"records": [{"id": "src-a"}]}\n'),
                (dictionary_path, "dictionary bytes"),
                (bib_path, "@article{a}\n"),
            ]:
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(content, encoding="utf-8")

            before = {
                source_path: source_path.read_text(encoding="utf-8"),
                dictionary_path: dictionary_path.read_text(encoding="utf-8"),
                bib_path: bib_path.read_text(encoding="utf-8"),
            }
            removed = self.mod.delete_history_entries_for_record(log_path, "src-a")

            remaining = json.loads(log_path.read_text(encoding="utf-8"))
            self.assertEqual(len(removed), 2)
            self.assertEqual(len(remaining["changes"]), 1)
            self.assertEqual(remaining["changes"][0]["record_id"], "src-b")
            for path, content in before.items():
                self.assertEqual(path.read_text(encoding="utf-8"), content)


    def test_delete_history_entries_for_record_removes_all_matching_rows(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            log_path = pathlib.Path(tmpdir) / "change_log.json"
            log_path.write_text(
                json.dumps(
                    {
                        "changes": [
                            {"operation": "add", "record_id": "src-a", "reason": "test", "updated_at": "2026-03-24T10:00:00Z"},
                            {"operation": "edit", "record_id": "src-a", "reason": "test", "updated_at": "2026-03-24T11:00:00Z"},
                            {"operation": "delete", "record_id": "src-b", "reason": "test", "updated_at": "2026-03-24T12:00:00Z"},
                        ]
                    },
                    indent=2,
                )
                + "\n",
                encoding="utf-8",
            )
            removed = self.mod.delete_history_entries_for_record(log_path, "src-a")
            remaining = json.loads(log_path.read_text(encoding="utf-8"))
            self.assertEqual(len(removed), 2)
            self.assertEqual([entry["record_id"] for entry in removed], ["src-a", "src-a"])
            self.assertEqual(len(remaining["changes"]), 1)
            self.assertEqual(remaining["changes"][0]["record_id"], "src-b")


if __name__ == "__main__":
    unittest.main()
