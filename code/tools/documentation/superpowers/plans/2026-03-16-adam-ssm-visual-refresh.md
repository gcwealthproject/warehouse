# ADAM SSM Visual Refresh Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refresh the local source manager UI into the approved `Ledger Editorial` style and rename it to `ADAM SSM - Sleepless Source Manager` without changing workflow or validation behavior.

**Architecture:** Keep the implementation tightly scoped to the inline HTML/CSS/JS already embedded in `code/tools/sources/ui_local.py`. Add a small regression test module that imports the script file directly and asserts the presence of the new identity and presentation markers, then verify the finished UI in-browser across both branches and key states.

**Tech Stack:** Python 3, inline HTML/CSS/JavaScript in `ui_local.py`, `unittest`, local browser verification via the existing UI server

---

## File Map

- Modify: `code/tools/sources/ui_local.py`
  Responsibility: hold the app title, inline CSS theme, HTML structure, and existing client-side UI behavior.
- Create: `code/tools/sources/test_ui_local_html.py`
  Responsibility: verify the rendered HTML string exposes the approved branding and visual-system markers without needing to start the full server.
- Review only: `code/tools/source_manager_linux.sh`
  Responsibility: confirm launcher copy does not contradict the new app name.
- Review only: `code/tools/source_manager_mac.command`
  Responsibility: confirm launcher copy does not contradict the new app name.
- Review only: `code/tools/source_manager_win.bat`
  Responsibility: confirm launcher copy does not contradict the new app name.

## Chunk 1: Lock In Identity And Theme Tokens

### Task 1: Add a regression harness for the inline HTML document

**Files:**
- Create: `code/tools/sources/test_ui_local_html.py`
- Modify: `code/tools/sources/ui_local.py`
- Spec: `docs/superpowers/specs/2026-03-16-adam-ssm-visual-refresh-design.md`

- [ ] **Step 1: Write the failing test**

```python
import importlib.util
import pathlib
import sys
import unittest


def load_ui_local_module():
    path = pathlib.Path("code/tools/sources/ui_local.py").resolve()
    sys.path.insert(0, str(path.parent))
    spec = importlib.util.spec_from_file_location("ui_local", path)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


class UiLocalHtmlTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.html = load_ui_local_module().HTML

    def test_adam_ssm_branding_is_present(self):
        self.assertIn("ADAM SSM - Sleepless Source Manager", self.html)
        self.assertIn("<title>ADAM SSM - Sleepless Source Manager</title>", self.html)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 code/tools/sources/test_ui_local_html.py -v`
Expected: `FAIL` because the current title and visible heading still use `Source Registry UI` / `Source Registry Manager (Local)`.

- [ ] **Step 3: Write minimal implementation**

Update the inline HTML string in `code/tools/sources/ui_local.py` so the document title and visible heading use the approved app name, while the subtitle still explains that the UI validates and writes locally.

Concrete implementation target:

```html
<title>ADAM SSM - Sleepless Source Manager</title>
...
<h1>ADAM SSM - Sleepless Source Manager</h1>
<p class="app-subtitle">Local source-registry UI for validation and file writes.</p>
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python3 code/tools/sources/test_ui_local_html.py -v`
Expected: `OK`

- [ ] **Step 5: Commit**

```bash
git add code/tools/sources/test_ui_local_html.py code/tools/sources/ui_local.py
git commit -m "test: lock in ADAM SSM branding"
```

### Task 2: Add theme tokens for the approved editorial style

**Files:**
- Modify: `code/tools/sources/test_ui_local_html.py`
- Modify: `code/tools/sources/ui_local.py`
- Spec: `docs/superpowers/specs/2026-03-16-adam-ssm-visual-refresh-design.md`

- [ ] **Step 1: Write the failing test**

Extend `code/tools/sources/test_ui_local_html.py` with a second test that locks in the visual-system hooks:

```python
    def test_editorial_theme_tokens_are_defined(self):
        self.assertIn("--bg-page:", self.html)
        self.assertIn("--bg-panel:", self.html)
        self.assertIn("--accent-ink:", self.html)
        self.assertIn("--border-soft:", self.html)
        self.assertIn(".app-shell", self.html)
        self.assertIn(".app-subtitle", self.html)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 code/tools/sources/test_ui_local_html.py -v`
Expected: `FAIL` because the current CSS has no theme custom properties or app-shell/app-subtitle classes.

- [ ] **Step 3: Write minimal implementation**

Refactor the top of the inline `<style>` block in `code/tools/sources/ui_local.py` to introduce CSS custom properties and shell-level classes, without changing any behavior.

Concrete implementation target:

```css
:root {
  --bg-page: #f3ede2;
  --bg-panel: #fffdf8;
  --bg-input: #fffaf2;
  --accent-ink: #17324d;
  --accent-soft: #d8c7a6;
  --border-soft: #d8d1c3;
  --text-main: #1f2933;
  --text-muted: #5f6772;
}

body { background: var(--bg-page); color: var(--text-main); }
.app-shell { ... }
.app-subtitle { ... }
```

Use the new variables to restyle the page background, main container, and basic typography so the theme is centralized instead of hard-coded throughout the stylesheet.

- [ ] **Step 4: Run test to verify it passes**

Run: `python3 code/tools/sources/test_ui_local_html.py -v`
Expected: `OK`

- [ ] **Step 5: Commit**

```bash
git add code/tools/sources/test_ui_local_html.py code/tools/sources/ui_local.py
git commit -m "feat: add ADAM SSM editorial theme tokens"
```

