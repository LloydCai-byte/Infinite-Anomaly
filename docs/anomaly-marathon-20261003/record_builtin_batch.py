"""Record native scene outputs and refresh local batch checkpoints/gallery."""
import argparse, hashlib, html, json, shutil
from pathlib import Path
from datetime import datetime,timezone,timedelta
from PIL import Image
ROOT=Path(__file__).resolve().parents[2]
D=ROOT/'docs/anomaly-marathon-20261003'
ART=ROOT/'art/anomaly-concepts/continuous-20261004'
def read(p): return json.loads(p.read_text(encoding='utf-8'))
def save(p,v): p.write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
p=argparse.ArgumentParser()
p.add_argument('--anomaly');p.add_argument('--scene',type=int);p.add_argument('--source');p.add_argument('--prompt');p.add_argument('--review');p.add_argument('--refresh',action='store_true')
p.add_argument('--revise',action='store_true')
a=p.parse_args();q=read(D/'queue.json')
stamp=datetime.now(timezone(timedelta(hours=8))).isoformat()
if a.scene:
 it=next(x for x in q['items'] if x['id']==a.anomaly)
 base=(ROOT/it['spec_path']).parent
 src=Path(a.source);dst=base/'scenes'/f'{a.scene:02}.png'
 sha=hashlib.sha256(src.read_bytes()).hexdigest();size=list(Image.open(src).size)
 assert 2.6<size[0]/size[1]<3.3, size
 assert (ROOT/a.prompt).is_file()
 if dst.exists() and hashlib.sha256(dst.read_bytes()).hexdigest()!=sha:
  assert a.revise,'Revision must preserve prior candidate'
  oldsha=hashlib.sha256(dst.read_bytes()).hexdigest()
  shutil.copy2(dst,base/'reviews'/f'scene-{a.scene:02}-previous-{oldsha[:12]}.png')
  shutil.copy2(src,dst)
 elif not dst.exists(): shutil.copy2(src,dst)
 asset=dict(id=f'{a.anomaly}-S{a.scene:02}',kind='scene',file=dst.relative_to(ROOT).as_posix(),size=size,sha256=sha,generator='built-in image_gen',generated_source=str(src),prompt=a.prompt,status='reviewed_local_art_draft',uploaded=False,user_approved=False,resampled=False,review=dict(visual=a.review,continuity='pairwise_join_review_pending',user_approved=False))
 prev=next((x for x in it['assets'] if x['id']==asset['id']),None)
 if prev and prev['sha256']!=sha:
  assert a.revise
  asset['previous_versions']=prev.get('previous_versions',[])+[{k:v for k,v in prev.items() if k!='previous_versions'}]
  it['assets'][it['assets'].index(prev)]=asset
 elif prev: assert prev['sha256']==sha
 else: it['assets'].append(asset)
 save(base/'reviews'/f'{asset["id"]}.json',asset)
for it in q['items']:
 if not it.get('spec_path') or 'continuous-20261004' not in it['spec_path']: continue
 base=(ROOT/it['spec_path']).parent;mf=read(base/'manifest.json')
 for kind,key in [('scene','scenes'),('side_green','side_green'),('side_green_attack','side_green_attacks'),('panorama','panoramas')]:
  it['completed'][key]=max(it['completed'].get(key,0),sum(x['kind']==kind for x in it['assets']))
 mf.update(assets=it['assets'],generated_images=sum(x['kind']!='panorama' for x in it['assets']),derived_panoramas=sum(x['kind']=='panorama' for x in it['assets']),updated_at=stamp)
 mf['status']='complete_pending_user_review' if len(mf['assets'])==mf['expected_new_images'] else 'in_progress'
 save(base/'manifest.json',mf)
 if it.get('batch'): it['status']=mf['status']
prim=[it for it in q['items'] if it['relation']=='primary']
q['counts']['scene_plans_detailed']=sum(5 for it in prim if it.get('spec_path'))
for key,done in [('scenes','scenes_complete'),('side_green','side_green_complete'),('side_green_attacks','side_green_attacks_complete')]:
 q['counts'][done]=sum(it['completed'].get(key,0) for it in prim)
for kind,key in [('scenes','current_phase_missing_scenes'),('side_green','current_phase_missing_side_green'),('side_green_attacks','current_phase_missing_attack_green')]:
 q['counts'][key]=1675-sum(it['completed'].get(kind,0) for it in prim)
