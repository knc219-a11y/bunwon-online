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
## 마을 오브젝트가 차지하는 칸 (왼쪽 위 칸, 크기). 크기는 2026-09-27 결정, 자리는 임시 배치.
const INCUBATOR_RECT := Rect2i(17, 3, 2, 2)
const SUPPLY_RECT := Rect2i(17, 9, 2, 1)
const HUNT_GATE_RECT := Rect2i(21, 3, 3, 2)
## 배경 오브젝트 (2026-09-27 결정: 집 B 양옥, 나무 감나무 + 당산나무 하나). 자리는 임시 배치. 아직 충돌 없음.
const HOUSE_RECT := Rect2i(20, 8, 5, 4)
const DANGSAN_RECT := Rect2i(13, 11, 2, 2)
const PERSIMMON_CELLS: Array[Vector2i] = [Vector2i(2, 12), Vector2i(7, 12), Vector2i(11, 12), Vector2i(15, 3), Vector2i(25, 6)]
## 알이 부화하면 크리처가 나타나는 칸 (부화기 왼쪽 아래)
const HATCH_CELL := Vector2i(16, 5)

var farm: Farm
var farmer: Character
var hunter: Character
var incubator: Prop
var supply_box: Prop
var hunt_gate: Prop
var creatures: Array[Creature] = []
var active: Character
var tool_index := 0
## 부화기에 든 알이 부화하기까지 남은 날. -1 이면 비어 있음.
var incubating_days := -1
var incubating_species: CreatureSpecies

var _rng := RandomNumberGenerator.new()
var _status: Label
var _message: Label


func _ready() -> void:
	GameState.reset()
	farm = Farm.new()
	add_child(farm)

	_add_prop("", preload("res://assets/props/house.png"), HOUSE_RECT)
	_add_prop("", preload("res://assets/props/tree_dangsan.png"), DANGSAN_RECT)
	for cell in PERSIMMON_CELLS:
		_add_prop("", preload("res://assets/props/tree_persimmon.png"), Rect2i(cell, Vector2i.ONE))
	incubator = _add_prop("부화기", preload("res://assets/props/incubator.png"), INCUBATOR_RECT)
	supply_box = _add_prop("마을 공급함", preload("res://assets/props/supply_box.png"), SUPPLY_RECT)
	hunt_gate = _add_prop("사냥터 입구", preload("res://assets/props/hunt_gate.png"), HUNT_GATE_RECT)

	farmer = _add_character("농부", preload("res://assets/characters/player.png"), Vector2i(14, 6))
	hunter = _add_character("사냥꾼", preload("res://assets/characters/hunter.png"), Vector2i(20, 6))
	_set_active(farmer)

	_build_hud()
	GameState.changed.connect(_refresh_hud)
	GameState.message.connect(func(t: String) -> void: _message.text = t)
	_refresh_props()
	GameState.notify("농부로 밭을 가꿔 보자. 마을 공급함에 알이 하나 있다.")


func _add_prop(label: String, texture: Texture2D, rect: Rect2i) -> Prop:
	var p := Prop.new()
	p.label = label
	p.texture = texture
	p.place(rect.position, rect.size)
	add_child(p)
	return p


func _add_character(display_name: String, sheet: Texture2D, cell: Vector2i) -> Character:
	var c := Character.new()
	c.display_name = display_name
	c.sheet = sheet
	c.position = Farm.center_of(cell)
	add_child(c)
	return c


func _set_active(c: Character) -> void:
	if active:
		active.active = false
	active = c
	active.active = true
	GameState.touch()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed("switch_character"):
		switch_character()
	elif event.is_action_pressed("use_tool"):
		use_tool()
	elif event.is_action_pressed("interact"):
		interact()
	elif event.is_action_pressed("creature_job"):
		change_creature_job()
	elif event.is_action_pressed("next_day"):
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
	_set_active(hunter if active == farmer else farmer)
	GameState.notify("%s(으)로 전환했다." % active.display_name)


func cycle_tool(step: int) -> void:
	tool_index = wrapi(tool_index + step, 0, TOOLS.size())
	GameState.touch()


func use_tool() -> void:
	if active != farmer:
		GameState.notify("농사 도구는 농부만 쓸 수 있다.")
		return
	var work := TOOLS[tool_index]
	if not farm.do_work(work, farmer.facing_cell()):
		if work == Farm.Work.SOW and GameState.seeds <= 0:
			GameState.notify("씨앗이 없다.")
		else:
			GameState.notify("여기서는 %s을(를) 쓸 수 없다." % TOOL_NAMES[work])