## Chunk 2: Restyle Existing Components Without Changing Workflow

### Task 3: Apply the visual system to tabs, panels, inputs, and buttons

**Files:**
- Modify: `code/tools/sources/test_ui_local_html.py`
- Modify: `code/tools/sources/ui_local.py`
- Spec: `docs/superpowers/specs/2026-03-16-adam-ssm-visual-refresh-design.md`

- [ ] **Step 1: Write the failing test**

Extend `code/tools/sources/test_ui_local_html.py` with assertions for the component classes needed by the refresh:

```python
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
```

If `.panel` or `.section-heading` do not exist yet, this test should drive the small markup additions needed to wrap current sections consistently.

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 code/tools/sources/test_ui_local_html.py -v`
Expected: `FAIL` because the current UI does not yet expose the new panel/heading markers for the editorial treatment.

- [ ] **Step 3: Write minimal implementation**

Update `code/tools/sources/ui_local.py` to apply the approved styling to existing components only:

- wrap existing logical sections in shared panel classes where needed
- give section headings a consistent class
- restyle tabs as a segmented control
- restyle inputs/selects/textareas with warmer fills and stronger focus treatment
- restyle buttons so primary/secondary/destructive hierarchy is clearer
- style `details` / `summary` blocks so optional sections feel integrated

Do not change action order, field visibility logic, or branch structure.

- [ ] **Step 4: Run test to verify it passes**

Run: `python3 code/tools/sources/test_ui_local_html.py -v`
Expected: `OK`

- [ ] **Step 5: Commit**

```bash
git add code/tools/sources/test_ui_local_html.py code/tools/sources/ui_local.py
git commit -m "feat: restyle ADAM SSM shared UI components"
```

### Task 4: Improve status, search, and responsive presentation

**Files:**
- Modify: `code/tools/sources/test_ui_local_html.py`
- Modify: `code/tools/sources/ui_local.py`
- Spec: `docs/superpowers/specs/2026-03-16-adam-ssm-visual-refresh-design.md`

- [ ] **Step 1: Write the failing test**

Add one more test covering the remaining presentation hooks:

```python
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
```

Strengthen the responsive assertion if the finished CSS chooses a specific breakpoint string such as `@media (max-width: 960px)`.

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 code/tools/sources/test_ui_local_html.py -v`
Expected: `FAIL` if the responsive treatment and refreshed search/status styling hooks are not yet in place.

- [ ] **Step 3: Write minimal implementation**

Update the remaining style rules in `code/tools/sources/ui_local.py` so:

- search panels and result tables inherit the editorial surface treatment
- status containers remain `pre`-based but read as audit panels
- success/warning/failure colors still work against the new palette
- diff-highlight classes stay readable
- the existing mobile behavior is preserved or improved with an explicit responsive block

Keep all JS status rendering code and search behavior intact.

- [ ] **Step 4: Run test to verify it passes**

Run: `python3 code/tools/sources/test_ui_local_html.py -v`
Expected: `OK`

- [ ] **Step 5: Commit**

```bash
git add code/tools/sources/test_ui_local_html.py code/tools/sources/ui_local.py
git commit -m "feat: polish ADAM SSM status and responsive styles"
```

## Chunk 3: Verify The Finished UI End To End

### Task 5: Verify browser behavior and launcher consistency

**Files:**
- Modify: `code/tools/sources/ui_local.py` (only if final fixes are needed)
- Review only: `code/tools/source_manager_linux.sh`
- Review only: `code/tools/source_manager_mac.command`
- Review only: `code/tools/source_manager_win.bat`
- Spec: `docs/superpowers/specs/2026-03-16-adam-ssm-visual-refresh-design.md`

- [ ] **Step 1: Start the local UI**

Run: `python3 code/tools/sources/ui_local.py`
Expected: server starts successfully and reports `http://127.0.0.1:8765`

- [ ] **Step 2: Verify the finished UI in a browser**

In a second terminal or browser session, open `http://127.0.0.1:8765` and check all of the following:

- the visible title reads `ADAM SSM - Sleepless Source Manager`
- the subtitle still communicates local validation/file writes
- `Data Sources` and `Wealth Research` tabs both render with the new style
- add/edit mode toggles still reveal the same controls as before
- `BibTeX Paste`, optional `details` sections, search panels, and action areas remain usable
- status output remains readable for pass/warn/fail messages and diff output
- the page still works at a narrow viewport

Recommended automation path if Playwright is available:

```bash
export CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
export PWCLI="$CODEX_HOME/skills/playwright/scripts/playwright_cli.sh"
bash "$PWCLI" open http://127.0.0.1:8765 --headed
bash "$PWCLI" snapshot
```

If Playwright is unavailable, do the same verification manually in a browser.

- [ ] **Step 3: Review launcher scripts for copy drift**

Run: `sed -n '1,200p' code/tools/source_manager_linux.sh`
Run: `sed -n '1,200p' code/tools/source_manager_mac.command`
Run: `sed -n '1,200p' code/tools/source_manager_win.bat`
Expected: launcher scripts do not expose stale user-facing product naming; if they do, make the smallest copy-only update needed.

- [ ] **Step 4: Run the regression test suite**

Run: `python3 code/tools/sources/test_ui_local_html.py -v`
Expected: `OK`

- [ ] **Step 5: Commit**

```bash
git add code/tools/sources/ui_local.py code/tools/sources/test_ui_local_html.py code/tools/source_manager_linux.sh code/tools/source_manager_mac.command code/tools/source_manager_win.bat
git commit -m "feat: finalize ADAM SSM visual refresh"
```
