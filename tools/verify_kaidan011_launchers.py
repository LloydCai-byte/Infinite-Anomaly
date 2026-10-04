"""Exercise the real root CMD launchers with isolated saves and GPU readbacks."""
from pathlib import Path
import json, os, subprocess, time
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/kaidan-integration-011'
env = dict(os.environ, APPDATA=str(ROOT / '.local/kaidan-011-launcher-env'))
Path(env['APPDATA']).mkdir(parents=True, exist_ok=True)
jobs = [
    ('启动游戏.cmd', 'verify_kaidan011_entry.gd', 'root-entry.json', ['--', '--earth-test']),
    ('启动第一关测试.cmd', 'verify_kaidan011_entry.gd', 'first-stage-entry.json', []),
    ('启动怪谈测试.cmd', 'test_kaidan011_ui.gd', 'preview-entry-ui-test.json', []),
]
results = []
for launcher, test, report, tail in jobs:
    raw = (ROOT / launcher).read_bytes()
    assert not raw.startswith(b'\xef\xbb\xbf') and b'\n' not in raw.replace(b'\r\n', b''), launcher
    started = time.time()
    print('Launching ' + launcher, flush=True)
    command = ['cmd.exe', '/d', '/c', str(ROOT / launcher), '--script', str(ROOT / 'tests/earth' / test), *tail]
    # START lets the child inherit stdout; a pipe would keep communicate() open
    # until the game exits even though CMD has already returned successfully.
    with (OUT / (report + '.cmd.log')).open('wb') as stream:
        proc = subprocess.run(command, cwd=ROOT, env=env, stdout=stream, stderr=subprocess.STDOUT, timeout=10)
    assert proc.returncode == 0, launcher
    target = OUT / report
    while not (target.exists() and target.stat().st_mtime >= started):
        if time.time() - started > 150:
            raise RuntimeError('No new launcher result: ' + launcher)
        time.sleep(.5)
    data = json.loads(target.read_text('utf-8'))
    result = {'launcher': launcher, 'report': report, 'checks': data['checks'], 'failures': data['failures'],
              'crlf_no_bom': True, 'isolated_save_environment': env['APPDATA']}
    results.append(result)
    # Each launcher uses the same log path; archive it before the next launch.
    time.sleep(.5)
    log = ROOT / '.local/earth-game.log'
    if log.exists(): (OUT / (report + '.log')).write_bytes(log.read_bytes())
    print(json.dumps(result, ensure_ascii=False), flush=True)
    if result['failures']: break
(OUT / 'launcher-verification.json').write_text(json.dumps(results, ensure_ascii=False, indent=2), 'utf-8')
raise SystemExit(int(any(r['failures'] for r in results) or len(results) != 3))
