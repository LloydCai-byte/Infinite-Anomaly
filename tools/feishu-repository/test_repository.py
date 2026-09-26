"""Offline integration tests: real Git bundles, chunks and restore; fake Feishu transport."""
import pathlib, tempfile, unittest, shutil
import repository as r
P=pathlib.Path
class FakeLark:
 def __init__(self,root):self.root=root;self.items=[];self.uploads=0
 def nodes(self,space,parent=None):return [dict(x) for x in self.items if x['parent']==parent]
 def upload(self,path,parent,space,name=None):
  path=P(path);name=name or path.name
  for x in self.items:
   if x['parent']==parent and x['title']==name:
    return {'file_token':x['obj_token'],'node_token':x['node_token'],'name':name,'sha256':r.digest(path.read_bytes()),'size':path.stat().st_size,'reused':True}
  token='file'+str(len(self.items));dest=self.root/token;shutil.copyfile(path,dest)
  self.items.append({'parent':parent,'title':name,'obj_type':'file','obj_token':token,'node_token':'node'+token})
  self.uploads+=1
  return {'file_token':token,'node_token':'node'+token,'name':name,'sha256':r.digest(path.read_bytes()),'size':path.stat().st_size,'reused':False}
 def download(self,token,path,sha=None):
  path=P(path);path.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(self.root/token,path)
  if sha and r.digest(path.read_bytes())!=sha:raise RuntimeError('hash mismatch')
  return path
class RepositoryTests(unittest.TestCase):
 def setUp(self):
  self.tmp=tempfile.TemporaryDirectory(prefix='feishu-repo-test-');self.base=P(self.tmp.name).resolve();self.root=self.base/'game';r.init_git(self.root)
  (self.root/'project.godot').write_bytes(b'config_version=5\r\n')
  (self.root/'.gitignore').write_text('qa/\n.env\n',encoding='utf8')
  (self.root/'qa').mkdir();(self.root/'qa'/'big.mp4').write_bytes(b'ignored')
  (self.root/'.env').write_text('PRIVATE=not uploaded',encoding='utf8')
  (self.root/'assets').mkdir();self.binary=bytes(range(256))*((r.CHUNK+1024)//256)
  (self.root/'assets'/'movie.bin').write_bytes(self.binary);(self.root/'assets'/'copy.bin').write_bytes(self.binary)
  (self.root/'\u4e2d\u6587.gd').write_text('extends Node\n',encoding='utf8')
  r.git(self.root,'add','--','.');r.git(self.root,'commit','-m','original source');self.head=r.git(self.root,'rev-parse','HEAD');self.index=(self.root/'.git/index').read_bytes()
  self.remote=self.base/'remote';self.remote.mkdir();self.repo=r.Repository.__new__(r.Repository);self.repo.cache=self.base/'cache';self.repo.cache.mkdir()
  self.repo.space='space';self.repo.config={'objects_node':'objects','projects':{'test':{'versions_node':'versions','upload_enabled':True},'placeholder':{'versions_node':'empty','upload_enabled':False}}};self.repo.lark=FakeLark(self.remote)
 def tearDown(self):self.tmp.cleanup()
 def test_full_incremental_dedup_and_restore(self):
  a=self.repo.push(self.root,'test','baseline');self.assertEqual(len(a['chunks']),2);self.assertNotIn('.env',a['files']);self.assertNotIn('qa/big.mp4',a['files'])
  self.assertEqual(r.git(self.root,'rev-parse','HEAD'),self.head);self.assertEqual((self.root/'.git/index').read_bytes(),self.index)
  count=self.repo.lark.uploads;again=self.repo.push(self.root,'test','no change');self.assertEqual(again['version'],a['version']);self.assertEqual(self.repo.lark.uploads,count)
  (self.root/'project.godot').write_bytes(b'config_version=5\r\n;changed\r\n');(self.root/'\u4e2d\u6587.gd').unlink()
  b=self.repo.push(self.root,'test','text change and deletion');self.assertEqual(b['stats']['new_asset_packs'],0);self.assertEqual(len(b['git']['bundles']),2)
  out=self.base/'restored';self.repo.restore('test','latest',out);self.assertEqual((out/'assets/movie.bin').read_bytes(),self.binary);self.assertEqual((out/'project.godot').read_bytes(),(self.root/'project.godot').read_bytes());self.assertFalse((out/'\u4e2d\u6587.gd').exists())
  snap,_=r.snapshot(out,self.base/'rescan');self.assertEqual(snap['root_hash'],b['root_hash'])
  changed=bytearray(self.binary);changed[-1]=42;(self.root/'assets/movie.bin').write_bytes(changed)
  c=self.repo.push(self.root,'test','one changed chunk');self.assertEqual(c['stats']['new_asset_packs'],1);self.assertEqual(c['stats']['reused_chunks'],2)
  old=self.base/'old';self.repo.restore('test',a['version'],old);self.assertTrue((old/'\u4e2d\u6587.gd').exists());self.assertEqual((old/'project.godot').read_bytes(),b'config_version=5\r\n')
  (old/'project.godot').write_bytes(b'corrupt')
  with self.assertRaises(RuntimeError):r.verify_files(old,a)
  with self.assertRaises(ValueError):self.repo.restore('test','latest',old)
 def test_structure_only_and_path_safety(self):
  with self.assertRaises(RuntimeError):self.repo.push(self.root,'placeholder','forbidden')
  self.assertEqual(self.repo.lark.uploads,0)
  for p in ('../escape','/absolute','C:/escape','folder/../../escape','.git/config','a\\b'):
   with self.assertRaises(ValueError):r.safe_path(self.base,p)
 def test_committed_snapshot_rejects_uncommitted_changes(self):
  a=self.repo.push(self.root,'test','committed',committed=True)
  self.assertEqual(a['snapshot_kind'],'git-commit');self.assertEqual(a['source_git_head'],self.head.decode().strip())
  (self.root/'project.godot').write_bytes(b'new dirty work')
  count=self.repo.lark.uploads
  with self.assertRaises(RuntimeError):self.repo.push(self.root,'test','must refuse',committed=True)
  self.assertEqual(self.repo.lark.uploads,count)
 def test_packs_are_deterministic(self):
  job=self.base/'packjob';snap,_=r.snapshot(self.root,job/'chunks');chunks={h for v in snap['files'].values() for h in v.get('chunks',[])}
  a=r.make_packs(chunks,job/'packs',{});b=r.make_packs(chunks,job/'packs',{})
  self.assertEqual([x[0] for x in a],[x[0] for x in b]);self.assertEqual(r.make_packs(chunks,job/'packs',{h:{} for h in chunks}),[])
if __name__=='__main__':unittest.main(verbosity=2)
