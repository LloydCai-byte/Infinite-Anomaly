param([string]$Godot = 'D:\Godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe')
$ErrorActionPreference = 'Stop'
$fullRoot = Split-Path -Parent $PSScriptRoot
$fullRelease = Join-Path $fullRoot 'builds\InfiniteAnomaly-Full'
$fullRuntime = Join-Path (Split-Path -Parent $Godot) 'Godot_v4.7.1-stable_mono_win64.exe'
$env:APPDATA = Join-Path $fullRoot '.local\full-build-env'
New-Item -ItemType Directory -Force -Path $fullRelease,$env:APPDATA | Out-Null
$fullImportLog = Join-Path $fullRoot '.local\full-build-import.log'
& $Godot --headless --path $fullRoot --editor --import --log-file $fullImportLog
if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath $fullImportLog -Pattern 'SCRIPT ERROR|Parse Error')) { throw 'Full version import failed.' }
& $Godot --headless --path $fullRoot --script res://tools/build_full.gd
if ($LASTEXITCODE -ne 0) { throw 'Full version pack failed.' }
Copy-Item -LiteralPath $fullRuntime -Destination (Join-Path $fullRelease 'InfiniteAnomaly.exe') -Force
if (!(Test-Path -LiteralPath (Join-Path $fullRelease 'GodotSharp'))) {
  Copy-Item -LiteralPath (Join-Path (Split-Path -Parent $Godot) 'GodotSharp') -Destination $fullRelease -Recurse
}
Copy-Item -LiteralPath (Join-Path $fullRoot 'docs\完整功能版试玩说明.txt') -Destination (Join-Path $fullRelease 'README.txt') -Force
Get-ChildItem -LiteralPath $fullRelease -File -Recurse | Where-Object { $_.Name -ne 'checksums.json' } | Get-FileHash -Algorithm SHA256 | Select-Object Hash,@{Name='File';Expression={$_.Path.Substring($fullRelease.Length+1)}} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $fullRelease 'checksums.json') -Encoding UTF8
Write-Host ('Full version ready: '+$fullRelease)
