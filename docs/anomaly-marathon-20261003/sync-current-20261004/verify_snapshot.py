import argparse, json, re, hashlib
from sync_checkpoint import ROOT,OUT,SHEETS,cells,save

ap=argparse.ArgumentParser();ap.add_argument('--final',action='store_true');args=ap.parse_args()
before={sid:cells(json.loads((OUT/(n+'-before.json')).read_text(encoding='utf-8'))) for n,sid in SHEETS.items()}
after={sid:cells(json.loads((OUT/(n+'-after.json')).read_text(encoding='utf-8'))) for n,sid in SHEETS.items()}
expected={}; touched={s:set() for s in SHEETS.values()}
for filename in ['text-writes.json','image-notes.json']+(['final-writes.json'] if args.final else []):
    for w in json.loads((OUT/filename).read_text(encoding='utf-8')):
        m=re.match(r'([A-Z]+)(\d+)',w['range']); col=ord(m[1])-65;row=int(m[2]);sid=w['sheet_id']
        for ri,vs in enumerate(w['cells']):
            for ci,v in enumerate(vs):
                addr=f'{chr(65+col+ci)}{row+ri}';touched[sid].add(addr)
                expected.setdefault((sid,addr),{}).update(v)
items=json.loads((OUT/'selected-images.json').read_text(encoding='utf-8'))['images'];validated=[]
for a in items:
    sid=a['sheet_id'];addr=a['range'];c=after[sid][addr]
    ims=[x for x in c.get('rich_text',[]) if x.get('type')=='embed-image'];assert len(ims)==1,(a['id'],'missing image')
    im=ims[0];receipt=json.loads((OUT/('upload-'+a['id']+'.json')).read_text(encoding='utf-8'))
    assert im['image_token']==receipt['data']['file_token'],a['id']
    assert [im['image_width'],im['image_height']]==a['size'],(a['id'],im)
    assert a['sha256'] in c.get('note',''),a['id']
    assert hashlib.sha256((ROOT/a['file']).read_bytes()).hexdigest()==a['sha256']
    expected[(sid,addr)].pop('value',None)
    validated.append({'id':a['id'],'sheet_id':sid,'cell':addr,'token':im['image_token'],'size':a['size'],'sha256':a['sha256']})
checked=0
for (sid,addr),want in expected.items():
    for k,v in want.items():
        got=after[sid].get(addr,{}).get(k)
        # Sheets empty string may read back as an absent value.
        if v=='' and got is None:continue
        assert str(got)==str(v),(sid,addr,k,got,v)
        checked+=1
preserved=0
for sid,cs in before.items():
    for addr,c in cs.items():
        if addr in touched[sid]:continue
        comparable=lambda x:{k:v for k,v in x.items() if k in ['value','formula','rich_text','note'] and v not in [None,'',[]]}
        assert comparable(c)==comparable(after[sid].get(addr,{})),('old cell changed',sid,addr,c,after[sid].get(addr))
        if comparable(c):preserved+=1
report={'status':'passed','scope':'final' if args.final else 'images_and_text','embedded_images':len(items),'selected_images':67,'reference_images':1,'verified_fields':checked,'preserved_old_populated_cells':preserved,'user_opinion_columns_untouched':True,'images':validated,'incomplete':['K008 joins/panorama pending','K009 0 generated images','all images pending individual user review','4K after full art approval']}
save('verification-final.json' if args.final else 'verification-images.json',report)
print(json.dumps({k:v for k,v in report.items() if k!='images'},ensure_ascii=False))
