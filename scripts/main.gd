extends Node2D
## 프로토타입 메인 화면.
## 흐름: 농부 직접 농사 → 사냥꾼이 알 획득 → 마을 공급함 → 농부가 부화 → 크리처 배치로 자동화.

const TOOLS: Array[Farm.Work] = [Farm.Work.TILL, Farm.Work.SOW, Farm.Work.WATER, Farm.Work.HARVEST]
const TOOL_NAMES := {
	Farm.Work.TILL: "괭이",
	Farm.Work.SOW: "씨앗",
	Farm.Work.WATER: "물뿌리개",
	Farm.Work.HARVEST: "수확",
}
## 도구 강화 (2026-09-27 후보 A 첫 조각): 강화하면 이름이 바뀌고 앞 3칸 일자에 한 번에 쓴다.
const UPGRADED_TOOL_NAMES := {
	Farm.Work.TILL: "넓은 괭이",
	Farm.Work.WATER: "큰 물뿌리개",
}
## 공급함 선택창 id → 강화할 도구와 값
const TOOL_UPGRADES := {
	&"upgrade_hoe": [Farm.Work.TILL, Config.HOE_UPGRADE_PRICE],
	&"upgrade_can": [Farm.Work.WATER, Config.CAN_UPGRADE_PRICE],
}
## 마을 오브젝트가 차지하는 칸 (왼쪽 위 칸, 크기). 크기는 2026-09-27 결정, 자리는 임시 배치.
const INCUBATOR_RECT := Rect2i(17, 3, 2, 2)
const SUPPLY_RECT := Rect2i(17, 9, 2, 1)
const HUNT_GATE_RECT := Rect2i(21, 3, 3, 2)
## 마을 공용 창고 궤짝 (2026-09-28 사용자 요청 "창고 기능"). 자리는 임시 배치 (공급함 왼쪽).
const STASH_RECT := Rect2i(16, 9, 1, 1)
## 배경 오브젝트 (2026-09-27 결정: 집 B 양옥, 나무 감나무 + 당산나무 하나). 자리는 임시 배치.
const HOUSE_RECT := Rect2i(20, 8, 5, 4)
const DANGSAN_RECT := Rect2i(13, 11, 2, 2)
const PERSIMMON_CELLS: Array[Vector2i] = [Vector2i(2, 12), Vector2i(7, 12), Vector2i(11, 12), Vector2i(15, 3), Vector2i(25, 6)]
## 막는 범위 (그림 아래쪽 가운데 기준, px). 2026-09-27 결정 C: 집은 벽 두 줄, 나무는 밑동만 막고
## 지붕·나뭇잎 뒤로는 지나간다. 뒤로 가면 가리는 그림이 반투명해진다.
const HOUSE_BLOCK := Rect2(-60, -48, 120, 48)
const PERSIMMON_BLOCK := Rect2(-8, -12, 16, 12)
const DANGSAN_BLOCK := Rect2(-20, -18, 40, 18)
## 알이 부화하면 크리처가 나타나는 칸 (부화기 왼쪽 아래)
const HATCH_CELL := Vector2i(16, 5)
## 농부 집 현관 앞 흙길 칸. 여기서 F를 누르면 잔다 (2026-09-27 결정 A②).
const DOOR_CELL := Vector2i(22, 12)
## 아침 카드 기본 크기 (글이 많으면 세로로 늘어난다)
const MORNING_CARD_SIZE := Vector2(300, 150)
## 선택창에 한 번에 보이는 항목 수 (크리처 훈련처럼 길어질 때)
const MENU_VISIBLE_ROWS := 14

var farm: Farm
## 밭 밖 풀밭의 들나물 (2026-09-29 사용자 선택 A)
var forage: Forage
var farmer: Character
var hunter: Character
## 대장장이 (2026-09-29 대장간 복구 A): 셋째 캐릭터. 대장간을 고치면 나타나고 Tab 으로 바꾼다.
var smith: Character
## 대장간 (터 → 고친 대장간)과 고물 더미. 나타나기 전에는 null.
var forge: Prop
var scrap_heap: Prop
var incubator: Prop
var supply_box: Prop
var hunt_gate: Prop
var stash_box: Prop
var house: Prop
var props: Array[Prop] = []
var creatures: Array[Creature] = []
var active: Character
var tool_index := 0
## 부화기에 든 알이 부화하기까지 남은 날. -1 이면 비어 있음.
var incubating_days := -1
var incubating_species: CreatureSpecies
## 잠든 동안(밤 → 아침 카드)에는 이동·도구를 막고 F만 받는다.
var sleeping := false
var _night: ColorRect
## 저녁·밤 색 (하루 시계에 따라 조금씩 어두워진다. 일은 막지 않는다)
var _dusk: ColorRect
## 하루 시계가 흐르는지. 자동 플레이 봇은 끄고 스스로 시간을 잰다.
var clock_running := true
var _morning_card: Control
var _morning_text: Label
## 마을 공급함 선택창 (농부가 F로 연다). 열려 있는 동안 W/S로 고르고 F로 정한다.
var menu_open := false
## 열려 있는 선택창 종류: &"supply" 마을 공급함, &"companion" 사냥터 입구 동행 고르기
var menu_kind := &"supply"
var menu_index := 0
var _menu_options: Array[StringName] = []
var _menu: ColorRect
var _menu_text: Label
## 디아블로식 가방 창 (I 키, 창고 궤짝 F). 열려 있는 동안 캐릭터는 멈추고 사냥터도 멈춘다.
var inventory: InventoryUI
## 사냥터 (2026-09-27 결정 A). 사냥꾼이 들어가 있는 동안만 있다.
var hunt: HuntGround
## 사냥터에 있는 동안 숨기는 마을 쪽 노드
var _village_nodes: Array[Node2D] = []
## 사냥에 데려간 농장 크리처 (돌아오면 제자리로). 없으면 혼자.
var _companion_source: Creature

var _rng := RandomNumberGenerator.new()
var _status: Label
var _message: Label


func _ready() -> void:
	GameState.reset()
	farm = Farm.new()
	# 바닥은 앞뒤 가림(z_index = 발 y)보다 항상 뒤
	farm.z_index = -1000
	add_child(farm)
	forage = Forage.new()
	add_child(forage)
	forage.sprout(_rng)

	house = _add_prop("", preload("res://assets/props/house.png"), HOUSE_RECT, HOUSE_BLOCK, true)
	_add_prop("", preload("res://assets/props/tree_dangsan.png"), DANGSAN_RECT, DANGSAN_BLOCK, true)
	for cell in PERSIMMON_CELLS:
		_add_prop("", preload("res://assets/props/tree_persimmon.png"), Rect2i(cell, Vector2i.ONE), PERSIMMON_BLOCK, true)
	# 부화기·공급함·사냥터 입구는 키가 낮아 차지하는 칸 전체를 막는다
	incubator = _add_prop("부화기", preload("res://assets/props/incubator.png"), INCUBATOR_RECT)
	supply_box = _add_prop("마을 공급함", preload("res://assets/props/supply_box.png"), SUPPLY_RECT)
	hunt_gate = _add_prop("사냥터 입구", preload("res://assets/props/hunt_gate.png"), HUNT_GATE_RECT)
	stash_box = _add_prop("창고", preload("res://assets/props/stash.png"), STASH_RECT)

	farmer = _add_character("농부", preload("res://assets/characters/player.png"), Vector2i(14, 6), &"farmer")
	hunter = _add_character("사냥꾼", preload("res://assets/characters/hunter.png"), Vector2i(20, 6), &"hunter")
	smith = _add_character("대장장이", preload("res://assets/characters/smith.png"), Config.SMITH_CELL, &"smith")
	smith.visible = false
	_set_active(farmer)

	_build_hud()
	GameState.changed.connect(_refresh_hud)
	# 채집 크리처가 진열하면 공급함 표시도 바뀐다
	GameState.changed.connect(_refresh_props)
	GameState.message.connect(func(t: String) -> void: _message.text = t)
	_refresh_props()
	GameState.notify("농부로 밭을 가꿔 보자. 마을 공급함에 알이 하나 있다. 풀밭의 들나물은 F로 캔다.")
	# 테스트용 시작 지점 (2026-09-29): 개발용 빌드에서 게임으로 켰을 때만 (테스트 장면 안에서는 안 뜸)
	if OS.is_debug_build() and get_parent() == get_tree().root:
		open_menu(&"start")


func _add_prop(label: String, texture: Texture2D, rect: Rect2i, block := Rect2(), fade := false) -> Prop:
	var p := Prop.new()
	p.label = label
	p.texture = texture
	p.place(rect.position, rect.size)
	p.blocker = block if block.has_area() else p.footprint_rect()
	p.fade_behind = fade
	add_child(p)
	props.append(p)
	farm.add_blocker(p.blocker_world())
	return p


