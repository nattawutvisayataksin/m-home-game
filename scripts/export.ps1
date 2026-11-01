param(
    [ValidateSet('Windows', 'Android')]
    [string]$Platform = 'Windows',
    [ValidateSet('release', 'debug')]
    [string]$Mode = 'release'
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$project = Join-Path $root 'projects\last-light'
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

$preset = 'Windows Desktop'
$output = Join-Path $project 'build\windows\LAST_LIGHT.exe'
if ($Platform -eq 'Android') {
    $preset = 'Android Arm64'
    $output = Join-Path $project 'build\android\LAST_LIGHT.apk'
}
New-Item -ItemType Directory -Path (Split-Path -Parent $output) -Force | Out-Null

$exportArgument = "--export-$Mode"
& $godot --headless --path $project $exportArgument $preset $output
exit $LASTEXITCODE
