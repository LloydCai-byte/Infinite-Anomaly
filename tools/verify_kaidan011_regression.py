"""Run existing regressions while keeping their historical report files intact."""
from pathlib import Path
import json, os, re, subprocess

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/kaidan-integration-011'
WORK = ROOT / '.local/kaidan-011-tests'
WORK.mkdir(parents=True, exist_ok=True)
GODOT = 'D:/Godot/Godot_v4.7.1-stable_mono_win64/Godot_v4.7.1-stable_mono_win64_console.exe'
env = dict(os.environ, APPDATA=str(ROOT / '.local/kaidan-011-env'))
tests = ['test_stage1', 'test_stage2', 'test_persistence', 'test_gait',
         'test_stage01_art', 'test_assets', 'test_revision010',
         'test_revision010_ui', 'test_home_flow']
results = []
for name in tests:
    source = ROOT / 'tests/earth' / (name + '.gd')
    script = source.read_text('utf-8-sig')
    replacements = {
        'res://docs/revision-20261002/model-test.json': 'res://docs/kaidan-integration-011/regression-loot.json',
        'res://docs/revision-20261002/ui-test.json': 'res://docs/kaidan-integration-011/regression-ui010.json',
        'res://docs/asset-replacement/home-flow-test.json': 'res://docs/kaidan-integration-011/regression-home.json',
    }
    for before, after in replacements.items():
        script = script.replace(before, after)
    fixture = WORK / (name + '.gd')
    fixture.write_text(script, 'utf-8')
    run = subprocess.run([GODOT, '--headless', '--path', str(ROOT), '--script', str(fixture), '--', '--earth-test'],
                         cwd=ROOT, env=env, capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=120)
    log = run.stdout + run.stderr
    (OUT / (name + '.log')).write_text(log, 'utf-8')
    assertions = re.findall(r'(\d+) checks / (\d+) failures', log)
    result = {'test': name, 'exit_code': run.returncode,
              'assertions': [{'checks': int(c), 'failures': int(f)} for c, f in assertions],
              'script_error': bool(re.search(r'SCRIPT ERROR|Parse Error|FAIL ', log))}
    results.append(result)
    print(json.dumps(result), flush=True)
(OUT / 'regression.json').write_text(json.dumps(results, indent=2), 'utf-8')
raise SystemExit(int(any(r['exit_code'] or r['script_error'] for r in results)))
