"""Mechanical street stitching and generated-keyframe atlas import; no drawing APIs.

All original uploads and imagegen sheets remain in the task art directory.
This is temporary test art, not an approved suit or interpolated 60fps animation.
"""
from pathlib import Path
import hashlib, json, math
from collections import defaultdict
import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT/'art/earth-production/stage01-cel-motion-test-20261002'
PEOPLE = ['dadong','fenfen','gao','wang','qiqi']
NAMES = ['大东老师','粉粉','高哥','老王','七七']
CANVAS = (432,320)
PIVOT = (216,302)
ACTIONS = {'idle':([0,1,2,3],4,True), 'move':(list(range(4,12)),10,True),
           'attack':([12,13,14,15],10,False),'hit':([16,17],10,False),
           'fall':([17,18,19],6,False)}

def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()

def components(mask):
    """8-connected run-length labelling, avoiding optional native dependencies."""
    parent=[0]; runs=[]; prev=[]
    def root(i):
        while parent[i]!=i:
            parent[i]=parent[parent[i]];i=parent[i]
        return i
    for y,row in enumerate(mask):
        padded=np.pad(row.astype(np.int8),(1,1)); diff=np.diff(padded)
        starts=np.flatnonzero(diff==1);ends=np.flatnonzero(diff==-1)
        current=[]; cursor=0
        for x0,x1 in zip(starts,ends):
            while cursor<len(prev) and prev[cursor][1]<x0:cursor+=1
            overlaps=[];j=cursor
            while j<len(prev) and prev[j][0]<=x1:
                overlaps.append(root(prev[j][2]));j+=1
            if overlaps:
                ident=min(overlaps)
                for other in overlaps:parent[root(other)]=ident
            else:
                ident=len(parent);parent.append(ident)
            current.append((int(x0),int(x1),ident));runs.append((y,int(x0),int(x1),ident))
        prev=current
    groups={}; labels=np.zeros(mask.shape,np.int32)
    for y,x0,x1,ident in runs:
        ident=root(ident);labels[y,x0:x1]=ident
        if ident not in groups:groups[ident]=[x0,y,x1,y+1,0]
        g=groups[ident];g[0]=min(g[0],x0);g[1]=min(g[1],y)
        g[2]=max(g[2],x1);g[3]=max(g[3],y+1);g[4]+=x1-x0
    return labels,groups

