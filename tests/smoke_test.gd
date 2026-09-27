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

	# 1-1) 밭 넓히기 (A): 처음엔 첫 구역만, 나머지는 공급함에서 돈으로 연다
	var farm0: Farm = main.farm
	_check(GameState.open_plots == 1 and farm0.get_cell(Vector2i(6, 5)) != null and farm0.get_cell(Vector2i(7, 2)) == null, "처음엔 첫 구역(6x4)만 밭")
	_check(not farm0.do_work(Farm.Work.TILL, Vector2i(7, 2)), "잠긴 구역은 갈 수 없음")
	_check(farm0.find_work(Farm.Work.TILL, Vector2i(7, 3), 1) == Vector2i(6, 3), "잠긴 구역은 크리처 일감에서도 빠짐")
	farmer.position = main.supply_box.position
	main.interact()
	_check(main.supply_options().has(&"expand_field") and main.supply_option_text(&"expand_field").contains("300원"), "공급함에 밭 넓히기 (오른쪽 구역 300원)")
	GameState.money = 299
	_check(not main.supply_action(&"expand_field") and GameState.open_plots == 1 and GameState.money == 299, "돈이 모자라면 못 넓힘")
	GameState.money = 300 + 500 + 800
	for want in [Vector2i(7, 2), Vector2i(1, 6), Vector2i(7, 6)]:
		_check(main.supply_action(&"expand_field") and farm0.do_work(Farm.Work.TILL, want), "구역을 사서 넓히고 갈기 %s" % want)
		farm0.get_cell(want).tilled = false
	_check(GameState.money == 0 and GameState.open_plots == 4, "300 → 500 → 800원으로 세 구역 열림")
	_check(not main.supply_options().has(&"expand_field"), "다 넓히면 선택창에서 빠짐")
	main.close_menu()

	# 1-2) 도구 강화 (A 첫 조각): 괭이·물뿌리개를 공급함에서 사면 앞 3칸 일자에 한 번에 쓴다
	_check(main.supply_options().has(&"upgrade_hoe") and main.supply_option_text(&"upgrade_can").contains("큰 물뿌리개"), "공급함에 도구 손보기")
	_check(not main.supply_action(&"upgrade_hoe") and GameState.tool_level(Farm.Work.TILL) == 0, "돈이 모자라면 도구를 못 바꿈")
	var row := Vector2i(8, 3)
	farmer.position = Farm.center_of(row + Vector2i.LEFT)
	farmer.facing = Vector2i.RIGHT
	main.tool_index = 0
	main.use_tool()
	_check(farm0.get_cell(row).tilled and not farm0.get_cell(row + Vector2i.RIGHT).tilled, "처음 괭이는 한 칸만")
	GameState.money = Config.HOE_UPGRADE_PRICE + Config.CAN_UPGRADE_PRICE + Config.HUNTER_KNIFE_PRICE
	_check(main.supply_action(&"upgrade_hoe") and main.supply_action(&"upgrade_can") and main.supply_action(&"buy_knife") and GameState.money == 0, "넓은 괭이 · 큰 물뿌리개 · 사냥칼 사기")
	_check(not main.supply_action(&"upgrade_hoe") and not main.supply_options().has(&"upgrade_can") and not main.supply_options().has(&"buy_knife"), "산 도구는 선택창에서 빠짐")
	main._refresh_hud()
	_check(main._status.text.contains("넓은 괭이"), "HUD에 바뀐 도구 이름")
	main.use_tool()
	_check(farm0.get_cell(row + Vector2i(1, 0)).tilled and farm0.get_cell(row + Vector2i(2, 0)).tilled and not farm0.get_cell(row + Vector2i(3, 0)).tilled, "넓은 괭이는 앞 3칸 일자")
	main.tool_index = 1
	for i in 3:
		farmer.position = Farm.center_of(row + Vector2i(i - 1, 0))
		main.use_tool()
	main.tool_index = 2
	farmer.position = Farm.center_of(row + Vector2i.LEFT)
	main.use_tool()
	_check(farm0.get_cell(row).watered and farm0.get_cell(row + Vector2i(2, 0)).watered, "큰 물뿌리개는 심은 3칸에 한 번에 물")
	for i in 3:
		var rc: Farm.Cell = farm0.get_cell(row + Vector2i(i, 0))
		rc.tilled = false
		rc.planted = false
		rc.watered = false
	main.close_menu()

	# 1-3) 입는 장비 (B): 공급함에서 사면 바로 입고, 덧그림이 몸 시트와 같은 칸을 따라간다
	_check(main.supply_options().has(&"rain_boots") and main.supply_option_text(&"seed_vest").contains("씨앗 주머니 조끼"), "공급함에 입는 장비")
	_check(not main.supply_action(&"rain_boots") and Wearables.speed_mult(&"farmer") == 1.0, "돈이 모자라면 장비를 못 삼")
	var wear_total := 0
	for id: StringName in Wearables.ITEMS:
		wear_total += Wearables.ITEMS[id].price
	GameState.money = wear_total
	for id: StringName in Wearables.ITEMS:
		_check(main.supply_action(id), "장비 사서 입기: %s" % Wearables.ITEMS[id].name)
	_check(GameState.money == 0 and not main.supply_action(&"rain_boots"), "산 장비는 다시 못 삼")
	_check(Wearables.worn_by(&"farmer").size() == 3 and Wearables.worn_by(&"hunter").size() == 2, "농부 모자·옷·신발, 사냥꾼 모자·신발")
	_check(is_equal_approx(Wearables.speed_mult(&"farmer"), 1.15) and is_equal_approx(Wearables.speed_mult(&"hunter"), 1.15), "장화·등산화는 걷기 +15%")
	_check(farmer._wear.size() == 3 and main.hunter._wear.size() == 2, "입은 장비 덧그림")
	farmer.facing = Vector2i.LEFT
	farmer._update_sprite()
	_check(farmer._wear[0].frame_coords == farmer._sprite.frame_coords and farmer._wear[0].flip_h, "덧그림이 몸과 같은 칸 · 좌우 반전")
	var sow_row := Vector2i(8, 4)
	for i in 3:
		farm0.do_work(Farm.Work.TILL, sow_row + Vector2i(i, 0))
	farmer.position = Farm.center_of(sow_row + Vector2i.LEFT)
	farmer.facing = Vector2i.RIGHT
	main.tool_index = 1
	var seeds_now := GameState.seeds
	main.use_tool()
	_check(GameState.seeds == seeds_now - 3 and farm0.get_cell(sow_row + Vector2i(2, 0)).planted, "씨앗 주머니 조끼: 씨앗도 앞 3칸 한 번에")
	for i in 3:
		var sc: Farm.Cell = farm0.get_cell(sow_row + Vector2i(i, 0))
		sc.tilled = false
		sc.planted = false
	GameState.seeds = seeds_now
	main.close_menu()

	# 2) 시작 상태: 공급함에 알 1개, 사냥꾼은 잠김
	_check(GameState.village_eggs.size() == Config.START_VILLAGE_EGGS and GameState.village_eggs[0] == CreatureCatalog.SLIME, "공급함에 슬라임 알 1개로 시작")
	main.switch_character()
	_check(main.active == farmer, "첫 슬라임 배치 전에는 사냥꾼 전환 불가")

	# 3) 농부: 공급함에서 받기 → 부화기 → 다음 날 부화 (첫 슬라임은 급수)
	farmer.position = main.supply_box.position
	main.interact()
	_check(main.menu_open and main.supply_options()[0] == &"take_eggs", "공급함에서 F로 선택창, 알이 있으면 알 받기가 맨 위")
	main.menu_confirm()
	main.close_menu()
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
	# 밭에 크리처가 있으면 누구랑 갈지 먼저 묻는다. 여기서는 혼자 간다.
	_check(main.menu_open and main.menu_kind == &"companion" and main.companion_options() == [&"companion_0", &"solo"], "사냥터 입구 F → 누구랑 갈까? 창 (크리처 1 + 혼자)")
	_check(main.companion_option_text(&"companion_0").contains("물총"), "물 슬라임은 물총으로 돕는다고 표시")
	main._unhandled_input(_action(&"move_down"))
	main._unhandled_input(_action(&"interact"))
	var hunt: HuntGround = main.hunt
	_check(hunt != null and hunt.companion == null and not main.menu_open and not main.farm.visible and not farmer.visible and hunt.slimes.size() == Config.WILD_SLIME_COUNT, "사냥터 입구 F → 사냥터 화면, 야생 슬라임 3마리")
	hunt.set_ai(false)
	_check(hunt.hearts == Config.HUNTER_HEARTS, "하트 5개로 시작")
	# Space(바라보는 쪽)로 두 번 휘두르면 쓰러진다
	var wild: WildSlime = hunt.slimes[0]
	hunter.facing = Vector2i.UP
	wild.position = hunter.feet() + Vector2(0, -8 - Config.SWING_REACH)
	_check(hunt.swing() == 1 and wild.hp == 1, "휘두르기 한 번 맞히면 체력 -1")
	_check(hunt.swing() == 0, "휘두른 직후에는 다시 못 휘두름")
	hunt.tick(Config.SWING_COOLDOWN)
	wild.position = hunter.feet() + Vector2(0, -8 - Config.SWING_REACH)
	hunt.swing()
	_check(hunt.slimes.size() == 2 and hunt.drops.size() == 1, "두 번 맞으면 쓰러지고 그날 첫 슬라임은 알을 떨어뜨림")
	# 마우스 클릭: 누른 쪽을 향해 휘두른다
	hunt.tick(Config.SWING_COOLDOWN)
	var wild2: WildSlime = hunt.slimes[0]
	wild2.position = hunter.feet() + Vector2(-Config.SWING_REACH, -8)
	_check(hunt.swing(Vector2(-30, 2)) == 1 and hunter.facing == Vector2i.LEFT, "클릭한 쪽(왼쪽)을 바라보고 휘두름")
	hunt.tick(Config.SWING_COOLDOWN)
	wild2.position = hunter.feet() + Vector2(-Config.SWING_REACH, -8)
	hunt.swing(Vector2(-30, 2))
	_check(hunt.slimes.size() == 1 and hunt.drops.size() == 1, "알 보장은 첫 슬라임 한 번뿐")
	# 부딪히면 하트 -1, 잠깐 무적
	var wild3: WildSlime = hunt.slimes[0]
	wild3.position = hunter.feet()
	hunt.tick(0.01)
	wild3.position = hunter.feet()
	hunt.tick(0.01)
	_check(hunt.hearts == Config.HUNTER_HEARTS - 1, "부딪히면 하트 -1, 바로 다시 맞지는 않음")
	wild3.position = Vector2(20 * Config.TILE, 5 * Config.TILE)
	# 떨어진 알 줍기
	hunter.position = hunt.drops[0].at - Vector2(0, Character.FEET_Y)
	hunt.tick(0.01)
	_check(hunt.picked.size() == 1 and hunt.drops.is_empty(), "떨어진 알 줍기")
	hunter.position = hunt.SPAWN_AT
	main.interact()
	_check(main.hunt == null and main.farm.visible and GameState.hunter_eggs.size() == 1, "아래 입구 F로 마을에 돌아오면 알 1개")
	_check(main._near(main.hunt_gate) and hunter.walk_area == Rect2(), "마을 사냥터 입구 앞으로 돌아옴")
	main.interact()
	_check(main.hunt == null and GameState.hunter_eggs.size() == 1, "사냥터는 하루 한 번")
	hunter.position = main.supply_box.position
	main.interact()
	_check(GameState.village_eggs.size() == 1 and GameState.hunter_eggs.is_empty(), "마을 공급함에 알 공급")

	# 두 번째 슬라임은 역할 없이 태어나 직접 정한다
	main.switch_character()
	farmer.position = main.supply_box.position
	main.interact()
	main.menu_confirm()
	main.close_menu()
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

	# 10) 농장 바닥 타일: 타일셋 규격, 작물 성장 단계, 이웃 연결
	_check(Farm.TILES.get_width() == 24 * 16 and Farm.TILES.get_height() == 24 * 4, "농장 타일셋 384x96")
	_check(Farm.CROPS.get_width() == 24 * 4 and Farm.CROPS.get_height() == 24, "작물 시트 96x24")
	var crop := Farm.Cell.new()
	crop.planted = true
	var stages: Array[int] = []
	for g in Config.CROP_GROW_DAYS + 1:
		crop.growth = g
		stages.append(Farm.crop_stage(crop))
	_check(stages.front() == 0 and stages.back() == 3 and stages.has(1) and stages.has(2), "작물 성장 4단계 %s" % [stages])
	var fx := Config.FIELD_RECT.position + Vector2i(4, 4)
	for d in [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.UP, Vector2i.LEFT]:
		main.farm.get_cell(fx + d).tilled = d in [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.DOWN]
	main.farm.get_cell(fx + Vector2i.DOWN).watered = true
	_check(main.farm._mask(fx, main.farm._is_tilled) == 2 | 4, "갈아 둔 밭은 오른쪽·아래 이웃과 연결 (젖은 밭 포함)")
	_check(main.farm._mask(Vector2i(17, 6), main.farm._is_path) == 1 | 2 | 4 | 8, "흙길 교차점은 네 방향 연결")

	# 11) 마을 오브젝트: 그림 크기와 칸 수, 흙길 끝 칸에서 상호작용
	var props := {
		main.incubator: [Vector2(48, 48), Vector2i(2, 2), Vector2i(17, 5)],
		main.supply_box: [Vector2(48, 44), Vector2i(2, 1), Vector2i(17, 8)],
		main.hunt_gate: [Vector2(72, 56), Vector2i(3, 2), Vector2i(22, 5)],
	}
	for p: Prop in props:
		var spec: Array = props[p]
		_check(p.texture.get_size() == spec[0] and p.footprint == spec[1], "%s 그림 %s, %s칸" % [p.label, spec[0], spec[1]])
		_check(main.farm._is_path(spec[2]) and p.is_near(Farm.center_of(spec[2]), Config.PROP_INTERACT_DISTANCE),
			"%s 앞 흙길에서 상호작용" % p.label)
		_check(not p.is_near(Farm.center_of(spec[2] + Vector2i(-3, 0)), Config.PROP_INTERACT_DISTANCE),
			"%s 세 칸 떨어지면 상호작용 안 됨" % p.label)

	# 12) 배경 오브젝트: 밭 울타리와 농부 집 앞 흙길
	var farm: Farm = main.farm
	_check(Farm.FENCE.get_size() == Vector2(384, 24), "울타리 시트 384x24")
	_check(farm._mask(Vector2i(0, 1), farm._is_fence) == 2 | 4, "울타리 왼쪽 위 모서리는 오른쪽·아래 연결")
	_check(not farm._is_fence(Vector2i(13, 6)) and farm._is_path(Vector2i(13, 6)), "흙길이 들어오는 칸은 울타리를 비움")
	for x in Config.FIELD_RECT.size.x:
		for y in Config.FIELD_RECT.size.y:
			if farm._is_fence(Config.FIELD_RECT.position + Vector2i(x, y)):
				_check(false, "밭 칸에 울타리가 있으면 안 됨")
	var house_front := Vector2i(main.HOUSE_RECT.position.x + 2, main.HOUSE_RECT.end.y)
	_check(farm._is_path(house_front) and farm._mask(house_front, farm._is_path) == 8, "농부 집 현관 앞까지 흙길이 이어짐")

	# 13) 충돌과 앞뒤 가림: 집·나무는 밑동만 막고, 뒤로 가면 반투명. 울타리는 입구만 열림
	var house: Prop = main.house
	farmer.position = Farm.center_of(Vector2i(22, 13))
	for i in 30:
		farmer.step(Vector2(0, -2))
	_check(farmer.feet().y >= house.sort_y(), "집 벽으로는 못 들어감")
	farmer.position = Farm.center_of(Vector2i(19, 9)) + Vector2(0, -4)
	for i in 40:
		farmer.step(Vector2(1.5, 0))
	await get_tree().process_frame
	_check(farmer.position.x > Farm.center_of(Vector2i(21, 9)).x, "집 지붕 뒤로는 지나감")
	_check(farmer.z_index < house.z_index, "집 뒤에 있으면 집보다 먼저 그림")
	main.update_fading()
	_check(house.faded, "집에 가려지면 집이 반투명")
	farmer.position = Farm.center_of(Vector2i(22, 13))
	await get_tree().process_frame
	main.update_fading()
	_check(farmer.z_index > house.z_index and not house.faded, "집 앞에 있으면 캐릭터가 앞, 집은 그대로")
	farmer.position = Farm.center_of(Vector2i(25, 8))
	for i in 40:
		farmer.step(Vector2(0, -1.5))
	_check(farmer.feet().y > Farm.center_of(Vector2i(25, 6)).y, "감나무 밑동은 막힘")
	farmer.position = Farm.center_of(Vector2i(6, 3))
	for i in 40:
		farmer.step(Vector2(0, -2))
	_check(farmer.cell().y >= Config.FENCE_RECT.position.y + 1, "밭 울타리는 못 넘음")
	farmer.position = Farm.center_of(Vector2i(15, 6))
	for i in 60:
		farmer.step(Vector2(-2, 0))
	_check(farmer.cell().x <= Config.FIELD_RECT.end.x - 1, "흙길 입구로는 밭에 들어감")
	# 슬라임은 울타리 너머 칸으로 깡충 뛰지 않는다
	var outside := Vector2i(Config.FENCE_RECT.end.x, 4)
	var inside := Vector2i(Config.FIELD_RECT.end.x - 1, 4)
	farm.do_work(Farm.Work.TILL, inside)
	farm.do_work(Farm.Work.SOW, inside)
	_check(farm.find_work(Farm.Work.WATER, outside, 2) == inside, "울타리 밖에서도 범위 안에는 밭이 있음")
	_check(farm.find_work(Farm.Work.WATER, outside, 2, [], Farm.center_of(outside)) == null, "슬라임은 울타리를 넘어 일하러 가지 않음")
	_check(farm.find_work(Farm.Work.WATER, inside + Vector2i.LEFT, 2, [], Farm.center_of(inside + Vector2i.LEFT)) == inside, "울타리 안에서는 그대로 일함")
	# 들고 있는 슬라임은 든 캐릭터 앞에 그림
	var carried: Creature = main.creatures[1]
	carried.pick_up(farmer)
	await get_tree().process_frame
	_check(carried.z_index > farmer.z_index, "들고 있는 슬라임은 캐릭터 앞에 그림")
	carried.place(Vector2i(6, 6))

	# 14) 잠자기 (A②): 집 현관에서 F → 밤 1초 → 아침 카드 → F로 일어남
	if main.active != farmer:
		main.switch_character()
	farmer.position = Farm.center_of(Vector2i(10, 6))
	_check(not main.near_door(), "현관에서 멀면 잠잘 수 없음")
	var sleep_cell := Vector2i(3, 3)
	farm.do_work(Farm.Work.TILL, sleep_cell)
	farm.do_work(Farm.Work.SOW, sleep_cell)
	farm.do_work(Farm.Work.WATER, sleep_cell)
	var day_before := GameState.day
	farmer.position = Farm.center_of(main.DOOR_CELL)
	_check(main.near_door(), "현관 앞 칸에서는 잠잘 수 있음")
	main.interact()
	_check(main.sleeping and not farmer.active, "잠들면 조작이 멈춤")
	_check(GameState.day == day_before, "어두워지는 동안에는 아직 같은 날")
	main.interact()
	_check(main.sleeping, "어두워지는 중에 F를 눌러도 깨지 않음")
	await get_tree().create_timer(Config.SLEEP_FADE_TIME + 0.2).timeout
	_check(GameState.day == day_before + 1 and GameState.hunts_today == 0, "자고 나면 다음 날, 사냥 횟수 초기화")
	_check(main._morning_card.visible and main._night.color.a > 0.8, "밤 화면 위에 아침 카드")
	var card: String = main._morning_text.text
	_check(card.contains("%d일째 아침" % GameState.day) and card.contains("작물") and card.contains("F 일어나기"), "아침 카드에 밤사이 결과 표시")
	main.interact()
	_check(not main._morning_card.visible, "F로 아침 카드 닫기")
	await get_tree().create_timer(Config.WAKE_FADE_TIME + 0.2).timeout
	_check(not main.sleeping and farmer.active and main._night.color.a < 0.01, "일어나면 다시 조작 가능")

	# 15) 경제 첫 단계 (C): 공급함에 무 진열 → 밤사이 팔림 → 아침 정산, 씨앗은 공급함에서 바로 산다
	GameState.crops = 3
	GameState.money = 0
	GameState.displayed_crops = 0
	var seeds_before := GameState.seeds
	farmer.position = main.supply_box.position
	main.interact()
	_check(main.menu_open and farmer.frozen, "선택창이 열리면 캐릭터는 멈춤")
	_check(main.supply_options() == [&"display_crops", &"buy_seeds", &"close"], "알이 없으면 진열·씨앗·닫기만")
	_check(not main.supply_action(&"buy_seeds") and GameState.seeds == seeds_before, "돈이 모자라면 씨앗을 못 삼")
	main._unhandled_input(_action(&"move_down"))
	_check(main.menu_index == 1, "W/S로 고르기")
	main._unhandled_input(_action(&"move_up"))
	main._unhandled_input(_action(&"interact"))
	_check(GameState.crops == 0 and GameState.displayed_crops == 3, "F로 무 3개 진열")
	_check(main.supply_box.badge.contains("무 3"), "공급함에 진열한 무 표시")
	_check(main.menu_open and main.supply_options() == [&"buy_seeds", &"close"], "진열 뒤에도 선택창은 열려 있음")
	main._unhandled_input(_action(&"menu_close"))
	_check(not main.menu_open and not farmer.frozen, "Esc로 선택창 닫기")
	var money_lines: Array[String] = main.next_day()
	_check(GameState.money == 3 * Config.CROP_PRICE and GameState.displayed_crops == 0, "밤사이 무가 팔려 돈이 들어옴")
	_check(money_lines[0].contains("무 3개가 팔렸다") and money_lines[0].contains("+%d원" % (3 * Config.CROP_PRICE)), "아침 카드 첫 줄에 판매 정산")
	_check(main.supply_action(&"buy_seeds") and GameState.seeds == seeds_before + Config.SEED_PACK_SIZE and GameState.money == 3 * Config.CROP_PRICE - Config.SEED_PACK_PRICE, "씨앗 묶음 사기")
	var quiet: Array[String] = main.next_day()
	_check(not "\n".join(quiet).contains("팔렸다") and GameState.money == 3 * Config.CROP_PRICE - Config.SEED_PACK_PRICE, "진열한 게 없으면 정산 없음")
	main.close_menu()

	# 16) 튼튼한 사냥칼: 이후 태어나는 크리처는 능력치 바닥 보장 (첫 크리처와 같은 값)
	var weakest := 99.0
	var smallest := 99
	for i in 30:
		var k: Creature = main._hatch(CreatureCatalog.SLIME, Vector2i(3, 12))
		weakest = minf(weakest, k.data.base_work_speed)
		smallest = mini(smallest, k.data.base_radius)
		main.creatures.erase(k)
		k.queue_free()
	_check(weakest >= Config.FIRST_CREATURE_MIN_WORK_SPEED and smallest >= Config.FIRST_CREATURE_MIN_RADIUS, "사냥칼이 있으면 능력치 바닥 보장")

	# 17) 사냥터에서 쓰러져도 주운 것(떨어진 알 포함)은 그대로, 다음 날 다시 들어갈 수 있다
	main.next_day()
	var eggs_before := GameState.hunter_eggs.size()
	main._set_active(main.hunter)
	main.hunter.position = main.hunt_gate.position
	main.interact()
	main.menu_index = main.companion_options().size() - 1
	main.menu_confirm()
	var h2: HuntGround = main.hunt
	_check(h2 != null, "자고 나면 다시 사냥터에 들어감")
	h2.set_ai(false)
	var w: WildSlime = h2.slimes[0]
	w.hp = 1
	main.hunter.facing = Vector2i.UP
	w.position = main.hunter.feet() + Vector2(0, -8 - Config.SWING_REACH)
	h2.swing()
	_check(h2.drops.size() == 1, "새 날 첫 슬라임도 알 보장")
	h2.hearts = 1
	var w2: WildSlime = h2.slimes[0]
	w2.position = main.hunter.feet()
	h2.tick(0.01)
	_check(main.hunt == null and main.farm.visible, "하트가 0이 되면 쓰러져 마을로 돌아옴")
	_check(GameState.hunter_eggs.size() == eggs_before + 1, "쓰러져도 떨어진 알은 챙겨 옴")
	_check(main._near(main.hunt_gate), "쓰러지면 사냥터 입구 앞으로")

	# 18) 크리처 동행 (A. 따라오는 동료): 입구에서 고른 크리처가 따라와 알아서 싸우고, 돌아오면 제자리로
	main.next_day()
	var buddy: Creature = main.companion_candidates()[0]
	var buddy_home := buddy.home
	var buddy_job := buddy.job
	var buddy_pos := buddy.position
	main.hunter.position = main.hunt_gate.position
	main.interact()
	main.menu_index = 0
	main.menu_confirm()
	var h3: HuntGround = main.hunt
	_check(h3 != null and h3.companion != null and h3.companion.source == buddy, "고른 크리처와 함께 사냥터에 들어감")
	_check(not buddy.visible and not buddy.can_process(), "데려간 크리처는 사냥 동안 농장 일을 쉰다")
	_check(h3.companion.style == HuntCompanion.Style.SHOT, "물 슬라임은 물총")
	h3.set_ai(false)
	h3.companion_ai = false
	# 물총: 먼 거리의 야생 슬라임을 맞힌다. 그날 첫 슬라임이라 알 보장.
	var far: WildSlime = h3.slimes[0]
	h3.companion.position = main.hunter.feet() + Vector2(0, 20)
	for other in h3.slimes:
		other.position = h3.companion.position + Vector2(200, 0)
	far.position = h3.companion.position + Vector2(Config.COMPANION_SHOT_RANGE - 10, 0)
	h3.tick(0.01)
	_check(far.hp == Config.WILD_SLIME_HP - 1, "물총은 먼 거리의 야생 슬라임을 맞힘")
	far.position = h3.companion.position + Vector2(Config.COMPANION_SHOT_RANGE - 10, 0)
	h3.tick(0.01)
	_check(far.hp == Config.WILD_SLIME_HP - 1, "물총은 간격을 두고 쏜다")
	far.position = h3.companion.position + Vector2(Config.COMPANION_SHOT_RANGE - 10, 0)
	h3.tick(h3.companion.attack_interval())
	_check(h3.slimes.size() == Config.WILD_SLIME_COUNT - 1 and h3.drops.size() == 1, "크리처가 쓰러뜨린 슬라임도 그날 첫 알 보장")
	# 따라다니기
	h3.companion_ai = true
	for other in h3.slimes:
		other.position = main.hunter.feet() + Vector2(0, -200)
	h3.companion.position = main.hunter.feet() + Vector2(80, 0)
	for i in 30:
		h3.tick(0.05)
	_check(h3.companion.position.distance_to(main.hunter.feet()) <= Config.COMPANION_FOLLOW_DISTANCE + 4.0, "사냥꾼 뒤를 따라온다")
	_check(h3.hearts == Config.HUNTER_HEARTS, "크리처 동행 중에도 하트는 그대로 (크리처는 다치지 않음)")
	# 돌아오면 원래 자리·원래 일
	var eggs_before_buddy := GameState.hunter_eggs.size()
	main.hunter.position = h3.SPAWN_AT
	main.interact()
	_check(main.hunt == null and buddy.visible and buddy.can_process(), "돌아오면 크리처가 농장에 다시 나타나 일한다")
	_check(buddy.home == buddy_home and buddy.job == buddy_job and buddy.position == buddy_pos, "원래 자리·원래 일 그대로")
	_check(GameState.hunter_eggs.size() == eggs_before_buddy + 1, "크리처 덕에 떨어진 알도 챙겨 옴")
	# 땅 슬라임은 붙어서 박치기
	main.next_day()
	var earth_buddy: Creature = main._hatch(CreatureCatalog.SLIME, Vector2i(3, 3))
	earth_buddy.data.set_element(load("res://data/creatures/elements/earth.tres"))
	main.hunter.position = main.hunt_gate.position
	main.interact()
	main.menu_index = main.companion_candidates().find(earth_buddy)
	_check(main.companion_option_text(main.companion_options()[main.menu_index]).contains("박치기"), "땅 슬라임은 박치기로 돕는다고 표시")
	main.menu_confirm()
	var h4: HuntGround = main.hunt
	_check(h4.companion.style == HuntCompanion.Style.BUMP, "땅 슬라임은 박치기")
	h4.set_ai(false)
	h4.companion_ai = false
	var near: WildSlime = h4.slimes[0]
	for other in h4.slimes:
		other.position = main.hunter.feet() + Vector2(0, -150)
	h4.companion.position = main.hunter.feet() + Vector2(0, 20)
	near.position = h4.companion.position + Vector2(40, 0)
	h4.tick(0.01)
	_check(near.hp == Config.WILD_SLIME_HP, "박치기는 멀리서는 못 때림")
	near.position = h4.companion.position + Vector2(Config.COMPANION_BUMP_RANGE - 4, 0)
	var before_x := near.position.x
	h4.tick(0.01)
	_check(near.hp == Config.WILD_SLIME_HP - 1 and near.position.x - before_x > 14.0, "붙어서 박치기, 더 멀리 밀쳐냄")
	h4.companion_ai = true
	near.position = h4.companion.position + Vector2(50, 0)
	var gap := h4.companion.position.distance_to(near.position)
	h4.tick(0.1)
	_check(h4.companion.position.distance_to(near.position) < gap, "박치기 크리처는 가까운 야생 슬라임에게 다가간다")
	main.hunter.position = h4.SPAWN_AT
	main.interact()
	_check(main.hunt == null and earth_buddy.can_process(), "땅 슬라임도 돌아와 다시 일함")

	print("SMOKE TEST: %s (%d failures)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		_failures += 1


func _action(action: StringName) -> InputEventAction:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	return ev
