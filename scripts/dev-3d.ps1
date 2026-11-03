param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('run', 'import', 'check')]
    [string]$Action
)

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

switch ($Action) {
    'run' {
        & $godot --path $project
        exit $LASTEXITCODE
    }
    'import' {
        & $godot --headless --path $project --import
        if ($LASTEXITCODE -ne 0) {
            exit $LASTEXITCODE
        }
    }
    'check' {
        $scriptFiles = Get-ChildItem -Path (Join-Path $project 'scripts') -Recurse -Filter '*.gd'
        $errorCount = 0
        foreach ($file in $scriptFiles) {
            $relative = $file.FullName.Substring($project.Length + 1).Replace('\', '/')
            $output = & $godot --headless --path $project --check-only --script ("res://" + $relative) 2>&1
            $text = ($output | Out-String)
            if ($text -match 'SCRIPT ERROR' -or $text -match 'Parse Error') {
                Write-Output $text
                $errorCount += 1
            }
        }
        Write-Output "Summary: $errorCount errors out of $($scriptFiles.Count) scripts checked (last-light-3d)."
        if ($errorCount -gt 0) {
            exit 1
        }
    }
}