func _add_character(display_name: String, sheet: Texture2D, cell: Vector2i, who: StringName) -> Character:
	var c := Character.new()
	c.display_name = display_name
	c.who = who
	c.sheet = sheet
	c.position = Farm.center_of(cell)
	c.farm = farm
	add_child(c)
	return c


func _set_active(c: Character) -> void:
	if active:
		active.active = false
	active = c
	active.active = true
	GameState.touch()


func _process(delta: float) -> void:
	if hunt == null:
		update_fading()
	if clock_running and not sleeping and not menu_open and not inventory.visible:
		advance_clock(delta * Config.CLOCK_MINUTES_PER_SECOND)


## 하루 시계를 게임 분만큼 돌린다. 새벽 2시에서 멈추고, 아무것도 막지 않는다. HUD는 10분마다 고친다.
func advance_clock(game_minutes: float) -> void:
	var before := int(GameState.minutes) / 10
	GameState.minutes = minf(GameState.minutes + game_minutes, Config.CLOCK_MAX_MINUTE)
	_update_dusk()
	if int(GameState.minutes) / 10 != before:
		_refresh_hud()


func _update_dusk() -> void:
	var t := inverse_lerp(Config.DUSK_START_MINUTE, Config.DUSK_FULL_MINUTE, GameState.minutes)
	_dusk.color.a = clampf(t, 0.0, 1.0) * Config.DUSK_ALPHA


## 캐릭터·크리처가 집·나무 그림 뒤에 가려지면 그 그림을 반투명하게 한다.
func update_fading() -> void:
	for p in props:
		if not p.fade_behind:
			continue
		var pic := Rect2(p.picture_rect().position + p.position, p.picture_rect().size)
		var hidden := false
		for c: Character in [farmer, hunter, smith]:
			if not c.visible:
				continue
			hidden = hidden or (c.sort_y() < p.sort_y() and pic.intersects(Rect2(c.position + Vector2(-8, -30), Vector2(16, 40))))
		for s in creatures:
			hidden = hidden or (s.carried_by == null and s.sort_y() < p.sort_y() and pic.intersects(Rect2(s.position + Vector2(-8, -10), Vector2(16, 18))))
		p.set_faded(hidden)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if sleeping:
		if event.is_action_pressed("interact"):
			interact()
		return
	if inventory.visible:
		if event.is_action_pressed("inventory") or event.is_action_pressed("menu_close") or event.is_action_pressed("switch_character"):
			close_inventory()
		else:
			inventory.handle_key(event)
		return
	if event.is_action_pressed("inventory") and not menu_open:
		open_inventory()
		return
	if hunt:
		if event.is_action_pressed("attack"):
			hunt.swing(get_global_mouse_position() - (hunter.feet() + Vector2(0, -12)))
		elif event.is_action_pressed("use_tool"):
			hunt.swing()
		elif event.is_action_pressed("use_potion"):
			hunt.drink_potion()
		elif event.is_action_pressed("interact"):
			interact()
		elif event.is_action_pressed("switch_character"):
			GameState.notify("사냥 중에는 캐릭터를 바꿀 수 없다. 아래 입구에서 F로 돌아가자.")
		return
	if menu_open:
		if menu_kind == &"start" and event is InputEventKey and event.pressed and event.physical_keycode >= KEY_1 and event.physical_keycode <= KEY_9:
			var n: int = event.physical_keycode - KEY_1
			if n < _menu_options.size():
				menu_index = n
				menu_confirm()
			return
		if event.is_action_pressed("move_up"):
			menu_move(-1)
		elif event.is_action_pressed("move_down"):
			menu_move(1)
		elif event.is_action_pressed("interact") or event.is_action_pressed("use_tool"):
			menu_confirm()
		elif event.is_action_pressed("menu_close") or event.is_action_pressed("switch_character"):
			close_menu()
		return
	if event.is_action_pressed("switch_character"):
		switch_character()
	elif event.is_action_pressed("use_tool"):
		use_tool()
	elif event.is_action_pressed("interact"):
		interact()
	elif event.is_action_pressed("creature_job"):
		change_creature_job()
	elif event.is_action_pressed("next_day") and OS.is_debug_build():
		# 개발용 단축키. 정식 빌드에서는 현관에서 자야 하루가 넘어간다.
		next_day()
	elif event.is_action_pressed("tool_next"):
		cycle_tool(1)
	elif event.is_action_pressed("tool_prev"):
		cycle_tool(-1)


# --- 플레이어 동작 ---------------------------------------------------------

func switch_character() -> void:
	if not GameState.hunter_unlocked:
		GameState.notify("아직 사냥꾼을 조작할 수 없다. 첫 크리처를 밭에 배치해 보자.")
		return
	# 농부 → 사냥꾼 → (대장간을 고쳤으면) 대장장이 → 농부
	var order: Array[Character] = [farmer, hunter]
	if GameState.forge_state >= 2:
		order.append(smith)
	_set_active(order[(order.find(active) + 1) % order.size()])
	if active == smith:
		GameState.notify("대장장이로 전환했다. 대장간 모루에서 F로 장비를 만든다.")
	else:
		GameState.notify("%s(으)로 전환했다." % active.display_name)


func cycle_tool(step: int) -> void:
	tool_index = wrapi(tool_index + step, 0, TOOLS.size())
	GameState.touch()


func use_tool() -> void:
	if active != farmer:
		GameState.notify("농사 도구는 농부만 쓸 수 있다.")
		return
	var work := TOOLS[tool_index]
	var done := 0
	for cell in tool_cells(work):
		if farm.do_work(work, cell):
			done += 1
	if done == 0:
		if work == Farm.Work.SOW and GameState.seeds <= 0:
			GameState.notify("씨앗이 없다.")
		else:
			GameState.notify("여기서는 %s을(를) 쓸 수 없다." % tool_name(work))


## 도구가 닿는 칸. 강화한 도구는 바라보는 방향으로 앞 3칸 일자.
func tool_cells(work: Farm.Work) -> Array[Vector2i]:
	var first := farmer.facing_cell()
	var reach := Config.TOOL_UPGRADE_REACH if GameState.tool_level(work) > 0 else 1
	if work == Farm.Work.SOW:
		reach = Wearables.sow_reach(farmer.who)
	elif work == Farm.Work.TILL or work == Farm.Work.WATER:
		# 대장간 제작품 옵션 "괭이 · 물뿌리개 칸 +" (2026-09-29)
		reach += Wearables.stat_sum(farmer.who, "reach_add")
	var cells: Array[Vector2i] = []
	for i in reach:
		cells.append(first + farmer.facing * i)
	return cells


func tool_name(work: Farm.Work) -> String:
	return UPGRADED_TOOL_NAMES[work] if GameState.tool_level(work) > 0 else TOOL_NAMES[work]


func interact() -> void:
	if sleeping:
		if _morning_card.visible:
			wake_up()
		return
	if hunt:
		if hunt.near_exit():
			leave_hunt()
		elif hunt.near_next():
			hunt.advance()
		elif hunt.path_open:
			GameState.notify("위쪽 길에서 F로 더 깊이, 아래 입구에서 F로 마을로 돌아간다.")
		else:
			GameState.notify("아래 입구에서 F로 마을로 돌아간다.")
		return
	if near_door() and _carried_creature() == null:
		go_to_sleep()
		return
	if forge and _near(forge) and _carried_creature() == null:
		_forge_interact()
	elif scrap_heap and _near(scrap_heap) and _carried_creature() == null and active != hunter:
		pick_scrap()
	elif active == farmer:
		_farmer_interact()
	elif active == hunter:
		_hunter_interact()
	else:
		GameState.notify("대장장이는 대장간 모루에서 F로 장비를 만든다. 고철은 고물 더미에서 F로 줍거나 크리처에게 맡긴다.")
	_refresh_props()


