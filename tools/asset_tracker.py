"""Local ledger exports; never calls Feishu or publishes automatically."""
from pathlib import Path
import argparse, csv, hashlib, html, json, shutil, struct, datetime

ROOT=Path(__file__).resolve().parents[1]
REG=ROOT/'assets/earth/asset_registry.json'
OUT=ROOT/'docs/asset-replacement'
def read():return json.loads(REG.read_text('utf-8-sig'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest() if p.is_file() else ''
def audit():
    data=read(); entries=data['entries']; out=[]
    for e in entries:
        target=ROOT/e['target_path']; current=ROOT/e['current_path'] if e['current_path'] else None
        actual=target if target.is_file() else current
        installed=e['integration_status']!='未替换'
        # Animation containers are shared: existence alone does NOT mark an action complete.
        issue=''
        native=e.get('render_mode')=='time_card'
        if installed and not target.is_file() and not native: issue='清单标为已接入，但目标文件缺失'
        if e['review_status']=='已通过' and (not installed or not e.get('review_evidence')):issue='验收标记缺少接入或验收依据'
        status='已验收' if installed and e['review_status']=='已通过' else ('已接入待验收' if installed else '未替换')
        row={'素材编号':e['id'],'素材名称':e['name'],'分类':e['category'],'替换状态':[status],
            '制作状态':[e['production_status']],'已接入游戏':installed,'用户验收':[e['review_status']],
            '当前文件':actual.relative_to(ROOT).as_posix() if actual and actual.is_file() else ('原生时间卡（黑底文字）' if native else '程序绘制 / 身份卡 / 姓名标记'),
            '候选新文件':e['candidate_path'],'固定替换入口':e['target_path'],'规格':e['spec'],'使用位置':e['used_by'],
            '替换版本':e['replacement_version'],'文件SHA256':sha(actual) if actual else '',
            '待办说明':e['notes'],'检查问题':issue,'验收意见':e.get('review_evidence','')}
        out.append(row)
    OUT.mkdir(exist_ok=True,parents=True)
    (OUT/'inventory.json').write_text(json.dumps(out,ensure_ascii=False,indent=2),'utf-8')
    with (OUT/'素材替换台账.csv').open('w',encoding='utf-8-sig',newline='') as f:
        w=csv.DictWriter(f,fieldnames=out[0].keys());w.writeheader()
        w.writerows({k:('、'.join(v) if isinstance(v,list) else v) for k,v in row.items()} for row in out)
    fields=[]
    for k in out[0]:
        field={'name':k,'type':'text'}
        if k in ['替换状态','制作状态','用户验收']:
            opts={'替换状态':['未替换','已接入待验收','已验收'],'制作状态':['待替换制作','已有候选','制作中','待修订'],'用户验收':['待用户验收','已通过','需修改']}[k]
            field.update(type='select',multiple=False,options=[{'name':x} for x in opts])
        if k=='已接入游戏':field['type']='checkbox'
        fields.append(field)
    fields += [{'name':'当前预览','type':'attachment'},{'name':'新素材','type':'attachment'}]
    (OUT/'feishu-fields.json').write_text(json.dumps(fields,ensure_ascii=False),'utf-8')
    for i in range(0,len(out),200):
        (OUT/f'feishu-records-{i//200+1}.json').write_text(json.dumps({'create_records':out[i:i+200]},ensure_ascii=False),'utf-8')
    counts={k:sum(row['替换状态']==[k] for row in out) for k in ['未替换','已接入待验收','已验收']}
    summary={'total':len(out),'status':counts,'problems':sum(bool(x['检查问题']) for x in out),'version':data['version']}
    (OUT/'audit.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2),'utf-8')
    esc=html.escape
    tr=[]
    for row in out:
        p=ROOT/row['当前文件']
        link=f'<a href="{p.as_uri()}">查看当前文件</a>' if p.is_file() else esc(row['当前文件'])
        tr.append('<tr>'+''.join('<td>'+value+'</td>' for value in [esc(row['素材编号']),esc(row['素材名称']),esc(row['分类']),esc(row['替换状态'][0]),esc(row['用户验收'][0]),link,esc(row['固定替换入口']),esc(row['待办说明'])])+'</tr>')
    page='''<!doctype html><meta charset="utf-8"><title>无限异常 · 素材替换台账</title>
<style>body{font:15px "Microsoft YaHei",sans-serif;background:#101c24;color:#e9eded;padding:30px}h1{font-size:28px}input,select{padding:12px;margin:6px;background:#233744;color:white;border:1px solid #607a89}table{border-collapse:collapse;width:100%}td,th{padding:12px;text-align:left;border-bottom:1px solid #344955}td{max-width:330px;word-break:break-all}thead{position:sticky;top:0;background:#1b303e}a{color:#a6dce8}small{color:#b0c3cf}</style>
<h1>无限异常 · 素材替换台账</h1><p>SUMMARY</p><small>“已生成”不等于“已接入”；“已接入”不等于“用户验收通过”。此页为本地快照，不自动上传飞书。</small><p><input id="search" placeholder="搜索编号、人物、镜头"><select id="state"><option value="">全部状态</option><option>未替换</option><option>已接入待验收</option><option>已验收</option></select></p><table><thead><tr><th>编号</th><th>名称</th><th>类别</th><th>替换状态</th><th>用户验收</th><th>当前文件</th><th>固定入口</th><th>说明</th></tr></thead><tbody>ROWS</tbody></table>
<script>function filter(){for(const r of document.querySelectorAll('tbody tr'))r.hidden=!(r.innerText.toLowerCase().includes(search.value.toLowerCase())&&(!state.value||r.children[3].innerText===state.value))}search.oninput=filter;state.onchange=filter;</script>'''
    page=page.replace('SUMMARY',f"共 {len(out)} 项 ｜ 未替换 {counts['未替换']} ｜ 已接入待验收 {counts['已接入待验收']} ｜ 已验收 {counts['已验收']}").replace('ROWS',''.join(tr))
    (OUT/'index.html').write_text(page,'utf-8')
    print(json.dumps(summary,ensure_ascii=False))
    return summary

def replace(id,source,version):
    data=read();e=next(x for x in data['entries'] if x['id']==id)
    src=Path(source).resolve();target=(ROOT/e['target_path']).resolve()
    if not target.is_relative_to(ROOT/'assets/earth'):raise ValueError('Replacement must stay in Earth assets')
    if target.suffix.lower() not in ['.png','.svg','.wav','.ogg']:raise ValueError('Animation packages require importer and runtime action checks; no single-file replacement.')
    if src.suffix.lower()!=target.suffix.lower():raise ValueError('File extension differs from registered target')
    if src==target:raise ValueError('Supply an external candidate; do not replace a file with itself')
    if target.suffix=='.png':
        raw=src.read_bytes()
        if raw[:8]!=b'\x89PNG\r\n\x1a\n':raise ValueError('Invalid PNG')
        w,h=struct.unpack('>II',raw[16:24])
        if '1920×1080' in e['spec'] and (w,h)!=(1920,1080):raise ValueError('Expected 1920×1080')
    stamp=datetime.datetime.now().strftime('%Y%m%d-%H%M%S-%f')
    backup=ROOT/'art/asset-replacement-history'/stamp
    backup.mkdir(parents=True)
    shutil.copy2(REG,backup/'registry-before.json')
    if target.is_file():shutil.copy2(target,backup/target.name)
    target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src,target)
    e.update(candidate_path=str(src),production_status='已有候选',integration_status='已接入待验收',review_status='待用户验收',replacement_version=version,review_evidence='')
    REG.write_text(json.dumps(data,ensure_ascii=False,indent=2),'utf-8')
    (backup/'change.json').write_text(json.dumps({'id':id,'from':str(src),'to':str(target),'sha256':sha(target),'version':version,'validation':'needs Godot import and runtime check'},ensure_ascii=False,indent=2),'utf-8')
    audit()

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('command',choices=['audit','replace']);p.add_argument('--id');p.add_argument('--file');p.add_argument('--version',default='待构建')
    a=p.parse_args()
    if a.command=='audit':audit()
    else:
        if not a.id or not a.file:p.error('replace requires --id and --file')
        replace(a.id,a.file,a.version)
