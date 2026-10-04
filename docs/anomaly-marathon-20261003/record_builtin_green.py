"""Save an already visually inspected generated PNG unchanged and advance its checkpoint."""
import argparse, hashlib, html, json, shutil
from pathlib import Path
from datetime import datetime, timezone, timedelta
import numpy as np
from PIL import Image

ROOT=Path(__file__).resolve().parents[2]
D=Path(__file__).resolve().parent
def read(p): return json.loads(p.read_text(encoding='utf-8'))
def save(p,v): p.write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
p=argparse.ArgumentParser()
p.add_argument('--anomaly',required=True)
p.add_argument('--monster',required=True,type=int)
p.add_argument('--kind',required=True,choices=['idle','attack'])
p.add_argument('--source',required=True)
p.add_argument('--prompt',required=True)
p.add_argument('--review',required=True)
args=p.parse_args()
q=read(D/'queue.json')
assert q['builtin_art_phase_20261004']['generator']=='built-in image_gen only'
item=next(x for x in q['items'] if x['id']==args.anomaly)
base=(ROOT/item['spec_path']).parent
spec=read(base/'spec.json')
tag='G' if args.kind=='idle' else 'A'
aid=f'{args.anomaly}-M{args.monster:02}-{tag}'
kind='side_green' if tag=='G' else 'side_green_attack'
src=Path(args.source)
dest=base/'enemies'/f'{args.monster:02}-{"side" if tag=="G" else "attack"}-green.png'
sha=hashlib.sha256(src.read_bytes()).hexdigest()
im=Image.open(src)
rgb=np.asarray(im.convert('RGB'),dtype=np.int16)
h,w=rgb.shape[:2]
green=(rgb[:,:,1]>170)&(rgb[:,:,1]>rgb[:,:,0]+100)&(rgb[:,:,1]>rgb[:,:,2]+100)
edge=np.concatenate((green[:10].ravel(),green[-10:].ravel(),green[:,:10].ravel(),green[:,-10:].ravel()))
ys,xs=np.nonzero(~green)
assert len(xs)>0,'No visible subject'
box=[int(xs.min()),int(ys.min()),int(xs.max()+1),int(ys.max()+1)]
margin=[box[0]/w,box[1]/h,(w-box[2])/w,(h-box[3])/h]
metrics={'size':[w,h],'subject_bbox':box,'margins_ltrb':margin,'green_border_fraction':float(edge.mean()),'reference_background_rgb':[int(x) for x in rgb[0,0]]}
assert edge.mean()>.995,metrics
assert min(margin)>.075,metrics
assert 1.4<w/h<1.6,metrics
if dest.exists(): assert hashlib.sha256(dest.read_bytes()).hexdigest()==sha,'Keep previous versions; explicit revision required'
else: shutil.copy2(src,dest)
assert hashlib.sha256(dest.read_bytes()).hexdigest()==sha
asset={'id':aid,'kind':kind,'file':dest.relative_to(ROOT).as_posix(),'size':[w,h],'sha256':sha,'generator':'built-in image_gen','generated_source':str(src),'prompt':args.prompt,'status':'reviewed_local_art_draft','uploaded':False,'review':{'visual':args.review,'method':'assistant visual inspection plus green-edge/subject-margin measurements','single_pose':True,'side_direction':'right','user_approved':False,'not_animation':True,'not_transparent':True,**metrics}}
old=next((x for x in item['assets'] if x['id']==aid),None)
if old: assert old['sha256']==sha
else: item['assets'].append(asset)
for typ,key in [('side_green','side_green'),('side_green_attack','side_green_attacks')]:
    item['completed'][key]=sum(a['kind']==typ for a in item['assets'])
item['completed']['attacks']=max(item['completed'].get('attacks',0),item['completed']['side_green_attacks'])
for kind,key in [('side_green','side_green_complete'),('side_green_attacks','side_green_attacks_complete')]:
    q['counts'][key]=sum(x['completed'].get(kind,0) for x in q['items'] if x['relation']=='primary')
