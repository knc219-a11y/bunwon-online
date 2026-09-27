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

var farm: Farm
var farmer: Character
var hunter: Character
var incubator: Prop
var supply_box: Prop
var hunt_gate: Prop
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
var _morning_card: Control
var _morning_text: Label

var _rng := RandomNumberGenerator.new()
var _status: Label
var _message: Label


func _ready() -> void:
	GameState.reset()
	farm = Farm.new()
	# 바닥은 앞뒤 가림(z_index = 발 y)보다 항상 뒤
	farm.z_index = -1000
	add_child(farm)

	house = _add_prop("", preload("res://assets/props/house.png"), HOUSE_RECT, HOUSE_BLOCK, true)
	_add_prop("", preload("res://assets/props/tree_dangsan.png"), DANGSAN_RECT, DANGSAN_BLOCK, true)
	for cell in PERSIMMON_CELLS:
		_add_prop("", preload("res://assets/props/tree_persimmon.png"), Rect2i(cell, Vector2i.ONE), PERSIMMON_BLOCK, true)
	# 부화기·공급함·사냥터 입구는 키가 낮아 차지하는 칸 전체를 막는다
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


func _add_character(display_name: String, sheet: Texture2D, cell: Vector2i) -> Character:
	var c := Character.new()
	c.display_name = display_name
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


func _process(_delta: float) -> void:
	update_fading()


## 캐릭터·크리처가 집·나무 그림 뒤에 가려지면 그 그림을 반투명하게 한다.
func update_fading() -> void:
	for p in props:
		if not p.fade_behind:
			continue
		var pic := Rect2(p.picture_rect().position + p.position, p.picture_rect().size)
		var hidden := false
		for c: Character in [farmer, hunter]:
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
	if sleeping:
		if _morning_card.visible:
			wake_up()
		return
	if near_door() and _carried_creature() == null:
		go_to_sleep()
		return
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
			GameState.notify("알을 부화기에 넣었다. 하룻밤 자고 나면 부화한다 (집 현관에서 F).")


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
	_morning_text.text = "%d일째 아침\n\n%s\n\nF 일어나기" % [GameState.day, "\n".join(lines)]
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
	var lines: Array[String] = []
	var grown := farm.advance_day()
	if grown > 0:
		lines.append("밤사이 작물 %d개가 자랐다." % grown)
	var ripe := farm.ripe_count()
	if ripe > 0:
		lines.append("수확할 수 있는 작물 %d개." % ripe)
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
	help.text = "이동 WASD · 도구 Space · 도구 변경 Q/E · 상호작용 F · 크리처 일 R · 캐릭터 전환 Tab · 잠자기 집 현관 F"
	layer.add_child(help)
	# 잠잘 때 화면 전체를 덮는 밤 색. 평소에는 투명.
	_night = ColorRect.new()
	_night.color = Color(0.05, 0.06, 0.18, 0.0)
	_night.size = Vector2(640, 360)
	_night.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_night)
	_morning_card = ColorRect.new()
	(_morning_card as ColorRect).color = Color(0.99, 0.95, 0.85)
	_morning_card.size = Vector2(300, 150)
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
	_refresh_hud()


func _refresh_hud() -> void:
	if _status == null:
		return
	var tool_text: String = TOOL_NAMES[TOOLS[tool_index]] if active == farmer else "-"
	_status.text = "%d일째 | %s | 도구: %s | 씨앗 %d  작물 %d | 알: 농부 %d · 사냥꾼 %d · 공급함 %d | 크리처 %d" % [
		GameState.day, active.display_name, tool_text, GameState.seeds, GameState.crops,
		GameState.farmer_eggs.size(), GameState.hunter_eggs.size(), GameState.village_eggs.size(), creatures.size(),
	]
