param([string]$Godot='D:\Godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe')
$ErrorActionPreference='Stop'
$gameRoot=Split-Path -Parent $PSScriptRoot
$testRun=Join-Path $gameRoot ('.local\campaign-qa\'+(Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Force -Path $testRun | Out-Null
function Invoke-GameCheck([string]$Name,[string]$Script,[string]$Success,[string]$UserDir,[string[]]$StageArgs=@()) {
  $env:APPDATA=Join-Path $testRun $UserDir
  New-Item -ItemType Directory -Force -Path $env:APPDATA | Out-Null
  $qaLog=Join-Path $testRun ($Name+'.log')
  & $Godot --headless --path $gameRoot --script ('res://tests/reboot/'+$Script+'.gd') --quit-after 1800 --log-file $qaLog -- @StageArgs
  if ($LASTEXITCODE -ne 0) { throw "Failed $Name" }
  $logText=Get-Content -LiteralPath $qaLog -Raw
  if ($logText -match 'SCRIPT ERROR|FAIL:|[1-9][0-9]* failures' -or $logText -notmatch $Success) { throw "Failed or incomplete $Name; inspect $qaLog" }
}
Invoke-GameCheck 'model' 'test_model' 'REBOOT_MODEL:.*0 failures' 'model-user'
Invoke-GameCheck 'equipment' 'test_equipment' 'EQUIPMENT:.*0 failures' 'equipment-user'
Invoke-GameCheck 'natural-progression' 'test_progression' 'NATURAL_PROGRESSION:.*0 failures' 'progression-user'
Invoke-GameCheck 'campaign' 'test_campaign' 'CAMPAIGN:.*0 failures' 'campaign-user'
Invoke-GameCheck 'ui' 'test_ui' 'REBOOT_UI:.*0 failures' 'ui-user'
Invoke-GameCheck 'campaign-ui' 'test_campaign_ui' 'CAMPAIGN_UI:.*0 failures' 'campaign-ui-user'
Invoke-GameCheck 'pointer' 'test_pointer' 'REBOOT_POINTER:.*0 failures' 'pointer-user'
Invoke-GameCheck 'war-pointer' 'test_war_pointer' 'WAR_POINTER:.*0 failures' 'war-pointer-user'
foreach ($stage in @('write','read','again')) {
  Invoke-GameCheck "persistence-$stage" 'test_persistence' 'REBOOT_PERSIST.*0 failures' 'persistence-user' @($stage)
}
foreach ($stage in @('write','read','again')) {
  Invoke-GameCheck "war-persistence-$stage" 'test_war_persistence' 'WAR_PERSIST.*0 failures' 'war-persistence-user' @($stage)
}
Write-Output "All checks passed. Logs: $testRun"
