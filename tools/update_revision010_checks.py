from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
p=ROOT/'tests/earth/test_home_flow.gd'
s=p.read_text(encoding='utf-8')
start=s.index('\tawait click("back");await click("map");')
end=s.index('\tawait click("printer");',start)
s=s[:start]+'''\tawait click("back")
	ck(not game.buttons.has("map"),"no floorplan entry")
	await click("door_back");await click("door_back");await click("door_balcony")
	ck(game.model.s.home.room=="balcony","balcony linked to living")
	ck(game.model.s.home.preset==stable,"doors preserve assignments")
	await click("door_back");await click("door_workroom");await shot("05-workroom")
'''+s[end:]
start=s.index('\tawait click("back");await click("collection");')
end=s.index('\tawait shot("08-squad")',start)
s=s[:start]+'''\tawait click("back");ck(not game.buttons.has("collection"),"collection removed from decorated workroom")
	await click("door_back");await click("depart")
	ck(game.view=="missions","black door hosts anomaly archive")
	await click("next_page");await click("mission11");ck(game.buttons.open_portal.disabled,"locked portal cannot dispatch")
	await click("back");await click("door_workroom");await click("squad");ck(game.view=="squad","squad menu")
'''+s[end:]
s=s.replace('await click("depart");await click("mission1")','await click("depart");await click("mission1");await click("open_portal");await create_timer(1.0).timeout')
s=s.replace('await click("back");await click("collection");await click("support");await click("buy_laser")','await click("back");await click("door_back");await click("depart");await click("support");await click("buy_laser")')
s=s.replace('support purchased through collection','support purchased through portal')
s=s.replace('["base","map","squad","printer","collection","growth","suits","room","support","missions"]','["base","squad","printer","equipment","growth","suits","room","support","missions"]')
p.write_text(s,encoding='utf-8')
for name in ['tools/build_earth.gd','tools/build_earth.ps1','启动地球篇.cmd']:
    p=ROOT/name;s=p.read_text(encoding='utf-8-sig').replace('0.9.0','0.10.0').replace('earth-stage01-test','earth-loot-portal')
    if p.suffix=='.cmd':p.write_bytes(s.replace('\r\n','\n').replace('\n','\r\n').encode('utf-8'))
    else:p.write_text(s,encoding='utf-8')
print('Updated checks for intentional removal of map/collection and two-step deployment; build target 0.10.0.')
