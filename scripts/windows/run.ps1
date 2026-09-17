$ErrorActionPreference = 'Stop'

$executable = Join-Path $env:USERPROFILE 'scoop/apps/pegasus/current/pegasus-fe.exe'

if (-not (Test-Path -LiteralPath $executable -PathType Leaf)) {
    throw 'Pegasus is not installed with Scoop. Run: scoop install pegasus'
}

& $executable --portable
