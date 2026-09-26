extends SceneTree
const Model = preload("res://scripts/model.gd")
const Store = preload("res://scripts/save_store.gd")
var checks: int = 0
var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		printerr("FAIL: " + message)

func _initialize() -> void:
	call_deferred("run")

func first_gate(seed_value: int = 42):
	var m = Model.new()
	m.new_game(seed_value)
	m.complete_tutorial()
	m.dispatch("A01")
	m.tick(60.0)
	return m

func boss(seed_value: int = 42):
	var m = first_gate(seed_value)
	m.buy("action")
	m.retry()
	m.tick(100.0)
	return m

func run() -> void:
	var m = Model.new()
	check(m.content.validate().is_empty(), "content references, tag dependency and upgrade reachability")
	check(not m.dispatch("A01"), "dispatch requires tutorial")
	check(m.complete_tutorial(), "tutorial completes")
	check(not m.complete_tutorial(), "tutorial cannot be claimed twice")
	check(m.s.cards == ["A01_01"] and m.s.tags == ["anchor"], "tutorial card and ability")
	check(not m.dispatch("B01"), "second dungeon locked before A01 boss")
	m.dispatch("A01")
	check(not m.settle(int(m.s.attempt_serial)), "cannot settle before elapsed duration")
	m.tick(60.0)
	check(m.s.credits == 60 and m.s.energy == 20, "T02 guaranteed first three stage economy")
	check(m.s.cards.size() == 3 and "silence" in m.s.tags, "guaranteed ability before gate")
	check(m.s.mode == "FARM" and m.s.target == "A01_FRONT" and m.s.blocked == "A01_S4", "T03 fallback instead of repeated failures")
	check(m.missing("A01_S4").size() == 1, "explicit power-only gap")
	check(not m.retry(), "retry rejects missing power")
	var old_snapshot: Dictionary = m.s.snapshot.duplicate(true)
	check(m.buy("action"), "T04 upgrade affordable")
	check(m.power() == 2 and m.s.credits == 0 and m.s.energy == 0, "upgrade costs exact resources")
	check(m.s.snapshot == old_snapshot and m.s.mode == "FARM", "upgrade does not mutate active attempt or auto-retry")
	check(not m.buy("action"), "max upgrade cannot debit twice")
	check(m.retry(), "manual retry after upgrade")
	m.tick(100.0)
	check(m.s.mode == "FARM" and m.s.target == "A01_END", "T05 automatic boss farming")
	check(m.s.credits == 80 and m.s.energy == 20, "remaining fixed rewards exact")
	check(m.s.cards.size() == 5 and "A01_08" in m.s.cards, "boss card guaranteed")
	check(m.is_unlocked("B01"), "B01 unlocked by boss")
	check(m.s.dungeon == "A01", "no automatic new-dungeon dispatch")
	var wallet: int = m.s.credits
	check(not m.settle(int(m.s.settled_serial)), "attempt cannot settle twice")
	check(m.s.credits == wallet, "duplicate settle cannot award resources")
	var rng_before: String = str(m.rng.state)
	m.read_comic("A01_1")
	m.read_comic("A01_1")
	check(m.s.credits == wallet and str(m.rng.state) == rng_before, "reading never awards or rolls RNG")
	var old_energy: int = m.s.energy
	check(not m.grant_card("A01_01"), "duplicate is not a new card")
	check(m.s.energy == old_energy + 5 and m.s.cards.size() == 5, "T07 sample parsed once, original retained")
	var old_clear_count: int = m.s.cleared.size()
	m.dispatch("A01", "A01_FRONT")
	m.tick(30.0)
	check(m.s.cleared.size() == old_clear_count and m.s.credits == wallet + 20, "old dungeon farm does not replay first reward")
	var partial_credits: int = m.s.credits
	m.tick(29.0)
	m.dispatch("B01")
	check(m.s.credits == partial_credits and m.s.remaining == 15, "T10 unfinished time discarded on switching")
	check(m.s.cards.has("A01_01") and m.s.upgrades.action == 1, "switch retains cards and upgrades")
	m.tick(60.0)
	check(m.s.target == "B01_END", "second dungeon uses same controller")
	check(m.s.cards.has("B01_01") and m.s.cards.has("B01_03"), "B01 fixed rewards")
	var front_count: int = int(m.s.pity.get("A01_FRONT", 0))
	m.tick(30.0)
	check(int(m.s.pity.get("A01_FRONT", 0)) == front_count, "pool counters independent")

	# Sweep deterministic seeds: guarantees are bounds, not a lucky demonstration.
	for seed_value in range(1, 101):
		var trial = boss(seed_value)
		for round_index in range(15):
			trial.tick(30.0)
		check("A01" in trial.s.completed and trial.collection_count("A01") == 8, "all three random cards within 15 rolls seed %d" % seed_value)
		var completed_credits: int = trial.s.credits
		trial.check_collections()
		check(trial.s.credits == completed_credits, "T08 collection reward once seed %d" % seed_value)
		check(int(trial.s.pity.A01_END) == 0, "full pool cannot bank pity seed %d" % seed_value)

	m = boss(123)
	for id in ["A01_05", "A01_06"]:
		m.grant_card(id)
	m.s.pity.A01_END = 4
	check(m.draw_pool("A01_END") == "A01_07", "T06 fifth drop guarantees last missing card")
	check(m.s.pity.A01_END == 0, "new card resets pity")
	m.check_collections()
	check("A01_END" in m.s.comics and "A01" in m.s.completed, "ending and gold unlocked together")
	var reward_before: int = m.s.credits
	m.s.credits += 80
	m.s.energy += 25
	m.buy("display")
	m.check_collections()
	check(m.s.credits == reward_before, "display upgrade does not retroactively pay ending")

	var snap: Dictionary = m.export_state()
	var restored = Model.new()
	check(restored.restore(snap), "restore versioned snapshot")
	check(restored.s.cards == m.s.cards and restored.s.completed == m.s.completed, "permanent collection survives reload")
	check(str(restored.rng.state) == str(m.rng.state), "64-bit RNG state lossless through strings")
	for i in range(10):
		check(restored.draw_pool("A01_END") == m.draw_pool("A01_END"), "restored RNG roll %d" % i)
	var online = boss(99)
	var catchup = Model.new()
	catchup.restore(online.export_state())
	for i in range(90):
		online.tick(1.0)
	catchup.tick(90.0)
	var online_state: Dictionary = online.export_state()
	var catchup_state: Dictionary = catchup.export_state()
	online_state.erase("first_obtained")
	catchup_state.erase("first_obtained")
	check(online_state == catchup_state, "T11 frame-independent time and identical payouts")
	var carry_trial = boss(11)
	carry_trial.tick(300.0, 2)
	check(carry_trial.s.carry == 240.0, "bounded catch-up retains unprocessed elapsed time")
	for i in range(4):
		carry_trial.tick(0.0, 2)
	check(carry_trial.s.carry == 0, "catch-up drains backlog without losing time")
	var negative_snapshot: Dictionary = carry_trial.export_state()
	carry_trial.tick(-50.0)
	check(carry_trial.export_state() == negative_snapshot, "negative elapsed time cannot regress or award")
	var decoration_first = first_gate(7)
	decoration_first.tick(30)
	check(decoration_first.buy("living"), "can choose visual upgrade before power")
	check(not decoration_first.buy("action"), "insufficient funds cannot buy power")
	decoration_first.tick(90)
	check(decoration_first.buy("action") and decoration_first.retry(), "stable free farming recovers from early decoration spending")
	var no_farm = Model.new()
	no_farm.complete_tutorial()
	no_farm.s.tags.clear()
	no_farm.dispatch("A01")
	check(no_farm.s.mode=="BLOCKED" and no_farm.s.remaining==0, "missing capability without legal farm remains BLOCKED")
	var blocked_events: int = no_farm.s.events.size()
	no_farm.tick(1000)
	check(no_farm.s.events.size()==blocked_events and no_farm.s.credits==0, "BLOCKED does not auto-retry or accrue rewards")
	var bonus_trial = boss(17)
	bonus_trial.s.credits += 80
	bonus_trial.s.energy += 25
	bonus_trial.buy("display")
	for id in ["A01_05","A01_06","A01_07"]:
		bonus_trial.grant_card(id)
	var balance: int = bonus_trial.s.credits
	bonus_trial.check_collections()
	check(bonus_trial.s.credits==balance+120, "pre-completion display upgrade applies to future credit reward")
	bonus_trial.stop()
	balance = bonus_trial.s.credits
	bonus_trial.tick(500)
	check(bonus_trial.s.credits==balance and bonus_trial.s.mode=="IDLE", "IDLE never creates work or income")

	var store = Store.new("res://.local/test_save.json")
	check(store.save(snap), "atomic snapshot write")
	check(store.save(snap), "atomic snapshot replacement and backup")
	var round_trip = Model.new()
	check(round_trip.restore(store.load_primary()), "T09 checksum JSON load")
	check(round_trip.s.cards == snap.cards and str(round_trip.rng.state) == snap.rng_state, "disk round-trip preserves cards and RNG")
	var corrupt = FileAccess.open(store.path, FileAccess.WRITE)
	corrupt.store_string("interrupted write")
	corrupt.close()
	check(store.load_primary().is_empty(), "corruption detected")
	check(not store.load_backup().is_empty(), "valid backup retained after corrupt primary")
	var recovered = Model.new()
	check(recovered.restore(store.load_backup()), "backup recoverable")
	var invalid_store = Store.new("res://.local/test_save.json/child.json")
	check(not invalid_store.save(snap), "write failure reported instead of claiming success")
	# Only these specifically owned test files are removed.
	for suffix in ["", ".bak", ".tmp"]:
		var test_path: String = store.path + suffix
		if FileAccess.file_exists(test_path):
			DirAccess.remove_absolute(test_path)
	var report: Dictionary = {"checks": checks, "failures": failures, "passed": failures.is_empty(), "engine": Engine.get_version_info().string}
	var report_file = FileAccess.open("res://.local/test_report.json", FileAccess.WRITE)
	if report_file:
		report_file.store_string(JSON.stringify(report, "  "))
		report_file.close()
	print("TEST RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
