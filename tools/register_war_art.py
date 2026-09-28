"""Register untouched PNG atlases using alpha bounds. Never edits image pixels."""
from pathlib import Path
from PIL import Image
import json
ROOT=Path(__file__).resolve().parents[1]
manifest_path=ROOT/'assets/reboot/art_manifest.json'
manifest=json.loads(manifest_path.read_text(encoding='utf-8'))
sources=json.loads((ROOT/'art/reboot-war/generated-sources.json').read_text(encoding='utf-8'))
reports=[]
for key,data in sources.items():
 path=ROOT/'assets/reboot'/data['folder']/(key+'.png')
 if not path.exists(): raise RuntimeError(f'Missing final art {path}')
 im=Image.open(path)
 if data['folder']=='backgrounds':
  reports.append(dict(id=key,size=im.size,type='background'))
  continue
 cols,rows=(3,1) if key=='room_transport' else ((4,3) if key=='equipment_advanced' else (4,4))
 if im.mode!='RGBA': raise RuntimeError(f'{key}: must have native transparent alpha')
 alpha=im.getchannel('A')
 w,h=im.size
 if alpha.getextrema()[0]!=0: raise RuntimeError(f'{key}: no transparent background')
 # Detect meaningful ink, not tiny transparent-matte noise. This changes atlas
 # coordinates only; PNG pixels remain untouched. Boss rows may be taller.
 mask=alpha.point(lambda value: 255 if value>16 else 0)
 def gutter(edges,expected,span):
  groups=[]
  for point in edges:
   if groups and point==groups[-1][-1]+1: groups[-1].append(point)
   else: groups.append([point])
  candidates=[round((g[0]+g[-1])/2) for g in groups if len(g)>=3 and abs((g[0]+g[-1])/2-expected)<span*.45]
  if not candidates: raise RuntimeError(f'{key}: no safe atlas gutter at {expected}')
  return min(candidates,key=lambda point:abs(point-expected))
 y_edges=[0]
 for row in range(1,rows):
  middle=h*row/rows
  clear=[y for y in range(h) if sum(value>0 for value in mask.crop((0,y,w,y+1)).get_flattened_data())<=3]
  y_edges.append(gutter(clear,middle,h/rows))
 y_edges.append(h)
 frames=[]
 for row in range(rows):
  top,bottom=y_edges[row:row+2]
  x_edges=[0]
  for col in range(1,cols):
   middle=w*col/cols
   clear=[x for x in range(w) if sum(value>0 for value in mask.crop((x,top,x+1,bottom)).get_flattened_data())<=3]
   x_edges.append(gutter(clear,middle,w/cols))
  x_edges.append(w)
  for col in range(cols):
   left,right=x_edges[col:col+2]
   bounds=mask.crop((left,top,right,bottom)).getbbox()
   if bounds is None: raise RuntimeError(f'{key} empty frame {row*cols+col}')
   x,y,x2,y2=bounds
   x=max(0,x-2);y=max(0,y-2);x2=min(right-left,x2+2);y2=min(bottom-top,y2+2)
   region=[left+x,top+y,x2-x,y2-y]
   frames.append(dict(region=region,pivot=[w*(col+.5)/cols-region[0],region[3]]))
 manifest[key]=dict(path=path.relative_to(ROOT).as_posix(),cell=[w/cols,h/rows],frames=frames)
 reports.append(dict(id=key,size=im.size,type='atlas',frames=len(frames),alpha=True,regions=[f['region'] for f in frames]))
manifest_path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
(ROOT/'art/reboot-war/registration.json').write_text(json.dumps(reports,ensure_ascii=False,indent=2),encoding='utf-8')
print(f'Registered {len(sources)} final assets; kept existing manifests.')
