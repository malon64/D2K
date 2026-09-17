$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$themeSource = Join-Path $repoRoot 'pegasus/themes/d2k'
$metadataSource = Join-Path $repoRoot 'pegasus/metadata/nds'
$pegasusDir = Join-Path $env:USERPROFILE 'scoop/apps/pegasus/current'
$executable = Join-Path $pegasusDir 'pegasus-fe.exe'
$configDir = Join-Path $pegasusDir 'config'
$themeTarget = Join-Path $configDir 'themes/d2k'
$metadataTarget = Join-Path $configDir 'metafiles'
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

if (-not (Test-Path -LiteralPath $metadataTarget)) {
    New-Item -ItemType Junction -Path $metadataTarget -Target $metadataSource | Out-Null
}
else {
    $existingMetadata = Get-Item -LiteralPath $metadataTarget
    $existingTarget = @($existingMetadata.Target)[0]
    if ($existingMetadata.LinkType -ne 'Junction' -or -not $existingTarget -or
        (Resolve-Path -LiteralPath $existingTarget).Path -ne (Resolve-Path -LiteralPath $metadataSource).Path) {
        throw "Pegasus metafiles already exist at $metadataTarget. Replace them with a junction to $metadataSource."
    }
}

if (-not (Test-Path -LiteralPath $settingsPath -PathType Leaf)) {
    @(
        'general.theme: themes/d2k'
        'general.fullscreen: false'
    ) | Set-Content -LiteralPath $settingsPath -Encoding UTF8
}

Write-Host "D2K is linked into Scoop Pegasus: $themeTarget"
Write-Host "DS metadata is linked into Scoop Pegasus: $metadataTarget"
Write-Host 'Run: .\scripts\windows\run.ps1'
