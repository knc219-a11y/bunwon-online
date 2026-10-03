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
## 마을 오브젝트 · 배경 자리는 Config "마을 배치" 에 모았다 (2026-10-01 마을 넓히기). 테스트가 main.X 로도 읽는다.
const INCUBATOR_RECT := Config.INCUBATOR_RECT
const SUPPLY_RECT := Config.SUPPLY_RECT
const HUNT_GATE_RECT := Config.HUNT_GATE_RECT
const STASH_RECT := Config.STASH_RECT
const HOUSE_RECT := Config.HOUSE_RECT
const DANGSAN_RECT := Config.DANGSAN_RECT
const PERSIMMON_CELLS := Config.PERSIMMON_CELLS
## 막는 범위 (그림 아래쪽 가운데 기준, px). 2026-09-27 결정 C: 집은 벽 두 줄, 나무는 밑동만 막고
## 지붕·나뭇잎 뒤로는 지나간다. 뒤로 가면 가리는 그림이 반투명해진다.
const HOUSE_BLOCK := Rect2(-60, -48, 120, 48)
const PERSIMMON_BLOCK := Rect2(-8, -12, 16, 12)
const DANGSAN_BLOCK := Rect2(-20, -18, 40, 18)
const HATCH_CELL := Config.HATCH_CELL
const DOOR_CELL := Config.DOOR_CELL
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
## 연금술사 (2026-09-29 약방 복구): 넷째 캐릭터. 약방을 고치면 나타나고 Tab 으로 바꾼다.
var alchemist: Character
## 약방 (터 → 고친 약방)과 도라지밭. 나타나기 전에는 null.
var yak: Prop
var herb_bed: Prop
## 목축인 (2026-09-30 축사 닭장): 다섯째 캐릭터. 축사를 고치면 나타나고 Tab 으로 바꾼다.
var rancher: Character
## 축사 (터 → 고친 축사). 나타나기 전에는 null. 닭장 앞 암탉 · 병아리 그림.
var barn: Prop
## 뱃사공 (2026-10-02 나루터): 여섯째 캐릭터. 나루터를 고치면 나타나고 Tab 으로 바꾼다.
var ferryman: Character
## 나루터 (터 → 나룻집). 나타나기 전에는 null. 잔교 · 나룻배 · 통발은 물가 그림(_lake)이 함께 그린다.
var naru: Prop
var _lake: Node2D
var _flock: Node2D
var incubator: Prop
var supply_box: Prop
var hunt_gate: Prop
var stash_box: Prop
var house: Prop
var props: Array[Prop] = []
var creatures: Array[Creature] = []
## 주민에게 입양 보낸 크리처 (Expedition.spawn_adopted). 일은 안 하고 주민 곁에 있다. creatures 에는 없다.
var adoptees: Array[Creature] = []
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
## 사냥꾼 스킬 창 (2026-10-02, T)
var skill_panel: SkillPanel
## 조련 "둘이 함께": 두 번째로 데려간 크리처
var _companion_source2: Creature
## 사냥터 (2026-09-27 결정 A). 사냥꾼이 들어가 있는 동안만 있다.
var hunt: HuntGround
## 사냥터에 있는 동안 숨기는 마을 쪽 노드
var _village_nodes: Array[Node2D] = []
## 사냥에 데려간 농장 크리처 (돌아오면 제자리로). 없으면 혼자.
var _companion_source: Creature
## 마지막으로 사냥에 데려간 크리처. 원정 · 입양에 고르지 않는다 (아끼는 동행이 떠나지 않게, Expedition.idle)
var last_companion: Creature

## 지금 쓰는 저장 슬롯 (2026-09-30 사용자 선택 C). -1 = 저장하지 않음 (테스트 장면, 개발 중 처음 화면 없이 켠 때)
var save_slot := -1
## 슬롯 지우기: 한 번 고르면 여기에 적어 두고, 같은 슬롯을 한 번 더 고르면 지운다
var _delete_armed := -1

var _rng := RandomNumberGenerator.new()
var _status: Label
## 위 줄 알약 (그래픽 시범 2026-09-30). _status 글줄은 숨긴 채 같은 내용을 유지한다.
var _hud_bar: HudBar
## 하루 빛 · 불빛 · 구름 그림자 · 날리는 잎 (그래픽 시범 C)
var ambience: Ambience
var _message: Label
## 마을 카메라 (2026-10-01 마을 넓히기): 맵이 화면보다 크면 조작 중인 캐릭터를 따라간다. 사냥터에서는 사냥터 카메라가 켜진다.
var camera: Camera2D


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
	supply_box = _add_prop("공급함", preload("res://assets/props/supply_box.png"), SUPPLY_RECT)
	hunt_gate = _add_prop("사냥터 입구", preload("res://assets/props/hunt_gate.png"), HUNT_GATE_RECT)
	stash_box = _add_prop("창고", preload("res://assets/props/stash.png"), STASH_RECT)
	_build_lake()

	ambience = Ambience.new()
	ambience.area = world_size()
	add_child(ambience)
	var warm := Color(1.0, 0.78, 0.48)
	ambience.add_light(house.position + Vector2(-32, -44), 46, warm)
	ambience.add_light(house.position + Vector2(30, -44), 46, warm)
	ambience.add_light(incubator.position + Vector2(10, -40), 34, Color(1.0, 0.55, 0.4))
	ambience.add_light(supply_box.position + Vector2(0, -20), 30, warm)

	farmer = _add_character("농부", preload("res://assets/characters/player.png"), Config.FARMER_START, &"farmer")
	hunter = _add_character("사냥꾼", preload("res://assets/characters/hunter.png"), Config.HUNTER_START, &"hunter")
	smith = _add_character("대장장이", preload("res://assets/characters/smith.png"), Config.SMITH_CELL, &"smith")
	smith.visible = false
	alchemist = _add_character("연금술사", preload("res://assets/characters/alchemist.png"), Config.ALCHEMIST_CELL, &"alchemist")
	alchemist.visible = false
	rancher = _add_character("목축인", preload("res://assets/characters/rancher.png"), Config.RANCHER_CELL, &"rancher")
	rancher.visible = false
	ferryman = _add_character("뱃사공", preload("res://assets/characters/ferryman.png"), Config.FERRYMAN_CELL, &"ferryman")
	ferryman.visible = false
	camera = Camera2D.new()
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(world_size().x)
	camera.limit_bottom = int(world_size().y)
	add_child(camera)
	camera.make_current()
	_set_active(farmer)
	follow_camera()

	_build_hud()
	GameState.changed.connect(_refresh_hud)
	# 채집 크리처가 진열하면 공급함 표시도 바뀐다
	GameState.changed.connect(_refresh_props)
	GameState.message.connect(func(t: String) -> void: _message.text = t)
	_refresh_props()
	GameState.notify("농부로 밭을 가꿔 보자. 마을 공급함에 알이 하나 있다. 풀밭의 들나물은 F로 캔다.")
	# 처음 화면 (2026-09-30 저장 슬롯): 게임으로 켰을 때만 (테스트 장면 안에서는 안 뜸).
	# 빈 슬롯에서 새 게임을 고르면 개발용 빌드에서는 테스트용 시작 지점 창이 이어서 뜬다.
	if get_parent() == get_tree().root:
		open_menu(&"title")


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
	farm.deco_skip.append(rect)
	farm.queue_redraw()
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


## 마을 맵 크기 (px). 화면보다 좁으면 화면만큼 (남는 곳도 풀밭으로 그린다).
static func world_size() -> Vector2:
	return Vector2(Config.MAP_SIZE * Config.TILE).max(Vector2(640, 360))


## 월드 px → 화면 px (CanvasLayer 위 창을 오브젝트 옆에 띄울 때)
func to_screen(world: Vector2) -> Vector2:
	if camera == null or hunt != null:
		return world
	return world - (view_center() - Vector2(320, 180))


## 마을 화면 가운데 (월드 px): 조작 중인 캐릭터, 맵 가장자리에서는 맵 안쪽으로 멈춘 자리
func view_center() -> Vector2:
	var half := Vector2(320, 180)
	return active.position.round().clamp(half, world_size() - half)


## 마을 카메라를 조작 중인 캐릭터에게 맞춘다 (가장자리에서는 맵 밖이 안 보이게 멈춘다)
func follow_camera() -> void:
	if camera and active and hunt == null:
		camera.position = active.position.round()


func _process(delta: float) -> void:
	if hunt == null:
		follow_camera()
		update_fading()
		Creature.focus = active.position
	if clock_running and not sleeping and not menu_open and not inventory.visible and not skill_panel.visible:
		advance_clock(delta * Config.CLOCK_MINUTES_PER_SECOND)
	Sound.bgm(wanted_bgm())
	# 사냥터: 왼쪽 클릭을 꾹 누르고 있으면 계속 공격한다 (2026-10-02 손맛, 쿨이 돌 때마다 한 번)
	if hunt and HuntGround.feel and not menu_open and not inventory.visible and not skill_panel.visible and Input.is_action_pressed("attack"):
		hunt.swing(get_global_mouse_position() - (hunter.feet() + Vector2(0, -12)))


