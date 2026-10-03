class_name SkillPanel
extends Control
## 사냥꾼 스킬 창 (2026-10-02 사용자 선택 B: 무기 트리 셋 + 조련). T 키로 어디서나 연다 (사냥터에선 멈춤).
## 마우스: 스킬 칸 클릭 = 한 단계 찍기. 키보드: WASD 칸 고르기, F = 찍기, T 또는 Esc 닫기.
## 2026-10-03 직업 · 스탯: 맨 아래 줄은 스탯 (힘 · 솜씨 · 지혜 · 교감, 트리 칸 아래 같은 자리). 자기 직업이 아닌 무기 트리는 흐리게.
## 2026-10-03 농사 레벨 (백로그 9): 위 탭 [사냥 | 농사]. Tab 또는 탭 클릭으로 바꾼다. 농사 쪽은 FarmSkills.TREES (세 갈래), 스탯 줄 자리에 경험치 막대.
## 2026-10-03 대장장이 레벨 (백로그 10): 대장간을 고치면 탭 [대장] 이 붙는다 (SmithSkills, 농사와 같은 모양). 농사 · 대장을 "직업 쪽" 이라 부른다.

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

## 고른 칸 (x = 트리, y = 스킬. y == rows() 면 스탯 줄)
var cursor := Vector2i(0, 0)
## 보고 있는 쪽: &"hunt" 사냥꾼 · &"farm" 농사 · &"smith" 대장
var page := &"hunt"
const TAB_W := 52.0
const PAGE_NAMES := {&"hunt": "사냥", &"farm": "농사", &"smith": "대장"}


## 탭에 보이는 쪽들 (대장은 대장간을 고친 뒤)
static func pages() -> Array[StringName]:
	var out: Array[StringName] = [&"hunt", &"farm"]
	if GameState.forge_state == 2:
		out.append(&"smith")
	return out


## 직업 쪽 (농사 · 대장) 인지. 이름은 옛 그대로 farm_page.
func farm_page() -> bool:
	return page != &"hunt"


## 직업 쪽의 기술 스크립트 (FarmSkills · SmithSkills: TREES · level · points · rank · why_not · learn · progress · xp_to_next)
func job() -> GDScript:
	return SmithSkills if page == &"smith" else FarmSkills


func job_points(p: StringName) -> int:
	match p:
		&"farm":
			return GameState.farm_points
		&"smith":
			return GameState.smith_points
	return GameState.skill_points + GameState.stat_points


## 지금 쪽의 트리들
func trees() -> Array[Dictionary]:
	return job().TREES if farm_page() else HunterSkills.TREES


## 탭 [사냥 | 농사 | 대장] 자리 (창 오른쪽 위 제목 줄 아래가 아니라 제목 왼쪽)
func tab_rect(i: int) -> Rect2:
	return Rect2(Vector2(6 + i * (TAB_W + 2), 4), Vector2(TAB_W, 14))


func set_page(p: StringName) -> void:
	page = p
	cursor = Vector2i(0, 0)
	queue_redraw()
## 스탯 줄을 트리 아래 조금 띄운다
const STAT_GAP := 8.0


## 스킬 줄 수 (가장 긴 트리)
static func rows() -> int:
	var n := 0
	for t in HunterSkills.TREES:
		n = maxi(n, t.skills.size())
	return n


func on_stat_row() -> bool:
	return cursor.y == rows()


func _init() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP


func open() -> void:
	# 보던 쪽에 찍을 포인트가 없으면 포인트가 남은 쪽부터
	if not page in pages():
		page = &"hunt"
	if job_points(page) == 0:
		for p in pages():
			if job_points(p) > 0:
				page = p
				break
	cursor = Vector2i(0, 0)
	size = Vector2(COL_W * HunterSkills.TREES.size() + 24, TOP + (rows() + 1) * ROW_H + STAT_GAP + 54)
	position = ((Vector2(640, 360) - size) / 2 + Vector2(0, 6)).round()
	visible = true
	queue_redraw()


func close() -> void:
	visible = false


func skill_at(c: Vector2i) -> Dictionary:
	if c.x < 0 or c.x >= trees().size():
		return {}
	var sk: Array = trees()[c.x].skills
	return sk[c.y] if c.y >= 0 and c.y < sk.size() else {}


## 쪽마다 트리가 몇 개든 가운데 맞춤 (사냥 넷 · 농사 셋)
func _x0() -> float:
	return (size.x - COL_W * trees().size()) / 2


