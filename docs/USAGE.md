# Usage Guide

## What This Tool Changes

The scripts control Firefox updates through this Windows policy value:

- Key: `HKLM\SOFTWARE\Policies\Mozilla\Firefox`
- Value: `DisableAppUpdate` (`REG_DWORD`)

Meaning:

- `1` => updates disabled
- value removed => updates enabled

## GUI Steps (Recommended)

1. Run `open-firefox-update-gui.bat`.
2. Click `Disable Updates` or `Enable Updates`.
3. Approve the UAC prompt.
4. Wait for the confirmation message.
5. Click `Refresh Status` and confirm the shown state.
6. Restart Firefox completely.
7. Open `about:policies` and verify policy state.

Verification note:

- If disabled, `DisableAppUpdate` should appear as active policy.
- If enabled, `DisableAppUpdate` should no longer be active.

## CLI Steps

### Disable updates

1. Open Command Prompt as Administrator.
2. Run:

```bat
firefox-update-toggle.bat disable
```

3. Restart Firefox.
4. Open `about:policies` and verify.

### Enable updates

1. Open Command Prompt as Administrator.
2. Run:

```bat
firefox-update-toggle.bat enable
```

3. Restart Firefox.
4. Open `about:policies` and verify.

### Check status only

```bat
firefox-update-toggle.bat status
```

## Common Notes

- `disable` and `enable` require admin privileges.
- `status` does not require elevation.
- Firefox must be restarted after every policy change.
- `about:policies` is the source of truth inside Firefox.