func _farmer_interact() -> void:
	var carried := _carried_creature()
	if carried:
		carried.place(farmer.cell())
		if not GameState.hunter_unlocked:
			GameState.hunter_unlocked = true
			GameState.notify("%s이(가) 주변 밭에서 일하기 시작했다! 이제 Tab으로 사냥꾼을 조작할 수 있다." % carried.data.species.display_name)
		else:
			GameState.notify("%s을(를) 내려놓았다. R 키로 맡길 일을 고른다." % carried.data.species.display_name)
		return
	var s := _nearest_creature()
	if s:
		s.pick_up(farmer)
		GameState.notify("%s을(를) 들었다. 원하는 자리에서 다시 F." % s.data.species.display_name)
	elif forage.nearest(farmer.feet()) != null:
		var herb := forage.pick(forage.nearest(farmer.feet()))
		GameState.herbs += 1
		GameState.notify("%s%s 캤다! (들나물 %d) 공급함에 진열하면 밤사이 한 포기 %d원." % [herb, Forage.object_particle(herb), GameState.herbs, Config.HERB_PRICE])
	elif forage.nearest_root(farmer.feet()) != null:
		GameState.notify("땅속 깊이 %s 뿌리가 있다. 손으로는 못 캔다. 땅속성 크리처에게 채집(R)을 맡기면 캐 온다." % Config.ROOT_NAME)
	elif _near_stash():
		open_inventory(true)
	elif _near(supply_box):
		open_menu()
	elif _near(incubator):
		if incubating_days >= 0:
			GameState.notify("알이 부화 중이다. %d일 남았다." % incubating_days)
		elif GameState.farmer_eggs.is_empty():
			GameState.notify("넣을 알이 없다.")
		else:
			incubating_species = GameState.farmer_eggs.pop_front()
			incubating_days = Config.EGG_HATCH_DAYS
			GameState.notify("알을 부화기에 넣었다. 하룻밤 자고 나면 부화한다 (집 현관에서 F).")


func _hunter_interact() -> void:
	if _near(hunt_gate):
		# 켜진 웨이포인트가 있으면 어디서 시작할지 먼저 고른다 (2026-09-28 사용자 선택 B + 웨이포인트)
		_pending_zone = 0
		if GameState.hunts_today < Config.HUNTS_PER_DAY and GameState.waypoints.size() > 1:
			open_menu(&"waypoint")
		else:
			_open_companion_or_enter()
	elif _near_stash():
		open_inventory(true)
	elif _near(supply_box):
		var has_gear := Wearables.rolled_in_bag(&"hunter") > 0
		if GameState.hunter_eggs.is_empty() and GameState.junk <= 0:
			if has_gear:
				open_menu()
			else:
				GameState.notify("공급할 알이 없다. 사냥터 입구로 가자.")
			return
		var parts: Array[String] = []
		if not GameState.hunter_eggs.is_empty():
			GameState.village_eggs.append_array(GameState.hunter_eggs)
			GameState.hunter_eggs.clear()
			parts.append("마을 공급함에 알을 넣었다. 농부가 받아 갈 수 있다.")
		if GameState.junk > 0:
			# 사냥터 잡템(슬라임 젤리)은 공급함에 두면 바로 값이 나온다 (제작 소재가 아님)
			var earned := GameState.junk * Config.JUNK_PRICE
			parts.append("사냥 잡템 (젤리 · 껍데기 · 깃털 · 옹이) %d개를 팔았다. +%d원" % [GameState.junk, earned])
			GameState.money += earned
			GameState.junk = 0
		GameState.notify(" ".join(parts))
		# 가방에 사냥터 등급 장비가 있으면 장비 팔기 선택창도 연다 (2026-09-28 사용자 선택 A)
		if has_gear:
			open_menu()
	else:
		GameState.notify("사냥터 입구나 마을 공급함 가까이에서 F.")


# --- 사냥터 (2026-09-27 결정 A. 실시간 한 화면, 첫 조각) ------------------

## 사냥터 입구에서 고른 시작 구역 (웨이포인트). 동행을 고른 뒤 enter_hunt 에 넘긴다.
var _pending_zone := 0


## 밭에 크리처가 있으면 누구랑 갈지 먼저 고른다 (2026-09-27 결정 A. 따라오는 동료)
func _open_companion_or_enter() -> void:
	if GameState.hunts_today < Config.HUNTS_PER_DAY and not companion_candidates().is_empty():
		open_menu(&"companion")
	else:
		enter_hunt(null, _pending_zone)

## 사냥에 데려갈 수 있는 크리처 (농장에 나와 있고 들려 있지 않은 크리처)
func companion_candidates() -> Array[Creature]:
	var list: Array[Creature] = []
	for s in creatures:
		if s.carried_by == null:
			list.append(s)
	return list


## 사냥터 입구에서 F. 하루 한 번 들어간다. 마을은 숨기고 사냥터 화면을 띄운다.
## companion 을 주면 그 크리처가 따라온다. 사냥하는 동안 농장 일은 쉬고, 돌아오면 원래 자리·원래 일로 돌아간다.
## zone 은 시작할 웨이포인트 구역 (켜진 것만, 0 = 숲 공터부터).
func enter_hunt(companion: Creature = null, zone := 0) -> bool:
	if hunt:
		return false
	if not zone in GameState.waypoints:
		zone = 0
	if GameState.hunts_today >= Config.HUNTS_PER_DAY:
		GameState.notify("오늘은 이미 사냥을 다녀왔다. 자고 나면 다시 갈 수 있다.")
		return false
	GameState.hunts_today += 1
	_village_nodes.clear()
	for n in get_children():
		if n is Node2D and n != hunter and (n as Node2D).visible and not n.is_queued_for_deletion():
			_village_nodes.append(n)
			(n as Node2D).visible = false
	hunt = HuntGround.new()
	add_child(hunt)
	hunter.farm = null
	hunt.start(hunter, zone)
	_pending_zone = 0
	hunt.knocked_out.connect(leave_hunt)
	if companion:
		_companion_source = companion
		companion.process_mode = Node.PROCESS_MODE_DISABLED
		var c := hunt.add_companion(companion)
		GameState.notify("%s과(와) 사냥터에 들어왔다. 클릭(또는 Space)으로 휘두르면 %s도 알아서 돕는다!" % [c.display_name(), c.display_name()])
		return true
	if zone > 0:
		GameState.notify("%s 웨이포인트에서 사냥을 시작했다. 클릭(또는 Space)으로 휘두른다!" % Config.HUNT_ZONES[zone].name)
	else:
		GameState.notify("사냥터에 들어왔다. 클릭(또는 Space)으로 사냥칼을 휘두른다. 야생 슬라임을 쓰러뜨리자!")
	return true


## 마을로 돌아온다 (아래 입구 F, 또는 하트가 다 떨어져 쓰러졌을 때). 주운 알은 그대로 가진다.
func leave_hunt() -> void:
	if hunt == null:
		return
	var knocked := hunt.knocked
	var eggs := hunt.collect_all()
	GameState.hunter_eggs.append_array(eggs)
	hunt.queue_free()
	hunt = null
	# 금가루에 느려진 채로 마을에 돌아오지 않게
	hunter.slow_mult = 1.0
	for n in _village_nodes:
		n.visible = true
	_village_nodes.clear()
	if _companion_source:
		# 데려간 크리처는 원래 자리에서 원래 일을 다시 한다
		_companion_source.process_mode = Node.PROCESS_MODE_INHERIT
		_companion_source = null
	hunter.farm = farm
	hunter.walk_area = Rect2()
	hunter.terrain = null
	hunter.show_facing_cell = true
	hunter.position = Farm.center_of(HUNT_GATE_RECT.position + Vector2i(1, HUNT_GATE_RECT.size.y))
	hunter.facing = Vector2i.DOWN
	if knocked:
		GameState.notify("사냥꾼이 쓰러져 마을 입구로 돌아왔다. 알 %d개는 그대로 가지고 있다." % eggs.size())
	elif eggs.is_empty():
		GameState.notify("사냥터에서 돌아왔다.")
	else:
		GameState.notify("사냥터에서 알 %d개를 가지고 돌아왔다! 마을 공급함에 넣자." % eggs.size())


# --- 마을 공급함 선택창 (2026-09-27 결정 C) --------------------------------

## 지금 공급함에서 할 수 있는 일. 알 받기와 진열은 가진 게 있을 때만 보인다.
func supply_options() -> Array[StringName]:
	var options: Array[StringName] = []
	# 사냥꾼: 알 넣기 · 젤리 팔기는 F 한 번에 끝나고, 선택창에는 장비 팔기만 (2026-09-28 사용자 선택 A)
	if active == hunter:
		if Wearables.normal_in_bag(&"hunter") > 0:
			options.append(&"sell_normal")
		if Wearables.rolled_in_bag(&"hunter") > 0:
			options.append(&"sell_gear")
		options.append(&"close")
		return options
	if not GameState.village_eggs.is_empty():
		options.append(&"take_eggs")
	# 대장간 제작품은 농부 가방에도 쌓이므로 농부도 공급함에서 판다
	if Wearables.rolled_in_bag(&"farmer") > 0:
		options.append(&"sell_gear")
	if GameState.crops > 0:
		options.append(&"display_crops")
	if GameState.herbs > 0:
		options.append(&"display_herbs")
	options.append(&"buy_seeds")
	if not creatures.is_empty():
		options.append(&"train")
	if Farm.next_plot() >= 0:
		options.append(&"expand_field")
	for id: StringName in TOOL_UPGRADES:
		if GameState.tool_level(TOOL_UPGRADES[id][0]) == 0:
			options.append(id)
	if not GameState.hunter_knife:
		options.append(&"buy_knife")
	for id: StringName in Wearables.shop_items():
		if not Wearables.is_owned(id):
			options.append(id)
	options.append(&"close")
	return options


