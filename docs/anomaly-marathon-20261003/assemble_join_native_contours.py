"""Cut and assemble existing AI pixels along matched contours, no pixel synthesis."""
import argparse,json,shutil
from pathlib import Path
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser();p.add_argument('--folder',required=True);p.add_argument('--join',type=int,required=True);a=p.parse_args()
b=ROOT/'art/anomaly-concepts/continuous-20261004'/a.folder/'reviews'
stem=f'join-{a.join:02}'
original=np.array(Image.open(b/f'{stem}-input.png').convert('RGB'))
repaint=np.array(Image.open(b/f'{stem}-repaint.png').convert('RGB'))
assert original.shape==repaint.shape
h,w,_=original.shape
err=np.abs(original.astype(float)-repaint.astype(float)).mean(2)
def path(lo,hi):
 cost=err[:,lo:hi];width=hi-lo
 previous=cost[0].copy();back=np.zeros((h,width),dtype=np.int16)
 for y in range(1,h):
  choices=[]
  for shift in range(-2,3):
   row=np.full(width,np.inf)
   if shift<0:row[-shift:]=previous[:width+shift]
   elif shift>0:row[:width-shift]=previous[shift:]
   else:row=previous.copy()
   choices.append(row+abs(shift)*.45)
  options=np.array(choices);select=options.argmin(0);back[y]=select-2
  previous=cost[y]+options[select,np.arange(width)]
 result=np.zeros(h,dtype=int);result[-1]=previous.argmin()
 for y in range(h-1,0,-1):result[y-1]=result[y]+back[y,result[y]]
 return result+lo
left=path(w//5,w//2-96);right=path(w//2+96,4*w//5)
assert np.all(left<right)
out=original.copy()
for y in range(h):out[y,left[y]:right[y]]=repaint[y,left[y]:right[y]]
target=b/f'{stem}-composite.png'
rect=b/f'{stem}-rectangular-composite.png'
if not rect.exists():shutil.copy2(target,rect)
Image.fromarray(out).save(target)
mp=b/f'{stem}-metadata.json';m=json.loads(mp.read_text(encoding='utf-8'))
m['previous_rectangular_crop']=m.get('selected_crop');m['selected_crop']=None
m['assembly']='Native pixel selection between two minimum-difference cut contours; no resampling, color correction, painting or blending'
m['cut_contours']={'left_x_by_row':left.tolist(),'right_x_by_row':right.tolist()}
m['needs_revision']=True;m['visual_review']='Native contour assembly awaiting visual inspection'
mp.write_text(json.dumps(m,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'join':a.join,'left_range':[int(left.min()),int(left.max())],'right_range':[int(right.min()),int(right.max())]},ensure_ascii=False))
