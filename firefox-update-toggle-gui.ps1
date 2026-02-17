[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$batchPath = Join-Path -Path $PSScriptRoot -ChildPath "firefox-update-toggle.bat"

if (-not (Test-Path -LiteralPath $batchPath)) {
    [System.Windows.Forms.MessageBox]::Show(
        "Missing file: $batchPath",
        "Firefox Update Toggle",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
    exit 1
}

function Invoke-StatusCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string]$BatchFile
    )

    $lines = & $BatchFile status 2>&1
    $exitCode = $LASTEXITCODE
    $text = ($lines | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine

    [pscustomobject]@{
        ExitCode = $exitCode
        Output   = $text.Trim()
    }
}

function Invoke-PolicyCommandElevated {
    param(
        [Parameter(Mandatory = $true)]
        [string]$BatchFile,
        [Parameter(Mandatory = $true)]
        [ValidateSet("disable", "enable")]
        [string]$Action
    )

    $argList = "/c `"$BatchFile`" $Action"

    try {
        $proc = Start-Process -FilePath "cmd.exe" -ArgumentList $argList -Verb RunAs -WindowStyle Hidden -Wait -PassThru
        return [pscustomobject]@{
            ExitCode    = $proc.ExitCode
            UserCanceled = $false
            ErrorText   = ""
        }
    } catch [System.ComponentModel.Win32Exception] {
        if ($_.Exception.NativeErrorCode -eq 1223) {
            return [pscustomobject]@{
                ExitCode    = $null
                UserCanceled = $true
                ErrorText   = "UAC prompt was canceled."
            }
        }

        return [pscustomobject]@{
            ExitCode    = $null
            UserCanceled = $false
            ErrorText   = $_.Exception.Message
        }
    }
}

function Get-FirefoxPath {
    $candidate = (Get-Command "firefox.exe" -ErrorAction SilentlyContinue | Select-Object -First 1).Source
    if ($candidate) {
        return $candidate
    }

    $paths = @(
        (Join-Path $env:ProgramFiles "Mozilla Firefox\firefox.exe"),
        (Join-Path ${env:ProgramFiles(x86)} "Mozilla Firefox\firefox.exe")
    )

    foreach ($path in $paths) {
        if ($path -and (Test-Path -LiteralPath $path)) {
            return $path
        }
    }

    return $null
}

function New-ActionButton {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Text,
        [Parameter(Mandatory = $true)]
        [int]$X,
        [Parameter(Mandatory = $true)]
        [int]$Y,
        [Parameter(Mandatory = $true)]
        [System.Drawing.Color]$BackColor
    )

    $button = New-Object System.Windows.Forms.Button
    $button.Text = $Text
    $button.Location = New-Object System.Drawing.Point($X, $Y)
    $button.Size = New-Object System.Drawing.Size(170, 42)
    $button.BackColor = $BackColor
    $button.ForeColor = [System.Drawing.Color]::White
    $button.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $button.FlatAppearance.BorderSize = 0
    $button.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    return $button
}

$form = New-Object System.Windows.Forms.Form
$form.Text = "Firefox Update Policy Toggle"
$form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
$form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
$form.MaximizeBox = $false
$form.MinimizeBox = $false
$form.ClientSize = New-Object System.Drawing.Size(590, 390)
$form.BackColor = [System.Drawing.Color]::FromArgb(244, 247, 251)

$title = New-Object System.Windows.Forms.Label
$title.Text = "Firefox Update Policy"
$title.Location = New-Object System.Drawing.Point(22, 18)
$title.Size = New-Object System.Drawing.Size(520, 34)
$title.Font = New-Object System.Drawing.Font("Segoe UI", 18, [System.Drawing.FontStyle]::Bold)
$title.ForeColor = [System.Drawing.Color]::FromArgb(38, 50, 66)
$form.Controls.Add($title)

$subtitle = New-Object System.Windows.Forms.Label
$subtitle.Text = "Control automatic updates through organizational policy."
$subtitle.Location = New-Object System.Drawing.Point(24, 54)
$subtitle.Size = New-Object System.Drawing.Size(540, 20)
$subtitle.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$subtitle.ForeColor = [System.Drawing.Color]::FromArgb(84, 96, 112)
$form.Controls.Add($subtitle)

$statusHeader = New-Object System.Windows.Forms.Label
$statusHeader.Text = "Current Status"
$statusHeader.Location = New-Object System.Drawing.Point(24, 90)
$statusHeader.Size = New-Object System.Drawing.Size(180, 24)
$statusHeader.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
$statusHeader.ForeColor = [System.Drawing.Color]::FromArgb(38, 50, 66)
$form.Controls.Add($statusHeader)

$statusValue = New-Object System.Windows.Forms.Label
$statusValue.Text = "Checking..."
$statusValue.Location = New-Object System.Drawing.Point(24, 116)
$statusValue.Size = New-Object System.Drawing.Size(540, 26)
$statusValue.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($statusValue)

$statusDetails = New-Object System.Windows.Forms.TextBox
$statusDetails.Location = New-Object System.Drawing.Point(24, 150)
$statusDetails.Size = New-Object System.Drawing.Size(540, 105)
$statusDetails.Multiline = $true
$statusDetails.ReadOnly = $true
$statusDetails.ScrollBars = [System.Windows.Forms.ScrollBars]::Vertical
$statusDetails.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$statusDetails.BackColor = [System.Drawing.Color]::White
$statusDetails.Font = New-Object System.Drawing.Font("Consolas", 9)
$form.Controls.Add($statusDetails)

$lastUpdated = New-Object System.Windows.Forms.Label
$lastUpdated.Location = New-Object System.Drawing.Point(24, 260)
$lastUpdated.Size = New-Object System.Drawing.Size(540, 20)
$lastUpdated.Font = New-Object System.Drawing.Font("Segoe UI", 8)
$lastUpdated.ForeColor = [System.Drawing.Color]::FromArgb(84, 96, 112)
$form.Controls.Add($lastUpdated)

$disableButton = New-ActionButton -Text "Disable Updates" -X 24 -Y 290 -BackColor ([System.Drawing.Color]::FromArgb(220, 53, 69))
$enableButton = New-ActionButton -Text "Enable Updates" -X 210 -Y 290 -BackColor ([System.Drawing.Color]::FromArgb(40, 167, 69))
$refreshButton = New-ActionButton -Text "Refresh Status" -X 396 -Y 290 -BackColor ([System.Drawing.Color]::FromArgb(0, 123, 255))
$aboutPoliciesButton = New-ActionButton -Text "Open about:policies" -X 118 -Y 338 -BackColor ([System.Drawing.Color]::FromArgb(108, 117, 125))
$exitButton = New-ActionButton -Text "Exit" -X 304 -Y 338 -BackColor ([System.Drawing.Color]::FromArgb(52, 58, 64))

$form.Controls.AddRange(@($disableButton, $enableButton, $refreshButton, $aboutPoliciesButton, $exitButton))
$form.AcceptButton = $refreshButton
$form.CancelButton = $exitButton

$refreshStatus = {
    $result = Invoke-StatusCommand -BatchFile $batchPath
    $detailText = if ([string]::IsNullOrWhiteSpace($result.Output)) { "(No output from status command)" } else { $result.Output }

    $status = "UNKNOWN"
    if ($detailText -match "(?im)^Status:\s*(.+)$") {
        $status = $Matches[1].Trim()
    }

    if ($status -like "DISABLED*") {
        $statusValue.Text = "DISABLED"
        $statusValue.ForeColor = [System.Drawing.Color]::FromArgb(200, 35, 51)
    } elseif ($status -like "ENABLED*") {
        $statusValue.Text = "ENABLED"
        $statusValue.ForeColor = [System.Drawing.Color]::FromArgb(25, 135, 84)
    } else {
        $statusValue.Text = "UNKNOWN"
        $statusValue.ForeColor = [System.Drawing.Color]::FromArgb(220, 149, 0)
    }

    $statusDetails.Text = $detailText
    $lastUpdated.Text = "Last checked: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
}

$disableButton.Add_Click({
    $result = Invoke-PolicyCommandElevated -BatchFile $batchPath -Action "disable"
    if ($result.UserCanceled) {
        [System.Windows.Forms.MessageBox]::Show(
            "Disable action was canceled.",
            "Firefox Update Toggle",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null
        & $refreshStatus
        return
    }

    if ($result.ExitCode -eq 0) {
        [System.Windows.Forms.MessageBox]::Show(
            "Firefox updates were set to DISABLED.`n`nRestart Firefox, then verify in about:policies.",
            "Policy Updated",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null
    } else {
        [System.Windows.Forms.MessageBox]::Show(
            "Failed to disable updates. Exit code: $($result.ExitCode)`n$result.ErrorText",
            "Action Failed",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
    }
    & $refreshStatus
})