func interact() -> void:
	if active == farmer:
		_farmer_interact()
	else:
		_hunter_interact()
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
	elif _near(supply_box):
		if GameState.village_eggs.is_empty():
			GameState.notify("마을 공급함이 비어 있다. 사냥꾼이 알을 가져와야 한다.")
			return
		GameState.farmer_eggs.append_array(GameState.village_eggs)
		GameState.village_eggs.clear()
		GameState.notify("마을 공급함에서 알을 받았다. 부화기에 넣어 보자.")
	elif _near(incubator):
		if incubating_days >= 0:
			GameState.notify("알이 부화 중이다. %d일 남았다." % incubating_days)
		elif GameState.farmer_eggs.is_empty():
			GameState.notify("넣을 알이 없다.")
		else:
			incubating_species = GameState.farmer_eggs.pop_front()
			incubating_days = Config.EGG_HATCH_DAYS
			GameState.notify("알을 부화기에 넣었다. 하루가 지나면 부화한다 (N).")


func _hunter_interact() -> void:
	if _near(hunt_gate):
		if GameState.hunts_today >= Config.HUNTS_PER_DAY:
			GameState.notify("오늘은 이미 사냥을 다녀왔다.")
			return
		# 전투 구현 전 대체 동작: 사냥을 다녀오면 알 1개를 얻는다.
		GameState.hunts_today += 1
		var table := CreatureCatalog.HUNT_TABLE
		var egg := table[_rng.randi_range(0, table.size() - 1)]
		GameState.hunter_eggs.append(egg)
		GameState.notify("사냥을 다녀와 %s 알을 얻었다! 마을 공급함에 넣자." % egg.display_name)
	elif _near(supply_box):
		if GameState.hunter_eggs.is_empty():
			GameState.notify("공급할 알이 없다. 사냥터 입구로 가자.")
			return
		GameState.village_eggs.append_array(GameState.hunter_eggs)
		GameState.hunter_eggs.clear()
		GameState.notify("마을 공급함에 알을 넣었다. 농부가 받아 갈 수 있다.")
	else:
		GameState.notify("사냥터 입구나 마을 공급함 가까이에서 F.")


func change_creature_job() -> void:
	var s := _nearest_creature()
	if s == null or active != farmer:
		GameState.notify("농부로 크리처 가까이에서 R.")
		return
	s.next_job()
	GameState.notify(s.describe())


## 하루를 넘긴다. 강제 취침 없이 원할 때 넘긴다.
func next_day() -> void:
	GameState.day += 1
	GameState.hunts_today = 0
	farm.advance_day()
	if incubating_days > 0:
		incubating_days -= 1
	var text := "%d일째 아침." % GameState.day
	if incubating_days == 0:
		incubating_days = -1
		var s := _hatch(incubating_species, HATCH_CELL)
		incubating_species = null
		text += " 알이 부화했다! " + s.describe() + " F로 들어서 밭 옆에 놓아 주자."
	_refresh_props()
	GameState.notify(text)


func _hatch(species: CreatureSpecies, at_cell: Vector2i) -> Creature:
	var data := CreatureData.hatch(species, _rng)
	var s := Creature.new()
	if creatures.is_empty():
		# 첫 크리처는 급수 담당, 최저 능력치 보장 (2026-09-27 결정)
		data.guarantee_minimum(Config.FIRST_CREATURE_MIN_WORK_SPEED, Config.FIRST_CREATURE_MIN_RADIUS)
		s.job = CreatureCatalog.FIRST_JOB
		data.set_element(CreatureCatalog.FIRST_ELEMENT)
	add_child(s)
	s.setup(farm, data, at_cell)
	creatures.append(s)
	return s


# --- 보조 ------------------------------------------------------------------

func _near(prop: Prop) -> bool:
	return prop.is_near(active.position, Config.PROP_INTERACT_DISTANCE)


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
	supply_box.set_badge("알 %d" % GameState.village_eggs.size() if not GameState.village_eggs.is_empty() else "")


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
	help.text = "이동 WASD · 도구 Space · 도구 변경 Q/E · 상호작용 F · 크리처 일 R · 캐릭터 전환 Tab · 다음 날 N"
	layer.add_child(help)
	_refresh_hud()


func _refresh_hud() -> void:
	if _status == null:
		return
	var tool_text: String = TOOL_NAMES[TOOLS[tool_index]] if active == farmer else "-"
	_status.text = "%d일째 | %s | 도구: %s | 씨앗 %d  작물 %d | 알: 농부 %d · 사냥꾼 %d · 공급함 %d | 크리처 %d" % [
		GameState.day, active.display_name, tool_text, GameState.seeds, GameState.crops,
		GameState.farmer_eggs.size(), GameState.hunter_eggs.size(), GameState.village_eggs.size(), creatures.size(),
	]
