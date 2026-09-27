param([string]$Godot = 'D:\Godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe')
$ErrorActionPreference = 'Stop'
$stageRoot = Split-Path -Parent $PSScriptRoot
$stageRelease = Join-Path $stageRoot 'builds\InfiniteAnomaly-Stage2'
$stageRuntime = Join-Path (Split-Path -Parent $Godot) 'Godot_v4.7.1-stable_mono_win64.exe'
$env:APPDATA = Join-Path $stageRoot '.local\stage2-build-env'
New-Item -ItemType Directory -Force -Path $stageRelease,$env:APPDATA | Out-Null
$stageImportLog = Join-Path $stageRoot '.local\stage2-build-import.log'
& $Godot --headless --path $stageRoot --editor --import --log-file $stageImportLog
if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath $stageImportLog -Pattern 'SCRIPT ERROR|Parse Error')) { throw 'Stage 2 import failed.' }
& $Godot --headless --path $stageRoot --script res://tools/build_stage2.gd
if ($LASTEXITCODE -ne 0) { throw 'Stage 2 pack failed.' }
Copy-Item -LiteralPath $stageRuntime -Destination (Join-Path $stageRelease 'InfiniteAnomaly.exe') -Force
if (!(Test-Path -LiteralPath (Join-Path $stageRelease 'GodotSharp'))) {
  Copy-Item -LiteralPath (Join-Path (Split-Path -Parent $Godot) 'GodotSharp') -Destination $stageRelease -Recurse
}
Copy-Item -LiteralPath (Join-Path $stageRoot 'docs\阶段2试玩说明.txt') -Destination (Join-Path $stageRelease 'README.txt') -Force
Get-ChildItem -LiteralPath $stageRelease -File -Recurse | Where-Object { $_.Name -ne 'checksums.json' } | Get-FileHash -Algorithm SHA256 | Select-Object Hash,@{Name='File';Expression={$_.Path.Substring($stageRelease.Length+1)}} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $stageRelease 'checksums.json') -Encoding UTF8
Write-Host ('Stage 2 ready: ' + $stageRelease)
