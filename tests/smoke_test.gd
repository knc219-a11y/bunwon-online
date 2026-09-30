extends Node
## 헤드리스 스모크 테스트. 프로토타입 핵심 순환을 코드로 한 바퀴 돌린다.
## 실행: godot --headless --path . res://tests/smoke_test.tscn

var _failures := 0


func _ready() -> void:
	# 사냥터 드롭표는 19)에서 따로 본다. 그 전까지는 알 보장만 보도록 끈다.
	HuntGround.loot_enabled = false
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
	for id: StringName in Wearables.shop_items():
		wear_total += Wearables.ITEMS[id].price
	GameState.money = wear_total
	for id: StringName in Wearables.shop_items():
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
	_check(slime.job == CreatureJobs.FARM, "첫 슬라임은 농사 역할 (급수 포함)")
	_check(slime.data.element_names() == "물", "첫 슬라임은 물속성")
	_check(slime.data.base_work_speed >= Config.FIRST_CREATURE_MIN_WORK_SPEED and slime.data.base_radius >= Config.FIRST_CREATURE_MIN_RADIUS, "첫 슬라임 최저 능력치 보장")

	# 4) 슬라임 옮겨서 배치 → 농사 역할 → 자동으로 물주기
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
	_check(hunt != null and hunt.companion == null and not main.menu_open and not main.farm.visible and not farmer.visible and hunt.slimes.size() == Config.WILD_SLIME_COUNT, "사냥터 입구 F → 사냥터 화면, 야생 슬라임 %d마리" % Config.WILD_SLIME_COUNT)
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
	_check(hunt.slimes.size() == Config.WILD_SLIME_COUNT - 1 and hunt.drops.size() == 1, "두 번 맞으면 쓰러지고 게임 첫 처치는 알을 떨어뜨림")
	# 마우스 클릭: 누른 쪽을 향해 휘두른다
	hunt.tick(Config.SWING_COOLDOWN)
	var wild2: WildSlime = hunt.slimes[0]
	wild2.position = hunter.feet() + Vector2(-Config.SWING_REACH, -8)
	_check(hunt.swing(Vector2(-30, 2)) == 1 and hunter.facing == Vector2i.LEFT, "클릭한 쪽(왼쪽)을 바라보고 휘두름")
	hunt.tick(Config.SWING_COOLDOWN)
	wild2.position = hunter.feet() + Vector2(-Config.SWING_REACH, -8)
	HuntGround.egg_roll = 0.99
	hunt.swing(Vector2(-30, 2))
	_check(hunt.slimes.size() == Config.WILD_SLIME_COUNT - 2 and hunt.drops.size() == 1, "알 보장은 게임 첫 처치 한 번뿐, 그 뒤로는 확률")
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
	hunter.position = hunt.spawn_at()
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
	_check(main.supply_options() == [&"display_crops", &"buy_seeds", &"train", &"close"], "알이 없으면 진열·씨앗·크리처 훈련·닫기만")
	_check(not main.supply_action(&"buy_seeds") and GameState.seeds == seeds_before, "돈이 모자라면 씨앗을 못 삼")
	main._unhandled_input(_action(&"move_down"))
	_check(main.menu_index == 1, "W/S로 고르기")
	main._unhandled_input(_action(&"move_up"))
	main._unhandled_input(_action(&"interact"))
	_check(GameState.crops == 0 and GameState.displayed_crops == 3, "F로 무 3개 진열")
	_check(main.supply_box.badge.contains("무 3"), "공급함에 진열한 무 표시")
	_check(main.menu_open and main.supply_options() == [&"buy_seeds", &"train", &"close"], "진열 뒤에도 선택창은 열려 있음")
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
	_check(h2.drops.is_empty(), "새 날 첫 처치라도 알은 보장되지 않음 (2026-09-29 드롭률 낮춤)")
	HuntGround.egg_roll = 0.0
	var w1b: WildSlime = h2.slimes[0]
	w1b.hp = 1
	w1b.position = main.hunter.feet() + Vector2(0, -8 - Config.SWING_REACH)
	h2.tick(Config.SWING_COOLDOWN)
	h2.swing()
	_check(h2.drops.size() == 1, "알 확률에 걸리면 알이 떨어짐")
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
	_check(h3.slimes.size() == Config.WILD_SLIME_COUNT - 1 and h3.drops.size() == 1, "크리처가 쓰러뜨린 슬라임도 알 확률은 같음")
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
	main.hunter.position = h3.spawn_at()
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
	main.hunter.position = h4.spawn_at()
	main.interact()
	_check(main.hunt == null and earth_buddy.can_process(), "땅 슬라임도 돌아와 다시 일함")

	# 19) 사냥터 드롭 (A + 드롭표, 디아블로2식): 20%로 돈 · 물약 · 잡템 · 장비, 장비 보장 칸 없음
	HuntGround.loot_enabled = true
	_check(HuntLoot.pick_kind(0.0) == &"money" and HuntLoot.pick_kind(39.9) == &"money" and HuntLoot.pick_kind(40.0) == &"potion" \
		and HuntLoot.pick_kind(65.0) == &"junk" and HuntLoot.pick_kind(85.0) == &"gear" and HuntLoot.pick_kind(99.9) == &"gear", "드롭 종류 무게 돈 40 · 물약 25 · 젤리 20 · 장비 15")
	for id in Wearables.ITEMS:
		if Wearables.is_hunt_drop(id):
			_check(not id in main.supply_options(), "사냥터 장비는 공급함에서 팔지 않음: %s" % id)
	var loot_rng := RandomNumberGenerator.new()
	loot_rng.seed = 7
	# 확률: 많이 굴려 보면 약 20%, 장비는 없는 것만 (가진 셈 치고 되돌린다)
	var owned_before := GameState.owned_wear.duplicate()
	var dropped := 0
	var gear_ids: Array[StringName] = []
	for i in 2000:
		var d := HuntLoot.roll_for_kill(loot_rng)
		if d.is_empty():
			continue
		dropped += 1
		if d.kind == &"gear" and d.has("id"):
			_check(not d.id in gear_ids, "세트 조각은 아직 없는 것만 떨어짐")
			gear_ids.append(d.id)
			GameState.owned_wear.append(d.id)
	_check(dropped > 330 and dropped < 470, "처치마다 약 20%% 드롭 (%d/2000)" % dropped)
	_check(gear_ids.size() == 3 and Wearables.missing_hunt_drops().is_empty(), "세트 세 조각이 모두 나옴")
	var gear_after_set := 0
	for i in 500:
		if HuntLoot.roll_for_kill(loot_rng).get("kind") == &"gear":
			gear_after_set += 1
	_check(gear_after_set > 0, "세트를 다 모아도 등급 장비는 계속 떨어짐 (%d/500)" % gear_after_set)
	GameState.owned_wear = owned_before
	# 실제 사냥터: 쓰러뜨린 자리에 떨어진 장비를 주우면 바로 입는다
	main.next_day()
	main.hunter.position = main.hunt_gate.position
	main.interact()
	main.menu_index = main.companion_options().size() - 1
	main.menu_confirm()
	var h5: HuntGround = main.hunt
	h5.set_ai(false)
	var base_hearts := h5.max_hearts()
	# 20%가 나올 때까지 같은 자리에서 쓰러뜨린다 (시드 고정)
	h5.loot_rng.seed = 3
	var target: WildSlime = h5.slimes[0]
	target.hp = 1
	main.hunter.facing = Vector2i.UP
	target.position = main.hunter.feet() + Vector2(0, -8 - Config.SWING_REACH)
	h5.swing()
	_check(h5.slimes.size() == Config.WILD_SLIME_COUNT - 1, "사냥터에서 쓰러뜨리면 드롭표를 굴림")
	h5.loot.clear()
	h5.loot.append({kind = &"gear", id = &"acorn_helm", at = main.hunter.feet() + Vector2(0, 30)})
	_check(HuntLoot.label(h5.loot[0]) == "도토리 투구", "땅에 장비 이름이 보임")
	main.hunter.position = h5.loot[0].at - Vector2(0, Character.FEET_Y)
	h5.tick(0.01)
	_check(h5.loot.is_empty() and GameState.worn[&"hunter"].get(&"hat") == &"acorn_helm" and Wearables.is_owned(&"acorn_helm"), "주우면 바로 입음 (모자 칸)")
	_check(h5.max_hearts() == base_hearts + 1 and h5.hearts == h5.max_hearts(), "도토리 투구: 하트 칸 +1, 그만큼 채워짐")
	# 빨간 물약
	GameState.potions = 1
	h5.hearts = h5.max_hearts() - 1
	main._unhandled_input(_action(&"use_potion"))
	_check(h5.hearts == h5.max_hearts() and GameState.potions == 0, "1 키로 빨간 물약을 마시면 하트 +1")
	GameState.potions = 1
	_check(not h5.drink_potion() and GameState.potions == 1, "하트가 가득하면 물약을 아낌")
	# 나머지 세트 조각과 잡템·돈은 땅에 둔 채 떠나도 챙긴다
	var money_before := GameState.money
	h5.loot.append({kind = &"gear", id = &"forest_cape", at = Vector2(5 * Config.TILE, 5 * Config.TILE)})
	h5.loot.append({kind = &"gear", id = &"feather_boots", at = Vector2(6 * Config.TILE, 5 * Config.TILE)})
	h5.loot.append({kind = &"junk", at = Vector2(7 * Config.TILE, 5 * Config.TILE)})
	h5.loot.append({kind = &"money", amount = 20, at = Vector2(8 * Config.TILE, 5 * Config.TILE)})
	var junk_before := GameState.junk
	main.hunter.position = h5.spawn_at()
	main.interact()
	_check(main.hunt == null and GameState.junk == junk_before + 1 and GameState.money == money_before + 20, "떠날 때 안 주운 젤리·돈도 챙김")
	_check(Wearables.set_complete(&"forest", &"hunter") and Wearables.bonus_hearts(&"hunter") == 2, "숲 공터 세트 완성: 하트 +1 더")
	_check(is_equal_approx(Wearables.swing_radius(&"hunter"), 24.0) and is_equal_approx(Wearables.speed_mult(&"hunter"), 1.25), "숲지기 망토 휘두르기 범위 · 깃털 장화 걷기 +25%")
	main.hunter.position = main.supply_box.position
	var money_before_sell := GameState.money
	var junk_to_sell := GameState.junk
	main.interact()
	_check(GameState.junk == 0 and GameState.money == money_before_sell + junk_to_sell * Config.JUNK_PRICE, "사냥꾼이 공급함에서 F로 젤리를 팜")

	# 20) 디아블로식 가방 + 공용 창고 (2026-09-28 사용자 요청)
	# 지금 사냥꾼: 숲 공터 세트 다 입음, 가방에 캡모자·등산화 (주운 세트가 밀어냄)
	var hb: Array[StringName] = GameState.bag[&"hunter"]
	_check(&"ball_cap" in hb and &"hiking_shoes" in hb, "세트를 주워 입으면 입던 캡모자·등산화는 가방으로")
	main.hunter.position = Farm.center_of(Vector2i(20, 6))
	main._unhandled_input(_action(&"inventory"))
	var inv: InventoryUI = main.inventory
	_check(inv.visible and inv.character == main.hunter and main.hunter.frozen and not inv.with_stash, "I 키로 어디서나 가방 창")
	var cap_i := hb.find(&"ball_cap")
	_check(inv.primary(&"bag", cap_i) and GameState.worn[&"hunter"][&"hat"] == &"ball_cap" and &"acorn_helm" in hb, "가방 캡모자 클릭 = 입기, 도토리 투구는 가방으로 바꿔 들어감")
	_check(main.hunter._wear.size() == 3 and Wearables.set_worn_count(&"forest", &"hunter") == 2 and Wearables.bonus_hearts(&"hunter") == 0, "덧그림 바뀜 · 세트 2/3 이면 보너스 없음")
	_check(inv.primary(&"equip", 0) and not GameState.worn[&"hunter"].has(&"hat") and &"ball_cap" in hb, "입은 칸 클릭 = 벗어서 가방으로 (안 입음)")
	_check(inv.secondary(&"bag", hb.find(&"acorn_helm")) and Wearables.set_complete(&"forest", &"hunter"), "오른쪽 클릭으로도 입기, 세트 다시 완성")
	main._unhandled_input(_action(&"inventory"))
	_check(not inv.visible and not main.hunter.frozen, "I 키로 닫기")
	# 농부 장비는 사냥꾼이 입지 못함 (창고로 넘기면 농부가 꺼내 입음)
	GameState.stash.append(&"straw_hat")
	GameState.owned_wear.append(&"straw_hat")
	main.hunter.position = main.stash_box.position + Vector2(-Config.TILE + 4, 0)
	main.interact()
	_check(inv.visible and inv.with_stash, "창고 궤짝에서 F = 가방 + 창고 창")
	_check(inv.primary(&"stash", 0) and hb.back() == &"straw_hat" and GameState.stash.is_empty(), "창고 칸 클릭 = 가방으로 꺼내기")
	var before_hat: StringName = GameState.worn[&"hunter"].get(&"hat", &"")
	_check(not inv.secondary(&"bag", hb.size() - 1) and GameState.worn[&"hunter"].get(&"hat", &"") == before_hat, "농부 밀짚모자는 사냥꾼이 입지 못함")
	_check(inv.primary(&"bag", hb.size() - 1) and GameState.stash.size() == 1 and GameState.stash[0] == &"straw_hat", "창고가 열려 있으면 가방 칸 클릭 = 창고로 넣기")
	main.close_inventory()
	main._set_active(main.farmer)
	main.farmer.position = main.stash_box.position + Vector2(-Config.TILE + 4, 0)
	main.interact()
	_check(inv.visible and inv.character == main.farmer and inv.primary(&"stash", 0) and inv.secondary(&"bag", 0) and GameState.worn[&"farmer"][&"hat"] == &"straw_hat", "농부가 창고에서 꺼내 입음 (공용 창고)")
	main.close_inventory()
	# 가방이 차면 창고로, 잃어버리지 않음
	var fb: Array[StringName] = GameState.bag[&"farmer"]
	fb.clear()
	for i in Config.BAG_SIZE:
		fb.append(&"rain_boots")
	var stash_before := GameState.stash.size()
	_check(Wearables.take_off(&"farmer", &"hat") and GameState.stash.size() == stash_before + 1 and GameState.stash.back() == &"straw_hat", "가방이 차면 벗은 장비는 창고로")
	fb.clear()
	# 사냥터에서도 I, 여는 동안 사냥터는 멈춤
	GameState.hunts_today = 0
	main._set_active(main.hunter)
	main.hunter.position = main.hunt_gate.position
	main.enter_hunt()
	var h6: HuntGround = main.hunt
	main._unhandled_input(_action(&"inventory"))
	_check(inv.visible and not h6.is_processing(), "사냥터에서도 I 키 가방, 여는 동안 사냥터 멈춤")
	inv.primary(&"equip", 0)
	_check(h6.hearts <= h6.max_hearts() and h6.max_hearts() == Config.HUNTER_HEARTS, "사냥터에서 도토리 투구를 벗으면 하트 칸이 줄어듦")
	main._unhandled_input(_action(&"menu_close"))
	_check(not inv.visible and h6.is_processing(), "Esc로 닫으면 사냥터 다시 움직임")

	# 21) 장비 등급 (2026-09-28 사용자 선택 A: 디아블로2 그대로): 일반 · 마법 · 레어, 무작위 옵션, 공급함 팔기
	main.close_inventory()
	main.hunter.position = h6.spawn_at()
	main.interact()
	_check(main.hunt == null, "사냥터에서 돌아옴")
	var rr := RandomNumberGenerator.new()
	rr.seed = 11
	var counts := {&"normal": 0, &"magic": 0, &"rare": 0}
	var affix_ok := true
	for i in 3000:
		var roll := Wearables.roll_gear(rr)
		counts[roll.rarity] += 1
		var range_: Array = Config.GEAR_AFFIX_COUNT[roll.rarity]
		var stats := {}
		for a: Dictionary in roll.affixes:
			stats[a.stat] = true
			var def: Dictionary = Wearables.AFFIXES[a.stat]
			if a.value < def.min or a.value > def.max:
				affix_ok = false
		if roll.affixes.size() < range_[0] or roll.affixes.size() > range_[1] or stats.size() != roll.affixes.size():
			affix_ok = false
	_check(counts[&"normal"] > 1650 and counts[&"normal"] < 1950 and counts[&"magic"] > 830 and counts[&"magic"] < 1100 and counts[&"rare"] > 160 and counts[&"rare"] < 320, "등급 비율 약 일반 60 · 마법 32 · 레어 8 %s" % [counts])
	_check(affix_ok, "마법 옵션 1~2개 · 레어 3~4개, 같은 옵션 겹치지 않음, 수치 범위 안")
	_check(Wearables.pick_rarity(0.0) == &"normal" and Wearables.pick_rarity(60.0) == &"magic" and Wearables.pick_rarity(92.0) == &"rare", "등급 무게 경계")
	# 옵션 효과: 새로 시작한 사냥꾼에게 굴린 장비를 입힌다
	GameState.reset()
	main.hunter.refresh_wear()
	var rare := {base = &"leather_shoes", rarity = &"rare", name = "이끼 발굽", affixes = [
		{stat = &"speed", value = 20}, {stat = &"hearts", value = 1}, {stat = &"swing", value = 4}, {stat = &"money", value = 50}]}
	_check(Wearables.gain_rolled(rare) == &"worn", "칸이 비었으면 주운 등급 장비를 바로 입음")
	var rare_id: StringName = GameState.worn[&"hunter"][&"shoes"]
	_check(is_equal_approx(Wearables.speed_mult(&"hunter"), 1.2) and Wearables.bonus_hearts(&"hunter") == 1 and is_equal_approx(Wearables.swing_radius(&"hunter"), Config.SWING_RADIUS + 4.0), "레어 옵션: 걷기 +20% · 하트 +1 · 휘두르기 +4")
	_check(Wearables.describe(rare_id).contains("레어") and Wearables.describe(rare_id).contains("사냥꾼 가죽 신") and Wearables.describe(rare_id).contains("돈 드롭 +50%"), "레어 설명: 이름 · 기본 장비 · 옵션")
	var mr := RandomNumberGenerator.new()
	mr.seed = 5
	var money_roll := HuntLoot._money(mr)
	_check(money_roll.amount >= roundi(Config.HUNT_MONEY_MIN * 1.5) and money_roll.amount <= roundi(Config.HUNT_MONEY_MAX * 1.5), "돈 드롭 +50%% 옵션 (%d원)" % money_roll.amount)
	var magic := {base = &"leather_hood", rarity = &"magic", name = "보물 찾는 가죽 두건", affixes = [{stat = &"find", value = 5}]}
	_check(Wearables.gain_rolled(magic) == &"worn" and is_equal_approx(HuntLoot.loot_chance(), Config.HUNT_LOOT_CHANCE + 0.05), "드롭 확률 +5%p 옵션")
	var normal := {base = &"leather_hood", rarity = &"normal", name = "가죽 두건", affixes = []}
	_check(Wearables.gain_rolled(normal) == &"bag" and Wearables.normal_in_bag(&"hunter") == 1, "칸에 입은 게 있으면 가방으로")
	_check(Wearables.item(GameState.bag[&"hunter"][0]).effect == "꾸미기", "일반은 효과 없음")
	# 땅 이름 색
	_check(HuntLoot.color({kind = &"gear", roll = magic}) == HuntLoot.RARITY_COLORS[&"magic"] and HuntLoot.color({kind = &"gear", roll = rare}) == HuntLoot.RARITY_COLORS[&"rare"] \
		and HuntLoot.color({kind = &"gear", id = &"acorn_helm"}) == HuntLoot.RARITY_COLORS[&"set"], "땅 이름 색: 마법 파랑 · 레어 노랑 · 세트 초록")
	_check(HuntLoot.label({kind = &"gear", roll = rare}) == "이끼 발굽", "땅에 레어 이름")
	# 공급함 장비 팔기 (사냥꾼): 알·젤리가 없어도 가방에 등급 장비가 있으면 선택창
	for i in 2:
		Wearables.gain_rolled({base = &"hunter_jerkin", rarity = &"normal", name = "사냥꾼 조끼", affixes = []})
	Wearables.take_off(&"hunter", &"hat")  # 마법 두건은 가방으로
	GameState.bag[&"hunter"].append(&"ball_cap")
	GameState.owned_wear.append(&"ball_cap")
	main._set_active(main.hunter)
	main.hunter.position = main.supply_box.position
	main.interact()
	_check(main.menu_open and main.supply_options() == [&"sell_normal", &"sell_gear", &"close"], "사냥꾼 공급함 F → 일반 한꺼번에 팔기 · 가방에서 팔기 · 닫기")
	var m0 := GameState.money
	var n0 := Wearables.normal_in_bag(&"hunter")
	_check(n0 == 2 and main.supply_action(&"sell_normal") and GameState.money == m0 + n0 * Config.GEAR_SELL_PRICES[&"normal"] and Wearables.normal_in_bag(&"hunter") == 0, "일반 장비 한꺼번에 팔기 (두건 · 조끼, 첫 조끼는 빈 옷 칸에 입음)")
	_check(&"ball_cap" in GameState.bag[&"hunter"], "마을 장비는 한꺼번에 팔기에서 빠짐")
	main.menu_move(0)  # 선택창을 다시 그려 목록을 새로 받는다
	main.menu_index = main.supply_options().find(&"sell_gear")
	main.menu_confirm()
	var inv2: InventoryUI = main.inventory
	_check(inv2.visible and inv2.sell_mode and not main.menu_open, "가방에서 장비 팔기 → 팔기 창")
	var hb2: Array[StringName] = GameState.bag[&"hunter"]
	var m1 := GameState.money
	var hood_i := -1
	for i in hb2.size():
		if Wearables.is_rolled(hb2[i]):
			hood_i = i
	_check(inv2.primary(&"bag", hood_i) and GameState.money == m1 + Config.GEAR_SELL_PRICES[&"magic"] and Wearables.rolled_in_bag(&"hunter") == 0, "마법 장비 클릭 = 팔기 (20원)")
	var cap_at := hb2.find(&"ball_cap")
	_check(not inv2.primary(&"bag", cap_at) and &"ball_cap" in hb2, "마을 장비는 팔 수 없음")
	main.close_inventory()
	# 가방과 창고가 모두 차면 줍지 못하고 땅에 남음
	hb2.clear()
	for i in Config.BAG_SIZE:
		hb2.append(&"ball_cap")
	GameState.stash.clear()
	for i in Config.STASH_SIZE:
		GameState.stash.append(&"ball_cap")
	var gear_before := GameState.gear.size()
	_check(Wearables.gain_rolled({base = &"hunter_jerkin", rarity = &"normal", name = "사냥꾼 조끼", affixes = []}) == &"" and GameState.gear.size() == gear_before, "가방·창고가 다 차면 줍지 못함 (가진 것에 안 들어감)")
	hb2.clear()
	GameState.stash.clear()

	# 22) 대장 슬라임 (2026-09-28 사용자 선택 B): 셋을 다 쓰러뜨리면 대장 1마리, 대장은 반드시 하나를 떨어뜨림
	# 앞에서 입힌 "돈 드롭 +%" 옵션을 벗긴다
	GameState.worn[&"hunter"] = {}
	main.hunter.refresh_wear()
	var money_in_range := true
	var brng := RandomNumberGenerator.new()
	brng.seed = 11
	var boss_counts := {&"money": 0, &"set": 0, &"normal": 0, &"magic": 0, &"rare": 0}
	var owned_b := GameState.owned_wear.duplicate()
	for i in 3000:
		var bd := HuntLoot.roll_for_boss(brng)
		if bd.kind == &"money":
			boss_counts[&"money"] += 1
			if bd.amount < Config.BOSS_MONEY_MIN or bd.amount > Config.BOSS_MONEY_MAX:
				money_in_range = false
		elif bd.has("roll"):
			boss_counts[bd.roll.rarity] += 1
		else:
			boss_counts[&"set"] += 1
			GameState.owned_wear.append(bd.id)
	_check(money_in_range, "대장 돈 주머니 %d~%d원" % [Config.BOSS_MONEY_MIN, Config.BOSS_MONEY_MAX])
	var boss_gear: int = boss_counts[&"normal"] + boss_counts[&"magic"] + boss_counts[&"rare"]
	_check(boss_counts[&"money"] + boss_gear + boss_counts[&"set"] == 3000, "대장은 반드시 하나를 떨어뜨림")
	_check(boss_counts[&"money"] > 1650 and boss_counts[&"money"] < 1950, "대장 장비 약 40%%, 아니면 돈 %s" % [boss_counts])
	_check(boss_counts[&"set"] == 3 and boss_counts[&"magic"] > boss_gear * 0.47 and boss_counts[&"magic"] < boss_gear * 0.63 \
		and boss_counts[&"rare"] > boss_gear * 0.1 and boss_counts[&"rare"] < boss_gear * 0.2, "대장 장비 등급 약 일반 30 · 마법 55 · 레어 15, 세트 조각도 나옴")
	GameState.owned_wear = owned_b
	# 실제 사냥터: 셋을 다 쓰러뜨리면 대장이 나오고, 네 번 때려야 쓰러지고, 드롭이 반드시 떨어진다
	main.close_inventory()
	main.next_day()
	main._set_active(main.hunter)
	main.hunter.position = main.hunt_gate.position
	_check(main.enter_hunt(), "다음 날 다시 사냥터에 들어감")
	var bh: HuntGround = main.hunt
	bh.set_ai(false)
	main.hunter.facing = Vector2i.UP
	for i in Config.WILD_SLIME_COUNT:
		var bw: WildSlime = bh.slimes[0]
		_check(not bh.boss_spawned, "셋을 다 잡기 전엔 대장이 없음 (%d)" % i)
		bw.hp = 1
		bw.position = main.hunter.feet() + Vector2(0, -8 - Config.SWING_REACH)
		bh.tick(Config.SWING_COOLDOWN)
		bh.swing()
	_check(bh.boss_spawned and bh.slimes.size() == 1 and bh.slimes[0].boss and bh.slimes[0].hp == Config.BOSS_HP, "셋을 다 쓰러뜨리면 대장 슬라임 1마리 (체력 %d)" % Config.BOSS_HP)
	var bs: WildSlime = bh.slimes[0]
	_check(not bs.ai_enabled and is_equal_approx(bs.scale.x, Config.BOSS_SCALE), "대장은 크고, 멈춤 설정을 따름")
	bh.loot.clear()
	for i in Config.BOSS_HP:
		bs.position = main.hunter.feet() + Vector2(0, -8 - Config.SWING_REACH)
		bh.tick(Config.SWING_COOLDOWN)
		bh.swing()
		if i < Config.BOSS_HP - 1:
			_check(bh.slimes.size() == 1, "대장은 %d대 맞아도 버팀" % (i + 1))
	_check(bh.slimes.is_empty() and bh.loot.size() == 1, "대장을 쓰러뜨리면 반드시 하나가 떨어짐")
	_check(not bh.boss_spawned or bh.slimes.is_empty(), "대장은 사냥 한 번에 한 마리")
	bh.collect_all()
	main.leave_hunt()
	# 크리처 동행이 쓰러뜨려도 대장 드롭 (규칙은 같은 _defeat)
	var hcg := HuntGround.new()
	main.add_child(hcg)
	hcg.set_ai(false)
	var bb2 := hcg.spawn_boss()
	for s in hcg.slimes.duplicate():
		if s != bb2:
			hcg.slimes.erase(s)
			s.queue_free()
	bb2.hp = 1
	hcg._defeat(bb2)
	_check(hcg.loot.size() == 1 and hcg.slimes.is_empty(), "동행이 쓰러뜨린 것과 같은 길로도 대장 드롭")
	hcg.queue_free()

	# 23) 스테이지 사냥터 (2026-09-28 사용자 선택 B + 웨이포인트): 대장을 쓰러뜨리면 위쪽 길로 다음 구역, 웨이포인트는 도착하면 켜짐
	var z2: Dictionary = Config.HUNT_ZONES[1]
	_check(GameState.waypoints == [0], "처음엔 웨이포인트가 1구역(입구)뿐")
	main.next_day()
	main._set_active(main.hunter)
	main.hunter.position = main.hunt_gate.position
	main._hunter_interact()
	_check(not main.menu_open or main.menu_kind != &"waypoint", "웨이포인트가 하나면 시작 구역을 묻지 않음")
	if main.menu_open:
		main.close_menu()
	if main.hunt == null:
		main.enter_hunt()
	var sh: HuntGround = main.hunt
	sh.set_ai(false)
	_check(sh.zone == 0 and sh.slimes.size() == Config.WILD_SLIME_COUNT, "1구역 %s에서 시작" % Config.HUNT_ZONES[0].name)
	main.hunter.facing = Vector2i.UP
	for i in Config.WILD_SLIME_COUNT + 1:
		var sw: WildSlime = sh.slimes[0]
		_check(not sh.path_open, "대장을 쓰러뜨리기 전엔 위쪽 길이 닫힘 (%d)" % i)
		sw.hp = 1
		sw.position = main.hunter.feet() + Vector2(0, -8 - Config.SWING_REACH)
		sh.tick(Config.SWING_COOLDOWN)
		sh.swing()
	_check(sh.path_open and sh.slimes.is_empty(), "대장을 쓰러뜨리면 위쪽 길이 열림")
	main.hunter.position = Vector2(13, 8) * Config.TILE
	main.interact()
	_check(main.hunt == sh and sh.zone == 0, "위쪽 길에서 멀면 F로 넘어가지 않음")
	# 드롭이 하트 장비면 하트 칸이 바뀌므로 비교 전에 치운다
	sh.loot.clear()
	var hearts_before := sh.hearts - 1
	sh.hearts = hearts_before
	main.hunter.position = sh.next_area().get_center()
	main.interact()
	_check(sh.zone == 1 and not sh.path_open and not sh.boss_spawned, "위쪽 길에서 F → 2구역 %s" % z2.name)
	_check(sh.hearts == hearts_before and GameState.hunts_today == 1, "하트는 그대로, 같은 날 같은 사냥 (%d/%d, %d번)" % [sh.hearts, hearts_before, GameState.hunts_today])
	_check(1 in GameState.waypoints, "%s에 도착하면 웨이포인트가 켜짐" % z2.name)
	_check(sh.slimes.size() == z2.count and sh.slimes[0].hp == z2.hp and sh.slimes[0].speed == z2.speed and sh.slimes[0].title == z2.monster, "2구역 몬스터: %s 체력 %d · 빠르기 %s" % [z2.monster, z2.hp, z2.speed])
	# 금사리 (사용자 선택: 모래게 + 대장 금두꺼비, 입구에 "금사리(구터)" 회색 항아리 표지)
	var crab: WildSlime = sh.slimes[0]
	_check(crab.buried and crab.sheet.resource_path.ends_with("wild_sand_crab.png"), "모래게는 모래에 숨어 있음")
	_check(sh.sign_node != null and z2.sign == "금사리(구터)", "금사리 입구에 마을 표지")
	var hearts_c := sh.hearts
	crab.position = main.hunter.feet() + Vector2(Config.WILD_BURROW_POP_DISTANCE + 20, 0)
	sh.tick(0.01)
	_check(crab.buried, "멀면 숨은 채로")
	crab.position = main.hunter.feet() + Vector2(Config.WILD_BURROW_POP_DISTANCE - 10, 0)
	sh.tick(0.01)
	_check(not crab.buried and sh.hearts == hearts_c, "가까이 가면 모래에서 튀어나옴 (아직 안 부딪힘)")
	for i in z2.count:
		var zw: WildSlime = sh.slimes[0]
		zw.position = main.hunter.feet() + Vector2(0, -8 - Config.SWING_REACH)
		for k in z2.hp:
			sh.tick(Config.SWING_COOLDOWN)
			sh.swing()
			zw.position = main.hunter.feet() + Vector2(0, -8 - Config.SWING_REACH)
	_check(sh.boss_spawned and sh.slimes.size() == 1 and sh.slimes[0].hp == z2.boss_hp, "2구역 대장 체력 %d" % z2.boss_hp)
	_check(sh.slimes[0].title == z2.boss_monster and not sh.slimes[0].buried and sh.slimes[0].sheet.resource_path.ends_with("wild_gold_toad.png"), "금사리 대장은 %s" % z2.boss_monster)
	sh.slimes[0].hp = 1
	sh.slimes[0].position = main.hunter.feet() + Vector2(0, -8 - Config.SWING_REACH)
	sh.tick(Config.SWING_COOLDOWN)
	sh.swing()
	_check(sh.slimes.is_empty() and sh.path_open, "금사리 대장 뒤엔 2막 3구역 광동리 길이 열림")
	var toad_eggs := sh.drops.filter(func(d: Dictionary) -> bool: return d.species == CreatureCatalog.GOLD_TOAD)
	_check(toad_eggs.size() == 1, "대장 금두꺼비는 알 확률에 걸리면 금두꺼비 알을 남김")
	sh.drops.clear()
	main.hunter.position = sh.next_area().get_center()
	# 끊어진 쇠다리 (2026-09-29 "대장간과 묶기"): 대장간을 고치기 전엔 광동리로 못 건넘
	var br_state := GameState.forge_state
	GameState.forge_state = 1
	_check(sh.bridge_broken() and not sh.advance() and sh.zone == 1, "대장간을 고치기 전엔 금사리 쇠다리가 끊겨 광동리로 못 감")
	GameState.forge_state = 2
	_check(not sh.bridge_broken(), "대장간을 고치면 쇠다리가 이어짐")
	_check(sh.advance() and sh.zone == 2 and 2 in GameState.waypoints and sh.slimes[0].title == "참새", "위쪽 길로 3구역 광동리 (웨이포인트 켜짐, 참새)")
	GameState.forge_state = br_state
	main.hunter.position = sh.exit_area().get_center()
	main.interact()
	_check(main.hunt == null, "아래 입구 F로 마을로")
	# 다음 날: 사냥터 입구에서 웨이포인트를 고른다
	main.next_day()
	main.hunter.position = main.hunt_gate.position
	main._hunter_interact()
	_check(main.menu_open and main.menu_kind == &"waypoint" and main.waypoint_options() == [&"zone_0", &"zone_1", &"zone_2", &"close"], "웨이포인트가 여럿이면 어디서 시작할지 물음")
	main.menu_move(1)
	main.menu_confirm()
	if main.menu_open and main.menu_kind == &"companion":
		main.menu_index = main.companion_options().size() - 1
		main.menu_confirm()
	_check(main.hunt != null and main.hunt.zone == 1 and main.hunt.slimes[0].hp == z2.hp, "%s 웨이포인트에서 바로 시작" % z2.name)
	main.leave_hunt()
	_check(not main.enter_hunt(null, 1), "하루 한 번은 그대로")
	main.next_day()
	_check(main.enter_hunt(null, 5) and main.hunt.zone == 0, "켜지지 않은 구역은 입구에서 시작")
	main.leave_hunt()
	# 2구역 드롭: 등급 무게가 오르고, 대장 돈 주머니도 큼
	var zr := RandomNumberGenerator.new()
	zr.seed = 23
	var zc := {&"normal": 0, &"magic": 0, &"rare": 0}
	var zmoney_ok := true
	# 입은 장비의 "돈 드롭 +%" 옵션만큼 범위가 늘어난다
	var zmult := 1.0 + Wearables.stat_sum(&"hunter", "money") / 100.0
	for i in 4000:
		var zd := HuntLoot.roll_for_boss(zr, 1)
		if zd.kind == &"money":
			zmoney_ok = zmoney_ok and zd.amount >= roundi(z2.boss_money[0] * zmult) and zd.amount <= roundi(z2.boss_money[1] * zmult)
		elif zd.has("roll"):
			zc[zd.roll.rarity] += 1
	var zg: int = zc[&"normal"] + zc[&"magic"] + zc[&"rare"]
	_check(zmoney_ok, "2구역 대장 돈 주머니 %d~%d원" % z2.boss_money)
	_check(zc[&"rare"] > zg * 0.2 and zc[&"rare"] < zg * 0.3 and zc[&"normal"] < zg * 0.26, "2구역 대장 장비 등급 약 일반 20 · 마법 55 · 레어 25 %s" % [zc])
	var kind_gear := 0
	for i in 1000:
		if HuntLoot.pick_kind(i / 10.0, z2.loot) == &"gear":
			kind_gear += 1
	_check(kind_gear == z2.loot[&"gear"] * 10, "2구역 장비 몫 %d" % z2.loot[&"gear"])

	# 24. 아기 금두꺼비 (2026-09-28 사용자 선택): 땅속성만, 혀 당기기 동행, 밭에서 사금 줍기
	var trng := RandomNumberGenerator.new()
	trng.seed = 24
	var only_earth := true
	for i in 50:
		var td := CreatureData.hatch(CreatureCatalog.GOLD_TOAD, trng)
		only_earth = only_earth and td.elements.size() == 1 and td.elements[0].id == &"earth"
	_check(only_earth, "금두꺼비는 땅속성만 나옴")
	var water_el: CreatureElement = load("res://data/creatures/elements/water.tres")
	_check(not CreatureData.hatch(CreatureCatalog.GOLD_TOAD, trng).set_element(water_el), "금두꺼비에 물속성은 못 붙임")
	var toad: Creature = main._hatch(CreatureCatalog.GOLD_TOAD, Vector2i(6, 12))
	_check(toad.data.species.id == &"gold_toad" and toad.data.species.sprite_sheets.has(&"earth"), "금두꺼비 부화 (땅속성 그림)")
	_check(HuntCompanion.style_for(toad.data) == HuntCompanion.Style.PULL and HuntCompanion.style_name(toad.data) == "혀로 끌어오기", "금두꺼비 동행은 혀로 끌어오기")
	toad.job = CreatureJobs.SOW
	var money_t := GameState.money
	var night: Array = main.next_day()
	var gained := GameState.money - money_t
	_check(gained >= 5 and gained <= 15 and night.any(func(l: String) -> bool: return l.contains("사금")), "밭에서 일하는 금두꺼비는 밤마다 사금 5~15원 (+%d)" % gained)
	toad.job = CreatureJobs.REST
	money_t = GameState.money
	main.next_day()
	_check(GameState.money == money_t, "쉬는 금두꺼비는 사금을 줍지 않음")
	_check(main.enter_hunt(toad, 1) and main.hunt.companion.style == HuntCompanion.Style.PULL, "금두꺼비와 금사리로")
	var th: HuntGround = main.hunt
	th.set_ai(false)
	th.companion_ai = false
	var pc := th.companion
	main.hunter.position = Vector2(10, 7) * HuntGround.T
	pc.position = main.hunter.feet() + Vector2(0, 20)
	var pulled: WildSlime = th.slimes[0]
	pulled.buried = false
	pulled.hp = 3
	pulled.position = pc.position + Vector2(Config.COMPANION_PULL_RANGE - 10, 0)
	for other in th.slimes:
		if other != pulled:
			other.position = pc.position + Vector2(0, -Config.COMPANION_PULL_RANGE * 3)
	var hp_before := pulled.hp
	th.tick(Config.COMPANION_PULL_INTERVAL * 2)
	th.tick(Config.COMPANION_PULL_TIME)
	_check(pulled.hp == hp_before - 1 and pulled.position.distance_to(pc.position) <= Config.COMPANION_PULL_GAP + 1 and pulled.stunned(), "혀 당기기: 멀리 있는 몬스터를 끌어와 피해 1 + 멈춤")
	var hearts_t := th.hearts
	pulled.position = main.hunter.feet()
	th.tick(0.01)
	_check(th.hearts == hearts_t, "멈춘 몬스터에 닿아도 다치지 않음")
	pulled.tick(Config.COMPANION_PULL_STUN, main.hunter.feet())
	_check(not pulled.stunned(), "%.0f초 뒤 다시 움직임" % Config.COMPANION_PULL_STUN)
	main.leave_hunt()

	# 25. 넓은 맵 (2026-09-28 사용자 선택 C): 금사리는 화면보다 넓은 칸 지도 + 카메라
	main.next_day()
	_check(main.enter_hunt(null, 1), "금사리 웨이포인트로 입장")
	var wh: HuntGround = main.hunt
	wh.set_ai(false)
	var wm := wh.map
	_check(wm != null and wm.size == Vector2i(52, 30) and wm.pixel_size() == Vector2(1248, 720), "금사리는 52x30칸 (화면 2x2) 넓은 맵")
	_check(wh.camera.is_current() and wh.camera.limit_right == 1248 and wh.camera.limit_bottom == 720, "카메라가 맵 끝까지 따라감")
	_check(main.hunter.position == wm.spot("S") and wh.near_exit(), "아래 입구 앞에서 시작")
	_check(wh.slimes.size() == z2.count and wh.slimes.all(func(s: WildSlime) -> bool: return s.buried and wm.at_point(s.position) == "c"), "모래게 %d마리가 모래톱마다 숨어 있음" % z2.count)
	var hunter_w: Character = main.hunter
	hunter_w.position = Vector2(46, 26) * HuntGround.T
	wh.tick(0.01)
	await get_tree().process_frame
	var screen_center := wh.camera.get_screen_center_position()
	_check(screen_center.distance_to(Vector2(1248 - 320, 720 - 180)) < 1.0 and get_viewport().canvas_transform.origin.x < -500, "사냥꾼을 따라 화면이 움직이고 맵 끝에서 멈춤 %s %s" % [screen_center, get_viewport().canvas_transform.origin])
	# 깊은 물: 물 아래쪽 풀·모래에서 위로 걸어도 물에 못 들어감
	var shore := Vector2i(-1, -1)
	for x in range(2, 50):
		for y in range(1, 29):
			if shore.x < 0 and wm.at(Vector2i(x, y)) == "~" and wm.at(Vector2i(x - 1, y)) == "~" and wm.at(Vector2i(x + 1, y)) == "~" and wm.at(Vector2i(x, y + 1)) in [".", ","]:
				shore = Vector2i(x, y)
	hunter_w.position = Vector2(shore.x * 24 + 12, (shore.y + 1) * 24 + 12)
	for i in 30:
		hunter_w.step(Vector2(0, -2))
	_check(wm.at_point(hunter_w.feet()) != "~" and wm.is_free(hunter_w.feet_rect(hunter_w.position)), "깊은 물에는 못 들어감")
	# 징검다리: 사냥꾼은 건너고 몬스터는 못 섬
	var stones := wm.find("o")
	hunter_w.position = stones[stones.size() - 1] + Vector2(0, 24 - Character.FEET_Y)
	for i in 60:
		hunter_w.step(Vector2(0, -2))
	_check(not stones.is_empty() and hunter_w.feet().y < stones[0].y, "징검다리로 냇물을 건넘")
	_check(not wm.monster_ok(stones[0]) and wm.monster_ok(wm.spot("K")), "몬스터는 징검다리에 못 섬")
	# 여울: 걸을 수 있지만 느려짐
	var ford: Vector2 = wm.find("=")[0]
	hunter_w.active = true
	hunter_w.frozen = false
	hunter_w.position = ford - Vector2(0, Character.FEET_Y)
	Input.action_press(&"move_down")
	var y0 := hunter_w.position.y
	hunter_w._process(0.1)
	var ford_step := hunter_w.position.y - y0
	hunter_w.position = wm.spot("K")
	y0 = hunter_w.position.y
	hunter_w._process(0.1)
	var sand_step := hunter_w.position.y - y0
	Input.action_release(&"move_down")
	_check(ford_step > 0.0 and absf(ford_step / sand_step - Config.HUNT_FORD_SPEED) < 0.01, "여울에서는 걷기 %d%% (%.1f / %.1f px)" % [roundi(Config.HUNT_FORD_SPEED * 100), ford_step, sand_step])
	# 몬스터는 물을 건너 쫓아오지 않음 (여울 말고는)
	var chaser: WildSlime = wh.slimes[0]
	chaser.buried = false
	chaser.ai_enabled = true
	chaser.position = Vector2(shore.x * 24 + 12, (shore.y + 1) * 24 + 16)
	var far_bank := Vector2(chaser.position.x, shore.y * 24 - 60)
	var dry := true
	for i in 300:
		chaser.tick(0.05, far_bank)
		dry = dry and wm.monster_ok(chaser.position + Vector2(0, WildSlime.BOTTOM_Y - 2))
	_check(dry, "몬스터는 깊은 물로 뛰어들지 않음")
	chaser.ai_enabled = false
	GameState.worn[&"hunter"].erase(&"weapon")  # 드롭으로 무기를 들었으면 사냥칼로 (이 아래는 칼 휘두르기 점검)
	# 대장은 대장 모래밭에 나옴
	for s in wh.slimes.duplicate():
		s.hp = 1
		s.buried = false
		hunter_w.position = s.position - Vector2(0, -8 - Config.SWING_REACH) - Vector2(0, Character.FEET_Y)
		wh.tick(Config.SWING_COOLDOWN)
		wh.swing(Vector2.UP)
	_check(wh.boss_spawned and wh.slimes.size() == 1 and wh.slimes[0].position == wm.spot("K"), "다 잡으면 대장 %s이(가) 대장 모래밭에 나타남" % z2.boss_monster)
	hunter_w.position = wm.spot("S")
	wh.tick(0.01)
	_check(wh.near_exit(), "입구로 돌아오면 F로 나갈 수 있음")
	main.interact()
	await get_tree().process_frame
	_check(main.hunt == null and hunter_w.terrain == null and get_viewport().canvas_transform == Transform2D.IDENTITY, "마을로 돌아오면 화면이 원래대로")

	# 26. 분원농협 넓은 맵 (2026-09-28 사용자 선택 C. 창고 마당) + 작은 지도 (추천 M2: 가 본 곳만 보임)
	main.next_day()
	var z1: Dictionary = Config.HUNT_ZONES[0]
	_check(main.enter_hunt(null, 0), "분원농협으로 입장")
	var nh: HuntGround = main.hunt
	nh.set_ai(false)
	var nm := nh.map
	var hunter_n: Character = main.hunter
	_check(nh.zone == 0 and nm != null and z1.map == "nonghyup" and nm.size == Vector2i(52, 30), "분원농협도 52x30칸 (화면 2x2) 넓은 맵")
	_check(hunter_n.position == nm.spot("S") and nh.near_exit(), "아래 입구 앞에서 시작")
	_check(nh.slimes.size() == Config.WILD_SLIME_COUNT and nh.slimes.all(func(s: WildSlime) -> bool: return not s.buried and nm.at_point(s.position) == "c"), "야생 슬라임 %d마리가 마당·논밭에 흩어져 있음" % Config.WILD_SLIME_COUNT)
	_check(nm.find("H").size() > 100 and nm.find("F").size() > 30 and nm.find("s").size() > 5 and nm.find("m").size() > 10, "창고 · 철망 · 쌀 포대 · 멍석이 있음")
	_check((z1.labels as Array).any(func(l: Array) -> bool: return l[1] == "분원농협" and nm.at_point(Vector2(l[0]) * HuntGround.T) == "H"), "창고 벽에 분원농협 간판")
	# 창고: 마당에서 창고 벽 쪽으로 걸어도 못 들어감
	var wall := Vector2i(-1, -1)
	for x in range(2, 50):
		if wall.x < 0 and nm.at(Vector2i(x, 22)) == "H" and nm.at(Vector2i(x, 23)) == "%":
			wall = Vector2i(x, 22)
	hunter_n.position = Vector2(wall.x * 24 + 12, 24 * 24 + 12)
	for i in 30:
		hunter_n.step(Vector2(0, -2))
	_check(wall.x > 0 and nm.at_point(hunter_n.feet()) != "H" and hunter_n.feet().y > 23 * 24, "창고 안으로는 못 들어감")
	# 철망: 울타리는 막히고, 철망 문으로는 지나감
	var fence_x := -1
	var gate_x := -1
	for x in range(2, 50):
		if nm.at(Vector2i(x, 15)) == "F" and nm.at(Vector2i(x, 14)) == "." and nm.at(Vector2i(x, 16)) == "%" and fence_x < 0:
			fence_x = x
		if nm.at(Vector2i(x, 15)) == "%" and gate_x < 0:
			gate_x = x
	hunter_n.position = Vector2(fence_x * 24 + 12, 16 * 24 + 18 - Character.FEET_Y)
	var fence_free := nm.is_free(hunter_n.feet_rect(hunter_n.position))
	for i in 40:
		hunter_n.step(Vector2(0, -2))
	_check(fence_x > 0 and fence_free and hunter_n.feet().y > 16 * 24, "철망 울타리는 못 넘음")
	hunter_n.position = Vector2(gate_x * 24 + 12, 16 * 24 + 18 - Character.FEET_Y)
	for i in 40:
		hunter_n.step(Vector2(0, -2))
	_check(gate_x > 0 and hunter_n.feet().y < 15 * 24, "철망 문으로는 논밭 쪽으로 나감")
	# 논: 걸을 수 있지만 사냥꾼만 느려짐
	var paddy := Vector2(-1, -1)
	for p in nm.find("p"):
		if paddy.x < 0 and nm.at_point(p + Vector2(0, 24)) == "p" and nm.at_point(p - Vector2(0, 24)) == "p":
			paddy = p
	hunter_n.active = true
	hunter_n.frozen = false
	hunter_n.position = paddy - Vector2(0, Character.FEET_Y)
	Input.action_press(&"move_down")
	var py0 := hunter_n.position.y
	hunter_n._process(0.1)
	var paddy_step := hunter_n.position.y - py0
	hunter_n.position = nm.spot("S") - Vector2(0, 24 * 3)
	py0 = hunter_n.position.y
	hunter_n._process(0.1)
	var yard_step := hunter_n.position.y - py0
	Input.action_release(&"move_down")
	_check(paddy_step > 0.0 and absf(paddy_step / yard_step - Config.HUNT_PADDY_SPEED) < 0.01, "논에서는 걷기 %d%% (%.1f / %.1f px)" % [roundi(Config.HUNT_PADDY_SPEED * 100), paddy_step, yard_step])
	_check(nm.monster_ok(paddy) and not nm.monster_ok(nm.find("s")[0]) and not nm.monster_ok(nm.find("F")[0]), "슬라임은 논에 들어가고, 쌀 포대·철망에는 못 감")
	# 작은 지도: 들어온 곳 둘레만 보이고, 걸어간 곳이 늘어남
	hunter_n.position = nm.spot("S")
	nh._reset_minimap()
	var k_cell := Vector2i(nm.spot("K") / 24)
	var n_cell := Vector2i(nm.spot("N") / 24)
	var s_cell := Vector2i(nm.spot("S") / 24)
	var r := nh.minimap_rect()
	_check(nh.minimap_seen(s_cell) and not nh.minimap_seen(k_cell) and not nh.minimap_seen(n_cell), "작은 지도: 처음엔 입구 둘레만 보임")
	_check(r.size == Vector2(104, 60) and r.position.y >= 48 and r.end.x <= 640, "작은 지도는 오른쪽 위 구석 %s" % r)
	hunter_n.position = nm.spot("K")
	nh.tick(0.01)
	_check(nh.minimap_seen(k_cell) and not nh.minimap_seen(n_cell), "대장 자리까지 가 보면 그곳이 지도에 드러남")
	GameState.worn[&"hunter"].erase(&"weapon")  # 드롭으로 무기를 들었으면 사냥칼로 (이 아래는 칼 휘두르기 점검)
	# 대장은 곳간 앞, 위쪽 길로 금사리
	for s in nh.slimes.duplicate():
		s.hp = 1
		hunter_n.position = s.position - Vector2(0, -8 - Config.SWING_REACH) - Vector2(0, Character.FEET_Y)
		nh.tick(Config.SWING_COOLDOWN)
		nh.swing(Vector2.UP)
	_check(nh.boss_spawned and nh.slimes.size() == 1 and nh.slimes[0].position == nm.spot("K"), "다 잡으면 %s이(가) 곳간 앞에 나타남" % z1.boss_monster)
	var nboss: WildSlime = nh.slimes[0]
	nboss.hp = 1
	hunter_n.position = nboss.position - Vector2(0, -8 - Config.SWING_REACH) - Vector2(0, Character.FEET_Y)
	nh.tick(Config.SWING_COOLDOWN)
	nh.swing(Vector2.UP)
	nh.loot.clear()
	hunter_n.position = nm.spot("N") + Vector2(0, 30)
	nh.tick(0.01)
	_check(nh.path_open and nh.near_next() and nh.minimap_seen(n_cell), "대장을 잡으면 위쪽 길이 열리고, 지도에도 위쪽 길이 보임")
	main.interact()
	_check(nh.zone == 1 and nh.map.size == Vector2i(52, 30) and nh.minimap_seen(Vector2i(nh.map.spot("S") / 24)) and not nh.minimap_seen(Vector2i(nh.map.spot("K") / 24)), "금사리로 넘어가면 작은 지도가 새로 가려짐")
	main.leave_hunt()
	main.next_day()
	_check(main.enter_hunt(null, 0), "다음 날 다시 분원농협")
	_check(not main.hunt.minimap_seen(k_cell), "다음 사냥에서는 작은 지도가 다시 가려짐")
	main.leave_hunt()

	# 28) 알 드롭률 (2026-09-29 사용자: 너무 잘 나와서 낮춤): 확률에 안 걸리면 대장도 알을 남기지 않음
	HuntGround.egg_roll = 0.99
	var hz := HuntGround.new()
	main.add_child(hz)
	hz.zone = 1
	hz.set_ai(false)
	var toad_b := hz.spawn_boss()
	toad_b.hp = 1
	hz._defeat(toad_b)
	_check(hz.drops.is_empty(), "확률에 안 걸리면 대장 금두꺼비도 알을 남기지 않음")
	var egg_zc: float = Config.HUNT_ZONES[1].egg_chance
	var egg_bc: float = Config.HUNT_ZONES[1].boss_egg_chance
	_check(egg_zc < 0.1 and egg_bc < 0.5, "금사리 알 확률: 몬스터 %d%% · 대장 %d%%" % [roundi(egg_zc * 100), roundi(egg_bc * 100)])
	hz.queue_free()
	HuntGround.egg_roll = -1.0

	# 27) 아침 카드: 밤사이 일이 많아도 "F 일어나기"까지 카드 안에 들어온다 (핵심 루프 점검 2026-09-28)
	var busy: Array[String] = []
	for i in 7:
		busy.append("알이 부화했다! 아기 금두꺼비 [쉬는 중] 땅 · 속도 1.54 / 범위 1 / 부지런함")
	main.show_morning_card(busy)
	var mcard: Control = main._morning_card
	var mfont: Font = main._morning_text.get_theme_font("font")
	var need: float = mfont.get_multiline_string_size(main._morning_text.text, HORIZONTAL_ALIGNMENT_CENTER, mcard.size.x - 24, 10).y
	_check(mcard.size.y > Config.TILE * 6 and main._morning_text.size.y >= need and mcard.position.y >= 0 and mcard.get_rect().end.y <= 360, "밤사이 일이 많으면 아침 카드가 늘어나 글이 넘치지 않음")
	main.show_morning_card([] as Array[String])
	_check(mcard.size.y == main.MORNING_CARD_SIZE.y, "조용한 밤에는 아침 카드가 원래 크기")
	mcard.visible = false

	# 29) 크리처 훈련 (2026-09-29 사용자 선택 A, 돈 쓸 곳 2단계): 공급함에서 크리처마다 범위·속도, 값은 단계마다 두 배
	main._set_active(farmer)
	farmer.position = main.supply_box.position + Vector2(0, 16)
	var tr: Creature = main.creatures[0]
	tr.data.radius_level = 0
	tr.data.speed_level = 0
	_check(main.supply_options().has(&"train"), "크리처가 있으면 공급함에 크리처 훈련")
	var r0 := tr.data.work_radius()
	var sp0 := tr.data.work_speed(CreatureJobs.WATER)
	GameState.money = Config.TRAIN_PRICES[0] - 1
	_check(not main.train(tr, &"radius") and tr.data.radius_level == 0, "돈이 모자라면 훈련 못 함")
	GameState.money = 10000
	_check(main.train(tr, &"radius") and tr.data.work_radius() == r0 + 1 and GameState.money == 10000 - Config.TRAIN_PRICES[0], "범위 훈련 1단계: 범위 +1")
	_check(main.train_price(tr, &"radius") == Config.TRAIN_PRICES[0] * 2, "다음 단계 값은 두 배")
	_check(main.train(tr, &"speed") and is_equal_approx(tr.data.work_speed(CreatureJobs.WATER), sp0 * (1.0 + Config.TRAIN_SPEED_STEP)), "속도 훈련 1단계: 일 속도 +25%")
	for i in Config.TRAIN_PRICES.size() - 1:
		main.train(tr, &"radius")
	_check(tr.data.radius_level == Config.TRAIN_PRICES.size() and main.train_price(tr, &"radius") == -1 and not main.train(tr, &"radius"), "범위는 최대 단계까지만")
	var topt: Array[StringName] = main.train_options()
	_check(not topt.has(&"train_0_radius") and topt.has(&"train_0_speed") and topt[-1] == &"back", "다 올린 능력은 훈련 목록에서 빠짐")
	_check(tr.describe().contains("훈련"), "크리처 설명에 훈련 단계")
	# 선택창: 공급함 → 크리처 훈련 → 한 줄 고르면 돈이 나가고 창은 그대로
	main.close_menu()
	main.open_menu()
	main.menu_index = main.supply_options().find(&"train")
	main.menu_confirm()
	_check(main.menu_open and main.menu_kind == &"train" and main._menu_text.text.contains("크리처 훈련"), "공급함 크리처 훈련 → 훈련 선택창")
	var m_before := GameState.money
	main.menu_index = main.train_options().find(&"train_0_speed")
	main.menu_confirm()
	_check(GameState.money == m_before - Config.TRAIN_PRICES[1] and tr.data.speed_level == 2 and main.menu_kind == &"train", "훈련 선택창에서 속도 2단계")
	main.menu_index = main.train_options().size() - 1
	main.menu_confirm()
	_check(main.menu_open and main.menu_kind == &"supply", "뒤로 → 공급함 선택창")
	main.close_menu()
	# 동행도 속도 훈련만큼 공격이 빨라진다
	var comp_t := HuntCompanion.new()
	comp_t.data = tr.data
	var fast := comp_t.attack_interval()
	tr.data.speed_level = 0
	_check(fast < comp_t.attack_interval() or is_equal_approx(fast, comp_t.attack_interval()), "속도 훈련은 동행 공격 간격도 줄임 (최대 두 배 제한 안에서)")
	comp_t.free()

	# 30) 사냥 난이도 (2026-09-29 사용자: 후보 A·B·C 셋 다). A 달려들기 · B 금사리 세기 · C 대장 패턴
	if main.hunt:
		main.leave_hunt()
	main.close_menu()
	main._set_active(main.hunter)
	GameState.hunts_today = 0
	if not 1 in GameState.waypoints:
		GameState.waypoints.append(1)
	main.enter_hunt(null, 0)
	GameState.worn[&"hunter"].erase(&"weapon")  # 드롭으로 무기를 들었으면 사냥칼로 (이 아래는 칼 휘두르기 점검)
	var d_dh: HuntGround = main.hunt
	d_dh.set_ai(false)
	var d_hf: Vector2 = main.hunter.feet()
	var d_lw: WildSlime = d_dh.slimes[0]
	for o: WildSlime in d_dh.slimes:
		o.position = d_hf + Vector2(0, 300)
	d_lw.position = d_hf + Vector2(40, 0)
	d_lw.ai_enabled = true
	var d_h0 := d_dh.hearts
	d_dh.tick(0.05)
	var d_tg := d_lw.telegraph()
	_check(not d_tg.is_empty() and d_tg.kind == &"lane" and d_dh.hearts == d_h0, "A. 가까이 오면 웅크리고 붉은 띠로 예고 (아직 안 맞음)")
	d_dh.swing(Vector2.RIGHT)
	_check(not d_lw.telegraph().is_empty(), "A. 웅크리는 중엔 맞아도 달려들기가 멈추지 않음")
	for i in 30:
		d_dh.tick(1.0 / 30.0)
	_check(d_dh.hearts == d_h0 - 1 and d_lw.recovering(), "A. 띠 위에 서 있으면 돌진에 맞고, 몬스터는 헐떡임 (하트 %d → %d)" % [d_h0, d_dh.hearts])
	# 비켜서면 안 맞는다
	d_dh._invulnerable = 0.0
	d_lw.hp = 99
	for i in 60:
		d_dh.tick(1.0 / 30.0)
		if not d_lw.telegraph().is_empty():
			break
	d_lw.position = main.hunter.feet() + Vector2(40, 0)
	d_lw._lunge_dir = Vector2.LEFT
	var d_h1 := d_dh.hearts
	main.hunter.position += Vector2(0, 40)
	for i in 25:
		d_dh.tick(1.0 / 30.0)
	_check(d_dh.hearts == d_h1, "A. 예고를 보고 옆으로 비키면 안 맞음")
	main.leave_hunt()
	# B. 금사리: 하트 -2, 무리로 튀어나옴
	GameState.hunts_today = 0
	main.enter_hunt(null, 1)
	var d_gh: HuntGround = main.hunt
	d_gh.set_ai(false)
	var d_z2d: Dictionary = Config.HUNT_ZONES[1]
	_check(d_z2d.damage == 2 and d_gh.slimes[0].damage == 2 and d_gh.slimes[0].hp == d_z2d.hp and d_z2d.hp > Config.HUNT_ZONES[0].hp, "B. 금사리는 체력 %d · 하트 -%d" % [d_z2d.hp, d_z2d.damage])
	_check(main.waypoint_option_text(&"zone_1").contains(d_z2d.advice), "B. 웨이포인트 메뉴에 권장 준비")
	var d_gf: Vector2 = main.hunter.feet()
	for o: WildSlime in d_gh.slimes:
		o.buried = true
		o.position = d_gf + Vector2(0, 400)
	var d_pa: WildSlime = d_gh.slimes[0]
	var d_pb: WildSlime = d_gh.slimes[1]
	d_pa.position = d_gf + Vector2(50, 0)
	d_pb.position = d_gf + Vector2(50 + Config.WILD_PACK_DISTANCE - 10, 0)
	d_gh.tick(0.01)
	_check(not d_pa.buried and not d_pb.buried and d_gh.slimes[2].buried, "B. 하나가 튀어나오면 근처 모래게도 무리로 튀어나옴 (먼 것은 그대로)")
	var d_h2 := d_gh.hearts
	d_pa.position = d_gf
	d_gh.tick(0.01)
	_check(d_gh.hearts == d_h2 - 2, "B. 모래게에 부딪히면 하트 -2")
	# C. 금두꺼비 혀 채찍 + 금가루
	d_gh._invulnerable = 0.0
	d_gh.hearts = d_gh.max_hearts()
	for o: WildSlime in d_gh.slimes.duplicate():
		o.hp = 1
		d_gh._defeat(o)
	var d_toad_b: WildSlime = d_gh._boss()
	_check(d_toad_b != null and d_toad_b.pattern == &"tongue" and d_toad_b.hp == d_z2d.boss_hp, "C. 금두꺼비 대장 (혀 채찍, 체력 %d)" % d_z2d.boss_hp)
	d_toad_b.ai_enabled = true
	d_toad_b._pattern_cd = 0.0
	main.hunter.position = d_toad_b.position + Vector2(60, 0) - Vector2(0, main.hunter.feet().y - main.hunter.position.y)
	var d_h3 := d_gh.hearts
	d_gh.tick(0.02)
	_check(not d_toad_b.telegraph().is_empty() and d_gh.hearts == d_h3, "C. 혀 채찍 예고 (직선 띠)")
	for i in int(Config.TONGUE_WINDUP * 30) + 3:
		d_gh.tick(1.0 / 30.0)
	_check(d_gh.hearts == d_h3 - d_z2d.damage and d_gh.dust.size() == 3, "C. 혀에 맞으면 하트 -%d, 지나간 자리에 금가루 3곳" % d_z2d.damage)
	main.hunter.position += d_gh.dust[0].at - main.hunter.feet()
	d_gh.tick(0.01)
	_check(is_equal_approx(main.hunter.slow_mult, Config.GOLD_DUST_SLOW), "C. 금가루를 밟으면 느려짐")
	main.leave_hunt()
	_check(is_equal_approx(main.hunter.slow_mult, 1.0), "C. 사냥터를 나오면 빠르기 원래대로")
	# C. 대장 슬라임 내려찍기 + 새끼
	GameState.hunts_today = 0
	main.enter_hunt(null, 0)
	var d_bh2: HuntGround = main.hunt
	d_bh2.set_ai(false)
	for o: WildSlime in d_bh2.slimes.duplicate():
		o.hp = 1
		d_bh2._defeat(o)
	var d_sb: WildSlime = d_bh2._boss()
	d_sb.ai_enabled = true
	d_sb._pattern_cd = 0.0
	main.hunter.position = d_sb.position + Vector2(0, 80)
	var d_h4 := d_bh2.hearts
	d_bh2.tick(0.02)
	_check(d_sb.airborne() and d_sb.telegraph().kind == &"circle", "C. 대장 슬라임이 뛰어올라 사냥꾼 발밑에 그림자 원")
	var d_sb_hp := d_sb.hp
	d_sb.position = main.hunter.feet() + Vector2(0, -8 - Config.SWING_REACH)
	d_bh2._cooldown = 0.0
	d_bh2.swing(Vector2.UP)
	_check(d_sb.hp == d_sb_hp, "C. 공중에 뜬 대장은 칼에 안 맞음")
	for i in int(Config.SLAM_AIR_TIME * 30) + 3:
		d_bh2.tick(1.0 / 30.0)
	var d_minions := d_bh2.slimes.filter(func(o: WildSlime) -> bool: return o.minion)
	_check(d_bh2.hearts == d_h4 - 1 and d_minions.size() == Config.SLAM_MINIONS and d_sb.recovering(), "C. 쿵! 원 안이면 하트 -1, 새끼 %d마리, 대장은 헐떡임" % Config.SLAM_MINIONS)
	var d_drops_before := d_bh2.drops.size() + d_bh2.loot.size()
	d_minions[0].hp = 1
	d_bh2._defeat(d_minions[0])
	_check(d_bh2.drops.size() + d_bh2.loot.size() == d_drops_before and d_bh2._boss() == d_sb, "C. 새끼는 알·드롭을 남기지 않음")
	main.leave_hunt()

	# 31) 들나물 캐기 (2026-09-29 사용자 선택 A, 초반 며칠 할 일): 아침마다 풀밭에 돋고, F로 캐서 공급함에 진열 → 밤사이 팔림
	main._set_active(main.farmer)
	var h_forage: Forage = main.forage
	var h_bad: Array[Vector2i] = []
	for spot in Config.HERB_SPOTS:
		# 대장간 터 · 고물 더미가 들어선 자리는 쓰지 않는다 (Forage.blocked)
		if main.forage.blocked.any(func(r: Rect2i) -> bool: return r.has_point(spot)):
			continue
		var stand := Farm.center_of(spot) - Vector2(0, main.farmer.FEET_Y)
		var h_inside: bool = main.farm.get_cell(spot) != null or main.farm._path.has(spot) or main.farm._fence.has(spot) or spot.y < 1 or spot.y > 12
		for p: Prop in main.props:
			if p.footprint_rect().has_point(Farm.center_of(spot) - p.position):
				h_inside = true
		if h_inside or not main.farm.is_free(main.farmer.feet_rect(stand)):
			h_bad.append(spot)
	_check(h_bad.is_empty(), "들나물 자리는 모두 밭·길·울타리·오브젝트 밖, 서서 캘 수 있는 풀밭 %s" % [h_bad])
	main.next_day()
	var h_n: int = h_forage.herbs.size()
	_check(h_n >= Config.HERBS_PER_DAY.x and h_n <= Config.HERBS_PER_DAY.y, "아침마다 들나물 %d~%d포기가 돋음 (%d)" % [Config.HERBS_PER_DAY.x, Config.HERBS_PER_DAY.y, h_n])
	for s: Creature in main.creatures:
		s.position = Vector2(-500, -500)
	GameState.herbs = 0
	for spot: Vector2i in h_forage.herbs.keys():
		main.farmer.position = Farm.center_of(spot) - Vector2(0, main.farmer.FEET_Y) + Vector2(10, 0)
		main.interact()
	_check(GameState.herbs == h_n and h_forage.herbs.is_empty(), "농부가 가까이서 F로 캠 (들나물 %d)" % GameState.herbs)
	main.farmer.position = main.supply_box.position
	_check(main.supply_options().has(&"display_herbs") and main.supply_option_text(&"display_herbs").contains("%d원" % (h_n * Config.HERB_PRICE)), "공급함에 들나물 진열하기")
	_check(main.supply_action(&"display_herbs") and GameState.herbs == 0 and GameState.displayed_herbs == h_n, "들나물 진열")
	var h_money := GameState.money
	var h_lines: Array[String] = main.next_day()
	_check(GameState.money - h_money >= h_n * Config.HERB_PRICE and GameState.displayed_herbs == 0 and " ".join(h_lines).contains("들나물 %d포기가 팔렸다" % h_n), "밤사이 팔려 아침에 +%d원" % (h_n * Config.HERB_PRICE))
	_check(not h_forage.herbs.is_empty() and " ".join(h_lines).contains("들나물"), "다음 날 아침 새로 돋음")
	_check(Forage.object_particle("쑥") == "을" and Forage.object_particle("냉이") == "를", "들나물 이름에 맞는 조사 (쑥을 · 냉이를)")
	main._set_active(main.hunter)
	main.hunter.position = Farm.center_of(h_forage.herbs.keys()[0]) - Vector2(0, main.hunter.FEET_Y)
	var h_before: int = h_forage.herbs.size()
	main.interact()
	_check(h_forage.herbs.size() == h_before, "사냥꾼은 들나물을 캐지 않음 (농부 일)")
	main._set_active(main.farmer)

	# 32) 하루 시계 (2026-09-29 사용자: 시간은 아주 여유 있게, 막지 않고, 자야 하루가 넘어감)
	main.next_day()
	_check(is_equal_approx(GameState.minutes, Config.DAY_START_MINUTE) and main._status.text.contains("오전 6:00"), "아침 6시에 시작, 위 줄에 시계")
	main.advance_clock(8 * 60 + 40)
	_check(main._status.text.contains("오후 2:40") and is_zero_approx(main._dusk.color.a), "시계가 흐름 (오후 2:40), 낮엔 안 어두움")
	main.advance_clock(8 * 60)
	_check(main._status.text.contains("밤 10:40") and is_equal_approx(main._dusk.color.a, Config.DUSK_ALPHA), "밤이 되면 조금 어두워짐")
	var c_day := GameState.day
	main.advance_clock(24 * 60)
	_check(GameState.day == c_day and is_equal_approx(GameState.minutes, Config.CLOCK_MAX_MINUTE) and main._status.text.contains("새벽 2:00"), "새벽 2시에서 멈추고 하루는 안 넘어감")
	var c_cell: Farm.Cell = main.farm.get_cell(Vector2i(2, 3))
	c_cell.planted = false
	c_cell.tilled = false
	_check(main.farm.do_work(Farm.Work.TILL, Vector2i(2, 3)), "새벽에도 도구질은 됨 (막지 않음)")
	main.next_day()
	_check(GameState.day == c_day + 1 and is_equal_approx(GameState.minutes, Config.DAY_START_MINUTE) and is_zero_approx(main._dusk.color.a), "자고 나면 다음 날 아침 6시")
	main.advance_clock(3 * 60)
	main.open_menu()
	var c_min := GameState.minutes
	main._process(5.0)
	_check(is_equal_approx(GameState.minutes, c_min), "선택창을 연 동안은 시계가 멈춤")
	main.close_menu()
	main._process(5.0)
	_check(is_equal_approx(GameState.minutes, c_min + 5.0 * Config.CLOCK_MINUTES_PER_SECOND), "닫으면 다시 흐름 (실제 1초 = 게임 %s분)" % Config.CLOCK_MINUTES_PER_SECOND)

	# 33) 크리처 채집 (2026-09-29 사용자 선택 B 속성별 채집): 채집 크리처가 풀밭 나물을 캐서 공급함에 바로 진열.
	#     땅속성은 손으로 못 캐는 도라지 뿌리도 캐고, 물속성은 캔 자리에 물을 줘서 다음 날 나물이 더 돋는다.
	var f_forage: Forage = main.forage
	var f_bad: Array[Vector2i] = []
	for spot in Config.ROOT_SPOTS:
		# 대장간 터 · 고물 더미가 들어선 자리는 쓰지 않는다 (Forage.blocked)
		if main.forage.blocked.any(func(r: Rect2i) -> bool: return r.has_point(spot)):
			continue
		var stand := Farm.center_of(spot) - Vector2(0, main.farmer.FEET_Y)
		var f_inside: bool = main.farm.get_cell(spot) != null or main.farm._path.has(spot) or main.farm._fence.has(spot) or spot.y < 1 or spot.y > 12 or spot in Config.HERB_SPOTS
		for p: Prop in main.props:
			if p.footprint_rect().has_point(Farm.center_of(spot) - p.position):
				f_inside = true
		if f_inside or not main.farm.is_free(main.farmer.feet_rect(stand)):
			f_bad.append(spot)
	_check(f_bad.is_empty(), "도라지 자리는 모두 들나물 자리와 겹치지 않는 풀밭 %s" % [f_bad])
	for s: Creature in main.creatures:
		s.queue_free()
	main.creatures.clear()
	main.next_day()
	var f_roots := f_forage.roots.size()
	_check(f_roots >= Config.ROOTS_PER_DAY.x and f_roots <= Config.ROOTS_PER_DAY.y, "아침마다 땅속에 도라지 %d~%d뿌리 (%d)" % [Config.ROOTS_PER_DAY.x, Config.ROOTS_PER_DAY.y, f_roots])
	main._set_active(main.farmer)
	var f_root_cell: Vector2i = f_forage.roots.keys()[0]
	main.farmer.position = Farm.center_of(f_root_cell) - Vector2(0, main.farmer.FEET_Y) + Vector2(10, 0)
	for f_cell: Vector2i in f_forage.herbs.keys():
		if Farm.center_of(f_cell).distance_to(main.farmer.feet()) <= Config.INTERACT_DISTANCE:
			f_forage.herbs.erase(f_cell)
	main.interact()
	_check(f_forage.roots.has(f_root_cell) and main._message.text.contains("손으로는 못 캔다"), "농부는 도라지를 손으로 못 캠 (알려 줌)")
	_check(CreatureJobs.FARM_JOBS.has(CreatureJobs.FORAGE) and CreatureJobs.display_name(CreatureJobs.FORAGE) == "채집", "크리처 일 목록(R)에 채집")
	var f_water: Creature = main._hatch(CreatureCatalog.SLIME, Vector2i(3, 12))
	f_water.data.set_element(load("res://data/creatures/elements/water.tres"))
	var f_earth: Creature = main._hatch(CreatureCatalog.SLIME, Vector2i(8, 12))
	f_earth.data.set_element(load("res://data/creatures/elements/earth.tres"))
	for s: Creature in [f_water, f_earth]:
		s.auto_work = false
		while s.job != CreatureJobs.FORAGE:
			s.next_job()
	f_earth.queue_redraw()
	var f_herbs := f_forage.herbs.size()
	GameState.displayed_herbs = 0
	GameState.displayed_roots = 0
	Engine.time_scale = 20.0
	for i in 400:
		var f_any := false
		for s: Creature in [f_water, f_earth]:
			if s._busy or s.work_once():
				f_any = true
		if not f_any:
			break
		await get_tree().process_frame
	Engine.time_scale = 1.0
	_check(f_forage.herbs.is_empty() and GameState.displayed_herbs == f_herbs, "채집 크리처 둘이 나물 %d포기를 모두 캐서 공급함에 진열" % f_herbs)
	_check(f_forage.roots.is_empty() and GameState.displayed_roots == f_roots, "땅속성은 도라지 %d뿌리도 캠" % f_roots)
	_check(f_forage.claimed.is_empty() and f_water.position.distance_to(Farm.center_of(f_water.home)) < 1.0, "할 일이 없으면 제자리로 돌아감")
	_check(not f_forage.watered.is_empty(), "물속성은 캔 자리 풀밭에 물을 줌 (%d칸)" % f_forage.watered.size())
	main._refresh_props()
	_check(main.supply_box.badge.contains("도라지 %d" % f_roots) and main.supply_box.badge.contains("나물 %d" % f_herbs), "공급함 표시에 진열한 나물·도라지")
	var f_bonus := mini(f_forage.watered.size(), Config.HERB_WATER_BONUS_MAX)
	var f_money := GameState.money
	var f_lines: Array[String] = main.next_day()
	var f_text := " ".join(f_lines)
	_check(GameState.money - f_money >= f_herbs * Config.HERB_PRICE + f_roots * Config.ROOT_PRICE and f_text.contains("도라지 %d뿌리가 팔렸다" % f_roots), "밤사이 나물·도라지가 팔림 (도라지 한 뿌리 %d원)" % Config.ROOT_PRICE)
	_check(f_forage.bonus_today == f_bonus and f_forage.herbs.size() >= Config.HERBS_PER_DAY.x + f_bonus and f_text.contains("물 준 풀밭 +%d" % f_bonus), "물 준 풀밭 덕분에 다음 날 나물 +%d포기" % f_bonus)
	_check(f_forage.watered.is_empty(), "물 준 표시는 하루 지나면 사라짐")
	# 쉬는 중이면 채집하지 않음
	f_earth.job = CreatureJobs.REST
	_check(not f_earth.work_once(), "쉬는 크리처는 채집하지 않음")

	# 34) 크리처 일 배분 (2026-09-29 사용자 선택 A+B): 파종·급수·수확을 "농사" 하나로 합침.
	#     농사 크리처는 범위 안 밭을 수확 → 파종 → 급수 순으로 다 돌보고, 밭에 할 일이 없으면 풀밭으로 채집하러 간다.
	_check(CreatureJobs.FARM_JOBS == [CreatureJobs.REST, CreatureJobs.FARM, CreatureJobs.FORAGE], "R 일 목록: 쉬는 중 → 농사 → 채집")
	for s: Creature in main.creatures:
		s.queue_free()
	main.creatures.clear()
	main.next_day()
	var j_home := Vector2i(4, 4)
	var j: Creature = main._hatch(CreatureCatalog.SLIME, j_home)
	j.data.set_element(load("res://data/creatures/elements/earth.tres"))
	j.auto_work = false
	while j.job != CreatureJobs.FARM:
		j.next_job()
	# 범위 안: 익은 칸 하나, 갈아 둔 빈 칸 하나, 심고 물 안 준 칸 하나. 나머지 칸은 다 심고 물 줌.
	var j_ripe := j_home + Vector2i.LEFT
	var j_empty := j_home + Vector2i.RIGHT
	var j_dry := j_home + Vector2i.UP
	var j_r := j.data.work_radius()
	for dx in range(-j_r, j_r + 1):
		for dy in range(-j_r, j_r + 1):
			var jc: Farm.Cell = main.farm.get_cell(j_home + Vector2i(dx, dy))
			if jc == null:
				continue
			jc.tilled = true
			jc.planted = true
			jc.watered = true
			jc.growth = 1
	var j_rc: Farm.Cell = main.farm.get_cell(j_ripe)
	j_rc.growth = Config.CROP_GROW_DAYS
	j_rc.watered = false
	var j_ec: Farm.Cell = main.farm.get_cell(j_empty)
	j_ec.planted = false
	j_ec.watered = false
	j_ec.growth = 0
	main.farm.get_cell(j_dry).watered = false
	GameState.seeds = 5
	var j_order: Array[StringName] = []
	Engine.time_scale = 20.0
	for i in 3:
		_check(j.work_once(), "농사 크리처가 밭 일 찾음 %d" % i)
		j_order.append(j.task)
		while j._busy:
			await get_tree().process_frame
	Engine.time_scale = 1.0
	_check(j_order == [CreatureJobs.HARVEST, CreatureJobs.SOW, CreatureJobs.SOW], "수확 먼저, 그다음 빈 칸 파종 (수확한 칸 포함) %s" % [j_order])
	_check(main.farm.get_cell(j_ripe).planted and main.farm.get_cell(j_empty).planted, "익은 칸 거두고 빈 칸에 심음")
	var j_wet := 0
	Engine.time_scale = 20.0
	while j.work_once() and j.task == CreatureJobs.WATER:
		j_wet += 1
		while j._busy:
			await get_tree().process_frame
	Engine.time_scale = 1.0
	_check(j_wet == 3 and main.farm.get_cell(j_dry).watered, "그다음 마른 칸에 물 (%d칸)" % j_wet)
	_check(is_equal_approx(j.data.work_speed(CreatureJobs.SOW), j.data.work_speed(CreatureJobs.WATER) * 1.5), "농사 안에서도 땅속성은 파종만 1.5배")
	# 밭 일이 다 끝났으니 방금 부른 work_once 는 채집하러 나간 것
	_check(j._busy and j.task == &"" and not main.forage.claimed.is_empty(), "밭에 할 일이 없으면 풀밭으로 채집하러 감")
	GameState.displayed_herbs = 0
	GameState.displayed_roots = 0
	Engine.time_scale = 20.0
	while j._busy:
		await get_tree().process_frame
	Engine.time_scale = 1.0
	_check(GameState.displayed_herbs + GameState.displayed_roots == 1 and j.position.distance_to(Farm.center_of(j_home)) > 3 * Config.TILE, "풀밭에서 한 포기(또는 도라지)를 캐서 진열")
	# 풀밭에 나가 있는 동안 밭에 일이 생기면 (무가 익으면) 돌아와서 한다
	j_rc = main.farm.get_cell(j_ripe)
	j_rc.growth = Config.CROP_GROW_DAYS
	var j_t0 := Time.get_ticks_msec()
	_check(j.work_once() and j.task == CreatureJobs.HARVEST, "밭에 일이 생기면 채집을 멈추고 돌아와 수확")
	Engine.time_scale = 20.0
	while j._busy:
		await get_tree().process_frame
	Engine.time_scale = 1.0
	_check(main.farm.get_cell(j_ripe).growth == 0 and j.position == Farm.center_of(j_ripe), "돌아와서 익은 무를 거둠")
	# 채집 전담은 밭 일을 하지 않는다
	j_rc.planted = false
	var jf: Creature = main._hatch(CreatureCatalog.SLIME, j_home + Vector2i.DOWN)
	jf.auto_work = false
	while jf.job != CreatureJobs.FORAGE:
		jf.next_job()
	jf.forage = null
	_check(not jf.work_once(), "채집 전담은 밭 일을 하지 않음")
	_check(j.describe().contains("수확") and j.describe().contains("급수"), "농사 크리처 설명에 일마다 속도 (%s)" % j.describe())

	# 35) 대장간 복구 · 대장장이 (2026-09-29 사용자 선택 A: 한 번에 복구 + 사람 장비 제작)
	#     금사리 대장을 잡으면 사금 덩이 + 다음 날 대장간 터 → 돈 · 무 · 사금 덩이로 한 번에 고침 → 대장장이(Tab) · 고물 더미 · 크리처 고철 줍기
	close_all(main)
	var f_material := GameState.material
	var hf := HuntGround.new()
	main.add_child(hf)
	hf.zone = Config.FORGE_ZONE
	hf.set_ai(false)
	var f_boss := hf.spawn_boss()
	f_boss.hp = 1
	hf._defeat(f_boss)
	_check(GameState.material == f_material + 1 and GameState.forge_boss_down, "금사리 대장을 잡으면 %s +1, 대장간 터 예약" % Config.BOSS_MATERIAL_NAME)
	hf.queue_free()
	var hf0 := HuntGround.new()
	main.add_child(hf0)
	hf0.set_ai(false)
	var f_boss0 := hf0.spawn_boss()
	f_boss0.hp = 1
	hf0._defeat(f_boss0)
	_check(GameState.material == f_material + 1, "분원농협 대장은 %s을 주지 않음" % Config.BOSS_MATERIAL_NAME)
	hf0.queue_free()
	main.next_day()
	_check(main.forge != null and GameState.forge_state == 1 and main.forge.texture == preload("res://assets/props/forge_ruin.png"), "다음 날 아침 무너진 대장간 터")
	var f_blocked := true
	for fc: Vector2i in main.forage.herbs:
		f_blocked = f_blocked and not Config.FORGE_RECT.has_point(fc)
	_check(f_blocked, "대장간 터 자리에는 들나물이 돋지 않음")
	main._set_active(main.farmer)
	GameState.hunter_unlocked = true
	main.switch_character()
	main.switch_character()
	_check(main.active == main.farmer, "고치기 전에는 Tab 이 농부 ↔ 사냥꾼만")
	GameState.money = 0
	GameState.crops = 0
	GameState.material = 0
	_check(not main.restore_forge() and GameState.forge_state == 1, "모자라면 못 고침")
	GameState.money = Config.FORGE_COST_MONEY + 1000
	GameState.crops = Config.FORGE_COST_CROPS + 10
	GameState.material = Config.FORGE_COST_MATERIAL
	main.farmer.position = Farm.center_of(Config.FORGE_RECT.position + Vector2i(1, Config.FORGE_RECT.size.y))
	main.interact()
	_check(main.menu_open and main.menu_kind == &"forge", "대장간 터에서 F → 복구 창")
	main.menu_confirm()
	_check(GameState.forge_state == 2 and not main.menu_open, "다 모았으면 한 번에 고침")
	_check(GameState.money == 1000 and GameState.crops == 10 and GameState.material == 0, "돈 · 무 · %s을 냄" % Config.BOSS_MATERIAL_NAME)
	_check(main.smith.visible and main.scrap_heap != null and GameState.scrap_pile == Config.SCRAP_PER_DAY, "대장장이와 고물 더미가 생김")
	_check(CreatureJobs.SCRAP in CreatureJobs.jobs(), "R 일 목록에 고철 줍기")
	main.switch_character()
	main.switch_character()
	_check(main.active == main.smith, "Tab: 농부 → 사냥꾼 → 대장장이")
	main.switch_character()
	_check(main.active == main.farmer, "대장장이 다음은 농부")
	# 크리처 고철 줍기: 땅속성이 빠르다
	var fs: Creature = main._hatch(CreatureCatalog.SLIME, Vector2i(14, 12))
	fs.data.set_element(load("res://data/creatures/elements/earth.tres"))
	fs.auto_work = false
	while fs.job != CreatureJobs.SCRAP:
		fs.next_job()
	_check(is_equal_approx(fs.data.work_speed(CreatureJobs.SCRAP), fs.data.work_speed(CreatureJobs.WATER) * 1.5), "땅속성은 고철 줍기 1.5배")
	GameState.scrap = 0
	_check(fs.work_once(), "고철 줍기 크리처가 고물 더미로")
	Engine.time_scale = 20.0
	while fs._busy:
		await get_tree().process_frame
	Engine.time_scale = 1.0
	_check(GameState.scrap == 1 and GameState.scrap_pile == Config.SCRAP_PER_DAY - 1, "고철 하나를 주워 옴")
	GameState.scrap_pile = 0
	_check(fs.work_once() and fs._busy, "더미가 비면 제자리로 돌아감")
	Engine.time_scale = 20.0
	while fs._busy:
		await get_tree().process_frame
	Engine.time_scale = 1.0
	_check(not fs.work_once(), "제자리에서 쉼")
	main.next_day()
	_check(GameState.scrap_pile == Config.SCRAP_PER_DAY, "아침마다 고물 더미가 다시 쌓임")
	main.farmer.position = Farm.center_of(Creature.scrap_spot())
	main.interact()
	_check(GameState.scrap == 2, "농부가 F로 고철을 손으로 주움")
	# 제작: 대장장이만 모루에서
	GameState.scrap = 20
	GameState.money = 1000
	forge_f(main, main.farmer)
	_check(not main.menu_open, "농부는 모루를 못 씀")
	forge_f(main, main.smith)
	_check(main.menu_open and main.menu_kind == &"craft", "대장장이가 모루에서 F → 제작 창")
	var f_cost: Array = Config.CRAFT_COSTS[&"work_cap"]
	var f_serial := GameState.gear_serial
	main.menu_confirm()
	var f_id := StringName("gear_%d" % GameState.gear_serial)
	_check(GameState.gear_serial == f_serial + 1 and Wearables.rarity(f_id) == &"crafted", "작업 모자를 만듦 (등급 제작)")
	_check(GameState.scrap == 20 - f_cost[0] and GameState.money == 1000 - f_cost[1], "고철 %d · %d원을 씀" % [f_cost[0], f_cost[1]])
	var f_it := Wearables.item(f_id)
	_check(f_it.who == &"farmer" and f_id in (GameState.bag[&"farmer"] + Wearables.worn_by(&"farmer")), "농부 것으로 들어감 (입었거나 가방)")
	_check((f_it.affixes as Array).size() >= 1 and (f_it.affixes as Array).size() <= 3, "옵션 1~3개 (%s)" % f_it.effect)
	main.close_menu()
	# 옵션은 주인 것만: 농부 제작품 = 걷기 · 씨앗 칸 · 괭이 칸, 사냥꾼 것과 사냥터 장비에는 농부 옵션이 없음
	var f_rng := RandomNumberGenerator.new()
	f_rng.seed = 3
	var f_ok_farm := true
	var f_ok_hunt := true
	var f_counts := {}
	for i in 200:
		var rf := Wearables.roll_crafted(f_rng, &"rain_suit")
		f_counts[rf.affixes.size()] = f_counts.get(rf.affixes.size(), 0) + 1
		for fa: Dictionary in rf.affixes:
			f_ok_farm = f_ok_farm and fa.stat in [&"speed", &"sow", &"reach"]
		for fa: Dictionary in Wearables.roll_crafted(f_rng, &"hard_hat").affixes + Wearables.roll_gear(f_rng).affixes:
			f_ok_hunt = f_ok_hunt and not fa.stat in [&"sow", &"reach"]
	_check(f_ok_farm and f_ok_hunt, "농부 제작품은 농부 옵션만, 사냥꾼 것에는 농부 옵션 없음")
	_check(f_counts.has(1) and f_counts.has(2) and f_counts.has(3), "옵션 수 1 · 2 · 3 모두 나옴 %s" % f_counts)
	# 괭이 · 물뿌리개 칸 + 옵션이 실제 칸 수에 들어감
	var f_reach: int = main.tool_cells(Farm.Work.TILL).size()
	GameState.gear_serial += 1
	var f_rid := StringName("gear_%d" % GameState.gear_serial)
	GameState.gear[f_rid] = {base = &"work_boots", rarity = &"crafted", name = "손 긴 작업 장화", affixes = [{stat = &"reach", value = 1}]}
	var f_old_shoes: StringName = GameState.worn[&"farmer"].get(&"shoes", &"")
	GameState.worn[&"farmer"][&"shoes"] = f_rid
	_check(main.tool_cells(Farm.Work.TILL).size() == f_reach + 1, "괭이 칸 +1 옵션 (%d → %d칸)" % [f_reach, main.tool_cells(Farm.Work.TILL).size()])
	if f_old_shoes != &"":
		GameState.worn[&"farmer"][&"shoes"] = f_old_shoes
	else:
		GameState.worn[&"farmer"].erase(&"shoes")
	_check(not (&"work_cap" in Wearables.shop_items()), "제작품은 공급함에서 팔지 않음")
	GameState.scrap = 0
	_check(main.craft(&"hard_hat") == &"", "고철이 모자라면 못 만듦")
	GameState.bag[&"farmer"].append(f_rid)
	main._set_active(main.farmer)
	_check(&"sell_gear" in main.supply_options(), "농부도 공급함에서 제작품을 팜")
	GameState.bag[&"farmer"].erase(f_rid)
	main._set_active(main.smith)
	main.open_inventory()
	_check(not main.inventory.visible, "대장장이는 가방이 없음")
	main._set_active(main.farmer)

	# 36) 광동리 (2026-09-29 사용자: "3구역은 광동리다", 후보 B. 동지벌 군량 벌판): 참새 떼 · 허수아비 장수 · 아기 참새
	close_all(main)
	var g_z: Dictionary = Config.HUNT_ZONES[2]
	_check(g_z.name == "광동리" and g_z.map == "gwangdong" and g_z.flyer, "3구역 광동리: 넓은 맵 + 나는 몬스터")
	main.next_day()
	GameState.hunts_today = 0
	if not 2 in GameState.waypoints:
		GameState.waypoints.append(2)
	HuntGround.loot_enabled = false
	main._set_active(main.hunter)
	_check(main.enter_hunt(null, 2) and main.hunt.zone == 2, "광동리 웨이포인트에서 시작")
	var gh: HuntGround = main.hunt
	gh.set_ai(false)
	gh.set_process(false)
	_check(gh.slimes.size() == g_z.count and gh.slimes[0].flyer and gh.slimes[0].sheet.resource_path.ends_with("wild_sparrow.png"), "참새 %d마리" % g_z.count)
	var sp_a: WildSlime = gh.slimes[0]
	for o in gh.slimes:
		if o != sp_a:
			o.position = Vector2(40, 40)
	sp_a.ai_enabled = true
	sp_a._rest = 0.0
	sp_a.position = main.hunter.feet() + Vector2(80, 0)
	gh.hearts = 9
	gh.tick(0.05)
	_check(sp_a.in_air() and sp_a.airborne(), "사냥꾼이 다가오면 날아오름")

	GameState.worn[&"hunter"].erase(&"weapon")  # 드롭으로 무기를 들었으면 사냥칼로 (이 아래는 칼 휘두르기 점검)
	sp_a.position = main.hunter.feet() + Vector2(0, -8 - Config.SWING_REACH)
	gh._cooldown = 0.0
	_check(gh.swing(Vector2.UP) == 0 and sp_a.hp == g_z.hp, "나는 참새는 칼에 안 맞음")
	sp_a._fly = 0.0
	gh.tick(0.05)
	_check(sp_a._swoop >= 0.0 and not sp_a.telegraph().is_empty() and sp_a.telegraph().kind == &"circle", "맴돌다가 발밑에 그림자 원 예고")
	var g_h0 := gh.hearts
	for i in 60:
		gh._invulnerable = 0.0 if i == 0 else gh._invulnerable
		gh.tick(0.05)
		if sp_a._rest > 0.0 and not sp_a.in_air():
			break
	_check(gh.hearts == g_h0 - g_z.damage, "원 안에 있으면 내려꽂기에 하트 -%d" % g_z.damage)
	_check(not sp_a.in_air() and sp_a._rest > 0.0, "내려앉아 낟알을 쫌 (칠 틈)")
	gh._cooldown = 0.0
	sp_a.position = main.hunter.feet() + Vector2(0, -8 - Config.SWING_REACH)
	_check(gh.swing(Vector2.UP) == 1 and sp_a.hp == g_z.hp - 1, "앉은 참새는 칼에 맞음")
	_check(sp_a._rest <= Config.SWOOP_HIT_RECOVER, "맞으면 곧 다시 날아오름")
	# 내려꽂기 원 밖이면 안 다침
	sp_a._rest = 0.0
	sp_a.position = main.hunter.feet() + Vector2(60, 0)
	gh._invulnerable = 0.0
	gh.tick(0.05)
	sp_a._fly = 0.0
	gh.tick(0.05)
	main.hunter.position += Vector2(0, 60)
	var g_h1 := gh.hearts
	for i in 40:
		gh.tick(0.05)
	_check(gh.hearts == g_h1, "비켜서면 내려꽂기에 안 맞음")
	# 대장 허수아비 장수: 짚단 셋 + 두 번에 한 번 참새 부르기
	for o in gh.slimes.duplicate():
		gh.slimes.erase(o)
		o.queue_free()
	var g_b := gh.spawn_boss()
	_check(g_b.title == "허수아비 장수" and g_b.hp == g_z.boss_hp and not g_b.flyer, "대장 허수아비 장수 체력 %d" % g_z.boss_hp)
	g_b.ai_enabled = true
	g_b._pattern_cd = 0.0
	g_b.position = main.hunter.feet() + Vector2(0, -100)
	gh.hearts = 9
	gh._invulnerable = 0.0
	gh.tick(0.05)
	_check(g_b.telegraphs().size() == Config.STRAW_BALES, "짚단 %d개 예고" % Config.STRAW_BALES)
	for i in 60:
		gh.tick(0.05)
		if g_b.telegraphs().is_empty():
			break
	_check(gh.hearts < 9, "발밑 짚단에 맞음")
	g_b._recover = 0.0
	g_b._pattern_cd = 0.0
	for i in 80:
		gh._invulnerable = 1.0
		gh.tick(0.05)
		if gh.slimes.size() > 1:
			break
	_check(gh.slimes.filter(func(o: WildSlime) -> bool: return o.minion and o.flyer).size() == Config.STRAW_CALL, "두 번째 던지기 뒤 참새 %d마리를 부름" % Config.STRAW_CALL)
	main.leave_hunt()
	HuntGround.loot_enabled = true
	# 알: 광동리 몬스터 알 = 아기 참새 (게임 첫 알은 그대로 슬라임)
	GameState.hunts_today = 0
	main.next_day()
	main.enter_hunt(null, 2)
	gh = main.hunt
	gh.set_ai(false)
	gh.set_process(false)
	HuntGround.egg_roll = 0.0
	HuntGround.loot_enabled = false
	GameState.worn[&"hunter"].erase(&"weapon")  # 드롭으로 무기를 들었으면 사냥칼로 (이 아래는 칼 휘두르기 점검)
	var g_s: WildSlime = gh.slimes[0]
	g_s.hp = 1
	g_s.position = main.hunter.feet() + Vector2(0, -8 - Config.SWING_REACH)
	gh.swing(Vector2.UP)
	_check(gh.drops.size() == 1 and gh.drops[0].species == CreatureCatalog.SPARROW, "광동리 알 = 아기 참새")
	HuntGround.egg_roll = -1.0
	HuntGround.loot_enabled = true
	main.leave_hunt()
	# 아기 참새: 비행 속성만, 채집 1.5배 + 빨리 날아다님, 동행 = 날아가 쪼기 (나는 몬스터도), 아침마다 씨앗
	var g_rng := RandomNumberGenerator.new()
	g_rng.seed = 36
	var g_fly := true
	for i in 30:
		var gd := CreatureData.hatch(CreatureCatalog.SPARROW, g_rng)
		g_fly = g_fly and gd.elements.size() == 1 and gd.elements[0].id == &"flying"
	_check(g_fly, "아기 참새는 비행 속성만")
	var g_c: Creature = main._hatch(CreatureCatalog.SPARROW, Vector2i(16, 12))
	_check(g_c.data.species.sprite_sheets.has(&"flying") and g_c.data.move_speed() > 1.4, "아기 참새 부화 (비행 그림, 빨리 날아다님)")
	_check(is_equal_approx(g_c.data.aptitude(CreatureJobs.FORAGE), 1.5 * g_c.data.creature_trait.job_aptitude.get(CreatureJobs.FORAGE, 1.0)), "채집 재능 1.5배")
	_check(HuntCompanion.style_for(g_c.data) == HuntCompanion.Style.PECK and HuntCompanion.style_name(g_c.data) == "날아가 쪼기", "동행은 날아가 쪼기")
	g_c.job = CreatureJobs.FORAGE
	var g_seeds := GameState.seeds
	var g_got: int = main.gather_seeds()
	_check(g_got >= 2 and g_got <= 4 * main.creatures.filter(func(c: Creature) -> bool: return c.data.species == CreatureCatalog.SPARROW and c.job != CreatureJobs.REST).size() and GameState.seeds == g_seeds + g_got, "아침마다 씨앗 %d" % g_got)
	# 씨앗 넘침: 씨앗이 넉넉하면 남는 낟알은 공급함에서 돈으로
	var g_old_seeds := GameState.seeds
	GameState.seeds = Config.GRAIN_SEED_CAP
	var g_money := GameState.money
	var g_kept: int = main.gather_seeds()
	var g_sold := GameState.money - g_money
	_check(g_kept == 0 and GameState.seeds == Config.GRAIN_SEED_CAP and g_sold >= 2 * Config.GRAIN_PRICE and g_sold % Config.GRAIN_PRICE == 0, "씨앗 %d개부터 낟알은 팔림 (+%d원)" % [Config.GRAIN_SEED_CAP, g_sold])
	GameState.seeds = g_old_seeds
	GameState.money = g_money
	GameState.hunts_today = 0
	main.next_day()
	main.enter_hunt(g_c, 2)
	gh = main.hunt
	gh.set_ai(false)
	gh.set_process(false)
	gh.companion_ai = false
	var g_t: WildSlime = gh.slimes[0]
	g_t._fly = 1.0
	g_t.hp = 2
	g_t.position = gh.companion.position + Vector2(90, 0)
	gh._companion_cooldown = 0.0
	gh._tick_companion(0.01)
	_check(g_t.hp == 1 and not g_t.in_air() and g_t._rest > 0.0, "아기 참새가 날던 참새를 쪼아 떨어뜨림")
	main.leave_hunt()

	# 37. 도마리 (4구역, 2막 마지막 구역): 고목 그루터기 · 장승 한 쌍 · 아기 나무 정령 (2026-09-29)
	var d_zi := 3
	var d_z: Dictionary = Config.HUNT_ZONES[d_zi]
	_check(d_z.name == "도마리" and d_z.monster == "고목 그루터기" and d_z.boss_monster == "천하대장군" and d_z.partner.name == "지하여장군", "4구역 도마리: 고목 그루터기 · 천하대장군 · 지하여장군")
	var d_map := HuntMap.load_map("doma")
	_check(d_map.size == Vector2i(52, 30) and not d_map.find("G").is_empty() and not d_map.find("u").is_empty(), "도마리 칸 지도 52x30 (비닐하우스 · 그루터기)")
	var d_g := d_map.find("G")[0]
	_check(not d_map.is_free(Rect2(d_g - Vector2(4, 3), Vector2(8, 6))) and not d_map.monster_ok(d_map.find("u")[0]), "장작 비닐하우스 · 그루터기는 막힘")
	var d_c: Creature = main._hatch(CreatureCatalog.TREE_SPIRIT, Vector2i(18, 12))
	_check(d_c.data.species.display_name == "아기 나무 정령" and d_c.data.elements[0].id == &"earth" and HuntCompanion.style_name(d_c.data) == "덩굴 묶기", "아기 나무 정령 (땅, 동행 덩굴 묶기)")
	GameState.hunts_today = 0
	if not d_zi in GameState.waypoints:
		GameState.waypoints.append(d_zi)
	main.enter_hunt(d_c, d_zi)
	var dh: HuntGround = main.hunt
	dh.set_ai(false)
	dh.set_process(false)
	dh.companion_ai = false
	_check(dh.zone == d_zi and dh.slimes.size() == d_z.count, "도마리에 들어옴 (고목 그루터기 %d)" % d_z.count)
	var d_s: WildSlime = dh.slimes[0]
	_check(d_s.buried and d_s.disguise and d_s.hp == d_z.hp, "고목 그루터기는 그루터기인 척 숨어 있음 (체력 %d)" % d_z.hp)
	d_s.position = main.hunter.feet() + Vector2(Config.WILD_BURROW_POP_DISTANCE - 10, 0)
	dh.tick(0.01)
	_check(not d_s.buried, "가까이 가면 일어남")
	# 덩굴 묶기: 잠깐 붙잡음
	d_s.position = dh.companion.position + Vector2(Config.COMPANION_BIND_RANGE - 10, 0)
	dh._companion_cooldown = 0.0
	var d_hp0 := d_s.hp
	dh._tick_companion(0.01)
	_check(d_s.stunned() and d_s.hp == d_hp0 - 1, "아기 나무 정령이 덩굴로 묶음 (피해 1 + 멈춤)")
	# 대장: 장승 한 쌍
	for o in dh.slimes.duplicate():
		dh.slimes.erase(o)
		o.queue_free()
	dh.spawn_boss()
	var d_bs := dh.slimes.filter(func(o: WildSlime) -> bool: return o.boss)
	_check(d_bs.size() == 2 and d_bs[0].title == "천하대장군" and d_bs[1].title == "지하여장군" and d_bs[0].pattern == &"log" and d_bs[1].pattern == &"slam" and d_bs[0].hp == d_z.boss_hp, "장승 한 쌍 (천하대장군 통나무 · 지하여장군 내려찍기, 체력 %d씩)" % d_z.boss_hp)
	var d_ch: WildSlime = d_bs[0]
	var d_ji: WildSlime = d_bs[1]
	d_ji.position = Vector2(-500, -500)
	d_ch.ai_enabled = true
	d_ch._pattern_cd = 0.0
	main.hunter.position = dh.map.pixel_size() / 2.0 + Vector2(0, 60)
	d_ch.position = main.hunter.feet() + Vector2(0, -120)
	dh.hearts = 10
	dh._invulnerable = 0.0
	dh.tick(0.05)
	var d_tel := d_ch.telegraph()
	_check(d_tel.get("kind", &"") == &"lane" and d_tel.from.distance_to(d_tel.to) > 150.0, "천하대장군 통나무 굴리기 긴 띠 예고")
	for i in 40:
		dh.tick(0.05)
	_check(dh.hearts == 10 - d_z.damage, "띠 위에 서 있으면 굴러온 통나무에 치임")
	d_ch._recover = 0.0
	d_ch._pattern_cd = 0.0
	dh.hearts = 10
	dh._invulnerable = 0.0
	dh.tick(0.05)
	main.hunter.position += Vector2(60, 0)
	for i in 40:
		dh.tick(0.05)
	_check(dh.hearts == 10, "옆으로 비키면 통나무에 안 맞음")
	d_ch.ai_enabled = false
	# 대장은 몸에 닿기만 해선 안 다침 (예고 패턴으로만)
	d_ch._recover = 1.0
	d_ch.position = main.hunter.feet()
	dh.hearts = 10
	dh._invulnerable = 0.0
	for i in 5:
		dh.tick(0.05)
	_check(dh.hearts == 10, "대장 몸에 닿기만 해선 하트가 안 줆")
	d_ch.position = main.hunter.feet() + Vector2(0, -120)
	# 하나만 쓰러뜨리면 보상 없음, 둘 다 쓰러뜨리면 대장 알 (확률 고정)
	HuntGround.egg_roll = 0.0
	dh.drops.clear()
	dh._defeat(d_ch)
	_check(dh.drops.is_empty() and dh.slimes.has(d_ji), "천하대장군만 쓰러뜨리면 알 없음 (지하여장군이 남음)")
	dh._defeat(d_ji)
	var d_eggs := dh.drops.filter(func(d: Dictionary) -> bool: return d.species == CreatureCatalog.TREE_SPIRIT)
	_check(d_eggs.size() == 1, "둘 다 쓰러뜨리면 나무 정령 알 (확률에 걸리면)")
	HuntGround.egg_roll = -1.0
	main.leave_hunt()
	# 키우기: 농사를 맡으면 범위 안 밭 작물이 가끔 하루 더 자람 (확률을 1로 두고 확인)
	var d_cell: Vector2i = Config.FIELD_PLOTS[0].position + Vector2i(1, 1)
	main.farm.do_work(Farm.Work.TILL, d_cell)
	main.farm.do_work(Farm.Work.SOW, d_cell)
	main.farm.do_work(Farm.Work.WATER, d_cell)
	main.farm.get_cell(d_cell).growth = 0
	var d_g0: int = main.farm.get_cell(d_cell).growth
	d_c.home = d_cell
	d_c.job = CreatureJobs.FARM
	var d_sp: CreatureSpecies = CreatureCatalog.TREE_SPIRIT
	var d_ch0 := d_sp.grow_chance
	d_sp.grow_chance = 1.0
	var d_boost: int = main.boost_growth()
	d_sp.grow_chance = d_ch0
	_check(d_boost >= 1 and main.farm.get_cell(d_cell).growth == d_g0 + 1, "아기 나무 정령 키우기: 물 준 작물이 하루 더 자람")
	# 잡템 이름은 구역 몬스터에 맞춤 (금사리 모래게 껍데기 · 광동리 참새 깃털 · 도마리 고목 옹이)
	var j_rng := RandomNumberGenerator.new()
	var j_names := {}
	for zi in 4:
		for k in 400:
			var jd := HuntLoot.roll_for_kill(j_rng, zi)
			if jd.get("kind") == &"junk":
				j_names[zi] = HuntLoot.label(jd)
				break
	_check(j_names.get(0) == "슬라임 젤리" and j_names.get(1) == "모래게 껍데기" and j_names.get(2) == "참새 깃털" and j_names.get(3) == "고목 옹이", "잡템 이름이 구역마다 다름 %s" % j_names)

	# 무기 (2026-09-29 사용자: 근거리 · 활 · 지팡이). 무기 칸이 비면 사냥칼.
	GameState.reset()
	GameState.hunter_unlocked = true
	GameState.first_egg_done = true
	GameState.waypoints = [0, 1, 2, 3]
	main._set_active(main.hunter)
	var wr := RandomNumberGenerator.new()
	wr.seed = 5
	_check(Wearables.weapon().kind == &"melee" and Wearables.weapon().name == "사냥칼", "무기 칸이 비면 사냥칼")
	_check(Wearables.slots_for(&"hunter").has(&"weapon") and not Wearables.slots_for(&"farmer").has(&"weapon"), "무기 칸은 사냥꾼만")
	var w_gift := HuntLoot.roll_for_boss(wr, 0)
	var w_gift2 := HuntLoot.roll_for_boss(wr, 1)
	_check(w_gift.has("roll") and w_gift.roll.base == &"hunting_bow" and w_gift.roll.rarity == &"normal" \
		and w_gift2.has("roll") and w_gift2.roll.base == &"water_staff", "대장 첫 처치 선물: 분원농협 사냥 활 · 금사리 물의 지팡이 (일반)")
	var w_again := 0
	for i in 200:
		var d := HuntLoot.roll_for_boss(wr, 0)
		if d.has("roll") and d.roll.base == &"hunting_bow" and d.roll.rarity == &"normal":
			w_again += 1
	_check(w_again < 20, "선물은 한 번만 (그 뒤는 보통 드롭, 200번 중 일반 사냥 활 %d)" % w_again)
	var w_count := 0
	var w_affix_ok := true
	for i in 2000:
		var g := Wearables.roll_gear(wr, &"rare")
		var is_w: bool = Wearables.ITEMS[g.base].slot == &"weapon"
		w_count += int(is_w)
		for a: Dictionary in g.affixes:
			w_affix_ok = w_affix_ok and Wearables.AFFIXES[a.stat].on in [&"", &"weapon" if is_w else &"armor"]
	_check(w_count > 600 and w_count < 800, "장비 드롭 중 무기 약 35%% (%d/2000)" % w_count)
	_check(w_affix_ok, "무기엔 무기 옵션(공격 빠르기 · 사거리 · 돈 · 드롭)만, 방어구엔 방어구 옵션만")
	var w_bow_where := Wearables.gain_rolled(w_gift.roll)
	_check(w_bow_where == &"worn" and Wearables.weapon().kind == &"bow" and Wearables.weapon().range == 150.0, "처음 얻은 무기는 바로 듦 (활 사거리 150)")
	# 활: 칼이 안 닿는 거리에서 화살 한 대
	GameState.hunts_today = 0
	main.hunter.position = main.hunt_gate.position
	main.enter_hunt(null, 0)
	var wph: HuntGround = main.hunt
	wph.set_ai(false)
	wph.set_process(false)
	var w_feet: Vector2 = main.hunter.feet()
	for o: WildSlime in wph.slimes:
		o.position = w_feet + Vector2(-300, 0)
	var w_t: WildSlime = wph.slimes[0]
	w_t.hp = 3
	w_t.position = w_feet + Vector2(120, 8)
	_check(wph.swing(Vector2.RIGHT) == 1 and wph.shots.size() == 1, "활: 클릭하면 화살이 날아감")
	for i in 30:
		wph.tick(1.0 / 30.0)
	_check(w_t.hp == 2 and wph.shots.is_empty(), "화살이 120 떨어진 몬스터에 맞고 사라짐")
	w_t.position = w_feet + Vector2(220, 8)
	wph._cooldown = 0.0
	wph.swing(Vector2.RIGHT)
	for i in 40:
		wph.tick(1.0 / 30.0)
	_check(w_t.hp == 2, "사거리(150) 밖은 안 맞음")
	# 지팡이: 물 = 느려짐 · 땅 = 멈춤 · 불 = 잠시 뒤 한 번 더
	for el: StringName in [&"water_staff", &"earth_staff", &"fire_staff"]:
		Wearables.gain_rolled(Wearables.roll_gear(wr, &"normal", {}, el))
		GameState.worn[&"hunter"][&"weapon"] = StringName("gear_%d" % GameState.gear_serial)
		w_t.hp = 5
		w_t._stun = 0.0
		w_t._slow = 0.0
		w_t.position = w_feet + Vector2(90, 8)
		var w_near: WildSlime = wph.slimes[1]
		w_near.hp = 5
		w_near.position = w_t.position + Vector2(10, 6)
		wph._cooldown = 0.0
		wph.swing(Vector2.RIGHT)
		for i in 25:
			wph.tick(1.0 / 30.0)
		var w_fx := {&"water_staff": w_t.slowed(), &"earth_staff": w_t.stunned(), &"fire_staff": wph._burns.size() == 2}
		_check(w_t.hp == 4 and w_near.hp == 4 and w_fx[el], "%s: 구슬이 터져 둘레 둘 다 1 피해 + %s" % [Wearables.ITEMS[el].name, Wearables.ELEMENT_EFFECTS[Wearables.ITEMS[el].weapon.element]])
	for i in 60:
		wph.tick(1.0 / 30.0)
	_check(w_t.hp == 3, "불 구슬: 잠시 뒤 한 번 더 피해")
	# 근거리 무기: 전투 도끼는 사냥칼보다 넓게
	Wearables.gain_rolled(Wearables.roll_gear(wr, &"normal", {}, &"battle_axe"))
	GameState.worn[&"hunter"][&"weapon"] = StringName("gear_%d" % GameState.gear_serial)
	w_t.position = w_feet + Vector2(0, -8) + Vector2(Config.SWING_REACH + 24, 0)
	w_t.hp = 5
	wph._cooldown = 0.0
	_check(wph.swing(Vector2.RIGHT) == 1 and w_t.hp == 4, "전투 도끼: 사냥칼이 안 닿는 옆까지 벰")
	main.leave_hunt()
	# 나는 참새도 화살엔 맞는다
	GameState.worn[&"hunter"][&"weapon"] = &"gear_1"
	GameState.hunts_today = 0
	main.hunter.position = main.hunt_gate.position
	main.enter_hunt(null, 2)
	var wpg: HuntGround = main.hunt
	wpg.set_ai(false)
	wpg.set_process(false)
	var wg_feet: Vector2 = main.hunter.feet()
	for o: WildSlime in wpg.slimes:
		o.position = wg_feet + Vector2(-300, 0)
	var w_sp: WildSlime = wpg.slimes[0]
	w_sp.position = wg_feet + Vector2(80, 0)
	w_sp.ai_enabled = true
	w_sp._rest = 0.0
	wpg.tick(0.05)
	w_sp.ai_enabled = false
	var w_sp_hp := w_sp.hp
	w_sp.position = wg_feet + Vector2(100, 8)
	wpg._cooldown = 0.0
	wpg.swing(Vector2.RIGHT)
	for i in 30:
		wpg.tick(1.0 / 30.0)
	_check(w_sp.hp == w_sp_hp - 1 and not w_sp.in_air(), "화살은 나는 참새도 맞혀 떨어뜨림")
	main.leave_hunt()
	# 대장간: 강철 검 · 쇠뇌
	GameState.scrap = 20
	GameState.money = 2000
	var w_cid: StringName = main.craft(&"crossbow")
	_check(w_cid != &"" and Wearables.rarity(w_cid) == &"crafted" and Wearables.item(w_cid).weapon.kind == &"bow" and Config.CRAFT_COSTS.has(&"steel_sword"), "대장간에서 쇠뇌 (제작 무기) · 강철 검")
	_check(Wearables.describe(w_cid).contains("활 · 사거리"), "무기 설명에 종류 · 사거리 %s" % Wearables.describe(w_cid))

	# 39) 3막 번천 (2026-09-29 사용자: 번천 = 춥고 어두운 삼거리, 유령 몬스터 → 후보 A 도깨비불 + 유령 막차 + 아기 도깨비불)
	#     약방 · 연금술사 (사용자 선택 A+B 물약 · 크리처 보약): 장승 조각 → 약방 터 → 한 번에 복구 → 연금술사 · 호롱
	var b_zi := 4
	var b_z: Dictionary = Config.HUNT_ZONES[b_zi]
	_check(b_z.name == "번천" and b_z.monster == "도깨비불" and b_z.boss_monster == "유령 막차" and b_z.night and b_z.ghost, "5구역 번천: 도깨비불 · 유령 막차 · 밤 · 유령")
	var b_map := HuntMap.load_map("bunjeon")
	_check(b_map.find("L").size() >= 6 and not b_map.find("P").is_empty() and not b_map.is_free(Rect2(b_map.find("L")[0] - Vector2(3, 3), Vector2(6, 6))), "번천 칸 지도: 가로등 · 버스 정류장 (막힘)")
	var b_c: Creature = main._hatch(CreatureCatalog.WILL_O, Vector2i(18, 12))
	_check(b_c.data.species.display_name == "아기 도깨비불" and b_c.data.elements[0].id == &"fire" and HuntCompanion.style_name(b_c.data) == "불빛 + 불씨", "아기 도깨비불 (새 속성 불, 동행 불빛 + 불씨)")
	_check(b_c.data.work_speed(CreatureJobs.HERB) > b_c.data.work_speed(CreatureJobs.FORAGE), "불 속성은 도라지밭 일이 빠름")
	GameState.hunts_today = 0
	GameState.lamp_oil = 1
	GameState.strength = 1
	if not b_zi in GameState.waypoints:
		GameState.waypoints.append(b_zi)
	main.enter_hunt(b_c, b_zi)
	var bjh: HuntGround = main.hunt
	bjh.set_ai(false)
	bjh.set_process(false)
	bjh.companion_ai = false
	_check(bjh.zone == b_zi and bjh.is_night() and bjh.lamps.size() == b_map.find("L").size(), "번천에 들어옴: 밤, 가로등 %d" % bjh.lamps.size())
	_check(bjh.lamp_oil and GameState.lamp_oil == 0 and is_equal_approx(bjh.lantern_radius(), Config.LANTERN_RADIUS * Config.LAMP_OIL_MULT), "호롱 기름을 채워 호롱 불빛이 넓음")
	_check(bjh.strong and GameState.strength == 0 and bjh.power() == 2, "힘 물약: 이번 사냥 피해 +1")
	bjh.strong = false
	bjh.lamp_oil = false
	var b_feet: Vector2 = main.hunter.feet()
	var b_lamps := bjh.lamps.duplicate()
	bjh.lamps.clear()
	bjh.companion.position = b_feet + Vector2(0, -220)
	for o: WildSlime in bjh.slimes:
		o.position = b_feet + Vector2(-320, 0)
	var b_g: WildSlime = bjh.slimes[0]
	b_g.hp = 3
	b_g.position = b_feet + Vector2(120, 8)
	bjh.tick(0.01)
	_check(not bjh.hittable(b_g) and is_equal_approx(b_g.modulate.a, Config.GHOST_FADE), "어둠 속 도깨비불은 반쯤 비침 (못 맞힘)")
	_check(bjh.in_light(b_feet + Vector2(20, 0)) and not bjh.in_light(b_feet + Vector2(Config.LANTERN_RADIUS + 10, 0)), "사냥꾼 호롱 둘레만 밝음")
	bjh._cooldown = 0.0
	bjh.swing(Vector2.RIGHT)
	for i in 30:
		bjh.tick(1.0 / 30.0)
	_check(b_g.hp == 3, "화살이 어둠 속 도깨비불을 지나감")
	bjh.lamps.assign(b_lamps)
	_check(bjh.hittable(b_g) == bjh.in_light(b_g.position) and bjh.in_light(b_lamps[0] + Vector2(0, 10)), "가로등 아래는 밝음")
	# 불빛 동행: 동행 둘레 유령도 맞고, 불씨로 잠시 뒤 한 번 더 (아직 날던 화살은 치움)
	bjh.lamps.clear()
	bjh.shots.clear()
	b_g.position = bjh.companion.position + Vector2(20, 0)
	_check(bjh.hittable(b_g), "아기 도깨비불 불빛 안의 도깨비불은 맞음")
	bjh.companion_attack(b_g)
	_check(b_g.hp == 2 and bjh._burns.size() == 1, "불씨: 1 피해 + 불붙음")
	for i in int(Config.STAFF_BURN_DELAY * 30) + 5:
		# 동행이 사냥꾼 쪽으로 걸어가도 도깨비불이 불빛 안에 있게 (불씨는 불빛 안에서만 탄다)
		b_g.position = bjh.companion.position + Vector2(20, 0)
		bjh._companion_cooldown = 99.0  # 동행이 다시 치지 않게 (크리처 공격 간격은 타고난 능력치에 따라 1.5초보다 짧을 수 있다)
		bjh.tick(1.0 / 30.0)
	_check(b_g.hp == 1, "불씨: 잠시 뒤 한 번 더 피해 (체력 %d)" % b_g.hp)
	# 도깨비불 불똥: 불빛 안에서만 부풀어 원 안을 다치게 함
	var b_w: WildSlime = bjh.slimes[1]
	b_w.lit = false
	b_w._lunge_cd = 0.0
	_check(not b_w._tick_attack(0.01, b_w.position + Vector2(10, 0)) and b_w._burst < 0.0, "어둠 속 도깨비불은 불똥을 안 튀김")
	b_w.position = b_feet + Vector2(16, 0)
	b_w.ai_enabled = true
	bjh._invulnerable = 0.0
	var b_h0 := bjh.hearts
	bjh.tick(0.02)
	_check(b_w._burst >= 0.0, "호롱 불빛에 들어온 도깨비불이 부풂 (예고)")
	for i in int(b_z.windup * 30) + 3:
		bjh.tick(1.0 / 30.0)
	_check(bjh.hearts == b_h0 - b_z.damage and b_w._recover > 0.0, "불똥에 다침 (하트 -%d), 쪼그라든 동안 칠 틈" % b_z.damage)
	b_w.ai_enabled = false
	# 유령 막차: 전조등 띠 예고 → 도로 따라 돌진, 닿으면 다침. 대장은 어둠에서도 맞음
	bjh.lamps.assign(b_lamps)
	for o: WildSlime in bjh.slimes.duplicate():
		bjh.slimes.erase(o)
		o.queue_free()
	var b_bus: WildSlime = bjh.spawn_boss()
	_check(b_bus.boss_frame == Vector2i(96, 48) and b_bus.pattern == &"bus" and b_bus.hp == b_z.boss_hp and bjh.hittable(b_bus), "유령 막차 (96x48, 체력 %d, 어둠에서도 맞음)" % b_z.boss_hp)
	b_bus.position = b_feet + Vector2(150, 0)
	b_bus.ai_enabled = true
	b_bus._pattern_cd = 0.0
	bjh._invulnerable = 0.0
	b_h0 = bjh.hearts
	bjh.tick(0.02)
	_check(b_bus._bus_aim >= 0.0 and b_bus._bus_to.y == b_bus._bus_from.y, "막차가 전조등으로 가로 띠를 비춤 (예고)")
	for i in int((Config.BUS_WINDUP + Config.BUS_TIME) * 30) + 5:
		bjh.tick(1.0 / 30.0)
	_check(bjh.hearts < b_h0 and b_bus._runs == 1, "막차 돌진에 치임 (하트 %d → %d)" % [b_h0, bjh.hearts])
	b_bus.ai_enabled = false
	main.leave_hunt()

	# 약방: 도마리 장승 한 쌍을 잡으면 장승 조각 + 다음 날 약방 터, 고치기 전엔 번천 쪽이 캄캄
	GameState.yak_state = 0
	GameState.material2 = 0
	GameState.hunts_today = 0
	main.enter_hunt(null, 3)
	var yh: HuntGround = main.hunt
	yh.set_ai(false)
	yh.set_process(false)
	for o: WildSlime in yh.slimes.duplicate():
		yh.slimes.erase(o)
		o.queue_free()
	yh.spawn_boss()
	for o: WildSlime in yh.slimes.duplicate():
		yh._defeat(o)
	_check(GameState.material2 == 1 and GameState.yak_boss_down and yh.path_open, "장승 한 쌍을 쓰러뜨리면 장승 조각 1")
	_check(yh.road_dark() and yh.path_block().contains("캄캄") and not yh.advance(), "약방을 고치기 전엔 번천 쪽이 캄캄해서 못 감")
	main.leave_hunt()
	var y_lines: Array[String] = main.next_day()
	_check(GameState.yak_state == 1 and main.yak != null and " ".join(y_lines).contains("약방 터"), "다음 날 아침 약방 터가 드러남")
	GameState.money = 100
	_check(not main.restore_yak() and GameState.yak_state == 1, "모자라면 못 고침")
	GameState.money = Config.YAK_COST_MONEY + 7
	GameState.roots = Config.YAK_COST_ROOTS
	GameState.material2 = Config.YAK_COST_MATERIAL
	_check(main.restore_yak() and GameState.yak_state == 2 and main.alchemist.visible and main.herb_bed != null and GameState.money == 7 and GameState.roots == 0 and GameState.material2 == 0,
		"약방 복구 (돈 %d · 도라지 %d · 장승 조각 %d) → 연금술사" % [Config.YAK_COST_MONEY, Config.YAK_COST_ROOTS, Config.YAK_COST_MATERIAL])
	_check(CreatureJobs.jobs().has(CreatureJobs.HERB) and GameState.herb_bed == Config.HERB_BED_PER_DAY, "도라지밭 일이 생김 (하루 %d)" % Config.HERB_BED_PER_DAY)
	_check(main.pick_herb_bed() and GameState.roots == 1 and GameState.herb_bed == Config.HERB_BED_PER_DAY - 1, "도라지밭에서 손으로 도라지 하나")
	b_c.home = Vector2i(18, 12)
	b_c.job = CreatureJobs.HERB
	_check(b_c._herb_once(), "아기 도깨비불이 도라지밭 일을 함")
	GameState.hunts_today = 0
	main.enter_hunt(null, 3)
	_check(main.hunt.path_block() == "", "약방을 고치면 번천 길이 열림 (호롱)")
	main.leave_hunt()
	# 연금술사 제작: 물약 (A) · 크리처 보약 (B)
	GameState.herbs = 4
	GameState.junk = 3
	GameState.roots = 0
	GameState.potions = 0
	_check(main.brew(&"potion") and GameState.potions == 2 and GameState.herbs == 2 and GameState.junk == 2, "빨간 물약 두 병 (나물 2 · 잡템 1)")
	_check(not main.brew(&"lamp_oil") and GameState.lamp_oil == 0, "도라지가 없으면 호롱 기름 못 만듦")
	GameState.roots = 4
	_check(main.brew(&"lamp_oil") and GameState.lamp_oil == 1 and GameState.roots == 2 and GameState.junk == 2, "호롱 기름 (도라지 2)")
	GameState.crops = 5
	_check(main.brew(&"tonic") and GameState.tonics == 1 and GameState.crops == 0 and GameState.roots == 0, "크리처 보약 (무 5 · 도라지 2)")
	b_c._reset_timer()
	var y_t1 := b_c._timer
	_check(main.brew_options().has(&"feed_tonic") and main.feed_tonic() and not main.feed_tonic() and GameState.tonics == 0, "보약 먹이기 (하루 한 번)")
	_check(is_equal_approx(b_c._timer, y_t1 / Config.TONIC_SPEED_MULT), "보약 먹은 날 크리처 일 두 배 빠름")
	GameState.junk = Config.JUNK_KEEP + 5
	var y_m0 := GameState.money
	main._set_active(main.hunter)
	main.hunter.position = Farm.center_of(main.SUPPLY_RECT.position + Vector2i(1, 1))
	main._hunter_interact()
	main.close_menu()
	_check(GameState.junk == Config.JUNK_KEEP and GameState.money == y_m0 + 5 * Config.JUNK_PRICE, "약방을 고친 뒤 공급함은 잡템 %d개를 약방 재료로 남기고 나머지만 팖" % Config.JUNK_KEEP)
	main.next_day()
	_check(GameState.tonic_day != GameState.day and GameState.herb_bed == Config.HERB_BED_PER_DAY, "다음 날: 보약 효과 끝 · 도라지밭 다시 돋음")

	# 40) 3막 둘째 구역 밀목 (2026-09-30 사용자: "다음은 광주시에있는 밀목이야", 후보 B 늑대 + 호랑이, 판타지풍으로)
	#     그림자 늑대 무리 · 산군 백호 · 아기 호랑이 (드물게 아기 백호, 신령 속성) · 산군 발톱 → 축사 (닭장 · 목축인)
	var m_zi := 5
	var m_z: Dictionary = Config.HUNT_ZONES[m_zi]
	_check(m_z.name == "밀목" and m_z.monster == "그림자 늑대" and m_z.boss_monster == "산군 백호" and m_z.wolf and m_z.boss_pattern == &"tiger" and not m_z.get("night", false), "6구역 밀목: 그림자 늑대 · 산군 백호 · 그늘 (밤 아님)")
	var m_map := HuntMap.load_map("milmok")
	_check(not m_map.find("K").is_empty() and not m_map.find("W").is_empty() and m_map.find("T").size() > 600, "밀목 칸 지도: 빽빽한 나무 %d · 대장 자리 · 웨이포인트" % m_map.find("T").size())
	var m_t: Creature = main._hatch(CreatureCatalog.TIGER, Vector2i(18, 12))
	_check(m_t.data.species.display_name == "아기 호랑이" and m_t.data.elements[0].id == &"earth" and HuntCompanion.style_name(m_t.data) == "포효" and m_t.data.species.guards_coop, "아기 호랑이 (땅, 동행 포효, 축사 지킴이)")
	var m_w: Creature = main._hatch(CreatureCatalog.WHITE_TIGER, Vector2i(18, 12))
	_check(m_w.data.elements[0].id == &"spirit" and m_w.data.elements[0].display_name == "신령" and HuntCompanion.style_name(m_w.data) == "포효 + 번개 발톱" and m_w.data.work_radius() >= 2, "아기 백호 (새 속성 신령, 스킬 둘, 범위 2 이상)")
	_check(m_w.data.aptitude(CreatureJobs.FORAGE) >= 1.5 and m_w.data.aptitude(CreatureJobs.FEED) >= 3.0 and m_t.data.aptitude(CreatureJobs.FEED) == 2.0, "신령은 모든 일 1.5배 (백호 모이 주기 3배, 호랑이 2배)")
	GameState.hunts_today = 0
	if not m_zi in GameState.waypoints:
		GameState.waypoints.append(m_zi)
	main.enter_hunt(m_t, m_zi)
	var mh: HuntGround = main.hunt
	mh.set_ai(false)
	mh.set_process(false)
	mh.companion_ai = false
	_check(mh.zone == m_zi and not mh.is_night() and mh._night.size() == 1, "밀목에 들어옴: 그늘 (어둡기만, 불빛 규칙 없음)")
	var m_feet: Vector2 = main.hunter.feet()
	for o: WildSlime in mh.slimes:
		o.position = m_feet + Vector2(-400, 0)
	var m_a: WildSlime = mh.slimes[0]
	var m_b: WildSlime = mh.slimes[1]
	_check(m_a.wolf and m_a._lunge_cd >= Config.WOLF_FIRST_GAP, "늑대 첫 달려들기는 어긋나게 늦춤")
	# 둘러서서 돈다 (나무가 없는 빈터에서)
	m_a.position = m_feet + Vector2(100, 0)
	m_a._lunge_cd = 5.0
	m_a.ai_enabled = true
	for i in 90:
		m_a.tick(1.0 / 30.0, m_feet)
	var m_ring := m_a.position.distance_to(m_feet)
	_check(m_ring < 90.0 and m_ring > 30.0 and m_a._windup < 0.0, "그림자 늑대가 둘레에 둘러서서 돎 (거리 %.0f · %s → 발 %s · 영역 %s · 돎 %s · 풀림 %.1f)" % [m_ring, m_a.position, m_feet, m_a.area, m_a._circling, m_a._stun])
	m_a._lunge_cd = 0.0
	m_a.tick(0.01, m_feet)
	_check(m_a._windup >= 0.0, "차례가 오면 달려들기 예고")
	m_a.ai_enabled = false
	m_a._windup = -1.0
	# 하나가 쓰러지면 둘레 늑대가 멈칫
	m_b.position = m_a.position + Vector2(40, 0)
	m_a.hp = 1
	_check(m_a.hit(m_feet) and true, "늑대 쓰러짐")
	mh._defeat(m_a)
	_check(m_b.stunned(), "둘레 늑대가 멈칫 (칠 틈)")
	# 아기 호랑이 포효: 맞은 늑대와 둘레 늑대가 멈춤
	var m_c: WildSlime = mh.slimes[1]
	m_b._stun = 0.0
	m_b.hp = 5
	mh.companion.position = m_feet + Vector2(0, -60)
	m_b.position = mh.companion.position + Vector2(20, 0)
	m_c.position = mh.companion.position + Vector2(-30, 0)
	m_c._stun = 0.0
	mh.companion_attack(m_b)
	_check(m_b.hp == 4 and m_b.stunned() and m_c.stunned(), "포효: 1 피해 + 둘레 멈춤")
	main.leave_hunt()
	GameState.hunts_today = 0
	main.enter_hunt(m_w, m_zi)
	mh = main.hunt
	mh.set_ai(false)
	mh.set_process(false)
	mh.companion_ai = false
	m_b = mh.slimes[0]
	m_b.hp = 5
	m_b.position = mh.companion.position + Vector2(20, 0)
	mh.companion_attack(m_b)
	_check(m_b.hp == 3, "아기 백호 번개 발톱: 한 방에 2 피해")
	# 산군 백호: 도약 (착지 원, 새끼 없음) → 쓰러지는 나무 → 포효 (굳음)
	for o: WildSlime in mh.slimes.duplicate():
		mh.slimes.erase(o)
		o.queue_free()
	m_feet = main.hunter.feet()
	var m_boss: WildSlime = mh.spawn_boss()
	_check(m_boss.pattern == &"tiger" and m_boss.hp == m_z.boss_hp and m_boss.title == "산군 백호", "산군 백호 (체력 %d)" % m_z.boss_hp)
	m_boss.position = m_feet + Vector2(120, 0)
	m_boss.ai_enabled = true
	m_boss._pattern_cd = 0.0
	mh._invulnerable = 0.0
	var m_h0 := mh.hearts
	mh.tick(0.02)
	_check(m_boss._air_t >= 0.0 and m_boss.telegraph().kind == &"circle", "백호 도약 (착지 원 예고)")
	for i in int(Config.SLAM_AIR_TIME * 30) + 4:
		mh.tick(1.0 / 30.0)
	_check(mh.hearts == m_h0 - m_z.damage and mh.slimes.size() == 1, "착지에 다침 (하트 -%d), 새끼는 안 나옴" % m_z.damage)
	m_boss._recover = 0.0
	m_boss._pattern_cd = 0.0
	m_boss.position = main.hunter.feet() + Vector2(60, 0)
	mh.tick(0.02)
	_check(m_boss._log_aim >= 0.0, "쓰러지는 나무 (띠 예고)")
	m_boss._log_aim = -1.0
	m_boss._recover = 0.0
	m_boss._pattern_cd = 0.0
	m_boss.position = main.hunter.feet() + Vector2(40, 0)
	mh.tick(0.02)
	_check(m_boss._roar >= 0.0 and m_boss.telegraph().get("roar", false), "포효 (둘레 원 예고)")
	for i in int(Config.TIGER_ROAR_WINDUP * 30) + 3:
		mh.tick(1.0 / 30.0)
	mh._cooldown = 0.0
	_check(mh.frozen > 0.0 and main.hunter.frozen and mh.swing(Vector2.RIGHT) == 0, "포효 원 안이면 잠깐 굳음 (못 휘두름)")
	for i in int(Config.TIGER_ROAR_FREEZE * 30) + 3:
		mh.tick(1.0 / 30.0)
	_check(mh.frozen == 0.0 and not main.hunter.frozen, "굳음이 풀림")
	m_boss.ai_enabled = false
	# 대장을 잡으면 산군 발톱 + 다음 날 축사 터, 대장 알은 드물게 아기 백호
	GameState.material3 = 0
	GameState.barn_state = 0
	HuntGround.egg_roll = 0.0
	mh._defeat(m_boss)
	_check(GameState.material3 == 1 and GameState.barn_boss_down and not mh.path_open, "산군 백호를 쓰러뜨리면 산군 발톱 1 (더 깊은 곳은 아직 막힘)")
	_check(mh.drops.size() == 1 and mh.drops[0].species == CreatureCatalog.WHITE_TIGER, "확률에 걸리면 대장 알이 아기 백호")
	HuntGround.egg_roll = 0.15
	var m_boss2: WildSlime = mh.spawn_boss()
	mh._defeat(m_boss2)
	_check(mh.drops.size() == 2 and mh.drops[1].species == CreatureCatalog.TIGER and GameState.material3 == 2, "보통은 아기 호랑이 알")
	HuntGround.egg_roll = -1.0
	main.leave_hunt()
	# 축사 (닭장): 터 → 한 번에 복구 → 목축인 · 닭 한 쌍
	var m_lines: Array[String] = main.next_day()
	_check(GameState.barn_state == 1 and main.barn != null and " ".join(m_lines).contains("축사 터"), "다음 날 아침 축사 터가 드러남")
	GameState.money = 100
	main._barn_interact()
	_check(main.menu_kind == &"barn" and main._menu_options == [&"restore", &"close"], "축사 터에서 F → 복구 창")
	main.close_menu()
	_check(not main.restore_barn() and GameState.barn_state == 1, "모자라면 못 고침")
	GameState.money = Config.BARN_COST_MONEY + 3
	GameState.crops = Config.BARN_COST_CROPS + 4
	GameState.material3 = Config.BARN_COST_MATERIAL
	_check(main.restore_barn() and GameState.barn_state == 2 and main.rancher.visible and GameState.hens == Config.START_HENS and GameState.money == 3 and GameState.crops == 4 and GameState.material3 == 0,
		"축사 복구 (돈 %d · 무 %d · 산군 발톱 %d) → 목축인 · 암탉 %d" % [Config.BARN_COST_MONEY, Config.BARN_COST_CROPS, Config.BARN_COST_MATERIAL, Config.START_HENS])
	_check(CreatureJobs.jobs().has(CreatureJobs.FEED), "모이 주기 일이 생김")
	main._set_active(main.farmer)
	_check(not main.coop_options().has(&"lunch") and main.coop_options().has(&"feed"), "농부는 모이 주기만 (도시락은 목축인)")
	_check(main.coop_action(&"feed") and GameState.fed == GameState.hens and GameState.crops == 3, "모이 주기 (무 %d)" % Config.FEED_CROP_COST)
	var m_rng := RandomNumberGenerator.new()
	m_rng.seed = 7
	var m_r: Dictionary = main.coop_night(m_rng, true)
	_check(m_r.laid == 1 and GameState.nest == 1 and GameState.fed == 0, "모이 먹은 암탉은 아침에 달걀 하나")
	# 둥지에 남긴 달걀 → 병아리 → 암탉 (확률을 1로)
	GameState.nest = 4
	GameState.fed = GameState.hens
	var m_hatch := Config.CHICK_HATCH_CHANCE
	for i in Config.CHICK_GROW_DAYS + 1:
		m_r = main.coop_night(m_rng, true)
		if i == 0:
			_check(m_r.hatched >= 1 and GameState.chicks.size() == m_r.hatched, "둥지에 남긴 달걀이 병아리가 됨 (%d마리)" % m_r.hatched)
		GameState.fed = GameState.hens
	var m_hens := GameState.hens
	_check(m_hens > Config.START_HENS and GameState.hens + GameState.chicks.size() <= Config.HEN_CAP, "병아리가 %d일 뒤 암탉이 됨 (암탉 %d)" % [Config.CHICK_GROW_DAYS, m_hens])
	# 족제비: 지킴이가 없으면 가끔 둥지 달걀을 물어 감 (확률 1로 확인), 지킴이가 있으면 안 옴
	GameState.nest = 4
	var m_seen := false
	for i in 40:
		GameState.nest = 4
		var m_wz: Dictionary = main.coop_night(m_rng, false)
		m_seen = m_seen or (m_wz.weasel as String).contains("족제비")
	_check(m_seen, "지킴이가 없으면 족제비가 가끔 옴")
	var m_guard_seen := false
	for i in 40:
		GameState.nest = 4
		var m_gz: Dictionary = main.coop_night(m_rng, true)
		m_guard_seen = m_guard_seen or m_gz.weasel != ""
	_check(not m_guard_seen, "모이 주는 아기 호랑이가 있으면 족제비가 안 옴")
	# 크리처 모이 주기
	GameState.fed = 0
	m_t.home = Creature.feed_spot()
	m_t.job = CreatureJobs.FEED
	m_t._busy = false
	_check(m_t._feed_once(), "아기 호랑이가 모이 주기 일을 함")
	# 달걀: 꺼내기 → 공급함 진열 → 밤사이 팔림, 목축인 사냥 도시락 → 하트 +2
	GameState.nest = 5
	GameState.hen_eggs = 0
	_check(main.coop_action(&"take_nest") and GameState.hen_eggs == 5 and GameState.nest == 0, "둥지 달걀 꺼내기")
	main._set_active(main.rancher)
	GameState.crops = 1
	_check(main.coop_options().has(&"lunch") and main.coop_action(&"lunch") and GameState.lunches == 1 and GameState.hen_eggs == 3 and GameState.crops == 0, "목축인 사냥 도시락 (달걀 %d · 무 %d)" % [Config.LUNCH_EGGS, Config.LUNCH_CROPS])
	main._set_active(main.farmer)
	_check(main.supply_options().has(&"display_hen_eggs") and main.supply_action(&"display_hen_eggs") and GameState.displayed_hen_eggs == 3, "달걀 진열")
	var m_m0 := GameState.money
	main.next_day()
	_check(GameState.money >= m_m0 + 3 * Config.HEN_EGG_PRICE and GameState.displayed_hen_eggs == 0, "진열한 달걀이 밤사이 팔림")
	GameState.hunts_today = 0
	main.enter_hunt(null, 0)
	_check(main.hunt.lunch and GameState.lunches == 0 and main.hunt.hearts == main.hunt.max_hearts() and main.hunt.max_hearts() == Config.HUNTER_HEARTS + Wearables.bonus_hearts(&"hunter") + Config.LUNCH_HEARTS, "사냥 도시락: 들어갈 때 먹고 하트 +%d" % Config.LUNCH_HEARTS)
	main.leave_hunt()

	# 38) 테스트용 시작 지점 (2026-09-29 사용자: "매번 처음부터 시작하는게 조금 어려운거같아")
	_check(not main.menu_open, "테스트 장면 안에서는 시작 지점 창이 안 뜸")
	main.queue_free()
	await get_tree().process_frame
	for sid: StringName in TestStarts.ids():
		var ts: Node2D = load("res://scenes/main.tscn").instantiate()
		add_child(ts)
		await get_tree().process_frame
		var ok := TestStarts.apply(ts, sid)
		var spec := TestStarts.find(sid)
		var want_creatures: int = spec.get("creatures", []).size()
		var farmers: int = ts.creatures.filter(func(x: Creature) -> bool: return x.job == CreatureJobs.FARM).size()
		var ts_w: Dictionary = Wearables.weapon()
		var weapons: Array = spec.get("weapons", [])
		var weapon_ok: bool = weapons.is_empty() or ts_w.name.contains(Wearables.ITEMS[weapons[0]].name)
		var gear_n := 0
		for who: StringName in [&"farmer", &"hunter"]:
			gear_n += Wearables.worn_by(who).size() + GameState.bag[who].size()
		var want_gear: int = weapons.size() + spec.get("armor", []).size() + spec.get("crafted", []).size() + spec.get("shop", []).size()
		_check(ok and GameState.day == spec.get("day", 1) and GameState.money == spec.get("money", Config.START_MONEY)
			and ts.creatures.size() == want_creatures and GameState.waypoints == Array(spec.get("waypoints", [0]), TYPE_INT, "", null)
			and GameState.forge_state == spec.get("forge", 0) and weapon_ok and gear_n == want_gear,
			"시작 지점 %s: %d일 · 돈 %d · 크리처 %d (농사 %d) · 웨이포인트 %s · 대장간 %d · 무기 %s · 장비 %d/%d" % [
				sid, GameState.day, GameState.money, ts.creatures.size(), farmers, GameState.waypoints, GameState.forge_state, ts_w.name, gear_n, want_gear])
		if sid == &"forge_ready":
			_check(ts.restore_forge() and ts.smith.visible, "대장간 고치기 직전: 바로 고칠 수 있음")
		if sid == &"barn":
			_check(GameState.barn_state == 2 and ts.rancher.visible and GameState.hens == spec.hens and GameState.lunches == 1, "축사 복구 뒤: 목축인 · 암탉 %d · 도시락" % GameState.hens)
		if sid != &"fresh":
			_check(GameState.hunter_unlocked and GameState.village_eggs.is_empty() and ts.farm.get_cell(Config.FIELD_PLOTS[0].position).planted, "%s: 사냥꾼 열림 · 밭 심어 둠" % sid)
			# 가장 깊은 웨이포인트에서 바로 사냥 들어가기
			var deepest: int = GameState.waypoints.max()
			ts.hunter.position = ts.hunt_gate.position
			_check(ts.enter_hunt(null, deepest) and ts.hunt != null, "%s: %s 웨이포인트로 사냥 들어감" % [sid, Config.HUNT_ZONES[deepest].name])
			ts.leave_hunt()
			ts.next_day()
			_check(GameState.day == spec.day + 1, "%s: 하루 넘기기" % sid)
		ts.queue_free()
		await get_tree().process_frame

	# 41) 저장/불러오기 (2026-09-30 사용자 선택 C 디아2식): 저장 → 장면을 버리고 → 새 장면에 불러오면 모든 상태가 같다
	await _save_load_checks()

	print("SMOKE TEST: %s (%d failures)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(1 if _failures > 0 else 0)


## 41) 저장/불러오기. 여러 가지가 섞인 70일째 (축사 복구 뒤) 를 만들어 저장하고 되살린다.
func _save_load_checks() -> void:
	SaveGame.dir = "user://smoke_saves"
	DirAccess.make_dir_recursive_absolute(SaveGame.dir)
	for i in range(1, SaveGame.SLOTS + 1):
		SaveGame.erase(i)
	var a: Node2D = load("res://scenes/main.tscn").instantiate()
	add_child(a)
	await get_tree().process_frame
	_check(a.save_slot == -1 and not a.autosave() and not SaveGame.exists(1), "테스트 장면은 슬롯이 없어 저절로 저장하지 않음")
	TestStarts.apply(a, &"barn")
	# 섞인 상태: 시각 · 알 세 군데 · 부화 중 · 가방 · 창고 장비 · 밭 물 · 풀밭 · 병아리 · 들고 있는 크리처 · 사냥꾼으로 전환
	GameState.minutes = 14 * 60 + 30
	GameState.hunter_eggs.append(load(TestStarts.SPECIES[&"tiger"]))
	GameState.village_eggs.append(load(TestStarts.SPECIES[&"slime"]))
	GameState.farmer_eggs.append(load(TestStarts.SPECIES[&"gold_toad"]))
	a.incubating_days = 2
	a.incubating_species = load(TestStarts.SPECIES[&"will_o"])
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	for n in 3:
		Wearables.gain_rolled(Wearables.roll_gear(rng, &"rare"))
	var stash_id := StringName("gear_%d" % (GameState.gear_serial + 1))
	Wearables.gain_rolled(Wearables.roll_gear(rng, &"magic"))
	if GameState.gear.has(stash_id) and stash_id in GameState.bag.hunter:
		GameState.bag.hunter.erase(stash_id)
		GameState.stash.append(stash_id)
	GameState.chicks.assign([2, 1])
	GameState.nest = 3
	GameState.fed = 1
	GameState.displayed_crops = 5
	GameState.tonic_day = 69
	GameState.tool_levels[Farm.Work.HARVEST] = 1
	a.farm.do_work(Farm.Work.WATER, Vector2i(2, 2))
	a.forage.water(Vector2i(15, 12))
	var carried: Creature = a.creatures[5]
	a.farmer.position = Farm.center_of(Vector2i(9, 9))
	carried.pick_up(a.farmer)
	a.creatures[0].data.radius_level = 3
	a._set_active(a.hunter)
	a.hunter.position = Farm.center_of(Vector2i(19, 6))
	a.hunter.facing = Vector2i.LEFT
	a.tool_index = 2
	a.save_slot = 2
	var before: Dictionary = SaveGame.snapshot(a)
	_check(a.autosave() and SaveGame.exists(2) and not SaveGame.exists(1), "슬롯 2에 저장 (다른 슬롯은 그대로 비어 있음)")
	var sum := SaveGame.summary(2)
	_check(sum.day == 70 and sum.money == GameState.money, "슬롯 요약: %d일째 · %d원" % [sum.day, sum.money])
	var gear_before := GameState.gear.duplicate(true)
	var creatures_before: Array = a.creatures.map(func(c: Creature) -> String: return c.describe())
	a.queue_free()
	await get_tree().process_frame

	# 게임을 끈 것처럼: 전역 상태를 처음으로 돌리고 새 장면을 띄운 뒤 불러온다
	GameState.reset()
	var b: Node2D = load("res://scenes/main.tscn").instantiate()
	add_child(b)
	await get_tree().process_frame
	_check(GameState.day == 1 and b.creatures.is_empty(), "새 장면은 1일째 빈 마을")
	_check(SaveGame.load_into(b, 2), "슬롯 2 불러오기")
	var after: Dictionary = SaveGame.snapshot(b)
	var diff: Array[String] = []
	for k: String in before:
		if k == "gs":
			for g: String in before.gs:
				if before.gs[g] != after.gs.get(g):
					diff.append("gs." + g)
		elif before[k] != after.get(k):
			diff.append(k)
	_check(diff.is_empty(), "저장 전과 불러온 뒤 전체 상태가 같음 %s" % (diff if not diff.is_empty() else ""))
	_check(GameState.gear == gear_before and b.creatures.map(func(c: Creature) -> String: return c.describe()) == creatures_before, "장비 옵션 · 크리처 능력치 · 일 · 훈련이 그대로 (%d개 · %d마리)" % [GameState.gear.size(), b.creatures.size()])
	_check(GameState.bag.hunter is Array and GameState.bag.hunter.get_typed_builtin() == TYPE_STRING_NAME and GameState.hunter_eggs.get_typed_class_name() == &"Resource" or GameState.hunter_eggs[0] is CreatureSpecies, "가방 · 알 목록 타입이 그대로")
	_check(GameState.hunter_eggs.size() == 1 and GameState.hunter_eggs[0].id == &"tiger" and GameState.farmer_eggs.back().id == &"gold_toad" and b.incubating_days == 2 and b.incubating_species.id == &"will_o", "알 (사냥꾼 · 공급함 · 농부) · 부화기 그대로")
	_check(b.forge.label == "대장간" and b.scrap_heap != null and b.smith.visible and b.yak.label == "약방" and b.herb_bed != null and b.alchemist.visible and b.barn.label == "축사" and b.rancher.visible, "대장간 · 약방 · 축사 고친 모습 · 일꾼 셋 (값을 다시 치르지 않음)")
	_check(GameState.hens == 3 and GameState.chicks == [2, 1] and GameState.nest == 3, "닭장 (암탉 · 병아리 · 둥지) 그대로")
	_check(b.farm.get_cell(Vector2i(2, 2)).watered and b.farm.get_cell(Vector2i(7, 6)) != null and b.forage.watered.has(Vector2i(15, 12)), "밭 네 구역 · 물 준 칸 · 물 준 풀밭")
	_check(b.active == b.hunter and b.hunter.facing == Vector2i.LEFT and b.creatures[5].carried_by == null and b.creatures[5].home == Vector2i(9, 9), "사냥꾼으로 이어 함 · 들고 있던 크리처는 농부 발밑에 놓임")
	_check(is_equal_approx(GameState.minutes, 14 * 60 + 30) and b.save_slot == -1, "시각 오후 2:30 그대로")
	# 불러온 뒤에도 게임이 이어진다: 하루 넘기기 · 사냥
	var eggs_n := GameState.hunter_eggs.size()
	b.next_day()
	_check(GameState.day == 71 and b.incubating_days == 1, "불러온 뒤 하루 넘기기")
	b.hunter.position = b.hunt_gate.position
	_check(b.enter_hunt(null, 5) and b.hunt != null, "불러온 뒤 밀목 웨이포인트로 사냥")

	# 사냥터 안에서 저장하고 나가기: 마을로 돌아온 채로 저장
	b.save_slot = 3
	b.open_menu(&"pause")
	_check(b.hunt.process_mode == Node.PROCESS_MODE_DISABLED and b._menu_options == [&"resume", &"save_quit"], "사냥 중 Esc: 사냥터가 멈추고 계속하기 · 저장하고 나가기")
	b.close_menu()
	b.leave_hunt()
	_check(SaveGame.exists(3) and SaveGame.read(3).gs.hunts_today == 1 and SaveGame.read(3).gs.hunter_eggs.size() == eggs_n, "사냥터에서 돌아오면 저절로 저장")

	# 처음 화면: 슬롯 셋 + 지우기, 지우기는 두 번 눌러야
	b.open_menu(&"title")
	_check(b._menu_options == [&"slot_1", &"slot_2", &"slot_3", &"delete"] and b.save_menu_text(&"slot_1").contains("새 게임") and b.save_menu_text(&"slot_2").contains("70일째"), "처음 화면: 빈 슬롯은 새 게임, 쓴 슬롯은 날짜 · 이어하기")
	b.save_menu_confirm(&"delete")
	b.save_menu_confirm(&"slot_3")
	_check(SaveGame.exists(3), "지우기: 한 번 고르면 아직 안 지움")
	b.save_menu_confirm(&"slot_3")
	_check(not SaveGame.exists(3) and b.menu_kind == &"title", "지우기: 한 번 더 고르면 지우고 처음 화면")
	b.close_menu()
	b.queue_free()
	await get_tree().process_frame

	# 옛 저장 파일 (나중에 늘어난 변수가 없음): 없는 변수는 처음 값으로
	var old := SaveGame.read(2)
	old.gs.erase("lunches")
	old.gs.erase("barn_state")
	GameState.reset()
	var c: Node2D = load("res://scenes/main.tscn").instantiate()
	add_child(c)
	await get_tree().process_frame
	SaveGame.apply(c, old)
	_check(GameState.day == 70 and GameState.lunches == 0 and GameState.barn_state == 0 and c.barn == null, "옛 저장 파일: 없는 변수는 처음 값으로 읽음")
	c.queue_free()
	await get_tree().process_frame
	for i in range(1, SaveGame.SLOTS + 1):
		SaveGame.erase(i)
	SaveGame.dir = "user://"


## c 로 대장간 앞에 서서 F
func forge_f(main: Node2D, c: Character) -> void:
	main._set_active(c)
	c.position = Farm.center_of(Config.FORGE_RECT.position + Vector2i(1, Config.FORGE_RECT.size.y))
	main.interact()


## 열린 선택창 · 가방 창을 닫는다
func close_all(main: Node2D) -> void:
	main.close_menu()
	main.close_inventory()
	if main.hunt:
		main.leave_hunt()


func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		_failures += 1


func _action(action: StringName) -> InputEventAction:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	return ev
