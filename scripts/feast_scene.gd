class_name FeastScene
extends Node
## 잔치 장면 + 엔딩 크레딧 (2026-10-03 엔딩, 사용자 선택 B 잔치상 차리기). main.start_feast() 가 만든다.
## 마을 사람 일곱이 잔치상 뒤에 서고, 크리처 (일하는 크리처 · 입양 크리처) 가 잔치상 앞에 둥글게 모인다 (원래 크리처는 그동안 숨기고
## 일을 멈춘 손님 그림을 따로 세운다). 제목 → 크레딧이 올라가고, 다 올라가면 (또는 F) F 로 다음 날 아침 (main.end_feast).

## 한 번에 세우는 크리처 손님 수 (자리가 모자라지 않게)
const GUESTS_MAX := 18

var main: Node2D
var center := Vector2.ZERO
var t := 0.0
var done := false
var _layer: CanvasLayer
var _title: Label
var _credits: Label
var _hint: Label
## 크레딧 뒤 어둡게 까는 판
var _shade: ColorRect
var _guests: Array[Creature] = []
var _hidden: Array[Node2D] = []
var _people_was := {}


func begin(m: Node2D) -> void:
	main = m
	var table: Prop = main.feast_table
	center = table.position + Vector2(0, -20)
	# 사람: 잔치상 뒤 한 줄 (주인공 + 보이는 마을 사람), 다 앞을 본다
	var people: Array = ([main.player] + main.people()).filter(func(c: Character) -> bool: return c.visible)
	for i in people.size():
		var c: Character = people[i]
		_people_was[c] = c.position
		c.position = table.position + Vector2((i - (people.size() - 1) / 2.0) * 22, -34)
		c.facing = Vector2i.DOWN
		c.frozen = true
	# 크리처: 원래 것은 숨기고 손님 그림을 잔치상 앞 반원에 세운다
	var all: Array[CreatureData] = []
	for s: Creature in main.creatures + main.adoptees:
		if s.visible:
			_hidden.append(s)
			s.visible = false
		if s.expedition_zone < 0:
			all.append(s.data)
	var n := mini(all.size(), GUESTS_MAX)
	for i in n:
		var g := Creature.new()
		g.auto_work = false
		main.add_child(g)
		g.setup(main.farm, all[i], Vector2i.ZERO)
		var ang := PI * (0.12 + 0.76 * (i + 0.5) / maxf(n, 1))
		var r := 46.0 + (i % 2) * 18.0
		g.position = table.position + Vector2(-cos(ang) * r * 1.5, sin(ang) * r * 0.55 + 14)
		_guests.append(g)
	# 잔치는 저녁 (등불 · 집 불빛이 켜지는 때). 다음 날 아침이 오면 시계는 새로 돈다.
	GameState.minutes = float(Config.FEAST_MINUTE)
	main._update_dusk()
	_build_overlay()
	Sound.sfx(&"hatch", 0.0, 1.0, 0.0)


func _build_overlay() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 5
	add_child(_layer)
	_shade = ColorRect.new()
	_shade.color = Color(0.08, 0.05, 0.1, 0.0)
	_shade.size = Vector2(640, 360)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_shade)
	_title = Label.new()
	_title.text = "분원리 잔치\n\n용이 물러간 밤, 온 마을이 당산나무 앞에 모였다"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.position = Vector2(0, 54)
	_title.size = Vector2(640, 60)
	_title.add_theme_font_size_override("font_size", 16)
	_title.add_theme_color_override("font_color", Color(1, 0.94, 0.78))
	_title.add_theme_color_override("font_outline_color", Color(0.16, 0.1, 0.14))
	_title.add_theme_constant_override("outline_size", 4)
	_title.modulate.a = 0.0
	_layer.add_child(_title)
	_credits = Label.new()
	_credits.text = "\n".join(credit_lines(main))
	_credits.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_credits.size = Vector2(640, 10)
	_credits.position = Vector2(0, 360)
	_credits.add_theme_font_size_override("font_size", 10)
	_credits.add_theme_color_override("font_color", Color(1, 0.96, 0.88))
	_credits.add_theme_color_override("font_outline_color", Color(0.16, 0.1, 0.14))
	_credits.add_theme_constant_override("outline_size", 4)
	_credits.visible = false
	_layer.add_child(_credits)
	_hint = Label.new()
	_hint.text = "F 넘기기"
	_hint.position = Vector2(560, 312)
	_hint.add_theme_font_size_override("font_size", 10)
	_hint.add_theme_color_override("font_color", Color(1, 0.96, 0.86, 0.8))
	_layer.add_child(_hint)


