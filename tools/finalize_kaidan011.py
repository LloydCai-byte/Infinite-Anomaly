"""Archive verified runtime delivery; preserve the paused art queue and originals."""
from pathlib import Path
import datetime, hashlib, html, json, shutil
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
DOC = ROOT / 'docs/kaidan-integration-011'
ART = ROOT / 'art/earth-production/kaidan-integration-011'
BUILD = ROOT / 'builds/InfiniteAnomaly-Earth-0.11.0'
def read(p): return json.loads(p.read_text('utf-8-sig'))
def write(p, data): p.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', 'utf-8')
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
stamp = datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=8))).isoformat()

sources = read(DOC / 'source-manifest.json')['copied_originals']
for item in sources:
    assert sha(ROOT / item['source']) == sha(ROOT / item['runtime']) == item['sha256']
regression = read(DOC / 'regression.json')
assert all(r['exit_code'] == 0 and not r['script_error'] for r in regression)
reg_checks = sum(a['checks'] for r in regression for a in r['assertions'])
reports = ['model-test.json', 'preview-entry-ui-test.json', 'root-entry.json', 'first-stage-entry.json', 'package-regression.json']
for name in reports: assert read(DOC / name)['failures'] == 0, name

launchers = []
for entry, report in [('启动游戏.cmd','root-entry.json'),('启动第一关测试.cmd','first-stage-entry.json'),('启动怪谈测试.cmd','preview-entry-ui-test.json')]:
    raw = (ROOT / entry).read_bytes()
    assert not raw.startswith(b'\xef\xbb\xbf') and b'\n' not in raw.replace(b'\r\n',b'')
    data = read(DOC / report)
    launchers.append({'launcher':entry,'report':report,'checks':data['checks'],'failures':data['failures'],
                      'crlf_no_bom':True,'isolated_save_environment':str(ROOT / '.local/kaidan-011-launcher-env')})
write(DOC / 'launcher-verification.json', launchers)

capture = read(DOC / 'preview-entry-ui-test.json')
captures = []
for shot in capture['screenshots']:
    p = ART / 'captures' / ('preview-entry-' + shot['name'] + '.png')
    with Image.open(p) as im: size = list(im.size)
    assert size == shot['size']
    captures.append({'file':p.relative_to(ROOT).as_posix(),'size':size,'sha256':sha(p)})
pack_files = read(BUILD / 'files.json')
assert len(pack_files) == 976
for item in sources: assert 'res://' + item['runtime'] in pack_files
assert 'res://scripts/earth/chroma_key.gdshader' in pack_files
assert 'res://assets/earth/anomalies/catalog.json' in pack_files
for item in read(BUILD / 'checksums.json'):
    assert sha(BUILD / item['File']).upper() == item['Hash'], item['File']

summary = {'verified_at':stamp,'version':'0.11.0-earth-kaidan','release':BUILD.relative_to(ROOT).as_posix(),
           'runtime_originals':len(sources),'source_bytes_unchanged':True,'pck_entries':len(pack_files),
           'pck_sha256':sha(BUILD / 'InfiniteAnomaly.pck'),'regression_checks':reg_checks,
           'model_checks':49,'actual_new_launcher_ui_checks':capture['checks'],'other_launcher_checks':13,
           'failures':0,'package_regression_pass':True,'package_test_workdir':'D:/Codex/home/visualizations/2026/10/03/01a1018f-2c67-7002-a6ee-cb0ba54c9c79',
           'ledger':read(ROOT / 'docs/asset-replacement/audit.json'),'captures':captures,
           'native_hd_source_complete':False,'full_frame_animation_complete':False,
           'seam_art_refinement_complete':False,'feishu_written_this_turn':False,'github_pushed':False,
           'harness_note':'First launcher orchestration timed out waiting on inherited stdout after CMD returned; the child finished with 125 checks and zero failures. Collected its fresh report; runner now redirects stdout to a file.'}
write(DOC / 'verification-summary.json', summary)

integration = {'version':'0.11.0-earth-kaidan','verified_at':stamp,'status':'playable_static_pose_integration_verified',
               'report':'docs/kaidan-integration-011/verification-summary.json','native_hd':False,'formal_animation':False}
