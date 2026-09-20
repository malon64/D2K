$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$themeSource = Join-Path $repoRoot 'pegasus/themes/d2k'
$librarySource = Join-Path $repoRoot 'library/consoles'
$pegasusDir = Join-Path $env:USERPROFILE 'scoop/apps/pegasus/current'
$executable = Join-Path $pegasusDir 'pegasus-fe.exe'
$configDir = Join-Path $pegasusDir 'config'
$themeTarget = Join-Path $configDir 'themes/d2k'
$metadataTarget = Join-Path $configDir 'metafiles'
$gameDirsPath = Join-Path $configDir 'game_dirs.txt'
$settingsPath = Join-Path $configDir 'settings.txt'

if (-not (Test-Path -LiteralPath $executable -PathType Leaf)) {
    throw "Pegasus was not found at $executable. Install it with: scoop install pegasus"
}

New-Item -ItemType Directory -Path (Split-Path -Parent $themeTarget) -Force | Out-Null
if (-not (Test-Path -LiteralPath $themeTarget)) {
    New-Item -ItemType Junction -Path $themeTarget -Target $themeSource | Out-Null
}
else {
    $existingTheme = Get-Item -LiteralPath $themeTarget
    $existingTarget = @($existingTheme.Target)[0]
    if ($existingTheme.LinkType -ne 'Junction' -or -not $existingTarget -or
        (Resolve-Path -LiteralPath $existingTarget).Path -ne (Resolve-Path -LiteralPath $themeSource).Path) {
        throw "D2K theme already exists at $themeTarget. Remove it or replace it with a junction to $themeSource."
    }
}

# The D2K theme now navigates by collection, so the library is indexed directly
# as a Pegasus game directory. The old three-game preview under
# pegasus/metadata/nds is no longer linked in: indexing both would list the same
# Nintendo DS games twice.
if (Test-Path -LiteralPath $metadataTarget) {
    $existingMetadata = Get-Item -LiteralPath $metadataTarget
    if ($existingMetadata.LinkType -eq 'Junction') {
        Remove-Item -LiteralPath $metadataTarget -Force -Recurse
        Write-Host "Removed the superseded metafiles junction: $metadataTarget"
    }
    else {
        throw "Pegasus metafiles at $metadataTarget are not a junction. Remove them by hand, then rerun this script."
    }
}

if (-not (Test-Path -LiteralPath $librarySource -PathType Container)) {
    throw "The D2K library was not found at $librarySource."
}

# Every console directory holding a metadata file becomes a Pegasus game
# directory, which is what gives the theme one collection per carousel entry.
$consoleDirs = Get-ChildItem -LiteralPath $librarySource -Directory |
    Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'metadata.pegasus.txt') } |
    Sort-Object Name

if (-not $consoleDirs) {
    throw "No console metadata found under $librarySource."
}

$libraryPaths = $consoleDirs | ForEach-Object { $_.FullName }
Set-Content -LiteralPath $gameDirsPath -Value $libraryPaths -Encoding UTF8

if (-not (Test-Path -LiteralPath $settingsPath -PathType Leaf)) {
    @(
        'general.theme: themes/d2k'
        'general.fullscreen: false'
    ) | Set-Content -LiteralPath $settingsPath -Encoding UTF8
}

Write-Host "D2K is linked into Scoop Pegasus: $themeTarget"
Write-Host "D2K library is indexed from $($consoleDirs.Count) console directories:"
$consoleDirs | ForEach-Object { Write-Host "  $($_.Name)" }
Write-Host 'Run: .\scripts\windows\run.ps1'
