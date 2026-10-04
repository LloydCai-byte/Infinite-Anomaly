"""One-time, local-only integration of existing approved-style candidates.
Original images remain untouched; portraits use Godot AtlasTexture regions.
"""
from pathlib import Path
import json, shutil, hashlib

ROOT=Path(__file__).resolve().parents[1]
REG=ROOT/'assets/earth/asset_registry.json'
DEST=ROOT/'art/earth-production/integration-080'
SOURCE=ROOT/'art/storyboards/opening-20261001-cel-final-v01'

def run():
    DEST.mkdir(parents=True,exist_ok=True)
    if (DEST/'integration.json').exists():raise RuntimeError('Integration already recorded; revise explicitly rather than re-seed.')
    shutil.copy2(REG,DEST/'registry-before.json')
    shutil.copy2(ROOT/'assets/earth/opening.json',DEST/'opening-before.json')
    data=json.loads(REG.read_text('utf-8-sig')); entries={e['id']:e for e in data['entries']}; changes=[]
    def install(id,src,note=''):
        e=entries[id];dest=ROOT/e['target_path'];dest.parent.mkdir(parents=True,exist_ok=True)
        if dest.exists():raise RuntimeError('Existing replacement: '+str(dest))
        shutil.copy2(src,dest)
        e.update(candidate_path=src.relative_to(ROOT).as_posix(),integration_status='已接入待验收',review_status='待用户验收',replacement_version='0.8.0',review_evidence='')
        if note:e['notes']=note
        changes.append({'id':id,'source':src.relative_to(ROOT).as_posix(),'target':e['target_path'],'sha256':hashlib.sha256(dest.read_bytes()).hexdigest()})
    for src in sorted((SOURCE/'frames').glob('S*.png')):
        id=src.stem[1:]
        if id=='27':continue  # Antagonist incorrectly reappears after his removal.
        install('opening.'+id,src)
    install('opening.03', ROOT/'art/storyboards/opening-20261001-guide-redraw-v01/seven-cast-guide-1080p.png') if False else None
    # 03 is the latest user-guide redraw, replacing the first batch's candidate non-destructively.
    e=entries['opening.03'];src=ROOT/'art/storyboards/opening-20261001-guide-redraw-v01/seven-cast-guide-1080p.png'
    shutil.copy2(ROOT/e['target_path'],DEST/'S03-before-guide.png');shutil.copy2(src,ROOT/e['target_path'])
    e['candidate_path']=src.relative_to(ROOT).as_posix();e['notes']='接入最新指南重绘七人主镜；挑衅者外套与相邻镜仍待统一，不视作用户验收。';e['production_status']='待修订'
    for c in changes:
        if c['id']=='opening.03':c.update(source=e['candidate_path'],sha256=hashlib.sha256(src.read_bytes()).hexdigest())
    # Native sources + runtime regions retain source pixels, no synthesized face changes.
    regions={'dadong':[260,25,440,440],'fenfen':[255,30,440,440],'gao':[285,40,450,450],'wang':[240,30,440,440],'qiqi':[240,30,440,440],'xuan':[285,85,390,390]}
    cast=ROOT/'assets/earth/cel_cast';cast.mkdir(parents=True,exist_ok=True)
    for id,r in regions.items():
        src=SOURCE/'references'/f'{id}.png';dest=cast/f'{id}.png';shutil.copy2(src,dest)
        e=entries['portrait.'+id];e['target_path']=f'assets/earth/replacements/portraits/{id}.tres'
        target=ROOT/e['target_path'];target.parent.mkdir(parents=True,exist_ok=True)
        target.write_text('[gd_resource type="AtlasTexture" load_steps=2 format=3]\n\n[ext_resource type="Texture2D" path="res://assets/earth/cel_cast/'+id+'.png" id="1"]\n\n[resource]\natlas = ExtResource("1")\nregion = Rect2('+', '.join(map(str,r))+')\nfilter_clip = true\n','utf-8')
        e.update(candidate_path=src.relative_to(ROOT).as_posix(),integration_status='已接入待验收',review_status='待用户验收',replacement_version='0.8.0',spec='正方形头像；原人设图 AtlasTexture 裁切显示',notes='直接读取用户最新赛璐璐人设正面，保留原始像素；以后可替换为独立头像。',review_evidence='')
        changes.append({'id':e['id'],'source':e['candidate_path'],'target':e['target_path'],'region':r,'sha256':hashlib.sha256(src.read_bytes()).hexdigest()})
    e=entries['portrait.antagonist'];e['target_path']='assets/earth/replacements/portraits/antagonist.tres'
    (ROOT/e['target_path']).write_text('[gd_resource type="AtlasTexture" load_steps=2 format=3]\n\n[ext_resource type="Texture2D" path="res://assets/earth/replacements/opening/12.png" id="1"]\n\n[resource]\natlas = ExtResource("1")\nregion = Rect2(900, 20, 490, 490)\nfilter_clip = true\n','utf-8')
    e.update(candidate_path=entries['opening.12']['target_path'],integration_status='已接入待验收',review_status='待用户验收',production_status='待修订',replacement_version='0.8.0',spec='正方形头像；现有镜头 AtlasTexture 裁切显示',notes='沿用开场第12镜挑衅者；与03指南版配饰区别待统一。',review_evidence='')
    changes.append({'id':e['id'],'source':e['candidate_path'],'target':e['target_path']})
    # No incorrect cast resurrection and no false claim that 29–30 are new final frames.
    shots=json.loads((ROOT/'assets/earth/opening.json').read_text('utf-8-sig'))
    for s in shots:
        if (ROOT/entries['opening.'+s['id']]['target_path']).is_file():s['status']='cel-candidate-integrated'
        if s['id']=='06':s.update(status='native-time-card',presentation='time_card')
        if s['id']=='27':s.update(title='异常收集阵',line='这些印记……会记录我们带回来的异常？',status='existing-image-bridge',fallback_asset='room.workroom',camera_region=[970,80,940,529])
        if s['id']=='29':s.update(status='existing-image-bridge',fallback_asset='opening.28',line='准备好再出发。武器和战斗服是一整套。')
        if s['id']=='29b':s.update(status='existing-image-bridge',fallback_asset='opening.25',line='按手册检查一遍，别落下。')
        if s['id']=='30':s.update(status='existing-image-bridge',fallback_asset='room.living',line='准备好就从这扇门出发。祝你们好运。')
        if s['id']=='05':s['camera_region']=[120,0,1300,731] # Tighten threshold, exclude vacant host chair.
        if s['id']=='13':s['camera_region']=[365,90,1200,675] # Facial detail; exclude misplaced exit.
        if s['id']=='16':s['camera_region']=[40,90,1600,900] # Keep all five, exclude vacant chair.
        if s['id'] in ['02','03','05','13','16']:
            entries['opening.'+s['id']]['production_status']='待修订'
    for id in ['27','29','29b','30']:
        entries['opening.'+id]['notes']='当前以现有彩图衔接；专用镜头尚未完成，不记为已替换。'+(' 原27错误重现挑衅者，已停用。' if id=='27' else '')
    entries['opening.06']['notes']='游戏内原生黑底“五分钟后”时间卡；不依赖绘图。'
    entries['opening.06']['render_mode']='time_card'
    data['version']='0.8.0'
    REG.write_text(json.dumps(data,ensure_ascii=False,indent=2),'utf-8')
    (ROOT/'assets/earth/opening.json').write_text(json.dumps(shots,ensure_ascii=False,indent=2),'utf-8')
    (DEST/'integration.json').write_text(json.dumps({'version':'0.8.0','changes':changes,'bridged_shots':['27','29','29b','30'],'time_card':'06','uploads':False},ensure_ascii=False,indent=2),'utf-8')
    print(f'Installed {len(changes)} image/portrait entries; originals preserved.')
if __name__=='__main__':run()
