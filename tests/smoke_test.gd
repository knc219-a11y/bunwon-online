extends Node
## 헤드리스 스모크 테스트. 프로토타입 핵심 순환을 코드로 한 바퀴 돌린다.
## 실행: godot --headless --path . res://tests/smoke_test.tscn

## 피해 단위 (2026-10-03: 한 대 1 → DMG_UNIT)
const U := Config.DMG_UNIT
var _failures := 0


func _ready() -> void:
	# 사냥터 드롭표는 19)에서 따로 본다. 그 전까지는 알 보장만 보도록 끈다.
	HuntGround.loot_enabled = false
	# 사냥 손맛 · 몰아잡기 떼 (2026-10-02)는 44)에서 따로 본다. 그 전 구역 · 몬스터 수 검사는 예전 한 마리씩 기준.
	HuntGround.feel = false
	HuntGround.swarm = false
	HuntGround.bow_style = &""
	var main: Node2D = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame

	# 1) 농부 직접 농사: 갈기 → 심기 → 물주기 → (3일) → 수확
	var farmer: Character = main.player
	var cell := fc(1, 2)
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
	_check(GameState.open_plots == 1 and farm0.get_cell(fc(6, 5)) != null and farm0.get_cell(fc(7, 2)) == null, "처음엔 첫 구역(6x4)만 밭")
	_check(not farm0.do_work(Farm.Work.TILL, fc(7, 2)), "잠긴 구역은 갈 수 없음")
	_check(farm0.find_work(Farm.Work.TILL, fc(7, 3), 1) == fc(6, 3), "잠긴 구역은 크리처 일감에서도 빠짐")
	farmer.position = main.supply_box.position
	main.interact()
	_check(main.supply_options().has(&"expand_field") and main.supply_option_text(&"expand_field").contains("300원"), "공급함에 밭 넓히기 (오른쪽 구역 300원)")
	GameState.money = 299
	_check(not main.supply_action(&"expand_field") and GameState.open_plots == 1 and GameState.money == 299, "돈이 모자라면 못 넓힘")
	GameState.money = 300 + 500 + 800
	for want in [fc(7, 2), fc(1, 6), fc(7, 6)]:
		_check(main.supply_action(&"expand_field") and farm0.do_work(Farm.Work.TILL, want), "구역을 사서 넓히고 갈기 %s" % want)
		farm0.get_cell(want).tilled = false
	_check(GameState.money == 0 and GameState.open_plots == 4, "300 → 500 → 800원으로 세 구역 열림")
	_check(not main.supply_options().has(&"expand_field"), "다 넓히면 선택창에서 빠짐")
	main.close_menu()

	# 1-2) 도구 강화 (A 첫 조각): 괭이·물뿌리개를 공급함에서 사면 앞 3칸 일자에 한 번에 쓴다
	_check(main.supply_options().has(&"upgrade_hoe") and main.supply_option_text(&"upgrade_can").contains("큰 물뿌리개"), "공급함에 도구 손보기")
	_check(not main.supply_action(&"upgrade_hoe") and GameState.tool_level(Farm.Work.TILL) == 0, "돈이 모자라면 도구를 못 바꿈")
	var row := fc(8, 3)
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
	_check(farmer._wear.size() == 3 and farmer.outfit == &"farmer", "마을에서는 밭 옷 덧그림 (모자 · 옷 · 신발)")
	farmer.facing = Vector2i.LEFT
	farmer._update_sprite()
	_check(farmer._wear[0].frame_coords == farmer._sprite.frame_coords and farmer._wear[0].flip_h, "덧그림이 몸과 같은 칸 · 좌우 반전")
	var sow_row := fc(8, 4)
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
	farmer.position = main.hunt_gate.position
	main.interact()
	_check(not main.menu_open and main.hunt == null, "첫 슬라임 배치 전에는 사냥터 입구가 잠김")
	_check(farmer == main.player and main.farmer != farmer and main.farmer.npc and not main.player.npc, "조작은 주인공 하나, 농부는 마을 사람 NPC")

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
	var home := fc(6, 5)
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

	# 5) 같은 주인공이 사냥터 입구 → 알 획득 → 부화기
	var hunter: Character = main.player
	hunter.position = main.hunt_gate.position
	main.interact()
	# 처음엔 직업부터 고른다 (2026-10-03). 전사 → 사냥칼 그대로, 피해 +20%
	_check(main.menu_open and main.menu_kind == &"class" and main.class_options() == [&"warrior", &"archer", &"mage", &"close"], "처음 사냥터 입구 F → 직업 고르기 창")
	main._unhandled_input(_action(&"interact"))
	_check(GameState.hunter_class == &"warrior" and GameState.stat_points == 0 and Wearables.weapon().kind == &"melee", "전사를 고름 (Lv 1 이라 스탯 포인트 0, 사냥칼 그대로)")
	# 밭에 크리처가 있으면 누구랑 갈지 먼저 묻는다. 여기서는 혼자 간다.
	_check(main.menu_open and main.menu_kind == &"companion" and main.companion_options() == [&"companion_0", &"respec", &"solo"], "이어서 누구랑 갈까? 창 (크리처 1 + 직업 · 초기화 + 혼자)")
	_check(main.companion_option_text(&"companion_0").contains("물총"), "물 슬라임은 물총으로 돕는다고 표시")
	main._unhandled_input(_action(&"move_down"))
	main._unhandled_input(_action(&"move_down"))
	main._unhandled_input(_action(&"interact"))
	var hunt: HuntGround = main.hunt
	_check(hunt != null and hunt.companion == null and not main.menu_open and not main.farm.visible and not main.farmer.visible and hunter.visible and hunter.outfit == &"hunter" and hunt.slimes.size() == Config.WILD_SLIME_COUNT, "사냥터 입구 F → 사냥터 화면 (사냥 옷으로 갈아입음), 야생 슬라임 %d마리" % Config.WILD_SLIME_COUNT)
	hunt.set_ai(false)
	_check(hunt.life == hunt.max_life() and hunt.max_life() == Config.HUNTER_HP, "체력 가득 (%d) 으로 시작" % Config.HUNTER_HP)
	# Space(바라보는 쪽)로 두 번 휘두르면 쓰러진다
	var wild: WildSlime = hunt.slimes[0]
	hunter.facing = Vector2i.UP
	wild.position = hunter.feet() + Vector2(0, -8 - Config.SWING_REACH)
	var full_hp := HunterSkills.monster_hp(0, Config.WILD_SLIME_HP)
	var knife := HunterClass.hunter_damage(1, &"melee")
	_check(hunt.swing() == 1 and wild.hp == full_hp - knife and knife == roundi(Config.DMG_UNIT * (1.0 + Config.CLASS_WEAPON_BONUS)), "휘두르기 한 번 맞히면 체력 -%d (%d, 전사 +20%%)" % [knife, full_hp])
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
	_check(hunt.life == hunt.max_life() - wild3.damage and wild3.damage == Config.HP_PER_HEART, "부딪히면 체력 -%d, 바로 다시 맞지는 않음" % wild3.damage)
	wild3.position = Vector2(20 * Config.TILE, 5 * Config.TILE)
	# 떨어진 알 줍기
	hunter.position = hunt.drops[0].at - Vector2(0, Character.FEET_Y)
	hunt.tick(0.01)
	_check(hunt.picked.size() == 1 and hunt.drops.is_empty(), "떨어진 알 줍기")
	hunter.position = hunt.spawn_at()
	main.interact()
	_check(main.hunt == null and main.farm.visible and GameState.farmer_eggs.size() == 1, "아래 입구 F로 마을에 돌아오면 알 1개 (주인공 손에)")
	_check(main._near(main.hunt_gate) and hunter.walk_area == Rect2(), "마을 사냥터 입구 앞으로 돌아옴")
	main.interact()
	main.close_menu()
	_check(main.hunt == null and GameState.farmer_eggs.size() == 1, "사냥터는 하루 한 번")

	# 두 번째 슬라임은 역할 없이 태어나 직접 정한다
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
	_check(Farm.CROPS.get_width() == 24 * 4 and Farm.CROPS.get_height() == 24 * Config.CROPS.size(), "작물 시트 96x96 (무 · 감자 · 고추 · 배추)")
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
	var junction: Vector2i = main.farm._path.keys().filter(func(q: Vector2i) -> bool: return [Vector2i.UP, Vector2i.RIGHT, Vector2i.LEFT].all(func(o: Vector2i) -> bool: return main.farm._is_path(q + o)))[0]
	_check(main.farm._mask(junction, main.farm._is_path) & (1 | 2 | 8) == 1 | 2 | 8, "흙길 갈림길은 이어진 방향마다 연결")

	# 11) 마을 오브젝트: 그림 크기와 칸 수, 흙길 끝 칸에서 상호작용
	var props := {
		main.incubator: [Vector2(48, 48), Vector2i(2, 2), Config.INCUBATOR_RECT.position + Vector2i(1, 2)],
		main.supply_box: [Vector2(48, 44), Vector2i(2, 1), Config.SUPPLY_RECT.position + Vector2i(0, -1)],
		main.hunt_gate: [Vector2(72, 56), Vector2i(3, 2), Config.HUNT_GATE_RECT.position + Vector2i(1, 2)],
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
	_check(farm._mask(Config.FENCE_RECT.position, farm._is_fence) == 2 | 4, "울타리 왼쪽 위 모서리는 오른쪽·아래 연결")
	_check(not farm._is_fence(Config.FENCE_GAPS[0]) and farm._is_path(Config.FENCE_GAPS[0]), "흙길이 들어오는 칸은 울타리를 비움")
	for x in Config.FIELD_RECT.size.x:
		for y in Config.FIELD_RECT.size.y:
			if farm._is_fence(Config.FIELD_RECT.position + Vector2i(x, y)):
				_check(false, "밭 칸에 울타리가 있으면 안 됨")
	var house_front := Vector2i(main.HOUSE_RECT.position.x + 2, main.HOUSE_RECT.end.y)
	_check(farm._is_path(house_front) and farm._mask(house_front, farm._is_path) != 0, "농부 집 현관 앞까지 흙길이 이어짐")
	# 12-1) 넓은 마을 (2026-10-01): 맵이 화면보다 크면 마을 카메라가 조작 중인 캐릭터를 따라가고 맵 가장자리에서 멈춘다
	var world_px := Vector2(Config.MAP_SIZE * Config.TILE)
	_check(world_px.x > 640 and world_px.y > 360 and main.camera.is_current() and Vector2(main.camera.limit_right, main.camera.limit_bottom) == world_px, "마을 맵 %s칸은 화면보다 넓고 카메라 끝 = 맵 끝" % Config.MAP_SIZE)
	var cam_who: Character = main.player
	var cam_keep := cam_who.position
	cam_who.position = Farm.center_of(Config.MAP_SIZE - Vector2i(2, 2))
	# process_frame 은 _process 앞에 오니까 한 프레임 더
	await get_tree().process_frame
	await get_tree().process_frame
	_check(main.camera.position == cam_who.position.round() and main.view_center() == world_px - Vector2(320, 180), "카메라가 캐릭터를 따라가고 맵 구석에선 멈춤")
	cam_who.position = main.supply_box.position + Vector2(0, 12)
	var supply_on_screen: Vector2 = main.to_screen(main.supply_box.position)
	_check(Rect2(0, 0, 640, 360).has_point(supply_on_screen) and supply_on_screen.distance_to(Vector2(320, 180)) < 40, "공급함 옆 창은 화면 안 공급함 자리에 뜸")
	cam_who.position = cam_keep

	# 13) 충돌과 앞뒤 가림: 집·나무는 밑동만 막고, 뒤로 가면 반투명. 울타리는 입구만 열림
	var house: Prop = main.house
	farmer.position = Farm.center_of(house_front)
	for i in 30:
		farmer.step(Vector2(0, -2))
	_check(farmer.feet().y >= house.sort_y(), "집 벽으로는 못 들어감")
	farmer.position = Farm.center_of(main.HOUSE_RECT.position + Vector2i(-1, 1)) + Vector2(0, -4)
	for i in 40:
		farmer.step(Vector2(1.5, 0))
	await get_tree().process_frame
	_check(farmer.position.x > Farm.center_of(main.HOUSE_RECT.position + Vector2i(1, 1)).x, "집 지붕 뒤로는 지나감")
	_check(farmer.z_index < house.z_index, "집 뒤에 있으면 집보다 먼저 그림")
	main.update_fading()
	_check(house.faded, "집에 가려지면 집이 반투명")
	farmer.position = Farm.center_of(house_front)
	await get_tree().process_frame
	main.update_fading()
	_check(farmer.z_index > house.z_index and not house.faded, "집 앞에 있으면 캐릭터가 앞, 집은 그대로")
	var tree_cell: Vector2i = Config.PERSIMMON_CELLS.filter(func(t: Vector2i) -> bool: return not farm._is_path(t + Vector2i(0, 2)) and t.y + 2 < Config.MAP_SIZE.y)[0]
	farmer.position = Farm.center_of(tree_cell + Vector2i(0, 2))
	for i in 40:
		farmer.step(Vector2(0, -1.5))
	_check(farmer.feet().y > Farm.center_of(tree_cell).y, "감나무 밑동은 막힘")
	farmer.position = Farm.center_of(fc(6, 3))
	for i in 40:
		farmer.step(Vector2(0, -2))
	_check(farmer.cell().y >= Config.FENCE_RECT.position.y + 1, "밭 울타리는 못 넘음")
	farmer.position = Farm.center_of(Config.FENCE_GAPS[0] + Vector2i(2, 0))
	for i in 60:
		farmer.step(Vector2(-2, 0))
	_check(farmer.cell().x <= Config.FIELD_RECT.end.x - 1, "흙길 입구로는 밭에 들어감")
	# 슬라임은 울타리 너머 칸으로 깡충 뛰지 않는다
	var outside := Vector2i(Config.FENCE_RECT.end.x, Config.FIELD_RECT.position.y + 2)
	var inside := Vector2i(Config.FIELD_RECT.end.x - 1, Config.FIELD_RECT.position.y + 2)
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
	carried.place(fc(6, 6))

	# 14) 잠자기 (A②): 집 현관에서 F → 밤 1초 → 아침 카드 → F로 일어남
	farmer.position = Farm.center_of(fc(10, 6))
	_check(not main.near_door(), "현관에서 멀면 잠잘 수 없음")
	var sleep_cell := fc(3, 3)
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
	GameState.crop_stars = {}
	GameState.money = 0
	GameState.displayed_crops = 0
	var seeds_before := GameState.seeds
	farmer.position = main.supply_box.position
	main.interact()
	_check(main.menu_open and farmer.frozen, "선택창이 열리면 캐릭터는 멈춤")
	_check(main.supply_options() == [&"display_crops", &"buy_seeds", &"crops", &"train", &"close"], "알이 없으면 진열·씨앗·밭 작물(퇴비)·크리처 훈련·닫기만")
	_check(not main.supply_action(&"buy_seeds") and GameState.seeds == seeds_before, "돈이 모자라면 씨앗을 못 삼")
	main._unhandled_input(_action(&"move_down"))
	_check(main.menu_index == 1, "W/S로 고르기")
	main._unhandled_input(_action(&"move_up"))
	main._unhandled_input(_action(&"interact"))
	_check(GameState.crops == 0 and GameState.displayed_crops == 3, "F로 무 3개 진열")
	_check(main.supply_box.badge.contains("무 3"), "공급함에 진열한 무 표시")
	_check(main.menu_open and main.supply_options() == [&"buy_seeds", &"crops", &"train", &"close"], "진열 뒤에도 선택창은 열려 있음")
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
		var k: Creature = main._hatch(CreatureCatalog.SLIME, Config.FORAGE_CELLS[0])
		weakest = minf(weakest, k.data.base_work_speed)
		smallest = mini(smallest, k.data.base_radius)
		main.creatures.erase(k)
		k.queue_free()
	_check(weakest >= Config.FIRST_CREATURE_MIN_WORK_SPEED and smallest >= Config.FIRST_CREATURE_MIN_RADIUS, "사냥칼이 있으면 능력치 바닥 보장")

	# 17) 사냥터에서 쓰러져도 주운 것(떨어진 알 포함)은 그대로, 다음 날 다시 들어갈 수 있다
	main.next_day()
	var eggs_before := GameState.farmer_eggs.size()
	main.player.position = main.hunt_gate.position
	main.interact()
	main.menu_index = main.companion_options().size() - 1
	main.menu_confirm()
	var h2: HuntGround = main.hunt
	_check(h2 != null, "자고 나면 다시 사냥터에 들어감")
	h2.set_ai(false)
	var w: WildSlime = h2.slimes[0]
	w.hp = 1
	main.player.facing = Vector2i.UP
	w.position = main.player.feet() + Vector2(0, -8 - Config.SWING_REACH)
	h2.swing()
	_check(h2.drops.is_empty(), "새 날 첫 처치라도 알은 보장되지 않음 (2026-09-29 드롭률 낮춤)")
	HuntGround.egg_roll = 0.0
	var w1b: WildSlime = h2.slimes[0]
	w1b.hp = 1
	w1b.position = main.player.feet() + Vector2(0, -8 - Config.SWING_REACH)
	h2.tick(Config.SWING_COOLDOWN)
	h2.swing()
	_check(h2.drops.size() == 1, "알 확률에 걸리면 알이 떨어짐")
	h2.life = 1
	var w2: WildSlime = h2.slimes[0]
	w2.position = main.player.feet()
	h2.tick(0.01)
	_check(main.hunt == null and main.farm.visible, "하트가 0이 되면 쓰러져 마을로 돌아옴")
	_check(GameState.farmer_eggs.size() == eggs_before + 1, "쓰러져도 떨어진 알은 챙겨 옴")
	_check(main._near(main.hunt_gate), "쓰러지면 사냥터 입구 앞으로")

	# 18) 크리처 동행 (A. 따라오는 동료): 입구에서 고른 크리처가 따라와 알아서 싸우고, 돌아오면 제자리로
	main.next_day()
	var buddy: Creature = main.companion_candidates()[0]
	var buddy_home := buddy.home
	var buddy_job := buddy.job
	var buddy_pos := buddy.position
	main.player.position = main.hunt_gate.position
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
	h3.companion.position = main.player.feet() + Vector2(0, 20)
	for other in h3.slimes:
		other.position = h3.companion.position + Vector2(200, 0)
	far.position = h3.companion.position + Vector2(Config.COMPANION_SHOT_RANGE - 10, 0)
	h3.tick(0.01)
	var slime_full := HunterSkills.monster_hp(0, Config.WILD_SLIME_HP)
	_check(far.hp == slime_full - HunterClass.companion_damage(1), "물총은 먼 거리의 야생 슬라임을 맞힘")
	far.position = h3.companion.position + Vector2(Config.COMPANION_SHOT_RANGE - 10, 0)
	h3.tick(0.01)
	_check(far.hp == slime_full - HunterClass.companion_damage(1), "물총은 간격을 두고 쏜다")
	far.position = h3.companion.position + Vector2(Config.COMPANION_SHOT_RANGE - 10, 0)
	far.hp = mini(far.hp, HunterClass.companion_damage(1))
	h3.tick(h3.companion.attack_interval())
	_check(h3.slimes.size() == Config.WILD_SLIME_COUNT - 1 and h3.drops.size() == 1, "크리처가 쓰러뜨린 슬라임도 알 확률은 같음")
	# 따라다니기
	h3.companion_ai = true
	for other in h3.slimes:
		other.position = main.player.feet() + Vector2(0, -200)
	h3.companion.position = main.player.feet() + Vector2(80, 0)
	for i in 30:
		h3.tick(0.05)
	_check(h3.companion.position.distance_to(main.player.feet()) <= Config.COMPANION_FOLLOW_DISTANCE + 4.0, "사냥꾼 뒤를 따라온다")
	_check(h3.life == h3.max_life(), "크리처 동행 중에도 체력은 그대로 (크리처는 다치지 않음)")
	# 돌아오면 원래 자리·원래 일
	var eggs_before_buddy := GameState.farmer_eggs.size()
	main.player.position = h3.spawn_at()
	main.interact()
	_check(main.hunt == null and buddy.visible and buddy.can_process(), "돌아오면 크리처가 농장에 다시 나타나 일한다")
	_check(buddy.home == buddy_home and buddy.job == buddy_job and buddy.position == buddy_pos, "원래 자리·원래 일 그대로")
	_check(GameState.farmer_eggs.size() == eggs_before_buddy + 1, "크리처 덕에 떨어진 알도 챙겨 옴")
	# 땅 슬라임은 붙어서 박치기
	main.next_day()
	var earth_buddy: Creature = main._hatch(CreatureCatalog.SLIME, fc(3, 3))
	earth_buddy.data.set_element(load("res://data/creatures/elements/earth.tres"))
	main.player.position = main.hunt_gate.position
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
		other.position = main.player.feet() + Vector2(0, -150)
	h4.companion.position = main.player.feet() + Vector2(0, 20)
	near.position = h4.companion.position + Vector2(40, 0)
	h4.tick(0.01)
	_check(near.hp == near.max_hp, "박치기는 멀리서는 못 때림")
	near.position = h4.companion.position + Vector2(Config.COMPANION_BUMP_RANGE - 4, 0)
	var before_x := near.position.x
	h4.tick(0.01)
	_check(near.hp == near.max_hp - HunterClass.companion_damage(1) and near.position.x - before_x > 14.0, "붙어서 박치기, 더 멀리 밀쳐냄")
	h4.companion_ai = true
	near.position = h4.companion.position + Vector2(50, 0)
	var gap := h4.companion.position.distance_to(near.position)
	h4.tick(0.1)
	_check(h4.companion.position.distance_to(near.position) < gap, "박치기 크리처는 가까운 야생 슬라임에게 다가간다")
	main.player.position = h4.spawn_at()
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
	main.player.position = main.hunt_gate.position
	main.interact()
	main.menu_index = main.companion_options().size() - 1
	main.menu_confirm()
	var h5: HuntGround = main.hunt
	h5.set_ai(false)
	var base_hearts := h5.max_life()
	# 20%가 나올 때까지 같은 자리에서 쓰러뜨린다 (시드 고정)
	h5.loot_rng.seed = 3
	var target: WildSlime = h5.slimes[0]
	target.hp = 1
	main.player.facing = Vector2i.UP
	target.position = main.player.feet() + Vector2(0, -8 - Config.SWING_REACH)
	h5.swing()
	_check(h5.slimes.size() == Config.WILD_SLIME_COUNT - 1, "사냥터에서 쓰러뜨리면 드롭표를 굴림")
	h5.loot.clear()
	h5.loot.append({kind = &"gear", id = &"acorn_helm", at = main.player.feet() + Vector2(0, 30)})
	_check(HuntLoot.label(h5.loot[0]) == "도토리 투구", "땅에 장비 이름이 보임")
	main.player.position = h5.loot[0].at - Vector2(0, Character.FEET_Y)
	h5.tick(0.01)
	_check(h5.loot.is_empty() and GameState.worn[&"hunter"].get(&"hat") == &"acorn_helm" and Wearables.is_owned(&"acorn_helm"), "주우면 바로 입음 (모자 칸)")
	_check(h5.max_life() == base_hearts + Config.HP_PER_HEART and h5.life == h5.max_life(), "도토리 투구: 최대 체력 +10, 그만큼 채워짐")
	# 빨간 물약
	GameState.potions = 1
	h5.life = h5.max_life() - 1
	main._unhandled_input(_action(&"use_potion"))
	_check(h5.life == h5.max_life() and GameState.potions == 0, "1 키로 빨간 물약을 마시면 하트 +1")
	GameState.potions = 1
	_check(not h5.drink_potion() and GameState.potions == 1, "하트가 가득하면 물약을 아낌")
	# 나머지 세트 조각과 잡템·돈은 땅에 둔 채 떠나도 챙긴다
	var money_before := GameState.money
	h5.loot.append({kind = &"gear", id = &"forest_cape", at = Vector2(5 * Config.TILE, 5 * Config.TILE)})
	h5.loot.append({kind = &"gear", id = &"feather_boots", at = Vector2(6 * Config.TILE, 5 * Config.TILE)})
	h5.loot.append({kind = &"junk", at = Vector2(7 * Config.TILE, 5 * Config.TILE)})
	h5.loot.append({kind = &"money", amount = 20, at = Vector2(8 * Config.TILE, 5 * Config.TILE)})
	var junk_before := GameState.junk
	main.player.position = h5.spawn_at()
	main.interact()
	_check(main.hunt == null and GameState.junk == junk_before + 1 and GameState.money == money_before + 20, "떠날 때 안 주운 젤리·돈도 챙김")
	_check(Wearables.set_complete(&"forest", &"hunter") and Wearables.bonus_hearts(&"hunter") == 2, "숲 공터 세트 완성: 하트 +1 더")
	_check(is_equal_approx(Wearables.swing_radius(&"hunter"), 24.0) and is_equal_approx(Wearables.speed_mult(&"hunter"), 1.25), "숲지기 망토 휘두르기 범위 · 깃털 장화 걷기 +25%")
	main.player.position = main.supply_box.position
	var money_before_sell := GameState.money
	var junk_to_sell := GameState.junk
	main.interact()
	_check(GameState.junk == 0 and GameState.money == money_before_sell + junk_to_sell * Config.JUNK_PRICE, "공급함에서 F로 젤리를 팜")
	main.close_menu()

	# 20) 디아블로식 가방 + 공용 창고 (2026-09-28 사용자 요청)
	# 지금 사냥꾼: 숲 공터 세트 다 입음, 가방에 캡모자·등산화 (주운 세트가 밀어냄)
	var hb: Array[StringName] = GameState.bag[&"hunter"]
	_check(&"ball_cap" in hb and &"hiking_shoes" in hb, "세트를 주워 입으면 입던 캡모자·등산화는 가방으로")
	main.player.position = Farm.center_of(Config.HUNTER_CELL)
	main._unhandled_input(_action(&"inventory"))
	var inv: InventoryUI = main.inventory
	_check(inv.visible and inv.character == main.player and main.player.frozen and not inv.with_stash and inv.outfit == &"farmer", "I 키로 어디서나 가방 창 (마을에서는 밭 옷부터)")
	main._unhandled_input(_action(&"outfit_swap"))
	_check(inv.visible and inv.outfit == &"hunter", "가방 창에서 Tab = 사냥 옷으로 바꿔 보기")
	var cap_i := hb.find(&"ball_cap")
	_check(inv.primary(&"bag", cap_i) and GameState.worn[&"hunter"][&"hat"] == &"ball_cap" and &"acorn_helm" in hb, "가방 캡모자 클릭 = 입기, 도토리 투구는 가방으로 바꿔 들어감")
	_check(Wearables.set_worn_count(&"forest", &"hunter") == 2 and Wearables.bonus_hearts(&"hunter") == 0, "세트 2/3 이면 보너스 없음")
	_check(inv.primary(&"equip", 0) and not GameState.worn[&"hunter"].has(&"hat") and &"ball_cap" in hb, "입은 칸 클릭 = 벗어서 가방으로 (안 입음)")
	_check(inv.secondary(&"bag", hb.find(&"acorn_helm")) and Wearables.set_complete(&"forest", &"hunter"), "오른쪽 클릭으로도 입기, 세트 다시 완성")
	main._unhandled_input(_action(&"inventory"))
	_check(not inv.visible and not main.player.frozen, "I 키로 닫기")
	# 밭 옷 장비는 사냥 옷에 못 입음 (창고로 넘겼다가 밭 옷 가방으로 꺼내 입음)
	GameState.stash.append(&"straw_hat")
	GameState.owned_wear.append(&"straw_hat")
	main.player.position = main.stash_box.position + Vector2(-Config.TILE + 4, 0)
	main.interact()
	_check(inv.visible and inv.with_stash, "창고 궤짝에서 F = 가방 + 창고 창")
	inv.swap_outfit()
	_check(inv.primary(&"stash", 0) and hb.back() == &"straw_hat" and GameState.stash.is_empty(), "창고 칸 클릭 = 가방으로 꺼내기")
	var before_hat: StringName = GameState.worn[&"hunter"].get(&"hat", &"")
	_check(not inv.secondary(&"bag", hb.size() - 1) and GameState.worn[&"hunter"].get(&"hat", &"") == before_hat, "밀짚모자 (밭 옷) 는 사냥 옷 칸에 못 입음")
	_check(inv.primary(&"bag", hb.size() - 1) and GameState.stash.size() == 1 and GameState.stash[0] == &"straw_hat", "창고가 열려 있으면 가방 칸 클릭 = 창고로 넣기")
	main.close_inventory()
	main.player.position = main.stash_box.position + Vector2(-Config.TILE + 4, 0)
	main.interact()
	_check(inv.visible and inv.character == main.player and inv.primary(&"stash", 0) and inv.secondary(&"bag", 0) and GameState.worn[&"farmer"][&"hat"] == &"straw_hat", "밭 옷 가방으로 꺼내 입음 (공용 창고)")
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
	main.player.position = main.hunt_gate.position
	main.enter_hunt()
	var h6: HuntGround = main.hunt
	main._unhandled_input(_action(&"inventory"))
	_check(inv.visible and not h6.is_processing(), "사냥터에서도 I 키 가방, 여는 동안 사냥터 멈춤")
	inv.primary(&"equip", 0)
	_check(h6.life <= h6.max_life() and h6.max_life() == Config.HUNTER_HP + Config.HP_PER_LEVEL * (GameState.hunter_level - 1), "사냥터에서 도토리 투구를 벗으면 하트 칸이 줄어듦")
	main._unhandled_input(_action(&"menu_close"))
	_check(not inv.visible and h6.is_processing(), "Esc로 닫으면 사냥터 다시 움직임")

	# 21) 장비 등급 (2026-09-28 사용자 선택 A: 디아블로2 그대로): 일반 · 마법 · 레어, 무작위 옵션, 공급함 팔기
	main.close_inventory()
	main.player.position = h6.spawn_at()
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
	main.player.refresh_wear()
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
	main.player.position = main.supply_box.position
	main.interact()
	_check(main.menu_open and main.supply_options().has(&"sell_normal") and main.supply_options().has(&"sell_gear"), "공급함 F → 일반 한꺼번에 팔기 · 가방에서 팔기")
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
	main.player.refresh_wear()
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
	main.player.position = main.hunt_gate.position
	_check(main.enter_hunt(), "다음 날 다시 사냥터에 들어감")
	var bh: HuntGround = main.hunt
	bh.set_ai(false)
	main.player.facing = Vector2i.UP
	for i in Config.WILD_SLIME_COUNT:
		var bw: WildSlime = bh.slimes[0]
		_check(not bh.boss_spawned, "셋을 다 잡기 전엔 대장이 없음 (%d)" % i)
		bw.hp = 1
		bw.position = main.player.feet() + Vector2(0, -8 - Config.SWING_REACH)
		bh.tick(Config.SWING_COOLDOWN)
		bh.swing()
	var boss_full := HunterSkills.monster_hp(0, Config.BOSS_HP)
	_check(bh.boss_spawned and bh.slimes.size() == 1 and bh.slimes[0].boss and bh.slimes[0].hp == boss_full, "셋을 다 쓰러뜨리면 대장 슬라임 1마리 (체력 %d)" % boss_full)
	var bs: WildSlime = bh.slimes[0]
	_check(not bs.ai_enabled and is_equal_approx(bs.scale.x, Config.BOSS_SCALE), "대장은 크고, 멈춤 설정을 따름")
	bh.loot.clear()
	var boss_hits := ceili(float(boss_full) / HunterClass.hunter_damage(1, &"melee"))
	for i in boss_hits:
		bs.position = main.player.feet() + Vector2(0, -8 - Config.SWING_REACH)
		bh.tick(Config.SWING_COOLDOWN)
		bh.swing()
		if i < boss_hits - 1:
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
	# 앞 섹션에서 잡은 대장은 지운다 (처음 들어가는 흐름부터 보고, 다시 들어가면 대장이 나와 있는 것은 이 섹션 끝에서 본다)
	GameState.bosses_beaten.clear()
	main.next_day()
	main.player.position = main.hunt_gate.position
	main._gate_interact()
	_check(not main.menu_open or main.menu_kind != &"waypoint", "웨이포인트가 하나면 시작 구역을 묻지 않음")
	if main.menu_open:
		main.close_menu()
	if main.hunt == null:
		main.enter_hunt()
	var sh: HuntGround = main.hunt
	sh.set_ai(false)
	_check(sh.zone == 0 and sh.slimes.size() == Config.WILD_SLIME_COUNT, "1구역 %s에서 시작" % Config.HUNT_ZONES[0].name)
	main.player.facing = Vector2i.UP
	for i in Config.WILD_SLIME_COUNT + 1:
		var sw: WildSlime = sh.slimes[0]
		_check(not sh.path_open, "대장을 쓰러뜨리기 전엔 위쪽 길이 닫힘 (%d)" % i)
		sw.hp = 1
		sw.position = main.player.feet() + Vector2(0, -8 - Config.SWING_REACH)
		sh.tick(Config.SWING_COOLDOWN)
		sh.swing()
	_check(sh.path_open and sh.slimes.is_empty(), "대장을 쓰러뜨리면 위쪽 길이 열림")
	main.player.position = Vector2(13, 8) * Config.TILE
	main.interact()
	_check(main.hunt == sh and sh.zone == 0, "위쪽 길에서 멀면 F로 넘어가지 않음")
	# 드롭이 하트 장비면 하트 칸이 바뀌므로 비교 전에 치운다
	sh.loot.clear()
	var hearts_before := sh.life - 1
	sh.life = hearts_before
	main.player.position = sh.next_area().get_center()
	main.interact()
	_check(sh.zone == 1 and not sh.path_open and not sh.boss_spawned, "위쪽 길에서 F → 2구역 %s" % z2.name)
	_check(sh.life == hearts_before and GameState.hunts_today == 1, "체력은 그대로, 같은 날 같은 사냥 (%d/%d, %d번)" % [sh.life, hearts_before, GameState.hunts_today])
	_check(1 in GameState.waypoints, "%s에 도착하면 웨이포인트가 켜짐" % z2.name)
	_check(sh.slimes.size() == z2.count and sh.slimes[0].hp == HunterSkills.monster_hp(1, z2.hp) and sh.slimes[0].speed == z2.speed and sh.slimes[0].title == z2.monster, "2구역 몬스터: %s 체력 %d · 빠르기 %s" % [z2.monster, z2.hp, z2.speed])
	# 금사리 (사용자 선택: 모래게 + 대장 금두꺼비, 입구에 "금사리(구터)" 회색 항아리 표지)
	var crab: WildSlime = sh.slimes[0]
	_check(crab.buried and crab.sheet.resource_path.ends_with("wild_sand_crab.png"), "모래게는 모래에 숨어 있음")
	_check(sh.sign_node != null and z2.sign == "금사리(구터)", "금사리 입구에 마을 표지")
	var hearts_c := sh.life
	crab.position = main.player.feet() + Vector2(Config.WILD_BURROW_POP_DISTANCE + 20, 0)
	sh.tick(0.01)
	_check(crab.buried, "멀면 숨은 채로")
	crab.position = main.player.feet() + Vector2(Config.WILD_BURROW_POP_DISTANCE - 10, 0)
	sh.tick(0.01)
	_check(not crab.buried and sh.life == hearts_c, "가까이 가면 모래에서 튀어나옴 (아직 안 부딪힘)")
	for i in z2.count:
		var zw: WildSlime = sh.slimes[0]
		zw.position = main.player.feet() + Vector2(0, -8 - Config.SWING_REACH)
		for k in ceili(float(HunterSkills.monster_hp(1, z2.hp)) / HunterClass.hunter_damage(1, &"melee")):
			sh.tick(Config.SWING_COOLDOWN)
			sh.swing()
			zw.position = main.player.feet() + Vector2(0, -8 - Config.SWING_REACH)
	_check(sh.boss_spawned and sh.slimes.size() == 1 and sh.slimes[0].hp == HunterSkills.monster_hp(1, z2.boss_hp), "2구역 대장 체력 %d (레벨 반영)" % sh.slimes[0].hp)
	_check(sh.slimes[0].title == z2.boss_monster and not sh.slimes[0].buried and sh.slimes[0].sheet.resource_path.ends_with("wild_gold_toad_hd.png"), "금사리 대장은 %s" % z2.boss_monster)
	sh.slimes[0].hp = 1
	sh.slimes[0].position = main.player.feet() + Vector2(0, -8 - Config.SWING_REACH)
	sh.tick(Config.SWING_COOLDOWN)
	sh.swing()
	_check(sh.slimes.is_empty() and sh.path_open, "금사리 대장 뒤엔 2막 3구역 광동리 길이 열림")
	var toad_eggs := sh.drops.filter(func(d: Dictionary) -> bool: return d.species == CreatureCatalog.GOLD_TOAD)
	_check(toad_eggs.size() == 1, "대장 금두꺼비는 알 확률에 걸리면 금두꺼비 알을 남김")
	sh.drops.clear()
	main.player.position = sh.next_area().get_center()
	# 끊어진 쇠다리 (2026-09-29 "대장간과 묶기"): 대장간을 고치기 전엔 광동리로 못 건넘
	var br_state := GameState.forge_state
	GameState.forge_state = 1
	_check(sh.bridge_broken() and not sh.advance() and sh.zone == 1, "대장간을 고치기 전엔 금사리 쇠다리가 끊겨 광동리로 못 감")
	GameState.forge_state = 2
	_check(not sh.bridge_broken(), "대장간을 고치면 쇠다리가 이어짐")
	_check(sh.advance() and sh.zone == 2 and 2 in GameState.waypoints and sh.slimes[0].title == "요괴 까마귀", "위쪽 길로 3구역 광동리 (웨이포인트 켜짐, 요괴 까마귀)")
	GameState.forge_state = br_state
	main.player.position = sh.exit_area().get_center()
	main.interact()
	_check(main.hunt == null, "아래 입구 F로 마을로")
	# 다음 날: 사냥터 입구에서 웨이포인트를 고른다
	main.next_day()
	main.player.position = main.hunt_gate.position
	if not HunterClass.chosen():
		HunterClass.choose(&"warrior")
	GameState.hunter_unlocked = true
	main._gate_interact()
	_check(main.menu_open and main.menu_kind == &"waypoint" and main.waypoint_options().slice(0, 4) == [&"zone_0", &"zone_1", &"zone_2", &"respec"] and main.waypoint_options().back() == &"close", "웨이포인트가 여럿이면 어디서 시작할지 물음")
	main.menu_move(1)
	main.menu_confirm()
	if main.menu_open and main.menu_kind == &"companion":
		main.menu_index = main.companion_options().size() - 1
		main.menu_confirm()
	_check(main.hunt != null and main.hunt.zone == 1 and main.hunt.slimes[0].hp == HunterSkills.monster_hp(1, z2.hp), "%s 웨이포인트에서 바로 시작" % z2.name)
	main.leave_hunt()
	_check(not main.enter_hunt(null, 1), "하루 한 번은 그대로")
	main.next_day()
	_check(main.enter_hunt(null, 5) and main.hunt.zone == 0, "켜지지 않은 구역은 입구에서 시작")
	main.leave_hunt()
	# 23b) 한 번 잡은 대장은 다음부터 처음부터 나와 있음 (2026-10-01 사용자: "보스를 한번 잡으면 그담부터는 일반 몬스터 안잡아도 보스가 팝업되어있도록")
	_check(GameState.bosses_beaten == [0, 1], "대장을 쓰러뜨린 구역을 기억함 %s" % [GameState.bosses_beaten])
	_check(SaveGame.snapshot(main).gs.has("bosses_beaten"), "대장 처치 기록도 저장됨")
	main.next_day()
	_check(main.enter_hunt(null, 1) and main.hunt.zone == 1, "다시 금사리로")
	var rh: HuntGround = main.hunt
	var rboss := rh._boss()
	_check(rh.boss_spawned and rboss != null and rboss.title == z2.boss_monster and rh.slimes.size() == z2.count + 1, "한 번 잡은 %s이(가) 처음부터 나와 있고, %s %d마리도 그대로" % [z2.boss_monster, z2.monster, z2.count])
	_check(not rh.path_open, "대장을 다시 잡기 전엔 위쪽 길이 닫힘")
	rboss.hp = 1
	rh._defeat(rboss)
	_check(rh._boss() == null and rh.path_open and rh.slimes.size() == z2.count, "일반 몬스터를 안 잡고 대장만 잡아도 위쪽 길이 열림")
	for rw: WildSlime in rh.slimes.duplicate():
		rw.hp = 1
		rh._defeat(rw)
	_check(rh.slimes.is_empty() and rh._boss() == null, "다 잡아도 대장이 또 나오지는 않음 (사냥 한 번에 한 번)")
	main.leave_hunt()
	main.next_day()
	_check(main.enter_hunt(null, 2) and main.hunt.zone == 2 and not main.hunt.boss_spawned, "아직 못 잡은 광동리는 지금처럼 다 잡아야 대장이 나옴")
	main.leave_hunt()
	GameState.bosses_beaten.clear()
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
	var toad: Creature = main._hatch(CreatureCatalog.GOLD_TOAD, Config.FORAGE_CELLS[1])
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
	main.player.position = Vector2(10, 7) * HuntGround.T
	pc.position = main.player.feet() + Vector2(0, 20)
	var pulled: WildSlime = th.slimes[0]
	pulled.buried = false
	pulled.hp = 3 * U
	pulled.position = pc.position + Vector2(Config.COMPANION_PULL_RANGE - 10, 0)
	for other in th.slimes:
		if other != pulled:
			other.position = pc.position + Vector2(0, -Config.COMPANION_PULL_RANGE * 3)
	var hp_before := pulled.hp
	th.tick(Config.COMPANION_PULL_INTERVAL * 2)
	th.tick(Config.COMPANION_PULL_TIME)
	_check(pulled.hp == hp_before - HunterClass.companion_damage(1) and pulled.position.distance_to(pc.position) <= Config.COMPANION_PULL_GAP + 1 and pulled.stunned(), "혀 당기기: 멀리 있는 몬스터를 끌어와 피해 1 + 멈춤")
	var hearts_t := th.life
	pulled.position = main.player.feet()
	th.tick(0.01)
	_check(th.life == hearts_t, "멈춘 몬스터에 닿아도 다치지 않음")
	pulled.tick(Config.COMPANION_PULL_STUN, main.player.feet())
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
	_check(main.player.position == wm.spot("S") and wh.near_exit(), "아래 입구 앞에서 시작")
	_check(wh.slimes.size() == z2.count and wh.slimes.all(func(s: WildSlime) -> bool: return s.buried and wm.at_point(s.position) == "c"), "모래게 %d마리가 모래톱마다 숨어 있음" % z2.count)
	var hunter_w: Character = main.player
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
	_check(main.hunt == null and hunter_w.terrain == null and main.camera.is_current(), "마을로 돌아오면 마을 카메라로")

	# 26. 분원농협 넓은 맵 (2026-09-28 사용자 선택 C. 창고 마당) + 작은 지도 (추천 M2: 가 본 곳만 보임)
	main.next_day()
	var z1: Dictionary = Config.HUNT_ZONES[0]
	_check(main.enter_hunt(null, 0), "분원농협으로 입장")
	var nh: HuntGround = main.hunt
	nh.set_ai(false)
	var nm := nh.map
	var hunter_n: Character = main.player
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
	GameState.hunts_today = 0
	if not 1 in GameState.waypoints:
		GameState.waypoints.append(1)
	main.enter_hunt(null, 0)
	GameState.worn[&"hunter"].erase(&"weapon")  # 드롭으로 무기를 들었으면 사냥칼로 (이 아래는 칼 휘두르기 점검)
	var d_dh: HuntGround = main.hunt
	d_dh.set_ai(false)
	var d_hf: Vector2 = main.player.feet()
	var d_lw: WildSlime = d_dh.slimes[0]
	for o: WildSlime in d_dh.slimes:
		o.position = d_hf + Vector2(0, 300)
	d_lw.position = d_hf + Vector2(40, 0)
	d_lw.ai_enabled = true
	var d_h0 := d_dh.life
	d_dh.tick(0.05)
	var d_tg := d_lw.telegraph()
	_check(not d_tg.is_empty() and d_tg.kind == &"lane" and d_dh.life == d_h0, "A. 가까이 오면 웅크리고 붉은 띠로 예고 (아직 안 맞음)")
	d_dh.swing(Vector2.RIGHT)
	_check(not d_lw.telegraph().is_empty(), "A. 웅크리는 중엔 맞아도 달려들기가 멈추지 않음")
	for i in 30:
		d_dh.tick(1.0 / 30.0)
	_check(d_dh.life == d_h0 - d_lw.damage and d_lw.recovering(), "A. 띠 위에 서 있으면 돌진에 맞고, 몬스터는 헐떡임 (하트 %d → %d)" % [d_h0, d_dh.life])
	# 비켜서면 안 맞는다
	d_dh._invulnerable = 0.0
	d_lw.hp = 99
	for i in 60:
		d_dh.tick(1.0 / 30.0)
		if not d_lw.telegraph().is_empty():
			break
	d_lw.position = main.player.feet() + Vector2(40, 0)
	d_lw._lunge_dir = Vector2.LEFT
	var d_h1 := d_dh.life
	main.player.position += Vector2(0, 40)
	for i in 25:
		d_dh.tick(1.0 / 30.0)
	_check(d_dh.life == d_h1, "A. 예고를 보고 옆으로 비키면 안 맞음")
	main.leave_hunt()
	# B. 금사리: 하트 -2, 무리로 튀어나옴
	GameState.hunts_today = 0
	main.enter_hunt(null, 1)
	var d_gh: HuntGround = main.hunt
	d_gh.set_ai(false)
	var d_z2d: Dictionary = Config.HUNT_ZONES[1]
	_check(d_z2d.damage == 2 and d_gh.slimes[0].damage == HunterSkills.monster_damage(1, 2) and d_gh.slimes[0].hp == HunterSkills.monster_hp(1, d_z2d.hp) and d_z2d.hp > Config.HUNT_ZONES[0].hp, "B. 금사리는 체력 %d · 피해 %d" % [d_gh.slimes[0].hp, d_gh.slimes[0].damage])
	_check(main.waypoint_option_text(&"zone_1").contains(d_z2d.advice), "B. 웨이포인트 메뉴에 권장 준비")
	var d_gf: Vector2 = main.player.feet()
	for o: WildSlime in d_gh.slimes:
		o.buried = true
		o.position = d_gf + Vector2(0, 400)
	var d_pa: WildSlime = d_gh.slimes[0]
	var d_pb: WildSlime = d_gh.slimes[1]
	d_pa.position = d_gf + Vector2(50, 0)
	d_pb.position = d_gf + Vector2(50 + Config.WILD_PACK_DISTANCE - 10, 0)
	d_gh.tick(0.01)
	_check(not d_pa.buried and not d_pb.buried and d_gh.slimes[2].buried, "B. 하나가 튀어나오면 근처 모래게도 무리로 튀어나옴 (먼 것은 그대로)")
	var d_h2 := d_gh.life
	d_pa.position = d_gf
	d_gh.tick(0.01)
	_check(d_gh.life == d_h2 - d_pa.damage and d_pa.damage == HunterSkills.monster_damage(1, 2), "B. 모래게에 부딪히면 체력 -%d (하트 2 x 레벨)" % d_pa.damage)
	# C. 금두꺼비 혀 채찍 + 금가루
	d_gh._invulnerable = 0.0
	d_gh.life = d_gh.max_life()
	for o: WildSlime in d_gh.slimes.duplicate():
		o.hp = 1
		d_gh._defeat(o)
	var d_toad_b: WildSlime = d_gh._boss()
	_check(d_toad_b != null and d_toad_b.pattern == &"tongue" and d_toad_b.hp == HunterSkills.monster_hp(1, d_z2d.boss_hp), "C. 금두꺼비 대장 (혀 채찍, 체력 %d)" % d_toad_b.hp)
	d_toad_b.ai_enabled = true
	d_toad_b._pattern_cd = 0.0
	main.player.position = d_toad_b.position + Vector2(60, 0) - Vector2(0, main.player.feet().y - main.player.position.y)
	var d_h3 := d_gh.life
	d_gh.tick(0.02)
	_check(not d_toad_b.telegraph().is_empty() and d_gh.life == d_h3, "C. 혀 채찍 예고 (직선 띠)")
	for i in int(Config.TONGUE_WINDUP * 30) + 3:
		d_gh.tick(1.0 / 30.0)
	_check(d_gh.life == d_h3 - d_toad_b.damage and d_gh.dust.size() == 3, "C. 혀에 맞으면 체력 -%d, 지나간 자리에 금가루 3곳" % d_toad_b.damage)
	main.player.position += d_gh.dust[0].at - main.player.feet()
	d_gh.tick(0.01)
	_check(is_equal_approx(main.player.slow_mult, Config.GOLD_DUST_SLOW), "C. 금가루를 밟으면 느려짐")
	main.leave_hunt()
	_check(is_equal_approx(main.player.slow_mult, 1.0), "C. 사냥터를 나오면 빠르기 원래대로")
	# C. 대장 슬라임 내려찍기 + 새끼
	GameState.hunts_today = 0
	GameState.bosses_beaten.clear()  # 일반 몬스터를 다 잡아 대장이 나오는 흐름으로
	main.enter_hunt(null, 0)
	var d_bh2: HuntGround = main.hunt
	d_bh2.set_ai(false)
	for o: WildSlime in d_bh2.slimes.duplicate():
		o.hp = 1
		d_bh2._defeat(o)
	var d_sb: WildSlime = d_bh2._boss()
	d_sb.ai_enabled = true
	d_sb._pattern_cd = 0.0
	main.player.position = d_sb.position + Vector2(0, 80)
	var d_h4 := d_bh2.life
	d_bh2.tick(0.02)
	_check(d_sb.airborne() and d_sb.telegraph().kind == &"circle", "C. 대장 슬라임이 뛰어올라 사냥꾼 발밑에 그림자 원")
	var d_sb_hp := d_sb.hp
	d_sb.position = main.player.feet() + Vector2(0, -8 - Config.SWING_REACH)
	d_bh2._cooldown = 0.0
	d_bh2.swing(Vector2.UP)
	_check(d_sb.hp == d_sb_hp, "C. 공중에 뜬 대장은 칼에 안 맞음")
	for i in int(Config.SLAM_AIR_TIME * 30) + 3:
		d_bh2.tick(1.0 / 30.0)
	var d_minions := d_bh2.slimes.filter(func(o: WildSlime) -> bool: return o.minion)
	_check(d_bh2.life == d_h4 - d_sb.damage and d_minions.size() == Config.SLAM_MINIONS and d_sb.recovering(), "C. 쿵! 원 안이면 하트 -1, 새끼 %d마리, 대장은 헐떡임" % Config.SLAM_MINIONS)
	var d_drops_before := d_bh2.drops.size() + d_bh2.loot.size()
	d_minions[0].hp = 1
	d_bh2._defeat(d_minions[0])
	_check(d_bh2.drops.size() + d_bh2.loot.size() == d_drops_before and d_bh2._boss() == d_sb, "C. 새끼는 알·드롭을 남기지 않음")
	main.leave_hunt()

	# 31) 들나물 캐기 (2026-09-29 사용자 선택 A, 초반 며칠 할 일): 아침마다 풀밭에 돋고, F로 캐서 공급함에 진열 → 밤사이 팔림
	var h_forage: Forage = main.forage
	var h_bad: Array[Vector2i] = []
	for spot in Config.HERB_SPOTS:
		# 대장간 터 · 고물 더미가 들어선 자리는 쓰지 않는다 (Forage.blocked)
		if main.forage.blocked.any(func(r: Rect2i) -> bool: return r.has_point(spot)):
			continue
		var stand := Farm.center_of(spot) - Vector2(0, main.player.FEET_Y)
		var h_inside: bool = main.farm.get_cell(spot) != null or main.farm._path.has(spot) or main.farm._fence.has(spot) or spot.y < 1 or spot.y > Config.MAP_SIZE.y - 3
		for p: Prop in main.props:
			if p.footprint_rect().has_point(Farm.center_of(spot) - p.position):
				h_inside = true
		if h_inside or not main.farm.is_free(main.player.feet_rect(stand)):
			h_bad.append(spot)
	_check(h_bad.is_empty(), "들나물 자리는 모두 밭·길·울타리·오브젝트 밖, 서서 캘 수 있는 풀밭 %s" % [h_bad])
	main.next_day()
	var h_n: int = h_forage.herbs.size()
	_check(h_n >= Config.HERBS_PER_DAY.x and h_n <= Config.HERBS_PER_DAY.y, "아침마다 들나물 %d~%d포기가 돋음 (%d)" % [Config.HERBS_PER_DAY.x, Config.HERBS_PER_DAY.y, h_n])
	for s: Creature in main.creatures:
		s.position = Vector2(-500, -500)
	GameState.herbs = 0
	for spot: Vector2i in h_forage.herbs.keys():
		main.player.position = Farm.center_of(spot) - Vector2(0, main.player.FEET_Y) + Vector2(10, 0)
		main.interact()
	_check(GameState.herbs == h_n and h_forage.herbs.is_empty(), "농부가 가까이서 F로 캠 (들나물 %d)" % GameState.herbs)
	main.player.position = main.supply_box.position
	_check(main.supply_options().has(&"display_herbs") and main.supply_option_text(&"display_herbs").contains("%d원" % (h_n * Config.HERB_PRICE)), "공급함에 들나물 진열하기")
	_check(main.supply_action(&"display_herbs") and GameState.herbs == 0 and GameState.displayed_herbs == h_n, "들나물 진열")
	var h_money := GameState.money
	var h_lines: Array[String] = main.next_day()
	_check(GameState.money - h_money >= h_n * Config.HERB_PRICE and GameState.displayed_herbs == 0 and " ".join(h_lines).contains("들나물 %d포기가 팔렸다" % h_n), "밤사이 팔려 아침에 +%d원" % (h_n * Config.HERB_PRICE))
	_check(not h_forage.herbs.is_empty() and " ".join(h_lines).contains("들나물"), "다음 날 아침 새로 돋음")
	_check(Forage.object_particle("쑥") == "을" and Forage.object_particle("냉이") == "를", "들나물 이름에 맞는 조사 (쑥을 · 냉이를)")
	main.player.position = Farm.center_of(h_forage.herbs.keys()[0]) - Vector2(0, main.player.FEET_Y)
	var h_before: int = h_forage.herbs.size()
	main.interact()
	_check(h_forage.herbs.size() == h_before - 1, "사냥 다녀온 주인공도 들나물을 캠 (한 사람)")

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
	var c_cell: Farm.Cell = main.farm.get_cell(fc(2, 3))
	c_cell.planted = false
	c_cell.tilled = false
	_check(main.farm.do_work(Farm.Work.TILL, fc(2, 3)), "새벽에도 도구질은 됨 (막지 않음)")
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
		var stand := Farm.center_of(spot) - Vector2(0, main.player.FEET_Y)
		var f_inside: bool = main.farm.get_cell(spot) != null or main.farm._path.has(spot) or main.farm._fence.has(spot) or spot.y < 1 or spot.y > Config.MAP_SIZE.y - 3 or spot in Config.HERB_SPOTS
		for p: Prop in main.props:
			if p.footprint_rect().has_point(Farm.center_of(spot) - p.position):
				f_inside = true
		if f_inside or not main.farm.is_free(main.player.feet_rect(stand)):
			f_bad.append(spot)
	_check(f_bad.is_empty(), "도라지 자리는 모두 들나물 자리와 겹치지 않는 풀밭 %s" % [f_bad])
	for s: Creature in main.creatures:
		s.queue_free()
	main.creatures.clear()
	main.next_day()
	var f_roots := f_forage.roots.size()
	_check(f_roots >= Config.ROOTS_PER_DAY.x and f_roots <= Config.ROOTS_PER_DAY.y, "아침마다 땅속에 도라지 %d~%d뿌리 (%d)" % [Config.ROOTS_PER_DAY.x, Config.ROOTS_PER_DAY.y, f_roots])
	var f_root_cell: Vector2i = f_forage.roots.keys()[0]
	main.player.position = Farm.center_of(f_root_cell) - Vector2(0, main.player.FEET_Y) + Vector2(10, 0)
	for f_cell: Vector2i in f_forage.herbs.keys():
		if Farm.center_of(f_cell).distance_to(main.player.feet()) <= Config.INTERACT_DISTANCE:
			f_forage.herbs.erase(f_cell)
	main.interact()
	_check(f_forage.roots.has(f_root_cell) and main._message.text.contains("손으로는 못 캔다"), "농부는 도라지를 손으로 못 캠 (알려 줌)")
	_check(CreatureJobs.FARM_JOBS.has(CreatureJobs.FORAGE) and CreatureJobs.display_name(CreatureJobs.FORAGE) == "채집", "크리처 일 목록(R)에 채집")
	var f_water: Creature = main._hatch(CreatureCatalog.SLIME, Config.FORAGE_CELLS[0])
	f_water.data.set_element(load("res://data/creatures/elements/water.tres"))
	var f_earth: Creature = main._hatch(CreatureCatalog.SLIME, Config.FORAGE_CELLS[3])
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
	var j_home := fc(4, 4)
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
	GameState.hunter_unlocked = true
	GameState.money = 0
	GameState.crops = 0
	GameState.material = 0
	_check(not main.restore_forge() and GameState.forge_state == 1, "모자라면 못 고침")
	# 터가 있으면 금사리 · 분원농협 일반 몬스터도 사금 덩이를 가끔 (2026-10-03 백로그 4번)
	_check(SiteWork.mob_drop(Config.FORGE_ZONE, 0.0) != "" and GameState.material == 1, "터가 있으면 일반 몬스터도 %s" % Config.BOSS_MATERIAL_NAME)
	_check(SiteWork.mob_drop(Config.FORGE_ZONE, 0.99) == "" and SiteWork.mob_drop(4, 0.0) == "" and GameState.material == 1, "확률 밖 · 다른 막 구역은 안 줌")
	GameState.material = Config.FORGE_COST_MATERIAL
	_check(SiteWork.mob_drop(Config.FORGE_ZONE, 0.0) == "", "다 모았으면 더 안 줌")
	GameState.money = Config.FORGE_COST_MONEY + 1000
	GameState.crops = Config.FORGE_COST_CROPS + 10
	GameState.material = Config.FORGE_COST_MATERIAL
	main.player.position = Farm.center_of(Config.FORGE_RECT.position + Vector2i(1, Config.FORGE_RECT.size.y))
	main.interact()
	_check(main.menu_open and main.menu_kind == &"forge", "대장간 터에서 F → 복구 창")
	main.menu_confirm()
	_check(GameState.forge_state == 1 and SiteWork.building(&"forge") and main.menu_open, "다 모았으면 공사 시작 (아직 문은 안 엶)")
	_check(GameState.money == 1000 and GameState.crops == 10 and GameState.material == 0, "공사 시작에 돈 · 무 · %s을 냄" % Config.BOSS_MATERIAL_NAME)
	main.close_menu()
	# 공사 (2026-10-03 백로그 4번): 크리처가 하루 BUILD_CAP 번씩 days 일
	_check(CreatureJobs.BUILD in CreatureJobs.jobs() and SiteWork.build_site() == &"forge", "공사 중이면 R 일 목록에 터 공사")
	var bc: Creature = main._hatch(CreatureCatalog.SLIME, Config.FORAGE_CELLS[3])
	bc.auto_work = false
	bc.job = CreatureJobs.BUILD
	_check(bc.work_once(), "터 공사 크리처가 터로 감")
	GameState.build_today = 0
	var built := 0
	for i in Config.BUILD_CAP + 3:
		built += int(SiteWork.build_once())
	_check(built == Config.BUILD_CAP and not SiteWork.build_open(), "터 공사는 하루 %d번까지" % Config.BUILD_CAP)
	_check(not main.restore_forge() and GameState.forge_state == 1, "공사가 덜 되면 문을 못 엶")
	var fl: Array[String] = main.next_day()
	_check(GameState.build_today == 0 and SiteWork.build_open() and fl.any(func(l: String) -> bool: return l.contains("대장간 공사 1/")), "아침: 공사 진척 줄, 다시 공사")
	GameState.site_work[&"forge"] = SiteWork.work_need(&"forge") - 1
	SiteWork.build_once()
	_check(SiteWork.ready(&"forge") and SiteWork.build_site() == &"", "마지막 공사 → 내일 아침 문 엶")
	fl = main.next_day()
	_check(GameState.forge_state == 2 and fl.any(func(l: String) -> bool: return l.contains("대장간 공사가 끝나")), "공사가 다 된 다음 날 아침 대장간이 섬")
	_check(not GameState.site_work.has(&"forge") and not CreatureJobs.BUILD in CreatureJobs.jobs(), "문을 열면 공사 기록 · 터 공사 일이 사라짐")
	main.creatures.erase(bc)
	bc.queue_free()
	_check(main.smith.visible and main.scrap_heap != null and true, "대장장이와 고물 더미가 생김")
	_check(not CreatureJobs.SCRAP in CreatureJobs.jobs() and FacilityWorkers.is_open(&"forge"), "고물 캐기는 R 이 아니라 대장간 일꾼 자리 (멍석)")
	_check(main.smith.npc and main.player.active and not main.smith.active, "대장장이는 말 거는 마을 사람 (조작 안 함)")
	main.player.position = Farm.center_of(Config.SMITH_CELL) + Vector2(0, 10)
	_check(main.nearby_villager() == main.smith, "대장장이 옆에 서면 말 걸 사람")
	main.interact()
	_check(main.menu_open and main.menu_kind == &"craft", "대장장이에게 F → 제작 창")
	main.close_menu()
	# 크리처 고물 캐기 (2026-10-03 백로그 3): 더미는 저절로 안 차고, 한 마리가 하루 dig_cap() 개. 땅속성이 빠르다
	var fs: Creature = main._hatch(CreatureCatalog.SLIME, Config.FORAGE_CELLS[2])
	fs.data.set_element(load("res://data/creatures/elements/earth.tres"))
	fs.auto_work = false
	# 크리처 시설 배치 (2026-10-03): 들고 멍석 근처에서 F → 대장간 일꾼
	main.player.position = fs.position
	main.interact()
	_check(fs.carried_by == main.player, "크리처를 듦")
	main.player.position = Farm.center_of(Config.WORKER_SLOTS[&"forge"][1] + Vector2i(0, 1))
	main.interact()
	_check(fs.carried_by == null and fs.job == CreatureJobs.SCRAP and fs.home in Config.WORKER_SLOTS[&"forge"] and FacilityWorkers.workers(main, &"forge") == [fs], "멍석 근처에 내려놓으면 대장간 일꾼 (고물 캐기)")
	var r_job := fs.job
	main.player.position = fs.position + Vector2(0, 8)
	main.change_creature_job()
	_check(fs.job == r_job, "일꾼에게 R 은 일을 안 바꿈 (들어서 옮김)")
	# 멍석이 다 차면 더 못 앉힘
	var fill_a: Creature = main._hatch(CreatureCatalog.SLIME, Config.FORAGE_CELLS[3])
	var fill_b: Creature = main._hatch(CreatureCatalog.SLIME, Config.FORAGE_CELLS[4])
	var fill_c: Creature = main._hatch(CreatureCatalog.SLIME, Config.FORAGE_CELLS[5])
	_check(FacilityWorkers.assign(main, fill_a, &"forge") and FacilityWorkers.assign(main, fill_b, &"forge") and not FacilityWorkers.assign(main, fill_c, &"forge"), "대장간 멍석은 %d자리" % Config.WORKER_SLOTS[&"forge"].size())
	# 일꾼을 들어 밭 쪽에 내려놓으면 시설 일을 그만두고 쉼
	main.player.position = fill_b.position + Vector2(0, 6)
	main.interact()
	_check(fill_b.carried_by == main.player, "멍석 위 일꾼을 들 수 있음 (대장간 창보다 먼저)")
	main.player.position = Farm.center_of(Config.FORAGE_CELLS[6])
	main.interact()
	_check(fill_b.job == CreatureJobs.REST and FacilityWorkers.workers(main, &"forge").size() == 2, "밭 쪽에 내려놓으면 쉼 (일꾼 2)")
	for x: Creature in [fill_a, fill_b, fill_c]:
		main.creatures.erase(x)
		x.queue_free()
	_check(is_equal_approx(fs.data.work_speed(CreatureJobs.SCRAP), fs.data.work_speed(CreatureJobs.WATER) * 1.5), "땅속성은 고물 캐기 1.5배")
	GameState.scrap = 0
	var fs_cap0 := fs.dig_cap()
	fs.data.speed_level = 3
	_check(fs_cap0 == maxi(1, roundi(Config.SCRAP_DIG_PER_DAY * 1.5)) and fs.dig_cap() > fs_cap0, "땅속성 하루 캐는 수 %d개, 속도 훈련하면 %d개" % [fs_cap0, fs.dig_cap()])
	fs.data.speed_level = 0
	_check(fs.work_once(), "고물 캐기 크리처가 고물 더미로")
	Engine.time_scale = 20.0
	while fs._busy:
		await get_tree().process_frame
	Engine.time_scale = 1.0
	_check(GameState.scrap == 1 and fs.dug_today == 1, "고철 하나를 캐 옴")
	fs.dug_today = fs.dig_cap()
	_check(fs.work_once() and fs._busy, "오늘 몫을 다 캐면 제자리로 돌아감")
	Engine.time_scale = 20.0
	while fs._busy:
		await get_tree().process_frame
	Engine.time_scale = 1.0
	_check(not fs.work_once(), "제자리에서 쉼")
	main.next_day()
	_check(fs.dug_today == 0, "아침마다 캔 수를 새로 셈")
	main.player.position = Farm.center_of(Config.SCRAP_RECT.position + Vector2i(Config.SCRAP_RECT.size.x, 0))
	main.interact()
	_check(GameState.scrap == 1, "고물 더미는 손으로 못 팜 (크리처 몫)")
	main.creatures.erase(fs)
	fs.queue_free()
	# 장비 갈기 (2026-10-03 백로그 8): 대장장이 창 → 가방에서 장비 클릭 = 고철
	var sv_roll := Wearables.roll_gear(RandomNumberGenerator.new(), &"rare")
	var sv_where := Wearables.gain_rolled(sv_roll)
	var sv_who: StringName = Wearables.ITEMS[sv_roll.base].who
	if sv_where == &"worn":
		Wearables.take_off(sv_who, Wearables.ITEMS[sv_roll.base].slot)
	_check(sv_where != &"" and (GameState.bag[sv_who] as Array).size() > 0, "갈 장비를 하나 얻어 가방에")
	var sv_i := (GameState.bag[sv_who] as Array).size() - 1
	_check(&"salvage" in main.craft_options(), "대장장이 창에 장비 갈기")
	GameState.scrap = 0
	main.open_inventory(false, false, true)
	main.inventory.outfit = sv_who
	_check(main.inventory.salvage_mode, "갈기 창으로 열림")
	_check(main.inventory.primary(&"bag", sv_i) and GameState.scrap == Config.SALVAGE_SCRAP[&"rare"], "레어 장비를 갈면 고철 %d" % Config.SALVAGE_SCRAP[&"rare"])
	main.close_inventory()
	# 제작: 주인공이 대장간 모루에서 F → 대장장이 제작 창
	GameState.scrap = 20
	GameState.money = 1000
	forge_f(main, main.player)
	_check(main.menu_open and main.menu_kind == &"craft", "대장간 모루에서 F → 대장장이 제작 창")
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
	_check(&"sell_gear" in main.supply_options(), "농부도 공급함에서 제작품을 팜")
	GameState.bag[&"farmer"].erase(f_rid)
	main.open_inventory()
	_check(main.inventory.visible and main.inventory.character == main.player, "가방은 주인공 것 하나")
	main.close_inventory()

	# 36) 광동리 (2026-09-29 사용자: "3구역은 광동리다", 후보 B. 동지벌 군량 벌판): 요괴 까마귀 떼 · 허수아비 장수 · 아기 까마귀
	close_all(main)
	var g_z: Dictionary = Config.HUNT_ZONES[2]
	_check(g_z.name == "광동리" and g_z.map == "gwangdong" and g_z.flyer, "3구역 광동리: 넓은 맵 + 나는 몬스터")
	main.next_day()
	GameState.hunts_today = 0
	if not 2 in GameState.waypoints:
		GameState.waypoints.append(2)
	HuntGround.loot_enabled = false
	_check(main.enter_hunt(null, 2) and main.hunt.zone == 2, "광동리 웨이포인트에서 시작")
	var gh: HuntGround = main.hunt
	gh.set_ai(false)
	gh.set_process(false)
	_check(gh.slimes.size() == g_z.count and gh.slimes[0].flyer and gh.slimes[0].sheet.resource_path.ends_with("wild_sparrow.png"), "까마귀 %d마리" % g_z.count)
	var sp_a: WildSlime = gh.slimes[0]
	for o in gh.slimes:
		if o != sp_a:
			o.position = Vector2(40, 40)
	sp_a.ai_enabled = true
	sp_a._rest = 0.0
	sp_a.position = main.player.feet() + Vector2(80, 0)
	gh.life = 90
	gh.tick(0.05)
	_check(sp_a.in_air() and sp_a.airborne(), "사냥꾼이 다가오면 날아오름")

	GameState.worn[&"hunter"].erase(&"weapon")  # 드롭으로 무기를 들었으면 사냥칼로 (이 아래는 칼 휘두르기 점검)
	sp_a.position = main.player.feet() + Vector2(0, -8 - Config.SWING_REACH)
	gh._cooldown = 0.0
	_check(gh.swing(Vector2.UP) == 0 and sp_a.hp == sp_a.max_hp, "나는 까마귀는 칼에 안 맞음")
	sp_a._fly = 0.0
	gh.tick(0.05)
	_check(sp_a._swoop >= 0.0 and not sp_a.telegraph().is_empty() and sp_a.telegraph().kind == &"circle", "맴돌다가 발밑에 그림자 원 예고")
	var g_h0 := gh.life
	for i in 60:
		gh._invulnerable = 0.0 if i == 0 else gh._invulnerable
		gh.tick(0.05)
		if sp_a._rest > 0.0 and not sp_a.in_air():
			break
	_check(gh.life == g_h0 - sp_a.damage, "원 안에 있으면 내려꽂기에 체력 -%d" % sp_a.damage)
	_check(not sp_a.in_air() and sp_a._rest > 0.0, "내려앉아 낟알을 쫌 (칠 틈)")
	gh._cooldown = 0.0
	sp_a.position = main.player.feet() + Vector2(0, -8 - Config.SWING_REACH)
	_check(gh.swing(Vector2.UP) == 1 and sp_a.hp == sp_a.max_hp - HunterClass.hunter_damage(1, &"melee"), "앉은 까마귀는 칼에 맞음")
	_check(sp_a._rest <= Config.SWOOP_HIT_RECOVER, "맞으면 곧 다시 날아오름")
	# 내려꽂기 원 밖이면 안 다침
	sp_a._rest = 0.0
	sp_a.position = main.player.feet() + Vector2(60, 0)
	gh._invulnerable = 0.0
	gh.tick(0.05)
	sp_a._fly = 0.0
	gh.tick(0.05)
	main.player.position += Vector2(0, 60)
	var g_h1 := gh.life
	for i in 40:
		gh.tick(0.05)
	_check(gh.life == g_h1, "비켜서면 내려꽂기에 안 맞음")
	# 대장 허수아비 장수: 짚단 셋 + 두 번에 한 번 까마귀 부르기
	for o in gh.slimes.duplicate():
		gh.slimes.erase(o)
		o.queue_free()
	var g_b := gh.spawn_boss()
	_check(g_b.title == "허수아비 장수" and g_b.hp == HunterSkills.monster_hp(2, g_z.boss_hp) and not g_b.flyer, "대장 허수아비 장수 체력 %d" % g_b.hp)
	g_b.ai_enabled = true
	g_b._pattern_cd = 0.0
	g_b.position = main.player.feet() + Vector2(0, -100)
	gh.life = 90
	gh._invulnerable = 0.0
	gh.tick(0.05)
	_check(g_b.telegraphs().size() == Config.STRAW_BALES, "짚단 %d개 예고" % Config.STRAW_BALES)
	for i in 60:
		gh.tick(0.05)
		if g_b.telegraphs().is_empty():
			break
	_check(gh.life < 90, "발밑 짚단에 맞음")
	g_b._recover = 0.0
	g_b._pattern_cd = 0.0
	for i in 80:
		gh._invulnerable = 1.0
		gh.tick(0.05)
		if gh.slimes.size() > 1:
			break
	_check(gh.slimes.filter(func(o: WildSlime) -> bool: return o.minion and o.flyer).size() == Config.STRAW_CALL, "두 번째 던지기 뒤 까마귀 %d마리를 부름" % Config.STRAW_CALL)
	main.leave_hunt()
	HuntGround.loot_enabled = true
	# 알: 광동리 몬스터 알 = 아기 까마귀 (게임 첫 알은 그대로 슬라임)
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
	g_s.position = main.player.feet() + Vector2(0, -8 - Config.SWING_REACH)
	gh.swing(Vector2.UP)
	_check(gh.drops.size() == 1 and gh.drops[0].species == CreatureCatalog.SPARROW, "광동리 알 = 아기 까마귀")
	HuntGround.egg_roll = -1.0
	HuntGround.loot_enabled = true
	main.leave_hunt()
	# 아기 까마귀: 비행 속성만, 채집 1.5배 + 빨리 날아다님, 동행 = 날아가 쪼기 (나는 몬스터도), 아침마다 씨앗
	var g_rng := RandomNumberGenerator.new()
	g_rng.seed = 36
	var g_fly := true
	for i in 30:
		var gd := CreatureData.hatch(CreatureCatalog.SPARROW, g_rng)
		g_fly = g_fly and gd.elements.size() == 1 and gd.elements[0].id == &"flying"
	_check(g_fly, "아기 까마귀는 비행 속성만")
	var g_c: Creature = main._hatch(CreatureCatalog.SPARROW, Config.FORAGE_CELLS[4])
	_check(g_c.data.species.sprite_sheets.has(&"flying") and g_c.data.move_speed() > 1.4, "아기 까마귀 부화 (비행 그림, 빨리 날아다님)")
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
	g_t.hp = U + HunterClass.companion_damage(1)
	g_t.position = gh.companion.position + Vector2(90, 0)
	gh.companion.cooldown = 0.0
	gh._tick_companion(gh.companion, 0.01)
	_check(g_t.hp == U and not g_t.in_air() and g_t._rest > 0.0, "아기 까마귀가 날던 까마귀를 쪼아 떨어뜨림")
	main.leave_hunt()

	# 37. 도마리 (4구역, 2막 마지막 구역): 고목 그루터기 · 장승 한 쌍 · 아기 나무 정령 (2026-09-29)
	var d_zi := 3
	var d_z: Dictionary = Config.HUNT_ZONES[d_zi]
	_check(d_z.name == "도마리" and d_z.monster == "고목 그루터기" and d_z.boss_monster == "천하대장군" and d_z.partner.name == "지하여장군", "4구역 도마리: 고목 그루터기 · 천하대장군 · 지하여장군")
	var d_map := HuntMap.load_map("doma")
	_check(d_map.size == Vector2i(52, 30) and not d_map.find("G").is_empty() and not d_map.find("u").is_empty(), "도마리 칸 지도 52x30 (비닐하우스 · 그루터기)")
	var d_g := d_map.find("G")[0]
	_check(not d_map.is_free(Rect2(d_g - Vector2(4, 3), Vector2(8, 6))) and not d_map.monster_ok(d_map.find("u")[0]), "장작 비닐하우스 · 그루터기는 막힘")
	var d_c: Creature = main._hatch(CreatureCatalog.TREE_SPIRIT, Config.FORAGE_CELLS[5])
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
	_check(d_s.buried and d_s.disguise and d_s.hp == HunterSkills.monster_hp(3, d_z.hp), "고목 그루터기는 그루터기인 척 숨어 있음 (체력 %d)" % d_s.hp)
	d_s.position = main.player.feet() + Vector2(Config.WILD_BURROW_POP_DISTANCE - 10, 0)
	dh.tick(0.01)
	_check(not d_s.buried, "가까이 가면 일어남")
	# 덩굴 묶기: 잠깐 붙잡음
	d_s.position = dh.companion.position + Vector2(Config.COMPANION_BIND_RANGE - 10, 0)
	dh.companion.cooldown = 0.0
	var d_hp0 := d_s.hp
	dh._tick_companion(dh.companion, 0.01)
	_check(d_s.stunned() and d_s.hp == d_hp0 - HunterClass.companion_damage(1), "아기 나무 정령이 덩굴로 묶음 (피해 1 + 멈춤)")
	# 대장: 장승 한 쌍
	for o in dh.slimes.duplicate():
		dh.slimes.erase(o)
		o.queue_free()
	dh.spawn_boss()
	var d_bs := dh.slimes.filter(func(o: WildSlime) -> bool: return o.boss)
	_check(d_bs.size() == 2 and d_bs[0].title == "천하대장군" and d_bs[1].title == "지하여장군" and d_bs[0].pattern == &"log" and d_bs[1].pattern == &"slam" and d_bs[0].hp == HunterSkills.monster_hp(3, d_z.boss_hp), "장승 한 쌍 (천하대장군 통나무 · 지하여장군 내려찍기, 체력 %d씩)" % d_bs[0].hp)
	var d_ch: WildSlime = d_bs[0]
	var d_ji: WildSlime = d_bs[1]
	d_ji.position = Vector2(-500, -500)
	d_ch.ai_enabled = true
	d_ch._pattern_cd = 0.0
	main.player.position = dh.map.pixel_size() / 2.0 + Vector2(0, 60)
	d_ch.position = main.player.feet() + Vector2(0, -120)
	dh.life = 100
	dh._invulnerable = 0.0
	dh.tick(0.05)
	var d_tel := d_ch.telegraph()
	_check(d_tel.get("kind", &"") == &"lane" and d_tel.from.distance_to(d_tel.to) > 150.0, "천하대장군 통나무 굴리기 긴 띠 예고")
	for i in 40:
		dh.tick(0.05)
	_check(dh.life == 100 - d_ch.damage, "띠 위에 서 있으면 굴러온 통나무에 치임")
	d_ch._recover = 0.0
	d_ch._pattern_cd = 0.0
	dh.life = 100
	dh._invulnerable = 0.0
	dh.tick(0.05)
	main.player.position += Vector2(60, 0)
	for i in 40:
		dh.tick(0.05)
	_check(dh.life == 100, "옆으로 비키면 통나무에 안 맞음")
	d_ch.ai_enabled = false
	# 대장은 몸에 닿기만 해선 안 다침 (예고 패턴으로만)
	d_ch._recover = 1.0
	d_ch.position = main.player.feet()
	dh.life = 100
	dh._invulnerable = 0.0
	for i in 5:
		dh.tick(0.05)
	_check(dh.life == 100, "대장 몸에 닿기만 해선 하트가 안 줆")
	d_ch.position = main.player.feet() + Vector2(0, -120)
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
	# 잡템 이름은 구역 몬스터에 맞춤 (금사리 모래게 껍데기 · 광동리 까마귀 깃털 · 도마리 고목 옹이)
	var j_rng := RandomNumberGenerator.new()
	var j_names := {}
	for zi in 4:
		for k in 400:
			var jd := HuntLoot.roll_for_kill(j_rng, zi)
			if jd.get("kind") == &"junk":
				j_names[zi] = HuntLoot.label(jd)
				break
	_check(j_names.get(0) == "슬라임 젤리" and j_names.get(1) == "모래게 껍데기" and j_names.get(2) == "까마귀 깃털" and j_names.get(3) == "고목 옹이", "잡템 이름이 구역마다 다름 %s" % j_names)

	# 무기 (2026-09-29 사용자: 근거리 · 활 · 지팡이). 무기 칸이 비면 사냥칼.
	GameState.reset()
	GameState.hunter_unlocked = true
	GameState.first_egg_done = true
	GameState.waypoints = [0, 1, 2, 3]
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
	main.player.position = main.hunt_gate.position
	main.enter_hunt(null, 0)
	var wph: HuntGround = main.hunt
	wph.set_ai(false)
	wph.set_process(false)
	var w_feet: Vector2 = main.player.feet()
	for o: WildSlime in wph.slimes:
		o.position = w_feet + Vector2(-300, 0)
	var w_t: WildSlime = wph.slimes[0]
	var bow_d := HunterClass.hunter_damage(1, &"bow")
	w_t.hp = 3 * U
	w_t.position = w_feet + Vector2(120, 8)
	_check(wph.swing(Vector2.RIGHT) == 1 and wph.shots.size() == 1, "활: 클릭하면 화살이 날아감")
	for i in 30:
		wph.tick(1.0 / 30.0)
	_check(w_t.hp == 3 * U - bow_d and wph.shots.is_empty(), "화살이 120 떨어진 몬스터에 맞고 사라짐")
	w_t.position = w_feet + Vector2(220, 8)
	wph._cooldown = 0.0
	wph.swing(Vector2.RIGHT)
	for i in 40:
		wph.tick(1.0 / 30.0)
	_check(w_t.hp == 3 * U - bow_d, "사거리(150) 밖은 안 맞음")
	# 지팡이: 물 = 느려짐 · 땅 = 멈춤 · 불 = 잠시 뒤 한 번 더
	for el: StringName in [&"water_staff", &"earth_staff", &"fire_staff"]:
		Wearables.gain_rolled(Wearables.roll_gear(wr, &"normal", {}, el))
		GameState.worn[&"hunter"][&"weapon"] = StringName("gear_%d" % GameState.gear_serial)
		w_t.hp = 5 * U
		w_t._stun = 0.0
		w_t._slow = 0.0
		w_t.position = w_feet + Vector2(90, 8)
		var w_near: WildSlime = wph.slimes[1]
		w_near.hp = 5 * U
		w_near.position = w_t.position + Vector2(10, 6)
		wph._cooldown = 0.0
		wph.swing(Vector2.RIGHT)
		for i in 25:
			wph.tick(1.0 / 30.0)
		var w_fx := {&"water_staff": w_t.slowed(), &"earth_staff": w_t.stunned(), &"fire_staff": wph._burns.size() == 2}
		var staff_d := HunterClass.hunter_damage(1, &"staff")
		_check(w_t.hp == 5 * U - staff_d and w_near.hp == 5 * U - staff_d and w_fx[el], "%s: 구슬이 터져 둘레 둘 다 1 피해 + %s" % [Wearables.ITEMS[el].name, Wearables.ELEMENT_EFFECTS[Wearables.ITEMS[el].weapon.element]])
	for i in 60:
		wph.tick(1.0 / 30.0)
	_check(w_t.hp == 5 * U - 2 * HunterClass.hunter_damage(1, &"staff"), "불 구슬: 잠시 뒤 한 번 더 피해")
	# 근거리 무기: 전투 도끼는 사냥칼보다 넓게
	Wearables.gain_rolled(Wearables.roll_gear(wr, &"normal", {}, &"battle_axe"))
	GameState.worn[&"hunter"][&"weapon"] = StringName("gear_%d" % GameState.gear_serial)
	w_t.position = w_feet + Vector2(0, -8) + Vector2(Config.SWING_REACH + 24, 0)
	w_t.hp = 5 * U
	wph._cooldown = 0.0
	_check(wph.swing(Vector2.RIGHT) == 1 and w_t.hp == 5 * U - HunterClass.hunter_damage(1, &"melee"), "전투 도끼: 사냥칼이 안 닿는 옆까지 벰")
	main.leave_hunt()
	# 나는 까마귀도 화살엔 맞는다
	GameState.worn[&"hunter"][&"weapon"] = &"gear_1"
	GameState.hunts_today = 0
	main.player.position = main.hunt_gate.position
	main.enter_hunt(null, 2)
	var wpg: HuntGround = main.hunt
	wpg.set_ai(false)
	wpg.set_process(false)
	var wg_feet: Vector2 = main.player.feet()
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
	_check(w_sp.hp == w_sp_hp - HunterClass.hunter_damage(1, &"bow") and not w_sp.in_air(), "화살은 나는 까마귀도 맞혀 떨어뜨림")
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
	var b_c: Creature = main._hatch(CreatureCatalog.WILL_O, Config.FORAGE_CELLS[5])
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
	var b_feet: Vector2 = main.player.feet()
	var b_lamps := bjh.lamps.duplicate()
	bjh.lamps.clear()
	bjh.companion.position = b_feet + Vector2(0, -220)
	for o: WildSlime in bjh.slimes:
		o.position = b_feet + Vector2(-320, 0)
	var b_g: WildSlime = bjh.slimes[0]
	b_g.hp = 3 * U
	b_g.position = b_feet + Vector2(120, 8)
	bjh.tick(0.01)
	_check(not bjh.hittable(b_g) and is_equal_approx(b_g.modulate.a, Config.GHOST_FADE), "어둠 속 도깨비불은 반쯤 비침 (못 맞힘)")
	_check(bjh.in_light(b_feet + Vector2(20, 0)) and not bjh.in_light(b_feet + Vector2(Config.LANTERN_RADIUS + 10, 0)), "사냥꾼 호롱 둘레만 밝음")
	bjh._cooldown = 0.0
	bjh.swing(Vector2.RIGHT)
	for i in 30:
		bjh.tick(1.0 / 30.0)
	_check(b_g.hp == 3 * U, "화살이 어둠 속 도깨비불을 지나감")
	bjh.lamps.assign(b_lamps)
	_check(bjh.hittable(b_g) == bjh.in_light(b_g.position) and bjh.in_light(b_lamps[0] + Vector2(0, 10)), "가로등 아래는 밝음")
	# 불빛 동행: 동행 둘레 유령도 맞고, 불씨로 잠시 뒤 한 번 더 (아직 날던 화살은 치움)
	bjh.lamps.clear()
	bjh.shots.clear()
	b_g.position = bjh.companion.position + Vector2(20, 0)
	_check(bjh.hittable(b_g), "아기 도깨비불 불빛 안의 도깨비불은 맞음")
	bjh.companion_attack(b_g)
	_check(b_g.hp == 3 * U - HunterClass.companion_damage(1) and bjh._burns.size() == 1, "불씨: 1 피해 + 불붙음")
	for i in int(Config.STAFF_BURN_DELAY * 30) + 5:
		# 동행이 사냥꾼 쪽으로 걸어가도 도깨비불이 불빛 안에 있게 (불씨는 불빛 안에서만 탄다)
		b_g.position = bjh.companion.position + Vector2(20, 0)
		bjh.companion.cooldown = 99.0  # 동행이 다시 치지 않게 (크리처 공격 간격은 타고난 능력치에 따라 1.5초보다 짧을 수 있다)
		bjh.tick(1.0 / 30.0)
	_check(b_g.hp == 3 * U - 2 * HunterClass.companion_damage(1), "불씨: 잠시 뒤 한 번 더 피해 (체력 %d)" % b_g.hp)
	# 도깨비불 불똥: 불빛 안에서만 부풀어 원 안을 다치게 함
	var b_w: WildSlime = bjh.slimes[1]
	b_w.lit = false
	b_w._lunge_cd = 0.0
	_check(not b_w._tick_attack(0.01, b_w.position + Vector2(10, 0)) and b_w._burst < 0.0, "어둠 속 도깨비불은 불똥을 안 튀김")
	b_w.position = b_feet + Vector2(16, 0)
	b_w.ai_enabled = true
	bjh._invulnerable = 0.0
	var b_h0 := bjh.life
	bjh.tick(0.02)
	_check(b_w._burst >= 0.0, "호롱 불빛에 들어온 도깨비불이 부풂 (예고)")
	for i in int(b_z.windup * 30) + 3:
		bjh.tick(1.0 / 30.0)
	_check(bjh.life == b_h0 - b_w.damage and b_w._recover > 0.0, "불똥에 다침 (체력 -%d), 쪼그라든 동안 칠 틈" % b_w.damage)
	b_w.ai_enabled = false
	# 유령 막차: 전조등 띠 예고 → 도로 따라 돌진, 닿으면 다침. 대장은 어둠에서도 맞음
	bjh.lamps.assign(b_lamps)
	for o: WildSlime in bjh.slimes.duplicate():
		bjh.slimes.erase(o)
		o.queue_free()
	var b_bus: WildSlime = bjh.spawn_boss()
	_check(b_bus.boss_frame == Vector2i(96, 48) and b_bus.pattern == &"bus" and b_bus.hp == HunterSkills.monster_hp(4, b_z.boss_hp) and bjh.hittable(b_bus), "유령 막차 (96x48, 체력 %d, 어둠에서도 맞음)" % b_bus.hp)
	b_bus.position = b_feet + Vector2(150, 0)
	b_bus.ai_enabled = true
	b_bus._pattern_cd = 0.0
	bjh._invulnerable = 0.0
	bjh.life = 200
	b_h0 = bjh.life
	bjh.tick(0.02)
	_check(b_bus._bus_aim >= 0.0 and b_bus._bus_to.y == b_bus._bus_from.y, "막차가 전조등으로 가로 띠를 비춤 (예고)")
	for i in int((Config.BUS_WINDUP + Config.BUS_TIME) * 30) + 5:
		bjh.tick(1.0 / 30.0)
	_check(bjh.life < b_h0 and b_bus._runs == 1, "막차 돌진에 치임 (체력 %d → %d)" % [b_h0, bjh.life])
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
	main.restore_yak()
	SiteWork.fill(&"yak")
	_check(main.restore_yak() and GameState.yak_state == 2 and main.alchemist.visible and main.herb_bed != null and GameState.money == 7 and GameState.roots == 0 and GameState.material2 == 0,
		"약방 복구 (돈 %d · 도라지 %d · 장승 조각 %d) → 연금술사" % [Config.YAK_COST_MONEY, Config.YAK_COST_ROOTS, Config.YAK_COST_MATERIAL])
	_check(FacilityWorkers.is_open(&"yak") and GameState.herb_bed == Config.HERB_BED_PER_DAY, "약방 일꾼 자리 (도라지밭, 하루 %d)" % Config.HERB_BED_PER_DAY)
	_check(main.pick_herb_bed() and GameState.roots == 1 and GameState.herb_bed == Config.HERB_BED_PER_DAY - 1, "도라지밭에서 손으로 도라지 하나")
	b_c.home = Config.FORAGE_CELLS[5]
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
	GameState.crops = 3
	_check(main.brew(&"tonic") and GameState.tonics == 1 and GameState.crops == 0 and GameState.roots == 0, "크리처 보약 (무 3 · 도라지 2)")
	b_c._reset_timer()
	var y_t1 := b_c._timer
	_check(main.brew_options().has(&"feed_tonic") and main.feed_tonic() and not main.feed_tonic() and GameState.tonics == 0, "보약 먹이기 (하루 한 번)")
	_check(is_equal_approx(b_c._timer, y_t1 / Config.TONIC_SPEED_MULT), "보약 먹은 날 크리처 일 두 배 빠름")
	GameState.junk = Config.JUNK_KEEP + 5
	var y_m0 := GameState.money
	main.player.position = Farm.center_of(main.SUPPLY_RECT.position + Vector2i(1, 1))
	main._supply_interact()
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
	var m_t: Creature = main._hatch(CreatureCatalog.TIGER, Config.FORAGE_CELLS[5])
	_check(m_t.data.species.display_name == "아기 호랑이" and m_t.data.elements[0].id == &"earth" and HuntCompanion.style_name(m_t.data) == "포효" and m_t.data.species.guards_coop, "아기 호랑이 (땅, 동행 포효, 축사 지킴이)")
	var m_w: Creature = main._hatch(CreatureCatalog.WHITE_TIGER, Config.FORAGE_CELLS[5])
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
	var m_feet: Vector2 = main.player.feet()
	for o: WildSlime in mh.slimes:
		o.position = m_feet + Vector2(-400, 0)
	var m_a: WildSlime = mh.slimes[0]
	var m_b: WildSlime = mh.slimes[1]
	_check(m_a.wolf and m_a._lunge_cd >= Config.WOLF_FIRST_GAP, "늑대 첫 달려들기는 어긋나게 늦춤")
	# 둘러서서 돈다 (나무가 없는 빈터에서)
	m_a.position = m_feet + Vector2(100, 0)
	m_a._lunge_cd = 5.0
	# 둘레 자리 각도를 위쪽에서 시작 (사냥꾼이 맵 아래 가장자리라 아래쪽 자리는 영역 밖으로 밀려 거리가 짧아짐, 예전엔 무작위라 가끔 실패)
	m_a._angle = -PI / 2.0
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
	m_b.hp = 5 * U
	mh.companion.position = m_feet + Vector2(0, -60)
	m_b.position = mh.companion.position + Vector2(20, 0)
	m_c.position = mh.companion.position + Vector2(-30, 0)
	m_c._stun = 0.0
	mh.companion_attack(m_b)
	_check(m_b.hp == 5 * U - HunterClass.companion_damage(1) and m_b.stunned() and m_c.stunned(), "포효: 1 피해 + 둘레 멈춤")
	main.leave_hunt()
	GameState.hunts_today = 0
	main.enter_hunt(m_w, m_zi)
	mh = main.hunt
	mh.set_ai(false)
	mh.set_process(false)
	mh.companion_ai = false
	m_b = mh.slimes[0]
	m_b.hp = 5 * U
	m_b.position = mh.companion.position + Vector2(20, 0)
	mh.companion_attack(m_b)
	_check(m_b.hp == 5 * U - HunterClass.companion_damage(2), "아기 백호 번개 발톱: 한 방에 2 피해")
	# 산군 백호: 도약 (착지 원, 새끼 없음) → 쓰러지는 나무 → 포효 (굳음)
	for o: WildSlime in mh.slimes.duplicate():
		mh.slimes.erase(o)
		o.queue_free()
	m_feet = main.player.feet()
	var m_boss: WildSlime = mh.spawn_boss()
	_check(m_boss.pattern == &"tiger" and m_boss.hp == HunterSkills.monster_hp(5, m_z.boss_hp) and m_boss.title == "산군 백호", "산군 백호 (체력 %d)" % m_boss.hp)
	m_boss.position = m_feet + Vector2(120, 0)
	m_boss.ai_enabled = true
	m_boss._pattern_cd = 0.0
	mh._invulnerable = 0.0
	var m_h0 := mh.life
	mh.tick(0.02)
	_check(m_boss._air_t >= 0.0 and m_boss.telegraph().kind == &"circle", "백호 도약 (착지 원 예고)")
	for i in int(Config.SLAM_AIR_TIME * 30) + 4:
		mh.tick(1.0 / 30.0)
	_check(mh.life == m_h0 - m_boss.damage and mh.slimes.size() == 1, "착지에 다침 (체력 -%d), 새끼는 안 나옴" % m_boss.damage)
	m_boss._recover = 0.0
	m_boss._pattern_cd = 0.0
	m_boss.position = main.player.feet() + Vector2(60, 0)
	mh.tick(0.02)
	_check(m_boss._log_aim >= 0.0, "쓰러지는 나무 (띠 예고)")
	m_boss._log_aim = -1.0
	m_boss._recover = 0.0
	m_boss._pattern_cd = 0.0
	m_boss.position = main.player.feet() + Vector2(40, 0)
	mh.tick(0.02)
	_check(m_boss._roar >= 0.0 and m_boss.telegraph().get("roar", false), "포효 (둘레 원 예고)")
	for i in int(Config.TIGER_ROAR_WINDUP * 30) + 3:
		mh.tick(1.0 / 30.0)
	mh._cooldown = 0.0
	_check(mh.frozen > 0.0 and main.player.frozen and mh.swing(Vector2.RIGHT) == 0, "포효 원 안이면 잠깐 굳음 (못 휘두름)")
	for i in int(Config.TIGER_ROAR_FREEZE * 30) + 3:
		mh.tick(1.0 / 30.0)
	_check(mh.frozen == 0.0 and not main.player.frozen, "굳음이 풀림")
	m_boss.ai_enabled = false
	# 대장을 잡으면 산군 발톱 + 다음 날 축사 터, 대장 알은 드물게 아기 백호
	GameState.material3 = 0
	GameState.barn_state = 0
	HuntGround.egg_roll = 0.0
	mh._defeat(m_boss)
	_check(GameState.material3 == 1 and GameState.barn_boss_down and mh.path_open and mh.gate_closed() and mh.path_block().contains("축사"), "산군 백호를 쓰러뜨리면 산군 발톱 1, 역동 쪽 목책은 축사를 고쳐야 열림")
	main.player.position = mh.next_area().get_center()
	_check(not mh.advance() and mh.zone == m_zi, "목책이 닫혀 있으면 역동으로 못 감")
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
	main.restore_barn()
	SiteWork.fill(&"barn")
	_check(main.restore_barn() and GameState.barn_state == 2 and main.rancher.visible and GameState.hens == Config.START_HENS and GameState.money == 3 and GameState.crops == 4 and GameState.material3 == 0,
		"축사 복구 (돈 %d · 무 %d · 산군 발톱 %d) → 목축인 · 암탉 %d" % [Config.BARN_COST_MONEY, Config.BARN_COST_CROPS, Config.BARN_COST_MATERIAL, Config.START_HENS])
	_check(FacilityWorkers.is_open(&"barn"), "축사 일꾼 자리 (모이 주기)")
	_check(main.coop_options().has(&"lunch") and main.coop_options().has(&"feed"), "닭장: 모이 주기 · 목축인에게 도시락 부탁")
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
	GameState.crops = 1
	_check(main.coop_options().has(&"lunch") and main.coop_action(&"lunch") and GameState.lunches == 1 and GameState.hen_eggs == 3 and GameState.crops == 0, "목축인 사냥 도시락 (달걀 %d · 무 %d)" % [Config.LUNCH_EGGS, Config.LUNCH_CROPS])
	_check(main.supply_options().has(&"display_hen_eggs") and main.supply_action(&"display_hen_eggs") and GameState.displayed_hen_eggs == 3, "달걀 진열")
	var m_m0 := GameState.money
	main.next_day()
	_check(GameState.money >= m_m0 + 3 * Config.HEN_EGG_PRICE and GameState.displayed_hen_eggs == 0, "진열한 달걀이 밤사이 팔림")
	GameState.hunts_today = 0
	main.enter_hunt(null, 0)
	_check(main.hunt.lunch and GameState.lunches == 0 and main.hunt.life == main.hunt.max_life() and main.hunt.max_life() == Config.HUNTER_HP + Config.HP_PER_LEVEL * (GameState.hunter_level - 1) + Config.HP_PER_HEART * Wearables.bonus_hearts(&"hunter") + Config.LUNCH_HP, "사냥 도시락: 들어갈 때 먹고 체력 +%d" % Config.LUNCH_HP)
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
			_check(not ts.restore_forge() and SiteWork.building(&"forge") and not ts.smith.visible, "대장간 고치기 직전: 바로 공사를 시작할 수 있음")
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

	# 42) 크리처 원정 + 입양 (2026-10-01 사용자 선택 B + D)
	var ex: Node2D = load("res://scenes/main.tscn").instantiate()
	add_child(ex)
	await get_tree().process_frame
	TestStarts.apply(ex, &"barn")
	var ex_idle := Expedition.idle(ex)
	_check(Expedition.zones() == range(6) and ex_idle.size() == 5, "원정: 대장 잡은 구역 %s · 쉬는 · 채집 %d마리" % [Expedition.zones(), ex_idle.size()])
	ex.player.position = ex.hunt_gate.position + Vector2(0, 8)
	HunterClass.choose(&"archer")
	ex.interact()
	_check(ex.menu_open and ex.menu_kind == &"waypoint" and ex._menu_options.has(&"expedition"), "사냥터 입구에서 F: 웨이포인트 창에 크리처 원정대")
	ex.menu_index = ex._menu_options.find(&"expedition")
	ex.menu_confirm()
	_check(ex.menu_open and ex.menu_kind == &"expedition" and ex._menu_options.size() == Expedition.zones().size() + 1, "원정대 → 원정 선택창 (대장 잡은 구역 + 닫기)")
	ex.menu_index = 1
	ex.menu_confirm()
	var team1 := Expedition.team(ex, 1)
	_check(team1.size() == Config.EXPEDITION_TEAM_MAX and team1.filter(func(x: Creature) -> bool: return x.data.species == CreatureCatalog.GOLD_TOAD).size() == 2 and Expedition.power(team1, 1) > Config.EXPEDITION_TEAM_MAX,
		"금사리로 5마리: 아기 금두꺼비(고향) 먼저 (%s)" % ", ".join(team1.map(func(x: Creature) -> String: return x.data.species.display_name)))
	_check(team1.all(func(x: Creature) -> bool: return not x.visible and x.job == Expedition.JOB) and Expedition.idle(ex).is_empty() and ex.companion_candidates().size() == ex.creatures.size() - 5,
		"원정 중인 크리처는 마을에서 사라지고 동행 · 채집에서 빠짐")
	ex.close_menu()
	_check(Expedition.send(ex, 2) == 0, "쉬는 크리처가 3마리보다 적으면 원정대를 못 보냄")
	var ex_eggs_before := GameState.village_eggs.size() + GameState.farmer_eggs.size()
	var ex_m0 := GameState.money
	var ex_j0 := GameState.junk
	var ex_lines: Array[String] = ex.next_day()
	var ex_line := ""
	for l in ex_lines:
		if l.begins_with("원정대"):
			ex_line = l
	_check(ex_line != "" and GameState.money > ex_m0 and GameState.junk > ex_j0 and GameState.village_eggs.size() + GameState.farmer_eggs.size() == ex_eggs_before,
		"아침 카드: %s (알은 안 가져옴)" % ex_line)
	_check(Expedition.team(ex, 1).size() == 5, "원정대는 불러들일 때까지 날마다 다시 감")
	# 1/3 어림: 5마리 보통 팀이 100밤 가져온 돈 평균
	var ex_erng := RandomNumberGenerator.new()
	ex_erng.seed = 42
	var ex_ez: Dictionary = Config.EXPEDITION_ZONES[1]
	var ex_esum := 0
	for i in 100:
		ex_esum += ex_erng.randi_range(ex_ez.money[0], ex_ez.money[1])
	_check(absf(ex_esum / 100.0 - 67.0 / 3.0) < 4.0, "금사리 보통 팀 하룻밤 돈 평균 %.0f원 ≈ 사냥 한 번(67원)의 1/3" % (ex_esum / 100.0))
	Expedition.recall(ex, 1)
	_check(Expedition.team(ex, 1).is_empty() and Expedition.idle(ex).size() == 5 and team1.all(func(x: Creature) -> bool: return x.visible and x.job == CreatureJobs.FORAGE), "불러들이면 마을로 돌아와 채집")
	# 입양
	_check(&"adopt" in ex.supply_options(), "공급함: 크리처 입양 보내기")
	var ex_n_before: int = ex.creatures.size()
	var ex_scrap0 := GameState.scrap
	var ex_potions0 := GameState.potions
	var ex_who1 := Expedition.adopt(ex, Expedition.idle(ex)[0])
	var ex_who2 := Expedition.adopt(ex, Expedition.idle(ex)[0])
	_check(ex_who1 == &"smith" and ex_who2 == &"alchemist" and GameState.scrap == ex_scrap0 + 5 and GameState.potions == ex_potions0 + 2, "입양: 대장장이 → 고철 +5, 연금술사 → 빨간 물약 +2")
	await get_tree().process_frame
	_check(ex.creatures.size() == ex_n_before - 2 and ex.adoptees.size() == 2 and GameState.adopted.size() == 2 and ex.adoptees[0].position == Farm.center_of(Config.ADOPT_SPOTS[&"smith"][0]),
		"입양된 크리처는 마을 크리처에서 빠지고 주민 곁에 있음")
	for i in 20:
		if Expedition.idle(ex).is_empty():
			break
		Expedition.adopt(ex, Expedition.idle(ex)[0])
	_check(Expedition.adopted_by(&"smith") <= Config.ADOPT_CAP and GameState.adopted.size() == 5, "쉬는 크리처가 다 입양되면 끝 (%d마리)" % GameState.adopted.size())
	ex.queue_free()
	await get_tree().process_frame

	# 43) 소리 (2026-10-01 사운드 첫 단계): 버스 · 소리 파일 · 배경음 고르기 · 크기 단계
	await _sound_checks()

	# 44) 사냥 손맛 · 몰아잡기 (2026-10-02): 구르기 · 연속 베기 3타 · 꾹 눌러 공격 · 떼 · 한꺼번에 덮치는 수 · 드롭 몫
	await _pace_checks()

	# 45) 활 몰아잡기 (2026-10-02): 관통 · 부채살 · 3연사
	await _bow_style_checks()

	# 46) 사냥꾼 레벨 · 스킬 (2026-10-02 사용자 선택 B: 무기 트리 셋 + 조련)
	await _hunter_skill_checks()

	# 46b) 사냥꾼 직업 · 스탯 · 초기화 (2026-10-03 사용자 선택 B · B · B)
	await _hunter_class_checks()

	# 47) 4막 첫 구역 역동 (2026-10-02 사용자 선택 A): 켄타우로스 창기병 · 역마 장군 · 아기 망아지 (밭 갈기 · 뒷발차기)
	await _yeokdong_checks()

	# 48) 4막 대장 구역 곤지암 (2026-10-02 사용자 선택 A 악마형): 뿔 악귀 · 마왕 · 아기 악귀 (밤일 · 불 할퀴기 + 겁주기)
	await _gonjiam_checks()

	# 49) 시설 4 나루터 (2026-10-02 사용자 선택 A 나루터 + B 통발): 팔당호 물가 · 뱃사공 · 통발 · 물고기 몰기 · 매운탕
	await _naru_checks()

	# 50) 5막 (2026-10-03 사용자: 9구역 귀여리 · 10구역 소내섬 와이번 + 일반 용, 드물게 희귀 용 셋)
	await _sonae_checks()
	await _guiyeo_checks()

	# 51) 시설 5 마을회관 · 이장 + 잔치상 엔딩 (2026-10-03 사용자 선택 A + B)
	await _hall_checks()

	# 52) 밭 작물 (2026-10-03 백로그 5번): 감자 · 고추 · 배추, 대장 땅 씨앗 · 구역 작물 · 여러 번 따기 · 진열
	await _crop_checks()
	# 53) 작물 등급 (돌봄 점수) · 퇴비 · 사냥 음식 (2026-10-03 사용자 선택)
	await _grade_checks()

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
	# 섞인 상태: 시각 · 알 두 군데 · 부화 중 · 가방 · 창고 장비 · 밭 물 · 풀밭 · 병아리 · 들고 있는 크리처
	GameState.minutes = 14 * 60 + 30
	GameState.farmer_eggs.append(load(TestStarts.SPECIES[&"tiger"]))
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
	# 사냥꾼 레벨 · 스킬 (2026-10-02)
	GameState.hunter_level = 13
	GameState.hunter_xp = 77
	GameState.skill_points = 2
	GameState.skills = {&"pierce": 2, &"spread": 1, &"fight_together": 3}
	GameState.skill_left = {&"bow": &"spread"}
	GameState.fed = 1
	GameState.displayed_crops = 5
	GameState.tonic_day = 69
	GameState.tool_levels[Farm.Work.HARVEST] = 1
	a.farm.do_work(Farm.Work.WATER, fc(2, 2))
	a.forage.water(Config.FORAGE_CELLS[7])
	var carried: Creature = a.creatures[5]
	a.player.position = Farm.center_of(fc(9, 9))
	carried.pick_up(a.player)
	a.creatures[0].data.radius_level = 3
	# 원정 · 입양 (42): 하나는 대장장이에게 입양, 남은 쉬는 크리처는 금사리 원정
	Expedition.adopt(a, Expedition.idle(a)[-1])
	Expedition.send(a, 1)
	a.player.position = Farm.center_of(Config.HUNTER_CELL)
	a.player.facing = Vector2i.LEFT
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
	_check(b.adoptees.size() == 1 and Expedition.team(b, 1).size() == 3 and Expedition.team(b, 1).all(func(x: Creature) -> bool: return not x.visible), "입양된 크리처 · 원정 중인 크리처 그대로")
	_check(diff.is_empty(), "저장 전과 불러온 뒤 전체 상태가 같음 %s" % (diff if not diff.is_empty() else ""))
	_check(GameState.gear == gear_before and b.creatures.map(func(c: Creature) -> String: return c.describe()) == creatures_before, "장비 옵션 · 크리처 능력치 · 일 · 훈련이 그대로 (%d개 · %d마리)" % [GameState.gear.size(), b.creatures.size()])
	_check(GameState.bag.hunter is Array and GameState.bag.hunter.get_typed_builtin() == TYPE_STRING_NAME and GameState.farmer_eggs.get_typed_class_name() == &"Resource" or GameState.farmer_eggs[0] is CreatureSpecies, "가방 · 알 목록 타입이 그대로")
	_check(GameState.farmer_eggs.size() >= 2 and GameState.farmer_eggs[-2].id == &"tiger" and GameState.farmer_eggs.back().id == &"gold_toad" and GameState.village_eggs.back().id == &"slime" and b.incubating_days == 2 and b.incubating_species.id == &"will_o", "알 (주인공 · 공급함) · 부화기 그대로")
	_check(b.forge.label == "대장간" and b.scrap_heap != null and b.smith.visible and b.yak.label == "약방" and b.herb_bed != null and b.alchemist.visible and b.barn.label == "축사" and b.rancher.visible, "대장간 · 약방 · 축사 고친 모습 · 일꾼 셋 (값을 다시 치르지 않음)")
	_check(GameState.hens == 3 and GameState.chicks == [2, 1] and GameState.nest == 3, "닭장 (암탉 · 병아리 · 둥지) 그대로")
	_check(b.farm.get_cell(fc(2, 2)).watered and b.farm.get_cell(fc(7, 6)) != null and b.forage.watered.has(Config.FORAGE_CELLS[7]), "밭 네 구역 · 물 준 칸 · 물 준 풀밭")
	_check(b.player.position == Farm.center_of(Config.HUNTER_CELL) and b.player.facing == Vector2i.LEFT and b.creatures[5].carried_by == null and b.creatures[5].home == Config.HUNTER_CELL, "주인공 자리 · 방향 그대로 · 들고 있던 크리처는 주인공 발밑에 놓임")
	_check(is_equal_approx(GameState.minutes, 14 * 60 + 30) and b.save_slot == -1, "시각 오후 2:30 그대로")
	# 불러온 뒤에도 게임이 이어진다: 하루 넘기기 · 사냥
	var eggs_n := GameState.farmer_eggs.size()
	b.next_day()
	_check(GameState.day == 71 and b.incubating_days == 1, "불러온 뒤 하루 넘기기")
	b.player.position = b.hunt_gate.position
	_check(b.enter_hunt(null, 5) and b.hunt != null, "불러온 뒤 밀목 웨이포인트로 사냥")

	# 사냥터 안에서 저장하고 나가기: 마을로 돌아온 채로 저장
	b.save_slot = 3
	b.open_menu(&"pause")
	_check(b.hunt.process_mode == Node.PROCESS_MODE_DISABLED and b._menu_options == [&"resume", &"music_volume", &"sfx_volume", &"save_quit"], "사냥 중 Esc: 사냥터가 멈추고 계속하기 · 소리 크기 · 저장하고 나가기")
	b.close_menu()
	b.leave_hunt()
	_check(SaveGame.exists(3) and SaveGame.read(3).gs.hunts_today == 1 and SaveGame.read(3).gs.farmer_eggs.size() == eggs_n, "사냥터에서 돌아오면 저절로 저장")

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

	# 옛 마을 (VERSION 1, 26x15칸) 저장 파일: 밭 칸 · 크리처 자리를 새 배치로 옮겨 읽는다 (2026-10-01 마을 넓히기)
	var v1 := SaveGame.read(2)
	v1.version = 1
	v1.farm = {Vector2i(1, 2): [true, true, true, 2], Vector2i(12, 9): [true, false, false, 0]}
	v1.forage = {herbs = {Vector2i(16, 12): 0}, roots = {}, watered = {}, bonus_today = 0}
	v1.creatures = v1.creatures.slice(0, 3)
	v1.creatures[0].home = Vector2i(3, 3)
	v1.creatures[1].home = SaveGame.V1_SCRAP_SPOT
	v1.creatures[2].home = Vector2i(25, 1)
	v1.people = {&"farmer": [Vector2(600, 20), Vector2i.UP]}
	v1.erase("player")
	GameState.reset()
	c = load("res://scenes/main.tscn").instantiate()
	add_child(c)
	await get_tree().process_frame
	SaveGame.apply(c, v1)
	var p0: Rect2i = Config.FIELD_PLOTS[0]
	var p3: Rect2i = Config.FIELD_PLOTS[3]
	_check(c.farm.get_cell(p0.position).planted and c.farm.get_cell(p0.position).growth == 2 and c.farm.get_cell(p3.end - Vector2i.ONE).tilled, "옛 마을 저장: 밭 칸은 같은 구역 같은 자리로")
	_check(c.creatures[0].home == p0.position + Vector2i(2, 1) and c.creatures[1].home == Creature.scrap_spot() and c.creatures[2].home in Config.FORAGE_CELLS, "옛 마을 저장: 밭 · 고물 더미 앞 크리처는 새 자리로, 풀밭 크리처는 공급함 옆으로")
	_check(not c.forage.herbs.is_empty() and c.forage.herbs.keys().all(func(h: Vector2i) -> bool: return h in Config.HERB_SPOTS), "옛 마을 저장: 들나물은 새 풀밭에 다시 돋음")
	_check(c.player.position == Farm.center_of(Config.PLAYER_START), "옛 마을 저장: 주인공은 새 마을 처음 자리")
	c.queue_free()
	await get_tree().process_frame

	# 주인공 하나 전 (VERSION 2) 저장 파일: 조작하던 사람 자리에 주인공, 사냥꾼이 든 알은 주인공 손으로,
	# 사냥꾼 레벨 · 직업 · 장비 · 농부 장비는 그대로 (2026-10-03)
	var v2 := SaveGame.read(2)
	v2.version = 2
	v2.erase("player")
	v2.people = {&"farmer": [Vector2(100, 100), Vector2i.UP], &"hunter": [Vector2(700, 150), Vector2i.RIGHT], &"smith": [Vector2(300, 400), Vector2i.DOWN]}
	v2.active = &"hunter"
	var eggs_v2: int = v2.gs.farmer_eggs.size()
	v2.gs.hunter_eggs = [{res = TestStarts.SPECIES[&"foal"]}]
	var lv_v2: int = v2.gs.hunter_level
	GameState.reset()
	c = load("res://scenes/main.tscn").instantiate()
	add_child(c)
	await get_tree().process_frame
	SaveGame.apply(c, v2)
	_check(c.player.position == Vector2(700, 150) and c.player.facing == Vector2i.RIGHT, "옛 저장 (일곱 사람): 주인공은 조작하던 사냥꾼 자리에")
	_check(c.smith.position == Farm.center_of(Config.SMITH_CELL) and c.farmer.position == Farm.center_of(Config.FARMER_CELL), "옛 저장: 마을 사람은 제자리")
	_check(GameState.farmer_eggs.size() == eggs_v2 + 1 and GameState.farmer_eggs.back().id == &"foal", "옛 저장: 사냥꾼이 든 알은 주인공 손으로")
	_check(GameState.hunter_level == lv_v2 and GameState.gear == gear_before and c.player.outfit == &"farmer", "옛 저장: 레벨 · 장비 그대로, 마을에서는 밭 옷")
	c.queue_free()
	await get_tree().process_frame
	for i in range(1, SaveGame.SLOTS + 1):
		SaveGame.erase(i)
	SaveGame.dir = "user://"


## 옛 마을 (26x15칸) 밭 기준 칸 → 지금 배치에서 같은 밭 구역 같은 자리 (밭이 옮겨 가도 테스트가 같은 칸을 보게)
func fc(x: int, y: int) -> Vector2i:
	return SaveGame.v1_cell(Vector2i(x, y))


## c 로 대장간 앞에 서서 F
func forge_f(main: Node2D, c: Character) -> void:
	c.position = Farm.center_of(Config.FORGE_RECT.position + Vector2i(1, Config.FORGE_RECT.size.y))
	main.interact()


## 열린 선택창 · 가방 창을 닫는다
func close_all(main: Node2D) -> void:
	main.close_menu()
	main.close_inventory()
	if main.hunt:
		main.leave_hunt()


func _sound_checks() -> void:
	_check(AudioServer.get_bus_index(&"Music") > 0 and AudioServer.get_bus_index(&"SFX") > 0, "오디오 버스: Master · Music · SFX")
	var missing: Array[String] = []
	for id in [&"hoe", &"water", &"harvest", &"coin", &"hatch", &"hit", &"hurt"]:
		if Sound._stream(Sound.SFX_DIR, id) == null:
			missing.append(String(id))
	for id in [&"village_day", &"village_night", &"hunt"]:
		var st := Sound._stream(Sound.BGM_DIR, id)
		if st == null or not (st as AudioStreamOggVorbis).loop:
			missing.append(String(id))
	_check(missing.is_empty(), "효과음 7개 · 배경음 3개(반복) 모두 있음 %s" % [missing])
	var so: Node2D = load("res://scenes/main.tscn").instantiate()
	add_child(so)
	await get_tree().process_frame
	GameState.minutes = 8 * 60
	var day_bgm: StringName = so.wanted_bgm()
	GameState.minutes = Config.NIGHT_MUSIC_MINUTE + 30
	var night_bgm: StringName = so.wanted_bgm()
	GameState.hunter_unlocked = true
	GameState.hunts_today = 0
	so.hunter.position = so.hunt_gate.position
	so.enter_hunt()
	var hunt_bgm: StringName = so.wanted_bgm()
	await get_tree().process_frame
	_check(day_bgm == &"village_day" and night_bgm == &"village_night" and hunt_bgm == &"hunt" and Sound.bgm_name == &"hunt", "배경음: 낮 · 저녁 7시부터 밤 · 사냥터")
	so.leave_hunt()
	so.queue_free()
	await get_tree().process_frame
	var m0 := Sound.music_volume
	var steps: Array[float] = []
	var v := 1.0
	for i in Sound.VOLUME_STEPS.size():
		steps.append(v)
		v = Sound.next_step(v)
	_check(steps == Sound.VOLUME_STEPS and Sound.next_step(0.0) == 1.0 and Sound.percent(0.0) == "끔" and Sound.percent(0.6) == "60%", "크기 단계 100 → 80 → … → 끔 → 100")
	Sound.set_music_volume(0.0)
	_check(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Music")), "배경음 끔 = Music 버스 음소거")
	Sound.set_music_volume(m0)
	_check(not AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Music")), "배경음 다시 켬")


func _pace_checks() -> void:
	HuntGround.feel = true
	HuntGround.swarm = true
	HuntGround.loot_enabled = false
	var m: Node2D = load("res://scenes/main.tscn").instantiate()
	add_child(m)
	await get_tree().process_frame
	GameState.reset()
	GameState.hunter_unlocked = true
	GameState.first_egg_done = true
	m.enter_hunt(null, 0)
	var h: HuntGround = m.hunt
	h.set_process(false)
	h.set_ai(false)
	var z: Dictionary = Config.HUNT_ZONES[0]
	_check(h.slimes.size() == z.count * Config.SWARM_SIZE, "떼: 분원농협 몬스터 자리마다 %d마리 (%d마리)" % [Config.SWARM_SIZE, h.slimes.size()])
	var s0: WildSlime = h.slimes[0]
	_check(s0.hp == maxi(U, roundi(HunterSkills.monster_hp(0, z.hp) * Config.SWARM_HP_MULT)) and is_equal_approx(s0.share, 1.0 / Config.SWARM_SIZE), "떼 몬스터는 체력 낮고 드롭 몫 1/%d" % Config.SWARM_SIZE)
	var rng := RandomNumberGenerator.new()
	var got := 0
	for i in 400:
		if not HuntLoot.roll_for_kill(rng, 0, 0.0).is_empty():
			got += 1
	_check(got == 0, "드롭 몫 0 이면 아무것도 안 떨어짐")
	# 구르기
	var feet: Vector2 = m.player.feet()
	for o: WildSlime in h.slimes:
		o.position = feet + Vector2(0, 300)
	var p0: Vector2 = m.player.position
	_check(h.dash(Vector2.UP), "Space 구르기")
	_check(not h.dash(Vector2.UP), "구르는 중에는 다시 못 구름")
	for i in 10:
		h.tick(1.0 / 30.0)
	_check(m.player.position.distance_to(p0) >= Config.DASH_DISTANCE * 0.8 and not m.player.dashing, "구르면 휙 움직임 (%.0fpx)" % m.player.position.distance_to(p0))
	# 구르는 동안은 몸에 부딪혀도 안 다침
	h.dash_cd = 0.0
	var hearts0 := h.life
	h.dash(Vector2.RIGHT)
	h.slimes[0].position = m.player.feet()
	h.tick(1.0 / 30.0)
	_check(h.life == hearts0, "구르는 동안은 안 맞음")
	for i in 40:
		h.tick(1.0 / 30.0)
	h.slimes[0].position = feet + Vector2(0, 300)
	# 연속 베기 3타: 3타째는 넓고 피해 +1
	feet = m.player.feet()
	var hand: Vector2 = feet + Vector2(0, -8)
	var w := Wearables.weapon()
	var far: Vector2 = hand + Vector2(w.reach + w.radius * 1.3, 0)
	var a: WildSlime = h.slimes[1]
	var b: WildSlime = h.slimes[2]
	var d1 := HunterClass.hunter_damage(1, &"melee")
	var d2 := HunterClass.hunter_damage(2, &"melee")
	a.position = far
	a.hp = 5 * U
	b.position = hand + Vector2(w.reach, 0)
	b.hp = 5 * U
	h._cooldown = 0.0
	h._since_swing = 99.0
	h.swing(Vector2.RIGHT)
	var hp_a1 := a.hp
	var hp_b1 := b.hp
	_check(h.combo == 0 and hp_a1 == 5 * U and hp_b1 == 5 * U - d1, "1타: 가까운 것만 1 피해")
	for k in 2:
		a.position = far + Vector2(Config.COMBO_FINISH_STEP * k, 0)
		b.position = hand + Vector2(w.reach, 0)
		h._hitstop = 0.0
		for i in 30:
			if h._cooldown <= 0.0:
				break
			h.tick(1.0 / 30.0)
			h._hitstop = 0.0
		a.position = m.player.feet() + Vector2(0, -8) + Vector2(w.reach + w.radius * 1.3 - (Config.COMBO_FINISH_STEP if k == 1 else 0.0), 0)
		b.position = m.player.feet() + Vector2(0, -8) + Vector2(w.reach, 0)
		h.swing(Vector2.RIGHT)
	_check(h.combo == 2 and a.hp == 5 * U - d2 and b.hp == 5 * U - 2 * d1 - d2, "3타째는 넓게 베고 피해 +1 (멀리 %d · 가까이 %d)" % [a.hp, b.hp])
	_check(h._hitstop > 0.0, "맞히면 잠깐 멈춤 (타격 멈춤)")
	# 한꺼번에 덮치는 수
	h.set_ai(true)
	h._hitstop = 0.0
	h._invulnerable = 99.0
	feet = m.player.feet()
	var near: Array[WildSlime] = []
	for i in 6:
		var o: WildSlime = h.slimes[3 + i]
		o.position = feet + Vector2.from_angle(TAU * i / 6.0) * 40.0
		o.hp = 9
		near.append(o)
	var most := 0
	for t in 90:
		h.tick(1.0 / 30.0)
		most = maxi(most, near.filter(func(o: WildSlime) -> bool: return o.attacking()).size())
	_check(most >= 1 and most <= Config.MAX_ATTACKERS, "떼여도 한꺼번에 달려드는 건 %d마리까지 (가장 많을 때 %d)" % [Config.MAX_ATTACKERS, most])
	# 꾹 누르고 있으면 계속 공격
	h.set_ai(false)
	h._cooldown = 0.0
	h._hitstop = 0.0
	Input.action_press("attack")
	var swings := 0
	for i in 30:
		var before := h._since_swing
		m._process(1.0 / 30.0)
		if h._since_swing < before:
			swings += 1
		h.tick(1.0 / 30.0)
		h._hitstop = 0.0
	Input.action_release("attack")
	_check(swings >= 2, "왼쪽 클릭을 꾹 누르면 계속 벤다 (1초에 %d번)" % swings)
	m.leave_hunt()
	m.queue_free()
	await get_tree().process_frame
	HuntGround.feel = false
	HuntGround.swarm = false


func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		_failures += 1


func _action(action: StringName) -> InputEventAction:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	return ev


## 45) 활 몰아잡기. 한 줄로 선 몬스터 셋 (체력 1) 에 오른쪽으로 쏜다.
func _bow_style_checks() -> void:
	var m: Node2D = load("res://scenes/main.tscn").instantiate()
	add_child(m)
	await get_tree().process_frame
	GameState.reset()
	GameState.hunter_unlocked = true
	GameState.first_egg_done = true
	GameState.worn[&"hunter"][&"weapon"] = &"hunting_bow"
	var kills := {}
	for style: StringName in [&"", &"pierce", &"spread", &"volley"]:
		# 구역마다 몬스터를 새로 (앞 방식이 잡은 수만큼 줄어서)
		GameState.hunts_today = 0
		m.enter_hunt(null, 0)
		var h: HuntGround = m.hunt
		h.set_process(false)
		h.set_ai(false)
		var feet: Vector2 = m.player.feet()
		HuntGround.bow_style = style
		h.shots.clear()
		h._cooldown = 0.0
		var line := []
		for o: WildSlime in h.slimes:
			o.position = feet + Vector2(-400, 0)
		for k in 3:
			var o: WildSlime = h.slimes[k]
			o.hp = 1
			o.position = feet + Vector2(50 + 22 * k, 8)
			line.append(o)
		h.swing(Vector2.RIGHT)
		var fired := h.shots.size()
		var cd := h._cooldown
		for i in 45:
			h.tick(1.0 / 30.0)
		kills[style] = line.filter(func(o) -> bool: return not is_instance_valid(o) or not o in h.slimes).size()
		match style:
			&"":
				_check(fired == 1 and kills[style] == 1, "활 지금: 한 발이 첫 몬스터에 박힘 (%d마리)" % kills[style])
			&"pierce":
				_check(fired == 1 and kills[style] == 3, "관통 화살: 한 발이 한 줄 %d마리를 꿰뚫음 (%d마리)" % [Config.BOW_PIERCE, kills[style]])
			&"spread":
				_check(fired == 3 and is_equal_approx(cd, 0.55 * Config.BOW_SPREAD_COOLDOWN), "부채살: 3발, 쿨 x%.1f" % Config.BOW_SPREAD_COOLDOWN)
			&"volley":
				_check(fired == 3 and kills[style] == 3 and is_equal_approx(cd, 0.55 * Config.BOW_VOLLEY_COOLDOWN), "3연사: 3발이 연달아 나가 한 줄 3마리 (%d마리), 쿨 x%.1f" % [kills[style], Config.BOW_VOLLEY_COOLDOWN])
		m.leave_hunt()
		await get_tree().process_frame
	HuntGround.bow_style = Config.BOW_STYLE
	m.queue_free()
	await get_tree().process_frame


## 46b) 직업 · 스탯 · 초기화. 처음 고르기 (옛 저장은 돌려받기) · 직업 무기 피해 · 스탯 효과 · 레벨업 포인트 · 첫 초기화 공짜 · 직업 바꾸기
func _hunter_class_checks() -> void:
	var m: Node2D = load("res://scenes/main.tscn").instantiate()
	add_child(m)
	await get_tree().process_frame
	GameState.reset()
	GameState.hunter_unlocked = true
	GameState.first_egg_done = true
	# 옛 저장: 직업 전에 Lv 10 으로 여러 트리를 찍어 둠
	GameState.hunter_level = 10
	GameState.skills = {&"whirl": 2, &"pierce": 3, &"fight_together": 1}
	GameState.skill_points = 4
	_check(not HunterClass.chosen() and HunterClass.weapon_mult(&"bow") == 1.0, "직업 전: 피해 배율 그대로")
	m.player.position = m.hunt_gate.position
	m._gate_interact()
	_check(m.menu_open and m.menu_kind == &"class", "직업 없으면 입구에서 직업 고르기 창")
	m.menu_index = 1
	m.menu_confirm()
	_check(GameState.hunter_class == &"archer" and GameState.skills.is_empty() and GameState.skill_points == 10 and GameState.stat_points == Config.STAT_POINTS_PER_LEVEL * 9, "궁수: 찍은 스킬 6점 돌려받음 (스킬 10 · 스탯 %d)" % GameState.stat_points)
	_check(Wearables.weapon().kind == &"bow" and 0 in GameState.weapon_gifts, "궁수는 사냥 활을 받아 듦 (첫 대장 활 선물은 넘어감)")
	_check(m.menu_open and m.menu_kind in [&"companion", &"waypoint"] or m.hunt != null, "고른 뒤 그대로 사냥 갈 준비")
	if m.hunt != null:
		m.leave_hunt()
	m.close_menu()
	_check(HunterSkills.why_not(&"pierce") == "" and HunterSkills.why_not(&"whirl") == "전사만", "궁수는 활 트리만 (검은 전사만)")
	_check(is_equal_approx(HunterClass.weapon_mult(&"bow"), 1.0 + Config.CLASS_WEAPON_BONUS) and HunterClass.weapon_mult(&"melee") == 1.0, "직업 무기 피해 +%d%%" % roundi(Config.CLASS_WEAPON_BONUS * 100))
	# 스탯: T 창 맨 아래 줄
	m._unhandled_input(_action(&"skills"))
	m.skill_panel.cursor = Vector2i(1, SkillPanel.rows())
	m.skill_panel.learn_cursor()
	m.skill_panel.learn_cursor()
	_check(HunterClass.stat(&"dex") == 2 and GameState.stat_points == Config.STAT_POINTS_PER_LEVEL * 9 - 2, "T 창 스탯 줄에서 솜씨 2")
	_check(HunterClass.hunter_damage(1, &"bow") == roundi(U * (1.0 + 2 * Config.STAT_DMG) * (1.0 + Config.CLASS_WEAPON_BONUS)), "솜씨가 활 피해를 올림 (%d)" % HunterClass.hunter_damage(1, &"bow"))
	m.skill_panel.cursor = Vector2i(3, SkillPanel.rows())
	m.skill_panel.learn_cursor()
	_check(HunterClass.companion_damage(1) == roundi(U * Config.COMPANION_BASE * (1.0 + Config.BOND_DMG)), "교감이 동행 피해를 올림")
	m.skill_panel.cursor = Vector2i(0, SkillPanel.rows())
	m.skill_panel.learn_cursor()
	GameState.hunts_today = 0
	m.enter_hunt(null, 0)
	_check(m.hunt.max_life() == Config.HUNTER_HP + Config.HP_PER_LEVEL * 9 + Config.STR_HP, "힘이 최대 체력을 올림")
	m.leave_hunt()
	m._unhandled_input(_action(&"skills"))
	var sp0 := GameState.stat_points
	HunterSkills.gain(HunterSkills.xp_to_next(GameState.hunter_level))
	_check(GameState.stat_points == sp0 + Config.STAT_POINTS_PER_LEVEL, "레벨업마다 스탯 %d점" % Config.STAT_POINTS_PER_LEVEL)
	# 초기화: 첫 번 공짜, 그 뒤 Lv x 값
	HunterSkills.learn(&"pierce")
	GameState.money = 0
	var r := HunterClass.respec()
	_check(r.ok and GameState.stats.is_empty() and GameState.skills.is_empty() and GameState.stat_points == Config.STAT_POINTS_PER_LEVEL * 10 and GameState.skill_points == 11, "첫 초기화는 공짜, 스탯 · 스킬 모두 돌려받음")
	_check(HunterClass.respec_price() == 11 * Config.RESPEC_PRICE_PER_LV and not HunterClass.respec(&"mage").ok, "그 뒤엔 Lv x %d원, 돈이 모자라면 못 함" % Config.RESPEC_PRICE_PER_LV)
	GameState.money = 5000
	m.open_menu(&"respec")
	_check(m.respec_options() == [&"reset", &"to_warrior", &"to_mage", &"close"], "입구 초기화 창: 초기화 · 전사 · 마법사 · 닫기")
	m.menu_index = 2
	m.menu_confirm()
	_check(GameState.hunter_class == &"mage" and GameState.money == 5000 - 11 * Config.RESPEC_PRICE_PER_LV and HunterSkills.why_not(&"big_orb") == "", "마법사로 바꿈 (-%d원), 지팡이 트리가 열림" % (11 * Config.RESPEC_PRICE_PER_LV))
	m.close_menu()
	# 몬스터 체력은 보통 빌드 피해만큼 함께 오른다
	_check(HunterSkills.monster_hp(0, 2) == roundi(2 * U * (1.0 + Config.CLASS_WEAPON_BONUS)) and HunterSkills.monster_hp(3, 2) > HunterSkills.monster_hp(0, 2), "몬스터 체력: x%d x 직업 무기 x 레벨" % U)
	# 저장 · 불러오기에 담김
	var snap := SaveGame.snapshot(m)
	GameState.reset()
	SaveGame.apply(m, snap)
	_check(GameState.hunter_class == &"mage" and GameState.free_respec_used and GameState.stat_points == Config.STAT_POINTS_PER_LEVEL * 10, "직업 · 스탯 · 초기화 기록이 저장됨")
	m.queue_free()
	await get_tree().process_frame


## 46) 사냥꾼 레벨 · 스킬. 경험치 · 레벨업 · 찍기 규칙 · 스킬마다 실제 효과.
func _hunter_skill_checks() -> void:
	var m: Node2D = load("res://scenes/main.tscn").instantiate()
	add_child(m)
	await get_tree().process_frame
	GameState.reset()
	GameState.hunter_unlocked = true
	GameState.first_egg_done = true
	_check(GameState.hunter_level == 1 and GameState.skill_points == 0 and GameState.skills.is_empty(), "새 게임은 사냥꾼 Lv 1 · 스킬 포인트 0")
	_check(HunterSkills.kill_xp(0) < HunterSkills.kill_xp(3) and HunterSkills.kill_xp(1, true) > HunterSkills.kill_xp(1) * (Config.BOSS_XP_MULT - 1), "깊은 구역 · 대장일수록 경험치가 많음")
	HunterSkills.gain(HunterSkills.xp_to_next(1))
	_check(GameState.hunter_level == 2 and GameState.skill_points == 1, "다음 레벨까지 모으면 Lv 2 · 스킬 포인트 +1")
	_check(HunterSkills.gap_mult(0, 20) == Config.XP_GAP_MIN and HunterSkills.gap_mult(5, 20) == 1.0, "레벨 차 벌칙: Lv 20 이 분원농협에선 경험치 %d%%, 밀목에선 그대로" % roundi(Config.XP_GAP_MIN * 100))
	_check(HunterSkills.is_act_boss_zone(1) and HunterSkills.is_act_boss_zone(3) and not HunterSkills.is_act_boss_zone(2), "막 대장 구역은 금사리 · 도마리 (스킬 포인트 +1)")
	_check(HunterSkills.why_not(&"whirl") == "직업을 먼저 고르기 (사냥터 입구)" and HunterSkills.why_not(&"fight_together") == "", "직업 전엔 무기 트리는 못 찍고 조련은 찍힘")
	GameState.hunter_class = &"warrior"
	_check(HunterSkills.why_not(&"dash_slash") == "Lv 6 부터", "레벨이 모자라면 못 찍음")
	GameState.hunter_level = 20
	GameState.skill_points = 40
	_check(HunterSkills.why_not(&"dash_slash") == "회전 베기 먼저", "위 스킬을 먼저 찍어야 함")
	_check(HunterSkills.why_not(&"pierce") == "궁수만" and HunterSkills.why_not(&"big_orb") == "마법사만", "전사는 활 · 지팡이 트리를 못 찍음")
	GameState.hunter_class = &"archer"
	_check(HunterSkills.learn(&"pierce") and HunterSkills.left_mode(&"bow") == &"pierce", "관통 화살을 찍으면 왼클릭에 걸림")
	HunterSkills.learn(&"spread")
	_check(HunterSkills.left_mode(&"bow") == &"spread" and HunterSkills.cycle_mode(&"bow") == &"" and HunterSkills.cycle_mode(&"bow") == &"pierce" and HunterSkills.cycle_mode(&"bow", -1) == &"", "Q/E 로 기본 · 관통 · 부채살을 돌려 고름")
	# 스킬 창 (T)
	m._unhandled_input(_action(&"skills"))
	_check(m.skill_panel.visible, "T 로 스킬 창이 열림")
	m.skill_panel.cursor = Vector2i(3, 0)
	var before: int = GameState.skill_points
	m.skill_panel.learn_cursor()
	_check(HunterSkills.rank(&"fight_together") == 1 and GameState.skill_points == before - 1, "스킬 창에서 찍기 (함께 싸우기 1)")
	m._unhandled_input(_action(&"skills"))
	_check(not m.skill_panel.visible, "T 로 닫힘")
	# 스킬 효과 확인: 직업과 상관없이 모든 트리를 한 단계씩 (실제 게임에선 자기 트리만)
	for id in [&"whirl", &"dash_slash", &"sword_mastery", &"earth_split", &"volley", &"arrow_rain", &"big_orb", &"chain_orb", &"element_boost", &"element_storm", &"creature_guard", &"charge_order", &"two_together"]:
		GameState.skills[id] = maxi(1, HunterSkills.rank(id))
	HuntGround.feel = true
	# 활: 관통 1단계 = 3마리, 부채살 5단계 = 5발
	GameState.worn[&"hunter"][&"weapon"] = &"hunting_bow"
	GameState.skill_left[&"bow"] = &"pierce"
	m.enter_hunt(null, 0)
	var h: HuntGround = m.hunt
	h.set_process(false)
	h.set_ai(false)
	h.swing(Vector2.RIGHT)
	_check(h.shots.size() == 1 and h.shots[0].pierce == Config.BOW_PIERCE, "관통 화살 1단계: %d마리 꿰뚫음" % Config.BOW_PIERCE)
	h.shots.clear()
	h._cooldown = 0.0
	GameState.skills[&"spread"] = 5
	GameState.skill_left[&"bow"] = &"spread"
	h.swing(Vector2.RIGHT)
	_check(h.shots.size() == 5, "부채살 5단계: 화살 5발 (%d)" % h.shots.size())
	h.shots.clear()
	# 부채살 4발 (3 · 4단계): 가운데 한 발이 늘 있어야 바로 앞 몬스터를 맞힘 (2026-10-02 고침)
	h._cooldown = 0.0
	GameState.skills[&"spread"] = 4
	h.swing(Vector2.RIGHT)
	_check(h.shots.size() == 4 and h.shots.any(func(sh: Dictionary) -> bool: return sh.dir.angle_to(Vector2.RIGHT) == 0.0 or absf(sh.dir.angle()) < 0.001), "부채살 4발에도 가운데 화살이 있음")
	h.shots.clear()
	GameState.skills[&"spread"] = 5
	# 화살비: 원 안 몬스터가 세 번 맞음
	var feet: Vector2 = m.player.feet()
	for o: WildSlime in h.slimes:
		o.position = feet + Vector2(-400, 0)
	var rain_t: WildSlime = h.slimes[0]
	rain_t.hp = 3 * U
	rain_t.position = feet + Vector2(60, 0)
	_check(h.skill_right(rain_t.position), "오른클릭 화살비")
	for i in 45:
		h.tick(1.0 / 30.0)
		h._hitstop = 0.0
	_check(not rain_t in h.slimes, "화살비가 세 번 쏟아져 체력 3 몬스터를 쓰러뜨림")
	_check(not h.skill_right(feet) and h.right_cd > 0.0, "오른클릭 스킬은 쿨이 있음")
	m.leave_hunt()
	await get_tree().process_frame
	# 검: 회전 베기 (등 뒤도 벰) · 돌진 베기 · 대지 가르기
	GameState.hunts_today = 0
	GameState.worn[&"hunter"][&"weapon"] = &"long_sword"
	GameState.skill_left[&"melee"] = &"whirl"
	m.enter_hunt(null, 0)
	h = m.hunt
	h.set_process(false)
	h.set_ai(false)
	feet = m.player.feet()
	for o: WildSlime in h.slimes:
		o.position = feet + Vector2(-400, 0)
	var behind: WildSlime = h.slimes[0]
	behind.hp = 1
	behind.position = feet + Vector2(-16, 0)
	for k in 3:
		h._cooldown = 0.0
		h._since_swing = 0.0
		h.swing(Vector2.RIGHT)
		h._hitstop = 0.0
	_check(not behind in h.slimes, "회전 베기: 3타째가 등 뒤 몬스터도 벰")
	var ahead: WildSlime = h.slimes[0]
	ahead.hp = 1
	# 구르기가 끝날 때 부르는 돌진 베기 (구르기 길이는 맵 막힘에 따라 달라서 끝난 자리에서 바로 본다)
	ahead.position = m.player.feet() + Vector2(24, 0)
	h._dash_dir = Vector2.RIGHT
	h._dash_slash()
	_check(not ahead in h.slimes, "돌진 베기: 구르기가 끝난 자리 앞을 벰")
	feet = m.player.feet()
	var line: Array = []
	for k in 3:
		var o: WildSlime = h.slimes[k]
		o.hp = 1
		o.position = feet + Vector2(25 + 20 * k, -6)
		line.append(o)
	h.right_cd = 0.0
	h.skill_right(feet + Vector2(100, -8))
	_check(line.all(func(o) -> bool: return not o in h.slimes), "대지 가르기: 앞 줄 3마리를 한 번에")
	m.leave_hunt()
	await get_tree().process_frame
	# 지팡이: 연쇄 구슬 · 원소 폭풍 · 큰 구슬
	GameState.hunts_today = 0
	GameState.worn[&"hunter"][&"weapon"] = &"water_staff"
	GameState.skill_left[&"staff"] = &"chain_orb"
	m.enter_hunt(null, 0)
	h = m.hunt
	h.set_process(false)
	h.set_ai(false)
	var wst: Dictionary = Wearables.weapon()
	_check(is_equal_approx(h.orb_blast(wst.blast), wst.blast * (1.0 + Config.BIG_ORB_STEP)), "큰 구슬 1단계: 터지는 범위 +10%")
	h.swing(Vector2.RIGHT)
	_check(h.shots.size() == 1 and h.shots[0].get("chain", 0) == 2, "연쇄 구슬: 작은 구슬 2개를 품음")
	for o: WildSlime in h.slimes:
		o.position = m.player.feet() + Vector2(-400, 0)
	for i in 60:
		h.tick(1.0 / 30.0)
		h._hitstop = 0.0
		if h.shots.any(func(sh) -> bool: return sh.get("small", false)):
			break
	_check(h.shots.filter(func(sh) -> bool: return sh.get("small", false)).size() == 2, "연쇄 구슬이 터지면 작은 구슬 2개가 튐")
	feet = m.player.feet()
	var storm_t: WildSlime = h.slimes[0]
	storm_t.hp = 1
	storm_t.position = feet + Vector2(70, 10)
	h.right_cd = 0.0
	h.skill_right(storm_t.position)
	_check(not storm_t in h.slimes, "원소 폭풍: 가리킨 곳이 넓게 터짐")
	m.leave_hunt()
	await get_tree().process_frame
	# 조련: 둘이 함께 · 크리처 방패 · 돌격 명령
	GameState.hunts_today = 0
	var c1: Creature = m._hatch(CreatureCatalog.SLIME, Vector2i(6, 10))
	var c2: Creature = m._hatch(CreatureCatalog.SLIME, Vector2i(7, 10))
	m.enter_hunt(c1, 0)
	h = m.hunt
	h.set_process(false)
	h.set_ai(false)
	_check(h.companion != null and h.companion2 != null and c2.process_mode == Node.PROCESS_MODE_DISABLED, "둘이 함께: 동행 둘")
	var hearts: int = h.life
	h._invulnerable = 0.0
	h._hurt(m.player.feet() + Vector2(10, 0))
	_check(h.life == hearts and h.guard_cd > 0.0, "크리처 방패: 첫 한 번은 동행이 대신 맞음")
	h._invulnerable = 0.0
	h._hurt(m.player.feet() + Vector2(10, 0))
	_check(h.life == hearts - 1, "방패 쿨 동안엔 그대로 맞음")
	feet = m.player.feet()
	for o: WildSlime in h.slimes:
		o.position = feet + Vector2(-400, 0)
	var ct: WildSlime = h.slimes[0]
	ct.hp = 5 * U
	ct.position = feet + Vector2(60, 0)
	_check(h.order_charge(ct.position), "R 돌격 명령")
	h.companion_ai = false
	for i in 20:
		h.tick(1.0 / 30.0)
		h._hitstop = 0.0
	_check(ct.hp < 5 * U and ct.stunned(), "돌격: 동행이 달려가 들이받고 기절시킴")
	m.leave_hunt()
	_check(c1.process_mode == Node.PROCESS_MODE_INHERIT and c2.process_mode == Node.PROCESS_MODE_INHERIT, "돌아오면 두 동행 모두 밭 일로")
	HuntGround.feel = false
	m.queue_free()
	await get_tree().process_frame


func _yeokdong_checks() -> void:
	var m: Node2D = load("res://scenes/main.tscn").instantiate()
	add_child(m)
	await get_tree().process_frame
	var zi := 6
	var z: Dictionary = Config.HUNT_ZONES[zi]
	_check(z.name == "역동" and z.monster == "켄타우로스 창기병" and z.boss_monster == "역마 장군" and z.lancer and z.boss_pattern == &"general" and Config.ZONE_MONSTER_LEVEL[zi] == 18, "7구역 역동: 창기병 · 역마 장군 · 몬스터 Lv 18")
	var ymap := HuntMap.load_map("yeokdong")
	_check(not ymap.find("K").is_empty() and not ymap.find("W").is_empty() and not ymap.find("S").is_empty() and not ymap.find("H").is_empty(), "역동 칸 지도: 대장 자리 (마방) · 웨이포인트 · 입구")
	_check(not HunterSkills.is_act_boss_zone(zi), "역동은 막 대장 구역이 아님 (4막 대장은 곤지암)")
	TestStarts.apply(m, &"yeokdong")
	_check(GameState.barn_state == 2 and zi in GameState.waypoints and GameState.hunter_level == TestStarts.LEVELS[&"yeokdong"], "시작 지점 역동 앞: 축사 · 역동 웨이포인트 · Lv %d" % TestStarts.LEVELS[&"yeokdong"])
	# 밀목 윗길: 축사를 고쳤으면 열림
	GameState.hunts_today = 0
	m.enter_hunt(null, 5)
	var mh: HuntGround = m.hunt
	mh.set_ai(false)
	mh.set_process(false)
	mh.path_open = true
	m.player.position = mh.next_area().get_center()
	_check(not mh.gate_closed() and mh.advance() and mh.zone == zi, "축사를 고쳤으면 밀목 윗길로 역동에 감")
	m.leave_hunt()
	# 아기 망아지
	var foal: Creature = m._hatch(CreatureCatalog.FOAL, Config.FORAGE_CELLS[5])
	_check(foal.data.species.display_name == "아기 망아지" and foal.data.elements[0].id == &"earth" and HuntCompanion.style_name(foal.data) == "뒷발차기", "아기 망아지 (땅, 동행 뒷발차기)")
	# 밭 갈기: 깊이 간 칸은 거둘 때 무 +1, 거두면 보통 칸
	var farm: Farm = m.farm
	var cell: Vector2i = farm._cells.keys()[0]
	var c: Farm.Cell = farm.get_cell(cell)
	c.planted = false
	c.plowed = false
	_check(farm.do_work(Farm.Work.PLOW, cell) and c.plowed and c.tilled and not farm.can_do(Farm.Work.PLOW, cell), "밭 갈기: 깊이 간 칸 (다시 못 감)")
	GameState.seeds = 5
	farm.do_work(Farm.Work.SOW, cell)
	c.growth = Config.CROP_GROW_DAYS
	var crops0 := GameState.crops
	_check(farm.do_work(Farm.Work.HARVEST, cell) and GameState.crops == crops0 + 1 + Config.PLOW_BONUS and not c.plowed, "깊이 간 칸에서 거두면 무 %d개, 다시 보통 칸" % (1 + Config.PLOW_BONUS))
	foal.home = cell
	foal.job = CreatureJobs.FARM
	foal._busy = false
	_check(foal._farm_once() and foal.task == CreatureJobs.PLOW, "농사를 맡은 아기 망아지는 거둔 빈 칸을 먼저 깊이 감")
	# 사냥: 창기병 돌격 · 역마 장군
	GameState.hunts_today = 0
	m.enter_hunt(foal, zi)
	var h: HuntGround = m.hunt
	h.set_ai(false)
	h.set_process(false)
	h.companion_ai = false
	_check(h.zone == zi and h.slimes.size() == z.count * h.swarm_size() and h.slimes.all(func(o: WildSlime) -> bool: return o.lancer), "역동에 들어옴: 창기병 %d마리 (자리마다 %d)" % [h.slimes.size(), h.swarm_size()])
	# 넓은 들판 가운데로 (입구는 숲 사이라 돌격 띠가 짧다)
	m.player.position = Vector2(30, 11) * Config.TILE
	var feet: Vector2 = m.player.feet()
	for o: WildSlime in h.slimes:
		o.position = feet + Vector2(-600, 0)
		o.ai_enabled = false
	var l: WildSlime = h.slimes[0]
	l.position = feet + Vector2(100, 0)
	l.ai_enabled = true
	l._lunge_cd = 0.0
	l._rest = 0.0
	l.tick(1.0 / 30.0, feet)
	var tg := l.telegraph()
	_check(l.attacking() and not tg.is_empty() and tg.from.distance_to(tg.to) > 120.0, "창기병: %d px 밖에서 긴 띠 예고 (돌격 %d px)" % [100, roundi(tg.from.distance_to(tg.to)) if not tg.is_empty() else 0])
	var hearts0 := h.life
	for i in 90:
		h.tick(1.0 / 30.0)
		if l.recovering():
			break
	_check(h.life == hearts0 - l.damage and l.recovering() and l.position.x < feet.x, "돌격에 받히면 체력 -%d, 지나쳐서 돌아서는 동안이 칠 틈" % l.damage)
	l.queue_free()
	h.slimes.erase(l)
	for o: WildSlime in h.slimes.duplicate():
		o.queue_free()
	h.slimes.clear()
	var b: WildSlime = h.spawn_boss()
	_check(b.boss and b.pattern == &"general" and b.title == "역마 장군" and is_equal_approx(b._sprite.scale.x * b.scale.x, 2.0), "역마 장군 (32칸 시트를 정수 2배로)")
	h._invulnerable = 0.0
	b.position = m.player.feet() + Vector2(120, 0)
	b.ai_enabled = true
	b._pattern_cd = 0.0
	b.tick(1.0 / 30.0, m.player.feet())
	_check(b._charges_left == Config.GENERAL_CHARGES and b._bus_aim > 0.0 and not b.telegraph().is_empty(), "역마 장군: 창 돌격 %d번 예고" % Config.GENERAL_CHARGES)
	h.life = 200  # 돌격 여러 번에 받혀도 쓰러지지 않게
	var hearts1 := h.life
	var charges_seen := 0
	var last := b._charges_left
	for i in 300:
		h.tick(1.0 / 30.0)
		if b._charges_left != last:
			charges_seen += 1
			last = b._charges_left
		if b.recovering():
			break
	_check(charges_seen == Config.GENERAL_CHARGES and b.recovering() and h.life < hearts1, "꺾이는 돌격 %d번 뒤 헐떡임, 받히면 다침 (체력 %d → %d)" % [charges_seen, hearts1, h.life])
	# 파발 나팔: 창기병이 원래 크기로 달려옴
	h._on_called(b.position)
	var calls := h.slimes.filter(func(o: WildSlime) -> bool: return o.minion)
	_check(calls.size() == Config.GENERAL_CALL and calls.all(func(o: WildSlime) -> bool: return o.lancer and o.scale == Vector2.ONE and o.hp == HunterSkills.minion_hp(h.zone, Config.GENERAL_MINION_HP)), "파발 나팔: 창기병 %d (원래 크기, 체력 %d)" % [Config.GENERAL_CALL, HunterSkills.minion_hp(h.zone, Config.GENERAL_MINION_HP)])
	# 체력 절반 아래면 말발굽 쿵 (새끼 없음)
	b._recover = 0.0
	b._pattern_cd = 0.0
	b._charges_left = 0
	b._bus_aim = -1.0
	b._bus_t = -1.0
	b.hp = b.max_hp / 2 - 1
	b.tick(1.0 / 30.0, m.player.feet())
	_check(b._air_t >= 0.0 and b._stomped, "체력 절반 아래: 돌격 앞에 말발굽 쿵")
	var n0 := h.slimes.size()
	h._on_slammed(b.position, b)
	_check(h.slimes.size() == n0, "말발굽 쿵은 새끼를 부르지 않음")
	# 뒷발차기
	var t := WildSlime.new()
	t.setup_zone(zi)
	t.area = h.monster_area()
	t.terrain = h.map
	t.position = h.companion.position + Vector2(10, 0)
	h.add_child(t)
	h.slimes.append(t)
	h.companion_attack(t, h.companion)
	_check(t.stunned() and t._pull_to.distance_to(t._pull_from) > 20.0, "뒷발차기: 멀리 밀리며 잠깐 멈춤")
	m.leave_hunt()
	m.queue_free()
	await get_tree().process_frame


func _gonjiam_checks() -> void:
	var m: Node2D = load("res://scenes/main.tscn").instantiate()
	add_child(m)
	await get_tree().process_frame
	var zi := 7
	var z: Dictionary = Config.HUNT_ZONES[zi]
	_check(z.name == "곤지암" and z.monster == "뿔 악귀" and z.boss_monster == "마왕" and z.demon and z.boss_pattern == &"archdemon" and Config.ZONE_MONSTER_LEVEL[zi] == 21, "8구역 곤지암: 뿔 악귀 · 마왕 · 몬스터 Lv 21")
	var gmap := HuntMap.load_map("gonjiam")
	_check(not gmap.find("K").is_empty() and not gmap.find("W").is_empty() and not gmap.find("Q").is_empty() and not gmap.find("M").is_empty() and gmap.find("Y").size() == 8, "곤지암 칸 지도: 폐병원 · 신립 장군 묘 · 갈라진 고양이 바위 · 대장 자리 · 웨이포인트")
	_check(not gmap.is_free(Rect2(gmap.find("Q")[0], Vector2(2, 2))) and not gmap.monster_ok(gmap.find("Y")[0]), "폐병원 · 고양이 바위는 막힘")
	_check(HunterSkills.is_act_boss_zone(zi), "곤지암은 4막 대장 구역 (첫 처치 스킬 포인트 +1)")
	TestStarts.apply(m, &"gonjiam")
	_check(zi in GameState.waypoints and GameState.hunter_level == TestStarts.LEVELS[&"gonjiam"], "시작 지점 곤지암 앞: 곤지암 웨이포인트 · Lv %d" % TestStarts.LEVELS[&"gonjiam"])
	# 역동 윗길 → 곤지암
	GameState.hunts_today = 0
	m.enter_hunt(null, 6)
	var yh: HuntGround = m.hunt
	yh.set_ai(false)
	yh.set_process(false)
	yh.path_open = true
	m.player.position = yh.next_area().get_center()
	_check(yh.path_block() == "" and yh.advance() and yh.zone == zi, "역마 장군을 잡으면 역동 윗길로 곤지암에 감")
	m.leave_hunt()
	# 아기 악귀: 불 · 겁주기 · 밤일
	var imp: Creature = m._hatch(CreatureCatalog.IMP, Config.FORAGE_CELLS[5])
	_check(imp.data.species.display_name == "아기 악귀" and imp.data.elements[0].id == &"fire" and HuntCompanion.style_name(imp.data) == "불 할퀴기 + 겁주기", "아기 악귀 (불, 동행 불 할퀴기 + 겁주기)")
	var farm: Farm = m.farm
	var cell: Vector2i = farm._cells.keys()[0]
	var c: Farm.Cell = farm.get_cell(cell)
	c.tilled = true
	c.planted = true
	c.growth = Config.CROP_GROW_DAYS
	imp.home = cell
	imp.job = CreatureJobs.FARM
	var crops0 := GameState.crops
	var done := imp.night_work()
	_check(done > 0 and GameState.crops > crops0 and not farm.can_do(Farm.Work.HARVEST, cell), "밤일: 밤사이 범위 안 익은 무를 거두고 심고 물까지 (%d번)" % done)
	var slime: Creature = m.creatures.filter(func(o: Creature) -> bool: return o.data.species == CreatureCatalog.SLIME)[0]
	_check(slime.night_work() == 0, "밤일은 아기 악귀만")
	# 사냥: 뿔 악귀는 바라보는 동안 얼어붙음
	GameState.hunts_today = 0
	m.enter_hunt(imp, zi)
	var h: HuntGround = m.hunt
	h.set_ai(false)
	h.set_process(false)
	h.companion_ai = false
	_check(h.zone == zi and h.slimes.size() == z.count * h.swarm_size() and h.slimes.all(func(o: WildSlime) -> bool: return o.demon), "곤지암에 들어옴: 뿔 악귀 %d마리 (자리마다 %d)" % [h.slimes.size(), h.swarm_size()])
	_check(h.slimes[0]._frame == 48 and is_equal_approx(h.slimes[0]._sprite.scale.x * h.slimes[0].scale.x, 1.0), "뿔 악귀 48칸 시트를 늘이지 않고 그림")
	m.player.position = Vector2(25, 10) * Config.TILE
	m.player.facing = Vector2i.RIGHT
	var feet: Vector2 = m.player.feet()
	for o: WildSlime in h.slimes:
		o.position = feet + Vector2(-900, 0)
		o.ai_enabled = false
	var front: WildSlime = h.slimes[0]
	var back: WildSlime = h.slimes[1]
	front.position = feet + Vector2(80, 0)
	back.position = feet + Vector2(-80, 0)
	for d: WildSlime in [front, back]:
		d.ai_enabled = true
		d.alert = true
	h._invulnerable = 99.0
	for i in 30:
		h.tick(1.0 / 30.0)
	_check(front.watched and front.gazed_frozen() and front.position.distance_to(feet + Vector2(80, 0)) < 0.5, "바라보는 쪽 악귀는 얼어붙음")
	_check(not back.watched and back.position.x > feet.x - 80.0 + 10.0, "등 뒤 악귀는 걸어서 다가옴 (%d px)" % roundi(back.position.x - (feet.x - 80.0)))
	# 등 뒤에서 붙으면 팔을 치켜들고 내려찍음
	h._invulnerable = 0.0
	h.life = 200
	var hearts0 := h.life
	for i in 150:
		h.tick(1.0 / 30.0)
		if h.life < hearts0:
			break
	_check(h.life == hearts0 - back.damage, "등 뒤 악귀가 둘레를 내려찍음 (체력 -%d)" % back.damage)
	# 아기 악귀 겁주기: 맞은 악귀는 달아남
	h.companion_attack(front, h.companion)
	_check(front._fear > 0.0 and not front.gazed_frozen(), "겁먹은 악귀는 바라봐도 달아남")
	for o: WildSlime in h.slimes.duplicate():
		o.queue_free()
	h.slimes.clear()
	# 마왕: 등불 깜빡 → 정전 + 등 뒤 악귀, 다음은 지옥불 기둥
	var b: WildSlime = h.spawn_boss()
	_check(b.boss and b.pattern == &"archdemon" and b.title == "마왕" and b._frame == 64 and is_equal_approx(b._sprite.scale.x * b.scale.x, 1.0), "마왕 (64칸 시트를 늘이지 않고)")
	b.position = feet + Vector2(140, 0)
	b.ai_enabled = true
	b._pattern_cd = 0.0
	b.tick(1.0 / 30.0, feet)
	_check(b._dim > 0.0, "마왕: 지옥불 등불 깜빡임 (예고)")
	for i in 60:
		h.tick(1.0 / 30.0)
		if h.blackout_t > 0.0:
			break
	var called := h.slimes.filter(func(o: WildSlime) -> bool: return o.minion)
	_check(h.blackout_t > 0.0 and called.size() == Config.ARCH_CALL and called.all(func(o: WildSlime) -> bool: return o.demon and o.position.x < feet.x and o.hp == HunterSkills.minion_hp(h.zone, Config.ARCH_MINION_HP)), "등불이 꺼지면 정전 + 사냥꾼 등 뒤에 뿔 악귀 %d" % Config.ARCH_CALL)
	var seen: WildSlime = called[0]
	seen.position = feet + Vector2(60, 0)
	h.tick(1.0 / 30.0)
	_check(seen.watched and seen.blackout and not seen.gazed_frozen(), "정전 동안엔 바라봐도 악귀가 움직임")
	for o: WildSlime in called:
		o.queue_free()
		h.slimes.erase(o)
	b._recover = 0.0
	b._pattern_cd = 0.0
	h.blackout_t = 0.0
	b.tick(1.0 / 30.0, feet)
	var pillars := b.telegraphs().filter(func(t: Dictionary) -> bool: return t.get("pillar", false))
	_check(pillars.size() == Config.ARCH_PILLARS, "다음 차례: 지옥불 기둥 %d" % Config.ARCH_PILLARS)
	h._invulnerable = 0.0
	h.life = 200
	var hearts1 := h.life
	for i in 60:
		h.tick(1.0 / 30.0)
		if h.life < hearts1:
			break
	_check(h.life == hearts1 - b.damage, "발밑 지옥불 기둥에 휩싸이면 체력 -%d" % b.damage)
	b.hp = b.max_hp / 2 - 1
	b._bales.clear()
	b._recover = 0.0
	b._pattern_cd = 0.0
	b._arch_step = 1
	b.tick(1.0 / 30.0, feet)
	_check(b._bales.size() == Config.ARCH_PILLARS_ENRAGED, "체력 절반 아래: 지옥불 기둥 %d" % Config.ARCH_PILLARS_ENRAGED)
	m.leave_hunt()
	m.queue_free()
	await get_tree().process_frame


func _naru_checks() -> void:
	var m: Node2D = load("res://scenes/main.tscn").instantiate()
	add_child(m)
	await get_tree().process_frame
	var farm: Farm = m.farm
	# 팔당호 물가: 처음부터 물 칸은 막히고 들나물이 안 돋음
	var water := Vector2i(Config.LAKE_ROWS[21], 21)
	_check(not farm.is_free(Rect2(Vector2(water * Config.TILE) + Vector2(4, 4), Vector2(8, 8))) and farm.is_free(Rect2(Vector2((water + Vector2i(-2, 0)) * Config.TILE) + Vector2(4, 4), Vector2(8, 8))), "팔당호 물가: 물 칸은 막히고 물가 모래는 걸어 다님")
	var in_water := Config.HERB_SPOTS.filter(func(c: Vector2i) -> bool: return Config.LAKE_ROWS.has(c.y) and c.x >= Config.LAKE_ROWS[c.y])
	_check(in_water.is_empty() and not Config.PERSIMMON_CELLS.any(func(c: Vector2i) -> bool: return Config.LAKE_ROWS.has(c.y) and c.x >= Config.LAKE_ROWS[c.y]), "들나물 자리 · 감나무가 물에 없음")
	_check(not Config.NARU_RECT.has_point(Creature.fish_spot()) and not (Config.LAKE_ROWS.has(Creature.fish_spot().y) and Creature.fish_spot().x >= Config.LAKE_ROWS[Creature.fish_spot().y]), "물고기 몰기 자리는 물가 땅")
	_check(Config.HUNT_ZONES[Config.NARU_ZONE].get("boss_material4", false), "곤지암 마왕이 4막 대장 재료 (마왕 뿔)")
	# 마왕을 처음 잡은 다음 날 나루터 터
	GameState.naru_boss_down = true
	var lines: Array[String] = m.next_day()
	_check(GameState.naru_state == 1 and m.naru != null and lines.any(func(l: String) -> bool: return l.contains("나루터 터")), "마왕 첫 처치 다음 날 아침 나루터 터")
	_check(not m.restore_naru() and GameState.naru_state == 1, "모자라면 못 고침")
	GameState.money += Config.NARU_COST_MONEY
	GameState.crops += Config.NARU_COST_CROPS + 10
	GameState.material4 += Config.NARU_COST_MATERIAL
	m.restore_naru()
	SiteWork.fill(&"naru")
	_check(m.restore_naru() and GameState.naru_state == 2 and m.ferryman.visible and GameState.material4 == 0, "돈 · 무 · 마왕 뿔로 한 번에 고침 → 뱃사공")
	_check(FacilityWorkers.is_open(&"naru"), "고치면 나루터 일꾼 자리 (물고기 몰기)")
	GameState.hunter_unlocked = true
	m.player.position = Farm.center_of(Config.FERRYMAN_CELL) + Vector2(10, 0)
	m.interact()
	_check(m.menu_open and m.menu_kind == &"dock" and m.dock_options().has(&"stew"), "뱃사공에게 F → 나루터 창 (매운탕도)")
	m.close_menu()
	# 통발
	var crops0 := GameState.crops
	_check(m.dock_action(&"set_traps") and GameState.traps == Config.TRAP_MAX and GameState.crops == crops0 - Config.TRAP_MAX * Config.TRAP_BAIT, "통발 놓기: 미끼 무 하나씩 %d개" % Config.TRAP_MAX)
	_check(not m.dock_action(&"set_traps"), "다 놓였으면 더 못 놓음")
	# 물고기 몰기: 물 크리처 · 통발이 있을 때만, 하루 FISH_DRIVE_CAP 번
	var sl: Creature = m._hatch(CreatureCatalog.SLIME, Creature.fish_spot() + Vector2i.LEFT, load("res://data/creatures/elements/water.tres"))
	sl.job = CreatureJobs.FISH
	_check(sl.data.work_speed(CreatureJobs.FISH) > sl.data.base_work_speed * 1.5, "물속성은 물고기 몰기가 빠름")
	var imp: Creature = m._hatch(CreatureCatalog.IMP, Creature.fish_spot() + Vector2i.LEFT)
	imp.job = CreatureJobs.FISH
	_check(imp.night_work() == Config.FISH_DRIVE_CAP and GameState.fish_drive == Config.FISH_DRIVE_CAP, "아기 악귀 밤일 물고기 몰기 (하루 %d번까지)" % Config.FISH_DRIVE_CAP)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var r: Dictionary = m.traps_night(rng)
	_check(r.traps == Config.TRAP_MAX and r.driven == Config.FISH_DRIVE_CAP and r.caught >= Config.FISH_DRIVE_CAP and r.caught <= Config.TRAP_MAX * 2 + Config.FISH_DRIVE_CAP and GameState.basket == r.caught and GameState.traps == 0 and GameState.fish_drive == 0, "아침 통발: 통발마다 0~2 + 몰아 준 수, 통발은 걷힘 (%d마리)" % r.caught)
	_check(sl.work_once() == false or sl.position.distance_to(Farm.center_of(sl.home)) > 0.5, "통발이 없으면 물고기 몰기 크리처는 쉼")
	var empty: Dictionary = m.traps_night(rng)
	_check(empty.traps == 0 and empty.caught == 0, "통발을 안 놓으면 물고기 없음")
	# 꺼내기 · 매운탕 · 팔기
	var basket := GameState.basket
	_check(m.dock_action(&"take_fish") and GameState.fish == basket and GameState.basket == 0, "바구니 물고기 꺼내기")
	GameState.fish = maxi(GameState.fish, Config.STEW_FISH + 1)
	var fish0 := GameState.fish
	GameState.peppers = 0
	_check(not m.dock_action(&"stew"), "고추가 없으면 매운탕을 못 끓임")
	GameState.peppers = Config.STEW_PEPPERS
	_check(m.dock_action(&"stew") and GameState.stews == 1 and GameState.fish == fish0 - Config.STEW_FISH and GameState.peppers == 0, "뱃사공 매운탕 (물고기 %d · 고추 %d)" % [Config.STEW_FISH, Config.STEW_PEPPERS])
	_check(&"stew" in m.dock_options(), "매운탕은 나루터 창에서 뱃사공에게 부탁")
	var money0 := GameState.money
	var sell := GameState.fish
	m.supply_action(&"display_fish")
	m.next_day()
	_check(GameState.money >= money0 + sell * Config.FISH_PRICE and GameState.fish == 0, "공급함에 진열한 물고기는 밤사이 팔림 (%d마리)" % sell)
	# 매운탕을 먹고 사냥: 하트 칸 +1 · 경험치 x1.5
	GameState.hunts_today = 0
	var hearts0: int = 0
	m.enter_hunt(null, 0)
	var h: HuntGround = m.hunt
	_check(h.stew and GameState.stews == 0, "사냥에 들어갈 때 매운탕을 먹음")
	h.stew = false
	hearts0 = h.max_life()
	h.stew = true
	_check(h.max_life() == hearts0 + Config.STEW_HP, "매운탕: 최대 체력 +%d" % Config.STEW_HP)
	m.leave_hunt()
	# 입양: 뱃사공도 받아 줌
	_check(Expedition.villager_open(&"ferryman") and Config.ADOPT_SPOTS[&"ferryman"].size() == 4, "뱃사공도 크리처 입양을 받음")
	# 저장 → 불러오기: 나루터 · 놓인 통발 · 바구니
	GameState.traps = 2
	GameState.basket = 3
	SaveGame.dir = "user://smoke_saves"
	DirAccess.make_dir_recursive_absolute(SaveGame.dir)
	_check(SaveGame.save(m, 3), "나루터 저장")
	m.queue_free()
	await get_tree().process_frame
	var b: Node2D = load("res://scenes/main.tscn").instantiate()
	add_child(b)
	await get_tree().process_frame
	_check(SaveGame.load_into(b, 3) and b.naru != null and b.ferryman.visible and GameState.traps == 2 and GameState.basket == 3, "불러오면 나루터 · 뱃사공 · 통발 · 바구니 그대로")
	SaveGame.erase(3)
	SaveGame.dir = "user://"
	# 시작 지점
	GameState.reset()
	TestStarts.apply(b, &"naru")
	_check(GameState.naru_state == 2 and b.ferryman.visible and GameState.fish == 4 and b.creatures.any(func(c: Creature) -> bool: return c.job == CreatureJobs.FISH), "시작 지점 나루터 복구 뒤: 뱃사공 · 물고기 4 · 물고기 몰기 크리처")
	b.queue_free()
	await get_tree().process_frame


func _sonae_checks() -> void:
	var m: Node2D = load("res://scenes/main.tscn").instantiate()
	add_child(m)
	await get_tree().process_frame
	var gi := 8
	var zi := 9
	var z: Dictionary = Config.HUNT_ZONES[zi]
	_check(Config.HUNT_ZONES[gi].name == "귀여리" and Config.HUNT_ZONES[gi].get("from_village", false) and Config.ZONE_MONSTER_LEVEL[gi] == 24, "9구역 귀여리: 마을 입구 웨이포인트로 감 · 몬스터 Lv 24")
	_check(z.name == "소내섬" and z.flyer and z.ferry and z.final and z.boss_pattern == &"dragon" and z.boss_monster == "용" and z.variants.size() == 3 and Config.ZONE_MONSTER_LEVEL[zi] == 27, "10구역 소내섬: 와이번 (날기) · 용 · 희귀 용 셋 · 몬스터 Lv 27")
	_check(Config.ferry_zone() == zi, "나룻배로만 가는 섬 = 소내섬")
	var smap := HuntMap.load_map("sonae")
	_check(not smap.find("K").is_empty() and not smap.find("E").is_empty() and smap.find("N").is_empty(), "소내섬 칸 지도: 용소 대장 자리 · 아래 나루 (위쪽 길 없음)")
	_check(HuntMap.load_map("guiyeo").find("N").is_empty(), "귀여리 칸 지도: 위쪽 길 없음 (섬은 나룻배로)")
	# 곤지암 마왕을 잡으면 위쪽 길 대신 마을 입구 귀여리 웨이포인트
	TestStarts.apply(m, &"gonjiam")
	GameState.hunts_today = 0
	m.enter_hunt(null, 7)
	var gh: HuntGround = m.hunt
	gh.set_ai(false)
	gh.set_process(false)
	for o: WildSlime in gh.slimes.duplicate():
		o.queue_free()
	gh.slimes.clear()
	var arch: WildSlime = gh.spawn_boss()
	gh._defeat(arch)
	_check(gi in GameState.waypoints and not gh.path_open, "곤지암 마왕 처치: 귀여리 웨이포인트 (위쪽 길은 안 열림)")
	m.leave_hunt()
	m.queue_free()
	await get_tree().process_frame
	m = load("res://scenes/main.tscn").instantiate()
	add_child(m)
	await get_tree().process_frame
	# 나룻배: 귀여리 대장을 잡기 전엔 못 감
	GameState.reset()
	TestStarts.apply(m, &"guiyeo")
	_check(m.waypoint_options().has(&"zone_8") and not m.waypoint_options().has(&"zone_9"), "시작 지점 귀여리 앞: 입구에 귀여리 (섬은 입구 목록에 없음)")
	m._pending_zone = 0
	GameState.hunts_today = 0
	m._ferry_interact()
	_check(m._pending_zone == 0 and m.hunt == null, "귀여리 대장 전엔 나룻배를 못 띄움")
	m.queue_free()
	await get_tree().process_frame
	m = load("res://scenes/main.tscn").instantiate()
	add_child(m)
	await get_tree().process_frame
	GameState.reset()
	TestStarts.apply(m, &"sonae")
	_check(gi in GameState.bosses_beaten and not zi in GameState.bosses_beaten and GameState.naru_state == 2, "시작 지점 소내섬 앞: 귀여리 대장 처치 · 나루터")
	_check(not m.waypoint_options().has(&"zone_9"), "섬은 사냥터 입구 웨이포인트 목록에 없음")
	_check(m.dock_options().has(&"ferry") and m.dock_option_text(&"ferry").contains("소내섬"), "나루터 창에 나룻배 타기 (소내섬)")
	GameState.hunts_today = 0
	m._ferry_interact()
	if m.hunt == null:
		m.enter_hunt(null, m._pending_zone)
	var h: HuntGround = m.hunt
	_check(h != null and h.zone == zi and zi in GameState.waypoints, "나루터 나룻배 타기 → 소내섬")
	h.set_ai(false)
	h.set_process(false)
	h.companion_ai = false
	_check(h.slimes.all(func(o: WildSlime) -> bool: return o.flyer and o.title == "독꼬리 와이번"), "독꼬리 와이번은 날아다님")
	for o: WildSlime in h.slimes.duplicate():
		o.queue_free()
	h.slimes.clear()
	# 처음 만나는 대장은 늘 일반 용
	HuntGround.force_variant = &""
	var b: WildSlime = h.spawn_boss()
	_check(b.title == "용" and b.variant == &"" and b._frame == 96 and is_equal_approx(b._sprite.scale.x * b.scale.x, 1.0), "처음 만나는 마지막 대장은 일반 용 (96칸 시트를 늘이지 않고)")
	var rare := 0
	for i in 2000:
		if not h._roll_variant(z).is_empty():
			rare += 1
	_check(rare == 0, "한 번도 안 잡았으면 희귀 용은 안 나옴")
	GameState.bosses_beaten.append(zi)
	h.loot_rng.seed = 11
	var seen := {}
	rare = 0
	for i in 2000:
		var v := h._roll_variant(z)
		if not v.is_empty():
			rare += 1
			seen[v.id] = true
	_check(rare > 200 and rare < 400 and seen.size() == 3, "잡은 뒤엔 희귀 용 셋이 드물게 (2000번에 %d, 기대 300)" % rare)
	# 일반 용: 물어뜯기 돌진 → 날개 바람
	m.player.position = Vector2(25, 16) * Config.TILE
	var feet: Vector2 = m.player.feet()
	b.position = feet + Vector2(150, 0)
	b.ai_enabled = true
	b._pattern_cd = 0.0
	b.tick(1.0 / 30.0, feet)
	_check(b._charges_left == Config.DRAGON_CHARGES, "용: 물어뜯기 돌진 %d번" % Config.DRAGON_CHARGES)
	h._invulnerable = 0.0
	h.life = 400
	var life0 := h.life
	for i in 120:
		h.tick(1.0 / 30.0)
		if h.life < life0:
			break
	_check(h.life < life0, "돌진에 물어뜯기면 체력이 깎임")
	b._charges_left = 0
	b._bus_t = -1.0
	b._bus_aim = -1.0
	b._recover = 0.0
	b._pattern_cd = 0.0
	b._bales.clear()
	b._dragon_step = 1
	b.position = feet + Vector2(40, 0)
	b.tick(1.0 / 30.0, feet)
	_check(b.telegraphs().any(func(t: Dictionary) -> bool: return t.get("gust", false)), "다음 차례: 날개 바람 (둘레 원)")
	h._invulnerable = 0.0
	life0 = h.life
	var at0: Vector2 = m.player.feet()
	for i in 60:
		h.tick(1.0 / 30.0)
		if h.life < life0:
			break
	_check(h.life < life0 and m.player.feet().distance_to(b.position) > at0.distance_to(b.position), "날개 바람에 맞으면 다치고 밀려남")
	for o: WildSlime in h.slimes.duplicate():
		o.queue_free()
	h.slimes.clear()
	# 용소 깊은 물 위에서 쓰러져도 줍는 자리는 물가 (2026-10-03 봇이 물 위 전리품에 막힘)
	var deep := Vector2(25.5, 3.5) * Config.TILE
	var dry_at := h._reachable(deep)
	_check(not h.map.is_free(Rect2(deep - Character.FEET_BOX / 2.0, Character.FEET_BOX)) and h.map.is_free(Rect2(dry_at - Character.FEET_BOX / 2.0, Character.FEET_BOX)), "용소 물 위 전리품은 물가로 (%d px)" % roundi(deep.distance_to(dry_at)))
	# 희귀 용 셋: 자기 기술
	var expect := {&"blue": "팔당 청룡", &"cloud": "운룡", &"gold": "황금 드래곤"}
	for id: StringName in expect:
		HuntGround.force_variant = id
		var r: WildSlime = h.spawn_boss()
		r.position = feet + Vector2(150, 0)
		r.ai_enabled = true
		r._pattern_cd = 0.0
		r._dragon_step = 2
		r.tick(1.0 / 30.0, feet)
		var ok := false
		match id:
			&"blue":
				ok = r.telegraphs().filter(func(t: Dictionary) -> bool: return t.get("water", false)).size() == Config.DRAGON_PILLARS
			&"cloud":
				ok = r._dim > 0.0
			&"gold":
				ok = r._log_aim > 0.0
		_check(r.title == expect[id] and r.variant == id and r._frame == 96 and ok, "희귀 용 %s: 자기 기술" % expect[id])
		r.queue_free()
		h.slimes.erase(r)
	# 희귀 용은 자기 아기 알, 마지막 대장 처치 기록
	HuntGround.force_variant = &"blue"
	HuntGround.egg_roll = 0.0
	var blue: WildSlime = h.spawn_boss()
	h._defeat(blue)
	_check(h.drops.any(func(d: Dictionary) -> bool: return d.species == CreatureCatalog.BLUE_DRAGON) and GameState.final_boss_down, "팔당 청룡은 아기 청룡 알을 남김 · 마지막 대장 처치 기록")
	HuntGround.egg_roll = -1.0
	HuntGround.force_variant = &""
	m.leave_hunt()
	# 아기 크리처 넷
	var bd: Creature = m._hatch(CreatureCatalog.BLUE_DRAGON, Config.FORAGE_CELLS[5])
	_check(bd.data.species.display_name == "아기 청룡" and bd.data.elements[0].id == &"water" and bd.data.species.rains, "아기 청룡 (물, 비 내리기)")
	var farm: Farm = m.farm
	for cell: Vector2i in farm._cells:
		var c: Farm.Cell = farm.get_cell(cell)
		if c.planted and not c.is_ripe():
			c.watered = false
	bd.job = CreatureJobs.FARM
	var dry := 0
	for cell: Vector2i in farm._cells:
		var c: Farm.Cell = farm.get_cell(cell)
		if c.planted and not c.is_ripe() and not c.watered:
			dry += 1
	_check(dry > 0 and m.rain_on_farm() == dry, "비 내리기: 아침에 심은 칸 전부 물 (%d칸)" % dry)
	bd.job = CreatureJobs.REST
	_check(m.rain_on_farm() == 0, "쉬는 아기 청룡은 비를 안 부름")
	var wy: Creature = m._hatch(CreatureCatalog.WYVERN, Config.FORAGE_CELLS[4])
	_check(wy.data.species.courier and Expedition.fit(wy.data, 0) == Config.EXPEDITION_HOME_MULT, "아기 와이번: 하늘 배달 = 어느 원정이든 제 구역처럼")
	var cd: Creature = m._hatch(CreatureCatalog.CLOUD_DRAGON, Config.FORAGE_CELLS[3])
	var gd: Creature = m._hatch(CreatureCatalog.GOLD_DRAGON, Config.FORAGE_CELLS[2])
	_check(cd.data.species.display_name == "아기 운룡" and gd.data.species.display_name == "아기 황금 드래곤" and gd.data.species.daily_gold.y > 0, "아기 운룡 · 아기 황금 드래곤")
	# 저장: 마지막 대장 처치
	_check(SaveGame.snapshot(m).gs.get("final_boss_down", false), "마지막 대장 처치 기록도 저장됨")
	m.queue_free()
	await get_tree().process_frame


func _guiyeo_checks() -> void:
	var m: Node2D = load("res://scenes/main.tscn").instantiate()
	add_child(m)
	await get_tree().process_frame
	var zi := 8
	var z: Dictionary = Config.HUNT_ZONES[zi]
	_check(z.monster == "방패 도마뱀" and z.boss_monster == "도마뱀 족장" and z.shield and z.boss_pattern == &"chief", "귀여리: 방패 도마뱀 · 도마뱀 족장 (A)")
	GameState.reset()
	TestStarts.apply(m, &"guiyeo")
	var baby: Creature = m._hatch(CreatureCatalog.LIZARD, Config.FORAGE_CELLS[5])
	_check(baby.data.species.display_name == "아기 도마뱀" and baby.data.elements[0].id == &"earth" and baby.data.species.market and baby.data.species.lid, "아기 도마뱀 (땅, 장보기 · 냄비뚜껑)")
	baby.job = CreatureJobs.FORAGE
	var money0 := GameState.money
	_check(m.market_bonus(1000) == 200 and GameState.money == money0 + 200, "장보기: 밤사이 판매값 +20%")
	baby.job = CreatureJobs.REST
	_check(m.market_bonus(1000) == 0, "쉬는 아기 도마뱀은 장에 안 감")
	baby.job = CreatureJobs.FORAGE
	GameState.hunts_today = 0
	m.enter_hunt(baby, zi)
	var h: HuntGround = m.hunt
	h.set_ai(false)
	h.set_process(false)
	h.companion_ai = false
	_check(h.zone == zi and h.slimes.all(func(o: WildSlime) -> bool: return o.shield), "귀여리에 들어옴: 모두 방패 도마뱀")
	# 냄비뚜껑: 한 번 대신 막고, 쿨 동안은 맞음
	h.life = 200
	h._invulnerable = 0.0
	h._hurt(m.player.feet() + Vector2(10, 0), 5)
	_check(h.life == 200 and h.lid_cd > 0.0, "아기 도마뱀 냄비뚜껑이 한 번 막음")
	h._invulnerable = 0.0
	h._hurt(m.player.feet() + Vector2(10, 0), 5)
	_check(h.life == 195, "뚜껑 쿨 동안은 맞음")
	var l: WildSlime = h.slimes[0]
	for o: WildSlime in h.slimes.duplicate():
		if o != l:
			h.slimes.erase(o)
			o.queue_free()
	m.player.position = Vector2(25, 14) * Config.TILE
	var feet: Vector2 = m.player.feet()
	l.position = feet + Vector2(60, 0)
	l.tick(1.0 / 30.0, feet)
	var hp0 := l.hp
	_check(l.blocks(feet) and not h._strike(l, feet, 1) and l.hp == hp0 and h.blocked_hits == 1, "앞에서 치면 방패에 막힘")
	_check(not h._strike(l, l.position + Vector2(40, 0), 1) and l.hp < hp0, "등 뒤에서 치면 맞음")
	l._recover = 1.0
	_check(not l.blocks(feet), "창을 찌른 뒤엔 방패가 내려가 앞도 열림")
	l.gold_t = 2.0
	_check(l.blocks(feet) and l.blocks(l.position + Vector2(0, 40)) and not l.blocks(l.position + Vector2(40, 0)), "금빛 방패: 찌른 뒤에도 앞 · 옆을 막고 등 뒤만 열림")
	l.gold_t = 0.0
	l._recover = 0.0
	# 창 찌르기: 당겼다 길게 찌름
	l.ai_enabled = true
	l.alert = true
	l.position = feet + Vector2(50, 0)
	l._lunge_cd = 0.0
	h._invulnerable = 0.0
	h.lid_cd = 99.0
	h.life = 200
	for i in 90:
		h.tick(1.0 / 30.0)
		if h.life < 200:
			break
	_check(h.life < 200, "방패 도마뱀 창 찌르기에 맞음")
	h.slimes.erase(l)
	l.queue_free()
	# 도마뱀 족장: 전쟁 북 → 도마뱀 둘 + 금빛 방패
	var b: WildSlime = h.spawn_boss()
	_check(b.title == "도마뱀 족장" and b.pattern == &"chief" and not b.shield, "도마뱀 족장 (방패 없음)")
	b.position = feet + Vector2(120, 0)
	b.ai_enabled = true
	b._pattern_cd = 0.0
	b.tick(1.0 / 30.0, feet)
	_check(b._drum > 0.0, "족장: 전쟁 북 예고")
	for i in 60:
		h.tick(1.0 / 30.0)
		if h.slimes.size() > 1:
			break
	var called := h.slimes.filter(func(o: WildSlime) -> bool: return o.minion)
	_check(called.size() == Config.CHIEF_CALL and called.all(func(o: WildSlime) -> bool: return o.shield and o.gold_t > 0.0), "북이 울리면 방패 도마뱀 %d (금빛 방패)" % Config.CHIEF_CALL)
	for o: WildSlime in called:
		h.slimes.erase(o)
		o.queue_free()
	b._recover = 0.0
	b._pattern_cd = 0.0
	b.position = feet + Vector2(30, 0)
	b.tick(1.0 / 30.0, feet)
	_check(b.telegraphs().any(func(t: Dictionary) -> bool: return t.get("tail", false)), "다음 차례: 꼬리 휘두르기 (둘레 원)")
	h._invulnerable = 0.0
	h.life = 200
	for i in 60:
		h.tick(1.0 / 30.0)
		if h.life < 200:
			break
	_check(h.life == 200 - b.damage, "꼬리에 휩쓸리면 체력 -%d" % b.damage)
	b.hp = b.max_hp / 2 - 1
	b._bales.clear()
	b._recover = 0.0
	b._pattern_cd = 0.0
	b._chief_step = 2
	b.tick(1.0 / 30.0, feet)
	_check(b.telegraphs().filter(func(t: Dictionary) -> bool: return t.get("spear", false)).size() == Config.CHIEF_SPEARS, "체력 절반 아래: 창 던지기 %d" % Config.CHIEF_SPEARS)
	m.leave_hunt()
	m.queue_free()
	await get_tree().process_frame


## 51) 마을회관 · 이장 · 게시판 · 심부름 · 잔치상 · 잔치 장면 · 저장
func _hall_checks() -> void:
	var m: Node2D = load("res://scenes/main.tscn").instantiate()
	add_child(m)
	await get_tree().process_frame
	GameState.reset()
	TestStarts.apply(m, &"sonae")
	# 용을 잡으면 용 비늘 + final_boss_down, 다음 날 아침 회관 터
	GameState.hunts_today = 0
	m.enter_hunt(null, 9)
	var h: HuntGround = m.hunt
	h.set_ai(false)
	h.set_process(false)
	for o: WildSlime in h.slimes.duplicate():
		o.queue_free()
	h.slimes.clear()
	h._defeat(h.spawn_boss())
	_check(GameState.final_boss_down and GameState.material5 == 1, "용 처치: 마지막 대장 · 용 비늘 1")
	m.leave_hunt()
	_check(m.hall == null, "회관 터는 그날 바로는 안 나옴")
	var lines: Array[String] = m.next_day()
	_check(GameState.hall_state == 1 and m.hall != null and lines.any(func(l: String) -> bool: return l.contains("마을회관 터")), "용 첫 처치 다음 날 아침 마을회관 터")
	_check(not Config.HALL_RECT.intersects(Config.FEAST_RECT) and not Config.HALL_RECT.has_point(Config.CHIEF_CELL) and not Config.HALL_RECT.has_point(Creature.errand_spot()), "회관 · 잔치상 · 이장 · 심부름 칸이 안 겹침")
	_check(not VillageHall.restore(m) and GameState.hall_state == 1, "모자라면 못 고침")
	GameState.money += Config.HALL_COST_MONEY
	GameState.crops += Config.HALL_COST_CROPS
	GameState.material5 += Config.HALL_COST_MATERIAL
	VillageHall.restore(m)
	SiteWork.fill(&"hall")
	_check(VillageHall.restore(m) and GameState.hall_state == 2 and m.chief.visible and GameState.feast_state == 1 and m.feast_table != null, "돈 · 무 · 용 비늘로 고침 → 이장 · 잔치상")
	_check(not GameState.hall_request.is_empty() and VillageHall.request_pool().has(&"fish"), "게시판 부탁이 붙음 (나루터를 고쳤으니 물고기 부탁도)")
	m.player.position = Farm.center_of(Config.CHIEF_CELL) + Vector2(10, 0)
	m.interact()
	_check(m.menu_open and m.menu_kind == &"board" and VillageHall.options(m, &"board").has(&"reroll"), "이장에게 F → 게시판 (부탁 바꾸기도)")
	m.close_menu()
	_check(FacilityWorkers.is_open(&"hall"), "회관 일꾼 자리 (심부름)")
	# 게시판: 무 부탁으로 고정해 보고 심부름 · 들어주기
	GameState.hall_request = {id = &"crops", count = 20}
	GameState.errands = 0
	var c: Creature = m.creatures[0]
	c.job = CreatureJobs.ERRAND
	for i in 6:
		c.night_work()
	_check(GameState.errands == 0 or not c.data.species.job_aptitude.has(CreatureJobs.NIGHT), "밤일 없는 크리처는 밤 심부름 안 함")
	GameState.errands = Config.ERRAND_CAP
	_check(not Creature.errand_open(), "심부름은 하루 ERRAND_CAP 번")
	GameState.crops = 20
	var money0 := GameState.money
	_check(VillageHall.turn_in(m) and GameState.crops == 20 - (20 - Config.ERRAND_CAP) and GameState.money == money0 + roundi(20 * Config.CROP_PRICE * Config.HALL_REWARD_MULT) and GameState.hall_request.is_empty(), "부탁 들어주기: 심부름 몫을 빼고 내고 보상")
	GameState.hall_request = {id = &"crops", count = 20}
	_check(VillageHall.reroll(m) and GameState.hall_request.id != &"crops" and not VillageHall.reroll(m), "이장에게 하루 한 번 부탁 바꾸기")
	var lines2: Array[String] = m.next_day()
	_check(not GameState.hall_request.is_empty() and GameState.errands == 0 and not GameState.hall_rerolled and lines2.any(func(l: String) -> bool: return l.contains("게시판")), "아침마다 새 부탁 · 방송")
	# 잔치상: 주인공이 재료를 가져오면 그 사람이 차림
	GameState.crops = 30
	_check(not VillageHall.set_dish(m, &"greens") and GameState.feast_dishes.is_empty(), "재료가 모자라면 못 차림")
	GameState.crops = 50
	GameState.potatoes = 0
	_check(not VillageHall.set_dish(m, &"greens"), "감자가 모자라면 농부 상을 못 차림")
	GameState.potatoes = 10
	GameState.peppers = 6
	GameState.cabbages = 4
	_check(VillageHall.set_dish(m, &"greens") and GameState.crops == 30 and GameState.potatoes == 0 and GameState.cabbages == 0, "농부가 김치 · 감자전 · 뭇국 (무 · 감자 · 고추 · 배추)")
	_check(not VillageHall.set_dish(m, &"greens"), "같은 상은 한 번")
	_check(not VillageHall.options(m, &"feast").has(&"open_feast"), "다 안 찼으면 잔치 열기 없음")
	GameState.junk = 20
	GameState.scrap = 20
	GameState.roots = 10
	GameState.hen_eggs = 12
	GameState.fish = 8
	GameState.money += 3000
	for dish: StringName in [&"skewer", &"cauldron", &"wine", &"eggs", &"stew_pot", &"rice_cake"]:
		VillageHall.set_dish(m, dish)
	_check(VillageHall.feast_full() and VillageHall.options(m, &"feast").has(&"open_feast"), "일곱 상이 다 차면 잔치 열기")
	var credits := FeastScene.credit_lines(m)
	_check(credits.any(func(l: String) -> bool: return l.contains("이장")) and credits.any(func(l: String) -> bool: return l.contains("소내섬")), "크레딧: 사람 일곱 · 걸어온 길")
	# 잔치 장면: 연 뒤 F 두 번 (넘기기 · 다음 날 아침)
	var day0 := GameState.day
	_check(m.start_feast() and GameState.feast_state == 2 and m._feast_scene != null, "잔치 열기 → 잔치 장면")
	await get_tree().process_frame
	_check(m.player.position.distance_to(m.feast_table.position) < 120 and m.creatures.all(func(x: Creature) -> bool: return not x.visible), "사람은 잔치상 뒤, 크리처는 손님 그림으로")
	m._feast_scene.press()
	m._feast_scene.press()
	await get_tree().process_frame
	_check(m._feast_scene == null and GameState.day == day0 + 1 and m.sleeping and m._morning_text.text.contains("잔치가 끝났다"), "F 로 다음 날 아침 (엔딩 카드)")
	_check(m.creatures.all(func(x: Creature) -> bool: return x.visible or x.expedition_zone >= 0) and m.player.position.distance_to(m.feast_table.position) > 0, "잔치 뒤 크리처 · 사람 제자리")
	m.wake_up()
	# 저장 → 불러오기
	SaveGame.dir = "user://smoke_saves"
	DirAccess.make_dir_recursive_absolute(SaveGame.dir)
	_check(SaveGame.save(m, 2), "잔치 뒤 저장")
	m.queue_free()
	await get_tree().process_frame
	var b: Node2D = load("res://scenes/main.tscn").instantiate()
	add_child(b)
	await get_tree().process_frame
	_check(SaveGame.load_into(b, 2) and b.hall != null and b.chief.visible and b.feast_table != null and GameState.feast_state == 2 and GameState.feast_dishes.size() == 7, "불러오면 회관 · 이장 · 잔치상 · 잔치 뒤 그대로")
	SaveGame.erase(2)
	b.queue_free()
	await get_tree().process_frame
	# 시작 지점 잔치 준비
	var c2: Node2D = load("res://scenes/main.tscn").instantiate()
	add_child(c2)
	await get_tree().process_frame
	GameState.reset()
	TestStarts.apply(c2, &"feast")
	_check(GameState.hall_state == 2 and GameState.feast_state == 1 and c2.chief.visible and c2.creatures.any(func(x: Creature) -> bool: return x.job == CreatureJobs.ERRAND), "시작 지점 잔치 준비: 이장 · 잔치상 · 심부름 크리처")
	# 크리처 시설 배치 (2026-10-03): 시작 지점의 시설 일 크리처는 멍석 위 일꾼, 아침에 시설마다 일을 해 둠
	var all_on_mats: bool = c2.creatures.all(func(x: Creature) -> bool: return not FacilityWorkers.is_facility_job(x.job) or x.home in Config.WORKER_SLOTS[FacilityWorkers.JOBS.find_key(x.job)])
	_check(all_on_mats, "시설 일 크리처는 모두 그 시설 멍석 위")
	for fac: StringName in [&"yak", &"barn", &"naru"]:
		if FacilityWorkers.workers(c2, fac).is_empty():
			var extra: Creature = c2._hatch(CreatureCatalog.SLIME, Config.FORAGE_CELLS[0])
			FacilityWorkers.assign(c2, extra, fac)
	GameState.yak_brew = &"lamp_oil"
	GameState.roots = 100
	GameState.lamp_oil = 0
	GameState.nest = 3
	GameState.hen_eggs = 0
	GameState.traps = 0
	GameState.crops = 50
	var wl := FacilityWorkers.morning(c2)
	_check(GameState.lamp_oil == FacilityWorkers.workers(c2, &"yak").size() and GameState.roots == 100 - 2 * GameState.lamp_oil, "약방 일꾼이 정해 둔 약 (호롱 기름) 을 한 마리에 한 번씩 달임")
	_check(GameState.hen_eggs >= 2 and GameState.nest <= 1, "축사 일꾼이 둥지 달걀을 거둬 둠 (병아리용 하나만 남김)")
	_check(GameState.traps == Config.TRAP_MAX and GameState.crops == 50 - Config.TRAP_MAX * Config.TRAP_BAIT, "나루터 일꾼이 무 미끼로 통발을 다시 놓음")
	_check(wl.size() == 3, "아침 카드에 일꾼 줄 셋")
	c2.cycle_yak_brew()
	_check(GameState.yak_brew != &"lamp_oil", "연금술사 창에서 달일 약을 바꿈")
	c2.queue_free()
	await get_tree().process_frame


## 52) 밭 작물: 막 대장을 처음 잡은 다음 아침 씨앗 → 구역마다 작물 → 자라는 날 · 거두는 수 · 고추 다시 열림 · 진열 · 저장
func _crop_checks() -> void:
	var m: Node2D = load("res://scenes/main.tscn").instantiate()
	add_child(m)
	await get_tree().process_frame
	GameState.reset()
	var farm: Farm = m.farm
	_check(Crops.unlocked() == [&"radish"] and Crops.options() == [&"compost", &"back"], "처음엔 무만 (밭 작물 메뉴엔 퇴비만)")
	GameState.bosses_beaten.append(Config.FORGE_ZONE)
	var lines: Array[String] = m.next_day()
	_check(&"potato" in GameState.crop_unlocked and GameState.potato_seeds == Config.CROP_UNLOCK_SEEDS and lines.any(func(l: String) -> bool: return l.contains("감자 씨앗")), "금사리 대장 다음 아침 감자 씨앗")
	_check(m.supply_options().has(&"crops") and Crops.options().has(&"plot_0") and Crops.options().has(&"seeds_potato") and not Crops.options().has(&"seeds_pepper"), "공급함 밭 작물 메뉴: 구역 · 감자 씨앗")
	_check(Crops.act(&"plot_0") and Crops.plot_kind(0) == &"potato" and Crops.cycle_plot(0) == &"radish", "구역 작물 바꾸기 (무 → 감자 → 무)")
	Crops.set_plot(0, &"potato")
	var cell := fc(1, 2)
	var seeds0 := GameState.seeds
	farm.do_work(Farm.Work.TILL, cell)
	_check(farm.do_work(Farm.Work.SOW, cell) and farm.get_cell(cell).kind == &"potato" and GameState.potato_seeds == Config.CROP_UNLOCK_SEEDS - 1 and GameState.seeds == seeds0, "감자 구역엔 감자 씨앗을 심음 (무 씨앗 그대로)")
	var c := farm.get_cell(cell)
	for d in 2:
		farm.do_work(Farm.Work.WATER, cell)
		farm.advance_day()
	_check(c.is_ripe(), "감자는 2일")
	_check(farm.do_work(Farm.Work.HARVEST, cell) and GameState.potatoes == 2 and not c.planted and GameState.potato_seeds == Config.CROP_UNLOCK_SEEDS, "감자 한 칸에 둘 + 씨앗 하나 돌려받음")
	# 고추: 4일, 딴 뒤 2일마다, 4번
	GameState.crop_unlocked.append(&"pepper")
	GameState.pepper_seeds = 1
	Crops.set_plot(0, &"pepper")
	farm.do_work(Farm.Work.SOW, cell)
	for d in 4:
		farm.do_work(Farm.Work.WATER, cell)
		farm.advance_day()
	_check(c.is_ripe() and c.kind == &"pepper" and Farm.crop_stage(c) == 3, "고추는 4일")
	var picks := 0
	for round in 4:
		if farm.do_work(Farm.Work.HARVEST, cell):
			picks += 1
		if round < 3:
			_check(c.planted and not c.is_ripe() and Farm.crop_stage(c) == 2, "고추 딴 뒤 그대로 섬 (%d번째)" % (round + 1))
			for d in 2:
				farm.do_work(Farm.Work.WATER, cell)
				farm.advance_day()
	_check(picks == 4 and GameState.peppers == 4 and not c.planted and GameState.pepper_seeds == Config.SEEDS_PER_HARVEST, "고추 한 번 심어 네 번 따고 끝")
	# 진열: 무 · 감자 · 고추 한꺼번에, 아침에 값대로
	GameState.crops = 2
	GameState.crop_stars = {}
	var money0 := GameState.money
	_check(m.supply_action(&"display_crops") and Crops.held_total() == 0, "작물 한꺼번에 진열")
	m.next_day()
	_check(GameState.money - money0 == 2 * Config.CROP_PRICE + 2 * int(Config.CROPS[&"potato"].price) + 4 * int(Config.CROPS[&"pepper"].price), "밤사이 작물값 (무 · 감자 · 고추)")
	# 크리처도 구역 작물을 심는다
	Crops.set_plot(0, &"potato")
	GameState.potato_seeds = 5
	var sl: Creature = m._hatch(CreatureCatalog.STARTER_EGG, cell)
	sl.job = CreatureJobs.FARM
	sl.auto_work = false
	var other := cell + Vector2i.RIGHT
	farm.do_work(Farm.Work.TILL, other)
	for i in 3:
		if farm.get_cell(other).planted or not sl.work_once():
			break
		await get_tree().create_timer(sl.hop_time() + Config.CREATURE_WORK_ANIM_TIME + 0.2).timeout
	_check(farm.get_cell(other).planted and farm.get_cell(other).kind == &"potato", "농사 크리처도 구역 작물 (감자) 을 심음")
	# 저장 · 불러오기: 칸 작물 · 딴 횟수
	SaveGame.dir = "user://smoke_saves"
	DirAccess.make_dir_recursive_absolute(SaveGame.dir)
	c.planted = true
	c.kind = &"pepper"
	c.picks = 2
	c.growth = 3
	_check(SaveGame.save(m, 3), "저장")
	var snap := SaveGame.snapshot(m)
	m.queue_free()
	await get_tree().process_frame
	GameState.reset()
	var b: Node2D = load("res://scenes/main.tscn").instantiate()
	add_child(b)
	await get_tree().process_frame
	_check(SaveGame.load_into(b, 3), "불러오기")
	var bc: Farm.Cell = b.farm.get_cell(cell)
	_check(bc.kind == &"pepper" and bc.picks == 2 and Crops.plot_kind(0) == &"potato" and &"pepper" in GameState.crop_unlocked and SaveGame.snapshot(b).farm == snap.farm, "불러오면 칸 작물 · 구역 작물 · 열린 작물 그대로")
	SaveGame.erase(3)
	b.queue_free()
	await get_tree().process_frame


## 53) 작물 등급 (돌봄 점수) · 퇴비 · 사냥 음식 (2026-10-03 사용자 선택)
func _grade_checks() -> void:
	var m: Node2D = load("res://scenes/main.tscn").instantiate()
	add_child(m)
	await get_tree().process_frame
	GameState.reset()
	var farm: Farm = m.farm
	var cell := fc(1, 2)
	var c := farm.get_cell(cell)
	# 물을 하루도 안 빠뜨리면 ★2
	farm.do_work(Farm.Work.TILL, cell)
	farm.do_work(Farm.Work.SOW, cell)
	for d in Config.CROP_GROW_DAYS:
		farm.do_work(Farm.Work.WATER, cell)
		farm.advance_day()
	_check(farm.do_work(Farm.Work.HARVEST, cell) and farm.last_grade == 2 and Crops.stars(&"radish") == [0, 1, 0], "물을 하루도 안 빠뜨린 무는 ★2")
	# 하루 빠뜨리면 ★1
	farm.do_work(Farm.Work.SOW, cell)
	farm.advance_day()
	_check(c.missed, "물 없이 지난 밤은 빠뜨린 날")
	for d in Config.CROP_GROW_DAYS:
		farm.do_work(Farm.Work.WATER, cell)
		farm.advance_day()
	_check(farm.do_work(Farm.Work.HARVEST, cell) and farm.last_grade == 1 and Crops.stars(&"radish") == [1, 1, 0], "하루 빠뜨리면 ★1")
	# 퇴비: 들나물 3 → 1, 심은 칸에 주면 ★3
	GameState.herbs = Config.COMPOST_COST
	_check(Crops.act(&"compost") and GameState.compost == 1 and GameState.herbs == 0, "들나물로 퇴비 만들기")
	GameState.displayed_herbs = Config.COMPOST_COST
	GameState.junk = 0
	_check(Crops.make_compost() and GameState.displayed_herbs == 0 and GameState.compost == 2, "진열해 둔 들나물로도 퇴비")
	GameState.compost = 1
	_check(not Crops.make_compost(), "재료가 없으면 퇴비를 못 만듦")
	_check(not farm.fertilize(cell), "안 심은 칸엔 퇴비를 못 줌")
	farm.do_work(Farm.Work.SOW, cell)
	_check(farm.fertilize(cell) and c.fert and GameState.compost == 0 and not farm.fertilize(cell), "심은 칸에 퇴비 한 줌 (한 번만)")
	for d in Config.CROP_GROW_DAYS:
		farm.do_work(Farm.Work.WATER, cell)
		farm.advance_day()
	_check(farm.do_work(Farm.Work.HARVEST, cell) and farm.last_grade == 3 and not c.fert, "물 + 퇴비 = ★3, 거두면 퇴비는 다시 없음")
	# 씨앗 주머니로 퇴비 주기 (주인공 손)
	GameState.compost = 1
	farm.do_work(Farm.Work.SOW, cell)
	m.player.position = Farm.center_of(cell + Vector2i.UP)
	m.player.facing = Vector2i.DOWN
	m.tool_index = m.TOOLS.find(Farm.Work.SOW)
	m.use_tool()
	_check(c.fert and GameState.compost == 0, "이미 심은 칸에 씨앗 주머니를 쓰면 퇴비")
	# 속성 맞는 크리처가 돌본 칸
	farm.do_work(Farm.Work.WATER, cell, [&"fire"] as Array[StringName])
	_check(not c.matched, "속성이 안 맞으면 그대로")
	c.watered = false
	farm.do_work(Farm.Work.WATER, cell, [&"spirit"] as Array[StringName])
	_check(c.matched, "무는 정령 속성 크리처가 돌보면 잘 큼")
	c.fert = false
	_check(Crops.harvest_grade(c, 0.0) == 3 and Crops.harvest_grade(c, 0.99) == 2, "속성 맞으면 확률로 한 단계 더")
	# 다른 데 쓰면 ★1 부터
	GameState.crops = 0
	GameState.crop_stars = {}
	Crops.add_graded(&"radish", 2, 1)
	Crops.add_graded(&"radish", 1, 3)
	GameState.crops -= 2
	_check(Crops.stars(&"radish") == [0, 0, 1], "공사 · 모이로 쓰면 ★1 부터 씀")
	GameState.crops -= 1
	_check(Crops.stars(&"radish") == [0, 0, 0], "다 쓰면 ★ 도 없어짐")
	# 팔면 ★ 웃돈
	Crops.add_graded(&"radish", 1, 3)
	Crops.add_graded(&"radish", 1, 2)
	var money0 := GameState.money
	m.supply_action(&"display_crops")
	var lines: Array[String] = m.next_day()
	var want := Config.CROP_PRICE * (Config.STAR_PRICE_PCT[2] + Config.STAR_PRICE_PCT[1]) / 100
	_check(GameState.money - money0 == want and lines.any(func(l: String) -> bool: return l.contains("값을 더 쳐")), "★3 · ★2 무는 더 비싸게 팔림 (%d원)" % want)
	# 사냥 음식: 찐 감자는 가장 좋은 감자 등급
	GameState.crop_unlocked.append(&"potato")
	Crops.add_graded(&"potato", 2, 1)
	Crops.add_graded(&"potato", 1, 3)
	_check(Crops.options().has(&"food_steamed_potato") and not Crops.options().has(&"food_kimchi"), "열린 작물의 음식만 메뉴에")
	_check(Crops.act(&"food_steamed_potato") and GameState.foods[&"steamed_potato"] == [0, 0, 1] and Crops.stars(&"potato") == [1, 0, 0], "찐 감자 ★3 (★3 감자 하나 + ★1 하나)")
	_check(not Crops.act(&"food_steamed_potato"), "감자가 모자라면 못 만듦")
	GameState.crop_unlocked.append(&"pepper")
	GameState.peppers = 2
	_check(Crops.cook(&"pepper_rice") == 1, "고추장 주먹밥 ★1")
	GameState.hunts_today = 0
	m.enter_hunt()
	var hunt: HuntGround = m.hunt
	_check(hunt.food_hp == 40 and is_equal_approx(hunt.food_attack, 0.1) and Crops.food_count(&"steamed_potato") == 0 and Crops.food_count(&"pepper_rice") == 0, "사냥에 들어가면 음식마다 하나씩 먹음 (체력 +40 · 공격 +10%)")
	_check(hunt.life == hunt.max_life(), "찐 감자로 늘어난 체력만큼 참")
	m.leave_hunt()
	await get_tree().process_frame
	# 저장: 퇴비 칸 · 음식 · ★
	SaveGame.dir = "user://smoke_saves"
	DirAccess.make_dir_recursive_absolute(SaveGame.dir)
	farm.do_work(Farm.Work.SOW, cell)
	c.fert = true
	c.missed = true
	GameState.foods = {&"kimchi": [0, 1, 0]}
	Crops.add_graded(&"potato", 3, 2)
	_check(SaveGame.save(m, 3), "저장")
	m.queue_free()
	await get_tree().process_frame
	GameState.reset()
	var b: Node2D = load("res://scenes/main.tscn").instantiate()
	add_child(b)
	await get_tree().process_frame
	_check(SaveGame.load_into(b, 3), "불러오기")
	var bc: Farm.Cell = b.farm.get_cell(cell)
	_check(bc.fert and bc.missed and Crops.food_count(&"kimchi") == 1 and Crops.stars(&"potato")[1] == 3, "불러오면 퇴비 칸 · 음식 · ★ 그대로")
	SaveGame.erase(3)
	b.queue_free()
	await get_tree().process_frame
