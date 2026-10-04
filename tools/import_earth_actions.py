"""Extract an explicitly reviewed action cut list into keyed 60fps sprite atlases.

Usage: python tools/import_earth_actions.py --spec relative/spec.json
No generation APIs, network, or automatic guessed cuts. FFmpeg motion interpolation
is recorded as interpolation, never described as sixty newly drawn source frames.
"""
from pathlib import Path
import argparse, hashlib, json, math, subprocess
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
FFMPEG=Path(r'D:\ChatCut\resources\app.asar.unpacked\node_modules\ffmpeg-ffprobe-static\ffmpeg.exe')
ACTIONS=('idle','move','attack','hit','fall')

def run(spec_path):
    spec=json.loads(spec_path.read_text(encoding='utf-8-sig'))
    source=(ROOT/spec['source']).resolve()
    output=(ROOT/spec['output']).resolve()
    if not output.is_relative_to(ROOT): raise ValueError('Output must stay in project')
    if set(spec['actions'])!=set(ACTIONS): raise ValueError('Exactly five reviewed action ranges required')
    if not spec.get('cuts_reviewed'): raise ValueError('Review source frames before approving cut positions')
    if spec.get('stride_pixels',0)<=0: raise ValueError('Measured runtime stride required')
    output.mkdir(parents=True,exist_ok=True)
    canvas=spec.get('canvas',[432,248]); fps=60
    records={}; pngs=[]
    for action in ACTIONS:
        cut=spec['actions'][action]
        duration=cut['end']-cut['start']
        if duration<=0 or duration>8: raise ValueError('Invalid reviewed segment')
        folder=output/'frames'/action; folder.mkdir(parents=True,exist_ok=True)
        excess='(g(X,Y)-max(r(X,Y),b(X,Y)))'
        key=f"format=rgba,geq=r='if(gte({excess},40),0,r(X,Y))':g='if(gte({excess},40),0,min(g(X,Y),max(r(X,Y),b(X,Y))+4))':b='if(gte({excess},40),0,b(X,Y))':a='255*clip((40-{excess})/32,0,1)',format=rgba"
        vf=f"minterpolate=fps=60:mi_mode=mci:mc_mode=aobmc:me_mode=bidir,scale={canvas[0]}:{canvas[1]}:flags=lanczos,{key}"
        # Extra tail frames allow the interpolator to resolve its final output sample.
        count=max(2,round(duration*fps))
        cmd=[str(FFMPEG),'-hide_banner','-loglevel','error','-ss',str(cut['start']),'-i',str(source),'-t',str(duration+.2),'-vf',vf,'-frames:v',str(count),'-start_number','0','-y',str(folder/'%04d.png')]
        subprocess.run(cmd,check=True)
        files=sorted(folder.glob('*.png'))[:count]
        if len(files)!=count: raise ValueError(f'{action}: expected {count}, received {len(files)}')
        records[action]={'loop':action in ('idle','move'),'frames':[]}
        for file in files:
            im=Image.open(file).convert('RGBA'); bbox=im.getchannel('A').getbbox()
            if not bbox: raise ValueError('Empty keyed frame '+str(file))
            cropped=im.crop(bbox)
            ident=len(pngs); pngs.append((cropped,bbox,ident))
            records[action]['frames'].append(ident)
    # Tight shelf packing, transparent margin is reconstructed in AtlasTexture.
    page_size=2048; pages=[]; page=Image.new('RGBA',(page_size,page_size)); x=y=2; row=0; atlas={}
    for im,bbox,ident in sorted(pngs,key=lambda item:-item[0].height):
        if x+im.width+2>page_size: x=2;y+=row+4;row=0
        if y+im.height+2>page_size:
            pages.append(page);page=Image.new('RGBA',(page_size,page_size));x=y=2;row=0
        page.paste(im,(x,y));atlas[ident]={'page':len(pages),'rect':[x,y,im.width,im.height],'offset':[bbox[0],bbox[1]]}
        x+=im.width+4;row=max(row,im.height)
    pages.append(page)
    rel=output.relative_to(ROOT).as_posix()
    lines=[f'[gd_resource type="SpriteFrames" load_steps={1+len(pages)+len(pngs)} format=3]','']
    for i,page in enumerate(pages):
        name=f'atlas-{i:02}.png';page.save(output/name)
        lines.append(f'[ext_resource type="Texture2D" path="res://{rel}/{name}" id="p{i}"]')
    for ident in range(len(pngs)):
        info=atlas[ident];rect=info['rect'];off=info['offset']
        lines += ['',f'[sub_resource type="AtlasTexture" id="f{ident}"]',f'atlas = ExtResource("p{info["page"]}")',f'region = Rect2({", ".join(map(str,rect))})',f'margin = Rect2({off[0]}, {off[1]}, {canvas[0]-rect[2]}, {canvas[1]-rect[3]})','filter_clip = true']
    lines+=['','[resource]','animations = [']
    for i,(name,record) in enumerate(records.items()):
        frames=',\n'.join(f'{{ "duration": 1.0, "texture": SubResource("f{ident}") }}' for ident in record['frames'])
        lines+=['{','"frames": [',frames,'],',f'"loop": {str(record["loop"]).lower()},',f'"name": &"{name}",','"speed": 60.0','}'+(',' if i<4 else '')]
    lines+= [']']; (output/'sprite_frames.tres').write_text('\n'.join(lines),encoding='utf-8')
    manifest={'source':spec['source'],'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'interpolation':'FFmpeg motion compensated 60fps; original footage retained','canvas':canvas,'pivot':spec.get('pivot',[216,235]),'stride_pixels':spec['stride_pixels'],'native_height':spec.get('native_height',224),'reviewed_cuts':spec['actions'],'frame_count':len(pngs),'texture_pages':len(pages),'estimated_uncompressed_mib':len(pages)*16}
    (output/'motion.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps(manifest,ensure_ascii=False))

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--spec',required=True)
    run((ROOT/parser.parse_args().spec).resolve())