## 지금 틀 배경음: 사냥터 · 마을 밤(저녁 7시부터) · 마을 낮
func wanted_bgm() -> StringName:
	if hunt:
		return &"hunt"
	return &"village_night" if GameState.minutes >= Config.NIGHT_MUSIC_MINUTE else &"village_day"


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
		for c: Character in [farmer, hunter, smith, alchemist, rancher, ferryman]:
			if not c.visible:
				continue
			hidden = hidden or (c.sort_y() < p.sort_y() and pic.intersects(Rect2(c.position + Vector2(-8, -30), Vector2(16, 40))))
		for s in creatures:
			hidden = hidden or (s.visible and s.carried_by == null and s.sort_y() < p.sort_y() and pic.intersects(Rect2(s.position + Vector2(-8, -10), Vector2(16, 18))))
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
	if skill_panel.visible:
		if event.is_action_pressed("skills") or event.is_action_pressed("menu_close"):
			close_skills()
		else:
			skill_panel.handle_key(event)
		return
	if event.is_action_pressed("skills") and not menu_open:
		open_skills()
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
			if menu_kind == &"delete":
				open_menu(&"title")
			elif menu_kind != &"title":
				close_menu()
		return
	# Esc: 멈춤 메뉴 (계속하기 · 저장하고 나가기). 사냥터 안에서도 된다.
	if event.is_action_pressed("menu_close"):
		open_menu(&"pause")
		return
	if hunt:
		if event.is_action_pressed("attack"):
			hunt.swing(get_global_mouse_position() - (hunter.feet() + Vector2(0, -12)))
		elif event.is_action_pressed("dash") and HuntGround.feel:
			# 구르기 (Space · Shift): 걷는 쪽으로, 서 있으면 바라보는 쪽으로
			hunt.dash(Input.get_vector("move_left", "move_right", "move_up", "move_down"))
		elif event.is_action_pressed("use_tool"):
			hunt.swing()
		elif event.is_action_pressed("use_potion"):
			hunt.drink_potion()
		elif event.is_action_pressed("skill_right"):
			hunt.skill_right(get_global_mouse_position())
		elif event.is_action_pressed("creature_job"):
			# R: 조련 돌격 명령 (마우스 가까운 몬스터에)
			if not hunt.order_charge(get_global_mouse_position()) and HunterSkills.rank(&"charge_order") <= 0:
				GameState.notify("돌격 명령은 T 스킬 창 조련 트리 (Lv 12) 에서 찍는다.")
		elif event.is_action_pressed("tool_next") or event.is_action_pressed("tool_prev"):
			# Q/E: 왼클릭 공격 방식 바꾸기 (찍은 스킬 중)
			var kind: StringName = Wearables.weapon().kind
			if HunterSkills.modes_for(kind).size() <= 1:
				GameState.notify("바꿀 공격 스킬이 없다. T 스킬 창에서 찍자.")
			else:
				var m := HunterSkills.cycle_mode(kind, 1 if event.is_action_pressed("tool_next") else -1)
				GameState.notify("왼클릭: %s" % HunterSkills.skill_name(m))
		elif event.is_action_pressed("interact"):
			interact()
		elif event.is_action_pressed("switch_character"):
			GameState.notify("사냥 중에는 캐릭터를 바꿀 수 없다. 아래 입구에서 F로 돌아가자.")
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
	if GameState.yak_state >= 2:
		order.append(alchemist)
	if GameState.barn_state >= 2:
		order.append(rancher)
	if GameState.naru_state >= 2:
		order.append(ferryman)
	_set_active(order[(order.find(active) + 1) % order.size()])
	if active == smith:
		GameState.notify("대장장이로 전환했다. 대장간 모루에서 F로 장비를 만든다.")
	elif active == alchemist:
		GameState.notify("연금술사로 전환했다. 약방에서 F로 물약 · 크리처 보약을 만든다.")
	elif active == rancher:
		GameState.notify("목축인으로 전환했다. 축사에서 F로 달걀 꺼내기 · 모이 주기 · 사냥 도시락 싸기.")
	elif active == ferryman:
		GameState.notify("뱃사공으로 전환했다. 나루터에서 F로 통발 놓기 · 물고기 꺼내기 · 매운탕 끓이기.")
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
	if done > 0:
		match work:
			Farm.Work.TILL:
				Sound.sfx(&"hoe")
			Farm.Work.SOW:
				Sound.sfx(&"hoe", -8.0, 1.5)
			Farm.Work.WATER:
				Sound.sfx(&"water")
			Farm.Work.HARVEST:
				Sound.sfx(&"harvest")
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
	elif yak and _near(yak) and _carried_creature() == null:
		_yak_interact()
	elif barn and _near(barn) and _carried_creature() == null and active != hunter:
		_barn_interact()
	elif naru and _near(naru) and _carried_creature() == null and active != hunter:
		open_menu(&"naru" if GameState.naru_state == 1 else &"dock")
	elif scrap_heap and _near(scrap_heap) and _carried_creature() == null and active != hunter:
		pick_scrap()
	elif herb_bed and _near(herb_bed) and _carried_creature() == null and active != hunter:
		pick_herb_bed()
	elif active == farmer:
		_farmer_interact()
	elif active == hunter:
		_hunter_interact()
	elif active == rancher:
		GameState.notify("목축인은 축사에서 F로 달걀 꺼내기 · 모이 주기 · 사냥 도시락 싸기를 한다.")
	elif active == ferryman:
		GameState.notify("뱃사공은 나루터에서 F로 통발 놓기 · 물고기 꺼내기 · 매운탕 끓이기를 한다.")
	elif active == alchemist:
		GameState.notify("연금술사는 약방에서 F로 물약 · 크리처 보약을 만든다. 도라지는 도라지밭에서 F로 캐거나 크리처에게 맡긴다.")
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
	elif _near(hunt_gate):
		# 크리처 원정 (2026-10-01 사용자 선택 B): 농부가 사냥터 입구에서 원정대를 보내고 불러들인다
		if Expedition.zones().is_empty():
			GameState.notify("대장을 한 번이라도 쓰러뜨린 구역이 있어야 크리처 원정대를 보낼 수 있다.")
		else:
			open_menu(&"expedition")
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
		# 약방을 고친 뒤로는 잡템을 JUNK_KEEP 개까지 연금술사 재료로 남기고 나머지만 판다
		var keep := Config.JUNK_KEEP if GameState.yak_state >= 2 else 0
		var sell := maxi(GameState.junk - keep, 0)
		if GameState.hunter_eggs.is_empty() and sell <= 0:
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
		if sell > 0:
			# 사냥터 잡템(슬라임 젤리)은 공급함에 두면 바로 값이 나온다 (약방을 고치기 전엔 제작 소재가 아님)
			var earned := sell * Config.JUNK_PRICE
			parts.append("사냥 잡템 (젤리 · 껍데기 · 깃털 · 옹이 · 불씨) %d개를 팔았다. +%d원%s" % [sell, earned, (" (약방 재료로 %d개 남김)" % keep) if keep > 0 else ""])
			GameState.money += earned
			GameState.junk -= sell
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
		if s.carried_by == null and s.expedition_zone < 0:
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
	if hunt.boss_spawned:
		GameState.notify(hunt.boss_waiting_text())
	# 연금술사 물약 (2026-09-29): 힘 · 빠르기 물약은 사냥에 들어갈 때 하나씩 마신다
	var drank: Array[String] = []
	if GameState.strength > 0:
		GameState.strength -= 1
		hunt.strong = true
		drank.append("힘 물약")
	if GameState.speed > 0:
		GameState.speed -= 1
		hunt.quick = true
		drank.append("빠르기 물약")
	# 목축인 사냥 도시락 (2026-09-30 축사 닭장): 들어갈 때 하나 먹고 그 사냥 동안 최대 체력 +LUNCH_HP
	if GameState.lunches > 0:
		GameState.lunches -= 1
		hunt.eat_lunch()
		drank.append("사냥 도시락")
	# 뱃사공 매운탕 (2026-10-02 나루터): 들어갈 때 하나 먹고 그 사냥 동안 하트 +1 · 경험치 +50%
	if GameState.stews > 0:
		GameState.stews -= 1
		hunt.eat_stew()
		drank.append("매운탕")
	hunt.knocked_out.connect(leave_hunt)
	var drank_text := (" %s을(를) 먹었다." % " · ".join(drank)) if not drank.is_empty() else ""
	if companion:
		_companion_source = companion
		last_companion = companion
		companion.process_mode = Node.PROCESS_MODE_DISABLED
		var c := hunt.add_companion(companion)
		# 조련 "둘이 함께" (2026-10-02): 두 번째 동행은 훈련이 가장 많이 된 다른 크리처를 알아서 데려간다
		if HunterSkills.rank(&"two_together") > 0:
			var best: Creature = null
			for o in companion_candidates():
				if o != companion and (best == null or o.data.radius_level + o.data.speed_level > best.data.radius_level + best.data.speed_level):
					best = o
			if best:
				_companion_source2 = best
				best.process_mode = Node.PROCESS_MODE_DISABLED
				var c2 := hunt.add_companion(best)
				drank_text += " %s도 함께 왔다 (둘이 함께)." % c2.display_name()
		GameState.notify("%s과(와) 사냥터에 들어왔다. 클릭(꾹 누르면 연속 베기)으로 싸우고 Space로 구른다. %s도 알아서 돕는다!%s" % [c.display_name(), c.display_name(), drank_text])
		return true
	if zone > 0:
		GameState.notify("%s 웨이포인트에서 사냥을 시작했다. 클릭(꾹 누르면 연속 베기) · Space 구르기!" % Config.HUNT_ZONES[zone].name)
	else:
		GameState.notify("사냥터에 들어왔다. 클릭(꾹 누르면 연속 베기)으로 휘두르고 Space로 구른다. 야생 슬라임을 쓰러뜨리자!")
	return true


## 마을로 돌아온다 (아래 입구 F, 또는 하트가 다 떨어져 쓰러졌을 때). 주운 알은 그대로 가진다.
func leave_hunt() -> void:
	if hunt == null:
		return
	var knocked := hunt.knocked
	var eggs := hunt.collect_all()
	GameState.hunter_eggs.append_array(eggs)
	hunter.dashing = false
	hunt.queue_free()
	hunt = null
	# 금가루에 느려진 채로 마을에 돌아오지 않게
	hunter.slow_mult = 1.0
	for n in _village_nodes:
		n.visible = true
	_village_nodes.clear()
	camera.make_current()
	if _companion_source:
		# 데려간 크리처는 원래 자리에서 원래 일을 다시 한다
		_companion_source.process_mode = Node.PROCESS_MODE_INHERIT
		_companion_source = null
	if _companion_source2:
		_companion_source2.process_mode = Node.PROCESS_MODE_INHERIT
		_companion_source2 = null
	hunter.farm = farm
	hunter.walk_area = Rect2()
	hunter.terrain = null
	hunter.show_facing_cell = true
	hunter.position = Farm.center_of(HUNT_GATE_RECT.position + Vector2i(1, HUNT_GATE_RECT.size.y))
	hunter.facing = Vector2i.DOWN
	autosave()
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
	if GameState.hen_eggs > 0:
		options.append(&"display_hen_eggs")
	if GameState.fish > 0:
		options.append(&"display_fish")
	options.append(&"buy_seeds")
	if not creatures.is_empty():
		options.append(&"train")
	if Expedition.any_villager() and not Expedition.idle(self).is_empty():
		options.append(&"adopt")
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
		&"display_fish":
			return "물고기 진열하기 (%d마리, 밤사이 %d원)" % [GameState.fish, GameState.fish * Config.FISH_PRICE]
		&"display_hen_eggs":
			return "달걀 진열하기 (%d개, 밤사이 %d원)" % [GameState.hen_eggs, GameState.hen_eggs * Config.HEN_EGG_PRICE]
		&"buy_seeds":
			return "씨앗 %d개 사기 (%d원)" % [Config.SEED_PACK_SIZE, Config.SEED_PACK_PRICE]
		&"train":
			return "크리처 훈련 (%d마리) ▶" % creatures.size()
		&"adopt":
			return "크리처 입양 보내기 (쉬는 · 채집 %d마리) ▶" % Expedition.idle(self).size()
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
	_delete_armed = -1
	active.frozen = true
	# 멈춤 메뉴를 연 동안 사냥터도 멈춘다
	if hunt:
		hunt.process_mode = Node.PROCESS_MODE_DISABLED
	_rebuild_menu()


