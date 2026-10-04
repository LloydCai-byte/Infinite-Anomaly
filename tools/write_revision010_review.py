"""Write the local delivery review after the packaged launchers have passed."""
from pathlib import Path
import json
import html

root = Path(__file__).resolve().parents[1]
art = root / 'art/earth-production/revision-010'
docs = root / 'docs/revision-20261002'
shots = [
    ('package-portal', '黑门 · 选择异常', 'combat'),
    ('12-door-opening', '开门进入对应世界', 'combat'),
    ('13-victory-loot', '结算 · 继续下一异常与战利品', 'combat'),
    ('15-equipment-equipped', '装备 · 词条、穿戴与转交', 'combat'),
    ('16-spirit-battle', '战斗 · 头盔召唤精灵发射激光', 'combat'),
    ('package-preview-entry', '第一关快捷入口 · 临时进度', 'combat'),
    ('02-living', '客厅 · 去除多余书柜及地点标签', 'room'),
    ('03-corridor', '走廊 · 连接三个房间', 'room'),
    ('04-kitchen', '厨房', 'room'),
    ('05-bathroom', '卫生间', 'room'),
    ('06-bedroom', '卧室', 'room'),
    ('07-balcony', '阳台 · 与客厅统一为傍晚', 'room'),
    ('08-workroom', '工作间 · 普通装饰与完整打印舱', 'room'),
    ('01-menu', '主菜单', 'ui'),
    ('09-printer', '打印舱', 'ui'),
    ('10-locked-portal', '未开放异常 · 可预览不可进入', 'ui'),
    ('14-equipment-before', '装备 · 穿戴前对比', 'ui'),
    ('17-recall', '召回 · 重试或返回房间', 'ui'),
    ('18-squad', '小队情况', 'ui'),
    ('19-support', '支援装置', 'ui'),
    ('20-growth', '个人成长', 'ui'),
    ('21-suits', '整套战斗服与武器', 'ui'),
    ('22-space', '主神空间', 'ui'),
    ('23-settings', '设置', 'ui'),
]
cards = []
for name, title, group in shots:
    image = art / 'captures' / (name + '.png')
    assert image.is_file(), image
    cards.append(f'<figure data-group="{group}"><a href="captures/{name}.png" target="_blank"><img loading="lazy" src="captures/{name}.png" alt="{html.escape(title)}"></a><figcaption>{html.escape(title)}<small>点击查看原尺寸实机截图</small></figcaption></figure>')

