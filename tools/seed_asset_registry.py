"""Create the initial, local-only replacement ledger. Never publishes anything."""
from pathlib import Path
import json, shutil, hashlib

ROOT=Path(__file__).resolve().parents[1]
if (ROOT/'assets/earth/asset_registry.json').exists():
    raise SystemExit('Registry already exists; refusing to reset statuses or copy over installed assets.')
OUT=ROOT/'docs/asset-replacement'
OUT.mkdir(parents=True,exist_ok=True)
rows=[]
def add(id,name,category,current='',target='',candidate='',spec='',used='',note='',ready=False,integrated=False):
    rows.append(dict(id=id,name=name,category=category,current_path=current,target_path=target,
        candidate_path=candidate,spec=spec,used_by=used,notes=note,
        production_status='已有候选' if ready else '待替换制作',
        integration_status='已接入待验收' if integrated else '未替换',review_status='待用户验收',
        replacement_version='0.7.0' if integrated else '',
        baseline_sha256=hashlib.sha256((ROOT/current).read_bytes()).hexdigest() if current and (ROOT/current).is_file() else ''))

add('menu','主菜单六人同框','菜单', 'assets/earth/menu.png','assets/earth/replacements/menu.png',
    'art/style-baselines/approved-20261001/user-approved-style.png','1920×1080 PNG','标题页',
    '旧菜单仍运行；用户认可参考不等于游戏菜单已换。',True)
shots=json.loads((ROOT/'assets/earth/opening.json').read_text('utf-8-sig'))
for s in shots:
    candidates=list((ROOT/'art/storyboards/opening-20261001-cel-final-v01').glob('**/S'+s['id']+'*.png'))
    # Explicit paths are reviewed candidates, never auto-installed during this audit.
    add('opening.'+s['id'],s['id']+' · '+s['title'],'开场分镜','assets/earth/opening/'+s['id']+'.png',
        'assets/earth/replacements/opening/'+s['id']+'.png',
        str(candidates[0].relative_to(ROOT)).replace('\\','/') if candidates else '',
        '1920×1080 PNG；整幅，无字幕','AVG '+s['id'],'保留线稿占位；人物、门向、房间连续性需验收。',bool(candidates))
people=[('dadong','大东老师','大东老师.png'),('fenfen','粉粉','粉粉.png'),('gao','高哥','高哥.png'),('wang','老王','老王.png'),('qiqi','七七','七七.png'),('xuan','轩轩','轩轩-房间主人.png'),('antagonist','挑衅者','')]
for id,name,file in people:
    add('portrait.'+id,name+' · 对话头像','头像','assets/earth/cast/'+file if file else '',
        'assets/earth/replacements/portraits/'+id+'.png','art/storyboards/opening-20261001-cel-final-v01/references/'+id+'.png',
        '512×512 PNG；方形胸像','AVG / 人物对话 / 小队',
        '当前按旧人设裁切显示；新版头像不可直接拿四视图塞入。' if file else '当前以名字代替。',False)

roomids=['living','workroom','kitchen','bathroom','bedroom','balcony','corridor']
roomnames=['客厅','工作间','厨房','卫生间','卧室','阳台','走廊']
for n,(id,name) in enumerate(zip(roomids,roomnames),1):
    source=f'art/room-layout/home-cel-1080p-20261001-v03/rooms/{n:02d}-{id}.png'
    dest=f'assets/earth/home/{id}.png'
    (ROOT/dest).parent.mkdir(parents=True,exist_ok=True)
    shutil.copy2(ROOT/source,ROOT/dest)
    add('room.'+id,name+' · 空房正视图','房间空景',dest,dest,source,'1920×1080 PNG','基地 '+name,
        '复用已交付空景，接入不代表美术通过；窗外昼夜待统一。',True,True)
source='art/room-layout/home-cel-1080p-20261001-v03/floorplan.png'
shutil.copy2(ROOT/source,ROOT/'assets/earth/home/floorplan.png')
shutil.copy2(ROOT/'art/room-layout/home-layout-20261001-v02/layout.json',ROOT/'assets/earth/home/layout.json')
add('floorplan','全屋户型快捷导航','户型图','assets/earth/home/floorplan.png','assets/earth/home/floorplan.png',source,
    '沿用户型图；热点按 layout.json 米坐标映射','基地户型图','布局提案仍可调整，当前只接通路径。',True,True)

presets=[{'living':[],'workroom':['gao','dadong'],'kitchen':['qiqi','wang'],'balcony':['fenfen']},
 {'living':['fenfen'],'workroom':['wang'],'bedroom':['qiqi'],'balcony':['dadong','gao']},
 {'living':['qiqi','wang'],'workroom':['fenfen'],'kitchen':['dadong','gao']},
 {'living':['gao'],'kitchen':['qiqi'],'bedroom':['fenfen'],'balcony':['wang','dadong']},
 {'living':['dadong'],'workroom':['wang','fenfen'],'kitchen':['gao'],'balcony':['qiqi']},
 {'living':[],'workroom':['qiqi','gao'],'kitchen':['fenfen'],'bedroom':['wang'],'balcony':['dadong']}]
