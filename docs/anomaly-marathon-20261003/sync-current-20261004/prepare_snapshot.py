import hashlib, json, pathlib, re
from PIL import Image
from sync_checkpoint import ROOT, OUT, SHEETS, save, cells

ART=ROOT/'art/anomaly-concepts/continuous-20261004'
specs={p.parent.name:json.loads(p.read_text(encoding='utf-8')) for p in sorted(ART.glob('*/spec.json'))}
writes=[]; final=[]; images=[]; notes=[]; counts={}; rows={'monsters':12,'scenes':12,'panoramas':4,'plans':22}
HD='按2026-10-04新指令先完成普通原生分辨率美术，全部确认后统一4K；当前不称原生4K成品。'
GREEN='朝右侧视静态绿幕；有色背景，尚未抠透明或制作动画；待用户评价。'

def row(table,n,values,dest=writes):
    dest.append({'sheet_id':SHEETS[table],'range':f'A{n}:{chr(64+len(values))}{n}','cells':[[{'value':str(x)} for x in values]]})

def block(table,cell,values,dest=final):
    dest.append({'sheet_id':SHEETS[table],'range':cell,'cells':[[{'value':str(x)} for x in values]]})

def image(table,cell,asset,extra=''):
    path=asset.get('continuous_file',asset['file'])
    f=ROOT/path
    sha=hashlib.sha256(f.read_bytes()).hexdigest()
    expected=asset.get('continuous_sha256',asset.get('sha256'))
    if expected: assert sha==expected,(path,sha,expected)
    with Image.open(f) as im: size=list(im.size)
    assert size==asset['size'],(path,size,asset['size'])
    a={'id':asset['id'],'sheet_id':SHEETS[table],'range':cell,'file':path,'sha256':sha,'size':size,'bytes':f.stat().st_size,'kind':asset['kind']}
    images.append(a)
    notes.append({'sheet_id':a['sheet_id'],'range':cell,'cells':[[{'note':f'{path}\nSHA256 {sha}\n真实尺寸{size[0]}×{size[1]}；{extra}'}]]})

for slug,spec in specs.items():
    manifest=json.loads((ART/slug/'manifest.json').read_text(encoding='utf-8'))
    assets={a['id']:a for a in manifest['assets']}
    aid=spec['id']; name=spec['name']; counts[aid]={'selected_images':len(assets),'generated_originals':sum(a['kind']!='panorama' for a in assets.values()),'panoramas':sum(a['kind']=='panorama' for a in assets.values())}
    for enemy in spec['enemies']:
        eid=enemy['id']; idle=assets.get(eid+'-G'); attack=assets.get(eid+'-A')
        if not idle or not attack: continue
        n=rows['monsters'];rows['monsters']+=1
        row('monsters',n,[eid,name,enemy['name'],'待嵌入待机原图','待嵌入攻击原图',enemy['lore'],' → '.join(enemy['attack_steps']),enemy['silhouette'],enemy.get('palette','')+'；'+enemy.get('height',''),enemy.get('origin','原创改编'),f'原生{idle["size"][0]}×{idle["size"][1]}；{GREEN}',enemy.get('green_constraints',GREEN),''])
        image('monsters',f'D{n}',idle,GREEN);image('monsters',f'E{n}',attack,GREEN)
    for scene in spec['scenes']:
        sid=scene.get('id',f'{aid}-S{scene["n"]:02d}')
        asset=assets.get(sid)
        if asset:
            n=rows['scenes'];rows['scenes']+=1
            seam='接缝重绘并以原像素裁接，本地复核，待用户评价' if asset.get('continuous_file') else '场景原图已出；跨段接缝和长图尚待复核'
            row('scenes',n,[sid,name,scene['name'],'待嵌入原图',scene['description'],scene.get('layers',''),f'左：{scene["left"]}\n右：{scene["right"]}',f'{asset["size"][0]}×{asset["size"][1]}',seam+'；未接入游戏',spec['source_boundary'],HD,''])
            image('scenes',f'D{n}',asset,seam)
        if aid in ['K006','K007','K008','K009']:
            n=rows['plans'];rows['plans']+=1
            status='本地先写方案后画；本次补同步飞书，非远端前置。'+('尚未出图' if not asset else ('原图已出，接缝待复核' if aid=='K008' else '原图及长图已出，本地复核待用户评价'))
            row('plans',n,[sid,name,spec['batch'],int(aid[1:]),scene['name'],scene['description']+'\n'+scene['layers'],spec['map_geometry'],scene['lighting'],scene['left'],scene['right'],scene['avoid'],HD,status,spec['source_boundary'],''])
    for asset in assets.values():
        if asset['kind']!='panorama':continue
        n=rows['panoramas'];rows['panoramas']+=1
        row('panoramas',n,[asset['id'],name,' → '.join(s['name'] for s in spec['scenes']),'待嵌入长图',f'{asset["size"][0]}×{asset["size"][1]}','五段原像素连续图；内置绘图修补接缝；未插值放大','四处接缝已本地复核；待用户评价',HD,spec['combat'],spec['source_boundary'],''])
        image('panoramas',f'D{n}',asset,'衍生五段连续图；未插值放大；待用户评价')

