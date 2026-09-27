param([string]$Godot = 'D:\Godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe')
$ErrorActionPreference = 'Stop'
$fullRoot = Split-Path -Parent $PSScriptRoot
$env:APPDATA = Join-Path $fullRoot '.local\full-test-env'
& $Godot --headless --path $fullRoot --script res://tests/containment/test_full.gd --log-file (Join-Path $fullRoot '.local\full-tests.log') -- --full-test
if ($LASTEXITCODE -ne 0) { throw 'Functional checks failed.' }
$env:APPDATA = Join-Path $fullRoot '.local\full-persistence-env'
foreach ($phase in @('write','read','again')) {
  & $Godot --headless --path $fullRoot --script res://tests/containment/test_persistence.gd --log-file (Join-Path $fullRoot ".local\persistence-$phase.log") -- $phase
  if ($LASTEXITCODE -ne 0) { throw "Persistence failed: $phase" }
}
Write-Host 'Full functional and persistence checks passed.'