func supply_option_text(id: StringName) -> String:
	match id:
		&"take_eggs":
			return "알 받기 (%d개)" % GameState.village_eggs.size()
		&"display_crops":
			return "무 진열하기 (%d개, 밤사이 %d원)" % [GameState.crops, GameState.crops * Config.CROP_PRICE]
		&"display_herbs":
			return "들나물 진열하기 (%d포기, 밤사이 %d원)" % [GameState.herbs, GameState.herbs * Config.HERB_PRICE]
		&"buy_seeds":
			return "씨앗 %d개 사기 (%d원)" % [Config.SEED_PACK_SIZE, Config.SEED_PACK_PRICE]
		&"train":
			return "크리처 훈련 (%d마리) ▶" % creatures.size()
		&"expand_field":
			var i := Farm.next_plot()
			return "밭 넓히기: %s (%d원)" % [Config.FIELD_PLOT_NAMES[i], Config.FIELD_PLOT_PRICES[i]]
		&"upgrade_hoe", &"upgrade_can":
			var work: Farm.Work = TOOL_UPGRADES[id][0]
			return "도구 손보기: %s → %s (앞 %d칸, %d원)" % [TOOL_NAMES[work], UPGRADED_TOOL_NAMES[work], Config.TOOL_UPGRADE_REACH, TOOL_UPGRADES[id][1]]
		&"buy_knife":
			return "사냥꾼 튼튼한 사냥칼 (%d원)" % Config.HUNTER_KNIFE_PRICE
		&"sell_normal":
			var n := Wearables.normal_in_bag(active.who)
			return "일반 장비 한꺼번에 팔기 (%d개, %d원)" % [n, n * Config.GEAR_SELL_PRICES[&"normal"]]
		&"sell_gear":
			if active == farmer:
				return "가방에서 장비 팔기 (제작 %d원)" % Config.GEAR_SELL_PRICES[&"crafted"]
			return "가방에서 장비 팔기 (일반 %d · 마법 %d · 레어 %d · 제작 %d원)" % [Config.GEAR_SELL_PRICES[&"normal"], Config.GEAR_SELL_PRICES[&"magic"], Config.GEAR_SELL_PRICES[&"rare"], Config.GEAR_SELL_PRICES[&"crafted"]]
		_ when Wearables.ITEMS.has(id):
			var item: Dictionary = Wearables.ITEMS[id]
			return "%s %s: %s (%s, %d원)" % ["농부" if item.who == &"farmer" else "사냥꾼", Wearables.SLOT_NAMES[item.slot], item.name, item.effect, item.price]
		_:
			return "닫기"


func open_menu(kind := &"supply") -> void:
	menu_kind = kind
	menu_open = true
	menu_index = 0
	active.frozen = true
	_rebuild_menu()


func close_menu() -> void:
	if not menu_open:
		return
	menu_open = false
	_menu.visible = false
	active.frozen = false
	GameState.touch()


func menu_move(step: int) -> void:
	menu_index = wrapi(menu_index + step, 0, _menu_options.size())
	_rebuild_menu()


func menu_confirm() -> void:
	var id := _menu_options[menu_index]
	if menu_kind == &"start":
		close_menu()
		TestStarts.apply(self, id)
		return
	if menu_kind == &"companion":
		var pick := companion_from_option(id)
		close_menu()
		enter_hunt(pick, _pending_zone)
		return
	if menu_kind == &"waypoint":
		close_menu()
		if id == &"close":
			return
		_pending_zone = String(id).trim_prefix("zone_").to_int()
		_open_companion_or_enter()
		return
	if menu_kind == &"forge" or menu_kind == &"craft":
		if id == &"close":
			close_menu()
			return
		if id == &"restore":
			if restore_forge():
				close_menu()
				return
		else:
			craft(id)
		_rebuild_menu()
		return
	if menu_kind == &"train":
		if id == &"back":
			menu_kind = &"supply"
			menu_index = 0
		else:
			var pick := train_from_option(id)
			train(pick[0], pick[1])
		_rebuild_menu()
		return
	if id == &"train":
		menu_kind = &"train"
		menu_index = 0
		_rebuild_menu()
		return
	if id == &"close":
		close_menu()
		return
	if id == &"sell_gear":
		open_inventory(false, true)
		return
	supply_action(id)
	_rebuild_menu()
	_refresh_props()


## 공급함에서 한 가지 일을 한다. 선택창과 테스트가 함께 쓴다.
func supply_action(id: StringName) -> bool:
	match id:
		&"take_eggs":
			if GameState.village_eggs.is_empty():
				GameState.notify("마을 공급함에 알이 없다. 사냥꾼이 알을 가져와야 한다.")
				return false
			GameState.farmer_eggs.append_array(GameState.village_eggs)
			GameState.village_eggs.clear()
			GameState.notify("마을 공급함에서 알을 받았다. 부화기에 넣어 보자.")
		&"display_crops":
			if GameState.crops <= 0:
				GameState.notify("진열할 무가 없다.")
				return false
			var n := GameState.crops
			GameState.displayed_crops += n
			GameState.crops = 0
			GameState.notify("무 %d개를 공급함에 진열했다. 밤사이 마을 사람들이 사 가고 돈통에 값을 넣어 둔다." % n)
		&"display_herbs":
			if GameState.herbs <= 0:
				GameState.notify("진열할 들나물이 없다.")
				return false
			var n := GameState.herbs
			GameState.displayed_herbs += n
			GameState.herbs = 0
			GameState.notify("들나물 %d포기를 공급함에 진열했다. 밤사이 팔리면 아침에 돈통에 들어온다." % n)
		&"buy_seeds":
			if GameState.money < Config.SEED_PACK_PRICE:
				GameState.notify("돈이 모자라다. 씨앗 %d개에 %d원 (가진 돈 %d원)." % [Config.SEED_PACK_SIZE, Config.SEED_PACK_PRICE, GameState.money])
				return false
			GameState.money -= Config.SEED_PACK_PRICE
			GameState.seeds += Config.SEED_PACK_SIZE
			GameState.notify("씨앗 %d개를 샀다. -%d원" % [Config.SEED_PACK_SIZE, Config.SEED_PACK_PRICE])
		&"expand_field":
			var i := Farm.next_plot()
			if i < 0:
				GameState.notify("밭을 모두 넓혔다.")
				return false
			var price := Config.FIELD_PLOT_PRICES[i]
			if GameState.money < price:
				GameState.notify("돈이 모자라다. %s %d원 (가진 돈 %d원)." % [Config.FIELD_PLOT_NAMES[i], price, GameState.money])
				return false
			GameState.money -= price
			farm.open_next_plot()
			GameState.notify("밭을 넓혔다: %s -%d원. 잡초와 돌을 걷어 냈으니 괭이로 갈 수 있다." % [Config.FIELD_PLOT_NAMES[i], price])
		&"upgrade_hoe", &"upgrade_can":
			var work: Farm.Work = TOOL_UPGRADES[id][0]
			var price: int = TOOL_UPGRADES[id][1]
			if GameState.tool_level(work) > 0:
				GameState.notify("이미 %s이(가) 있다." % UPGRADED_TOOL_NAMES[work])
				return false
			if GameState.money < price:
				GameState.notify("돈이 모자라다. %s %d원 (가진 돈 %d원)." % [UPGRADED_TOOL_NAMES[work], price, GameState.money])
				return false
			GameState.money -= price
			GameState.tool_levels[work] = 1
			GameState.notify("%s을(를) %s(으)로 바꿨다! -%d원. 이제 바라보는 방향 앞 %d칸에 한 번에 쓴다." % [TOOL_NAMES[work], UPGRADED_TOOL_NAMES[work], price, Config.TOOL_UPGRADE_REACH])
		&"buy_knife":
			if GameState.hunter_knife:
				GameState.notify("사냥꾼은 이미 튼튼한 사냥칼이 있다.")
				return false
			if GameState.money < Config.HUNTER_KNIFE_PRICE:
				GameState.notify("돈이 모자라다. 튼튼한 사냥칼 %d원 (가진 돈 %d원)." % [Config.HUNTER_KNIFE_PRICE, GameState.money])
				return false
			GameState.money -= Config.HUNTER_KNIFE_PRICE
			GameState.hunter_knife = true
			GameState.notify("사냥꾼에게 튼튼한 사냥칼을 사 줬다! -%d원. 이제 태어나는 크리처는 능력치가 너무 낮게 나오지 않는다." % Config.HUNTER_KNIFE_PRICE)
		&"sell_normal":
			var sold := Wearables.sell_all_normal(active.who)
			if sold[0] == 0:
				GameState.notify("가방에 일반 장비가 없다.")
				return false
			GameState.notify("일반 장비 %d개를 팔았다. +%d원" % [sold[0], sold[1]])
		_ when Wearables.ITEMS.has(id) and not Wearables.is_hunt_drop(id):
			return buy_wear(id)
		_:
			return false
	return true


