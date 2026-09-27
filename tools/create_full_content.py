"""Build 30 independent case definitions using the approved five-scene placeholder."""
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'data' / 'containment'
OUT.mkdir(parents=True, exist_ok=True)

def save(name, value):
    (OUT / name).write_text(json.dumps(value, ensure_ascii=False, indent=2), encoding='utf-8')

groups = [
 ('M','物质',['构成异常','结构异常','物性异常','守恒异常','相态异常']),
 ('S','空间',['位置异常','尺度异常','方位异常','连通异常','边界异常']),
 ('T','时间',['流速异常','逆行异常','循环异常','连续性异常','同步异常']),
 ('L','生命',['代谢异常','稳态异常','发育异常','繁衍异常','死亡异常']),
 ('N','意识',['感知异常','记忆异常','自我认同异常','意志异常','意识边界异常']),
 ('C','因果',['因果缺失','因果倒置','因果转移','因果闭环','结果锁定']),
]
skills = [('perception','感知','察觉不显眼的痕迹'),('reason','思维','更快识别证据之间的关系'),('nerve','神经','在危险逼近时及时行动'),('survival','生存','在失误后找到退路'),('physique','体能','穿过难以通行的路线'),('dexterity','协调','稳定使用工具')]
items = ['灰白薄片','折叠碎片','停摆齿轮','温热纤维','透明结晶','纠缠细线']
points = ['结构','方位','时序','活性','知觉','关联']
catalog = []
for gi,(prefix,group,names) in enumerate(groups):
    for n,name in enumerate(names,1):
        catalog.append(dict(id=f'{prefix}{n:02}',name=name,group=group,index=len(catalog)+1,
                            story='floor',focus=skills[(gi+n-1)%6][0],item=f'item_{gi}',
                            sample_total=24,round_seconds=45,threshold=3+n//2))
save('catalog.json',catalog)
save('balance.json',dict(offline_cap_seconds=28800,skills={sid:dict(name=name,description=desc,primary=i,secondary=(i+1)%6,cap=20) for i,(sid,name,desc) in enumerate(skills)},points=points,
    items={f'item_{i}':dict(name=name,recipe={str(i):3,str((i+1)%6):1}) for i,name in enumerate(items)}))

def spot(id,title,rect,**kw): return dict(id=id,title=title,rect=rect,**kw)
def choice(id,label,**kw): return dict(id=id,label=label,**kw)
def node(name,image,line,spots,**kw): return dict(name=name,image=f'res://assets/continuity/story-floor/{image:02}.png',line=line,spots=spots,**kw)
nodes={}
nodes['landing']=node('门外的楼梯',1,'门牌写着十楼。你刚才明明又往下走了一层。',[
 spot('number','核对门牌',[1080,255,120,135],evidence='number',text='你记下了门牌。下楼前后都是十楼，脚步声却没有倒放。'),
 spot('window','看向窗外',[150,100,450,460],evidence='window',text='对面的车一直向前开。外面的时间没有重来。'),
 spot('down','沿楼梯继续',[1110,620,520,335],next='stranger'),
 spot('inspect','辨认墙角痕迹',[660,480,130,190],stat='perception',threshold=3,next='trace',evidence='trace'),
])
nodes['stranger']=node('楼道里的人',2,'楼道里的人站在门牌下。他没有跟着你下楼，却又出现在这里。',[
 spot('stranger','和他交谈',[145,250,440,650],choices=[
 choice('ask','问他刚才有没有移动',evidence='witness',text='“我一直在这里。你从那边下去，过一会儿又从那边上来。”'),
 choice('follow','相信他指的方向',next='follow'),
 choice('reason_route','根据已有线索推断',stat='reason',threshold=4,next='trace',evidence='trace')]),
 spot('paper','走近门牌下面的纸',[1570,190,310,665],next='note'),
 spot('up','回到楼梯口',[740,80,440,350],next='landing'),
],speech=dict(text='你也在找十一层？',rect=[620,140,420,140],tail=[505,370]))
nodes['follow']=node('另一个方向',1,'你跟着他的手势走进暗处。脚下的台阶开始变得稀薄。',[
 spot('retreat','沿刚才的扶手退回',[220,250,400,650],next='stranger',evidence='hazard',text='你退回原处。他仍然站在门牌下面。'),
 spot('jump','跨过断开的台阶',[1090,420,560,400],stat='physique',threshold=4,next='trace',evidence='trace'),
 spot('persist','继续向下走',[1200,850,410,200],death='你以为还有一级台阶。脚落下去时，那里已经没有任何东西。')])
nodes['trace']=node('墙角的划痕',1,'同一道新划痕，出现在楼梯上下两个出口边上。',[
 spot('check_trace','比对划痕与门的位置',[480,240,580,480],evidence='connection',text='划痕连着出口边缘。重复的是通路，不是时间，也不是那个人。'),
 spot('trace_next','沿划痕找到两扇门',[1210,530,510,430],next='doors')])
nodes['note']=node('纸角下面',3,'纸角被反复揭起。背面还有一层被压住的字。',[
 spot('read_note','翻开纸角',[998,349,235,297],evidence='rule',text='「灯灭的门通向家。亮灯的门，把两个出口接在一起。收容接缝，不要收人。」'),
 spot('tool_note','用收容夹照出压痕',[820,570,190,210],stat='dexterity',threshold=3,evidence='connection',text='夹片贴上纸面，门框接缝的轮廓显现出来。'),
 spot('continue','走到两扇门前',[235,510,415,430],next='doors'),
 spot('back_person','回去询问那个人',[1480,300,340,550],next='stranger')])
nodes['doors']=node('两扇门',4,'一盏灯亮着。两扇门之间，有一道几乎看不见的接缝。',[
 spot('dark_door','查看灯灭的门',[275,190,525,685],choices=[
 choice('listen_dark','贴近门听一听',evidence='home',text='门后有家里的声音，但接缝没有松开。先完成收容。'),
 choice('return_home','暂时回家',leave=True),
 choice('nerve_route','在门缝变化前记录它',stat='nerve',threshold=4,evidence='connection',text='你抓住了一瞬间：亮灯门的内侧，接着楼梯的另一端。')]),
 spot('lit_door','查看亮灯的门',[1110,190,525,685],choices=[
 choice('listen','听门里的脚步',evidence='echo',text='你向后退一步，脚步声从楼梯出口传来。声音穿过了不该相接的地方。'),
 choice('open_lit','推开门查看',next='danger'),
 choice('focus_route','凭当前能力直接确认接缝',stat='$focus',threshold=4,evidence='connection',next='inspect')]),
 spot('seam','检查两扇门之间的接缝',[850,280,190,530],next='inspect'),
 spot('back_note','回去看那张纸',[40,380,160,520],next='note')])
nodes['danger']=node('门后的空处',4,'亮灯门里没有地板。你抓住把手，身体已经悬空。',[
 spot('survive','稳住呼吸，沿门框攀回',[1050,180,560,620],stat='survival',threshold=3,next='doors',evidence='hazard'),
 spot('trust_voice','松手，跟随下面的声音',[340,490,390,390],death='下面的声音和你一样。你松开手，再也没有落到地面。')])
nodes['inspect']=node('确认目标',4,'收容夹只有一次闭合机会。你需要判断它该夹住什么。',[
 spot('verify','用脚步与划痕验证连接',[440,600,430,200],verify=True,evidence='connection',text='你确认亮灯门接回了楼梯。异常位于门框的连接边界。'),
 spot('prepare','打开收容夹',[900,520,520,310],containment=True),
 spot('inspect_back','暂时收起，继续调查',[100,270,290,570],next='doors')])
nodes['threshold']=node('回家的门',5,'夹片合拢。亮灯门后的脚步声断开了，另一扇门透出家里的光。',[
 spot('return_success','推门回家',[670,110,615,730],complete=True),
 spot('look_result','确认收容记录',[1320,450,420,340],text='收容夹内留下一道细线。门不再连接同一个出口。')])
save('floor.json',dict(id='floor',title='不存在的楼层',start='landing',nodes=nodes,
 evidence={'number':'重复的十楼门牌','window':'外界时间继续前进','witness':'始终没有移动的人','rule':'纸背的收容提醒','trace':'重复的墙面痕迹','connection':'门框连接了错误的出口','hazard':'错误路线没有地面','home':'门后传来家中的声音','echo':'脚步从另一端传回'},
 judgments=[{'id':'boundary','name':'亮灯门的接缝','reason':'出口被错误连接','correct':True},{'id':'person','name':'站在楼道里的人','reason':'他出现在相同位置','correct':False},{'id':'sign','name':'十楼的门牌','reason':'号码重复出现','correct':False}],
 idle_sequence=['landing','stranger','note','doors','threshold']))
save('samples.json',dict(locations=['楼梯口','走廊尽头','门牌下面','楼层转角'],conditions=['声音重复出现','入口藏在阴影里','记录与现场不符','线索留在物件背面','出口位置改变','接近时出现阻碍'],methods=['复核现场痕迹','绕开危险路线','依据先前记录判断','等待安全时机'],endings=['收容完成，样本送回','确认边界稳定，离开现场']))
print(f'Created {len(catalog)} independent cases and shared five-image story graph.')
