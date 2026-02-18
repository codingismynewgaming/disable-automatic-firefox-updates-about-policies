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
    $command = Get-Command -Name "firefox.exe" -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -ne $command) {
        $candidate = $null
        if ($command.PSObject.Properties.Match("Path").Count -gt 0) {
            $candidate = $command.Path
        } elseif ($command.PSObject.Properties.Match("Source").Count -gt 0) {
            $candidate = $command.Source
        }

        if (-not [string]::IsNullOrWhiteSpace($candidate) -and (Test-Path -LiteralPath $candidate)) {
            return $candidate
        }
    }

    $baseDirs = @(
        [Environment]::GetFolderPath([Environment+SpecialFolder]::ProgramFiles),
        [Environment]::GetFolderPath([Environment+SpecialFolder]::ProgramFilesX86),
        [Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData)
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

    $paths = $baseDirs | ForEach-Object {
        Join-Path -Path $_ -ChildPath "Mozilla Firefox\firefox.exe"
    }

    foreach ($path in $paths) {
        if (Test-Path -LiteralPath $path) {
            return $path
        }
    }

    return $null
}

function Get-WindowsAppTheme {
    $personalizePath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"

    try {
        $value = Get-ItemPropertyValue -Path $personalizePath -Name "AppsUseLightTheme" -ErrorAction Stop
        if ([int]$value -eq 0) {
            return "Dark"
        }
    } catch {
        # Default to light when the theme preference is unavailable.
    }

    return "Light"
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

function Set-StatusColor {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Status
    )

    if ($Status -like "DISABLED*") {
        $statusValue.ForeColor = $script:StatusDisabledColor
    } elseif ($Status -like "ENABLED*") {
        $statusValue.ForeColor = $script:StatusEnabledColor
    } else {
        $statusValue.ForeColor = $script:StatusUnknownColor
    }
}

function Set-AppTheme {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("Light", "Dark")]
        [string]$Theme
    )

    if ($Theme -eq "Dark") {
        $form.BackColor = [System.Drawing.Color]::FromArgb(30, 34, 39)
        $titleBar.BackColor = [System.Drawing.Color]::FromArgb(20, 24, 29)
        $titleBarLabel.BackColor = [System.Drawing.Color]::FromArgb(20, 24, 29)
        $titleBarLabel.ForeColor = [System.Drawing.Color]::FromArgb(236, 240, 245)
        $title.ForeColor = [System.Drawing.Color]::FromArgb(236, 240, 245)
        $subtitle.ForeColor = [System.Drawing.Color]::FromArgb(187, 197, 208)
        $themeLabel.ForeColor = [System.Drawing.Color]::FromArgb(187, 197, 208)
        $statusHeader.ForeColor = [System.Drawing.Color]::FromArgb(220, 228, 236)
        $lastUpdated.ForeColor = [System.Drawing.Color]::FromArgb(170, 181, 193)
        $statusDetails.BackColor = [System.Drawing.Color]::FromArgb(20, 24, 29)
        $statusDetails.ForeColor = [System.Drawing.Color]::FromArgb(226, 233, 240)
        $themeToggle.BackColor = [System.Drawing.Color]::FromArgb(63, 71, 80)
        $themeToggle.ForeColor = [System.Drawing.Color]::FromArgb(244, 247, 251)
        $themeToggle.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(92, 102, 112)
        $themeToggle.Text = "Dark: On"

        $script:StatusDisabledColor = [System.Drawing.Color]::FromArgb(255, 107, 122)
        $script:StatusEnabledColor = [System.Drawing.Color]::FromArgb(120, 224, 143)
        $script:StatusUnknownColor = [System.Drawing.Color]::FromArgb(255, 201, 107)

        # Dark mode textbox styling
        $statusDetails.BackColor = [System.Drawing.Color]::FromArgb(20, 24, 29)
        $statusDetails.ForeColor = [System.Drawing.Color]::FromArgb(226, 233, 240)
    } else {
        $form.BackColor = [System.Drawing.Color]::FromArgb(244, 247, 251)
        $titleBar.BackColor = [System.Drawing.Color]::FromArgb(38, 50, 66)
        $titleBarLabel.BackColor = [System.Drawing.Color]::FromArgb(38, 50, 66)
        $titleBarLabel.ForeColor = [System.Drawing.Color]::FromArgb(236, 240, 245)
        $title.ForeColor = [System.Drawing.Color]::FromArgb(38, 50, 66)
        $subtitle.ForeColor = [System.Drawing.Color]::FromArgb(84, 96, 112)
        $themeLabel.ForeColor = [System.Drawing.Color]::FromArgb(84, 96, 112)
        $statusHeader.ForeColor = [System.Drawing.Color]::FromArgb(38, 50, 66)
        $lastUpdated.ForeColor = [System.Drawing.Color]::FromArgb(84, 96, 112)
        $statusDetails.BackColor = [System.Drawing.Color]::White
        $statusDetails.ForeColor = [System.Drawing.Color]::FromArgb(31, 41, 55)
        $themeToggle.BackColor = [System.Drawing.Color]::FromArgb(227, 234, 243)
        $themeToggle.ForeColor = [System.Drawing.Color]::FromArgb(38, 50, 66)
        $themeToggle.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(169, 181, 198)
        $themeToggle.Text = "Dark: Off"

        $script:StatusDisabledColor = [System.Drawing.Color]::FromArgb(200, 35, 51)
        $script:StatusEnabledColor = [System.Drawing.Color]::FromArgb(25, 135, 84)
        $script:StatusUnknownColor = [System.Drawing.Color]::FromArgb(220, 149, 0)

        # Light mode textbox styling
        $statusDetails.BackColor = [System.Drawing.Color]::White
        $statusDetails.ForeColor = [System.Drawing.Color]::FromArgb(31, 41, 55)
    }

    Set-StatusColor -Status $statusValue.Text
}