## 입는 장비를 사서 바로 입힌다 (입던 것은 가방으로).
func buy_wear(id: StringName) -> bool:
	var item: Dictionary = Wearables.ITEMS[id]
	if Wearables.is_owned(id):
		GameState.notify("이미 %s이(가) 있다." % item.name)
		return false
	if GameState.money < item.price:
		GameState.notify("돈이 모자라다. %s %d원 (가진 돈 %d원)." % [item.name, item.price, GameState.money])
		return false
	GameState.money -= item.price
	Wearables.gain_and_wear(id)
	var c := farmer if item.who == &"farmer" else hunter
	c.refresh_wear()
	GameState.notify("%s이(가) %s을(를) 입었다! -%d원. %s" % [c.display_name, item.name, item.price, item.effect])
	return true


# --- 디아블로식 가방 · 공용 창고 (2026-09-28 사용자 요청) ----------------

## 가방 창을 연다. stash 면 창고 칸도 옆에 붙인다 (마을 창고 궤짝에서 F).
## sell 이면 공급함 장비 팔기 창 (가방 칸 클릭 = 팔기).
func open_inventory(stash := false, sell := false) -> void:
	if active == smith:
		GameState.notify("대장장이는 가방이 없다. 만든 장비는 입을 사람(농부 · 사냥꾼)에게 바로 간다.")
		return
	close_menu()
	active.frozen = true
	if hunt:
		hunt.set_process(false)
	inventory.open(active, stash, sell)


func close_inventory() -> void:
	if not inventory.visible:
		return
	inventory.close()
	active.frozen = false
	if hunt:
		hunt.set_process(true)
	GameState.touch()


func _on_wear_changed() -> void:
	farmer.refresh_wear()
	hunter.refresh_wear()
	if hunt:
		# 하트를 늘리는 장비를 벗으면 하트 칸이 줄어든다 (다시 입는다고 하트가 차지는 않음)
		hunt.hearts = clampi(hunt.hearts, 1, hunt.max_hearts())
	GameState.touch()


# --- 대장간 복구 · 대장장이 (2026-09-29 사용자 선택 A: 한 번에 복구 + 사람 장비 제작) ---

## 아침에 대장간 쪽에서 생긴 일 (아침 카드 한 줄, 없으면 ""). 1막 대장을 처음 잡은 다음 날 터가 드러나고,
## 고친 뒤로는 고물 더미에 고철이 다시 쌓인다.
func _forge_morning() -> String:
	if GameState.forge_state == 0 and GameState.forge_boss_down:
		show_forge_site()
		return "금사리 대장이 쓰러진 뒤, 마을 아래 풀밭에 무너진 대장간 터가 드러났다. 터에서 F."
	if GameState.forge_state >= 2:
		GameState.scrap_pile = Config.SCRAP_PER_DAY
	return ""


## 무너진 대장간 터를 마을에 놓는다. 그 자리의 들나물 · 도라지 자리는 쓰지 않는다.
func show_forge_site() -> void:
	GameState.forge_state = maxi(GameState.forge_state, 1)
	if forge == null:
		forge = _add_prop("대장간 터", preload("res://assets/props/forge_ruin.png"), Config.FORGE_RECT)
		forage.block(Config.FORGE_RECT)
	_refresh_props()


## 복구에 드는 것: [이름, 가진 것, 필요한 것]
func forge_costs() -> Array:
	return [
		["돈", GameState.money, Config.FORGE_COST_MONEY],
		["무 (수확해서 들고 있는 것)", GameState.crops, Config.FORGE_COST_CROPS],
		[Config.BOSS_MATERIAL_NAME + " (금사리 금두꺼비)", GameState.material, Config.FORGE_COST_MATERIAL],
	]


func can_restore_forge() -> bool:
	return GameState.forge_state == 1 and forge_costs().all(func(c: Array) -> bool: return c[1] >= c[2])


func forge_cost_lines() -> Array[String]:
	var out: Array[String] = []
	for c: Array in forge_costs():
		out.append("  %s  %d / %d %s" % [c[0], mini(c[1], c[2]), c[2], "✔" if c[1] >= c[2] else ""])
	out.append("다 모으면 한 번에 고친다 → 대장장이 (Tab)")
	return out


func forge_options() -> Array[StringName]:
	return [&"restore", &"close"]


func craft_options() -> Array[StringName]:
	var out: Array[StringName] = Wearables.craft_bases()
	out.append(&"close")
	return out


func forge_option_text(id: StringName) -> String:
	match id:
		&"restore":
			return "고치기" if can_restore_forge() else "고치기 (아직 모자람)"
		&"close":
			return "닫기"
	var it: Dictionary = Wearables.ITEMS[id]
	var cost: Array = Config.CRAFT_COSTS[id]
	if it.slot == &"weapon":
		return "%s (사냥꾼 무기 · %s)   고철 %d · %d원" % [it.name, Wearables.WEAPON_KIND_NAMES[it.weapon.kind], cost[0], cost[1]]
	return "%s (%s %s)   고철 %d · %d원" % [it.name, "농부" if it.who == &"farmer" else "사냥꾼", Wearables.SLOT_NAMES[it.slot], cost[0], cost[1]]


## 대장간 터 · 대장간에서 F. 터면 복구 창, 고친 대장간이면 대장장이만 제작 창.
func _forge_interact() -> void:
	if GameState.forge_state == 1:
		open_menu(&"forge")
	elif active == smith:
		open_menu(&"craft")
	else:
		GameState.notify("대장간이다. Tab으로 대장장이를 골라 모루에서 F로 장비를 만든다.")


## 한 번에 고친다 (선택창과 테스트가 함께 쓴다). 모자라면 무엇이 모자란지 알린다.
func restore_forge() -> bool:
	if GameState.forge_state != 1:
		return false
	if not can_restore_forge():
		var short: Array[String] = []
		for c: Array in forge_costs():
			if c[1] < c[2]:
				short.append("%s %d" % [String(c[0]).split(" ")[0], c[2] - c[1]])
		GameState.notify("아직 모자라다: %s." % ", ".join(short))
		return false
	GameState.money -= Config.FORGE_COST_MONEY
	GameState.crops -= Config.FORGE_COST_CROPS
	GameState.material -= Config.FORGE_COST_MATERIAL
	GameState.forge_state = 2
	forge.label = "대장간"
	forge.texture = preload("res://assets/props/forge.png")
	forge.queue_redraw()
	scrap_heap = _add_prop("고물 더미", preload("res://assets/props/scrap_pile.png"), Config.SCRAP_RECT)
	forage.block(Config.SCRAP_RECT)
	GameState.scrap_pile = Config.SCRAP_PER_DAY
	smith.visible = true
	smith.position = Farm.center_of(Config.SMITH_CELL)
	_refresh_props()
	GameState.notify("대장간을 고쳤다! 대장장이가 왔다 (Tab). 고물 더미의 고철로 모루에서 장비를 만든다. 크리처에게 고철 줍기(R)도 맡길 수 있다. 금사리 윗길 쇠다리도 이어 줘서 이제 광동리로 건너갈 수 있다.")
	return true


## 고물 더미에서 손으로 고철 하나 (농부 · 대장장이)
func pick_scrap() -> bool:
	if GameState.scrap_pile <= 0:
		GameState.notify("고물 더미가 비었다. 내일 아침 다시 쌓인다.")
		return false
	GameState.scrap_pile -= 1
	GameState.scrap += 1
	GameState.notify("고철을 하나 주웠다 (고철 %d). 크리처에게 고철 줍기(R)를 맡기면 알아서 주워 온다." % GameState.scrap)
	return true