func close_menu() -> void:
	if not menu_open:
		return
	menu_open = false
	_menu.visible = false
	active.frozen = false
	if hunt:
		hunt.process_mode = Node.PROCESS_MODE_INHERIT
	GameState.touch()


func menu_move(step: int) -> void:
	menu_index = wrapi(menu_index + step, 0, _menu_options.size())
	_rebuild_menu()


func menu_confirm() -> void:
	var id := _menu_options[menu_index]
	if menu_kind == &"title" or menu_kind == &"delete" or menu_kind == &"pause":
		save_menu_confirm(id)
		return
	if menu_kind == &"start":
		close_menu()
		TestStarts.apply(self, id)
		autosave()
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
	if menu_kind == &"yak" or menu_kind == &"brew":
		if id == &"close":
			close_menu()
			return
		if id == &"restore":
			if restore_yak():
				close_menu()
				return
		elif id == &"feed_tonic":
			feed_tonic()
		else:
			brew(id)
		_rebuild_menu()
		return
	if menu_kind == &"naru" or menu_kind == &"dock":
		if id == &"close":
			close_menu()
			return
		if id == &"restore":
			if restore_naru():
				close_menu()
				return
		else:
			dock_action(id)
		_rebuild_menu()
		_refresh_props()
		return
	if menu_kind == &"barn" or menu_kind == &"coop":
		if id == &"close":
			close_menu()
			return
		if id == &"restore":
			if restore_barn():
				close_menu()
				return
		else:
			coop_action(id)
		_rebuild_menu()
		_refresh_props()
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
	if menu_kind == &"expedition":
		if id == &"close":
			close_menu()
			return
		var z := String(id).trim_prefix("exp_").to_int()
		if Expedition.team(self, z).is_empty():
			Expedition.send(self, z)
		else:
			Expedition.recall(self, z)
		_rebuild_menu()
		_refresh_props()
		return
	if menu_kind == &"adopt":
		if id == &"back":
			menu_kind = &"supply"
			menu_index = 0
		else:
			Expedition.adopt(self, adopt_from_option(id))
			if adopt_options().size() <= 1:
				menu_kind = &"supply"
				menu_index = 0
		_rebuild_menu()
		return
	if id == &"adopt":
		menu_kind = &"adopt"
		menu_index = 0
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
	if supply_action(id):
		Sound.sfx(&"coin", 0.0, 1.0, 0.0)
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
		&"display_fish":
			if GameState.fish <= 0:
				GameState.notify("진열할 물고기가 없다.")
				return false
			var n := GameState.fish
			GameState.displayed_fish += n
			GameState.fish = 0
			GameState.notify("물고기 %d마리를 공급함에 진열했다. 밤사이 팔리면 아침에 돈통에 들어온다." % n)
		&"display_hen_eggs":
			if GameState.hen_eggs <= 0:
				GameState.notify("진열할 달걀이 없다.")
				return false
			var n := GameState.hen_eggs
			GameState.displayed_hen_eggs += n
			GameState.hen_eggs = 0
			GameState.notify("달걀 %d개를 공급함에 진열했다. 밤사이 팔리면 아침에 돈통에 들어온다." % n)
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
	if active == smith or active == alchemist or active == rancher or active == ferryman:
		GameState.notify("%s는 가방이 없다. 가방은 농부 · 사냥꾼만 든다." % active.display_name)
		return
	close_menu()
	active.frozen = true
	if hunt:
		hunt.set_process(false)
	inventory.open(active, stash, sell)


## 사냥꾼 스킬 창 (T). 사냥터에선 여는 동안 멈춘다.
func open_skills() -> void:
	close_menu()
	active.frozen = true
	if hunt:
		hunt.set_process(false)
	skill_panel.open()


func close_skills() -> void:
	if not skill_panel.visible:
		return
	skill_panel.close()
	active.frozen = false
	if hunt:
		hunt.set_process(true)
	GameState.touch()


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
		hunt.life = clampi(hunt.life, 1, hunt.max_life())
	GameState.touch()


# --- 대장간 복구 · 대장장이 (2026-09-29 사용자 선택 A: 한 번에 복구 + 사람 장비 제작) ---

## 아침에 대장간 쪽에서 생긴 일 (아침 카드 한 줄, 없으면 ""). 1막 대장을 처음 잡은 다음 날 터가 드러나고,
## 고친 뒤로는 고물 더미에 고철이 다시 쌓인다.
func _forge_morning() -> String:
	if GameState.forge_state == 0 and GameState.forge_boss_down:
		show_forge_site()
		return "금사리 대장이 쓰러진 뒤, 마을 아랫길 왼쪽 풀밭에 무너진 대장간 터가 드러났다. 터에서 F."
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
	GameState.scrap_pile = Config.SCRAP_PER_DAY
	show_forge_restored()
	GameState.notify("대장간을 고쳤다! 대장장이가 왔다 (Tab). 고물 더미의 고철로 모루에서 장비를 만든다. 크리처에게 고철 줍기(R)도 맡길 수 있다. 금사리 윗길 쇠다리도 이어 줘서 이제 광동리로 건너갈 수 있다.")
	return true


## 고친 대장간을 마을에 놓는다 (복구와 불러오기가 함께 쓴다): 대장간 그림 · 고물 더미 · 대장장이
func show_forge_restored() -> void:
	show_forge_site()
	forge.label = "대장간"
	forge.texture = preload("res://assets/props/forge.png")
	forge.queue_redraw()
	if scrap_heap == null:
		scrap_heap = _add_prop("고물 더미", preload("res://assets/props/scrap_pile.png"), Config.SCRAP_RECT)
		forage.block(Config.SCRAP_RECT)
	smith.visible = true
	smith.position = Farm.center_of(Config.SMITH_CELL)
	_refresh_props()


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


# --- 약방 복구 · 연금술사 (2026-09-29 사용자 선택: 한 번에 복구 + 물약 · 크리처 보약) ---

## 아침에 약방 쪽에서 생긴 일 (아침 카드 한 줄, 없으면 ""). 2막 대장을 처음 잡은 다음 날 터가 드러나고,
## 고친 뒤로는 도라지밭에 도라지가 다시 돋는다.
func _yak_morning() -> String:
	if GameState.yak_state == 0 and GameState.yak_boss_down:
		show_yak_site()
		return "장승이 쓰러진 뒤, 아랫길 가운데 풀밭에 무너진 약방 터가 드러났다. 터에서 F. 이제 캔 도라지는 팔지 않고 약방에 모은다."
	if GameState.yak_state >= 2:
		GameState.herb_bed = Config.HERB_BED_PER_DAY
	return ""


## 무너진 약방 터를 마을에 놓는다. 그 자리의 들나물 · 도라지 자리는 쓰지 않는다.
func show_yak_site() -> void:
	GameState.yak_state = maxi(GameState.yak_state, 1)
	if yak == null:
		yak = _add_prop("약방 터", preload("res://assets/props/yak_ruin.png"), Config.YAK_RECT)
		forage.block(Config.YAK_RECT)
		forage.block(Config.HERB_BED_RECT)
	_refresh_props()


## 복구에 드는 것: [이름, 가진 것, 필요한 것]
func yak_costs() -> Array:
	return [
		["돈", GameState.money, Config.YAK_COST_MONEY],
		[Config.ROOT_NAME + " (땅 크리처 채집)", GameState.roots, Config.YAK_COST_ROOTS],
		[Config.BOSS_MATERIAL2_NAME + " (도마리 장승)", GameState.material2, Config.YAK_COST_MATERIAL],
	]


func can_restore_yak() -> bool:
	return GameState.yak_state == 1 and yak_costs().all(func(c: Array) -> bool: return c[1] >= c[2])


func yak_cost_lines() -> Array[String]:
	var out: Array[String] = []
	for c: Array in yak_costs():
		out.append("  %s  %d / %d %s" % [c[0], mini(c[1], c[2]), c[2], "✔" if c[1] >= c[2] else ""])
	out.append("다 모으면 한 번에 고친다 → 연금술사 (Tab) · 호롱")
	return out


func yak_options() -> Array[StringName]:
	return [&"restore", &"close"]


func brew_options() -> Array[StringName]:
	var out: Array[StringName] = []
	out.assign(Config.BREWS.keys())
	if GameState.tonics > 0 and GameState.tonic_day != GameState.day:
		out.append(&"feed_tonic")
	out.append(&"close")
	return out


const BREW_COST_NAMES := {herbs = "나물", roots = Config.ROOT_NAME, junk = "잡템", crops = "무"}


func brew_option_text(id: StringName) -> String:
	match id:
		&"restore":
			return "고치기" if can_restore_yak() else "고치기 (아직 모자람)"
		&"close":
			return "닫기"
		&"feed_tonic":
			return "크리처 보약 먹이기 (오늘 모든 크리처 x2, 남은 보약 %d)" % GameState.tonics
	var b: Dictionary = Config.BREWS[id]
	var cost: Array[String] = []
	for k: String in b.cost:
		cost.append("%s %d" % [BREW_COST_NAMES[k], b.cost[k]])
	return "%s   %s   (%s)" % [b.name, " · ".join(cost), b.effect]


## 약방 터 · 약방에서 F. 터면 복구 창, 고친 약방이면 연금술사만 제작 창.
func _yak_interact() -> void:
	if GameState.yak_state == 1:
		open_menu(&"yak")
	elif active == alchemist:
		open_menu(&"brew")
	else:
		GameState.notify("약방이다. Tab으로 연금술사를 골라 F로 물약 · 크리처 보약을 만든다.")


## 한 번에 고친다 (선택창과 테스트가 함께 쓴다). 모자라면 무엇이 모자란지 알린다.
func restore_yak() -> bool:
	if GameState.yak_state != 1:
		return false
	if not can_restore_yak():
		var short: Array[String] = []
		for c: Array in yak_costs():
			if c[1] < c[2]:
				short.append("%s %d" % [String(c[0]).split(" ")[0], c[2] - c[1]])
		GameState.notify("아직 모자라다: %s." % ", ".join(short))
		return false
	GameState.money -= Config.YAK_COST_MONEY
	GameState.roots -= Config.YAK_COST_ROOTS
	GameState.material2 -= Config.YAK_COST_MATERIAL
	GameState.yak_state = 2
	GameState.herb_bed = Config.HERB_BED_PER_DAY
	show_yak_restored()
	GameState.notify("약방을 고쳤다! 연금술사가 왔다 (Tab). 약방에서 물약 · 크리처 보약을 만든다. 도라지밭 가꾸기(R)도 맡길 수 있다. 연금술사가 호롱을 만들어 줘서 이제 도마리 윗길 너머 번천으로 갈 수 있다.")
	return true