def street():
    src=ART/'source-street'; images=[Image.open(src/f'{i:02}.png').convert('RGB') for i in range(1,6)]
    assert all(im.height==724 for im in images)
    overlap=32; width=sum(im.width for im in images)-overlap*4
    joined=Image.new('RGB',(width,724));joined.paste(images[0],(0,0));x=images[0].width
    seams=[]
    for im in images[1:]:
        x-=overlap;seams.append(x+overlap//2)
        left=joined.crop((x,0,x+overlap,724));right=im.crop((0,0,overlap,724))
        ramp=np.tile(np.linspace(0,255,overlap,dtype=np.uint8),(724,1))
        joined.paste(Image.composite(right,left,Image.fromarray(ramp)),(x,0))
        joined.paste(im.crop((overlap,0,im.width,724)),(x+overlap,0));x+=im.width
    joined.save(ART/'长街拼接原尺寸.png')
    preview=joined.copy();preview.thumbnail((2680,500));preview.save(ART/'previews/street-overview.jpg',quality=94)
    seam_preview=Image.new('RGB',(1200,724*4))
    for i,x in enumerate(seams):seam_preview.paste(joined.crop((x-600,0,x+600,724)),(0,724*i))
    seam_preview.thumbnail((900,2172));seam_preview.save(ART/'previews/street-seams.jpg',quality=92)
    output=ROOT/'assets/earth/replacements/battle/street';output.mkdir(parents=True,exist_ok=True)
    edges=[round(i*width/5) for i in range(6)]
    tiles=[]
    for i in range(5):
        path=output.parent/f'street-{i+1}.png';joined.crop((edges[i],0,edges[i+1],724)).save(path)
        tiles.append({'id':f'battle.street.{i+1}','path':path.relative_to(ROOT).as_posix(),'x':edges[i],'width':edges[i+1]-edges[i]})
    meta={'size':[width,724],'overlap_pixels':overlap,'seams':seams,'tiles':tiles,
          'processing':'原比例拼接；四处32像素窄重叠线性羽化，无重绘、无拉伸；再等分为运行时连续瓦片。',
          'source_files':[{'file':f'{i:02}.png','sha256':sha(src/f'{i:02}.png')} for i in range(1,7)]}
    (output/'layout.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2),'utf-8')
    return meta

def actor(person):
    source=ART/'source-sprites'/f'{person}.png';im=Image.open(source).convert('RGBA');arr=np.array(im)
    labels,groups=components(arr[:,:,3]>16)
    mains=sorted(groups,key=lambda k:groups[k][4],reverse=True)[:20]
    assert len(mains)==20 and min(groups[k][4] for k in mains)>4000, (person, 'insufficient poses')
    # Raised weapons can cross a mathematical row boundary; visual rows are
    # instead ordered by their upper silhouette edge, four subjects per row.
    top_order=sorted(mains,key=lambda k:groups[k][1])
    rows={r:top_order[r*4:r*4+4] for r in range(5)}
    ordered=[k for r in range(5) for k in sorted(rows[r],key=lambda k:groups[k][0])]
    # Keep disconnected details attached to their nearest major silhouette; no grid-edge limb cuts.
    owners={k:k for k in ordered}
    for k,g in groups.items():
        if k in owners:continue
        cx=(g[0]+g[2])/2;cy=(g[1]+g[3])/2
        def distance(target):
            b=groups[target]
            return max(b[0]-cx,0,cx-b[2])**2+max(b[1]-cy,0,cy-b[3])**2
        best=min(ordered,key=distance)
        if distance(best)<144:owners[k]=best
    mapping=np.zeros(int(labels.max())+1,np.int32)
    for k,owner in owners.items():mapping[k]=owner
    owned=mapping[labels]
    native=float(np.median([groups[k][3]-groups[k][1] for k in ordered[:4]]))
    scale=280/native
    result=[];coords=[]
    out=ROOT/'assets/earth/actors'/person/'temp-test';out.mkdir(parents=True,exist_ok=True)
    frame_dir=ART/'frames'/person;frame_dir.mkdir(parents=True,exist_ok=True)
    for index,k in enumerate(ordered):
        mask=owned==k;ys,xs=np.where(mask);bbox=(int(xs.min()),int(ys.min()),int(xs.max()+1),int(ys.max()+1))
        frame=arr.copy();frame[:,:,3]=np.where(mask,arr[:,:,3],0)
        crop=Image.fromarray(frame).crop(bbox)
        # Translate whole key poses; preserve scale and crouch/fall compression.
        body=mask[max(bbox[1],int(bbox[3]-native*.55)):int(bbox[3]-native*.3)]
        torso_x=np.where(body)[1]
        anchor=float(np.median(torso_x)) if len(torso_x)>0 and index!=19 else (bbox[0]+bbox[2])/2
        crop=crop.resize((round(crop.width*scale),round(crop.height*scale)),Image.Resampling.LANCZOS)
        dest=(round(PIVOT[0]+(bbox[0]-anchor)*scale),PIVOT[1]-crop.height)
        assert dest[0]>=0 and dest[0]+crop.width<=CANVAS[0] and dest[1]>=0,(person,index,dest,crop.size)
        canvas=Image.new('RGBA',CANVAS);canvas.alpha_composite(crop,dest);result.append(canvas)
        canvas.save(frame_dir/f'{index:02}.png');coords.append({'frame':index,'source_bbox':bbox,'anchor_x':anchor,'dest':dest})
    atlas=Image.new('RGBA',(CANVAS[0]*4,CANVAS[1]*5))
    for index,frame in enumerate(result):atlas.alpha_composite(frame,((index%4)*CANVAS[0],(index//4)*CANVAS[1]))
    atlas.save(out/'atlas.png')
    rel=out.relative_to(ROOT).as_posix()
    lines=['[gd_resource type="SpriteFrames" load_steps=22 format=3]','',f'[ext_resource type="Texture2D" path="res://{rel}/atlas.png" id="atlas"]']
    for index in range(20):lines+=['',f'[sub_resource type="AtlasTexture" id="f{index}"]','atlas = ExtResource("atlas")',f'region = Rect2({index%4*432}, {index//4*320}, 432, 320)','filter_clip = true']
    lines+=['','[resource]','animations = [']
    for ai,(name,(indices,fps,loop)) in enumerate(ACTIONS.items()):
        frames=', '.join('{ "duration": 1.0, "texture": SubResource("f%d") }'%i for i in indices)
        lines+=['{',f'"frames": [{frames}],',f'"loop": {str(loop).lower()},',f'"name": &"{name}",',f'"speed": {fps}.0','}'+(',' if ai<4 else '')]
    lines+= [']'];(out/'sprite_frames.tres').write_text('\n'.join(lines)+'\n','utf-8')
    meta={'temporary':True,'source':source.relative_to(ROOT).as_posix(),'source_sha256':sha(source),'canvas':list(CANVAS),
          'pivot':list(PIVOT),'native_height':280,'stride_pixels':245 if person!='qiqi' else 220,
          'source_direction':1,'keyframe_count':20,'actions':{k:len(v[0]) for k,v in ACTIONS.items()},
          'method':'内置imagegen生成20个独立姿势；透明区域切帧、统一比例和脚底基准。未插帧，不是60fps源动作。',
          'costume':'现有人设日常服＋临时T1武器，所有套装级别在无正式动作时共用本测试形象；不代表正式战斗服已完成。',
          'source_coordinates':coords}
    (out/'motion.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2),'utf-8')
    for action,(indices,fps,loop) in ACTIONS.items():
        ordered_frames=[result[i] for i in indices]
        if action not in ['idle','move']:ordered_frames += [result[indices[-1]]]*4+[result[0]]*3
        ordered_frames[0].save(ART/'previews'/f'{person}-{action}.webp',save_all=True,append_images=ordered_frames[1:],duration=round(1000/fps),loop=0,lossless=True)
    return meta,result

def main():
    street_meta=street();people={};idle=[]
    for person in PEOPLE:
        meta,frames=actor(person);people[person]=meta;idle.append(frames[0]);print(person,meta['keyframe_count'],'keyframes')
    strip=Image.new('RGB',(5*300,380),(29,42,55))
    for i,frame in enumerate(idle):
        frame.thumbnail((300,320));strip.paste(frame,(i*300,15),frame)
    strip.save(ART/'previews/five-heroes.png')
    manifest={'version':'0.9.0-stage01-test','status':'临时效果测试，待用户评价','street':street_meta,'actors':people}
    (ART/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),'utf-8')
    print('street',street_meta['size'])

if __name__=='__main__':main()
