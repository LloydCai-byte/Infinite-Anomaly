"""Copy approved-direction originals unchanged; measure pivots for runtime chroma keying."""
from pathlib import Path
import json,hashlib,shutil
from PIL import Image
import numpy as np
ROOT=Path(__file__).resolve().parents[1]
DOC=ROOT/'docs/kaidan-integration-011';DOC.mkdir(parents=True,exist_ok=True)
ART=ROOT/'art/earth-production/kaidan-integration-011';ART.mkdir(parents=True,exist_ok=True)
(ART/'captures').mkdir(exist_ok=True)
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def save(p,v):p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
for name in ['scripts/earth/catalog.gd','scripts/earth/model.gd','scripts/earth/main.gd','scripts/earth/battle_view.gd','tools/build_earth.gd','tools/build_earth.ps1','project.godot','assets/earth/asset_registry.json','启动地球篇.cmd']:
    target=DOC/'before'/name;target.parent.mkdir(parents=True,exist_ok=True)
    if not target.exists():shutil.copy2(ROOT/name,target)
reg=read(ROOT/'assets/earth/asset_registry.json');reg['version']='0.11.0';new=[];catalog=[];sources=[]
names=[('K004-hasshaku',301,'hasshaku',[.9,1.2,.58,.72,1.4]),('K005-kuchisake',302,'kuchisake',[.9,.7,1.15,1.0,1.08])]
for folder,stage,key,heights in names:
    base=ROOT/'art/anomaly-concepts/continuous-20261003'/folder;spec=read(base/'spec.json');mf=read(base/'manifest.json')
    dest=ROOT/'assets/earth/anomalies'/key;dest.mkdir(parents=True,exist_ok=True)
    entry={'id':spec['id'],'key':key,'stage':stage,'name':spec['name'],'source_boundary':spec['source_boundary'],'scenes':[],'enemies':[],'height':900,'native_hd':False,'animation_method':'Two authored poses with runtime movement, recoil and fall; not full frame animation.'}
    for a in mf['assets']:
        if a['kind']=='panorama':continue
        src=ROOT/a['file'];assert sha(src)==a['sha256'];out=dest/('scene-'+a['id'][-2:]+'.png' if a['kind']=='scene' else Path(a['file']).name)
        if out.exists():assert sha(out)==sha(src)
        else:shutil.copy2(src,out)
        path=out.relative_to(ROOT).as_posix();sources.append({'id':a['id'],'source':a['file'],'runtime':path,'sha256':sha(out)})
        is_scene=a['kind']=='scene';n=int(a['id'][-2:] if is_scene else a['id'].split('-M')[1][:2]);label=spec['scenes'][n-1]['name'] if is_scene else spec['enemies'][n-1]['name']
        rid='anomaly.'+key+('.scene.%d'%n if is_scene else '.enemy.%d.'%n+('idle' if a['kind']=='side_green' else 'attack'))
        new.append({'id':rid,'name':spec['name']+' · '+label+('' if is_scene else ' · '+('待机' if a['kind']=='side_green' else '攻击')),'category':'怪谈场景' if is_scene else '怪谈角色姿势','current_path':path,'target_path':path,'candidate_path':a['file'],'spec':f"原生{a['size'][0]}×{a['size'][1]} PNG",'used_by':'家中黑门 / '+spec['name'],'notes':'背景保持源比例，高清与接缝待精修。' if is_scene else '原绿幕PNG不改写；游戏shader按色差透明化及去绿边。两张原姿势配合运行时动作，不是完整序列帧。','production_status':'已有候选','integration_status':'已接入待验收','review_status':'待用户验收','replacement_version':'0.11.0','baseline_sha256':sha(out),'review_evidence':''})
    cursor=0.0
    for s in spec['scenes']:
        file=dest/f"scene-{s['n']:02}.png";w,h=Image.open(file).size;width=w*900/h
        entry['scenes'].append({'id':s['id'],'name':s['name'],'path':'res://'+file.relative_to(ROOT).as_posix(),'size':[w,h],'world_x':cursor,'world_width':width,'encounter_x':cursor+width*.52})
        cursor+=width
    entry['world_width']=cursor
    for e,height in zip(spec['enemies'],heights):
        enemy={'id':e['id'],'name':e['name'],'height':215*height,'lore':e['lore'],'attack_steps':e['attack_steps'],'poses':{}}
        for action,suffix in [('idle','side'),('attack','attack')]:
            file=dest/f"{e['n']:02}-{suffix}-green.png";im=Image.open(file).convert('RGB');arr=np.asarray(im).astype(np.float32)/255
            foreground=arr[:,:,1]-np.maximum(arr[:,:,0],arr[:,:,2])<.35
            yy,xx=np.where(foreground);x0,x1=int(xx.min()),int(xx.max()+1);y0,y1=int(yy.min()),int(yy.max()+1)
            fy,fx=np.where(foreground[max(y0,y1-28):y1]);pivot_x=float((fx.min()+fx.max())/2)
            enemy['poses'][action]={'path':'res://'+file.relative_to(ROOT).as_posix(),'bbox':[x0,y0,x1,y1],'pivot':[pivot_x,y1],'native_height':y1-y0,'size':list(im.size)}
        # Use idle scale for both poses to avoid squash during a crouched attack.
        enemy['native_height']=enemy['poses']['idle']['native_height'];entry['enemies'].append(enemy)
    catalog.append(entry)
for e in new:
    old=next((i for i in reg['entries'] if i['id']==e['id']),None)
    if old:reg['entries'][reg['entries'].index(old)]=e
    else:reg['entries'].append(e)
save(ROOT/'assets/earth/asset_registry.json',reg)
save(ROOT/'assets/earth/anomalies/catalog.json',{'version':'0.11.0','entries':catalog})
save(DOC/'source-manifest.json',{'copied_originals':sources,'count':len(sources),'processing':'PNG bytes unchanged; pivot/bounds analysis only; runtime shader keys green','formal_animation':False,'native_hd':False})
print(json.dumps({'copied_originals':len(sources),'registry_entries':len(reg['entries']),'stages':[301,302]},ensure_ascii=False))