## 고친 약방을 마을에 놓는다 (복구와 불러오기가 함께 쓴다): 약방 그림 · 도라지밭 · 연금술사
func show_yak_restored() -> void:
	show_yak_site()
	yak.label = "약방"
	yak.texture = preload("res://assets/props/yak.png")
	yak.queue_redraw()
	if herb_bed == null:
		herb_bed = _add_prop("도라지밭", preload("res://assets/props/herb_bed.png"), Config.HERB_BED_RECT)
	alchemist.visible = true
	alchemist.position = Farm.center_of(Config.ALCHEMIST_CELL)
	_refresh_props()


## 도라지밭에서 손으로 도라지 하나 (농부 · 연금술사)
func pick_herb_bed() -> bool:
	if GameState.herb_bed <= 0:
		GameState.notify("도라지밭이 비었다. 내일 아침 다시 돋는다.")
		return false
	GameState.herb_bed -= 1
	GameState.roots += 1
	GameState.notify("도라지를 하나 캤다 (%s %d). 크리처에게 도라지밭(R)을 맡기면 알아서 캔다." % [Config.ROOT_NAME, GameState.roots])
	return true


## 연금술사가 id 를 한 번 만든다. 만들었으면 true.
func brew(id: StringName) -> bool:
	if not Config.BREWS.has(id):
		return false
	var b: Dictionary = Config.BREWS[id]
	var short: Array[String] = []
	for k: String in b.cost:
		if GameState.get(k) < b.cost[k]:
			short.append("%s %d" % [BREW_COST_NAMES[k], b.cost[k] - GameState.get(k)])
	if not short.is_empty():
		GameState.notify("모자라다: %s." % ", ".join(short))
		return false
	for k: String in b.cost:
		GameState.set(k, GameState.get(k) - b.cost[k])
	var field: String = {&"potion": "potions", &"lamp_oil": "lamp_oil", &"strength": "strength", &"speed": "speed", &"tonic": "tonics"}[id]
	GameState.set(field, GameState.get(field) + b.count)
	GameState.notify("%s을(를) %s 만들었다! %s" % [b.name, "두 병" if b.count == 2 else "하나", b.effect])
	return true


## 크리처 보약을 먹인다: 오늘 하루 모든 크리처 일 속도 두 배
func feed_tonic() -> bool:
	if GameState.tonics <= 0 or GameState.tonic_day == GameState.day:
		return false
	GameState.tonics -= 1
	GameState.tonic_day = GameState.day
	for c in creatures:
		c._reset_timer()
	GameState.notify("크리처들에게 보약을 먹였다! 오늘 하루 모두 두 배 빠르다 (남은 보약 %d)." % GameState.tonics)
	return true


# --- 축사 복구 · 목축인 (2026-09-30 사용자 선택 A 닭장) ---------------------

## 아침에 축사 쪽에서 생긴 일 (아침 카드 한 줄, 없으면 ""). 3막 대장을 처음 잡은 다음 날 터가 드러나고,
## 고친 뒤로는 닭장이 하룻밤을 보낸다: 둥지에 남긴 달걀이 병아리로 → 병아리가 자람 → 암탉이 달걀을 낳음.
func _barn_morning() -> String:
	if GameState.barn_state == 0 and GameState.barn_boss_down:
		show_barn_site()
		return "%s 대장이 쓰러진 뒤, 부화기 오른쪽 큰길 위 풀밭에 무너진 축사 터가 드러났다. 터에서 F." % Config.HUNT_ZONES[Config.BARN_ZONE].name
	if GameState.barn_state < 2:
		return ""
	var guarded := creatures.any(func(c: Creature) -> bool: return c.data.species.guards_coop and c.job == CreatureJobs.FEED)
	var r := coop_night(_rng, guarded)
	var parts: Array[String] = []
	if r.weasel != "":
		parts.append(r.weasel)
	if r.laid > 0:
		parts.append("달걀 %d개" % r.laid)
	if r.hatched > 0:
		parts.append("병아리 %d마리 깸" % r.hatched)
	if r.grown > 0:
		parts.append("병아리 %d마리가 암탉이 됨" % r.grown)
	if r.hungry > 0:
		parts.append("모이를 못 먹은 암탉 %d마리" % r.hungry)
	return ("닭장: " + " · ".join(parts)) if not parts.is_empty() else ""


## 닭장의 하룻밤 (아침 카드와 테스트가 함께 쓴다). 순서: 족제비 (지킴이가 없으면 가끔) → 둥지에 남은 달걀 → 병아리 (닭장 칸까지, 나머지는 버림),
## 병아리 자람, 암탉이 둥지에 달걀 (어제 모이를 먹었으면 반드시, 아니면 HEN_HUNGRY_LAY). 모이는 새로 센다.
static func coop_night(rng: RandomNumberGenerator, guarded := false) -> Dictionary:
	var weasel := ""
	if not guarded and rng.randf() < Config.WEASEL_CHANCE:
		if GameState.nest > 0:
			var took := ceili(GameState.nest / 2.0)
			GameState.nest -= took
			weasel = "족제비가 둥지 달걀 %d개를 물어 감" % took
		elif not GameState.chicks.is_empty():
			GameState.chicks.pop_back()
			weasel = "족제비가 병아리 하나를 물어 감"
	var hatched := 0
	for i in GameState.nest:
		if GameState.hens + GameState.chicks.size() < Config.HEN_CAP and rng.randf() < Config.CHICK_HATCH_CHANCE:
			hatched += 1
	var grown := 0
	var still: Array[int] = []
	for d in GameState.chicks:
		if d <= 1:
			grown += 1
		else:
			still.append(d - 1)
	GameState.chicks = still
	GameState.hens += grown
	for i in hatched:
		GameState.chicks.append(Config.CHICK_GROW_DAYS)
	var laid := 0
	var hungry := 0
	for i in GameState.hens - grown:
		if i < GameState.fed:
			laid += 1
		else:
			hungry += 1
			if rng.randf() < Config.HEN_HUNGRY_LAY:
				laid += 1
	GameState.nest = laid
	GameState.fed = 0
	return {laid = laid, hatched = hatched, grown = grown, hungry = hungry, weasel = weasel}


## 무너진 축사 터를 마을에 놓는다. 그 자리의 들나물 · 도라지 자리는 쓰지 않는다.
func show_barn_site() -> void:
	GameState.barn_state = maxi(GameState.barn_state, 1)
	if barn == null:
		barn = _add_prop("축사 터", preload("res://assets/props/barn_ruin.png"), Config.BARN_RECT)
		barn.badge_side = true
		forage.block(Config.BARN_RECT)
		_flock = Node2D.new()
		_flock.z_index = int(barn.position.y) + 2
		_flock.draw.connect(_draw_flock)
		add_child(_flock)
		_village_nodes_add(_flock)
	_refresh_props()


## 사냥 중에 터가 생기면 (테스트) 사냥터 화면 위로 나오지 않게 숨길 목록에 넣는다
func _village_nodes_add(n: Node2D) -> void:
	if hunt:
		n.visible = false
		_village_nodes.append(n)


const HEN_TEX: Texture2D = preload("res://assets/props/hen.png")
const CHICK_TEX: Texture2D = preload("res://assets/props/chick.png")


## 닭장 앞 암탉 · 병아리 (수만큼, 자리는 날마다 조금씩). 수탉은 늘 한 마리 (붉은 볏이 큰 암탉 그림을 같이 씀).
func _draw_flock() -> void:
	if GameState.barn_state < 2:
		return
	var base := barn.position + Vector2(-44, 10)
	var n := GameState.hens + 1
	for i in n:
		var at := base + Vector2((i % 5) * 18 + (GameState.day * 7 + i * 13) % 6, (i / 5) * 10 + 2)
		_flock.draw_texture(HEN_TEX, at - Vector2(8, 16), Color(1, 0.92, 0.85) if i == 0 else Color.WHITE)
	for j in GameState.chicks.size():
		var at := base + Vector2(8 + j * 11, 22 + (GameState.day + j) % 3)
		_flock.draw_texture(CHICK_TEX, at - Vector2(5, 10))


## 복구에 드는 것: [이름, 가진 것, 필요한 것]
func barn_costs() -> Array:
	return [
		["돈", GameState.money, Config.BARN_COST_MONEY],
		["무 (수확해서 들고 있는 것)", GameState.crops, Config.BARN_COST_CROPS],
		[Config.BOSS_MATERIAL3_NAME + " (%s 대장)" % Config.HUNT_ZONES[Config.BARN_ZONE].name, GameState.material3, Config.BARN_COST_MATERIAL],
	]


func can_restore_barn() -> bool:
	return GameState.barn_state == 1 and barn_costs().all(func(c: Array) -> bool: return c[1] >= c[2])


func barn_cost_lines() -> Array[String]:
	var out: Array[String] = []
	for c: Array in barn_costs():
		out.append("  %s  %d / %d %s" % [c[0], mini(c[1], c[2]), c[2], "✔" if c[1] >= c[2] else ""])
	out.append("다 모으면 한 번에 고친다 → 목축인 (Tab) · 닭 한 쌍")
	return out


## 축사 터 · 축사에서 F. 터면 복구 창, 고친 축사면 닭장 창 (농부 · 목축인, 도시락은 목축인만).
func _barn_interact() -> void:
	open_menu(&"barn" if GameState.barn_state == 1 else &"coop")


## 한 번에 고친다 (선택창과 테스트가 함께 쓴다). 모자라면 무엇이 모자란지 알린다.
func restore_barn() -> bool:
	if GameState.barn_state != 1:
		return false
	if not can_restore_barn():
		var short: Array[String] = []
		for c: Array in barn_costs():
			if c[1] < c[2]:
				short.append("%s %d" % [String(c[0]).split(" ")[0], c[2] - c[1]])
		GameState.notify("아직 모자라다: %s." % ", ".join(short))
		return false
	GameState.money -= Config.BARN_COST_MONEY
	GameState.crops -= Config.BARN_COST_CROPS
	GameState.material3 -= Config.BARN_COST_MATERIAL
	GameState.barn_state = 2
	GameState.hens = Config.START_HENS
	show_barn_restored()
	GameState.notify("축사를 고쳤다! 목축인이 수탉 · 암탉 한 쌍을 데려왔다 (Tab). 모이를 주면 아침마다 달걀, 둥지에 남긴 달걀은 병아리가 된다. 크리처에게 모이 주기(R)도 맡길 수 있다.")
	return true


