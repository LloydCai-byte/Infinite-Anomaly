param([string]$Godot='D:\Godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe')
$ErrorActionPreference='Stop'
$taskRoot=Split-Path -Parent $PSScriptRoot
$taskRelease=Join-Path $taskRoot 'builds\InfiniteAnomaly-Pixel-Home-0.40.0'
$env:APPDATA=Join-Path $taskRoot '.local\shadows-20261030\env'
New-Item -ItemType Directory -Force -Path $env:APPDATA,$taskRelease | Out-Null
& $Godot --headless --path $taskRoot --script res://tools/build_ground_shadows.gd
if($LASTEXITCODE -ne 0){throw 'Pixel Hyakki pack failed'}
Copy-Item -LiteralPath (Join-Path (Split-Path -Parent $Godot) 'Godot_v4.7.1-stable_mono_win64.exe') -Destination (Join-Path $taskRelease 'InfiniteAnomaly.exe') -Force
if(!(Test-Path -LiteralPath (Join-Path $taskRelease 'GodotSharp'))){Copy-Item -LiteralPath (Join-Path (Split-Path -Parent $Godot) 'GodotSharp') -Destination $taskRelease -Recurse}
Get-ChildItem -LiteralPath $taskRelease -File -Recurse | Where-Object Name -ne 'checksums.json' | Get-FileHash -Algorithm SHA256 | Select-Object Hash,@{Name='File';Expression={$_.Path.Substring($taskRelease.Length+1)}} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $taskRelease 'checksums.json') -Encoding utf8
Write-Output ('Pixel Hyakki release: '+$taskRelease)
