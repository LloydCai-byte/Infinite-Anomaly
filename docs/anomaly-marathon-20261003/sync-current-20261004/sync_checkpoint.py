import argparse, hashlib, json, pathlib, subprocess, time

ROOT = pathlib.Path('D:/无限异常')
OUT = ROOT / 'docs/anomaly-marathon-20261003/sync-current-20261004'
CLI = 'C:/Users/q/AppData/Roaming/npm/node_modules/@larksuite/cli/bin/lark-cli.exe'
TOKEN = 'RAqiszeH4hgCNStMvagcP4btnmh'
SHEETS = {'monsters':'ZYrOxl','scenes':'JIgZjv','panoramas':'yyLGNe','progress':'BF7Isc','plans':'kfzJo7','rules':'nHPyya'}

def save(name, obj):
    (OUT/name).write_text(json.dumps(obj,ensure_ascii=False,indent=2),encoding='utf-8')

def call(args, receipt):
    p=subprocess.run([CLI,'sheets',*args,'--as','user','--format','json'],cwd=ROOT,capture_output=True,encoding='utf-8',timeout=180)
    try: obj=json.loads(p.stdout)
    except Exception: raise RuntimeError(f'CLI non-JSON {p.returncode}: {p.stderr[:1000]} {p.stdout[:500]}')
    save(receipt,obj)
    if p.returncode or not obj.get('ok'): raise RuntimeError(f'CLI failed: {receipt} {str(obj)[:1200]}')
    return obj

def read(phase):
    for name,sid in SHEETS.items():
        path=f'docs/anomaly-marathon-20261003/sync-current-20261004/{name}-{phase}.json'
        call(['+cells-get','--spreadsheet-token',TOKEN,'--sheet-id',sid,'--range','A1:T394' if name=='progress' else 'A1:T200','--include','value,formula,style,comment','--output-path','./'+path],f'{name}-{phase}-receipt.json')
        obj=json.loads((ROOT/path).read_text(encoding='utf-8'))
        if obj.get('has_more') or any(r.get('truncated') for r in obj.get('ranges',[])): raise RuntimeError('truncated '+name)
        print(f'read {name} {phase}',flush=True)

def cells(obj):
    return {f'{c}{r}':v for rg in obj['ranges'] for r,row in zip(rg['row_indices'],rg['cells']) for c,v in zip(rg['col_indices'],row)}

def filearg(name):
    return '@./docs/anomaly-marathon-20261003/sync-current-20261004/'+name

def text_upload():
    call(['+cells-set','--spreadsheet-token',TOKEN,'--writes',filearg('text-writes.json')],'text-write-receipt.json')
    call(['+styles-put','--spreadsheet-token',TOKEN,'--styles',filearg('styles.json')],'styles-write-receipt.json')
    print('text and styles written',flush=True)

def upload():
    items=json.loads((OUT/'selected-images.json').read_text(encoding='utf-8'))['images']
    for i,a in enumerate(items,1):
        name='upload-'+a['id']+'.json'
        if (OUT/name).exists() and json.loads((OUT/name).read_text(encoding='utf-8')).get('ok'):
            print(f'{i}/{len(items)} receipt exists {a["id"]}',flush=True);continue
        assert hashlib.sha256((ROOT/a['file']).read_bytes()).hexdigest()==a['sha256']
        call(['+cells-set-image','--spreadsheet-token',TOKEN,'--sheet-id',a['sheet_id'],'--range',a['range'],'--image','./'+a['file']],name)
        print(f'{i}/{len(items)} embedded {a["id"]}',flush=True)
    call(['+cells-set','--spreadsheet-token',TOKEN,'--writes',filearg('image-notes.json')],'image-notes-receipt.json')
    print('68 images and notes submitted',flush=True)

if __name__=='__main__':
    ap=argparse.ArgumentParser();ap.add_argument('action');a=ap.parse_args()
    if a.action in ['before','after']: read(a.action)
    elif a.action=='text': text_upload()
    elif a.action=='upload': upload()
    elif a.action=='final':
        call(['+cells-set','--spreadsheet-token',TOKEN,'--writes',filearg('final-writes.json')],'final-write-receipt.json')
        print('checkpoint status submitted',flush=True)
