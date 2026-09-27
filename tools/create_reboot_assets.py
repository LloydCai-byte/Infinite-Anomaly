"""Deterministic production SVG UI artwork and original procedural sound cues.

Illustrated backgrounds/characters are made with image_gen, never this script.
All buttons use these reusable, individually authored texture states and icons.
"""
from pathlib import Path
import json, math, wave, array

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/reboot/ui'
OUT.mkdir(parents=True, exist_ok=True)

def svg(name, w, h, body):
    (OUT / (name+'.svg')).write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">{body}</svg>', encoding='utf-8')

# Cut paper / screenprinted instrument plaques. These are texture resources,
# including disabled/keyboard focus, not engine default rectangle styleboxes.
for kind, accent in [('neutral','#8b9b99'),('primary','#80c6b6'),('danger','#cf8b77'),('gold','#d8b572')]:
    for state in ['normal','hover','pressed','disabled','focus']:
        fill = {'normal':'#252d30','hover':'#344447','pressed':'#182326','disabled':'#252a2d','focus':'#344447'}[state]
        edge = '#4b5558' if state=='disabled' else accent
        path='M 12 2 H 308 L 318 12 V 54 L 310 62 H 10 L 2 54 V 12 Z'
        body=f'<path d="{path}" fill="#121a1d"/><path d="M12 2H308L318 12V50L310 58H10L2 50V12Z" fill="{fill}" stroke="{edge}" stroke-width="2"/>'
        body+=f'<path d="M17 7H301 M7 15V44 M14 54H298" fill="none" stroke="#c4c8bf" stroke-opacity=".18"/>'
        body+=f'<path d="M9 19V42" stroke="{edge}" stroke-width="3"/><path d="M298 42l8-8m-8 14l8-8" stroke="{edge}" stroke-opacity=".5"/>'
        if state in ['hover','focus']:
            body+=f'<path d="M22 2H105 M217 58H295" stroke="{edge}" stroke-width="3"/>'
        if state=='pressed': body+='<path d="M16 11H304" stroke="#080d0f" stroke-width="3"/>'
        svg(f'button_{kind}_{state}',320,64,body)

for name,fill,stroke in [('panel','#20292c','#657575'),('panel_light','#d8d4c5','#6b7370'),('card','#303a3c','#677875'),('card_selected','#304c4b','#90cebd'),('card_gold','#38392f','#d8b572'),('card_diamond','#293e46','#a0d2df')]:
    body=f'<path d="M14 1H498L511 14V304L496 319H14L1 306V14Z" fill="#10191c"/><path d="M14 1H498L511 14V300L496 315H14L1 302V14Z" fill="{fill}" stroke="{stroke}" stroke-width="2"/>'
    body+=f'<path d="M20 7H492 M7 22V294 M20 308H490" stroke="{stroke}" stroke-opacity=".38" fill="none"/>'
    body+=f'<path d="M14 28V15H28 M484 301H498V287" fill="none" stroke="{stroke}" stroke-width="2"/>'
    svg(name,512,320,body)

svg('topbar',1600,96,'<path d="M0 0H1600V78H1142L1128 88H455L441 78H0Z" fill="#1c272b"/><path d="M0 78H441L455 88H1128L1142 78H1600" stroke="#72817c" fill="none"/><path d="M0 3H1600" stroke="#526963"/><path d="M31 18H37V56H31Z" fill="#94cbb7"/>')
svg('bottom_bar',1600,132,'<path d="M0 17H48L64 1H1536L1552 17H1600V132H0Z" fill="#192529"/><path d="M0 17H48L64 1H1536L1552 17H1600" stroke="#667c77" stroke-width="2" fill="none"/><path d="M80 8H1520" stroke="#354844"/>')
svg('separator',512,8,'<path d="M0 4H480" stroke="#74847e" stroke-opacity=".5"/><path d="M486 4h14" stroke="#98c7b7" stroke-width="2"/>')
svg('health_bg',256,16,'<path d="M5 1H251L255 5V11L251 15H5L1 11V5Z" fill="#162327" stroke="#73817a"/>')
svg('health_fill',256,16,'<path d="M4 3H252V13H4Z" fill="#8cbfa8"/><path d="M4 3H252V5H4Z" fill="#c1dec9"/>')
svg('progress_fill',256,16,'<path d="M4 3H252V13H4Z" fill="#d7b775"/><path d="M4 3H252V5H4Z" fill="#e8d8aa"/>')
svg('shadow',128,32,'<ellipse cx="64" cy="16" rx="61" ry="12" fill="#0c181c" fill-opacity=".26"/>')
svg('vignette',1600,900,'<defs><linearGradient id="g" x1="0" x2="1"><stop stop-color="#152025" stop-opacity=".96"/><stop offset=".5" stop-color="#152025" stop-opacity=".8"/><stop offset="1" stop-color="#152025" stop-opacity="0"/></linearGradient></defs><path d="M0 0H1600V900H0Z" fill="url(#g)"/>')
svg('dim',16,16,'<path d="M0 0H16V16H0Z" fill="#0c161b" fill-opacity=".78"/>')

