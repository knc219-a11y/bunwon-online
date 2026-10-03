extends Node
## 저장 → 게임 끄기 → 불러오기를 프로세스 둘로 확인한다 (2026-09-30 저장/불러오기).
## 1) godot --headless --path . res://tests/save_restart.tscn -- save   (70일째 섞인 상태를 만들어 저장하고 끔)
## 2) godot --headless --path . res://tests/save_restart.tscn -- load   (새로 켜서 불러오고 저장 때 상태와 비교)

const DIR := "user://restart_saves"
const EXPECT := "user://restart_saves/expect.bin"


func _ready() -> void:
	var phase := "save" if OS.get_cmdline_user_args().has("save") else "load"
	SaveGame.dir = DIR
	DirAccess.make_dir_recursive_absolute(DIR)
	var main: Node2D = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	var ok := true
	if phase == "save":
		TestStarts.apply(main, &"barn")
		GameState.minutes = 15 * 60
		GameState.hunter_eggs.append(load(TestStarts.SPECIES[&"tiger"]))
		main.incubating_days = 1
		# 시설 공사 중 (2026-10-03): 공사 수 · 오늘 공사 수도 담기는지
		GameState.site_work[&"naru"] = 7
		GameState.build_today = 3
		main.incubating_species = load(TestStarts.SPECIES[&"slime"])
		main.save_slot = 1
		ok = main.autosave()
		var f := FileAccess.open(EXPECT, FileAccess.WRITE)
		f.store_var(SaveGame.snapshot(main), false)
		f.close()
		print("SAVED: day %d · money %d · creatures %d · gear %d" % [GameState.day, GameState.money, main.creatures.size(), GameState.gear.size()])
	else:
		ok = SaveGame.load_into(main, 1)
		var want: Dictionary = FileAccess.open(EXPECT, FileAccess.READ).get_var(false)
		var got := SaveGame.snapshot(main)
		var diff: Array[String] = []
		for k: String in want:
			if k == "gs":
				for g: String in want.gs:
					if want.gs[g] != got.gs.get(g):
						diff.append("gs." + g)
			elif want[k] != got.get(k):
				diff.append(k)
		ok = ok and diff.is_empty()
		print("LOADED: day %d · money %d · creatures %d · gear %d · diff %s" % [GameState.day, GameState.money, main.creatures.size(), GameState.gear.size(), diff])
		SaveGame.erase(1)
		DirAccess.remove_absolute(EXPECT)
	print("SAVE RESTART %s: %s" % [phase.to_upper(), "PASS" if ok else "FAIL"])
	get_tree().quit(0 if ok else 1)
