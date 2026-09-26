$ErrorActionPreference = 'Stop'
$taskProject = Split-Path -Parent $PSScriptRoot
$taskGodot = 'D:\Godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe'
$taskToken = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds().ToString()
New-Item -ItemType Directory -Path (Join-Path $taskProject '.local') -Force | Out-Null
$taskRuns = @(
  @{ Name = 'home-model'; Script = 'res://tests/home/test_model.gd'; Args = @() },
  @{ Name = 'home-ui'; Script = 'res://tests/home/test_ui.gd'; Args = @() },
  @{ Name = 'home-restart-save'; Script = 'res://tests/home/test_restart.gd'; Args = @('--save-session', "--checkpoint-test=$taskToken") },
  @{ Name = 'home-restart-load'; Script = 'res://tests/home/test_restart.gd'; Args = @('--load-session', "--checkpoint-test=$taskToken") }
)
foreach ($taskRun in $taskRuns) {
  $taskLog = Join-Path $taskProject ('.local/' + $taskRun.Name + '.log')
  & $taskGodot --headless --path $taskProject --log-file $taskLog --script $taskRun.Script -- --home-test @($taskRun.Args)
  if ($LASTEXITCODE -ne 0) { throw ($taskRun.Name + ' failed.') }
  if (Select-String -LiteralPath $taskLog -Pattern 'SCRIPT ERROR|Parse Error|FAIL:|ERROR:' -Quiet) { throw ('Error in ' + $taskLog) }
}
$taskSmokeLog = Join-Path $taskProject '.local/home-smoke.log'
& $taskGodot --headless --path $taskProject --log-file $taskSmokeLog -- --home-smoke
if ($LASTEXITCODE -ne 0) { throw 'Home scene smoke run failed.' }
if (Select-String -LiteralPath $taskSmokeLog -Pattern 'SCRIPT ERROR|Parse Error|FAIL:|ERROR:' -Quiet) { throw 'Error in home-smoke.log' }
Write-Output 'All apartment-edition tests passed. Player saves were not modified.'
