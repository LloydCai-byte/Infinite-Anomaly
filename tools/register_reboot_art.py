from pathlib import Path
import json,shutil
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
sources=json.loads((ROOT/'art/reboot-production/generated-sources.json').read_text('utf-8'))
sources.update({
 'base_t2':{'source':r'C:\Users\q\.codex\generated_images\01a0e366-79e6-7672-84a2-a0347e300381\exec-54107891-8920-4297-8f82-27b0f5c94659.png','folder':'backgrounds'},
 'equipment':{'source':r'C:\Users\q\.codex\generated_images\01a0e366-79e6-7672-84a2-a0347e300381\exec-fc1c3f3d-fdde-4077-892c-91411285b13e.png','folder':'equipment'}
})
(ROOT/'art/reboot-production/generated-sources.json').write_text(json.dumps(sources,indent=2),'utf-8')
manifest={}
for name,info in sources.items():
    dst=ROOT/'assets/reboot'/info['folder']/(name+'.png')
    dst.parent.mkdir(parents=True,exist_ok=True)
    shutil.copy2(info['source'],dst)
    im=Image.open(dst)
    entry={'path':dst.relative_to(ROOT).as_posix(),'size':list(im.size)}
    if info['folder'] in ('characters','enemies','equipment'):
        assert im.mode=='RGBA', (name,im.mode)
        alpha=im.getchannel('A')
        assert alpha.getextrema()[0]==0, 'Sprite must have actual alpha'
        rows=3 if name=='equipment' else 4
        w,h=im.size; cw,ch=w/4,h/rows; frames=[]
        row_edges={'crawler':[0,249,474,832,1254],'hollow':[0,253,478,848,1254],'hound':[0,300,560,940,1254]}.get(name,[round(k*h/rows) for k in range(rows+1)])
        for i in range(4*rows):
            x,y=round((i%4)*cw),row_edges[i//4]
            right,bottom=round((i%4+1)*cw),row_edges[i//4+1]
            # Inspect alpha only. Source pixels and transparency remain unchanged.
            bbox=alpha.crop((x,y,right,bottom)).point(lambda p:255 if p>36 else 0).getbbox()
            assert bbox is not None,(name,i)
            l,t,r,b=bbox
            frames.append({'region':[x+l,y+t,r-l,b-t], 'foot':[(x+right)/2,y+b]})
        entry['frames']=frames
        entry['cell']=[cw,ch]
    manifest[name]=entry
(ROOT/'assets/reboot/art_manifest.json').write_text(json.dumps(manifest,indent=2),'utf-8')
print(json.dumps({k:v['size'] for k,v in manifest.items()}))