queue_path = ROOT / 'docs/anomaly-marathon-20261003/queue.json'
queue = read(queue_path)
assert queue['current']['stop_after_batch'] and queue['current']['batch'] == 'B0001'
backup = DOC / 'before/queue-before-integration.json'
if not backup.exists(): shutil.copy2(queue_path, backup)
queue['game_integration'] = {**integration,'stages':[301,302],'scope':['K004','K005']}
for item in queue['items']:
    if item['id'] in ['K004','K005']:
        item['game_integration'] = {**integration,'stage':301 if item['id']=='K004' else 302}
write(queue_path, queue)
for folder, stage in [('K004-hasshaku',301),('K005-kuchisake',302)]:
    p = ROOT / 'art/anomaly-concepts/continuous-20261003' / folder / 'manifest.json'
    dest = DOC / 'before' / (folder + '-manifest-before-integration.json')
    if not dest.exists(): shutil.copy2(p, dest)
    data = read(p); data['game_integration'] = {**integration,'stage':stage}
    for asset in data['assets']:
        matched = next((x for x in sources if x['id']==asset['id']),None)
        if matched:
            asset['game_integration'] = {**integration,'runtime':matched['runtime']}
            if 'review' in asset and 'not_game_integrated' in asset['review']:
                asset['review']['not_game_integrated'] = False
    write(p, data)

def figure(name, caption):
    filename = 'preview-entry-' + name + '.png'
    return f'<figure><a href="captures/{filename}" target="_blank"><img loading="lazy" src="captures/{filename}" alt="{html.escape(caption)}"></a><figcaption>{html.escape(caption)}</figcaption></figure>'
body = '<h1>八尺大人 · 裂口女</h1><p class="intro">0.11.0 实机查看 · 客厅黑门 → 怪谈异境 · 新</p><p>根目录「启动怪谈测试.cmd」可直接试玩；正式进度用「启动游戏.cmd」。每套五段连续地图，每段五名敌人。</p><p class="note">当前背景源高724–727像素，完整逐帧动作与接缝精修待制作。下图来自实际Godot渲染；分段与整排姿势图使用测试定位。</p>'
for stage, title in [(301,'八尺大人'),(302,'裂口女')]:
    body += f'<h2>{title}</h2>' + figure(f'{stage}-natural-combat','自然战斗 · 初始队伍，无额外战力注入')
    body += '<div class="grid">'
    for action, label in [('idle','五款待机姿势'),('attack','五款攻击姿势')]: body += figure(f'{stage}-all-{action}',label+' · 测试排位')
    for i in range(1,6): body += figure(f'{stage}-section-{i}',f'第{i}段 · 测试入口定位')
    body += figure(f'{stage}-victory','自然通关结算 · 25名敌人') + '</div>'
body += '<h2>入口与视口</h2><div class="grid">'
for name, label in [('portal-hasshaku','黑门选择八尺大人'),('portal-kuchisake','黑门选择裂口女'),('viewport-2560x1440','2560×1440实际渲染'),('viewport-3840x2160','3840×2160实际渲染')]:body += figure(name,label)
body += '</div><p>1538项既有回归、49项新模型、125项新入口实机检查通过；两个其他根入口验证通过。点击图片可看原始截图。</p>'
page = '<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>无限异常0.11.0 · 怪谈实装</title><style>body{max-width:1440px;margin:auto;padding:36px 24px;background:#111714;color:#edeade;font:16px/1.7 "Microsoft YaHei",sans-serif}h1{font-size:42px;margin-bottom:0}h2{margin-top:48px;border-top:2px solid #ffae42;padding-top:20px}.intro{font-size:22px;color:#ffae42}.note,figcaption{color:#bcc5bb}figure{margin:18px 0}img{display:block;width:100%;height:auto;background:#1c251f}figcaption{margin-top:8px}.grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:22px}@media(max-width:750px){.grid{grid-template-columns:1fr}body{padding:20px}h1{font-size:30px}}</style><body>' + body + '</body></html>'
(ART / 'index.html').write_text(page, 'utf-8')
print(json.dumps({k:v for k,v in summary.items() if k not in ['captures','harness_note']},ensure_ascii=False,indent=2))