names={p[0]:p[1] for p in people}
seen=set()
for p in presets:
    for room,ids in p.items():
        ids=sorted(ids+(['xuan'] if room=='living' else []))
        if not ids: continue
        key='home.'+room+'.'+'_'.join(ids)
        if key in seen:continue
        seen.add(key)
        add(key,roomnames[roomids.index(room)]+' · '+'＋'.join(names[i] for i in ids),'人物房间整图','',
            'assets/earth/replacements/home/'+key+'.png','', '1920×1080 PNG + 人物热区 JSON','基地返家组合',
            '整张绘制，禁止贴立绘；缺图时使用空景和姓名交互标记。热区同步到 home_hotspots.json。')

actions={'idle':'待机','move':'跑步','attack':'攻击','hit':'受击','fall':'倒地'}
for id,name,_ in people[:5]:
    for tier in range(1,4):
        for action,aname in actions.items():
            add(f'actor.{id}.t{tier}.{action}',f'{name} T{tier} · {aname}','战士动作','',
                f'assets/earth/actors/{id}/t{tier}/sprite_frames.tres','',
                f'SpriteFrames {action} + atlas PNG + motion.json；同套5动作共用容器',
                '战斗 '+name, '衣服与武器绑定；当前身份卡占位；文件存在不代表五个动作均通过验收。')
    for tier in range(1,4):
        add(f'suit.{id}.t{tier}',f'{name} T{tier} · 套装预览','套装展示','',
            f'assets/earth/replacements/suits/{id}-t{tier}.png','','800×1000 PNG；人物＋服装＋武器',
            '打印舱 / 小队穿戴','文字卡占位，实际立绘待换。')
areas=[('street','夜行街区'),('apartment','封闭公寓'),('rooftop','激光盒子'),('overpass','高架桥下'),('pumps','海边泵站'),('towers','通信塔群'),('freezer','冷冻仓库'),('observatory','旧观测台'),('mall','地下商场'),('metro','零号地铁')]
for id,name in areas:
    if id=='street':
        for n in range(1,6): add(f'battle.street.{n}',f'夜行街区长街 · 第{n}段','战场背景',f'assets/reboot/street/{n:02d}.png',f'assets/earth/replacements/battle/street-{n}.png','','16:9 PNG；五段接缝一致','地球任务1类')
    else: add('battle.'+id,name,'战场背景',f'assets/reboot/backgrounds/{id}.png',f'assets/earth/replacements/battle/{id}.png','','1920×1080 PNG','地球任务10主题×30阶')
enemies=['katana','hollow','eye','hound','parasite','beacon','frost','sentinel','mirror','warden']
for id,(_,name) in zip(enemies,areas):
    for kind in ['normal','boss']:
        add(f'enemy.{id}.{kind}',name+(' · 普通异常' if kind=='normal' else ' · 首领'),'异常动作','',
            f'assets/earth/replacements/enemies/{id}-{kind}/sprite_frames.tres','','idle/move/attack/hit/fall + motion.json',
            '地球战斗','当前复用旧异形序列/图集；新动画包按此固定入口切换。')
for id,name in [('laser','激光'),('regen','恢复'),('bomb','轰击')]:
    add('support.'+id,name+'支援装置卡图','支援装置','',f'assets/earth/replacements/support/{id}.png','','640×360 PNG','异常收集 / 支援','文字卡占位。')
for id in ['hit','heal','laser','enemy_laser','bomb']:
    add('effect.'+id,id+' · 战斗特效','战斗特效','',f'assets/earth/replacements/effects/{id}.tres','','SpriteFrames default；居中透明图集','战场效果','当前由线条、圆环、伤害数字绘制。')
for file in sorted((ROOT/'assets/reboot/ui').glob('*.svg')):
    # Track the actual shared texture vocabulary, not every occurrence of a button.
    if file.stem.startswith('button_') or file.stem in ['panel','card','dim','topbar','bottom_bar']:
        add('ui.'+file.stem,file.stem,'界面皮肤',file.relative_to(ROOT).as_posix(),f'assets/earth/replacements/ui/{file.name}','','SVG；保持九宫格边距','地球界面','覆盖文件放地球目录，避免修改旧版游戏。')
for file in sorted((ROOT/'assets/reboot/audio').glob('*.wav')):
    add('audio.'+file.stem,file.stem+' 音频','音乐音效',file.relative_to(ROOT).as_posix(),f'assets/earth/replacements/audio/{file.name}','','WAV / 同名 OGG 需改清单','地球音频','基准音频暂时沿用；未接线的音效将随功能接通。')

dest=ROOT/'assets/earth/asset_registry.json'
dest.write_text(json.dumps({'schema':1,'version':'0.7.0','entries':rows},ensure_ascii=False,indent=2),'utf-8')
(ROOT/'assets/earth/home/home_hotspots.json').write_text('{}','utf-8')
print(json.dumps({'entries':len(rows),'categories':{k:sum(r['category']==k for r in rows) for k in sorted({r['category'] for r in rows})}},ensure_ascii=False))
