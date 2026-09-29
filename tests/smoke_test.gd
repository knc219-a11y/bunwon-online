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
	_check(sh.slimes.is_empty() and not sh.path_open, "마지막 구역 대장 뒤엔 길이 열리지 않음 (다음 구역은 아직)")
	var toad_eggs := sh.drops.filter(func(d: Dictionary) -> bool: return d.species == CreatureCatalog.GOLD_TOAD)
	_check(toad_eggs.size() == 1, "대장 금두꺼비는 알 확률에 걸리면 금두꺼비 알을 남김")
	main.hunter.position = sh.next_area().get_center()
	_check(not sh.advance() and sh.zone == 1, "더 깊이 갈 수 없음")
	main.hunter.position = sh.exit_area().get_center()
	main.interact()
	_check(main.hunt == null, "아래 입구 F로 마을로")
	# 다음 날: 사냥터 입구에서 웨이포인트를 고른다
	main.next_day()
	main.hunter.position = main.hunt_gate.position
	main._hunter_interact()
	_check(main.menu_open and main.menu_kind == &"waypoint" and main.waypoint_options() == [&"zone_0", &"zone_1", &"close"], "웨이포인트가 둘이면 어디서 시작할지 물음")
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
