param([string]$Godot = 'D:\Godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe')
$ErrorActionPreference = 'Stop'
$stageRoot = Split-Path -Parent $PSScriptRoot
$stageRelease = Join-Path $stageRoot 'builds\InfiniteAnomaly-Stage1'
$stageRuntime = Join-Path (Split-Path -Parent $Godot) 'Godot_v4.7.1-stable_mono_win64.exe'
$env:APPDATA = Join-Path $stageRoot '.local\stage1-build-env'
New-Item -ItemType Directory -Force -Path $stageRelease,$env:APPDATA | Out-Null
& $Godot --headless --path $stageRoot --script res://tools/build_stage1.gd
if ($LASTEXITCODE -ne 0) { throw 'Stage 1 pack failed.' }
Copy-Item -LiteralPath $stageRuntime -Destination (Join-Path $stageRelease 'InfiniteAnomaly.exe') -Force
if (!(Test-Path -LiteralPath (Join-Path $stageRelease 'GodotSharp'))) {
  Copy-Item -LiteralPath (Join-Path (Split-Path -Parent $Godot) 'GodotSharp') -Destination $stageRelease -Recurse
}
Copy-Item -LiteralPath (Join-Path $stageRoot 'docs\阶段1试玩说明.txt') -Destination (Join-Path $stageRelease 'README.txt') -Force
Get-ChildItem -LiteralPath $stageRelease -File -Recurse | Where-Object { $_.Name -ne 'checksums.json' } | Get-FileHash -Algorithm SHA256 | Select-Object Hash,@{Name='File';Expression={$_.Path.Substring($stageRelease.Length+1)}} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $stageRelease 'checksums.json') -Encoding UTF8
Write-Host ('Stage 1 ready: ' + $stageRelease)