page = '''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>无限异常 · 修改10.1 · 0.10.0</title><style>
*{box-sizing:border-box}body{margin:0;background:#101716;color:#ecede5;font:16px/1.65 system-ui,"Microsoft YaHei",sans-serif}main{max-width:1440px;margin:auto;padding:42px 30px 70px}h1{font-size:38px;line-height:1.2;margin:12px 0 22px}h2{font-size:24px;margin-top:35px}.eyebrow{color:#ffb243;font-weight:700;letter-spacing:2px}.lead{max-width:920px;color:#c3cac2}a{color:#b0e572}nav{display:flex;gap:12px;flex-wrap:wrap;margin:24px 0}nav a,button{padding:10px 18px;border:1px solid #697c71;background:#19221e;color:#edf0e6;text-decoration:none;font:inherit;cursor:pointer}button.active{border-color:#94d651;background:#2c3c22}.facts{display:grid;grid-template-columns:repeat(auto-fit,minmax(220px,1fr));gap:14px}.fact{padding:18px;border-left:3px solid #ffa830;background:#18201d}.fact strong{display:block;font-size:21px}.fact span{color:#adb9b0;font-size:14px}.gallery{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:22px}figure{margin:0;background:#19211e;border:1px solid #35463c}figure img{display:block;width:100%;aspect-ratio:16/9;object-fit:contain;background:#0c110e}figcaption{padding:14px 18px}small{display:block;color:#9bab9f;font-size:12px}.note{padding:18px 22px;background:#231f17;border-left:3px solid #efb04f}.before{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:16px}.before img{width:100%;display:block}details{margin:18px 0}summary{cursor:pointer;padding:12px;background:#1a251e}.hidden{display:none}footer{margin-top:44px;color:#9bab9f}@media(max-width:800px){main{padding:25px 16px}.gallery,.before{grid-template-columns:1fr}h1{font-size:29px}}
</style><main><div class="eyebrow">INFINITE ANOMALY / 0.10.0</div><h1>修改 10.1 · 本地试玩与实机记录</h1><p class="lead">依据飞书《修改 10.1》revision 228 完成 UI、房间连续性、黑门选关、连续出战和装备支援。正常入口与第一关快捷入口均已用实际发行包验证。此页图片为 Godot 实机截图，美术仍待你评价。</p>
<nav><a href="../../../docs/revision-20261002/README.md">完整修改说明</a><a href="../../../docs/asset-replacement/index.html">素材替换台账</a><a href="../../../docs/revision-20261002/signature-weapon-pipeline.md">专属武器动作制作流程</a><a href="../../../docs/revision-20261002/verification-summary.json">验证记录</a></nav>
<div class="facts"><div class="fact"><strong>黑门 → 异常世界</strong><span>选关预览、开门过渡、挑战与记录</span></div><div class="fact"><strong>战后可继续</strong><span>下一异常、重复挑战、整理装备、返家培养</span></div><div class="fact"><strong>装备 + 词条 + 精灵</strong><span>3槽位 · 6基础装备 · 3类召唤效果</span></div><div class="fact"><strong>7个房间已遍历</strong><span>移除户型入口 · 修正书柜、阳台、收集阵</span></div></div>
<h2>建议试玩顺序</h2><p>双击项目根目录 <b>启动游戏.cmd</b>，进入家中后点黑门 → 挑战第一关 → 结算整理战利品 → 给粉粉穿戴棱镜头盔 → 返回结算继续下一异常，观察精灵发射激光。快速查看长街与临时动作可用 <b>启动第一关测试.cmd</b>。</p><p class="note">五主角仍使用此前临时动作；粉粉三套战斗服方向尚未选择，正式套装和专属武器视频未生成。本轮数值是首版实现，未完成长期平衡。没有上传飞书或 GitHub。</p>
<h2>实机截图</h2><nav id="filters"><button class="active" data-filter="all">全部</button><button data-filter="combat">选关 / 装备 / 战斗</button><button data-filter="room">七个房间</button><button data-filter="ui">系统界面</button></nav><div class="gallery">''' + '\n'.join(cards) + '''</div><h2>三张房间图与提示词</h2><p>由内置 image_gen 编辑。原始生成尺寸1672×941，交付导出1920×1080；旧图及原始生成文件均保留。</p>'''
for room, title in [('living', '客厅'), ('balcony', '阳台'), ('workroom', '工作间')]:
    # Before files are named with the corresponding room id.
    choices = list((art / 'before').glob(f'*{room}*.png'))
    if not choices:
        raise RuntimeError(f'Missing archived before image for {room}')
    before = choices[0].relative_to(art).as_posix()
    page += f'<details><summary>{title} · 修改前后</summary><div class="before"><figure><img loading="lazy" src="{before}" alt="{title}修改前"><figcaption>修改前</figcaption></figure><figure><img loading="lazy" src="../../../assets/earth/home/{room}.png" alt="{title}修改后"><figcaption>已接入游戏 · 待评价</figcaption></figure></div><p><a href="prompts/{room}.txt">本次编辑提示词</a> · <a href="rooms/{room}-original.png">原始生成图</a></p></details>'
page += '''<footer>来源、SHA256与待验收状态：<a href="manifest.json">manifest.json</a>。历史发行包和存档保留。</footer></main><script>document.querySelectorAll('#filters button').forEach(b=>b.onclick=()=>{document.querySelectorAll('#filters button').forEach(x=>x.classList.toggle('active',x===b));document.querySelectorAll('.gallery figure').forEach(f=>f.classList.toggle('hidden',b.dataset.filter!=='all'&&f.dataset.group!==b.dataset.filter))});</script></html>'''
(art / 'index.html').write_text(page, encoding='utf-8')

summary = {
    'version': '0.10.0', 'source_revision': 228,
    'model': json.loads((docs / 'model-test.json').read_text(encoding='utf-8')),
    'ui': json.loads((docs / 'ui-test.json').read_text(encoding='utf-8')),
    'packaged_root_launcher': json.loads((docs / 'package-test.json').read_text(encoding='utf-8')),
    'packaged_preview_launcher': json.loads((docs / 'preview-entry-test.json').read_text(encoding='utf-8')),
    'regression_checks': {'stage1': 12, 'stage2': 14, 'stage3': 10, 'stage4': 9, 'stage5': 8, 'assets': 443, 'homeflow': 160, 'cel_integration': 160, 'stage01_art': 220, 'gait': 7, 'persistence': 14},
    'package_entries': len(json.loads((root / 'builds/InfiniteAnomaly-Earth-0.10.0/files.json').read_text(encoding='utf-8-sig'))),
    'capture_count': len(list((art / 'captures').glob('*.png'))),
    'visual_review': 'Actual RTX 5060 Godot Compatibility renderer; no low-end hardware validation.',
    'scope': 'First-stage natural victory and feature/regression checks; not a new 300-stage balance certification.',
    'uploaded_feishu': False, 'pushed_github': False,
}
summary['checks_total_excluding_package'] = summary['model']['checks'] + summary['ui']['checks'] + sum(summary['regression_checks'].values())
assert all(summary[k]['failures'] == 0 for k in ['model', 'ui', 'packaged_root_launcher', 'packaged_preview_launcher'])
(docs / 'verification-summary.json').write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding='utf-8')
print(json.dumps({'review': str(art / 'index.html'), 'checks': summary['checks_total_excluding_package'], 'package_entries': summary['package_entries'], 'screenshots': summary['capture_count']}, ensure_ascii=False))
