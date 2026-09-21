$ErrorActionPreference = 'Stop'

$executable = Join-Path $env:USERPROFILE 'scoop/apps/pegasus/current/pegasus-fe.exe'

if (-not (Test-Path -LiteralPath $executable -PathType Leaf)) {
    throw 'Pegasus is not installed with Scoop. Run: scoop install pegasus'
}

# theme.qml mirrors its navState into api.memory as "d2kNav" so a mid-session
# Pegasus rebuild (which happens around every game launch -- see the note in
# theme.qml) can resume on the same screen. That must not survive an actual
# power cycle, or "shutdown and restart the console" would skip the boot
# screen and land back in the game library instead of a fresh boot. This
# script runs exactly once per power-on, so it is where that key is cleared.
# A JSON round trip is used rather than a text/regex edit, which is what
# previously corrupted melonDS.toml -- clearing this must never risk the rest
# of the saved state (d2kConsole, d2kGame:<id>, d2kMusicReady), and must never block
# launching Pegasus if anything here goes wrong.
$themeSettingsPath = Join-Path $env:USERPROFILE 'scoop/apps/pegasus/current/config/theme_settings/d2k.json'
if (Test-Path -LiteralPath $themeSettingsPath -PathType Leaf) {
    try {
        $settings = Get-Content -LiteralPath $themeSettingsPath -Raw | ConvertFrom-Json
        $changed = $false
        if ($settings.PSObject.Properties.Match('d2kNav').Count -gt 0) {
            $settings.PSObject.Properties.Remove('d2kNav')
            $changed = $true
        }
        if ($settings.PSObject.Properties.Match('d2kMusicReady').Count -gt 0) {
            $settings.PSObject.Properties.Remove('d2kMusicReady')
            $changed = $true
        }
        if ($changed) {
            $json = $settings | ConvertTo-Json -Compress
            [System.IO.File]::WriteAllText($themeSettingsPath, $json, [System.Text.UTF8Encoding]::new($false))
        }
    }
    catch {
        Write-Warning "Could not clear d2kNav from $themeSettingsPath -- continuing anyway: $($_.Exception.Message)"
    }
}

function Test-D2KMusicReady {
    try {
        if (-not (Test-Path -LiteralPath $themeSettingsPath -PathType Leaf)) { return $false }
        $settings = Get-Content -LiteralPath $themeSettingsPath -Raw | ConvertFrom-Json
        return $settings.PSObject.Properties.Match('d2kMusicReady').Count -gt 0 -and $settings.d2kMusicReady -eq $true
    }
    catch { return $false }
}

try {
    $musicPrepared = $false
    try {
        & (Join-Path $PSScriptRoot 'mpd.ps1') -Action Prepare
        $musicPrepared = $true
    }
    catch { Write-Warning "D2K music is unavailable: $($_.Exception.Message)" }

    $pegasus = Start-Process -FilePath $executable -ArgumentList '--portable' -PassThru
    $deadline = [DateTime]::UtcNow.AddSeconds(30)
    while (-not $pegasus.HasExited -and [DateTime]::UtcNow -lt $deadline) {
        if (Test-D2KMusicReady) {
            if ($musicPrepared) {
                try { & (Join-Path $PSScriptRoot 'mpd.ps1') -Action Boot }
                catch { Write-Warning "D2K music is unavailable: $($_.Exception.Message)" }
            }
            break
        }
        Start-Sleep -Milliseconds 100
        $pegasus.Refresh()
    }

    $pegasus.WaitForExit()
}
finally {
    try { & (Join-Path $PSScriptRoot 'mpd.ps1') -Action Stop }
    catch { Write-Warning "D2K music could not be stopped: $($_.Exception.Message)" }
}
