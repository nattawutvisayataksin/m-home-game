param(
    [ValidateSet('run', 'import', 'check')]
    [string]$Action = 'run'
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$project = Join-Path $root 'projects\last-light'

if ($Action -eq 'check') {
    $checker = Join-Path $root '.agents\skills\godot-nodes-scenes\scripts\check_godot_project.py'
    if (-not (Test-Path -LiteralPath $checker)) {
        throw "Godot project checker not found: $checker"
    }

    $python = Join-Path $root 'mcp-servers\pixelart-mcp\.venv\Scripts\python.exe'
    if (-not (Test-Path -LiteralPath $python)) {
        $pythonCommand = Get-Command python -ErrorAction SilentlyContinue
        if ($null -ne $pythonCommand -and $pythonCommand.Source -notmatch '\\WindowsApps\\') {
            $python = $pythonCommand.Source
        }
    }

    if (-not (Test-Path -LiteralPath $python)) {
        throw 'Python 3.10+ was not found in PATH. Install Python, then rerun this command.'
    }

    & $python -c 'import sys; raise SystemExit(0 if sys.version_info >= (3, 10) else 1)'
    if ($LASTEXITCODE -ne 0) {
        throw 'Python 3.10+ is required to run the Godot project checker.'
    }

    & $python $checker $project
    exit $LASTEXITCODE
}

$godot = $env:GODOT_PATH
if ([string]::IsNullOrWhiteSpace($godot)) {
    $godotCommand = Get-Command godot -ErrorAction SilentlyContinue
    if ($null -ne $godotCommand) {
        $godot = $godotCommand.Source
    }
}

if ([string]::IsNullOrWhiteSpace($godot) -or -not (Test-Path -LiteralPath $godot)) {
    throw 'Godot was not found. Set GODOT_PATH to the Godot 4.7.2 executable or add godot to PATH.'
}

if ($Action -eq 'import') {
    & $godot --headless --path $project --editor --quit
} else {
    & $godot --path $project
}

exit $LASTEXITCODE
