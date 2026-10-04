"""Preserve AI seam artwork and assemble native pixels; no resizing or painting."""
import argparse,json,hashlib,shutil
from pathlib import Path
from PIL import Image
import numpy as np
ROOT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser();p.add_argument('--folder',required=True);p.add_argument('--join',type=int,required=True);p.add_argument('--source',required=True);p.add_argument('--review',default='Awaiting composite visual inspection');p.add_argument('--revise',action='store_true');a=p.parse_args()
b=ROOT/'art/anomaly-concepts/continuous-20261004'/a.folder
src=Path(a.source);out=b/'reviews'/f'join-{a.join:02}-repaint.png'
if out.exists() and out.read_bytes()!=src.read_bytes():
 assert a.revise,'Use --revise to preserve the old candidate'
 old=hashlib.sha256(out.read_bytes()).hexdigest()[:12]
 for suffix in ['repaint.png','composite.png','metadata.json']:
  previous=b/'reviews'/f'join-{a.join:02}-{suffix}'
  if previous.exists():shutil.copy2(previous,b/'reviews'/f'join-{a.join:02}-previous-{old}-{suffix}')
 shutil.copy2(src,out)
elif not out.exists():shutil.copy2(src,out)
original=Image.open(b/'reviews'/f'join-{a.join:02}-input.png').convert('RGB');repaint=Image.open(out).convert('RGB')
assert original.size==repaint.size
w,h=original.size
x=np.asarray(original).astype(float);y=np.asarray(repaint).astype(float)
err=np.abs(x-y).mean(axis=(0,2));smooth=np.convolve(err,np.ones(9)/9,mode='same')
l=w//4+int(np.argmin(smooth[w//4:w//2-96]));r=w//2+96+int(np.argmin(smooth[w//2+96:3*w//4]))
original.paste(repaint.crop((l,0,r,h)),(l,0));original.save(b/'reviews'/f'join-{a.join:02}-composite.png')
meta=dict(join=a.join,generator='built-in image_gen',generated_source=str(src),repaint=out.relative_to(ROOT).as_posix(),sha256=hashlib.sha256(out.read_bytes()).hexdigest(),size=[w,h],selected_crop=[l,0,r,h],assembly='AI artwork cropped and pasted at native coordinates; no scaling, painting or blending',boundary_mean_abs_rgb_difference=[float(smooth[l]),float(smooth[r])],visual_review=a.review,user_approved=False)
(b/'reviews'/f'join-{a.join:02}-metadata.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(meta,ensure_ascii=False))