q['counts']['current_phase_missing_side_green']=q['counts']['side_green_required']-q['counts']['side_green_complete']
q['counts']['current_phase_missing_attack_green']=q['counts']['side_green_required']-q['counts']['side_green_attacks_complete']
stamp=datetime.now(timezone(timedelta(hours=8))).isoformat()
q['updated_at']=stamp
mf=read(base/'manifest.json')
mf['assets']=item['assets']
mf['updated_at']=stamp
mf['generated_images']=sum(a['kind']!='panorama' for a in item['assets'])
mf['derived_panoramas']=sum(a['kind']=='panorama' for a in item['assets'])
mf['status']='complete_pending_user_review' if len(item['assets'])==mf.get('expected_new_images',16) else 'in_progress'
save(base/'manifest.json',mf)
save(base/'reviews'/f'{aid}.json',asset)
if q['current']['batch']=='R0000':
    ids=['K002','K003']
    selected={a['id'] for x in q['items'] if x['id'] in ids for a in x['assets'] if a['kind'] in ['side_green','side_green_attack']}
    missing=[f'{an}-M{n:02}-{t}' for an in ids for n in range(1,6) for t in ['G','A'] if f'{an}-M{n:02}-{t}' not in selected]
    back=next(b for b in q['revision_backlog'] if b['id']=='R0000')
    back['generated_images']=len(selected)
    back['status']='complete_pending_user_review' if not missing else 'in_progress'
    if missing:
        q['current']['next_assets']=missing[:2]
        q['current']['anomaly']=missing[0].split('-')[0]
    else:
        q['current']={'batch':'B0002','batch_anomalies':['K006','K007'],'anomaly':'K006','phase':'local_detailed_design_before_generation','next_assets':['K006-S01'],'stop_after_batch':False}
    gallery=ROOT/'art/anomaly-concepts/continuous-20261004/index.html'
    cards=[]
    for an in ids:
        it=next(x for x in q['items'] if x['id']==an)
        sp=read(ROOT/it['spec_path'])
        cards.append(f'<h2>{html.escape(it["name"])}</h2>')
        for e in sp['enemies']:
            cards.append(f'<section><h3>{html.escape(e["name"])}</h3><p>{html.escape(e["lore"])}</p><div class="pair">')
            for tag,label in [('G','待机侧视'),('A','攻击侧视')]:
                a=next((a for a in it['assets'] if a['id']==f'{an}-M{e["n"]:02}-{tag}'),None)
                if a:
                    href=(ROOT/a['file']).relative_to(gallery.parent).as_posix()
                    cards.append(f'<figure><a href="{href}"><img src="{href}" loading="lazy" alt="{html.escape(e["name"])} {label}"></a><figcaption>{label} · {a["size"][0]}×{a["size"][1]} · 待评价</figcaption></figure>')
                else: cards.append(f'<figure class="pending">{label}待生成</figure>')
            cards.append('</div><p>'+html.escape(' → '.join(e['attack_steps']))+'</p></section>')
    gallery.write_text('<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>连续美术 · 普通分辨率</title><style>body{background:#171c20;color:#e7e4dc;font:16px/1.65 sans-serif;margin:24px auto;max-width:1400px;padding:0 20px}h1,h2,h3{font-weight:500}section{margin-bottom:36px;padding:20px;background:#242c32}.pair{display:grid;grid-template-columns:1fr 1fr;gap:16px}figure{margin:0}img{display:block;width:100%}.pending{background:#303b44;min-height:200px;display:grid;place-items:center}a{color:#e9c083}@media(max-width:700px){.pair{grid-template-columns:1fr}}</style><h1>连续美术 · 普通分辨率</h1><p>内置绘图 · R0000旧角色绿幕补制 '+str(len(selected))+'/20 · 画风待逐图评价，4K后续统一制作。点击图片查看原PNG。</p>'+''.join(cards)+'</html>',encoding='utf-8')
if q['current']['batch']!='R0000':
    current_batch=q['current']['batch']
    batch_items=[x for x in q['items'] if x.get('batch')==current_batch and x['relation']=='primary']
    missing=[]
    for it in batch_items:
        selected={a['id'] for a in it['assets']};an=it['id']
        want=[f'{an}-S{n:02}' for n in range(1,6)]+[f'{an}-M{n:02}-{t}' for n in range(1,6) for t in ['G','A']]+[f'{an}-P01']
        missing.extend(x for x in want if x not in selected)
    missing.sort(key=lambda x:'-P' in x)
    if missing:q['current'].update(next_assets=missing[:2],anomaly=missing[0].split('-')[0])
    batch=next((b for b in q['batches'] if b['id']==current_batch),None)
    if batch:batch['generated_images']=sum(len(it['assets']) for it in batch_items)
q['builtin_art_phase_20261004']['generated_selected_since_resume']=sum(sum(a['kind']!='panorama' for a in it['assets']) for it in q['items'] if it.get('spec_path') and 'continuous-20261004' in it['spec_path'])
save(D/'queue.json',q)
print(json.dumps({'asset':aid,'metrics':metrics,'next':q['current'],'global_side_green':q['counts']['side_green_complete'],'global_attack_green':q['counts']['side_green_attacks_complete']},ensure_ascii=False))