q['builtin_art_phase_20261004']['generated_selected_since_resume']=sum(sum(x['kind']!='panorama' for x in it['assets']) for it in prim if it.get('spec_path') and 'continuous-20261004' in it['spec_path'])
batch=next(x for x in q['batches'] if x['id']==q['current']['batch'])
items=[it for it in prim if it['id'] in batch['anomalies']]
batch['generated_images']=sum(len(it['assets']) for it in items)
missing=[]
for it in items:
 selected={x['id'] for x in it['assets']};aid=it['id']
 want=[f'{aid}-S{n:02}' for n in range(1,6)]+[f'{aid}-M{n:02}-{t}' for n in range(1,6) for t in ['G','A']]+[f'{aid}-P01']
 missing.extend(x for x in want if x not in selected)
missing.sort(key=lambda x:'-P' in x)
if missing:
 q['current'].update(anomaly=missing[0].split('-')[0],next_assets=missing[:2],phase='builtin_art_generation')
else:
 batch['status']='complete_pending_user_review'
 nxt=next((b for b in q['batches'] if b['status']=='queued'),None)
 if nxt:q['current']=dict(batch=nxt['id'],batch_anomalies=nxt['anomalies'],anomaly=nxt['anomalies'][0],phase='local_detailed_design_before_generation',next_assets=[nxt['anomalies'][0]+'-S01'],stop_after_batch=False)
q['updated_at']=stamp;save(D/'queue.json',q)
cards=[]
for it in prim:
 if not it.get('spec_path') or 'continuous-20261004' not in it['spec_path']:continue
 spec=read(ROOT/it['spec_path']);assets=it['assets'];cards.append(f'<section><h2>{it["id"]} · {html.escape(it["name"])}</h2><p>{html.escape(spec.get("source_boundary","原创游戏改编；静态图待评价。"))}</p>')
 scenes=[x for x in assets if x['kind'] in ['scene','panorama']]
 for x in scenes:
  href=(ROOT/x.get('continuous_file',x['file'])).relative_to(ART).as_posix()
  cls='panorama' if x['kind']=='panorama' else 'scene'
  label='连续长图，可横向滚动' if x['kind']=='panorama' else ('接缝修订后分段' if x.get('continuous_file') else '生成原图')
  cards.append(f'<figure><div class="{cls}"><a href="{href}"><img src="{href}" loading="lazy"></a></div><figcaption>{x["id"]} · {x["size"][0]}×{x["size"][1]} · {label} · 待评价</figcaption></figure>')
 for e in spec['enemies']:
  cards.append(f'<h3>{html.escape(e["name"])}</h3><p>{html.escape(e["lore"])}</p><div class="pair">')
  for tag,label in [('G','侧视待机'),('A','侧视攻击')]:
   x=next((x for x in assets if x['id']==f'{it["id"]}-M{e["n"]:02}-{tag}'),None)
   if x:
    href=(ROOT/x['file']).relative_to(ART).as_posix();cards.append(f'<figure><a href="{href}"><img src="{href}" loading="lazy" alt="{html.escape(e["name"])} {label}"></a><figcaption>{label} · {x["size"][0]}×{x["size"][1]}</figcaption></figure>')
   else:cards.append(f'<figure class="pending">{label}待生成</figure>')
  cards.append('</div><p>'+html.escape(' → '.join(e['attack_steps']))+'</p>')
 cards.append('</section>')
page='<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>连续美术 · 普通分辨率</title><style>body{background:#171c20;color:#e7e4dc;font:16px/1.65 sans-serif;margin:24px auto;max-width:1500px;padding:0 20px}h1,h2,h3{font-weight:500}section{margin-bottom:36px;padding:20px;background:#242c32}.pair{display:grid;grid-template-columns:1fr 1fr;gap:16px}figure{margin:12px 0 28px}img{display:block;width:100%}.pending{background:#303b44;min-height:120px;display:grid;place-items:center}a{color:#e9c083}@media(max-width:700px){.pair{grid-template-columns:1fr}}</style><h1>连续美术 · 普通分辨率</h1><p>内置绘图 · 点击查看原PNG · 所有新图待用户美术评价，4K在全部定稿之后。绿幕是静态有色背景，尚未抠像或制作动画。</p>'
(ART/'index.html').write_text(page+'<style>.panorama{overflow-x:auto}.panorama img{height:420px;width:auto;max-width:none}</style>'+''.join(cards)+'</html>',encoding='utf-8')
print(json.dumps({'recorded':f'{a.anomaly}-S{a.scene:02}' if a.scene else 'refresh','batch_images':batch['generated_images'],'next':q['current']},ensure_ascii=False))