## 고친 축사를 마을에 놓는다 (복구와 불러오기가 함께 쓴다): 축사 그림 · 목축인
func show_barn_restored() -> void:
	show_barn_site()
	barn.label = "축사"
	barn.texture = preload("res://assets/props/barn.png")
	barn.queue_redraw()
	rancher.visible = true
	rancher.position = Farm.center_of(Config.RANCHER_CELL)
	_refresh_props()


func barn_options() -> Array[StringName]:
	var out: Array[StringName] = [&"restore", &"close"]
	return out


func coop_options() -> Array[StringName]:
	var out: Array[StringName] = []
	if GameState.nest > 0:
		out.append(&"take_nest")
	if GameState.fed < GameState.hens:
		out.append(&"feed")
	if active == rancher:
		out.append(&"lunch")
	out.append(&"close")
	return out


func coop_option_text(id: StringName) -> String:
	match id:
		&"restore":
			return "고치기" if can_restore_barn() else "고치기 (아직 모자람)"
		&"take_nest":
			return "둥지 달걀 꺼내기 (%d개)" % GameState.nest
		&"feed":
			return "모이 주기 (무 %d, 오늘 암탉 %d마리 모두)" % [Config.FEED_CROP_COST, GameState.hens]
		&"lunch":
			return "사냥 도시락 싸기 (달걀 %d · 무 %d, 다음 사냥 체력 +%d)" % [Config.LUNCH_EGGS, Config.LUNCH_CROPS, Config.LUNCH_HP]
	return "닫기"


## 닭장에서 한 가지 일 (선택창과 테스트가 함께 쓴다).
func coop_action(id: StringName) -> bool:
	match id:
		&"take_nest":
			if GameState.nest <= 0:
				return false
			GameState.hen_eggs += GameState.nest
			GameState.notify("둥지에서 달걀 %d개를 꺼냈다 (든 달걀 %d). 공급함에 진열하거나 목축인이 도시락을 싼다." % [GameState.nest, GameState.hen_eggs])
			GameState.nest = 0
		&"feed":
			if GameState.fed >= GameState.hens:
				GameState.notify("암탉들이 오늘 모이를 다 먹었다.")
				return false
			if GameState.crops < Config.FEED_CROP_COST:
				GameState.notify("모이로 줄 무가 없다. 크리처에게 모이 주기(R)를 맡기면 무 없이 먹인다.")
				return false
			GameState.crops -= Config.FEED_CROP_COST
			GameState.fed = GameState.hens
			GameState.notify("암탉 %d마리에게 모이를 줬다. 내일 아침 한 마리에 달걀 하나씩." % GameState.hens)
		&"lunch":
			if active != rancher:
				return false
			if GameState.hen_eggs < Config.LUNCH_EGGS or GameState.crops < Config.LUNCH_CROPS:
				GameState.notify("모자라다. 사냥 도시락: 달걀 %d · 무 %d (든 달걀 %d · 무 %d)." % [Config.LUNCH_EGGS, Config.LUNCH_CROPS, GameState.hen_eggs, GameState.crops])
				return false
			GameState.hen_eggs -= Config.LUNCH_EGGS
			GameState.crops -= Config.LUNCH_CROPS
			GameState.lunches += 1
			GameState.notify("사냥 도시락을 쌌다 (%d개). 사냥꾼이 다음 사냥에 들어갈 때 먹고 체력 +%d." % [GameState.lunches, Config.LUNCH_HP])
		_:
			return false
	return true


# --- 팔당호 물가 · 나루터 · 뱃사공 (2026-10-02 시설 4, 사용자 선택 A 나루터 + B 통발) ---

const LAKE_TEX: Texture2D = preload("res://assets/props/lake.png")
const LAKE_RUIN_TEX: Texture2D = preload("res://assets/props/lake_ruin.png")
const LAKE_NARU_TEX: Texture2D = preload("res://assets/props/lake_naru.png")
const TRAP_TEX: Texture2D = preload("res://assets/props/trap.png")


## 마을 오른쪽 아래 팔당호 물가 (처음부터 있음): 물 칸은 막고 들나물 · 풀 장식을 안 놓는다.
## 바닥 바로 위에 그려서 잔교 · 배 · 통발도 캐릭터보다 늘 뒤.
func _build_lake() -> void:
	for row: int in Config.LAKE_ROWS:
		var r := Rect2i(Config.LAKE_ROWS[row], row, Config.MAP_SIZE.x - Config.LAKE_ROWS[row], 1)
		farm.add_blocker(Rect2(Vector2(r.position * Config.TILE), Vector2(r.size * Config.TILE)))
		farm.deco_skip.append(r)
		forage.block(r)
	farm.queue_redraw()
	_lake = Node2D.new()
	_lake.z_index = -999
	_lake.position = Vector2(Config.LAKE_ORIGIN * Config.TILE)
	_lake.draw.connect(_draw_lake)
	add_child(_lake)


func _draw_lake() -> void:
	_lake.draw_texture(LAKE_TEX, Vector2.ZERO)
	if GameState.naru_state == 1:
		_lake.draw_texture(LAKE_RUIN_TEX, Vector2.ZERO)
	elif GameState.naru_state >= 2:
		_lake.draw_texture(LAKE_NARU_TEX, Vector2.ZERO)
		for i in mini(GameState.traps, Config.TRAP_CELLS.size()):
			var at := Farm.center_of(Config.TRAP_CELLS[i]) - _lake.position
			_lake.draw_texture(TRAP_TEX, at - Vector2(8, 6) + Vector2(0, (GameState.day + i) % 2))


## 아침에 나루터 쪽에서 생긴 일 (아침 카드 한 줄, 없으면 ""). 4막 대장을 처음 잡은 다음 날 터가 드러나고,
## 고친 뒤로는 밤사이 통발에 물고기가 든다.
func _naru_morning() -> String:
	if GameState.naru_state == 0 and GameState.naru_boss_down:
		show_naru_site()
		return "%s 대장이 쓰러진 뒤, 마을 오른쪽 아래 팔당호 물가에 무너진 나루터 터가 드러났다. 터에서 F." % Config.HUNT_ZONES[Config.NARU_ZONE].name
	if GameState.naru_state < 2:
		return ""
	var r := traps_night(_rng)
	if r.traps == 0:
		return ""
	var text := "나루터: 통발 %d개를 걷어 물고기 %d마리 (바구니 %d)" % [r.traps, r.caught, GameState.basket]
	if r.driven > 0:
		text += " · 크리처가 몰아 준 것 %d" % r.driven
	return text


## 통발의 하룻밤 (아침 카드와 테스트가 함께 쓴다): 통발마다 물고기 0~2마리 (TRAP_CATCH_WEIGHTS) + 어제 물고기 몰기 수를
## 바구니에 담고, 통발은 걷힌다 (다시 놓아야 함). 몰기 수는 새로 센다.
static func traps_night(rng: RandomNumberGenerator) -> Dictionary:
	var traps := GameState.traps
	var caught := 0
	for i in traps:
		caught += rng.rand_weighted(PackedFloat32Array(Config.TRAP_CATCH_WEIGHTS))
	var driven := GameState.fish_drive if traps > 0 else 0
	caught += driven
	GameState.basket += caught
	GameState.traps = 0
	GameState.fish_drive = 0
	return {traps = traps, caught = caught, driven = driven}


## 무너진 나루터 터를 물가에 놓는다. 그 자리의 들나물 · 도라지 자리는 쓰지 않는다.
func show_naru_site() -> void:
	GameState.naru_state = maxi(GameState.naru_state, 1)
	if naru == null:
		naru = _add_prop("나루터 터", preload("res://assets/props/naru_ruin.png"), Config.NARU_RECT)
		naru.badge_side = true
		forage.block(Config.NARU_RECT)
	_lake.queue_redraw()
	_refresh_props()


## 고친 나루터를 놓는다 (복구와 불러오기가 함께 쓴다): 나룻집 · 잔교 · 나룻배 · 뱃사공
func show_naru_restored() -> void:
	show_naru_site()
	naru.label = "나루터"
	naru.texture = preload("res://assets/props/naru.png")
	naru.queue_redraw()
	ferryman.visible = true
	ferryman.position = Farm.center_of(Config.FERRYMAN_CELL)
	_lake.queue_redraw()
	_refresh_props()


## 복구에 드는 것: [이름, 가진 것, 필요한 것]
func naru_costs() -> Array:
	return [
		["돈", GameState.money, Config.NARU_COST_MONEY],
		["무 (수확해서 들고 있는 것)", GameState.crops, Config.NARU_COST_CROPS],
		[Config.BOSS_MATERIAL4_NAME + " (%s 대장)" % Config.HUNT_ZONES[Config.NARU_ZONE].name, GameState.material4, Config.NARU_COST_MATERIAL],
	]


func can_restore_naru() -> bool:
	return GameState.naru_state == 1 and naru_costs().all(func(c: Array) -> bool: return c[1] >= c[2])


func naru_cost_lines() -> Array[String]:
	var out: Array[String] = []
	for c: Array in naru_costs():
		out.append("  %s  %d / %d %s" % [c[0], mini(c[1], c[2]), c[2], "✔" if c[1] >= c[2] else ""])
	out.append("다 모으면 한 번에 고친다 → 뱃사공 (Tab) · 통발 · 나룻배")
	return out


## 한 번에 고친다 (선택창과 테스트가 함께 쓴다). 모자라면 무엇이 모자란지 알린다.
func restore_naru() -> bool:
	if GameState.naru_state != 1:
		return false
	if not can_restore_naru():
		var short: Array[String] = []
		for c: Array in naru_costs():
			if c[1] < c[2]:
				short.append("%s %d" % [String(c[0]).split(" ")[0], c[2] - c[1]])
		GameState.notify("아직 모자라다: %s." % ", ".join(short))
		return false
	GameState.money -= Config.NARU_COST_MONEY
	GameState.crops -= Config.NARU_COST_CROPS
	GameState.material4 -= Config.NARU_COST_MATERIAL
	GameState.naru_state = 2
	show_naru_restored()
	GameState.notify("나루터를 고쳤다! 뱃사공이 왔다 (Tab). 통발에 미끼(무)를 넣어 놓으면 아침에 물고기가 든다. 크리처에게 물고기 몰기(R)도 맡길 수 있다.")
	return true


func naru_options() -> Array[StringName]:
	var out: Array[StringName] = [&"restore", &"close"]
	return out


## 고친 나루터 창: 통발 놓기 · 물고기 꺼내기는 농부 · 뱃사공, 매운탕은 뱃사공만
func dock_options() -> Array[StringName]:
	var out: Array[StringName] = []
	if GameState.traps < Config.TRAP_MAX:
		out.append(&"set_traps")
	if GameState.basket > 0:
		out.append(&"take_fish")
	if active == ferryman:
		out.append(&"stew")
	out.append(&"close")
	return out