icons = {
 'play':'M23 15L51 32 23 49Z',
 'back':'M39 15L22 32 39 49M23 32H53',
 'close':'M19 19L45 45M45 19L19 45',
 'pause':'M23 17V47M41 17V47',
 'speed':'M12 18L29 32 12 46ZM34 18L51 32 34 46Z',
 'home':'M10 29L32 10 54 29M17 27V53H47V27M27 53V37H37V53',
 'door':'M15 54V10H49V54M22 49V16H43V49M36 31H39M10 54H54',
 'team':'M23 16a7 7 0 1 0 .1 0M41 20a6 6 0 1 0 .1 0M9 49V44Q10 34 23 34Q35 34 36 44V49ZM38 35Q52 35 54 44V49H41',
 'printer':'M19 21V9H45V21M15 47H10V23H54V47H48M19 37H45V55H19ZM17 29H20M28 44H39M28 49H39',
 'training':'M10 20V44M17 14V50M47 14V50M54 20V44M17 32H47',
 'facility':'M14 10H49V54H14ZM30 17L23 33H34L29 47 42 27H31ZM19 17H21M43 47H45',
 'cards':'M13 17L39 10 50 46 24 54ZM25 14L48 17 44 53 22 50M23 26L34 22 38 37 27 42Z',
 'settings':'M26 10H38L40 19 48 21 54 30 48 39 40 42 38 53H26L23 44 15 41 10 32 16 23 24 20ZM32 23a9 9 0 1 0 .1 0',
 'save':'M14 10H44L53 19V54H11V10ZM21 10V26H43V10M21 54V37H44V54M35 15V22',
 'volume':'M12 25H22L35 14V50L22 39H12ZM43 23Q54 32 43 41M48 16Q64 32 48 48',
 'shield':'M32 9L51 16V31Q49 45 32 55Q15 45 13 31V16ZM32 19V43M22 28H42',
 'rifle':'M8 25H49V32H54V37H36L30 48H23L28 36H18L10 40ZM39 18V25M16 19H31V25',
 'cannon':'M9 24H49V37H9ZM49 27H58V34H49M17 37L22 51H31L28 37M20 18H40V24',
 'medical':'M13 19H51V52H13ZM24 19V11H40V19M27 27H37V33H43V41H37V47H27V41H21V33H27Z',
 'upgrade':'M16 34L32 18 48 34M32 19V54M14 10H50',
 'coin':'M32 8a24 24 0 1 0 .1 0M32 16a16 16 0 1 0 .1 0M37 22H28L24 27V38L29 42H37M22 31H38',
 'alloy':'M17 15H47L56 43 45 52H19L8 43ZM17 15L24 39H54M24 39L19 52M31 21H41',
 'skill':'M35 7L16 34H29L24 57 49 26H35Z',
 'chat':'M10 13H54V43H31L18 54V43H10ZM19 23H45M19 32H38',
 'stats':'M14 52V33H23V52M28 52V20H37V52M42 52V9H51V52M8 54H57',
 'lock':'M17 29H47V54H17ZM23 29V19Q23 7 32 7Q41 7 41 19V29M32 37V46',
 'check':'M12 32L26 46 53 16',
 'recycle':'M30 11L39 10 50 27M43 19L50 27 55 18M54 36L50 49H28M37 43L28 49 35 55M19 49L10 36 21 18M12 20L21 18 24 26',
 'map':'M9 15L25 9 40 16 55 10V48L40 55 25 48 9 54ZM25 9V48M40 16V55',
 'file':'M17 8H39L50 19V56H14V8ZM38 9V21H49M23 31H41M23 40H41M23 48H35',
 'eye':'M7 32Q31 4 57 32Q32 57 7 32ZM32 22a10 10 0 1 0 .1 0',
 'exit':'M28 10H13V54H28M27 32H57M45 20L57 32 45 44',
}
for name,path in icons.items():
    svg('icon_'+name,64,64,f'<path d="{path}" fill="none" stroke="#d4e2d8" stroke-width="2.6" stroke-linejoin="round" stroke-linecap="round"/>')