func cell_rect(c: Vector2i) -> Rect2:
	var x0 := _x0()
	if c.y >= rows() and not farm_page():
		x0 = (size.x - COL_W * HunterSkills.TREES.size()) / 2
	var cx := x0 + c.x * COL_W + COL_W / 2
	return Rect2(Vector2(cx - CELL.x / 2, TOP + c.y * ROW_H + (STAT_GAP if c.y >= rows() else 0.0)), CELL)


## 고른 칸을 한 단계 찍는다. 못 찍으면 까닭을 알린다.
func learn_cursor() -> bool:
	if farm_page():
		var fs := skill_at(cursor)
		if fs.is_empty():
			return false
		var fwhy: String = job().why_not(fs.id)
		if fwhy != "":
			GameState.notify("%s: %s" % [fs.name, fwhy])
			return false
		job().learn(fs.id)
		Sound.sfx(&"hatch", 0.0, 1.3)
		GameState.notify("%s %d단계를 찍었다. 남은 %s 포인트 %d." % [fs.name, job().rank(fs.id), PAGE_NAMES[page], job().points()])
		queue_redraw()
		return true
	if on_stat_row():
		var st: Dictionary = HunterClass.STATS[cursor.x]
		if not HunterClass.spend(st.id):
			GameState.notify("%s: 스탯 포인트 없음" % st.name)
			return false
		Sound.sfx(&"hatch", 0.0, 1.3)
		GameState.notify("%s %d (남은 스탯 포인트 %d). %s." % [st.name, HunterClass.stat(st.id), GameState.stat_points, st.desc])
		queue_redraw()
		return true
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
	var ts := trees()
	if event.is_action_pressed("outfit_swap"):
		var ps := pages()
		set_page(ps[(ps.find(page) + 1) % ps.size()])
		return
	if event.is_action_pressed("move_left"):
		cursor.x = (cursor.x - 1 + ts.size()) % ts.size()
	elif event.is_action_pressed("move_right"):
		cursor.x = (cursor.x + 1) % ts.size()
	elif event.is_action_pressed("move_up"):
		cursor.y = maxi(cursor.y - 1, 0)
	elif event.is_action_pressed("move_down"):
		if farm_page():
			cursor.y = mini(cursor.y + 1, ts[cursor.x].skills.size() - 1)
		else:
			cursor.y = rows() if cursor.y >= ts[cursor.x].skills.size() - 1 else cursor.y + 1
	elif event.is_action_pressed("interact") or event.is_action_pressed("use_tool"):
		learn_cursor()
	if not farm_page() and on_stat_row():
		cursor.x = mini(cursor.x, HunterClass.STATS.size() - 1)
	elif event.is_action_pressed("move_up") and cursor.y >= ts[cursor.x].skills.size():
		cursor.y = ts[cursor.x].skills.size() - 1
	else:
		cursor.y = mini(cursor.y, ts[cursor.x].skills.size() - 1)
	queue_redraw()


