param([string]$Godot = 'D:\Godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe')
$ErrorActionPreference = 'Stop'
$earthRoot = Split-Path -Parent $PSScriptRoot
$earthRelease = Join-Path $earthRoot 'builds\InfiniteAnomaly-Earth-0.11.0'
$earthRuntime = Join-Path (Split-Path -Parent $Godot) 'Godot_v4.7.1-stable_mono_win64.exe'
$env:APPDATA = Join-Path $earthRoot '.local\earth-build-env'
New-Item -ItemType Directory -Force -Path $earthRelease,$env:APPDATA | Out-Null
$earthLog = Join-Path $earthRoot '.local\earth-build-import.log'
& $Godot --headless --path $earthRoot --editor --import --log-file $earthLog | Out-Null
if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath $earthLog -Pattern 'SCRIPT ERROR|Parse Error')) { throw 'Earth asset import failed.' }
& $Godot --headless --path $earthRoot --script res://tools/build_earth.gd
if ($LASTEXITCODE -ne 0) { throw 'Earth pack failed.' }
Copy-Item -LiteralPath $earthRuntime -Destination (Join-Path $earthRelease 'InfiniteAnomaly.exe') -Force
if (!(Test-Path -LiteralPath (Join-Path $earthRelease 'GodotSharp'))) {
  Copy-Item -LiteralPath (Join-Path (Split-Path -Parent $Godot) 'GodotSharp') -Destination $earthRelease -Recurse
}
Copy-Item -LiteralPath (Join-Path $earthRoot 'docs\earth-production\README.txt') -Destination (Join-Path $earthRelease 'README.txt') -Force
Get-ChildItem -LiteralPath $earthRelease -File -Recurse | Where-Object { $_.Name -ne 'checksums.json' } | Get-FileHash -Algorithm SHA256 | Select-Object Hash,@{Name='File';Expression={$_.Path.Substring($earthRelease.Length+1)}} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $earthRelease 'checksums.json') -Encoding UTF8
Write-Output ('Earth preview ready: '+$earthRelease)
