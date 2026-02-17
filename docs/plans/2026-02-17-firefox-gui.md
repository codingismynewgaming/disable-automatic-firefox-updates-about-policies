# Firefox Update WinForms GUI Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a no-terminal Windows GUI for toggling Firefox auto-update policy while reusing the existing batch policy logic.

**Architecture:** Add a PowerShell WinForms application as the primary UI layer and keep `firefox-update-toggle.bat` as the single source of truth for registry changes. The GUI invokes the batch script for `disable`, `enable`, and `status`; elevation is requested only for `disable` and `enable`. A launcher `.bat` starts the GUI so users can use double-click flow without opening a terminal.

**Tech Stack:** Windows Batch (`.bat`), PowerShell 5+ (`System.Windows.Forms`, `System.Drawing`), local Git

---

### Task 1: Build WinForms GUI Shell

**Files:**
- Create: `firefox-update-toggle-gui.ps1`

**Step 1: Write the failing test**

Add a syntax-smoke command target for the new file:

```powershell
powershell -NoProfile -Command "[System.Management.Automation.Language.Parser]::ParseFile('firefox-update-toggle-gui.ps1',[ref]$null,[ref]$null) | Out-Null; if($error.Count -gt 0){ exit 1 }"
```

**Step 2: Run test to verify it fails**

Run:

```powershell
powershell -NoProfile -Command "if(Test-Path 'firefox-update-toggle-gui.ps1'){exit 0}else{exit 1}"
```

Expected: FAIL because file does not exist yet.

**Step 3: Write minimal implementation**

Create `firefox-update-toggle-gui.ps1` with:
- WinForms window and title
- Buttons: Disable, Enable, Refresh Status, Open about:policies, Exit
- Status output area
- Shared helper that runs `firefox-update-toggle.bat <command>`
- Elevation only for Disable/Enable (`Start-Process -Verb RunAs`)
- Non-elevated calls for Status and Open about:policies
- User-facing restart reminder after policy change

**Step 4: Run test to verify it passes**

Run:

```powershell
powershell -NoProfile -Command "[void][System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms'); [System.Management.Automation.Language.Parser]::ParseFile('firefox-update-toggle-gui.ps1',[ref]$null,[ref]$null) | Out-Null; if($error.Count -gt 0){ exit 1 }"
```

Expected: PASS (exit code 0).

**Step 5: Commit**

```bash
git add firefox-update-toggle-gui.ps1
git commit -m "feat(gui): add winforms interface for firefox update policy toggle"
```

### Task 2: Add Double-Click Launcher + UX Copy

**Files:**
- Create: `open-firefox-update-gui.bat`
- Modify: `firefox-update-toggle.bat`

**Step 1: Write the failing test**

Run:

```powershell
powershell -NoProfile -Command "if(Test-Path 'open-firefox-update-gui.bat'){exit 0}else{exit 1}"
```

Expected: FAIL because launcher does not exist yet.

**Step 2: Run test to verify it fails**

Run:

```powershell
powershell -NoProfile -Command "Select-String -Path 'firefox-update-toggle.bat' -Pattern 'Restart Firefox' -SimpleMatch | Measure-Object | ForEach-Object { if($_.Count -ge 2){ exit 0 } else { exit 1 } }"
```

Expected: PASS currently (baseline check before copy adjustment).

**Step 3: Write minimal implementation**

- Add `open-firefox-update-gui.bat` to launch `firefox-update-toggle-gui.ps1` in STA mode using `powershell.exe -ExecutionPolicy Bypass`.
- Keep launcher silent/minimal and exit quickly.
- Update user copy in `firefox-update-toggle.bat` to explicitly remind: restart Firefox and verify in `about:policies`.

**Step 4: Run test to verify it passes**

Run:

```powershell
powershell -NoProfile -Command "if((Test-Path 'open-firefox-update-gui.bat') -and (Select-String -Path 'open-firefox-update-gui.bat' -Pattern 'firefox-update-toggle-gui.ps1' -SimpleMatch)){exit 0}else{exit 1}"
```

Expected: PASS.

**Step 5: Commit**

```bash
git add open-firefox-update-gui.bat firefox-update-toggle.bat
git commit -m "feat(gui): add no-terminal launcher and clearer restart verification guidance"
```

### Task 3: Validate End-to-End Flow + Local Git Setup

**Files:**
- Modify: `.gitignore` (optional, only if needed for local artifacts)

**Step 1: Write the failing test**

Run command checks before git init:

```powershell
git rev-parse --is-inside-work-tree
```

Expected: FAIL in current state (not a git repo).

**Step 2: Run test to verify it fails**

Run:

```powershell
powershell -NoProfile -Command "if(Test-Path '.git'){exit 0}else{exit 1}"
```

Expected: FAIL in current state.

**Step 3: Write minimal implementation**

- Initialize local repo: `git init`
- Run smoke checks:
  - `powershell -ExecutionPolicy Bypass -File .\firefox-update-toggle-gui.ps1` (manual visual run)
  - `cmd /c firefox-update-toggle.bat status`
  - Trigger GUI buttons manually: Disable/Enable/Status/Open about:policies
- Confirm no remote configured and no push operations.

**Step 4: Run test to verify it passes**

Run:

```powershell
git rev-parse --is-inside-work-tree
git remote -v
```

Expected: first command returns `true`; second prints no remotes.

**Step 5: Commit**

```bash
git add docs/plans/2026-02-17-firefox-gui.md
git commit -m "docs(plan): add firefox winforms gui implementation plan"
```