$form = New-Object System.Windows.Forms.Form
$form.Text = "Firefox Update Policy Toggle"
$form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
$form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
$form.MaximizeBox = $false
$form.MinimizeBox = $false
$form.ClientSize = New-Object System.Drawing.Size(590, 440)
$form.BackColor = [System.Drawing.Color]::FromArgb(244, 247, 251)
$form.TopMost = $false

# Custom title bar for dark mode support
$titleBar = New-Object System.Windows.Forms.Panel
$titleBar.Location = New-Object System.Drawing.Point(0, 0)
$titleBar.Size = New-Object System.Drawing.Size(590, 32)
$titleBar.BackColor = [System.Drawing.Color]::FromArgb(38, 50, 66)
$titleBar.Cursor = [System.Windows.Forms.Cursors]::SizeAll
$form.Controls.Add($titleBar)

$titleBarLabel = New-Object System.Windows.Forms.Label
$titleBarLabel.Text = "Firefox Update Policy Toggle"
$titleBarLabel.Location = New-Object System.Drawing.Point(10, 8)
$titleBarLabel.Size = New-Object System.Drawing.Size(350, 20)
$titleBarLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$titleBarLabel.ForeColor = [System.Drawing.Color]::FromArgb(236, 240, 245)
$titleBarLabel.BackColor = [System.Drawing.Color]::FromArgb(38, 50, 66)
$titleBarLabel.Cursor = [System.Windows.Forms.Cursors]::SizeAll
$titleBar.Controls.Add($titleBarLabel)

$closeButton = New-Object System.Windows.Forms.Button
$closeButton.Text = "✕"
$closeButton.Location = New-Object System.Drawing.Point(550, 4)
$closeButton.Size = New-Object System.Drawing.Size(32, 24)
$closeButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$closeButton.FlatAppearance.BorderSize = 0
$closeButton.BackColor = [System.Drawing.Color]::FromArgb(199, 47, 58)
$closeButton.ForeColor = [System.Drawing.Color]::White
$closeButton.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Regular)
$closeButton.Cursor = [System.Windows.Forms.Cursors]::Default
$titleBar.Controls.Add($closeButton)

$closeButton.Add_Click({ $form.Close() })

# Drag functionality for custom title bar
$script:isDragging = $false
$script:dragStartPoint = [System.Drawing.Point]::Empty

$titleBar.Add_MouseDown({
    if ($_.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
        $script:isDragging = $true
        $script:dragStartPoint = $_.Location
    }
})

$titleBar.Add_MouseMove({
    if ($script:isDragging) {
        $form.Left += $_.X - $script:dragStartPoint.X
        $form.Top += $_.Y - $script:dragStartPoint.Y
    }
})

$titleBar.Add_MouseUp({
    $script:isDragging = $false
})

$titleBarLabel.Add_MouseDown({
    if ($_.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
        $script:isDragging = $true
        $script:dragStartPoint = $titleBar.PointToClient($titleBarLabel.PointToScreen($_.Location))
    }
})

$titleBarLabel.Add_MouseMove({
    if ($script:isDragging) {
        $form.Left += $_.X - $script:dragStartPoint.X
        $form.Top += $_.Y - $script:dragStartPoint.Y
    }
})