func dock_option_text(id: StringName) -> String:
	match id:
		&"restore":
			return "고치기" if can_restore_naru() else "고치기 (아직 모자람)"
		&"set_traps":
			var n := Config.TRAP_MAX - GameState.traps
			return "통발 놓기 (%d개, 미끼 무 %d씩)" % [n, Config.TRAP_BAIT]
		&"take_fish":
			return "바구니 물고기 꺼내기 (%d마리)" % GameState.basket
		&"stew":
			return "매운탕 끓이기 (물고기 %d · 무 %d, 다음 사냥 체력 +%d · 경험치 +%d%%)" % [Config.STEW_FISH, Config.STEW_CROPS, Config.STEW_HP, roundi((Config.STEW_XP_MULT - 1.0) * 100)]
	return "닫기"


## 나루터에서 한 가지 일 (선택창 · 테스트 · 봇이 함께 쓴다).
func dock_action(id: StringName) -> bool:
	match id:
		&"set_traps":
			var n := mini(Config.TRAP_MAX - GameState.traps, GameState.crops / Config.TRAP_BAIT)
			if n <= 0:
				GameState.notify("통발이 다 놓였거나 미끼로 넣을 무가 없다." if GameState.traps < Config.TRAP_MAX else "통발이 다 놓여 있다.")
				return false
			GameState.crops -= n * Config.TRAP_BAIT
			GameState.traps += n
			GameState.notify("통발 %d개를 물에 놓았다 (놓인 통발 %d). 내일 아침 물고기가 들어 있을 것이다." % [n, GameState.traps])
		&"take_fish":
			if GameState.basket <= 0:
				return false
			GameState.fish += GameState.basket
			GameState.notify("바구니에서 물고기 %d마리를 꺼냈다 (든 물고기 %d). 공급함에 진열하거나 뱃사공이 매운탕을 끓인다." % [GameState.basket, GameState.fish])
			GameState.basket = 0
		&"stew":
			if active != ferryman:
				return false
			if GameState.fish < Config.STEW_FISH or GameState.crops < Config.STEW_CROPS:
				GameState.notify("모자라다. 매운탕: 물고기 %d · 무 %d (든 물고기 %d · 무 %d)." % [Config.STEW_FISH, Config.STEW_CROPS, GameState.fish, GameState.crops])
				return false
			GameState.fish -= Config.STEW_FISH
			GameState.crops -= Config.STEW_CROPS
			GameState.stews += 1
			GameState.notify("매운탕을 끓였다 (%d그릇). 사냥꾼이 다음 사냥에 들어갈 때 먹는다." % GameState.stews)
		_:
			return false
	_lake.queue_redraw()
	return true


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
	var text := "%d구역 %s 웨이포인트 (%s Lv %d)" % [z + 1, Config.HUNT_ZONES[z].name, Config.HUNT_ZONES[z].monster, HunterSkills.monster_level(z)]
	if Config.HUNT_ZONES[z].has("advice"):
		text += " · " + Config.HUNT_ZONES[z].advice
	return text


# --- 크리처 원정 · 입양 (2026-10-01 사용자 선택 B + D, Expedition) ----------

## 원정 선택창: 대장을 잡은 구역마다 &"exp_<번호>" (보내기 또는 불러들이기), 마지막에 닫기
func expedition_options() -> Array[StringName]:
	var options: Array[StringName] = []
	for z in Expedition.zones():
		options.append(StringName("exp_%d" % z))
	options.append(&"close")
	return options


func expedition_option_text(id: StringName) -> String:
	if id == &"close":
		return "닫기"
	return Expedition.zone_text(self, String(id).trim_prefix("exp_").to_int())


## 입양 선택창: 쉬는 · 채집 크리처마다 &"adopt_<번호>" (받을 주민이 없으면 비어 있음), 마지막에 뒤로
func adopt_options() -> Array[StringName]:
	var options: Array[StringName] = []
	if Expedition.next_villager() != &"":
		for i in Expedition.idle(self).size():
			options.append(StringName("adopt_%d" % i))
	options.append(&"back")
	return options


func adopt_from_option(id: StringName) -> Creature:
	var list := Expedition.idle(self)
	var i := String(id).trim_prefix("adopt_").to_int()
	return list[i] if String(id).begins_with("adopt_") and i < list.size() else null


func adopt_option_text(id: StringName) -> String:
	var s := adopt_from_option(id)
	if s == null:
		return "뒤로"
	var star := (" ★%d" % s.data.train_total()) if s.data.train_total() > 0 else ""
	return "%s %s%s · %s · 속도 %.2f / 범위 %d" % [s.data.element_names(), s.data.species.display_name, star, CreatureJobs.display_name(s.job), s.data.base_work_speed, s.data.work_radius()]


func _rebuild_menu() -> void:
	var companion := menu_kind == &"companion"
	var waypoint := menu_kind == &"waypoint"
	var training := menu_kind == &"train"
	var forging := menu_kind == &"forge" or menu_kind == &"craft"
	var brewing := menu_kind == &"yak" or menu_kind == &"brew"
	var starting := menu_kind == &"start"
	var ranching := menu_kind == &"barn" or menu_kind == &"coop"
	var docking := menu_kind == &"naru" or menu_kind == &"dock"
	var expedition := menu_kind == &"expedition"
	var adopting := menu_kind == &"adopt"
	var saving := menu_kind == &"title" or menu_kind == &"delete" or menu_kind == &"pause"
	if saving:
		_menu_options = save_menu_options()
	elif starting:
		_menu_options = TestStarts.ids()
	elif brewing:
		_menu_options = yak_options() if menu_kind == &"yak" else brew_options()
	elif ranching:
		_menu_options = barn_options() if menu_kind == &"barn" else coop_options()
	elif docking:
		_menu_options = naru_options() if menu_kind == &"naru" else dock_options()
	elif forging:
		_menu_options = forge_options() if menu_kind == &"forge" else craft_options()
	elif training:
		_menu_options = train_options()
	elif expedition:
		_menu_options = expedition_options()
	elif adopting:
		_menu_options = adopt_options()
	else:
		_menu_options = companion_options() if companion else (waypoint_options() if waypoint else supply_options())
	menu_index = clampi(menu_index, 0, _menu_options.size() - 1)
	var head := "사냥터 입구 · 누구랑 갈까?" if companion else ("사냥터 입구 · 어디서 시작할까?" if waypoint else "마을 공급함   가진 돈 %d원" % GameState.money)
	if training:
		head = "크리처 훈련   가진 돈 %d원" % GameState.money
	if expedition:
		head = "사냥터 입구 · 크리처 원정   쉬는 · 채집 %d마리 · 원정 중 %d마리" % [Expedition.idle(self).size(), Expedition.away_count(self)]
	if adopting:
		var who := Expedition.next_villager()
		head = "크리처 입양 보내기 → %s" % (Expedition.gift_text(who) if who != &"" else "받아 줄 주민이 없다")
	if starting:
		head = "테스트용 시작 지점 (개발용 빌드에서만)"
	if menu_kind == &"title":
		head = "분원리   어느 슬롯으로 할까?"
	elif menu_kind == &"delete":
		head = "슬롯 지우기 (되돌릴 수 없다)"
	elif menu_kind == &"pause":
		head = "멈춤   %d일째 %s" % [GameState.day, GameState.clock_text(GameState.minutes)]
	if menu_kind == &"forge":
		head = "무너진 대장간 터"
	elif menu_kind == &"craft":
		head = "대장간 모루   고철 %d · 돈 %d원" % [GameState.scrap, GameState.money]
	elif menu_kind == &"yak":
		head = "무너진 약방 터"
	elif menu_kind == &"barn":
		head = "무너진 축사 터"
	elif menu_kind == &"coop":
		head = "축사 닭장   암탉 %d · 병아리 %d · 둥지 달걀 %d" % [GameState.hens, GameState.chicks.size(), GameState.nest]
	elif menu_kind == &"naru":
		head = "무너진 나루터 터"
	elif menu_kind == &"dock":
		head = "분원나루   통발 %d/%d · 바구니 물고기 %d" % [GameState.traps, Config.TRAP_MAX, GameState.basket]
	elif menu_kind == &"brew":
		head = "약방   나물 %d · %s %d · 잡템 %d · 무 %d" % [GameState.herbs, Config.ROOT_NAME, GameState.roots, GameState.junk, GameState.crops]
	var lines: Array[String] = [head]
	# 항목이 많으면 고른 줄 둘레만 보인다 (화면 밖으로 나가지 않게)
	var first := clampi(menu_index - MENU_VISIBLE_ROWS / 2, 0, maxi(0, _menu_options.size() - MENU_VISIBLE_ROWS))
	var last := mini(_menu_options.size(), first + MENU_VISIBLE_ROWS)
	if first > 0:
		lines.append("   ▲")
	for i in range(first, last):
		var o := _menu_options[i]
		var text := ""
		if saving:
			text = save_menu_text(o)
		elif starting:
			text = TestStarts.option_text(o)
		elif training:
			text = train_option_text(o)
		elif expedition:
			text = expedition_option_text(o)
		elif adopting:
			text = adopt_option_text(o)
		elif forging:
			text = forge_option_text(o)
		elif brewing:
			text = brew_option_text(o)
		elif ranching:
			text = coop_option_text(o)
		elif docking:
			text = dock_option_text(o)
		else:
			text = companion_option_text(o) if companion else (waypoint_option_text(o) if waypoint else supply_option_text(o))
		lines.append(("▶ " if i == menu_index else "   ") + text)
	if last < _menu_options.size():
		lines.append("   ▼")
	if training:
		lines.append("크리처마다 따로 · 단계마다 값 두 배 (%s원)" % " → ".join(Config.TRAIN_PRICES.map(func(p: int) -> String: return str(p))))
	if menu_kind == &"forge":
		lines.append_array(forge_cost_lines())
	elif menu_kind == &"yak":
		lines.append_array(yak_cost_lines())
	elif menu_kind == &"barn":
		lines.append_array(barn_cost_lines())
	elif menu_kind == &"naru":
		lines.append_array(naru_cost_lines())
	elif menu_kind == &"dock":
		lines.append("든 물고기 %d · 무 %d · 매운탕 %d · 오늘 물고기 몰기 %d/%d" % [GameState.fish, GameState.crops, GameState.stews, GameState.fish_drive, Config.FISH_DRIVE_CAP])
		lines.append("놓은 통발은 다음 날 아침 하나에 물고기 0~2마리 (걷히면 다시 놓기)")
		lines.append("물고기 몰기 크리처: 통발이 있으면 한 번에 내일 물고기 +1")
		lines.append("나룻배: 5막 팔당호 섬 뱃길 (아직 물길을 모른다)")
	elif menu_kind == &"coop":
		lines.append("든 달걀 %d · 무 %d · 사냥 도시락 %d · 오늘 모이 %d/%d" % [GameState.hen_eggs, GameState.crops, GameState.lunches, mini(GameState.fed, GameState.hens), GameState.hens])
		lines.append("모이를 먹은 암탉은 아침마다 달걀 하나 (굶으면 반쯤)")
		lines.append("둥지에 남긴 달걀은 밤사이 반쯤 병아리 → %d일 뒤 암탉 (%d마리까지)" % [Config.CHICK_GROW_DAYS, Config.HEN_CAP])
	elif menu_kind == &"brew":
		lines.append("가진 것: 빨간 물약 %d · 호롱 기름 %d · 힘 %d · 빠르기 %d · 보약 %d" % [GameState.potions, GameState.lamp_oil, GameState.strength, GameState.speed, GameState.tonics])
		lines.append("힘 · 빠르기 물약은 다음 사냥에 들어갈 때 하나씩 마신다")
	elif menu_kind == &"craft":
		lines.append("만들 때마다 옵션 1~3개가 무작위로 붙는다 (디아블로2 제작처럼)")
		lines.append("만든 장비는 칸이 비었으면 바로 입고, 아니면 그 사람 가방으로")
	if expedition:
		lines.append("쉬는 · 채집 크리처 중 잘 맞는 크리처부터 %d~%d마리가 한 팀" % [Config.EXPEDITION_TEAM_MIN, Config.EXPEDITION_TEAM_MAX])
		lines.append("밤마다 다녀와 아침에 돈 · 잡템 · 가끔 대장 재료 · 드물게 장비")
		lines.append("불러들일 때까지 날마다 다시 간다 · 알은 안 가져온다")
	if adopting:
		lines.append("고른 크리처는 주민 곁에서 지낸다 (일은 안 함, 되돌릴 수 없음)")
		lines.append("주민마다 %d마리까지 · 입양 수가 적은 주민에게 먼저" % Config.ADOPT_CAP)
	if companion:
		lines.append("데려간 크리처는 돌아오면 제자리에서 다시 일한다")
	if waypoint:
		lines.append("대장을 쓰러뜨리면 위쪽 길로 더 깊이 갈 수 있다")
	if starting:
		lines.append("W/S 고르기 · F 정하기 · 숫자키 바로 · Esc 처음부터")
		lines.append("그 시점쯤의 상태를 새로 채운다 (고른 뒤부터 이 슬롯에 저장)")
	if menu_kind == &"title":
		lines.append("W/S 고르기 · F 정하기")
		lines.append("잘 때 · 사냥터에서 돌아올 때 저절로 저장, Esc로 언제든 저장하고 나가기")
	elif menu_kind == &"delete":
		lines.append("같은 슬롯을 한 번 더 F: 지운다 · Esc 돌아가기")
	elif menu_kind == &"pause":
		lines.append("사냥터 안에서 나가면 마을로 돌아온 채로 저장한다" if hunt else "Esc 계속하기")
	_menu_text.text = "\n".join(lines)
	_menu.size = _menu_text.get_minimum_size() + Vector2(22, 16)
	# 공급함(또는 사냥터 입구) 옆에 띄우되 화면 밖으로 나가지 않게
	var at := (hunt_gate.position + Vector2(-200, 8)) if companion or waypoint or expedition else supply_box.position + Vector2(36, -80)
	if forging:
		at = forge.position + Vector2(40, -150)
	if brewing:
		at = yak.position + Vector2(-260, -150)
	if ranching:
		at = barn.position + Vector2(-300, 20)
	if docking:
		at = naru.position + Vector2(-320, -170)
	# 오브젝트 자리(월드)를 화면 자리로 (마을 카메라가 움직여도 오브젝트 옆에 뜨게)
	at = to_screen(at)
	if starting or saving:
		at = (Vector2(640, 360) - _menu.size) / 2
	_menu.position = at.clamp(Vector2(4, 32), Vector2(636, 324) - _menu.size)
	_menu.visible = menu_open