svg('crosshair',64,64,'<circle cx="32" cy="32" r="22" fill="none" stroke="#d9e3d5" stroke-width="2"/><path d="M32 1V19M32 45V63M1 32H19M45 32H63" stroke="#8bd7bd" stroke-width="2"/>')
svg('emblem',192,192,'<path d="M32 20H160V158L96 180 32 158Z" fill="#223232" stroke="#91b8a6" stroke-width="3"/><path d="M60 137V51H132V137M73 125V66H118V125M108 93H113" fill="none" stroke="#e3e4d2" stroke-width="5"/><path d="M46 148H145M83 28H110" stroke="#91b8a6" stroke-width="2"/>')

audio = ROOT/'assets/reboot/audio'; audio.mkdir(parents=True,exist_ok=True)
rate=22050
def tone(name,duration,freqs,noise=0):
    # Authored, deterministic additive synthesis; no third-party recordings.
    samples=array.array('h')
    for i in range(int(duration*rate)):
        t=i/rate
        env=min(1,t/.015)*max(0,1-t/duration)**2
        v=sum(math.sin(2*math.pi*f*t)*amp for f,amp in freqs)*env
        if noise: v+=math.sin(i*113.71)*math.sin(i*7.17)*noise*env
        samples.append(int(max(-.95,min(.95,v))*32767))
    with wave.open(str(audio/(name+'.wav')),'wb') as w:
        w.setnchannels(1);w.setsampwidth(2);w.setframerate(rate);w.writeframes(samples.tobytes())
tone('click',.07,[(720,.05),(1080,.02)])
tone('upgrade',.6,[(392,.08),(587.33,.055),(783.99,.045)])
tone('shot',.13,[(105,.09),(230,.05)],.12)
tone('heavy',.32,[(64,.16),(125,.08)],.1)
tone('blade',.19,[(380,.035),(710,.025)],.085)
tone('heal',.4,[(659,.055),(987.77,.035)])
tone('victory',1.5,[(261.63,.07),(329.63,.06),(392,.06),(523.25,.05)])
tone('defeat',1.2,[(110,.08),(130.81,.055),(155.56,.05)])
for name,notes in [('base',[130.81,164.81,196,293.66]),('battle',[110,130.81,164.81,220])]:
    samples=array.array('h'); duration=24
    for i in range(duration*rate):
        t=i/rate
        pad=sum(math.sin(2*math.pi*f*t)*.007 for f in notes)
        pulse=math.exp(-((t%3)*3))*math.sin(2*math.pi*notes[int(t/3)%4]*2*t)*.018
        breath=.8+.2*math.sin(2*math.pi*t/12)
        fade=min(1,t/2,(duration-t)/2)
        samples.append(int((pad+pulse)*breath*fade*32767))
    with wave.open(str(audio/(name+'.wav')),'wb') as w:
        w.setnchannels(1);w.setsampwidth(2);w.setframerate(rate);w.writeframes(samples.tobytes())
print(json.dumps({'ui_svg':len(list(OUT.glob('*.svg'))),'audio':len(list(audio.glob('*.wav')))}))
