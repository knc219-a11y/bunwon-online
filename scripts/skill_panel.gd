class_name SkillPanel
extends Control
## 사냥꾼 스킬 창 (2026-10-02 사용자 선택 B: 무기 트리 셋 + 조련). T 키로 어디서나 연다 (사냥터에선 멈춤).
## 마우스: 스킬 칸 클릭 = 한 단계 찍기. 키보드: WASD 칸 고르기, F = 찍기, T 또는 Esc 닫기.

const PAPER := Color(0.99, 0.95, 0.85)
const INK := Color(0.3, 0.2, 0.15)
const EDGE := Color(0.55, 0.38, 0.28)
const SLOT_BG := Color(0.93, 0.87, 0.74)
const SUB := Color(0.5, 0.4, 0.32)
const LOCK := Color(0.78, 0.72, 0.62)
const GOLD := Color(0.95, 0.68, 0.15)
const CELL := Vector2(64, 30)
const COL_W := 100.0
const ROW_H := 38.0
const TOP := 44.0

## 고른 칸 (x = 트리, y = 스킬)
var cursor := Vector2i(0, 0)


func _init() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP


func open() -> void:
	var rows := 0
	for t in HunterSkills.TREES:
		rows = maxi(rows, t.skills.size())
	size = Vector2(COL_W * HunterSkills.TREES.size() + 24, TOP + rows * ROW_H + 54)
	position = ((Vector2(640, 360) - size) / 2 + Vector2(0, 6)).round()
	visible = true
	queue_redraw()


func close() -> void:
	visible = false


func skill_at(c: Vector2i) -> Dictionary:
	if c.x < 0 or c.x >= HunterSkills.TREES.size():
		return {}
	var sk: Array = HunterSkills.TREES[c.x].skills
	return sk[c.y] if c.y >= 0 and c.y < sk.size() else {}


func cell_rect(c: Vector2i) -> Rect2:
	var x0 := (size.x - COL_W * HunterSkills.TREES.size()) / 2
	var cx := x0 + c.x * COL_W + COL_W / 2
	return Rect2(Vector2(cx - CELL.x / 2, TOP + c.y * ROW_H), CELL)


## 고른 칸을 한 단계 찍는다. 못 찍으면 까닭을 알린다.
func learn_cursor() -> bool:
	var s := skill_at(cursor)
	if s.is_empty():
		return false
	var why := HunterSkills.why_not(s.id)
	if why != "":
		GameState.notify("%s: %s" % [s.name, why])
		return false
	HunterSkills.learn(s.id)
	Sound.sfx(&"hatch", 0.0, 1.3)
	GameState.notify("%s %d단계를 찍었다. 남은 스킬 포인트 %d." % [s.name, HunterSkills.rank(s.id), GameState.skill_points])
	queue_redraw()
	return true