## 크레딧 글줄 (테스트도 읽는다)
static func credit_lines(m: Node2D) -> Array[String]:
	var out: Array[String] = ["분원리 (가제)", "", "— 잔치에 모인 사람들 —"]
	var names: Array[String] = []
	for c: Character in m.people():
		if c.visible:
			names.append(c.display_name)
	out.append(" · ".join(names))
	out.append("")
	out.append("— 함께한 크리처 —")
	var kinds := {}
	for s: Creature in m.creatures + m.adoptees:
		kinds[s.data.species.display_name] = kinds.get(s.data.species.display_name, 0) + 1
	var parts: Array[String] = []
	for k: String in kinds:
		parts.append("%s %d" % [k, kinds[k]])
	for i in range(0, parts.size(), 4):
		out.append(" · ".join(parts.slice(i, i + 4)))
	out.append("일하는 크리처 %d마리 · 주민 곁의 크리처 %d마리" % [m.creatures.size(), m.adoptees.size()])
	out.append("")
	out.append("— 걸어온 길 —")
	var zones: Array[String] = []
	for z: Dictionary in Config.HUNT_ZONES:
		zones.append(z.name)
	for i in range(0, zones.size(), 5):
		out.append(" → ".join(zones.slice(i, i + 5)))
	out.append("%d일 · 사냥꾼 Lv %d · 들어준 부탁 %d번" % [GameState.day, GameState.hunter_level, GameState.requests_done])
	out.append("")
	out.append("— 만든 사람 —")
	out.append("붕어맨")
	out.append("")
	out.append("고맙습니다. 분원리의 하루는 내일도 이어집니다.")
	return out


func total_time() -> float:
	return Config.FEAST_TITLE_TIME + Config.FEAST_CREDITS_TIME


func _process(delta: float) -> void:
	t += delta
	main.camera.position = center.round()
	_title.modulate.a = clampf(t / 1.5, 0.0, 1.0) if t < Config.FEAST_TITLE_TIME else clampf(1.0 - (t - Config.FEAST_TITLE_TIME), 0.0, 1.0)
	if t >= Config.FEAST_TITLE_TIME:
		_credits.visible = true
		_shade.color.a = clampf((t - Config.FEAST_TITLE_TIME) / 1.5, 0.0, 1.0) * 0.62
		var k := clampf((t - Config.FEAST_TITLE_TIME) / Config.FEAST_CREDITS_TIME, 0.0, 1.0)
		var h := _credits.get_minimum_size().y
		_credits.position.y = lerpf(360.0, (360.0 - h) / 2.0, k)
	if t >= total_time() and not done:
		done = true
		_hint.text = "F 다음 날 아침"


## F: 아직이면 끝까지 넘기고, 끝났으면 다음 날 아침으로
func press() -> void:
	if not done:
		t = total_time()
		_process(0.0)
		return
	finish()


## 장면을 걷는다 (사람 자리 · 크리처를 되돌림). 다음 날 아침은 main.end_feast 가 띄운다.
func finish() -> void:
	for c: Character in _people_was:
		c.position = _people_was[c]
		c.frozen = false
	for s in _hidden:
		if is_instance_valid(s):
			s.visible = true
	for g in _guests:
		g.queue_free()
	_guests.clear()
	main.end_feast()
	queue_free()