# --- 저장 슬롯 · 멈춤 메뉴 (2026-09-30 사용자 선택 C 디아2식) ---------------

func save_menu_options() -> Array[StringName]:
	var out: Array[StringName] = []
	match menu_kind:
		&"title":
			for i in range(1, SaveGame.SLOTS + 1):
				out.append(StringName("slot_%d" % i))
			if range(1, SaveGame.SLOTS + 1).any(func(i: int) -> bool: return SaveGame.exists(i)):
				out.append(&"delete")
		&"delete":
			for i in range(1, SaveGame.SLOTS + 1):
				if SaveGame.exists(i):
					out.append(StringName("slot_%d" % i))
			out.append(&"back")
		&"pause":
			out.append(&"resume")
			out.append(&"music_volume")
			out.append(&"sfx_volume")
			if save_slot >= 0:
				out.append(&"save_quit")
	return out


func save_menu_text(id: StringName) -> String:
	match id:
		&"delete":
			return "슬롯 지우기"
		&"back":
			return "돌아가기"
		&"resume":
			return "계속하기"
		&"music_volume":
			return "배경음 크기   %s   (F로 바꾸기)" % Sound.percent(Sound.music_volume)
		&"sfx_volume":
			return "효과음 크기   %s   (F로 바꾸기)" % Sound.percent(Sound.sfx_volume)
		&"save_quit":
			return "저장하고 나가기 (슬롯 %d)" % save_slot
	var slot := String(id).trim_prefix("slot_").to_int()
	var sum := SaveGame.summary(slot)
	if menu_kind == &"delete":
		var what := "슬롯 %d   %d일째 · %d원" % [slot, sum.get("day", 0), sum.get("money", 0)]
		return what + ("   ← 한 번 더 F: 지운다" if _delete_armed == slot else "")
	if sum.is_empty():
		return "슬롯 %d   비어 있음 · 새 게임" % slot
	return "슬롯 %d   %d일째 %s · %d원 · 이어하기" % [slot, sum.day, GameState.clock_text(sum.minutes), sum.money]


func save_menu_confirm(id: StringName) -> void:
	match id:
		&"delete":
			open_menu(&"delete")
			return
		&"back":
			open_menu(&"title")
			return
		&"resume":
			close_menu()
			return
		&"music_volume":
			Sound.set_music_volume(Sound.next_step(Sound.music_volume))
			_rebuild_menu()
			return
		&"sfx_volume":
			Sound.set_sfx_volume(Sound.next_step(Sound.sfx_volume))
			Sound.sfx(&"coin", 0.0, 1.0, 0.0)
			_rebuild_menu()
			return
		&"save_quit":
			save_and_quit()
			return
	var slot := String(id).trim_prefix("slot_").to_int()
	if menu_kind == &"delete":
		if _delete_armed == slot:
			SaveGame.erase(slot)
			open_menu(&"title")
			GameState.notify("슬롯 %d을(를) 지웠다." % slot)
		else:
			_delete_armed = slot
			_rebuild_menu()
		return
	close_menu()
	save_slot = slot
	if SaveGame.load_into(self, slot):
		GameState.notify("슬롯 %d: %d일째에서 이어 한다." % [slot, GameState.day])
	elif OS.is_debug_build():
		# 테스트용 시작 지점 (2026-09-29): 개발용 빌드에서만. 고른 상태부터 이 슬롯에 저장한다.
		open_menu(&"start")
	else:
		autosave()


## 저장 슬롯이 있으면 지금 상태를 쓴다 (잘 때 · 사냥터에서 돌아올 때 · 저장하고 나가기)
func autosave() -> bool:
	if save_slot < 0:
		return false
	return SaveGame.save(self, save_slot)


## 저장하고 처음 화면으로. 사냥터 안이면 먼저 마을로 돌아온다 (주운 것은 그대로).
func save_and_quit() -> void:
	close_menu()
	if hunt:
		leave_hunt()
	autosave()
	get_tree().reload_current_scene()


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
	autosave()
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


## 밤일 (2026-10-02 곤지암 아기 악귀): 밤일을 하는 크리처가 맡은 일을 한 바퀴 더 해 둔다. 모두 한 일 수.
func night_work() -> int:
	var done := 0
	for c: Creature in creatures:
		done += c.night_work()
	return done


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
	if GameState.displayed_fish > 0:
		var earned := GameState.displayed_fish * Config.FISH_PRICE
		GameState.money += earned
		lines.append("공급함의 물고기 %d마리가 팔렸다. 돈통에 +%d원" % [GameState.displayed_fish, earned])
		GameState.displayed_fish = 0
	if GameState.displayed_hen_eggs > 0:
		var earned := GameState.displayed_hen_eggs * Config.HEN_EGG_PRICE
		GameState.money += earned
		lines.append("공급함의 달걀 %d개가 팔렸다. 돈통에 +%d원" % [GameState.displayed_hen_eggs, earned])
		GameState.displayed_hen_eggs = 0
	var forge_line := _forge_morning()
	if forge_line != "":
		lines.append(forge_line)
	var yak_line := _yak_morning()
	if yak_line != "":
		lines.append(yak_line)
	var barn_line := _barn_morning()
	if barn_line != "":
		lines.append(barn_line)
	var naru_line := _naru_morning()
	if naru_line != "":
		lines.append(naru_line)
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
	var night_done := night_work()
	if night_done > 0:
		lines.append("아기 악귀가 밤새 맡은 일을 %d번 해 두었다." % night_done)
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
		lines.append("아기 까마귀가 벌판에서 낟알을 물어 왔다. 씨앗 +%d" % seeds)
	if grain_money > 0:
		lines.append("씨앗이 넉넉해서 남는 낟알은 공급함에서 팔렸다. +%d원" % grain_money)
	var expedition_line := Expedition.night(self, _rng)
	if expedition_line != "":
		lines.append(expedition_line)
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
		Sound.sfx(&"hatch", 0.0, 1.0, 0.0)
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
		if r.y > 0 and c.job != CreatureJobs.REST and c.expedition_zone < 0:
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


## 낟알 줍기 (아기 까마귀, 2026-09-29 광동리 B): 일을 맡은 개체마다 종의 daily_seeds 범위만큼 씨앗을 물어 온다. 쉬는 중이면 없음.
## 씨앗 넘침 (2026-09-29 4구역 스레드, Claude 기본값): 씨앗이 GRAIN_SEED_CAP 개를 넘으면 넘는 낟알은 씨앗 대신
## 공급함에서 밤에 팔린다 (개당 GRAIN_PRICE원). 돌려주는 값은 씨앗으로 들어온 수.
func gather_seeds() -> int:
	var total := 0
	for c in creatures:
		var r := c.data.species.daily_seeds
		if r.y > 0 and c.job != CreatureJobs.REST and c.expedition_zone < 0:
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
	return add_creature(data, at_cell, s.job, s)


