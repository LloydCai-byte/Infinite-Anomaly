#!/usr/bin/env python3
"""Git source history plus content-addressed assets on Feishu. Standard library only."""
from __future__ import annotations
import argparse, contextlib, datetime as dt, hashlib, json, os, pathlib, re, shutil, subprocess, sys, tempfile, time, zipfile
P = pathlib.Path
CHUNK = 8 * 1024 * 1024
PACK = 16 * 1024 * 1024
TEXT_LIMIT = 2 * 1024 * 1024
SCHEMA = 'feishu-game-repository/v1'
if hasattr(sys.stdout, 'reconfigure'): sys.stdout.reconfigure(encoding='utf-8')

def digest(b): return hashlib.sha256(b).hexdigest()
def encoded(o): return json.dumps(o, ensure_ascii=False, sort_keys=True, separators=(',', ':')).encode('utf-8')
def read_json(p): return json.loads(P(p).read_text(encoding='utf-8'))
def write_json(p, o):
    p=P(p); p.parent.mkdir(parents=True, exist_ok=True)
    temp=p.with_suffix(p.suffix+'.tmp'); temp.write_bytes(encoded(o)); os.replace(temp,p)
def say(**o): print(json.dumps(o,ensure_ascii=False),flush=True)
def utc(): return dt.datetime.now(dt.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
def safe_path(root, name):
    pp=pathlib.PurePosixPath(name)
    if not name or '\\' in name or ':' in name or pp.is_absolute() or '..' in pp.parts or '.git' in pp.parts:
        raise ValueError('Unsafe archive path: '+name)
    path=P(root).joinpath(*pp.parts)
    if not path.resolve().is_relative_to(P(root).resolve()): raise ValueError('Escaping archive path')
    return path

def git(root, *args, data=None, check=True):
    env=os.environ.copy(); env.update(GIT_CONFIG_NOSYSTEM='1',GIT_CONFIG_GLOBAL=os.devnull,GIT_TERMINAL_PROMPT='0')
    p=subprocess.run(['git','-c','core.hooksPath='+os.devnull,'-c','core.autocrlf=false','-C',str(root),*args],input=data,stdout=subprocess.PIPE,stderr=subprocess.PIPE,env=env)
    if check and p.returncode: raise RuntimeError('git '+args[0]+': '+p.stderr.decode('utf-8',errors='replace'))
    return p.stdout

def init_git(root):
    P(root).mkdir(parents=True,exist_ok=True); git(root,'init','-b','archive')
    (P(root)/'.git/info/attributes').write_text('* -text\n',encoding='utf-8')
    git(root,'config','user.name','Feishu Game Archive');git(root,'config','user.email','archive@local.invalid')

BLOCK_DIR={'.git','.godot','.codex','.tools','node_modules','__pycache__','.venv','venv','qa','qa-appdata','build','dist','exports'}
BLOCK_NAME={'.feishu-assets.json','export_credentials.cfg','.export_credentials','.git-credentials'}
def excluded(name):
    p=pathlib.PurePosixPath(name); low=p.name.lower()
    return bool(set(p.parts)&BLOCK_DIR or low in BLOCK_NAME or low.endswith(('.log','.tmp','.bak','.pem','.pfx','.p12','.key')) or
                (low.startswith('.env') and low not in {'.env.example','.env.template'}) or
                re.match(r'(credentials|secrets).*\.json$',low))

def refresh_conversations(root):
    root=P(root).resolve()
    if not (root/'docs/conversations/threads.json').is_file():return
    exporter=root/'tools/conversation_backup.py'
    if not exporter.is_file():raise RuntimeError('Conversation backup exporter missing')
    env=os.environ.copy();env['PYTHONIOENCODING']='utf-8'
    result=subprocess.run([sys.executable,str(exporter),'--root',str(root),'--allow-archived'],capture_output=True,text=True,encoding='utf-8',env=env)
    if result.returncode:raise RuntimeError('Conversation backup failed before upload: '+result.stderr)
    print(result.stdout,end='',flush=True)

def snapshot(root, chunk_dir):
    root=P(root).resolve(); chunk_dir=P(chunk_dir);chunk_dir.mkdir(parents=True,exist_ok=True)
    names=set(git(root,'ls-files','-z','--cached','--others','--exclude-standard').decode('utf-8').split('\0'))
    files={}; skip=[]; source={}
    for name in sorted(names):
        if not name: continue
        if excluded(name): skip.append(name);continue
        p=safe_path(root,name)
        if p.is_symlink(): raise ValueError('Symlink requires explicit packaging policy: '+name)
        if not p.is_file(): continue
        before=p.stat(); size=before.st_size
        # Text is kept in real Git, binary assets in shared SHA-256 chunks.
        text=None
        if size<=TEXT_LIMIT:
            b=p.read_bytes()
            try:
                if b'\0' not in b: b.decode('utf-8');text=b
            except UnicodeDecodeError: pass
        if text is not None:
            if re.search(rb'^-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----\r?$', text, re.M):
                raise ValueError('Private-key marker in '+name)
            files[name]={'sha256':digest(text),'size':size,'storage':'git'};source[name]=text
        else:
            hashes=[]; sha=hashlib.sha256()
            with p.open('rb') as f:
                while b:=f.read(CHUNK):
                    sha.update(b);h=digest(b);hashes.append(h)
                    cp=chunk_dir/h
                    if not cp.exists(): cp.write_bytes(b)
            files[name]={'sha256':sha.hexdigest(),'size':size,'storage':'cas','chunks':hashes}
        after=p.stat()
        if (size,before.st_mtime_ns)!=(after.st_size,after.st_mtime_ns): raise RuntimeError('File changed during snapshot: '+name)
    root_hash=digest(encoded(files))
    return {'files':files,'root_hash':root_hash,'excluded':skip,'bytes':sum(v['size'] for v in files.values())},source

def make_packs(chunks, directory, known):
    directory=P(directory);directory.mkdir(parents=True,exist_ok=True);groups=[];group=[];total=0
    for h in sorted(set(chunks)-set(known)):
        size=(directory.parent/'chunks'/h).stat().st_size
        if group and total+size>PACK: groups.append(group);group=[];total=0
        group.append(h);total+=size
    if group: groups.append(group)
    result=[]
    for group in groups:
        temporary=directory/'pending.zip'
        with zipfile.ZipFile(temporary,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=6) as z:
            for h in group:
                entry=zipfile.ZipInfo(h,(1980,1,1,0,0,0));entry.compress_type=zipfile.ZIP_DEFLATED
                z.writestr(entry,(directory.parent/'chunks'/h).read_bytes())
        sha=digest(temporary.read_bytes());path=directory/('pack-'+sha+'.zip');os.replace(temporary,path)
        result.append((sha,path,group))
    return result

class Lark:
    def __init__(self, cache, executable=None):
        self.cache=P(cache);self.cache.mkdir(parents=True,exist_ok=True)
        default=P(os.environ.get('APPDATA',''))/'npm/node_modules/@larksuite/cli/bin/lark-cli.exe'
        self.exe=executable or os.environ.get('LARK_CLI_EXE') or (str(default) if default.exists() else shutil.which('lark-cli'))
        if not self.exe: raise RuntimeError('Install lark-cli and authenticate as user first.')
    def call(self,*args):
        env=os.environ.copy();env.update(LARKSUITE_CLI_NO_UPDATE_NOTIFIER='1',LARKSUITE_CLI_NO_SKILLS_NOTIFIER='1')
        r=subprocess.run([self.exe,*map(str,args),'--as','user'],cwd=self.cache,stdout=subprocess.PIPE,stderr=subprocess.PIPE,env=env,timeout=600)
        try: out=json.loads(r.stdout.decode('utf-8'))
        except (ValueError,UnicodeDecodeError):
            try: out=json.loads(r.stderr.decode('utf-8'))
            except (ValueError,UnicodeDecodeError): raise RuntimeError('CLI failed (non-JSON), exit '+str(r.returncode))
        if r.returncode or not out.get('ok',True):
            err=out.get('error',out)
            raise RuntimeError('CLI '+str(args[:2])+': '+json.dumps(err,ensure_ascii=False))
        return out.get('data',out)
    def nodes(self,space,parent=None):
        result=[];cursor=None;seen=set()
        while True:
            args=['wiki','+node-list','--space-id',space,'--format','json']
            if parent: args+=['--parent-node-token',parent]
            if cursor: args+=['--page-token',cursor]
            d=self.call(*args);result.extend(d.get('nodes',[]))
            if not d.get('has_more'): return result
            cursor=d.get('page_token') or d.get('next_page_token')
            if not cursor or cursor in seen: raise RuntimeError('Invalid wiki pagination cursor')
            seen.add(cursor)
    def download(self,token,path,sha=None):
        path=P(path);path.parent.mkdir(parents=True,exist_ok=True)
        if path.exists() and sha and digest(path.read_bytes())==sha:return path
        if path.exists(): path.unlink()
        self.call('drive','+download','--file-token',token,'--output',os.path.relpath(path,self.cache))
        if sha and digest(path.read_bytes())!=sha: raise RuntimeError('Remote object checksum mismatch: '+path.name)
        return path
    def upload(self,path,parent,space,name=None):
        path=P(path).resolve();name=name or path.name
        matches=[n for n in self.nodes(space,parent) if n.get('title')==name]
        if len(matches)>1: raise RuntimeError('Ambiguous duplicate remote file: '+name)
        if matches:
            n=matches[0]
            if n.get('obj_type')!='file': raise RuntimeError('Remote name collision: '+name)
            return {'file_token':n['obj_token'],'node_token':n['node_token'],'name':name,'sha256':digest(path.read_bytes()),'size':path.stat().st_size,'reused':True}
        d=self.call('drive','+upload','--file',os.path.relpath(path,self.cache),'--wiki-token',parent,'--name',name)
        # Fresh listing is the authoritative receipt, not an assumed response shape.
        matches=[n for n in self.nodes(space,parent) if n.get('title')==name and n.get('obj_type')=='file']
        if len(matches)!=1: raise RuntimeError('Uploaded file cannot be verified: '+name)
        n=matches[0]
        return {'file_token':n['obj_token'],'node_token':n['node_token'],'name':name,'sha256':digest(path.read_bytes()),'size':path.stat().st_size,'reused':False}

class Repository:
    def __init__(self,config,cache):
        self.config=read_json(config);self.cache=P(cache).resolve();self.cache.mkdir(parents=True,exist_ok=True)
        self.lark=Lark(self.cache);self.space=self.config['space_id']
    def project(self,p):
        if p not in self.config['projects']: raise ValueError('Unknown project ID: '+p)
        return self.config['projects'][p]
    def releases(self,project):
        p=self.project(project)
        return sorted([n for n in self.lark.nodes(self.space,p['versions_node']) if n.get('obj_type')=='file' and n.get('title','').endswith('.release.json')],key=lambda n:n['title'])
    def load_release(self,project,version='latest'):
        nodes=self.releases(project)
        matches=nodes[-1:] if version=='latest' else [n for n in nodes if n['title']==version or n['title']==version+'.release.json']
        if not matches: return None
        if len(matches)!=1:raise RuntimeError('Ambiguous release')
        n=matches[0];p=self.lark.download(n['obj_token'],self.cache/'metadata'/n['title']);d=read_json(p)
        if d.get('schema')!=SCHEMA or d.get('project')!=project:raise RuntimeError('Release schema/project mismatch')
        d['_remote']={'file_token':n['obj_token'],'node_token':n['node_token']};return d
    def catalog(self):
        nodes=[n for n in self.lark.nodes(self.space,self.config['objects_node']) if n.get('obj_type')=='file' and re.fullmatch(r'catalog-[0-9TZ]+-[a-f0-9]{16}\.json',n.get('title',''))]
        if not nodes:return {'schema':SCHEMA,'chunks':{},'packs':{}}
        n=max(nodes,key=lambda n:n['title']);data=read_json(self.lark.download(n['obj_token'],self.cache/'metadata'/n['title']))
        return data
    def materialize_git(self,release,target):
        init_git(target)
        if release:
            for b in release['git']['bundles']:
                path=self.lark.download(b['file_token'],self.cache/'downloads'/b['name'],b['sha256'])
                git(target,'bundle','verify',str(path))
                git(target,'fetch',str(path),'+refs/heads/archive:refs/remotes/feishu/archive')
            git(target,'checkout','-f','-B','archive','refs/remotes/feishu/archive')
            if git(target,'rev-parse','HEAD').decode().strip()!=release['git']['commit']:raise RuntimeError('Git chain commit mismatch')
    def plan(self,root,project):
        refresh_conversations(root)
        previous=self.load_release(project);job=self.cache/'plans'/utc();job.mkdir(parents=True)
        snap,source=snapshot(root,job/'chunks');cat=self.catalog()
        needed={h for f in snap['files'].values() for h in f.get('chunks',[])}
        report={'project':project,'files':len(snap['files']),'bytes':snap['bytes'],'root_hash':snap['root_hash'],
                'changed':not previous or previous['root_hash']!=snap['root_hash'],'new_chunk_bytes':sum((job/'chunks'/h).stat().st_size for h in needed-set(cat['chunks'])),
                'reused_chunks':len(needed&set(cat['chunks'])),'source_files':len(source),'asset_files':len(snap['files'])-len(source)}
        write_json(job/'plan.json',report);say(**report);return report
    def push(self,root,project,message,committed=False):
        cfg=self.project(project)
        if not cfg.get('upload_enabled'):raise RuntimeError('This project is structure-only; enable only after explicit authorization.')
        if committed:
            if git(root,'status','--porcelain').strip():raise RuntimeError('Commit snapshot requires a clean worktree.')
        else:refresh_conversations(root)
        frozen_head=git(root,'rev-parse','HEAD',check=False).decode().strip()
        previous=self.load_release(project);job=self.cache/'jobs'/utc();job.mkdir(parents=True)
        snap,source=snapshot(root,job/'chunks');write_json(job/'snapshot.json',snap)
        if committed and (git(root,'status','--porcelain').strip() or git(root,'rev-parse','HEAD').decode().strip()!=frozen_head):raise RuntimeError('Working tree changed during committed snapshot.')
        if previous and previous['root_hash']==snap['root_hash']:
            say(status='unchanged',version=previous['version'],uploaded_bytes=0);return previous
        catalog=self.catalog();start_catalog=digest(encoded(catalog));version=utc()+'-'+snap['root_hash'][:12]
        needed={h for f in snap['files'].values() for h in f.get('chunks',[])}
        packs=make_packs(needed,job/'packs',catalog['chunks']);uploaded=0;newpacks=0
        for i,(h,path,members) in enumerate(packs):
            say(stage='upload-assets',pack=i+1,total=len(packs),bytes=path.stat().st_size)
            receipt=self.lark.upload(path,self.config['objects_node'],self.space)
            if not receipt['reused']:uploaded+=receipt['size'];newpacks+=1
            catalog['packs'][h]=receipt
            for member in members:catalog['chunks'][member]={'pack':h,'size':(job/'chunks'/member).stat().st_size}
            write_json(job/'upload-journal.json',catalog)
        # Immutable catalog checkpoints let a later version reuse completed uploads after interruption.
        if packs:
            if digest(encoded(self.catalog()))!=start_catalog:raise RuntimeError('Another publisher updated the object catalog; rerun serially.')
            cp=job/('catalog-'+utc()+'-'+digest(encoded(catalog))[:16]+'.json');write_json(cp,catalog)
            self.lark.upload(cp,self.config['objects_node'],self.space)
        shadow=job/'git';self.materialize_git(previous,shadow)
        old=git(shadow,'ls-files','-z').decode('utf-8').split('\0')
        for name in old:
            if name:
                p=safe_path(shadow,name)
                if p.exists():p.unlink()
        for name,b in source.items():
            p=safe_path(shadow,name);p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(b)
        write_json(shadow/'.feishu-assets.json',{'schema':SCHEMA,'files':snap['files'],'root_hash':snap['root_hash']})
        git(shadow,'add','-f','--','.');git(shadow,'commit','-m',version+' '+message)
        commit=git(shadow,'rev-parse','HEAD').decode().strip()
        bundle=job/(version+'.bundle');checkpoint=not previous or len(previous['git']['bundles'])>=20
        args=['bundle','create',str(bundle),'refs/heads/archive']
        if previous and not checkpoint:args+=['^'+previous['git']['commit']]
        git(shadow,*args);git(shadow,'bundle','verify',str(bundle))
        bundle_receipt=self.lark.upload(bundle,cfg['versions_node'],self.space);uploaded+=bundle_receipt['size'] if not bundle_receipt['reused'] else 0
        source_head=frozen_head
        oldfiles=previous['files'] if previous else {};newfiles=snap['files']
        changes={'added':sorted(set(newfiles)-set(oldfiles)),'deleted':sorted(set(oldfiles)-set(newfiles)),
                 'modified':sorted(k for k in set(newfiles)&set(oldfiles) if newfiles[k]['sha256']!=oldfiles[k]['sha256'])}
        # Assets do not change the user's .git, index, branch, or commits.
        release={'schema':SCHEMA,'project':project,'version':version,'message':message,'created_at':dt.datetime.now(dt.timezone.utc).isoformat(),
                 'previous':previous['version'] if previous else None,'source_git_head':source_head,'snapshot_kind':'git-commit' if committed else 'working-tree',
                 'root_hash':snap['root_hash'],'file_count':len(newfiles),'bytes':snap['bytes'],'files':newfiles,'changes':changes,
                 'git':{'commit':commit,'checkpoint':checkpoint,'bundles':([] if checkpoint else previous['git']['bundles'])+[bundle_receipt]},
                 'chunks':{h:catalog['chunks'][h] for h in sorted(needed)},
                 'packs':{h:catalog['packs'][h] for h in sorted({catalog['chunks'][x]['pack'] for x in needed})},
                 'stats':{'new_asset_packs':newpacks,'uploaded_payload_bytes':uploaded,'reused_chunks':len(needed)-sum(len(m) for _,_,m in packs)},
                 'excluded':snap['excluded']}
        # Check HEAD again before publication. Concurrent writers must not silently fork latest.
        current=self.load_release(project)
        if (current or {}).get('version')!=(previous or {}).get('version'):raise RuntimeError('Another publisher changed latest; rerun serially.')
        path=job/(version+'.release.json');write_json(path,release)
        receipt=self.lark.upload(path,cfg['versions_node'],self.space)
        actual=self.lark.download(receipt['file_token'],job/'published-release.json',receipt['sha256'])
        if read_json(actual)['root_hash']!=snap['root_hash']:raise RuntimeError('Published manifest mismatch')
        write_json(self.cache/('last-'+project+'.json'),{'version':version,'manifest':str(actual),'receipt':receipt,'job':str(job)})
        say(status='published',version=version,files=len(newfiles),bytes=snap['bytes'],uploaded_payload_bytes=uploaded,new_asset_packs=newpacks,manifest_node=receipt['node_token'])
        return release
    def restore(self,project,version,output):
        output=P(output).resolve()
        if output.exists() and any(output.iterdir()):raise ValueError('Restore requires an empty or new directory; never overwrite a working game.')
        release=self.load_release(project,version)
        if not release:raise ValueError('Release not found')
        # Validate every source path before any output mutation.
        for name in release['files']:safe_path(output,name)
        output.mkdir(parents=True,exist_ok=True);self.materialize_git(release,output)
        downloaded={}
        for i,(h,p) in enumerate(release['packs'].items()):
            say(stage='restore-assets',pack=i+1,total=len(release['packs']))
            downloaded[h]=self.lark.download(p['file_token'],self.cache/'downloads'/p['name'],p['sha256'])
        for name,f in release['files'].items():
            if f['storage']!='cas':continue
            target=safe_path(output,name);target.parent.mkdir(parents=True,exist_ok=True)
            with target.open('wb') as out:
                for h in f['chunks']:
                    info=release['chunks'][h]
                    with zipfile.ZipFile(downloaded[info['pack']]) as z:
                        entry=z.getinfo(h)
                        if entry.file_size!=info['size'] or entry.file_size>CHUNK:raise RuntimeError('Invalid chunk size')
                        b=z.read(h)
                    if digest(b)!=h:raise RuntimeError('Chunk hash mismatch')
                    out.write(b)
        report=verify_files(output,release);write_json(self.cache/('restore-'+project+'-'+release['version']+'.json'),report)
        say(**report);return report

def verify_files(root,release):
    failures=[]
    for name,f in release['files'].items():
        p=safe_path(root,name)
        if not p.is_file() or p.stat().st_size!=f['size']:
            failures.append(name);continue
        h=hashlib.sha256()
        with p.open('rb') as stream:
            while b:=stream.read(CHUNK):h.update(b)
        if h.hexdigest()!=f['sha256']:failures.append(name)
    if failures:raise RuntimeError('Restored file mismatch: '+', '.join(failures[:10]))
    if digest(encoded(release['files']))!=release['root_hash']:raise RuntimeError('Manifest root hash mismatch')
    return {'status':'verified','files':len(release['files']),'bytes':sum(f['size'] for f in release['files'].values()),'root_hash':release['root_hash'],'output':str(P(root).resolve())}

def prepare_godot(root, executable, cache):
    root=P(root).resolve();cache=P(cache).resolve();cache.mkdir(parents=True,exist_ok=True)
    if not (root/'project.godot').is_file():raise ValueError('Missing project.godot')
    engine=P(executable).resolve()
    if not engine.is_file():raise ValueError('Godot executable not found')
    env=os.environ.copy()
    for key in ('APPDATA','LOCALAPPDATA'):
        folder=cache/key.lower();folder.mkdir(parents=True,exist_ok=True);env[key]=str(folder)
    # First cold scan registers GDExtension importers; second imports Spine resources.
    for i in (1,2):
        log=cache/('godot-import-'+str(i)+'.log')
        say(stage='prepare-godot',import_pass=i,total=2)
        run=subprocess.run([str(engine),'--headless','--path',str(root),'--editor','--import','--quit','--log-file',str(log)],stdout=subprocess.PIPE,stderr=subprocess.PIPE,env=env,timeout=240)
        combined=run.stdout+run.stderr
        (cache/('godot-import-'+str(i)+'.console.log')).write_bytes(combined)
        if run.returncode or b'SCRIPT ERROR:' in combined or b'\nERROR:' in combined:
            raise RuntimeError('Godot import failed; see '+str(log))
    checked=0
    for meta in (root/'assets').rglob('*.import'):
        text=meta.read_text(encoding='utf-8')
        if 'importer="spine.' not in text:continue
        match=re.search(r'^path="res://([^"\n]+)"',text,re.M)
        if not match or not safe_path(root,match[1]).is_file():raise RuntimeError('Missing Spine import cache: '+str(meta))
        checked+=1
    report={'status':'godot-ready','spine_imports':checked,'root':str(root),'passes':2}
    write_json(cache/'result.json',report);say(**report);return report

@contextlib.contextmanager
def local_lock(cache):
    lock=P(cache)/'publisher.lock';lock.parent.mkdir(parents=True,exist_ok=True)
    try:fd=os.open(lock,os.O_CREAT|os.O_EXCL|os.O_WRONLY)
    except FileExistsError:raise RuntimeError('Another local publish may be running: '+str(lock))
    try:
        os.write(fd,str(os.getpid()).encode());os.close(fd);yield
    finally:lock.unlink(missing_ok=True)

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--config',default=str(P(__file__).with_name('repository.json')))
    ap.add_argument('--cache',default=str(P(os.environ.get('LOCALAPPDATA',tempfile.gettempdir()))/'GameFeishuRepository'))
    subs=ap.add_subparsers(dest='cmd',required=True)
    for c in ('plan','push'):
        sp=subs.add_parser(c);sp.add_argument('--root',required=True);sp.add_argument('--project',required=True)
        if c=='push':
            sp.add_argument('--message',required=True);sp.add_argument('--committed',action='store_true',help='Publish the already committed clean workspace without refreshing conversation files')
    sp=subs.add_parser('list');sp.add_argument('--project',required=True)
    sp=subs.add_parser('restore');sp.add_argument('--project',required=True);sp.add_argument('--version',default='latest');sp.add_argument('--output',required=True);sp.add_argument('--godot')
    sp=subs.add_parser('prepare');sp.add_argument('--root',required=True);sp.add_argument('--godot',required=True)
    sp=subs.add_parser('verify');sp.add_argument('--manifest',required=True);sp.add_argument('--root',required=True)
    args=ap.parse_args()
    if args.cmd=='verify':say(**verify_files(args.root,read_json(args.manifest)));return
    if args.cmd=='prepare':prepare_godot(args.root,args.godot,P(args.cache)/'godot-prepare');return
    repo=Repository(args.config,args.cache)
    if args.cmd=='plan':repo.plan(args.root,args.project)
    elif args.cmd=='push':
        with local_lock(repo.cache):repo.push(args.root,args.project,args.message,args.committed)
    elif args.cmd=='list':say(versions=[n['title'].removesuffix('.release.json') for n in repo.releases(args.project)])
    elif args.cmd=='restore':
        repo.restore(args.project,args.version,args.output)
        if args.godot:prepare_godot(args.output,args.godot,repo.cache/'godot-prepare')
if __name__=='__main__':
    try:main()
    except Exception as e:say(status='error',message=str(e));sys.exit(1)
