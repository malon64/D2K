param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Prepare', 'Boot', 'Start', 'Pause', 'Resume', 'Stop', 'SmokeTest')]
    [string]$Action
)

$ErrorActionPreference = 'Stop'
$port = 6600
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$musicDirectory = Join-Path $repoRoot 'library/consoles/music'
$playlistPath = Join-Path $musicDirectory 'playlist.m3u'
$mpd = Join-Path $env:USERPROFILE 'scoop/apps/mpd/current/mpd.exe'
$stateDirectory = Join-Path $env:LOCALAPPDATA 'D2K/mpd'
$configPath = Join-Path $stateDirectory 'mpd.conf'
$pidPath = Join-Path $stateDirectory 'mpd.pid'

function Invoke-Mpd {
    param([string[]]$Commands)

    $client = [Net.Sockets.TcpClient]::new('127.0.0.1', $port)
    try {
        $stream = $client.GetStream()
        $utf8 = [Text.UTF8Encoding]::new($false)
        $reader = [IO.StreamReader]::new($stream, $utf8, $false, 4096, $true)
        $writer = [IO.StreamWriter]::new($stream, $utf8, 4096, $true)
        if ($reader.ReadLine() -notlike 'OK MPD *') { throw 'MPD did not send its greeting.' }

        $reply = @()
        foreach ($command in $Commands) {
            $writer.WriteLine($command)
            $writer.Flush()
            do {
                $line = $reader.ReadLine()
                if ($null -eq $line) { throw 'MPD closed the connection.' }
                if ($line -like 'ACK *') { throw "MPD: $line" }
                if ($line -ne 'OK') { $reply += $line }
            } while ($line -ne 'OK')
        }
        return $reply
    }
    finally {
        if ($client) { $client.Dispose() }
    }
}

function Get-MpdStatus {
    $status = @{}
    foreach ($line in Invoke-Mpd @('status')) {
        $separator = $line.IndexOf(': ')
        if ($separator -ge 0) { $status[$line.Substring(0, $separator)] = $line.Substring($separator + 2) }
    }
    return $status
}

function Fade-MpdVolume {
    param(
        [int]$Target,
        [int]$DurationMilliseconds = 1500
    )

    $status = Get-MpdStatus
    $current = if ($status.ContainsKey('volume')) { [int]$status['volume'] } else { 100 }
    if ($current -eq $Target) { return }

    for ($step = 1; $step -le 5; $step++) {
        $volume = [Math]::Round($current + ($Target - $current) * $step / 5)
        Invoke-Mpd @("setvol $volume") | Out-Null
        Start-Sleep -Milliseconds ([Math]::Max(1, [Math]::Round($DurationMilliseconds / 5)))
    }
}

function Get-D2KMpdProcess {
    if (-not (Test-Path -LiteralPath $pidPath -PathType Leaf)) { return $null }
    try {
        $process = Get-Process -Id ([int](Get-Content -LiteralPath $pidPath -Raw)) -ErrorAction Stop
        if ($process.Path -ne $mpd) { throw 'The stored process is not D2K MPD.' }
        return $process
    }
    catch {
        Remove-Item -LiteralPath $pidPath -Force -ErrorAction SilentlyContinue
        return $null
    }
}

function Get-PlaylistTracks {
    if (-not (Test-Path -LiteralPath $playlistPath -PathType Leaf)) {
        throw "D2K playlist was not found at $playlistPath"
    }

    $tracks = @()
    foreach ($track in Get-Content -LiteralPath $playlistPath -Encoding utf8 | Where-Object { $_ -and -not $_.StartsWith('#') }) {
        $file = Join-Path $musicDirectory $track
        if ($track.StartsWith('/') -or $track.Contains('..') -or -not (Test-Path -LiteralPath $file -PathType Leaf)) {
            throw "D2K playlist contains an invalid track: $track"
        }
        if ((Get-Item -LiteralPath $file).Length -eq 0) {
            Write-Warning "D2K playlist skips the empty file: $track"
            continue
        }
        $tracks += $track
    }
    if (-not $tracks.Count) { throw "D2K playlist has no playable tracks: $playlistPath" }
    return $tracks
}