$titleBarLabel.Add_MouseUp({
    $script:isDragging = $false
})

# Define main content controls
$title = New-Object System.Windows.Forms.Label
$title.Text = "Firefox Update Policy"
$title.Location = New-Object System.Drawing.Point(22, 42)
$title.Size = New-Object System.Drawing.Size(350, 34)
$title.Font = New-Object System.Drawing.Font("Segoe UI", 18, [System.Drawing.FontStyle]::Bold)
$title.ForeColor = [System.Drawing.Color]::FromArgb(38, 50, 66)
$form.Controls.Add($title)

$subtitle = New-Object System.Windows.Forms.Label
$subtitle.Text = "Control automatic updates through organizational policy."
$subtitle.Location = New-Object System.Drawing.Point(24, 78)
$subtitle.Size = New-Object System.Drawing.Size(360, 20)
$subtitle.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$subtitle.ForeColor = [System.Drawing.Color]::FromArgb(84, 96, 112)
$form.Controls.Add($subtitle)

$themeLabel = New-Object System.Windows.Forms.Label
$themeLabel.Text = "Theme"
$themeLabel.Location = New-Object System.Drawing.Point(404, 50)
$themeLabel.Size = New-Object System.Drawing.Size(54, 20)
$themeLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$themeLabel.ForeColor = [System.Drawing.Color]::FromArgb(84, 96, 112)
$form.Controls.Add($themeLabel)

$themeToggle = New-Object System.Windows.Forms.CheckBox
$themeToggle.Appearance = [System.Windows.Forms.Appearance]::Button
$themeToggle.Location = New-Object System.Drawing.Point(462, 44)
$themeToggle.Size = New-Object System.Drawing.Size(102, 28)
$themeToggle.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$themeToggle.FlatAppearance.BorderSize = 1
$themeToggle.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$themeToggle.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$themeToggle.UseVisualStyleBackColor = $false
$form.Controls.Add($themeToggle)

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
$statusDetails.ScrollBars = [System.Windows.Forms.ScrollBars]::None
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
$restartButton = New-ActionButton -Text "Close & Restart Firefox" -X 396 -Y 290 -BackColor ([System.Drawing.Color]::FromArgb(108, 117, 125))
$refreshButton = New-ActionButton -Text "Refresh Status" -X 24 -Y 338 -BackColor ([System.Drawing.Color]::FromArgb(0, 123, 255))
$aboutPoliciesButton = New-ActionButton -Text "Open about:policies" -X 210 -Y 338 -BackColor ([System.Drawing.Color]::FromArgb(108, 117, 125))
$exitButton = New-ActionButton -Text "Exit" -X 396 -Y 338 -BackColor ([System.Drawing.Color]::FromArgb(52, 58, 64))

$form.Controls.AddRange(@($disableButton, $enableButton, $restartButton, $refreshButton, $aboutPoliciesButton, $exitButton))
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
    } elseif ($status -like "ENABLED*") {
        $statusValue.Text = "ENABLED"
    } else {
        $statusValue.Text = "UNKNOWN"
    }
    Set-StatusColor -Status $statusValue.Text

    $statusDetails.Text = $detailText
    $lastUpdated.Text = "Last checked: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
}

$startupTheme = Get-WindowsAppTheme
$themeToggle.Checked = ($startupTheme -eq "Dark")
Set-AppTheme -Theme $startupTheme

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

$themeToggle.Add_CheckedChanged({
    if ($themeToggle.Checked) {
        Set-AppTheme -Theme "Dark"
    } else {
        Set-AppTheme -Theme "Light"
    }
})

$restartButton.Add_Click({
    $result = [System.Windows.Forms.DialogResult]::No

    $result = [System.Windows.Forms.MessageBox]::Show(
        "This will close Firefox and restart it immediately.`n`nUnsaved data may be lost. Continue?",
        "Restart Firefox",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Warning
    )

    if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
        Write-Host "Closing Firefox..."
        taskkill /F /IM firefox.exe > $null 2>&1
        Start-Sleep -Seconds 2

        Write-Host "Starting Firefox..."
        $firefox = Get-FirefoxPath
        if ($firefox) {
            Start-Process -FilePath $firefox | Out-Null
            [System.Windows.Forms.MessageBox]::Show(
                "Firefox has been restarted.",
                "Firefox Restarted",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            ) | Out-Null
        } else {
            [System.Windows.Forms.MessageBox]::Show(
                "Firefox executable was not found. Please start Firefox manually.",
                "Firefox Not Found",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            ) | Out-Null
        }
    }
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
