import hashlib,json,pathlib,re,shutil
from sync_checkpoint import ROOT,OUT,save

DEST=ROOT/'.local/art-upload-worktree-20261004'
assert (DEST/'.git').is_file()
paths=[]
art=ROOT/'art/anomaly-concepts/continuous-20261004'
for p in sorted(art.rglob('*')):
    if p.is_file() and p.suffix in {'.png','.json','.txt','.html','.md'}:paths.append(p)
paths.append(ROOT/'art/anomaly-concepts/hasshaku-redraw-20261004-v02/generated/04-chatcut-nano-4k.png')
doc=ROOT/'docs/anomaly-marathon-20261003'
for name in ['ART_PHASE_20261004.md','NEXT.md','连续任务规范.md','r0000-builtin-verification-20261004.json','b0002-builtin-verification-20261004.json','record_builtin_batch.py','record_builtin_green.py','record_join_repaint.py','assemble_join_native_contours.py','assemble_builtin_panorama.py','verify_builtin_batch.py','prepare_b0002.py','prepare_b0003.py']:
    paths.append(doc/name)
for name in ['selected-images.json','verification-final.json','README.md','sync_checkpoint.py','prepare_snapshot.py','verify_snapshot.py','record_sync.py','package_git.py','queue-summary.json']:
    paths.append(OUT/name)
records=[]
for src in paths:
    assert src.is_file(),src
    rel=src.relative_to(ROOT);dst=DEST/rel
    dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src,dst)
    sha=hashlib.sha256(src.read_bytes()).hexdigest()
    assert hashlib.sha256(dst.read_bytes()).hexdigest()==sha
    assert src.stat().st_size<100*1024*1024
    records.append({'file':rel.as_posix(),'bytes':src.stat().st_size,'sha256':sha})
html=(DEST/'art/anomaly-concepts/continuous-20261004/index.html').read_text(encoding='utf-8')
links=set(re.findall(r'(?:src|href)="([^"]+)"',html))
local=[p for p in links if not re.match(r'\w+:|#',p)]
assert all((DEST/'art/anomaly-concepts/continuous-20261004'/p).is_file() for p in local)
report={'branch':'codex/art-checkpoint-20261004','base':'64e7b9783386c4a5115ee8e418468440a0897458','file_count':len(records),'bytes':sum(r['bytes'] for r in records),'gallery_link_count':len(local),'gallery_links_all_exist':True,'files':records,'scope':'Current art snapshot only. Full Feishu before/after raw responses and unrelated game edits remain local.'}
save('git-package-manifest.json',report)
shutil.copy2(OUT/'git-package-manifest.json',DEST/'docs/anomaly-marathon-20261003/sync-current-20261004/git-package-manifest.json')
print(json.dumps({k:v for k,v in report.items() if k!='files'},ensure_ascii=False))
