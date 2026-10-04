"""Verify actual files, hashes, chroma margins and native panorama reconstruction."""
import argparse,json,hashlib
from pathlib import Path
from PIL import Image
import numpy as np
ROOT=Path(__file__).resolve().parents[2];D=ROOT/'docs/anomaly-marathon-20261003'
p=argparse.ArgumentParser();p.add_argument('--batch',required=True);a=p.parse_args()
q=json.loads((D/'queue.json').read_text(encoding='utf-8'));items=[i for i in q['items'] if i.get('batch')==a.batch and i['relation']=='primary']
report={'batch':a.batch,'status':'verified_local_art_draft_pending_user','remote_writes':False,'game_integration':False,'upscaled':False,'items':[]}
for it in items:
 b=(ROOT/it['spec_path']).parent;assets=it['assets'];assert len(assets)==16,(it['id'],len(assets))
 assert len({x['id'] for x in assets})==16
 checks=[]
 for x in assets:
  f=ROOT/x['file'];im=Image.open(f);assert list(im.size)==x['size'];assert hashlib.sha256(f.read_bytes()).hexdigest()==x['sha256']
  assert not x.get('uploaded');assert not x.get('user_approved');assert not x.get('resampled')
  if x['kind']!='panorama':assert (ROOT/x['prompt']).is_file();assert x['generator']=='built-in image_gen'
  if x['kind'] in ['side_green','side_green_attack']:
   rgb=np.array(im.convert('RGB'),dtype=np.int16);g=(rgb[:,:,1]>170)&(rgb[:,:,1]>rgb[:,:,0]+100)&(rgb[:,:,1]>rgb[:,:,2]+100);ys,xs=np.nonzero(~g);h,w=g.shape
   margins=[xs.min()/w,ys.min()/h,(w-xs.max()-1)/w,(h-ys.max()-1)/h];assert min(margins)>.075
   assert all(t.mean()>.995 for t in [g[:10],g[-10:],g[:,:10],g[:,-10:]])
  checks.append({'id':x['id'],'size':x['size'],'sha256':x['sha256'],'verified':True})
 pan=np.array(Image.open(b/'panorama.png'));parts=np.concatenate([np.array(Image.open(b/'continuous-scenes'/f'{n:02}.png')) for n in range(1,6)],axis=1);assert np.array_equal(pan,parts)
 for n in range(1,5):
  m=json.loads((b/'reviews'/f'join-{n:02}-metadata.json').read_text(encoding='utf-8'));assert m.get('needs_revision') is False;assert m['visual_review'];assert not m['user_approved']
 cr={'status':'reviewed_local_draft_pending_user','native_size_each':[2172,724],'joined_size':[10860,724],'resampled':False,'findings':['四接口已内置重绘并拼回，原生逐接口和全景目检；不将局部目检等同用户验收或4K验收。'],'panorama_counted_complete':True}
 (b/'reviews'/'continuity-review.json').write_text(json.dumps(cr,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
 report['items'].append({'id':it['id'],'generated_images':15,'derived_panoramas':1,'files':checks,'five_tiles_reconstruct_panorama':True,'joins_reviewed':4})
report['total_generated_images']=sum(x['generated_images'] for x in report['items']);report['total_derived_panoramas']=len(items)
out=D/f'{a.batch.lower()}-builtin-verification-20261004.json';out.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({k:v for k,v in report.items() if k!='items'},ensure_ascii=False))
