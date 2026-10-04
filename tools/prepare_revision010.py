"""Create native cel-style UI textures and update registry. No raster redrawing."""
from pathlib import Path
import json

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/earth/replacements/ui'
OUT.mkdir(parents=True,exist_ok=True)

def svg(name,body,w=320,h=100):
    (OUT/(name+'.svg')).write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">{body}</svg>',encoding='utf-8')

for kind,accent in [('neutral','#a8ada3'),('primary','#88d844'),('gold','#ffa93b'),('danger','#ff4935')]:
    for state in ['normal','hover','pressed','focus','disabled']:
        c='#545953' if state=='disabled' else accent
        bg='#111515' if state=='disabled' else ('#27352a' if state=='hover' else '#070a09' if state=='pressed' else '#151a18')
        width=4 if state in ['hover','focus'] else 2
        body=f'<path d="M2 2H308L318 12V98H12L2 88Z" fill="{bg}" stroke="{c}" stroke-width="{width}"/>'
        body+=f'<path d="M8 8H13V83H8Z M282 88H294L304 78H292Z" fill="{c}"/>'
        body+=f'<path d="M22 9H276 M32 91H275" fill="none" stroke="{c}" stroke-width="1" opacity=".6"/>'
        if state=='pressed':body+=f'<path d="M23 79H276V84H23Z" fill="{c}"/>'
        svg('button_'+kind+'_'+state,body)

for name in ['panel','card','topbar','bottom_bar']:
    body='<path d="M1 1H310L319 10V99H10L1 90Z" fill="#0b100f" fill-opacity=".97" stroke="#a0ab9e" stroke-width="2"/>'
    body+='<path d="M8 7H80V11H8Z M242 89H310V93H242Z" fill="#ffa93b"/>'
    body+='<path d="M8 17V83 M312 18V82" stroke="#465047" fill="none"/>'
    svg(name,body)
svg('dim','<rect width="32" height="32" fill="#030706" opacity=".80"/>',32,32)

regpath=ROOT/'assets/earth/asset_registry.json'
reg=json.loads(regpath.read_text(encoding='utf-8-sig'))
reg['version']='0.10.0'
for e in reg['entries']:
    if e['id'].startswith('ui.'):
        e.update(production_status='已制作',integration_status='已接入待验收',review_status='待用户验收',replacement_version='0.10.0',notes='按用户《修改 10.1》参考重做原生硬边赛璐璐界面，黑底、警示橙、状态绿，五状态按钮。')
regpath.write_text(json.dumps(reg,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('UI: 25 native SVG textures generated; registry updated.')
