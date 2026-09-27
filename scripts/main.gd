extends Node2D
## 프로토타입 메인 화면.
## 흐름: 농부 직접 농사 → 사냥꾼이 알 획득 → 마을 공급함 → 농부가 부화 → 슬라임 배치로 자동화.

const TOOLS: Array[Farm.Work] = [Farm.Work.TILL, Farm.Work.SOW, Farm.Work.WATER, Farm.Work.HARVEST]
const TOOL_NAMES := {
	Farm.Work.TILL: "괭이",
	Farm.Work.SOW: "씨앗",
	Farm.Work.WATER: "물뿌리개",
	Farm.Work.HARVEST: "수확",
}
const INCUBATOR_CELL := Vector2i(15, 3)
const SUPPLY_CELL := Vector2i(15, 7)
const HUNT_GATE_CELL := Vector2i(18, 5)

var farm: Farm
var farmer: Character
var hunter: Character
var incubator: Prop
var supply_box: Prop
var hunt_gate: Prop
var slimes: Array[Slime] = []
var active: Character
var tool_index := 0
## 부화기에 든 알이 부화하기까지 남은 날. -1 이면 비어 있음.
var incubating_days := -1

var _rng := RandomNumberGenerator.new()
var _status: Label
var _message: Label


func _ready() -> void:
	GameState.reset()
	farm = Farm.new()
	add_child(farm)

	incubator = _add_prop("부화기", Color("e9d8a6"), INCUBATOR_CELL)
	supply_box = _add_prop("마을 공급함", Color("c08552"), SUPPLY_CELL)
	hunt_gate = _add_prop("사냥터 입구", Color("5c4d7d"), HUNT_GATE_CELL, Vector2(20, 48))

	farmer = _add_character("농부", Color("8d99ae"), Vector2i(7, 1))
	hunter = _add_character("사냥꾼", Color("6a994e"), Vector2i(16, 5))
	_set_active(farmer)

	_build_hud()
	GameState.changed.connect(_refresh_hud)
	GameState.message.connect(func(t: String) -> void: _message.text = t)
	_refresh_props()
	GameState.notify("농부로 밭을 가꿔 보자. 사냥꾼은 사냥터 입구에서 알을 구해 온다.")


func _add_prop(label: String, color: Color, cell: Vector2i, size := Vector2(28, 28)) -> Prop:
	var p := Prop.new()
	p.label = label
	p.color = color
	p.size = size
	p.position = Farm.center_of(cell)
	add_child(p)
	return p


func _add_character(display_name: String, color: Color, cell: Vector2i) -> Character:
	var c := Character.new()
	c.display_name = display_name
	c.body_color = color
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
	elif event.is_action_pressed("slime_role"):
		change_slime_role()
	elif event.is_action_pressed("next_day"):
		next_day()
	elif event.is_action_pressed("tool_next"):
		cycle_tool(1)
	elif event.is_action_pressed("tool_prev"):
		cycle_tool(-1)


# --- 플레이어 동작 ---------------------------------------------------------

func switch_character() -> void:
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
	var carried := _carried_slime()
	if carried:
		carried.place(farmer.cell())
		GameState.notify("슬라임을 내려놓았다. R 키로 맡길 일을 고른다.")
		return
	var s := _nearest_slime()
	if s:
		s.pick_up(farmer)
		GameState.notify("슬라임을 들었다. 원하는 자리에서 다시 F.")
	elif _near(supply_box):
		if GameState.village_eggs == 0:
			GameState.notify("마을 공급함이 비어 있다. 사냥꾼이 알을 가져와야 한다.")
			return
		GameState.farmer_eggs += GameState.village_eggs
		GameState.village_eggs = 0
		GameState.notify("마을 공급함에서 알을 받았다. 부화기에 넣어 보자.")
	elif _near(incubator):
		if incubating_days >= 0:
			GameState.notify("알이 부화 중이다. %d일 남았다." % incubating_days)
		elif GameState.farmer_eggs == 0:
			GameState.notify("넣을 알이 없다.")
		else:
			GameState.farmer_eggs -= 1
			incubating_days = Config.EGG_HATCH_DAYS
			GameState.notify("알을 부화기에 넣었다. 하루가 지나면 부화한다 (N).")


func _hunter_interact() -> void:
	if _near(hunt_gate):
		if GameState.hunts_today >= Config.HUNTS_PER_DAY:
			GameState.notify("오늘은 이미 사냥을 다녀왔다.")
			return
		# 전투 구현 전 대체 동작: 사냥을 다녀오면 알 1개를 얻는다.
		GameState.hunts_today += 1
		GameState.hunter_eggs += 1
		GameState.notify("사냥을 다녀와 슬라임 알을 얻었다! 마을 공급함에 넣자.")
	elif _near(supply_box):
		if GameState.hunter_eggs == 0:
			GameState.notify("공급할 알이 없다. 사냥터 입구로 가자.")
			return
		GameState.village_eggs += GameState.hunter_eggs
		GameState.hunter_eggs = 0
		GameState.notify("마을 공급함에 알을 넣었다. 농부가 받아 갈 수 있다.")
	else:
		GameState.notify("사냥터 입구나 마을 공급함 가까이에서 F.")


func change_slime_role() -> void:
	var s := _nearest_slime()
	if s == null or active != farmer:
		GameState.notify("농부로 슬라임 가까이에서 R.")
		return
	s.next_role()
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
		var s := _hatch(INCUBATOR_CELL + Vector2i(-1, 1))
		text += " 알이 부화했다! " + s.describe()
	_refresh_props()
	GameState.notify(text)


func _hatch(at_cell: Vector2i) -> Slime:
	var s := Slime.new()
	add_child(s)
	s.setup(farm, at_cell, _rng)
	slimes.append(s)
	return s


# --- 보조 ------------------------------------------------------------------

func _near(node: Node2D) -> bool:
	return active.position.distance_to(node.position) <= Config.INTERACT_DISTANCE


func _nearest_slime() -> Slime:
	var best: Slime = null
	var best_d := Config.INTERACT_DISTANCE
	for s in slimes:
		var d := farmer.position.distance_to(s.position)
		if d <= best_d:
			best_d = d
			best = s
	return best


func _carried_slime() -> Slime:
	for s in slimes:
		if s.carried_by != null:
			return s
	return null


func _refresh_props() -> void:
	incubator.set_badge("부화 중 (%d일)" % incubating_days if incubating_days >= 0 else "")
	supply_box.set_badge("알 %d" % GameState.village_eggs if GameState.village_eggs > 0 else "")


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
	help.text = "이동 WASD · 도구 Space · 도구 변경 Q/E · 상호작용 F · 슬라임 역할 R · 캐릭터 전환 Tab · 다음 날 N"
	layer.add_child(help)
	_refresh_hud()


func _refresh_hud() -> void:
	if _status == null:
		return
	var tool_text: String = TOOL_NAMES[TOOLS[tool_index]] if active == farmer else "-"
	_status.text = "%d일째 | %s | 도구: %s | 씨앗 %d  작물 %d | 알: 농부 %d · 사냥꾼 %d · 공급함 %d | 슬라임 %d" % [
		GameState.day, active.display_name, tool_text, GameState.seeds, GameState.crops,
		GameState.farmer_eggs, GameState.hunter_eggs, GameState.village_eggs, slimes.size(),
	]
