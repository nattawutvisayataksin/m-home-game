$ErrorActionPreference = 'Continue'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$project = Join-Path $root 'projects\last-light-3d'
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

foreach ($testScript in @('phase1_3d_smoke.gd', 'phase2_td_data_title_test.gd', 'phase3_settings_test.gd', 'phase4_audio_test.gd')) {
    & $godot --headless --path $project --script ("res://tests/" + $testScript)
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}