## 대장장이가 모루에서 base 장비를 하나 만든다. 만든 장비 id (못 만들면 &"").
func craft(base: StringName) -> StringName:
	if not Config.CRAFT_COSTS.has(base):
		return &""
	var cost: Array = Config.CRAFT_COSTS[base]
	var it: Dictionary = Wearables.ITEMS[base]
	if GameState.scrap < cost[0] or GameState.money < cost[1]:
		GameState.notify("모자라다. %s: 고철 %d · %d원 (가진 고철 %d · 돈 %d원)." % [it.name, cost[0], cost[1], GameState.scrap, GameState.money])
		return &""
	var roll := Wearables.roll_crafted(_rng, base)
	var before := GameState.gear_serial
	var where := Wearables.gain_rolled(roll)
	if where == &"":
		GameState.notify("%s 가방과 창고가 모두 가득 차서 만들 수 없다." % ("농부" if it.who == &"farmer" else "사냥꾼"))
		return &""
	GameState.scrap -= cost[0]
	GameState.money -= cost[1]
	var id := StringName("gear_%d" % GameState.gear_serial)
	assert(GameState.gear_serial == before + 1)
	var owner := farmer if it.who == &"farmer" else hunter
	owner.refresh_wear()
	var place: String = {&"worn": "바로 입었다", &"bag": "가방에 넣었다", &"stash": "창고로 보냈다"}[where]
	GameState.notify("%s을(를) 만들었다! %s · %s (%s)" % [roll.name, Wearables.affix_text(roll.affixes), owner.display_name, place])
	return id


# --- 크리처 훈련 (2026-09-29 사용자 선택 A, 돈 쓸 곳 2단계) ---------------

const TRAIN_STATS: Array[StringName] = [&"radius", &"speed"]


## 훈련 선택창 항목: 크리처마다 &"train_<번호>_radius" · &"train_<번호>_speed" (다 올린 것은 빠짐), 마지막에 뒤로
func train_options() -> Array[StringName]:
	var options: Array[StringName] = []
	for i in creatures.size():
		for stat in TRAIN_STATS:
			if train_level(creatures[i], stat) < Config.TRAIN_PRICES.size():
				options.append(StringName("train_%d_%s" % [i, stat]))
	options.append(&"back")
	return options


## 항목 → [크리처, 능력]. 못 찾으면 [null, &""]
func train_from_option(id: StringName) -> Array:
	var parts := String(id).split("_")
	if parts.size() != 3 or parts[0] != "train":
		return [null, &""]
	var i := parts[1].to_int()
	return [creatures[i] if i < creatures.size() else null, StringName(parts[2])]


func train_level(s: Creature, stat: StringName) -> int:
	return s.data.radius_level if stat == &"radius" else s.data.speed_level


## 다음 단계 값. 다 올렸으면 -1
func train_price(s: Creature, stat: StringName) -> int:
	var lv := train_level(s, stat)
	return Config.TRAIN_PRICES[lv] if lv < Config.TRAIN_PRICES.size() else -1


func train_option_text(id: StringName) -> String:
	if id == &"back":
		return "뒤로"
	var pick := train_from_option(id)
	var s: Creature = pick[0]
	var stat: StringName = pick[1]
	var who := "%s %s · %s" % [s.data.element_names(), s.data.species.display_name, CreatureJobs.display_name(s.job)]
	if stat == &"radius":
		var r := s.data.work_radius()
		return "%s   범위 %d → %d (%d원)" % [who, r, r + Config.TRAIN_RADIUS_STEP, train_price(s, stat)]
	# 농사·쉬는 중은 급수 속도로 보여 준다 (훈련 배율은 모든 일에 같게 붙는다)
	var job := s.job if s.job == CreatureJobs.FORAGE else CreatureJobs.WATER
	var now := s.data.work_speed(job)
	var next := now / s.data.train_speed_mult() * (s.data.train_speed_mult() + Config.TRAIN_SPEED_STEP)
	return "%s   속도 %.2f → %.2f (%d원)" % [who, now, next, train_price(s, stat)]


## 크리처 하나의 범위(&"radius") 또는 속도(&"speed")를 한 단계 올린다. 선택창과 테스트가 함께 쓴다.
func train(s: Creature, stat: StringName) -> bool:
	if s == null or stat not in TRAIN_STATS:
		return false
	var price := train_price(s, stat)
	var stat_name := "범위" if stat == &"radius" else "속도"
	if price < 0:
		GameState.notify("%s %s 훈련은 다 끝냈다." % [s.data.species.display_name, stat_name])
		return false
	if GameState.money < price:
		GameState.notify("돈이 모자라다. %s 훈련 %d원 (가진 돈 %d원)." % [stat_name, price, GameState.money])
		return false
	GameState.money -= price
	if stat == &"radius":
		s.data.radius_level += 1
	else:
		s.data.speed_level += 1
	s.queue_redraw()
	var lv := train_level(s, stat)
	var next := train_price(s, stat)
	GameState.notify("%s %s 훈련 %d단계! -%d원. %s" % [s.data.species.display_name, stat_name, lv, price,
		("다음 단계는 %d원." % next) if next > 0 else "이 능력은 다 올렸다."])
	return true


# --- 사냥터 입구 동행 고르기 (2026-09-27 결정 A. 따라오는 동료) -----------

## 동행 선택창 항목: 크리처마다 &"companion_<번호>", 마지막에 &"solo" (혼자 가기)
func companion_options() -> Array[StringName]:
	var options: Array[StringName] = []
	for i in companion_candidates().size():
		options.append(StringName("companion_%d" % i))
	options.append(&"solo")
	return options


func companion_from_option(id: StringName) -> Creature:
	if not String(id).begins_with("companion_"):
		return null
	var list := companion_candidates()
	var i := String(id).trim_prefix("companion_").to_int()
	return list[i] if i < list.size() else null


func companion_option_text(id: StringName) -> String:
	var s := companion_from_option(id)
	if s == null:
		return "혼자 가기"
	var fight := HuntCompanion.style_name(s.data)
	return "%s %s (밭: %s · 사냥: %s)" % [s.data.element_names(), s.data.species.display_name, CreatureJobs.display_name(s.job), fight]


## 웨이포인트 선택창 항목: 켜진 구역마다 &"zone_<번호>", 마지막에 닫기
func waypoint_options() -> Array[StringName]:
	var options: Array[StringName] = []
	for z in GameState.waypoints:
		options.append(StringName("zone_%d" % z))
	options.append(&"close")
	return options


func waypoint_option_text(id: StringName) -> String:
	if id == &"close":
		return "닫기"
	var z := String(id).trim_prefix("zone_").to_int()
	if z == 0:
		return "1구역 %s부터 걸어가기" % Config.HUNT_ZONES[0].name
	var text := "%d구역 %s 웨이포인트 (%s)" % [z + 1, Config.HUNT_ZONES[z].name, Config.HUNT_ZONES[z].monster]
	if Config.HUNT_ZONES[z].has("advice"):
		text += " · " + Config.HUNT_ZONES[z].advice
	return text


func _rebuild_menu() -> void:
	var companion := menu_kind == &"companion"
	var waypoint := menu_kind == &"waypoint"
	var training := menu_kind == &"train"
	var forging := menu_kind == &"forge" or menu_kind == &"craft"
	var starting := menu_kind == &"start"
	if starting:
		_menu_options = TestStarts.ids()
	elif forging:
		_menu_options = forge_options() if menu_kind == &"forge" else craft_options()
	elif training:
		_menu_options = train_options()
	else:
		_menu_options = companion_options() if companion else (waypoint_options() if waypoint else supply_options())
	menu_index = clampi(menu_index, 0, _menu_options.size() - 1)
	var head := "사냥터 입구 · 누구랑 갈까?" if companion else ("사냥터 입구 · 어디서 시작할까?" if waypoint else "마을 공급함   가진 돈 %d원" % GameState.money)
	if training:
		head = "크리처 훈련   가진 돈 %d원" % GameState.money
	if starting:
		head = "테스트용 시작 지점 (개발용 빌드에서만)"
	if menu_kind == &"forge":
		head = "무너진 대장간 터"
	elif menu_kind == &"craft":
		head = "대장간 모루   고철 %d · 돈 %d원" % [GameState.scrap, GameState.money]
	var lines: Array[String] = [head]
	# 항목이 많으면 고른 줄 둘레만 보인다 (화면 밖으로 나가지 않게)
	var first := clampi(menu_index - MENU_VISIBLE_ROWS / 2, 0, maxi(0, _menu_options.size() - MENU_VISIBLE_ROWS))
	var last := mini(_menu_options.size(), first + MENU_VISIBLE_ROWS)
	if first > 0:
		lines.append("   ▲")
	for i in range(first, last):
		var o := _menu_options[i]
		var text := ""
		if starting:
			text = TestStarts.option_text(o)
		elif training:
			text = train_option_text(o)
		elif forging:
			text = forge_option_text(o)
		else:
			text = companion_option_text(o) if companion else (waypoint_option_text(o) if waypoint else supply_option_text(o))
		lines.append(("▶ " if i == menu_index else "   ") + text)
	if last < _menu_options.size():
		lines.append("   ▼")
	if training:
		lines.append("크리처마다 따로 · 단계마다 값 두 배 (%s원)" % " → ".join(Config.TRAIN_PRICES.map(func(p: int) -> String: return str(p))))
	if menu_kind == &"forge":
		lines.append_array(forge_cost_lines())
	elif menu_kind == &"craft":
		lines.append("만들 때마다 옵션 1~3개가 무작위로 붙는다 (디아블로2 제작처럼)")
		lines.append("만든 장비는 칸이 비었으면 바로 입고, 아니면 그 사람 가방으로")
	if companion:
		lines.append("데려간 크리처는 돌아오면 제자리에서 다시 일한다")
	if waypoint:
		lines.append("대장을 쓰러뜨리면 위쪽 길로 더 깊이 갈 수 있다")
	if starting:
		lines.append("W/S 고르기 · F 정하기 · 숫자키 바로 · Esc 처음부터")
		lines.append("그 시점쯤의 상태를 새로 채운다 (저장이 아님)")
	_menu_text.text = "\n".join(lines)
	_menu.size = _menu_text.get_minimum_size() + Vector2(16, 10)
	# 공급함(또는 사냥터 입구) 옆에 띄우되 화면 밖으로 나가지 않게
	var at := (hunt_gate.position + Vector2(-200, 8)) if companion or waypoint else supply_box.position + Vector2(36, -80)
	if forging:
		at = forge.position + Vector2(40, -150)
	if starting:
		at = (Vector2(640, 360) - _menu.size) / 2
	_menu.position = at.clamp(Vector2(4, 32), Vector2(636, 324) - _menu.size)
	_menu.visible = menu_open


