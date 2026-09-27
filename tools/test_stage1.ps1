param([string]$Godot = 'D:\Godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe')
$ErrorActionPreference = 'Stop'
$stageRoot = Split-Path -Parent $PSScriptRoot
$env:APPDATA = Join-Path $stageRoot '.local\stage1-env'
New-Item -ItemType Directory -Force -Path $env:APPDATA | Out-Null
$stageJobs = @(
 @{ Script='test_stage1.gd'; Label='rules-ui'; Extra=@() },
 @{ Script='test_persistence.gd'; Label='persist-write'; Extra=@('--write') },
 @{ Script='test_persistence.gd'; Label='persist-read'; Extra=@() }
)
foreach ($stageJob in $stageJobs) {
 $stageLog = Join-Path $stageRoot ('.local\stage1-' + $stageJob.Label + '.log')
 & $Godot --headless --path $stageRoot --log-file $stageLog --script ('res://tests/continuity/'+$stageJob.Script) -- --stage1-test @($stageJob.Extra)
 if ($LASTEXITCODE -ne 0) { throw ('Failed: ' + $stageJob.Label) }
 if (Select-String -LiteralPath $stageLog -Pattern 'SCRIPT ERROR|Parse Error|FAIL STAGE1|FAIL:') { throw ('Script failure: ' + $stageJob.Label) }
}
Write-Host 'Stage 1 rules, mouse/keyboard input, and cross-process persistence passed.'
