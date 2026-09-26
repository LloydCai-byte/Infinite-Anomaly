param([string]$Godot = 'D:\Godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe')
$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
$env:APPDATA = Join-Path $taskRoot '.local/campaign-env'
New-Item -ItemType Directory -Force -Path $env:APPDATA | Out-Null
$taskChecks = @(
  @{ Script='test_model.gd'; Name='model'; Extra=@() },
  @{ Script='test_ui.gd'; Name='ui'; Extra=@() },
  @{ Script='test_persistence.gd'; Name='save-write'; Extra=@('--write') },
  @{ Script='test_persistence.gd'; Name='save-read'; Extra=@() }
)
foreach ($taskCheck in $taskChecks) {
  $taskLog = Join-Path $taskRoot ('.local/campaign-' + $taskCheck.Name + '.log')
  $taskArgs = @('--headless','--path',$taskRoot,'--log-file',$taskLog,'--script',('res://tests/campaign/'+$taskCheck.Script),'--','--campaign-test') + $taskCheck.Extra
  & $Godot @taskArgs
  if ($LASTEXITCODE -ne 0) { throw ('Check failed: ' + $taskCheck.Name) }
  $taskErrors = Select-String -LiteralPath $taskLog -Pattern 'SCRIPT ERROR|Parse Error|FAIL:|FAIL UI|FAIL PERSISTENCE'
  if ($taskErrors) { throw ('Engine error in ' + $taskLog) }
}
Write-Host 'All campaign checks passed. Player saves were not touched.'
