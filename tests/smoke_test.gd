extends Node
## 헤드리스 스모크 테스트. 프로토타입 핵심 순환을 코드로 한 바퀴 돌린다.
## 실행: godot --headless --path . res://tests/smoke_test.tscn

var _failures := 0


func _ready() -> void:
	var main: Node2D = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame

	# 1) 농부 직접 농사: 갈기 → 심기 → 물주기 → (3일) → 수확
	var farmer: Character = main.farmer
	var cell := Vector2i(1, 2)
	farmer.position = Farm.center_of(cell + Vector2i.UP)
	farmer.facing = Vector2i.DOWN
	for i in 3:
		main.tool_index = i
		main.use_tool()
	var c: Farm.Cell = main.farm.get_cell(cell)
	_check(c.tilled and c.planted and c.watered, "갈기/심기/물주기")
	for day in Config.CROP_GROW_DAYS:
		main.next_day()
		main.tool_index = 2
		main.use_tool()
	_check(c.is_ripe(), "물 준 날 수만큼 자라서 수확 가능")
	main.tool_index = 3
	main.use_tool()
	_check(GameState.crops == 1 and not c.planted, "수확")

	# 방치해도 죽지 않음
	main.tool_index = 1
	main.use_tool()
	for i in 5:
		main.next_day()
	_check(c.planted and c.growth == 0, "물을 안 줘도 작물이 죽지 않고 그대로")

	# 2) 사냥꾼: 사냥터 입구 → 알 획득 → 마을 공급함
	main.switch_character()
	var hunter: Character = main.hunter
	hunter.position = main.hunt_gate.position
	main.interact()
	main.interact()
	_check(GameState.hunter_eggs == 1, "사냥은 하루 한 번, 알 1개")
	hunter.position = main.supply_box.position
	main.interact()
	_check(GameState.village_eggs == 1 and GameState.hunter_eggs == 0, "마을 공급함에 알 공급")

	# 3) 농부: 공급함에서 받기 → 부화기 → 다음 날 부화
	main.switch_character()
	farmer.position = main.supply_box.position
	main.interact()
	_check(GameState.farmer_eggs == 1, "농부가 공급함에서 알 수령")
	farmer.position = main.incubator.position
	main.interact()
	_check(main.incubating_days == Config.EGG_HATCH_DAYS, "부화기에 알 넣기")
	main.next_day()
	_check(main.slimes.size() == 1, "다음 날 부화")
	var slime: Slime = main.slimes[0]
	_check(slime.trait_name != "" and slime.speed > 0.0, "부화 시 능력치/Trait 생성")

	# 4) 슬라임 옮겨서 배치 → 급수 역할 → 자동으로 물주기
	farmer.position = slime.position
	main.interact()
	_check(slime.carried_by == farmer, "슬라임 들기")
	var home := Vector2i(6, 5)
	farmer.position = Farm.center_of(home)
	main.interact()
	_check(slime.carried_by == null and slime.home == home, "슬라임 배치")
	for target in [home + Vector2i.RIGHT, home + Vector2i.LEFT]:
		main.farm.do_work(Farm.Work.TILL, target)
		main.farm.do_work(Farm.Work.SOW, target)
	main.change_slime_role()
	main.change_slime_role()
	_check(slime.role == Slime.Role.WATER, "역할 바꾸기 (급수)")
	for i in 2:
		_check(slime.work_once(), "슬라임이 일감 찾음 %d" % i)
		await get_tree().create_timer(Config.SLIME_HOP_TIME + 0.1).timeout
	var watered := 0
	for target in [home + Vector2i.RIGHT, home + Vector2i.LEFT]:
		if main.farm.get_cell(target).watered:
			watered += 1
	_check(watered == 2, "슬라임이 범위 안 작물에 물주기")

	print("SMOKE TEST: %s (%d failures)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		_failures += 1