## 마우스 아래 칸 (스킬 · 스탯), 없으면 (-1, -1)
func cell_at(p: Vector2) -> Vector2i:
	for ti in trees().size():
		for si in trees()[ti].skills.size():
			if cell_rect(Vector2i(ti, si)).has_point(p):
				return Vector2i(ti, si)
	if farm_page():
		return Vector2i(-1, -1)
	for ti in HunterClass.STATS.size():
		if cell_rect(Vector2i(ti, rows())).has_point(p):
			return Vector2i(ti, rows())
	return Vector2i(-1, -1)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var ps := pages()
		for i in ps.size():
			if tab_rect(i).has_point(event.position):
				set_page(ps[i])
				accept_event()
				return
		var c := cell_at(event.position)
		if c.x >= 0:
			cursor = c
			learn_cursor()
			accept_event()
	elif event is InputEventMouseMotion:
		var c := cell_at(event.position)
		if c.x >= 0 and cursor != c:
			cursor = c
			queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, size), EDGE)
	draw_rect(Rect2(Vector2(2, 2), size - Vector2(4, 4)), PAPER)
	_draw_tabs(font)
	if farm_page():
		_draw_farm(font)
		return
	draw_string(font, Vector2(tab_rect(pages().size() - 1).end.x + 6, 14), "%s · Tab" % HunterClass.class_name_of(GameState.hunter_class), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, INK)
	var right := "Lv %d · 스킬 포인트 %d · 스탯 %d" % [GameState.hunter_level, GameState.skill_points, GameState.stat_points]
	draw_string(font, Vector2(size.x - 8 - font.get_string_size(right, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x, 14), right, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, GOLD.darkened(0.25) if GameState.skill_points > 0 or GameState.stat_points > 0 else SUB)
	var weapon_kind: StringName = Wearables.weapon().kind
	for ti in HunterSkills.TREES.size():
		var t: Dictionary = HunterSkills.TREES[ti]
		var first := cell_rect(Vector2i(ti, 0))
		var tab := Rect2(first.get_center().x - COL_W / 2 + 3, 22, COL_W - 6, 15)
		var open := HunterClass.tree_open(t.id)
		draw_rect(tab, (t.color as Color).lerp(PAPER, 0.55) if open else LOCK)
		draw_string(font, Vector2(tab.position.x, 33), t.name, HORIZONTAL_ALIGNMENT_CENTER, tab.size.x, 10, INK if open else SUB)
		for si in t.skills.size():
			var s: Dictionary = t.skills[si]
			var r := cell_rect(Vector2i(ti, si))
			if si > 0:
				var a := cell_rect(Vector2i(ti, si - 1))
				draw_line(Vector2(a.get_center().x, a.end.y), Vector2(r.get_center().x, r.position.y), EDGE, 1.0)
			var rank := HunterSkills.rank(s.id)
			var locked: bool = s.req > GameState.hunter_level or not open
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
			var sub := ("Lv %d" % s.req) if s.req > GameState.hunter_level else ("%d/%d" % [rank, s.max])
			if not open:
				sub = "다른 직업"
			if tag != "":
				sub += " · " + tag
			draw_string(font, Vector2(r.position.x, r.position.y + 25), sub, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 9, SUB if locked or rank == 0 else INK)
	# 스탯 줄 (트리 칸 아래 같은 자리: 힘 · 솜씨 · 지혜 · 교감)
	for ti in HunterClass.STATS.size():
		var st: Dictionary = HunterClass.STATS[ti]
		var r := cell_rect(Vector2i(ti, rows()))
		draw_rect(r, EDGE)
		draw_rect(r.grow(-1), SLOT_BG if HunterClass.stat(st.id) == 0 else GOLD.lerp(PAPER, 0.6))
		if cursor == Vector2i(ti, rows()):
			draw_rect(r.grow(1), GOLD, false, 2.0)
		draw_string(font, Vector2(r.position.x, r.position.y + 12), st.name, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 10, INK)
		draw_string(font, Vector2(r.position.x, r.position.y + 25), str(HunterClass.stat(st.id)), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 9, INK)
	if on_stat_row():
		var st: Dictionary = HunterClass.STATS[cursor.x]
		var y := size.y - 48
		draw_rect(Rect2(8, y, size.x - 16, 42), SLOT_BG)
		draw_string(font, Vector2(12, y + 12), "%s %d · 스탯 (레벨업마다 %d점)" % [st.name, HunterClass.stat(st.id), Config.STAT_POINTS_PER_LEVEL], HORIZONTAL_ALIGNMENT_LEFT, size.x - 24, 10, INK)
		draw_string(font, Vector2(12, y + 25), "1점마다: %s" % st.desc, HORIZONTAL_ALIGNMENT_LEFT, size.x - 24, 9, SUB)
		draw_string(font, Vector2(12, y + 37), "초기화 · 직업 바꾸기: 사냥터 입구 (첫 번 공짜, 그 뒤 Lv x %d원)" % Config.RESPEC_PRICE_PER_LV, HORIZONTAL_ALIGNMENT_LEFT, size.x - 24, 9, SUB)
		return
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


## 위 탭 [사냥 | 농사 | 대장]. 찍을 포인트가 남은 쪽은 금색 점
func _draw_tabs(font: Font) -> void:
	var ps := pages()
	for i in ps.size():
		var r := tab_rect(i)
		var on: bool = ps[i] == page
		draw_rect(r, EDGE)
		draw_rect(r.grow(-1), GOLD.lerp(PAPER, 0.55) if on else SLOT_BG)
		draw_string(font, Vector2(r.position.x, r.position.y + 11), PAGE_NAMES[ps[i]], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 10, INK if on else SUB)
		if job_points(ps[i]) > 0:
			draw_circle(r.end - Vector2(5, 7), 2.0, GOLD.darkened(0.2))


## 직업 쪽 (농사 · 대장): 세 갈래 트리 (Lv 1 · 4 · 8 · 12) + 아래 경험치 막대 · 고른 기술 설명
func _draw_farm(font: Font) -> void:
	var j := job()
	var label: String = PAGE_NAMES[page]
	var smith := page == &"smith"
	var lv: int = j.level()
	var pts: int = j.points()
	var trees_j: Array = j.TREES
	draw_string(font, Vector2(tab_rect(pages().size() - 1).end.x + 6, 14), "Tab", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, INK)
	var right := "%s Lv %d · %s 포인트 %d" % [label, lv, label, pts]
	draw_string(font, Vector2(size.x - 8 - font.get_string_size(right, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x, 14), right, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, GOLD.darkened(0.25) if pts > 0 else SUB)
	for ti in trees_j.size():
		var t: Dictionary = trees_j[ti]
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
			var rank: int = j.rank(s.id)
			var locked: bool = s.req > lv
			draw_rect(r, EDGE)
			draw_rect(r.grow(-1), LOCK if locked else (SLOT_BG if rank == 0 else (t.color as Color).lerp(PAPER, 0.25)))
			if cursor == Vector2i(ti, si):
				draw_rect(r.grow(1), GOLD, false, 2.0)
			draw_string(font, Vector2(r.position.x, r.position.y + 12), s.name, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 10, SUB if locked else INK)
			var sub := ("Lv %d" % s.req) if locked else ("%d/%d" % [rank, s.max])
			draw_string(font, Vector2(r.position.x, r.position.y + 25), sub, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 9, SUB if locked or rank == 0 else INK)
	# 스탯 줄 자리: 경험치 막대
	var cap: int = Config.SMITH_LEVEL_CAP if smith else Config.FARM_LEVEL_CAP
	var xp: int = GameState.smith_xp if smith else GameState.farm_xp
	var bar_y := cell_rect(Vector2i(0, rows())).position.y + 4
	var bar := Rect2(Vector2(_x0() + 6, bar_y), Vector2(COL_W * trees_j.size() - 12, 8))
	draw_rect(bar, EDGE)
	draw_rect(Rect2(bar.position + Vector2.ONE, Vector2((bar.size.x - 2) * j.progress(), bar.size.y - 2)), Color(0.85, 0.5, 0.3) if smith else Color(0.5, 0.72, 0.35))
	var xp_text := "최대 레벨" if lv >= cap else "%d / %d" % [xp, j.xp_to_next(lv)]
	var how := "주인공 · 크리처가 거둔 작물마다 ★1 %d · ★2 %d · ★3 %d" % [Config.FARM_XP_HARVEST[0], Config.FARM_XP_HARVEST[1], Config.FARM_XP_HARVEST[2]]
	if smith:
		var top := SmithSkills.top_tier()
		how = "장비 만들기 (높은 단계일수록 많이) · 갈기 · %d단계까지" % (top + 1)
		if top + 1 < Config.SMITH_TIERS.size():
			how += " (다음 Lv %d)" % Config.SMITH_TIERS[top + 1].req
	draw_string(font, Vector2(12, bar.end.y + 11), "%s 경험치 %s · %s" % [label, xp_text, how], HORIZONTAL_ALIGNMENT_CENTER, size.x - 24, 9, SUB)
	var cs := skill_at(cursor)
	if cs.is_empty():
		return
	var y := size.y - 48
	draw_rect(Rect2(8, y, size.x - 16, 42), SLOT_BG)
	var head := "%s %d/%d · %s · %s Lv %d" % [cs.name, j.rank(cs.id), cs.max, trees_j[cursor.x].name, label, cs.req]
	var why: String = j.why_not(cs.id)
	if why != "" and why != "%s 포인트 없음" % label:
		head += " · " + why
	draw_string(font, Vector2(12, y + 12), head, HORIZONTAL_ALIGNMENT_LEFT, size.x - 24, 10, INK)
	draw_string(font, Vector2(12, y + 25), cs.desc, HORIZONTAL_ALIGNMENT_LEFT, size.x - 24, 9, SUB)
	draw_string(font, Vector2(12, y + 37), "단계마다: %s" % cs.per, HORIZONTAL_ALIGNMENT_LEFT, size.x - 24, 9, SUB)
