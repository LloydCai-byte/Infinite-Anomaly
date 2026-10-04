"""Assemble reviewed native scenes and AI join repaints, then register after inspection."""
import argparse,json,hashlib
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[2];D=ROOT/'docs/anomaly-marathon-20261003'
p=argparse.ArgumentParser();p.add_argument('--anomaly',required=True);p.add_argument('--register',action='store_true');a=p.parse_args()
qp=D/'queue.json';q=json.loads(qp.read_text(encoding='utf-8'));it=next(i for i in q['items'] if i['id']==a.anomaly)
b=(ROOT/it['spec_path']).parent
scenes=[Image.open(b/'scenes'/f'{n:02}.png').convert('RGB') for n in range(1,6)]
assert len({im.size for im in scenes})==1
w,h=scenes[0].size;pan=Image.new('RGB',(5*w,h));sources=[]
for n,im in enumerate(scenes):pan.paste(im,(n*w,0))
for n in range(1,5):
 mp=b/'reviews'/f'join-{n:02}-metadata.json';m=json.loads(mp.read_text(encoding='utf-8'))
 assert m.get('needs_revision') is False,(n,m.get('visual_review'))
 piece=b/'reviews'/f'join-{n:02}-composite.png';im=Image.open(piece).convert('RGB');assert im.size==(w,h)
 pan.paste(im,(n*w-w//2,0));sources.append({'join':n,'file':piece.relative_to(ROOT).as_posix(),'sha256':hashlib.sha256(piece.read_bytes()).hexdigest(),'metadata':mp.relative_to(ROOT).as_posix()})
out=b/'panorama.png';pan.save(out)
tiles=b/'continuous-scenes';tiles.mkdir(exist_ok=True)
for n in range(5):pan.crop((n*w,0,(n+1)*w,h)).save(tiles/f'{n+1:02}.png')
asset=dict(id=a.anomaly+'-P01',kind='panorama',file=out.relative_to(ROOT).as_posix(),size=list(pan.size),sha256=hashlib.sha256(out.read_bytes()).hexdigest(),generator='native assembly of built-in image_gen outputs',status='reviewed_local_art_draft' if a.register else 'awaiting_full_panorama_inspection',resampled=False,uploaded=False,user_approved=False,source_scenes=[x['id'] for x in it['assets'] if x['kind']=='scene'],join_sources=sources,continuous_scene_directory=tiles.relative_to(ROOT).as_posix(),review={'visual':'五段及四处接缝逐一复核；当前普通尺寸静态美术草案，非像素无缝或用户最终验收。','user_approved':False})
(b/'reviews'/'panorama-assembly.json').write_text(json.dumps(asset,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
if a.register:
 old=next((x for x in it['assets'] if x['id']==asset['id']),None)
 if old:it['assets'][it['assets'].index(old)]=asset
 else:it['assets'].append(asset)
 for x in it['assets']:
  if x['kind']=='scene':
   n=int(x['id'][-2:]);cp=tiles/f'{n:02}.png'
   x['review']['continuity']='reviewed_in_repainted_panorama_pending_user'
   x['continuous_file']=cp.relative_to(ROOT).as_posix();x['continuous_sha256']=hashlib.sha256(cp.read_bytes()).hexdigest()
 for task in q.get('local_revision_tasks',[]):
  if task['id']==f'B0002-{a.anomaly}-seams':task.update(status='resolved_local_draft_pending_user',detail='四处内置重绘接缝已拼回并复核；原图保留，用户评价尚未完成。',evidence=(b/'reviews'/'panorama-assembly.json').relative_to(ROOT).as_posix())
 qp.write_text(json.dumps(q,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'anomaly':a.anomaly,'size':list(pan.size),'registered':a.register,'output':str(out)},ensure_ascii=False))
