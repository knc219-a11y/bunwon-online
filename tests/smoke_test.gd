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

	# 2) 시작 상태: 공급함에 알 1개, 사냥꾼은 잠김
	_check(GameState.village_eggs.size() == Config.START_VILLAGE_EGGS and GameState.village_eggs[0] == CreatureCatalog.SLIME, "공급함에 슬라임 알 1개로 시작")
	main.switch_character()
	_check(main.active == farmer, "첫 슬라임 배치 전에는 사냥꾼 전환 불가")

	# 3) 농부: 공급함에서 받기 → 부화기 → 다음 날 부화 (첫 슬라임은 급수)
	farmer.position = main.supply_box.position
	main.interact()
	_check(GameState.farmer_eggs.size() == 1 and GameState.village_eggs.is_empty(), "농부가 공급함에서 알 수령")
	farmer.position = main.incubator.position
	main.interact()
	_check(main.incubating_days == Config.EGG_HATCH_DAYS, "부화기에 알 넣기")
	main.next_day()
	_check(main.creatures.size() == 1, "다음 날 부화")
	var slime: Creature = main.creatures[0]
	_check(slime.data.creature_trait != null and slime.data.base_work_speed > 0.0, "부화 시 능력치/Trait 생성")
	_check(slime.job == CreatureJobs.WATER, "첫 슬라임은 급수 역할")
	_check(slime.data.element_names() == "물", "첫 슬라임은 물속성")
	_check(slime.data.base_work_speed >= Config.FIRST_CREATURE_MIN_WORK_SPEED and slime.data.base_radius >= Config.FIRST_CREATURE_MIN_RADIUS, "첫 슬라임 최저 능력치 보장")

	# 4) 슬라임 옮겨서 배치 → 급수 역할 → 자동으로 물주기
	farmer.position = slime.position
	main.interact()
	_check(slime.carried_by == farmer, "슬라임 들기")
	var home := Vector2i(6, 5)
	farmer.position = Farm.center_of(home)
	main.interact()
	_check(slime.carried_by == null and slime.home == home, "슬라임 배치")
	_check(GameState.hunter_unlocked, "첫 슬라임 배치로 사냥꾼 해금")
	for target in [home + Vector2i.RIGHT, home + Vector2i.LEFT]:
		main.farm.do_work(Farm.Work.TILL, target)
		main.farm.do_work(Farm.Work.SOW, target)
	# 자동 작업 타이머가 테스트보다 먼저 일감을 가져가지 않도록 끄고 직접 일을 시킨다
	slime.auto_work = false
	for i in 2:
		_check(slime.work_once(), "슬라임이 일감 찾음 %d" % i)
		await get_tree().create_timer(slime.hop_time() + 0.1).timeout
		if i == 0:
			_check(slime.frame_column() in Creature.WATER_COLUMNS, "도착한 칸에서 급수 동작")
		await get_tree().create_timer(Config.CREATURE_WORK_ANIM_TIME).timeout
	var watered := 0
	for target in [home + Vector2i.RIGHT, home + Vector2i.LEFT]:
		if main.farm.get_cell(target).watered:
			watered += 1
	_check(watered == 2, "슬라임이 범위 안 작물에 물주기")

	# 5) 사냥꾼: 사냥터 입구 → 알 획득 → 마을 공급함
	main.switch_character()
	_check(main.active == main.hunter, "사냥꾼 전환")
	var hunter: Character = main.hunter
	hunter.position = main.hunt_gate.position
	main.interact()
	main.interact()
	_check(GameState.hunter_eggs.size() == 1, "사냥은 하루 한 번, 알 1개")
	hunter.position = main.supply_box.position
	main.interact()
	_check(GameState.village_eggs.size() == 1 and GameState.hunter_eggs.is_empty(), "마을 공급함에 알 공급")

	# 두 번째 슬라임은 역할 없이 태어나 직접 정한다
	main.switch_character()
	farmer.position = main.supply_box.position
	main.interact()
	farmer.position = main.incubator.position
	main.interact()
	main.next_day()
	_check(main.creatures.size() == 2 and main.creatures[1].job == CreatureJobs.REST, "두 번째 슬라임은 쉬는 중으로 부화")

	# 6) 속성: 물속성은 급수 재능, 비행은 이동이 빠름 (시험용 종을 코드로 만든다)
	var water: CreatureElement = load("res://data/creatures/elements/water.tres")
	var flying: CreatureElement = load("res://data/creatures/elements/flying.tres")
	var plain := CreatureData.hatch(CreatureCatalog.SLIME, RandomNumberGenerator.new())
	plain.creature_trait = null
	plain.elements = []
	var wet: CreatureData = plain.duplicate()
	wet.elements = [water, flying]
	_check(is_equal_approx(wet.work_speed(CreatureJobs.WATER), plain.work_speed(CreatureJobs.WATER) * 1.5), "물속성은 급수가 1.5배")
	_check(is_equal_approx(wet.work_speed(CreatureJobs.SOW), plain.work_speed(CreatureJobs.SOW)), "물속성은 다른 일에는 영향 없음")
	_check(wet.move_speed() > plain.move_speed(), "비행 속성은 이동이 빠름")
	_check(wet.element_names() == "물, 비행" and plain.element_names() == "무속성", "속성 이름 표시")

	# 7) 종별 속성 제한: 슬라임은 물·땅 중 하나만, 비행은 불가
	var rng := RandomNumberGenerator.new()
	var seen := {}
	var only_pool := true
	for i in 60:
		var d := CreatureData.hatch(CreatureCatalog.SLIME, rng)
		if d.elements.size() != 1 or d.elements[0] not in CreatureCatalog.SLIME.possible_elements:
			only_pool = false
		else:
			seen[d.elements[0].id] = true
	_check(only_pool and seen.has(&"water") and seen.has(&"earth"), "슬라임은 물 또는 땅으로만 부화")
	var s2 := CreatureData.hatch(CreatureCatalog.SLIME, rng)
	_check(not s2.set_element(flying), "슬라임에게 비행 속성 부여 불가")
	var earth: CreatureElement = load("res://data/creatures/elements/earth.tres")
	var dirt: CreatureData = plain.duplicate()
	dirt.elements = [earth]
	_check(dirt.work_speed(CreatureJobs.SOW) > plain.work_speed(CreatureJobs.SOW), "땅속성은 파종 재능")

	# 8) 캐릭터 스프라이트 시트: 방향별 행, 대기/걷기 열, 왼쪽은 반전
	farmer.moving = false
	farmer.facing = Vector2i.UP
	_check(farmer.frame_coords().y == 1 and farmer.frame_coords().x in Character.IDLE_COLUMNS, "위쪽 대기 프레임")
	farmer.moving = true
	farmer.facing = Vector2i.LEFT
	var f := farmer.frame_coords()
	_check(f.y == 2 and f.z == 1 and f.x in Character.WALK_COLUMNS, "왼쪽 걷기는 옆모습 반전")
	_check(farmer.sheet != null and farmer.sheet.get_width() == 48 * 6 and farmer.sheet.get_height() == 48 * 3, "시트 크기 288x144")

	# 9) 슬라임 스프라이트 시트: 속성별 시트, 대기2 · 깡충4 · 급수4
	for id in [&"water", &"earth"]:
		var tex: Texture2D = CreatureCatalog.SLIME.sprite_sheets.get(id)
		_check(tex != null and tex.get_width() == 32 * 10 and tex.get_height() == 32, "%s 슬라임 시트 320x32" % id)
	_check(slime.frame_column() in Creature.IDLE_COLUMNS, "일이 끝나면 대기 동작")

	print("SMOKE TEST: %s (%d failures)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		_failures += 1
