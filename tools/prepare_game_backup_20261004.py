"""Freeze the current playable game, excluding new standalone art production."""
import hashlib,json,pathlib,re,shutil,subprocess,zipfile
ROOT=pathlib.Path(__file__).resolve().parents[1]
DEST=ROOT/'.local/game-backup-worktree-20261004'
OUT=ROOT/'backups/2026-10-04-earth-0.11.0'
DOC=ROOT/'docs/game-backup-20261004'
RELEASE=ROOT/'builds/InfiniteAnomaly-Earth-0.11.0'
OUT.mkdir(parents=True,exist_ok=True);DOC.mkdir(parents=True,exist_ok=True)

def sha(p):
    with p.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
def save(p,o):p.write_text(json.dumps(o,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

def prepare():
    assert (DEST/'.git').is_file()
    files=[]
    for name in ['assets','scripts','scenes','data','tests','tools']:
        for p in (ROOT/name).rglob('*'):
            if p.is_file() and not {'__pycache__','node_modules','.venv'}.intersection(p.parts) and p.suffix not in {'.pyc','.tmp','.log'}:files.append(p)
    files += [ROOT/'project.godot']+list(ROOT.glob('*.cmd'))
    for directory in ['docs/earth-production','docs/kaidan-integration-011','docs/asset-replacement','docs/revision-20261002','docs/game-backup-20261004']:
        files += [p for p in (ROOT/directory).glob('*') if p.is_file() and p.suffix in {'.md','.txt','.html','.json'} and 'feishu' not in p.name.lower()]
    copied=[]
    for p in sorted(set(files)):
        rel=p.relative_to(ROOT);target=DEST/rel
        target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,target)
        assert p.stat().st_size<100*1024*1024,rel
        h=sha(p);assert sha(target)==h
        copied.append({'file':rel.as_posix(),'bytes':p.stat().st_size,'sha256':h})
    assert not (DEST/'art/anomaly-concepts/continuous-20261004').exists()
    checks=json.loads((RELEASE/'checksums.json').read_text(encoding='utf-8-sig'))
    for c in checks:assert sha(RELEASE/c['File'].replace('\\','/'))==c['Hash'].lower(),c['File']
    expected=json.loads((ROOT/'docs/kaidan-integration-011/verification-summary.json').read_text(encoding='utf-8'))['pck_sha256']
    assert sha(RELEASE/'InfiniteAnomaly.pck')==expected
    packfiles=json.loads((RELEASE/'files.json').read_text(encoding='utf-8'))
    source=[p[6:] for p in packfiles if p.startswith('res://') and not p.startswith('res://.godot/')]
    assert all((DEST/p).is_file() for p in source),[p for p in source if not (DEST/p).is_file()]
    for p in [ROOT/n for n in ['启动游戏.cmd','启动地球篇.cmd','启动第一关测试.cmd','启动怪谈测试.cmd']]:
        b=(DEST/p.name).read_bytes();assert not b.startswith(b'\xef\xbb\xbf') and b'\n' not in b.replace(b'\r\n',b''),p.name
    report={'version':'0.11.0-earth-kaidan','current_files_copied':len(copied),'copied_bytes':sum(x['bytes'] for x in copied),'runtime_pck_entries':len(packfiles),'runtime_source_files_present':len(source),'release_checksums_verified':len(checks),'pck_sha256':expected,'new_unintegrated_art_included':False,'files':copied}
    save(OUT/'source-snapshot.json',report)
    summary={k:v for k,v in report.items() if k!='files'};save(DOC/'snapshot-verification.json',summary)
    shutil.copy2(DOC/'snapshot-verification.json',DEST/'docs/game-backup-20261004/snapshot-verification.json')
    print(json.dumps(summary,ensure_ascii=False),flush=True)

def pack(name,files):
    target=OUT/name
    manifest={n:{'bytes':p.stat().st_size,'sha256':sha(p)} for p,n in files}
    with zipfile.ZipFile(target,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
        for p,n in files:z.write(p,n)
        z.writestr('BACKUP-SHA256.json',json.dumps(manifest,ensure_ascii=False,indent=2))
    with zipfile.ZipFile(target) as z:
        for n,v in manifest.items():
            with z.open(n) as f:assert hashlib.file_digest(f,'sha256').hexdigest()==v['sha256'],n
    receipt={'name':name,'files':len(files),'bytes':target.stat().st_size,'sha256':sha(target),'archive_contents_verified':True}
    save(OUT/(name+'.receipt.json'),receipt);print(json.dumps(receipt),flush=True)
    return receipt

if __name__=='__main__':
    import sys
    action=sys.argv[1]
    if action=='prepare':prepare()
    elif action=='windows':
        pack('InfiniteAnomaly-Earth-0.11.0-Windows.zip',[(p,p.relative_to(RELEASE).as_posix()) for p in sorted(RELEASE.rglob('*')) if p.is_file()])
    elif action=='source':
        names=subprocess.check_output(['git','-c','safe.directory='+DEST.as_posix(),'-C',str(DEST),'ls-files','-z']).decode('utf-8').strip('\0').split('\0')
        pack('InfiniteAnomaly-Earth-0.11.0-Source.zip',[(DEST/n,n) for n in names])
