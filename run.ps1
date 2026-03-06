$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$python = Join-Path $root ".venv\Scripts\python.exe"
$app = Join-Path $root "app.py"

if (-not (Test-Path $python)) {
    Write-Host "[FATAL] .venv non trovato. Crea l'ambiente virtuale prima di avviare."
    exit 1
}

if (-not (Test-Path $app)) {
    Write-Host "[FATAL] app.py non trovato."
    exit 1
}

& $python $app
