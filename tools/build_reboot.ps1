param([string]$Godot = 'D:\Godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe')
$ErrorActionPreference = 'Stop'
$rebootRoot = Split-Path -Parent $PSScriptRoot
$rebootRelease = Join-Path $rebootRoot 'builds\InfiniteAnomaly-Reboot'
$rebootRuntime = Join-Path (Split-Path -Parent $Godot) 'Godot_v4.7.1-stable_mono_win64.exe'
$env:APPDATA = Join-Path $rebootRoot '.local\reboot-build-env'
New-Item -ItemType Directory -Force -Path $rebootRelease,$env:APPDATA | Out-Null
$rebootLog = Join-Path $rebootRoot '.local\reboot-build-import.log'
& $Godot --headless --path $rebootRoot --editor --import --log-file $rebootLog | Out-Null
if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath $rebootLog -Pattern 'SCRIPT ERROR|Parse Error')) { throw 'Reboot asset import failed.' }
& $Godot --headless --path $rebootRoot --script res://tools/build_reboot.gd
if ($LASTEXITCODE -ne 0) { throw 'Reboot pack failed.' }
Copy-Item -LiteralPath $rebootRuntime -Destination (Join-Path $rebootRelease 'InfiniteAnomaly.exe') -Force
if (!(Test-Path -LiteralPath (Join-Path $rebootRelease 'GodotSharp'))) {
  Copy-Item -LiteralPath (Join-Path (Split-Path -Parent $Godot) 'GodotSharp') -Destination $rebootRelease -Recurse
}
Copy-Item -LiteralPath (Join-Path $rebootRoot 'docs\重做首章试玩说明.txt') -Destination (Join-Path $rebootRelease 'README.txt') -Force
Get-ChildItem -LiteralPath $rebootRelease -File -Recurse | Where-Object { $_.Name -ne 'checksums.json' } | Get-FileHash -Algorithm SHA256 | Select-Object Hash,@{Name='File';Expression={$_.Path.Substring($rebootRelease.Length+1)}} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $rebootRelease 'checksums.json') -Encoding UTF8
Write-Output ('Reboot release ready: '+$rebootRelease)
