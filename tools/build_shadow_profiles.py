"""Read unchanged sprite alpha to calibrate sole landmarks; output data, never repaint art."""
from pathlib import Path
from PIL import Image,ImageStat
import hashlib,json
ROOT=Path(__file__).resolve().parents[1]
ART=ROOT/'art/pixel-hyakki-level-20261024/sprites'
OUT=ROOT/'assets/pixel_campaign/ground_shadows.json'
ROSTER=json.loads((ART/'roster.json').read_text(encoding='utf-8-sig'))
REGIONS={
    'fenfen':[(30,72),(72,112)],'wang':[(35,72),(72,115)],
    'oni':[(20,68),(68,116)],'dadong':[(35,72),(72,116)],
    'gao':[(30,72),(72,116)],'qiqi':[(33,72),(72,116)],
    'tengu':[(34,75),(75,110)],'umbrella':[(58,104)],
    'kappa':[(30,72),(72,110)],'wheel':[(46,80),(80,108)],
}
def sole(image,region):
    left,right=region;alpha=image.getchannel('A')
    # Restrict to authored lower-leg windows so swords, clubs and flames never set the footprint.
    bottom=next((y for y in range(135,101,-1) if sum(alpha.getpixel((x,y))>=128 for x in range(left,right))>=3),None)
    if bottom is None:raise ValueError(f'No sole in {region}')
    xs=[x for y in range(bottom-2,bottom+1) for x in range(left,right) if alpha.getpixel((x,y))>=128]
    return {'x':round((min(xs)+max(xs)+1)*.5,2),'y':bottom+1,'width':max(xs)-min(xs)+1}
result={'schema':1,'anchor':[80,128],'frame_size':[160,144],'actors':{},'scenes':{},'source_hashes':{}}
def remember(path):result['source_hashes']['res://'+path.relative_to(ROOT).as_posix()]=hashlib.sha256(path.read_bytes()).hexdigest()
for actor,meta in ROSTER.items():
    path=ART/actor/'base.png';base=Image.open(path).convert('RGBA');remember(path)
    standing=[sole(base,region) for region in REGIONS[actor]]
    entry={'standing':standing,'clips':{}}
    for clip in ['idle','walk','attack','hurt']:
        path=ART/actor/('base.png' if clip=='idle' else clip+'.png');remember(path)
        atlas=Image.open(path).convert('RGBA');spec=meta['clips'][clip];poses=[]
        for i in range(1 if clip=='idle' else spec['frames']):
            x=i%spec['columns']*160;y=i//spec['columns']*144
            frame=atlas.crop((x,y,x+160,y+144))
            feet=[sole(frame,region) for region in REGIONS[actor]]
            for foot,reference in zip(feet,standing):
                foot['ground_y']=max(foot['y'],reference['y']);foot['lift']=max(0,reference['y']-foot['y'])
            poses.append(feet)
        entry['clips'][clip]=poses
    result['actors'][actor]=entry
campaign=json.loads((ROOT/'assets/pixel_campaign/first_two.json').read_text(encoding='utf-8-sig'))
for level in campaign['levels']:
    for scene in level['scenes']:
        key=scene['image'];path=ROOT/key.removeprefix('res://');im=Image.open(path).convert('RGB')
        # Same cover fit used by the battle renderer, sampled from its walkable ground strip.
        scale=max(1600/im.width,900/im.height);offx=(1600-im.width*scale)/2;offy=(900-im.height*scale)/2
        box=tuple(round(v) for v in ((70-offx)/scale,(610-offy)/scale,(1530-offx)/scale,(785-offy)/scale))
        rgb=ImageStat.Stat(im.crop(box)).median;r,g,b=rgb
        if r>g*1.15:family='warm';color='#281c25'
        elif b>r*1.1:family='cool';color='#172333'
        elif g>r*1.1:family='green';color='#14231f'
        else:family='neutral';color='#1b2027'
        result['scenes'][key]={'color':color,'outer_alpha':.24 if max(rgb)>65 else .20,'ground_family':family,'sample_rgb':rgb}
OUT.write_text(json.dumps(result,ensure_ascii=False,separators=(',',':')),encoding='utf-8')
print('Ground profiles:',len(result['actors']),'actors,',sum(len(v) for a in result['actors'].values() for v in a['clips'].values()),'poses,',len(result['scenes']),'scene palettes')