func change_creature_job() -> void:
	var s := _nearest_creature()
	if s == null or active != farmer:
		GameState.notify("농부로 크리처 가까이에서 R.")
		return
	s.next_job()
	GameState.notify(s.describe())


## 현관에서 잔다: 밤으로 어두워지고(1초), 하루를 넘긴 뒤 아침 카드를 띄운다. F로 일어난다.
func go_to_sleep() -> void:
	if sleeping:
		return
	sleeping = true
	active.active = false
	GameState.notify("집에 들어가 잠자리에 들었다.")
	var tween := create_tween()
	tween.tween_property(_night, "color:a", Config.NIGHT_ALPHA, Config.SLEEP_FADE_TIME)
	await tween.finished
	var lines := next_day()
	show_morning_card(lines)


## 아침 카드를 띄운다. 밤사이 일이 많으면 카드를 늘려 글이 카드 밖으로 넘치지 않게 한다.
func show_morning_card(lines: Array[String]) -> void:
	_morning_text.text = "%d일째 아침\n\n%s\n\nF 일어나기" % [GameState.day, "\n".join(lines)]
	var font := _morning_text.get_theme_font("font")
	var font_size := _morning_text.get_theme_font_size("font_size")
	var lines_n := roundi(font.get_multiline_string_size(_morning_text.text, HORIZONTAL_ALIGNMENT_CENTER, MORNING_CARD_SIZE.x - 24, font_size).y / font.get_height(font_size))
	var h := lines_n * (font.get_height(font_size) + _morning_text.get_theme_constant("line_spacing")) + 28
	_morning_card.size.y = clampf(h, MORNING_CARD_SIZE.y, 340)
	_morning_card.position = (Vector2(640, 360) - _morning_card.size) / 2
	_morning_text.size = _morning_card.size - Vector2(24, 20)
	_morning_card.visible = true


func wake_up() -> void:
	if not sleeping or not _morning_card.visible:
		return
	_morning_card.visible = false
	var tween := create_tween()
	tween.tween_property(_night, "color:a", 0.0, Config.WAKE_FADE_TIME)
	await tween.finished
	sleeping = false
	active.active = true
	GameState.touch()


func near_door() -> bool:
	return active.position.distance_to(Farm.center_of(DOOR_CELL)) <= Config.PROP_INTERACT_DISTANCE


## 하루를 넘기고 밤사이 일어난 일을 줄마다 돌려준다 (아침 카드에 쓴다).
func next_day() -> Array[String]:
	GameState.day += 1
	GameState.minutes = float(Config.DAY_START_MINUTE)
	_update_dusk()
	var lines: Array[String] = []
	if GameState.displayed_crops > 0:
		var earned := GameState.displayed_crops * Config.CROP_PRICE
		GameState.money += earned
		lines.append("공급함의 무 %d개가 팔렸다. 돈통에 +%d원" % [GameState.displayed_crops, earned])
		GameState.displayed_crops = 0
	if GameState.displayed_herbs > 0:
		var earned := GameState.displayed_herbs * Config.HERB_PRICE
		GameState.money += earned
		lines.append("공급함의 들나물 %d포기가 팔렸다. 돈통에 +%d원" % [GameState.displayed_herbs, earned])
		GameState.displayed_herbs = 0
	if GameState.displayed_roots > 0:
		var earned := GameState.displayed_roots * Config.ROOT_PRICE
		GameState.money += earned
		lines.append("공급함의 %s %d뿌리가 팔렸다. 돈통에 +%d원" % [Config.ROOT_NAME, GameState.displayed_roots, earned])
		GameState.displayed_roots = 0
	var forge_line := _forge_morning()
	if forge_line != "":
		lines.append(forge_line)
	forage.sprout(_rng)
	var herb_line := "밭 밖 풀밭에 들나물 %d포기가 돋았다." % forage.herbs.size()
	if forage.bonus_today > 0:
		herb_line += " (물 준 풀밭 +%d)" % forage.bonus_today
	lines.append(herb_line)
	var boosted := boost_growth()
	var grown := farm.advance_day()
	if boosted > 0:
		lines.append("아기 나무 정령이 밭을 돌봐 작물 %d개가 하루 더 자랐다." % boosted)
	if grown > 0:
		lines.append("밤사이 작물 %d개가 자랐다." % grown)
	var ripe := farm.ripe_count()
	if ripe > 0:
		lines.append("수확할 수 있는 작물 %d개." % ripe)
	var gold := gather_gold_dust()
	if gold > 0:
		lines.append("금두꺼비가 밭에서 사금을 주웠다. 돈통에 +%d원" % gold)
	var grain_money := GameState.money
	var seeds := gather_seeds()
	grain_money = GameState.money - grain_money
	if seeds > 0:
		lines.append("아기 참새가 벌판에서 낟알을 물어 왔다. 씨앗 +%d" % seeds)
	if grain_money > 0:
		lines.append("씨앗이 넉넉해서 남는 낟알은 공급함에서 팔렸다. +%d원" % grain_money)
	if GameState.hunter_unlocked and GameState.hunts_today > 0:
		lines.append("사냥꾼이 다시 사냥을 나갈 수 있다.")
	GameState.hunts_today = 0
	if incubating_days > 0:
		incubating_days -= 1
	var text := "%d일째 아침." % GameState.day
	if incubating_days == 0:
		incubating_days = -1
		var s := _hatch(incubating_species, HATCH_CELL)
		incubating_species = null
		lines.append("알이 부화했다! " + s.describe())
		text += " 알이 부화했다! " + s.describe() + " F로 들어서 밭 옆에 놓아 주자."
	elif incubating_days > 0:
		lines.append("알 부화까지 %d일." % incubating_days)
	if lines.is_empty():
		lines.append("조용한 밤이었다.")
	_refresh_props()
	GameState.notify(text)
	return lines


## 사금 줍기 (아기 금두꺼비, 2026-09-28): 밭에서 일을 맡은 개체마다 종의 daily_gold 범위만큼 돈을 줍는다.
## 쉬는 중이면 줍지 않는다. 주운 돈을 돌려준다.
func gather_gold_dust() -> int:
	var total := 0
	for c in creatures:
		var r := c.data.species.daily_gold
		if r.y > 0 and c.job != CreatureJobs.REST:
			total += _rng.randi_range(r.x, r.y)
	GameState.money += total
	return total


## 키우기 (아기 나무 정령, 2026-09-29 도마리): 농사를 맡은 개체마다 범위 안 밭의 작물을 가끔 하루 더 키운다.
func boost_growth() -> int:
	var total := 0
	for c in creatures:
		var ch := c.data.species.grow_chance
		if ch > 0.0 and c.job == CreatureJobs.FARM:
			total += farm.boost_growth(c.home, c.data.work_radius(), ch, _rng)
	return total


