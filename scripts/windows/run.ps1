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
# of the saved state (d2kConsole, d2kGame:<id>, d2kMusicReady, d2kMusicLaunch), and must never block
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
        if ($settings.PSObject.Properties.Match('d2kMusicLaunch').Count -gt 0) {
            $settings.PSObject.Properties.Remove('d2kMusicLaunch')
            $changed = $true
        }
        # A stale music command must not fire on the next power-on, or the
        # console would start playing whatever was last picked instead of the
        # shuffled menu music.
        foreach ($key in 'd2kMusicSeq', 'd2kMusicAction', 'd2kMusicTrack') {
            if ($settings.PSObject.Properties.Match($key).Count -gt 0) {
                $settings.PSObject.Properties.Remove($key)
                $changed = $true
            }
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

function Get-D2KMusicLaunch {
    try {
        if (-not (Test-Path -LiteralPath $themeSettingsPath -PathType Leaf)) { return $null }
        $settings = Get-Content -LiteralPath $themeSettingsPath -Raw | ConvertFrom-Json
        if ($settings.PSObject.Properties.Match('d2kMusicLaunch').Count -eq 0) { return $null }
        return $settings.d2kMusicLaunch
    }
    catch { return $null }
}

# The music screen posts its controls the same way: theme.qml bumps
# d2kMusicSeq alongside an action and, for Play, the track path. Only the
# sequence number is compared, so repeating the same action still registers.
function Get-D2KMusicCommand {
    try {
        if (-not (Test-Path -LiteralPath $themeSettingsPath -PathType Leaf)) { return $null }
        $settings = Get-Content -LiteralPath $themeSettingsPath -Raw | ConvertFrom-Json
        if ($settings.PSObject.Properties.Match('d2kMusicSeq').Count -eq 0) { return $null }
        return [pscustomobject]@{
            Seq    = $settings.d2kMusicSeq
            Action = if ($settings.PSObject.Properties.Match('d2kMusicAction').Count -gt 0) { $settings.d2kMusicAction } else { '' }
            Track  = if ($settings.PSObject.Properties.Match('d2kMusicTrack').Count -gt 0) { $settings.d2kMusicTrack } else { '' }
        }
    }
    catch { return $null }
}

# Dot-sourced for Write-D2KMpdStatus and its helpers. mpd.ps1 does nothing
# without an -Action, and the only variable the two scripts share is
# $ErrorActionPreference, which both set to 'Stop'. Polling MPD in-process this
# way avoids spawning a PowerShell per status read.
. (Join-Path $PSScriptRoot 'mpd.ps1')

try {
    $musicPrepared = $false
    try {
        & (Join-Path $PSScriptRoot 'mpd.ps1') -Action Prepare
        $musicPrepared = $true
    }
    catch { Write-Warning "D2K music is unavailable: $($_.Exception.Message)" }

    $lastMusicLaunch = Get-D2KMusicLaunch
    $lastMusicCommand = Get-D2KMusicCommand
    $lastMusicSeq = if ($lastMusicCommand) { $lastMusicCommand.Seq } else { $null }
    $pegasus = Start-Process -FilePath $executable -ArgumentList '--portable' -PassThru
    $musicBooted = $false
    $statusTick = 0
    while (-not $pegasus.HasExited) {
        if (-not $musicBooted -and (Test-D2KMusicReady)) {
            if ($musicPrepared) {
                try { & (Join-Path $PSScriptRoot 'mpd.ps1') -Action Boot }
                catch { Write-Warning "D2K music is unavailable: $($_.Exception.Message)" }
            }
            $musicBooted = $true
        }

        $musicLaunch = Get-D2KMusicLaunch
        if ($null -ne $musicLaunch -and $musicLaunch -ne $lastMusicLaunch) {
            $lastMusicLaunch = $musicLaunch
            if ($musicPrepared) {
                try { & (Join-Path $PSScriptRoot 'mpd.ps1') -Action Pause }
                catch { Write-Warning "D2K music is unavailable: $($_.Exception.Message)" }
            }
        }

        $musicCommand = Get-D2KMusicCommand
        if ($null -ne $musicCommand -and $musicCommand.Seq -ne $lastMusicSeq) {
            $lastMusicSeq = $musicCommand.Seq
            if ($musicPrepared) {
                try {
                    switch ($musicCommand.Action) {
                        'play'     { & (Join-Path $PSScriptRoot 'mpd.ps1') -Action Play -Track $musicCommand.Track }
                        'pause'    { & (Join-Path $PSScriptRoot 'mpd.ps1') -Action Pause }
                        'resume'   { & (Join-Path $PSScriptRoot 'mpd.ps1') -Action Resume }
                        'next'     { & (Join-Path $PSScriptRoot 'mpd.ps1') -Action Next }
                        'previous' { & (Join-Path $PSScriptRoot 'mpd.ps1') -Action Previous }
                        default    { Write-Warning "Unknown D2K music action: $($musicCommand.Action)" }
                    }
                }
                catch { Write-Warning "D2K music command failed: $($_.Exception.Message)" }
            }
        }

        # Roughly once a second, publish what MPD is doing so the upper screen's
        # progress rail has something to bind to. Failures are ignored on
        # purpose: MPD may be restarting, and a stale rail must never take the
        # menu down with it.
        $statusTick++
        if ($musicPrepared -and $statusTick -ge 10) {
            $statusTick = 0
            try { Write-D2KMpdStatus | Out-Null }
            catch { }
        }

        Start-Sleep -Milliseconds 100
        $pegasus.Refresh()
    }
}
finally {
    try { & (Join-Path $PSScriptRoot 'mpd.ps1') -Action Stop }
    catch { Write-Warning "D2K music could not be stopped: $($_.Exception.Message)" }
}
