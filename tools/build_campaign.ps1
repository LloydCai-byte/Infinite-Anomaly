param([string]$Godot = 'D:\Godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe')
$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
$taskRelease = Join-Path $taskRoot 'builds/InfiniteAnomaly-1.0'
$taskRuntime = Join-Path (Split-Path -Parent $Godot) 'Godot_v4.7.1-stable_mono_win64.exe'
if (!(Test-Path -LiteralPath $taskRuntime)) { throw 'Local Godot runtime is missing.' }
$env:APPDATA = Join-Path $taskRoot '.local/campaign-env'
New-Item -ItemType Directory -Force -Path $taskRelease | Out-Null
& $Godot --headless --path $taskRoot --editor --import --quit
if ($LASTEXITCODE -ne 0) { throw 'Resource import failed.' }
& $Godot --headless --path $taskRoot --script res://tools/build_campaign.gd -- --campaign-test
if ($LASTEXITCODE -ne 0) { throw 'Game pack build failed.' }
Copy-Item -LiteralPath $taskRuntime -Destination (Join-Path $taskRelease 'InfiniteAnomaly.exe') -Force
Copy-Item -LiteralPath (Join-Path (Split-Path -Parent $Godot) 'GodotSharp') -Destination $taskRelease -Recurse -Force
Copy-Item -LiteralPath (Join-Path $taskRoot 'docs/游戏使用说明.txt') -Destination (Join-Path $taskRelease 'README.txt') -Force
Get-ChildItem -LiteralPath $taskRelease -File -Recurse | Where-Object { $_.Name -ne 'checksums.json' -and $_.FullName -notmatch '\\\.local\\' } | Get-FileHash -Algorithm SHA256 | Select-Object Hash,@{Name='File';Expression={$_.Path.Substring($taskRelease.Length+1)}} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $taskRelease 'checksums.json') -Encoding UTF8
Write-Host ('Built: ' + $taskRelease)
$taskBundle = Get-ChildItem -LiteralPath $taskRelease | Where-Object { $_.Name -ne '.local' } | Select-Object -ExpandProperty FullName
Compress-Archive -LiteralPath $taskBundle -DestinationPath (Join-Path $taskRoot 'builds/InfiniteAnomaly-1.0-Windows.zip') -Force
Write-Host 'Created InfiniteAnomaly-1.0-Windows.zip'