## 낟알 줍기 (아기 참새, 2026-09-29 광동리 B): 일을 맡은 개체마다 종의 daily_seeds 범위만큼 씨앗을 물어 온다. 쉬는 중이면 없음.
## 씨앗 넘침 (2026-09-29 4구역 스레드, Claude 기본값): 씨앗이 GRAIN_SEED_CAP 개를 넘으면 넘는 낟알은 씨앗 대신
## 공급함에서 밤에 팔린다 (개당 GRAIN_PRICE원). 돌려주는 값은 씨앗으로 들어온 수.
func gather_seeds() -> int:
	var total := 0
	for c in creatures:
		var r := c.data.species.daily_seeds
		if r.y > 0 and c.job != CreatureJobs.REST:
			total += _rng.randi_range(r.x, r.y)
	var kept := clampi(Config.GRAIN_SEED_CAP - GameState.seeds, 0, total)
	GameState.seeds += kept
	GameState.money += (total - kept) * Config.GRAIN_PRICE
	return kept


## element: 속성을 정해서 낳는다 (테스트 시작 지점). null 이면 부화 때 굴린 대로.
func _hatch(species: CreatureSpecies, at_cell: Vector2i, element: CreatureElement = null) -> Creature:
	var data := CreatureData.hatch(species, _rng)
	var s := Creature.new()
	if creatures.is_empty():
		# 첫 크리처는 급수 담당, 최저 능력치 보장 (2026-09-27 결정)
		data.guarantee_minimum(Config.FIRST_CREATURE_MIN_WORK_SPEED, Config.FIRST_CREATURE_MIN_RADIUS)
		s.job = CreatureCatalog.FIRST_JOB
		data.set_element(CreatureCatalog.FIRST_ELEMENT)
	elif GameState.hunter_knife:
		# 튼튼한 사냥칼 (2026-09-27 후보 A 첫 조각): 좋은 알을 골라 오므로 첫 크리처만큼 바닥 보장
		data.guarantee_minimum(Config.FIRST_CREATURE_MIN_WORK_SPEED, Config.FIRST_CREATURE_MIN_RADIUS)
	if element:
		data.set_element(element)
	add_child(s)
	s.forage = forage
	s.setup(farm, data, at_cell)
	creatures.append(s)
	return s


# --- 보조 ------------------------------------------------------------------

func _near(prop: Prop) -> bool:
	return prop.is_near(active.position, Config.PROP_INTERACT_DISTANCE)


## 창고 궤짝은 공급함 바로 옆이라 둘 다 닿으면 더 가까운 쪽을 쓴다
func _near_stash() -> bool:
	return _near(stash_box) and stash_box.distance_to(active.position) < supply_box.distance_to(active.position)


func _nearest_creature() -> Creature:
	var best: Creature = null
	var best_d := Config.INTERACT_DISTANCE
	for s in creatures:
		var d := farmer.position.distance_to(s.position)
		if d <= best_d:
			best_d = d
			best = s
	return best


func _carried_creature() -> Creature:
	for s in creatures:
		if s.carried_by != null:
			return s
	return null


func _refresh_props() -> void:
	incubator.set_badge("부화 중 (%d일)" % incubating_days if incubating_days >= 0 else "")
	var shelf: Array[String] = []
	if not GameState.village_eggs.is_empty():
		shelf.append("알 %d" % GameState.village_eggs.size())
	if GameState.displayed_crops > 0:
		shelf.append("무 %d 진열" % GameState.displayed_crops)
	if GameState.displayed_herbs > 0:
		shelf.append("나물 %d" % GameState.displayed_herbs)
	if GameState.displayed_roots > 0:
		shelf.append("%s %d" % [Config.ROOT_NAME, GameState.displayed_roots])
	supply_box.set_badge(" · ".join(shelf))
	if forge:
		forge.set_badge("%s %d/%d" % [Config.BOSS_MATERIAL_NAME, GameState.material, Config.FORGE_COST_MATERIAL] if GameState.forge_state == 1 else ("고철 %d" % GameState.scrap))
	if scrap_heap:
		scrap_heap.set_badge("고철 %d" % GameState.scrap_pile if GameState.scrap_pile > 0 else "비었음")


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := ColorRect.new()
	panel.color = Color(0, 0, 0, 0.45)
	panel.size = Vector2(640, 28)
	layer.add_child(panel)
	_status = Label.new()
	_status.position = Vector2(6, 2)
	_status.add_theme_font_size_override("font_size", 10)
	layer.add_child(_status)
	var bottom := ColorRect.new()
	bottom.color = Color(0, 0, 0, 0.45)
	bottom.position = Vector2(0, 328)
	bottom.size = Vector2(640, 32)
	layer.add_child(bottom)
	_message = Label.new()
	_message.position = Vector2(6, 330)
	_message.add_theme_font_size_override("font_size", 10)
	layer.add_child(_message)
	var help := Label.new()
	help.position = Vector2(6, 345)
	help.add_theme_font_size_override("font_size", 9)
	help.modulate = Color(1, 1, 1, 0.7)
	help.text = "이동 WASD · 도구 Space (사냥터: 클릭) · 도구 변경 Q/E · 상호작용 F (공급함: W/S 고르기) · 크리처 일 R · 가방 I · 캐릭터 전환 Tab · 잠자기 집 현관 F"
	layer.add_child(help)
	# 저녁·밤 색 (하루 시계). 아침엔 투명.
	_dusk = ColorRect.new()
	_dusk.color = Color(0.1, 0.08, 0.3, 0.0)
	_dusk.size = Vector2(640, 360)
	_dusk.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_dusk)
	layer.move_child(_dusk, 0)
	# 잠잘 때 화면 전체를 덮는 밤 색. 평소에는 투명.
	_night = ColorRect.new()
	_night.color = Color(0.05, 0.06, 0.18, 0.0)
	_night.size = Vector2(640, 360)
	_night.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_night)
	_morning_card = ColorRect.new()
	(_morning_card as ColorRect).color = Color(0.99, 0.95, 0.85)
	_morning_card.size = MORNING_CARD_SIZE
	_morning_card.position = (Vector2(640, 360) - _morning_card.size) / 2
	_morning_card.visible = false
	layer.add_child(_morning_card)
	_morning_text = Label.new()
	_morning_text.position = Vector2(12, 10)
	_morning_text.size = _morning_card.size - Vector2(24, 20)
	_morning_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_morning_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_morning_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_morning_text.add_theme_font_size_override("font_size", 10)
	_morning_text.add_theme_color_override("font_color", Color(0.3, 0.2, 0.15))
	_morning_card.add_child(_morning_text)
	_menu = ColorRect.new()
	_menu.color = Color(0.99, 0.95, 0.85)
	_menu.visible = false
	layer.add_child(_menu)
	_menu_text = Label.new()
	_menu_text.position = Vector2(8, 5)
	_menu_text.add_theme_font_size_override("font_size", 10)
	_menu_text.add_theme_color_override("font_color", Color(0.3, 0.2, 0.15))
	_menu.add_child(_menu_text)
	inventory = InventoryUI.new()
	inventory.wear_changed.connect(_on_wear_changed)
	layer.add_child(inventory)
	_refresh_hud()


func _refresh_hud() -> void:
	if _status == null:
		return
	var tool_text: String = tool_name(TOOLS[tool_index]) if active == farmer else ("튼튼한 사냥칼" if GameState.hunter_knife else "사냥칼")
	if active == hunter and GameState.worn[&"hunter"].has(&"weapon"):
		tool_text = Wearables.item(GameState.worn[&"hunter"][&"weapon"]).name
	if active == smith:
		tool_text = "망치"
	if hunt:
		var buddy := hunt.companion.display_name() if hunt.companion else "혼자"
		_status.text = "%d일째 %s | %s | 도구: %s | 동행: %s | 남은 몬스터 %d | 주운 알 %d | 돈 %d원 · 잡템 %d" % [GameState.day, GameState.clock_text(GameState.minutes), Config.HUNT_ZONES[hunt.zone].name, tool_text, buddy, hunt.slimes.size(), hunt.picked.size(), GameState.money, GameState.junk]
		return
	_status.text = "%d일째 %s | %s | 도구: %s | 돈 %d원 | 씨앗 %d  작물 %d  나물 %d | 알: 농부 %d · 사냥꾼 %d · 공급함 %d | 크리처 %d" % [
		GameState.day, GameState.clock_text(GameState.minutes), active.display_name, tool_text, GameState.money, GameState.seeds, GameState.crops, GameState.herbs,
		GameState.farmer_eggs.size(), GameState.hunter_eggs.size(), GameState.village_eggs.size(), creatures.size(),
	]
	# 윗줄이 넘치지 않게 대장간 단계에 필요한 것만
	if GameState.forge_state >= 2:
		_status.text += " | 고철 %d" % GameState.scrap
	elif GameState.material > 0:
		_status.text += " | %s %d/%d" % [Config.BOSS_MATERIAL_NAME, GameState.material, Config.FORGE_COST_MATERIAL]
