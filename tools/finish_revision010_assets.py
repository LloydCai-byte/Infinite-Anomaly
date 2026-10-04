from pathlib import Path
import json,hashlib,html
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'art/earth-production/revision-010'
GEAR=ROOT/'assets/earth/replacements/equipment'
GEAR.mkdir(parents=True,exist_ok=True)
# Original vector inventory illustrations share the flat ink palette of the native UI.
icons={
'prism-helmet':'<path d="M27 82V49Q27 21 61 18Q95 21 95 49V82L75 91V67H47V91Z" fill="#677563"/><path d="M29 45L47 32H78L93 45V57H29Z" fill="#202b28"/><path d="M56 33L62 25L69 33L63 49Z" fill="#b1e34c"/><path d="M50 68H74V97H50Z" fill="#344334"/>',
'pulse-gauntlet':'<path d="M31 104L27 73L21 61L23 50L34 46L40 57V26L52 20L59 27V51L64 23L77 27V53L84 36L95 42V78L82 106Z" fill="#775d48"/><path d="M37 72L56 54L82 61L89 79L75 94L49 89Z" fill="#b87541"/><path d="M61 61L52 80H63L59 92L78 72H66L70 61Z" fill="#ffe499"/>',
'tide-pendant':'<path d="M29 18Q61 77 96 18L104 23Q64 89 20 23Z" fill="#668088"/><path d="M62 57L85 85L62 113L40 85Z" fill="#314b65"/><path d="M63 70Q83 91 63 101Q43 91 63 70Z" fill="#8ddfe6"/>',
'night-mask':'<path d="M21 32Q61 18 104 32L97 74L64 103L29 75Z" fill="#69706a"/><path d="M27 45L51 42L53 56L31 59Z M72 42L98 45L93 59L71 56Z" fill="#171f20"/><path d="M63 57L50 77H75Z" fill="#3b4e4a"/><path d="M51 90H77" fill="none"/>',
'fiber-glove':'<path d="M39 107L26 75L17 59L23 46L35 48L45 67L40 28L49 20L58 27L63 59L63 19L76 19L78 58L82 28L93 31L93 72L85 107Z" fill="#84968f"/><path d="M41 92H88L86 109H41Z" fill="#323f3b"/><path d="M48 72L66 66L83 74L71 89L52 86Z" fill="#c0c9af"/>',
'echo-charm':'<path d="M32 14Q65 58 92 14L99 20Q65 72 24 20Z" fill="#776a4c"/><circle cx="64" cy="80" r="29" fill="#ab9467"/><circle cx="64" cy="80" r="21" fill="#272e2e"/><path d="M64 62V80L80 85" stroke="#f1d8a0" fill="none"/><circle cx="64" cy="80" r="4" fill="#f1d8a0"/>'
}
for name,body in icons.items():
    (GEAR/(name+'.svg')).write_text('<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128"><g stroke="#0a1111" stroke-width="3" stroke-linejoin="round">'+body+'</g></svg>',encoding='utf-8')

rpath=ROOT/'assets/earth/asset_registry.json'
data=json.loads(rpath.read_text(encoding='utf-8-sig'))
for i,(name,label) in enumerate(zip(icons,['棱镜头盔','脉冲护手','潮汐吊坠','守夜面罩','纤维手套','回声护符'])):
    id='equipment.'+str(i)
    item={'id':id,'name':label+' · 背包图标','category':'属性装备','current_path':f'assets/earth/replacements/equipment/{name}.svg','target_path':f'assets/earth/replacements/equipment/{name}.svg','candidate_path':f'assets/earth/replacements/equipment/{name}.svg','spec':'128×128 原生 SVG','used_by':'装备背包/结算','notes':'0.10 原创矢量图标，可独立换图；属性装备不要求改变人物外观。','production_status':'已有候选','integration_status':'已接入待验收','review_status':'待用户验收','replacement_version':'0.10.0'}
    if not any(e['id']==id for e in data['entries']):data['entries'].append(item)
for e in data['entries']:
    if e['id'] in ['room.living','room.workroom','room.balcony']:
        e.update(candidate_path=e['target_path'],replacement_version='0.10.0',notes={'room.living':'修正走廊入口：移除门内书柜，保留外门、内门与家具布局。','room.workroom':'移除收集阵，换普通山景画框/花瓶/台灯；全高打印舱保留。','room.balcony':'统一为与客厅相邻的傍晚光照，家具和窗框保留。'}[e['id']])
    if e['id'].startswith('ui.'):e['production_status']='已有候选'
data['version']='0.10.0'
rpath.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
manifest={'source_doc':'PxnjdkXZvo7sG5xWm7Jccnnqn5b','revision':228,'mode':'built-in image_gen','room_export':'1672×941 originals; high-quality bicubic delivery resize to 1920×1080','rooms':[],'ui':'25 original native SVG textures + 6 native inventory icons','review':'pending user review'}
for name in ['living','workroom','balcony']:
    p=ROOT/f'assets/earth/home/{name}.png'
    manifest['rooms'].append({'name':name,'runtime':p.relative_to(ROOT).as_posix(),'prompt':f'prompts/{name}.txt','sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
(OUT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
print('6 inventory icons; room provenance and registry updated.')