function Quote-Mpd {
    param([string]$Value)
    '"' + $Value.Replace('\', '\\').Replace('"', '\"') + '"'
}

function Start-D2KMpd {
    param([switch]$Muted)

    if (-not (Test-Path -LiteralPath $mpd -PathType Leaf)) { throw 'MPD is not installed. Run: scoop install mpd' }
    $tracks = Get-PlaylistTracks
    New-Item -ItemType Directory -Path $stateDirectory -Force | Out-Null

    $toMpdPath = { param([string]$Path) $Path.Replace('\', '/') }
    $config = @(
        'music_directory "' + (& $toMpdPath $musicDirectory) + '"'
        'db_file "' + (& $toMpdPath (Join-Path $stateDirectory 'database')) + '"'
        'state_file "' + (& $toMpdPath (Join-Path $stateDirectory 'state')) + '"'
        'log_file "' + (& $toMpdPath (Join-Path $stateDirectory 'mpd.log')) + '"'
        'bind_to_address "127.0.0.1"'
        "port `"$port`""
        'zeroconf_enabled "no"'
        'audio_output_format "44100:16:2"'
        'audio_output {'
        '    type "wasapi"'
        '    name "D2K"'
        '    mixer_type "software"'
        '}'
    )
    [IO.File]::WriteAllLines($configPath, $config, [Text.UTF8Encoding]::new($false))

    $process = Get-D2KMpdProcess
    if (-not $process) {
        try { Invoke-Mpd @('status') | Out-Null; throw "MPD port $port is already in use." } catch [Net.Sockets.SocketException] { }
        $process = Start-Process -FilePath $mpd -ArgumentList @('--no-daemon', $configPath) -WindowStyle Hidden -PassThru
        [IO.File]::WriteAllText($pidPath, "$($process.Id)`n", [Text.UTF8Encoding]::new($false))
    }

    $deadline = [DateTime]::UtcNow.AddSeconds(5)
    do {
        try { Get-MpdStatus | Out-Null; break } catch { Start-Sleep -Milliseconds 100 }
    } while ([DateTime]::UtcNow -lt $deadline)
    if ([DateTime]::UtcNow -ge $deadline) { throw 'MPD did not become ready within 5 seconds.' }

    $commands = @('clear')
    foreach ($track in $tracks) { $commands += 'add ' + (Quote-Mpd $track.Replace('\', '/')) }
    $commands += 'random 1', 'repeat 1', 'single 0', 'crossfade 5', 'setvol 0', 'play'
    Invoke-Mpd $commands | Out-Null
    if ($Muted) { Invoke-Mpd @('pause 1') | Out-Null }
    else { Fade-MpdVolume 100 }
}

function Stop-D2KMpd {
    $process = Get-D2KMpdProcess
    if (-not $process) { return }
    try { Fade-MpdVolume 0 } catch { }
    try { Invoke-Mpd @('stop', 'kill') | Out-Null } catch { }
    try { $process.WaitForExit(2000) | Out-Null } catch { }
    try {
        if (-not $process.HasExited) { $process.Kill() }
    }
    catch { }
    Remove-Item -LiteralPath $pidPath -Force -ErrorAction SilentlyContinue
}

switch ($Action) {
    'Prepare' { Start-D2KMpd -Muted }
    'Boot' { Invoke-Mpd @('pause 0') | Out-Null; Fade-MpdVolume 100 300 }
    'Start' { Start-D2KMpd }
    'Pause' { Fade-MpdVolume 0; Invoke-Mpd @('pause 1') | Out-Null }
    'Resume' { Invoke-Mpd @('pause 0') | Out-Null; Fade-MpdVolume 100 }
    'Stop' { Stop-D2KMpd }
    'SmokeTest' {
        try {
            Start-D2KMpd
            $status = Get-MpdStatus
            $expectedTrackCount = (Get-PlaylistTracks).Count
            if ($status['playlistlength'] -ne "$expectedTrackCount" -or $status['state'] -ne 'play' -or $status['random'] -ne '1' -or $status['repeat'] -ne '1' -or $status['xfade'] -ne '5') {
                throw "Unexpected MPD status: $($status | Out-String)"
            }
            Write-Output 'MPD smoke test passed.'
        }
        finally { Stop-D2KMpd }
    }
}