trial={'id':'K004-REF-20261004','kind':'style_reference','file':'art/anomaly-concepts/hasshaku-redraw-20261004-v02/generated/04-chatcut-nano-4k.png','size':[6336,2688],'sha256':'3df575f6383ea220ae86c071ef1dc40e44ea87ad0a10a5e04a874039139a1c38'}
n=rows['scenes'];rows['scenes']+=1
row('scenes',n,[trial['id'],'八尺大人','乡村风格试片（已认可方向）','待嵌入参考原图','独立乡村方向参考，不计入本批五段连续地图。','细密日式建筑、植被和真实村道路面','独立试片，非五段接缝验收','6336×2688','用户认可效果方向；其他单图仍待评价','本轮禁用ChatCut之前的历史试片；此次只归档上传，未调用ChatCut生成','按用户新要求，后续先普通分辨率定稿，最后统一4K',''])
image('scenes',f'D{n}',trial,'历史乡村试片；用户认可效果方向；不计入本批生成数量')

# Progress columns L (user feedback) and other unrequested rows are never written.
for n in [2,3]:
    block('progress',f'I{n}:K{n}',[26,'历史图16张＋新增侧视绿幕10张；待评价','R0000补齐5待机＋5攻击绿幕；已有历史图保留，后续统一4K'])
    block('progress',f'M{n}:O{n}',[5,5,'新增绿幕按普通原生分辨率完成；无新四视图；现阶段只确定美术'])
for n in [6,7,8]:
    pano=int(n!=8); total=15+pano
    block('progress',f'E{n}:K{n}',[5,0,5,pano,total,'静态图已同步，待用户评价' if pano else '花子15张原图已同步，接缝/长图待做',f'{"B0002" if pano else "B0003"}：5场景＋5待机绿幕＋5攻击绿幕'+('＋1连续长图；接缝已本地复核' if pano else '；尚无连续长图')+'；4K在全部美术确认后'])
    block('progress',f'M{n}:O{n}',[5,5,'五段方案本地先写后画；本次补同步飞书，不冒充远端前置；'+HD])
block('progress','J9:K9',['方案及首段提示词已备，0张成图','B0003 Mary的电话：5场景和5怪物方案已细化，接下来生成；不计入已出图'])
block('progress','O9',['本地详细方案已备，本次同步飞书；普通分辨率先行'])
row('rules',13,['2026-10-04最新执行规则（优先）','用户恢复全量连续制作：先普通原生分辨率完成美术，全部确认后统一4K；仅内置image_gen，不用ChatCut；先写本地详细方案再画。本次明确要求上传当前成果到飞书和git，是本次快照授权，不恢复未来默认上传；不改游戏。','替代旧条目中的强制4K/飞书前置；已出图仍待用户评价'],final)
row('rules',14,['本次快照数量与断点','67张选用图＝R0000绿幕20＋B0002原图30和长图2＋花子原图15；另附乡村参考1张，共68张实际嵌入。Mary只有方案、0张图。花子接缝和长图仍待完成。','以图片逐张嵌入并回读验证为准'],final)

assert len(images)==68 and rows=={'monsters':37,'scenes':28,'panoramas':6,'plans':42},(len(images),rows)
save('text-writes.json',writes);save('final-writes.json',final);save('image-notes.json',notes)
save('selected-images.json',{'selected_count':67,'reference_count':1,'images':images,'counts':counts,'future_images_not_included':'K009 Mary 0; K008 panorama pending'})
names={'monsters':'怪物图鉴_连续制作','scenes':'场景分段_连续制作','panoramas':'连续长图_连续制作','plans':'场景生成方案'}
styles=[]
for table,start in [('monsters',12),('scenes',12),('panoramas',4),('plans',22)]:
    end=rows[table]-1;last={'monsters':'M','scenes':'L','panoramas':'K','plans':'O'}[table]
    styles.append({'name':names[table],'cell_styles':[{'range':f'A{start}:{last}{end}','font_family':'Arial','font_size':11,'vertical_alignment':'top','horizontal_alignment':'left','word_wrap':'auto-wrap'}],'row_sizes':[{'range':f'{start}:{end}','size':320 if table!='plans' else 180}]})
styles.append({'name':'制作规范_侧视绿幕与高清','row_sizes':[{'range':'13:14','size':150}],'cell_styles':[{'range':'A13:C14','word_wrap':'auto-wrap','vertical_alignment':'top'}]})
save('styles.json',{'styles':styles})
print(json.dumps({'images':len(images),'image_bytes':sum(a['bytes'] for a in images),'text_rows':len(writes),'progress_writes':len(final),'rows':rows},ensure_ascii=False))
