import datetime, json, pathlib
from sync_checkpoint import ROOT,OUT,save

report=json.loads((OUT/'verification-final.json').read_text(encoding='utf-8'))
assert report['status']=='passed' and report['embedded_images']==68
images={a['id']:a for a in json.loads((OUT/'selected-images.json').read_text(encoding='utf-8'))['images']}
verified={a['id']:a for a in report['images']}
stamp=datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=8))).isoformat()
qpath=ROOT/'docs/anomaly-marathon-20261003/queue.json'
q=json.loads(qpath.read_text(encoding='utf-8'))
if not (OUT/'queue-before-upload-record.json').exists():save('queue-before-upload-record.json',q)

def annotate(asset):
    i=asset['id']
    if i not in verified:return
    a=images[i];v=verified[i]
    asset['uploaded']=True
    asset['feishu_checkpoint']={'date':stamp,'spreadsheet_token':'RAqiszeH4hgCNStMvagcP4btnmh','sheet_id':v['sheet_id'],'cell':v['cell'],'token':v['token'],'uploaded_file':a['file'],'uploaded_sha256':a['sha256'],'verified':True,'note':'连续场景上传continuous_file；原始生成图另保留。' if asset.get('continuous_file') else '本次明确授权的快照上传。'}

for mp in (ROOT/'art/anomaly-concepts/continuous-20261004').glob('*/manifest.json'):
    m=json.loads(mp.read_text(encoding='utf-8'))
    for a in m['assets']:annotate(a)
    m['feishu_verified_images']=sum(a['id'] in verified for a in m['assets'])
    mp.write_text(json.dumps(m,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
totals={'K002':26,'K003':26,'K006':16,'K007':16,'K008':15}
for item in q['items']:
    for a in item.get('assets',[]):annotate(a)
    if item['id'] in totals:item.setdefault('completed',{})['uploaded_images']=totals[item['id']]
for b in q['batches']:
    if b['id']=='B0002':b['uploaded_images']=32
    if b['id']=='B0003':b['uploaded_images']=15
q['counts']['scene_plans_uploaded_verified']=40
q['latest_upload_checkpoint']={'date':stamp,'user_instruction':'目前的内容上传飞书和git','scope':'2026-10-04当前成果单次快照','feishu_selected_images':67,'feishu_reference_images':1,'feishu_verified':True,'verification':'docs/anomaly-marathon-20261003/sync-current-20261004/verification-final.json','git_branch':'codex/art-checkpoint-20261004','git_status':'prepared_pending_push','future_default_upload':False,'production_goal_complete':False}
q['updated_at']=stamp
qpath.write_text(json.dumps(q,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('Recorded verified Feishu upload without changing production goal or next assets.')
