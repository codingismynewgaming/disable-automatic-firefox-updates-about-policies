# Disable Automatic Firefox Updates (Organization Policy)

Small Windows scripts to toggle Firefox automatic updates through Mozilla organization policy.

The project sets or removes this registry policy value:

- `HKLM\SOFTWARE\Policies\Mozilla\Firefox\DisableAppUpdate` (`REG_DWORD`)

But dont forget to frequently update your Firefox in other ways! (E.g. manual updates, or via Uniget, etc)

## Overview

Use this project if you want a simple way to:

- Disable Firefox auto-updates (`DisableAppUpdate=1`)
- Re-enable Firefox auto-updates (remove `DisableAppUpdate`)
- Check current policy status

You can use either a GUI or CLI workflow.

## Features

- GUI toggle app (`firefox-update-toggle-gui.ps1`) with current status display (`ENABLED` / `DISABLED` / `UNKNOWN`)
- One-click actions for Disable, Enable, and Refresh
- Button to open `about:policies` in Firefox
- Automatic Windows theme detection plus manual Light/Dark switch
- CLI batch tool (`firefox-update-toggle.bat`) with `disable`, `enable`, `status`, and `help` commands

## Requirements

- Windows (PowerShell + `reg.exe` available)
- Administrator rights for `disable` / `enable`

## GUI Usage

1. Run `open-firefox-update-gui.bat`.
2. Click `Disable Updates` or `Enable Updates`.
3. Accept the UAC prompt.
4. Click `Refresh Status` to confirm the result.
5. Restart Firefox.
6. Verify in `about:policies`.

## CLI Usage

Interactive mode:

```bat
firefox-update-toggle.bat
```

Direct commands:

```bat
firefox-update-toggle.bat disable
firefox-update-toggle.bat enable
firefox-update-toggle.bat status
firefox-update-toggle.bat help
```

Notes:

- `disable` and `enable` require an elevated Command Prompt.
- `status` works without elevation.
- After changing policy, restart Firefox and verify in `about:policies`.

## Troubleshooting

- `This action requires Administrator privileges.`  
  Run the batch file as Administrator (or accept UAC from GUI).

- `Missing file: ...`  
  Keep all project files together in the same folder.

- GUI says Firefox was not found  
  Open Firefox manually and go to `about:policies`.

- Status seems unchanged after toggle  
  Fully close and reopen Firefox, then check `about:policies` again.

- Policy verification in Windows Registry:

```bat
reg query "HKLM\SOFTWARE\Policies\Mozilla\Firefox" /v DisableAppUpdate
```

## Screenshots

![Main GUI view](./Screenshot%202026-02-17%20224452.png)

![Status/details view](./Screenshot%202026-02-17%20224536.png)

![Policy action view](./Screenshot%202026-02-17%20224813.png)
