param([string]$Godot = 'D:\Godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe')
$ErrorActionPreference = 'Stop'
$stageRoot = Split-Path -Parent $PSScriptRoot
$env:APPDATA = Join-Path $stageRoot ('.local\stage2-test-env-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $env:APPDATA | Out-Null
$stageJobs = @(
 @{ Script='test_stage1.gd'; Label='first-exploration'; Extra=@('--stage1-test') },
 @{ Script='test_stage2.gd'; Label='rules-ui'; Extra=@('--stage2-test') },
 @{ Script='test_stage2_persistence.gd'; Label='seed-old'; Extra=@('--seed-old') },
 @{ Script='test_stage2_persistence.gd'; Label='persist-write'; Extra=@('--write') },
 @{ Script='test_stage2_persistence.gd'; Label='persist-read'; Extra=@('--read') },
 @{ Script='test_stage2_persistence.gd'; Label='verify-claim'; Extra=@('--verify-claim') }
)
foreach ($stageJob in $stageJobs) {
 $stageLog = Join-Path $stageRoot ('.local\stage2-' + $stageJob.Label + '.log')
 & $Godot --headless --path $stageRoot --log-file $stageLog --script ('res://tests/continuity/'+$stageJob.Script) -- @($stageJob.Extra)
 if ($LASTEXITCODE -ne 0) { throw ('Failed: ' + $stageJob.Label) }
 if (Select-String -LiteralPath $stageLog -Pattern 'SCRIPT ERROR|Parse Error|FAIL STAGE') { throw ('Script failure: ' + $stageJob.Label) }
}
Write-Host 'Stage 2 exploration, idle, actual input, migration and cross-process inventory checks passed.'