## 이미 정해진 개체를 농장에 내놓는다 (부화와 불러오기가 함께 쓴다)
func add_creature(data: CreatureData, at_cell: Vector2i, job: StringName, s: Creature = null) -> Creature:
	if s == null:
		s = Creature.new()
	s.job = job
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
		if not s.visible:
			continue
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
	var away := Expedition.away_count(self)
	hunt_gate.set_badge("원정 %d마리" % away if away > 0 else "")
	if forge:
		forge.set_badge("%s %d/%d" % [Config.BOSS_MATERIAL_NAME, GameState.material, Config.FORGE_COST_MATERIAL] if GameState.forge_state == 1 else ("고철 %d" % GameState.scrap))
	if scrap_heap:
		scrap_heap.set_badge("고철 %d" % GameState.scrap_pile if GameState.scrap_pile > 0 else "비었음")
	if yak:
		# 고친 뒤엔 도라지밭 남은 수도 여기 함께 (도라지밭 배지가 약방 옆 배지와 겹쳐서, 2026-10-01)
		yak.set_badge("%s %d/%d" % [Config.BOSS_MATERIAL2_NAME, GameState.material2, Config.YAK_COST_MATERIAL] if GameState.yak_state == 1 else ("%s %d · 밭 %d" % [Config.ROOT_NAME, GameState.roots, GameState.herb_bed]))
	if herb_bed:
		herb_bed.set_badge("")
	if barn:
		barn.set_badge("%s %d/%d" % [Config.BOSS_MATERIAL3_NAME, GameState.material3, Config.BARN_COST_MATERIAL] if GameState.barn_state == 1 else ("둥지 달걀 %d" % GameState.nest if GameState.nest > 0 else ""))
		_flock.queue_redraw()
	if naru:
		naru.set_badge("%s %d/%d" % [Config.BOSS_MATERIAL4_NAME, GameState.material4, Config.NARU_COST_MATERIAL] if GameState.naru_state == 1 else ("물고기 %d" % GameState.basket if GameState.basket > 0 else ""))
	if _lake:
		_lake.queue_redraw()


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := Control.new()
	panel.position = Vector2(-4, -4)
	panel.size = Vector2(648, 30)
	panel.add_child(UiSkin.nine(UiSkin.BAR, 5))
	layer.add_child(panel)
	_status = Label.new()
	_status.position = Vector2(6, 2)
	_status.add_theme_font_size_override("font_size", 10)
	_status.visible = false
	layer.add_child(_status)
	_hud_bar = HudBar.new()
	_hud_bar.size = Vector2(640, 26)
	_hud_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_hud_bar)
	var bottom := Control.new()
	bottom.position = Vector2(-4, 328)
	bottom.size = Vector2(648, 36)
	bottom.add_child(UiSkin.nine(UiSkin.BAR, 5))
	layer.add_child(bottom)
	_message = Label.new()
	_message.position = Vector2(8, 330)
	_message.add_theme_font_size_override("font_size", 10)
	_message.add_theme_color_override("font_color", Color(1, 0.96, 0.86))
	layer.add_child(_message)
	var help := Label.new()
	help.position = Vector2(8, 345)
	help.add_theme_font_size_override("font_size", 10)
	help.modulate = Color(1, 1, 1, 0.6)
	help.text = "WASD 이동 · Space 도구 (사냥터: 클릭 공격 · Space 구르기) · Q/E 도구 바꾸기 · F 상호작용 · R 크리처 일 · I 가방 · Tab 캐릭터 · 집 현관 F 잠자기"
	layer.add_child(help)
	# 저녁·밤 색 (하루 시계). 아침엔 투명.
	_dusk = ColorRect.new()
	_dusk.color = Color(0.1, 0.08, 0.3, 0.0)
	_dusk.size = Vector2(640, 360)
	_dusk.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 저녁 어둡기는 Ambience 가 화면 색으로 그린다 (수치만 남김)
	_dusk.visible = false
	layer.add_child(_dusk)
	layer.move_child(_dusk, 0)
	# 잠잘 때 화면 전체를 덮는 밤 색. 평소에는 투명.
	_night = ColorRect.new()
	_night.color = Color(0.05, 0.06, 0.18, 0.0)
	_night.size = Vector2(640, 360)
	_night.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_night)
	_morning_card = ColorRect.new()
	(_morning_card as ColorRect).color = Color(0, 0, 0, 0)
	_morning_card.add_child(UiSkin.nine(UiSkin.WINDOW, 9))
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
	_morning_text.add_theme_color_override("font_color", UiSkin.INK)
	_morning_card.add_child(_morning_text)
	_menu = ColorRect.new()
	_menu.color = Color(0, 0, 0, 0)
	_menu.visible = false
	_menu.add_child(UiSkin.nine(UiSkin.WINDOW, 9))
	layer.add_child(_menu)
	_menu_text = Label.new()
	_menu_text.position = Vector2(11, 8)
	_menu_text.add_theme_font_size_override("font_size", 10)
	_menu_text.add_theme_color_override("font_color", UiSkin.INK)
	_menu.add_child(_menu_text)
	# 가방 · 스킬 창은 사냥터 HUD (층 2) 위에 (하트 · 작은 지도가 창을 덮지 않게)
	var top := CanvasLayer.new()
	top.layer = 5
	add_child(top)
	inventory = InventoryUI.new()
	inventory.wear_changed.connect(_on_wear_changed)
	top.add_child(inventory)
	skill_panel = SkillPanel.new()
	top.add_child(skill_panel)
	_refresh_hud()


func _refresh_hud() -> void:
	if _status == null:
		return
	var tool_text: String = tool_name(TOOLS[tool_index]) if active == farmer else ("튼튼한 사냥칼" if GameState.hunter_knife else "사냥칼")
	if active == hunter and GameState.worn[&"hunter"].has(&"weapon"):
		tool_text = Wearables.item(GameState.worn[&"hunter"][&"weapon"]).name
	if active == smith:
		tool_text = "망치"
	if active == alchemist:
		tool_text = "약탕기"
	if active == rancher:
		tool_text = "모이 바가지"
	if active == ferryman:
		tool_text = "삿대"
	if hunt:
		var buddy := hunt.companion.display_name() if hunt.companion else "혼자"
		_status.text = "%d일째 %s | %s | 도구: %s | 동행: %s | 남은 몬스터 %d | 주운 알 %d | 돈 %d원 · 잡템 %d" % [GameState.day, GameState.clock_text(GameState.minutes), Config.HUNT_ZONES[hunt.zone].name, tool_text, buddy, hunt.slimes.size(), hunt.picked.size(), GameState.money, GameState.junk]
		_hud_bar.set_chips([
			[_clock_icon(), "%d일째 %s" % [GameState.day, GameState.clock_text(GameState.minutes)]],
			[UiSkin.Icon.TOOL, tool_text], [UiSkin.Icon.CREATURE, buddy],
			[UiSkin.Icon.MONSTER, "남은 %d" % hunt.slimes.size()], [UiSkin.Icon.EGG, "%d" % hunt.picked.size()],
			[UiSkin.Icon.COIN, "%d원" % GameState.money], [UiSkin.Icon.JUNK, "%d" % GameState.junk],
		])
		return
	_status.text = "%d일째 %s | %s | 도구: %s | 돈 %d원 | 씨앗 %d  작물 %d  나물 %d | 알: 농부 %d · 사냥꾼 %d · 공급함 %d | 크리처 %d" % [
		GameState.day, GameState.clock_text(GameState.minutes), active.display_name, tool_text, GameState.money, GameState.seeds, GameState.crops, GameState.herbs,
		GameState.farmer_eggs.size(), GameState.hunter_eggs.size(), GameState.village_eggs.size(), creatures.size(),
	]
	var chips: Array = [
		[_clock_icon(), "%d일째 %s" % [GameState.day, GameState.clock_text(GameState.minutes)]],
		[UiSkin.Icon.PERSON, active.display_name], [UiSkin.Icon.TOOL, tool_text],
		[UiSkin.Icon.COIN, "%d원" % GameState.money], [UiSkin.Icon.SEED, "%d" % GameState.seeds],
		[UiSkin.Icon.RADISH, "%d" % GameState.crops], [UiSkin.Icon.HERB, "%d" % GameState.herbs],
		[UiSkin.Icon.EGG, "%d·%d·%d" % [GameState.farmer_eggs.size(), GameState.hunter_eggs.size(), GameState.village_eggs.size()]],
		[UiSkin.Icon.CREATURE, "%d" % creatures.size()],
	]
	var status_before := _status.text
	# 윗줄이 넘치지 않게 대장간 단계에 필요한 것만
	if GameState.forge_state >= 2:
		_status.text += " | 고철 %d" % GameState.scrap
	elif GameState.material > 0:
		_status.text += " | %s %d/%d" % [Config.BOSS_MATERIAL_NAME, GameState.material, Config.FORGE_COST_MATERIAL]
	if GameState.yak_state >= 1:
		_status.text += " | %s %d" % [Config.ROOT_NAME, GameState.roots]
	if GameState.yak_state == 1:
		_status.text += " · %s %d/%d" % [Config.BOSS_MATERIAL2_NAME, GameState.material2, Config.YAK_COST_MATERIAL]
	if GameState.barn_state == 1 or (GameState.barn_state == 0 and GameState.material3 > 0):
		_status.text += " | %s %d/%d" % [Config.BOSS_MATERIAL3_NAME, GameState.material3, Config.BARN_COST_MATERIAL]
	elif GameState.barn_state >= 2:
		_status.text += " | 달걀 %d" % GameState.hen_eggs
	if GameState.naru_state == 1 or (GameState.naru_state == 0 and GameState.material4 > 0):
		_status.text += " | %s %d/%d" % [Config.BOSS_MATERIAL4_NAME, GameState.material4, Config.NARU_COST_MATERIAL]
	elif GameState.naru_state >= 2:
		_status.text += " | 물고기 %d" % GameState.fish
	# 대장간 · 약방 · 축사 단계에 붙은 것은 잡템 알약 하나로 모은다
	var extra := _status.text.substr(status_before.length()).trim_prefix(" | ").replace(" | ", " · ")
	if extra != "":
		chips.append([UiSkin.Icon.JUNK, extra])
	_hud_bar.set_chips(chips)


func _clock_icon() -> int:
	return UiSkin.Icon.SUN if GameState.minutes < 18 * 60 else UiSkin.Icon.MOON