$enableButton.Add_Click({
    $result = Invoke-PolicyCommandElevated -BatchFile $batchPath -Action "enable"
    if ($result.UserCanceled) {
        [System.Windows.Forms.MessageBox]::Show(
            "Enable action was canceled.",
            "Firefox Update Toggle",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null
        & $refreshStatus
        return
    }

    if ($result.ExitCode -eq 0) {
        [System.Windows.Forms.MessageBox]::Show(
            "Firefox updates were set to ENABLED.`n`nRestart Firefox, then verify in about:policies.",
            "Policy Updated",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null
    } else {
        [System.Windows.Forms.MessageBox]::Show(
            "Failed to enable updates. Exit code: $($result.ExitCode)`n$result.ErrorText",
            "Action Failed",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
    }
    & $refreshStatus
})

$refreshButton.Add_Click({
    & $refreshStatus
})

$aboutPoliciesButton.Add_Click({
    $firefox = Get-FirefoxPath
    if ($firefox) {
        Start-Process -FilePath $firefox -ArgumentList "about:policies" | Out-Null
        return
    }

    [System.Windows.Forms.MessageBox]::Show(
        "Firefox executable was not found automatically.`nOpen Firefox manually and navigate to about:policies.",
        "Firefox Not Found",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Warning
    ) | Out-Null
})

$exitButton.Add_Click({
    $form.Close()
})

& $refreshStatus
[void]$form.ShowDialog()