func handle_key(event: InputEvent) -> void:
	if event.is_action_pressed("move_left"):
		cursor.x = (cursor.x - 1 + HunterSkills.TREES.size()) % HunterSkills.TREES.size()
	elif event.is_action_pressed("move_right"):
		cursor.x = (cursor.x + 1) % HunterSkills.TREES.size()
	elif event.is_action_pressed("move_up"):
		cursor.y = maxi(cursor.y - 1, 0)
	elif event.is_action_pressed("move_down"):
		cursor.y = mini(cursor.y + 1, HunterSkills.TREES[cursor.x].skills.size() - 1)
	elif event.is_action_pressed("interact") or event.is_action_pressed("use_tool"):
		learn_cursor()
	cursor.y = mini(cursor.y, HunterSkills.TREES[cursor.x].skills.size() - 1)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for ti in HunterSkills.TREES.size():
			for si in HunterSkills.TREES[ti].skills.size():
				if cell_rect(Vector2i(ti, si)).has_point(event.position):
					cursor = Vector2i(ti, si)
					learn_cursor()
					accept_event()
					return
	elif event is InputEventMouseMotion:
		for ti in HunterSkills.TREES.size():
			for si in HunterSkills.TREES[ti].skills.size():
				if cell_rect(Vector2i(ti, si)).has_point(event.position) and cursor != Vector2i(ti, si):
					cursor = Vector2i(ti, si)
					queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, size), EDGE)
	draw_rect(Rect2(Vector2(2, 2), size - Vector2(4, 4)), PAPER)
	draw_string(font, Vector2(8, 14), "사냥꾼 스킬 (T 닫기 · 클릭/F 찍기)", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, INK)
	var right := "Lv %d · 남은 스킬 포인트 %d" % [GameState.hunter_level, GameState.skill_points]
	draw_string(font, Vector2(size.x - 8 - font.get_string_size(right, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x, 14), right, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, GOLD.darkened(0.25) if GameState.skill_points > 0 else SUB)
	var weapon_kind: StringName = Wearables.weapon().kind
	for ti in HunterSkills.TREES.size():
		var t: Dictionary = HunterSkills.TREES[ti]
		var first := cell_rect(Vector2i(ti, 0))
		var tab := Rect2(first.get_center().x - COL_W / 2 + 3, 22, COL_W - 6, 15)
		draw_rect(tab, (t.color as Color).lerp(PAPER, 0.55))
		draw_string(font, Vector2(tab.position.x, 33), t.name, HORIZONTAL_ALIGNMENT_CENTER, tab.size.x, 10, INK)
		for si in t.skills.size():
			var s: Dictionary = t.skills[si]
			var r := cell_rect(Vector2i(ti, si))
			if si > 0:
				var a := cell_rect(Vector2i(ti, si - 1))
				draw_line(Vector2(a.get_center().x, a.end.y), Vector2(r.get_center().x, r.position.y), EDGE, 1.0)
			var rank := HunterSkills.rank(s.id)
			var locked: bool = s.req > GameState.hunter_level
			var bg := LOCK if locked else (SLOT_BG if rank == 0 else (t.color as Color).lerp(PAPER, 0.25))
			draw_rect(r, EDGE)
			draw_rect(r.grow(-1), bg)
			# 왼클릭에 건 방식은 금테
			if s.kind == &"mode" and HunterSkills.left_mode(s.weapon) == s.id:
				draw_rect(r.grow(-2), GOLD.darkened(0.1), false, 1.0)
			if cursor == Vector2i(ti, si):
				draw_rect(r.grow(1), GOLD, false, 2.0)
			draw_string(font, Vector2(r.position.x, r.position.y + 12), s.name, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 10, SUB if locked else INK)
			var tag: String = {&"passive": "늘", &"right": "오른", &"order": "R", &"mode": ""}[s.kind]
			var sub := ("Lv %d" % s.req) if locked else ("%d/%d" % [rank, s.max])
			if tag != "":
				sub += " · " + tag
			draw_string(font, Vector2(r.position.x, r.position.y + 25), sub, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 9, SUB if locked or rank == 0 else INK)
	var cs := skill_at(cursor)
	if not cs.is_empty():
		var y := size.y - 48
		draw_rect(Rect2(8, y, size.x - 16, 42), SLOT_BG)
		var tree_name: String = HunterSkills.TREES[cursor.x].name
		var head := "%s %d/%d · %s · Lv %d" % [cs.name, HunterSkills.rank(cs.id), cs.max, tree_name, cs.req]
		var why := HunterSkills.why_not(cs.id)
		if why != "" and why != "스킬 포인트 없음":
			head += " · " + why
		if cs.weapon != &"" and cs.weapon != weapon_kind:
			head += " · 지금 든 무기엔 안 듦"
		draw_string(font, Vector2(12, y + 12), head, HORIZONTAL_ALIGNMENT_LEFT, size.x - 24, 10, INK)
		draw_string(font, Vector2(12, y + 25), cs.desc, HORIZONTAL_ALIGNMENT_LEFT, size.x - 24, 9, SUB)
		if cs.per != "":
			draw_string(font, Vector2(12, y + 37), "단계마다: %s" % cs.per, HORIZONTAL_ALIGNMENT_LEFT, size.x - 24, 9, SUB)
