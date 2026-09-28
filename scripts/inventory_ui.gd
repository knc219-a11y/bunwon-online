class_name InventoryUI
extends Control
## 디아블로식 가방 창 (2026-09-28 사용자 요청: "인벤토리도 디아블로식으로 그냥 따로", "창고 기능").
## I 키로 어디서나 연다 (사냥터 포함, 여는 동안 사냥터는 멈춘다). 마을 창고 궤짝에서 F를 누르면 창고 칸이 옆에 붙는다.
## 마우스: 왼쪽 클릭 = 가방 칸 입기 / 입은 칸 벗기 (창고가 열려 있으면 가방 ↔ 창고 옮기기), 오른쪽 클릭 = 입기.
## 키보드: WASD 칸 고르기, F = 왼쪽 클릭, R = 오른쪽 클릭, I 또는 Esc 닫기.
## 장비 등급 (2026-09-28 사용자 선택 A): 칸 테두리와 설명 줄이 등급색 (일반 · 마법 파랑 · 레어 노랑 · 세트 초록).
## 공급함 "가방에서 장비 팔기"로 열면 가방 칸 클릭 = 팔기 (사냥터에서 굴린 장비만).

signal wear_changed

const CELL := 26
const GAP := 2
const PAPER := Color(0.99, 0.95, 0.85)
const INK := Color(0.3, 0.2, 0.15)
const EDGE := Color(0.55, 0.38, 0.28)
const SLOT_BG := Color(0.93, 0.87, 0.74)
const CURSOR := Color(1.0, 0.72, 0.2)
## 디아블로2처럼 세트 장비는 초록
const SET_GREEN := Color(0.2, 0.6, 0.25)
## 종이 바탕 위에서 보이도록 조금 진하게 한 등급색
const RARITY_EDGE := {&"magic": Color(0.25, 0.4, 0.9), &"rare": Color(0.82, 0.6, 0.05), &"set": SET_GREEN}
const SUB := Color(0.5, 0.4, 0.32)
## 덧그림(48x48 칸)에서 칸별 아이콘으로 잘라 쓸 부분
const ICON_SRC := {&"hat": Rect2(12, 2, 24, 18), &"clothes": Rect2(10, 16, 28, 22), &"shoes": Rect2(12, 32, 24, 14)}

const DOLL_AT := Vector2(10, 24)
const EQUIP_X := 110.0
const BAG_AT := Vector2(146, 28)
const STASH_AT := Vector2(274, 28)
const BOTTOM_Y := 136.0

var character: Character
## 창고 칸이 같이 열려 있는지
var with_stash := false
## 공급함에서 장비 팔기로 열었는지
var sell_mode := false
## 고른 칸: {kind = &"equip"/&"bag"/&"stash", index}
var cursor := {kind = &"bag", index = 0}


func _init() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP


func open(c: Character, stash := false, sell := false) -> void:
	character = c
	with_stash = stash
	sell_mode = sell and not stash
	cursor = {kind = &"bag", index = 0}
	size = Vector2(STASH_AT.x + Config.STASH_COLUMNS * (CELL + GAP) + 8 if stash else BAG_AT.x + Config.BAG_COLUMNS * (CELL + GAP) + 8, 208)
	position = ((Vector2(640, 360) - size) / 2).round()
	visible = true
	queue_redraw()


func close() -> void:
	visible = false


# --- 칸 배치 ---------------------------------------------------------------

func _grid_rect(origin: Vector2, columns: int, i: int) -> Rect2:
	return Rect2(origin + Vector2(i % columns, i / columns) * (CELL + GAP), Vector2(CELL, CELL))


func cell_rect(kind: StringName, i: int) -> Rect2:
	match kind:
		&"equip":
			return Rect2(Vector2(EQUIP_X, 28 + i * (CELL + 8)), Vector2(CELL, CELL))
		&"bag":
			return _grid_rect(BAG_AT, Config.BAG_COLUMNS, i)
		_:
			return _grid_rect(STASH_AT, Config.STASH_COLUMNS, i)


func _cells() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in Wearables.SLOTS.size():
		out.append({kind = &"equip", index = i})
	for i in Config.BAG_SIZE:
		out.append({kind = &"bag", index = i})
	if with_stash:
		for i in Config.STASH_SIZE:
			out.append({kind = &"stash", index = i})
	return out


func _cell_at(p: Vector2) -> Dictionary:
	for c in _cells():
		if cell_rect(c.kind, c.index).has_point(p):
			return c
	return {}


## 칸에 든 장비 id (없으면 &"")
func item_in(kind: StringName, i: int) -> StringName:
	var who := character.who
	match kind:
		&"equip":
			return GameState.worn[who].get(Wearables.SLOTS[i], &"")
		&"bag":
			var b: Array[StringName] = GameState.bag[who]
			return b[i] if i < b.size() else &""
		_:
			return GameState.stash[i] if i < GameState.stash.size() else &""


# --- 동작 -----------------------------------------------------------------

## 왼쪽 클릭 (F): 가방 → 입기 (창고가 열려 있으면 창고로), 입은 칸 → 벗기, 창고 → 가방
func primary(kind: StringName, i: int) -> bool:
	var who := character.who
	var ok := false
	match kind:
		&"equip":
			ok = Wearables.take_off(who, Wearables.SLOTS[i])
			if not ok and item_in(kind, i) != &"":
				GameState.notify("가방과 창고가 모두 차서 벗을 수 없다.")
		&"bag":
			if sell_mode:
				var id := item_in(kind, i)
				if id != &"" and not Wearables.is_rolled(id):
					GameState.notify("%s은(는) 팔 수 없다 (사냥터에서 주운 등급 장비만 판다)." % Wearables.item(id).name)
				elif id != &"":
					var what := "%s %s" % [Wearables.RARITY_NAMES[Wearables.rarity(id)], Wearables.item(id).name]
					var price := Wearables.sell(who, i)
					ok = price > 0
					GameState.notify("%s을(를) 팔았다. +%d원" % [what, price])
			elif with_stash:
				ok = Wearables.bag_to_stash(who, i)
				if not ok and item_in(kind, i) != &"":
					GameState.notify("창고가 가득 찼다.")
			else:
				ok = _wear(i)
		_:
			ok = Wearables.stash_to_bag(who, i)
			if not ok and item_in(kind, i) != &"":
				GameState.notify("%s 가방이 가득 찼다." % character.display_name)
	_after(ok)
	return ok


## 오른쪽 클릭 (R): 가방 칸 장비를 입는다. 다른 칸은 왼쪽 클릭과 같다.
func secondary(kind: StringName, i: int) -> bool:
	if kind != &"bag":
		return primary(kind, i)
	var ok := _wear(i)
	_after(ok)
	return ok


func _wear(i: int) -> bool:
	var id := item_in(&"bag", i)
	if id == &"":
		return false
	var it := Wearables.item(id)
	if it.who != character.who:
		var owner := "농부" if it.who == &"farmer" else "사냥꾼"
		GameState.notify("%s은(는) %s 장비다. 창고에 넣어 두면 %s이(가) 꺼내 입을 수 있다." % [it.name, owner, owner])
		return false
	return Wearables.wear_from_bag(character.who, i)


func _after(ok: bool) -> void:
	if ok:
		wear_changed.emit()
	queue_redraw()


# --- 입력 -----------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var c := _cell_at(event.position)
		if not c.is_empty() and c != cursor:
			cursor = c
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed:
		var c := _cell_at(event.position)
		if c.is_empty():
			return
		cursor = c
		if event.button_index == MOUSE_BUTTON_LEFT:
			primary(c.kind, c.index)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			secondary(c.kind, c.index)
	accept_event()


## 키보드 입력 (main 이 넘겨준다)
func handle_key(event: InputEvent) -> void:
	if event.is_action_pressed("move_up"):
		move_cursor(Vector2.UP)
	elif event.is_action_pressed("move_down"):
		move_cursor(Vector2.DOWN)
	elif event.is_action_pressed("move_left"):
		move_cursor(Vector2.LEFT)
	elif event.is_action_pressed("move_right"):
		move_cursor(Vector2.RIGHT)
	elif event.is_action_pressed("interact") or event.is_action_pressed("use_tool"):
		primary(cursor.kind, cursor.index)
	elif event.is_action_pressed("creature_job"):
		secondary(cursor.kind, cursor.index)


## 그 방향에서 가장 가까운 칸으로
func move_cursor(dir: Vector2) -> void:
	var from := cell_rect(cursor.kind, cursor.index).get_center()
	var best := {}
	var best_d := INF
	for c in _cells():
		var d := cell_rect(c.kind, c.index).get_center() - from
		var along := d.dot(dir)
		if along <= 1.0:
			continue
		var score := along + absf(d.cross(dir)) * 2.0
		if score < best_d:
			best_d = score
			best = c
	if not best.is_empty():
		cursor = best
		queue_redraw()


# --- 그리기 ---------------------------------------------------------------

func _text(p: Vector2, t: String, font_size := 9, col := INK) -> void:
	draw_string(ThemeDB.fallback_font, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, col)


func _icon(id: StringName, r: Rect2) -> void:
	var item := Wearables.item(id)
	var src: Rect2 = ICON_SRC[item.slot]
	draw_texture_rect_region(item.sheet, Rect2(r.get_center() - src.size / 2, src.size), src)


func _draw() -> void:
	if character == null:
		return
	var who := character.who
	draw_rect(Rect2(Vector2.ZERO, size), PAPER)
	draw_rect(Rect2(Vector2.ZERO, size), EDGE, false, 1.0)
	_text(Vector2(10, 16), "%s 가방%s" % [character.display_name, " · 장비 팔기" if sell_mode else ""], 10)
	_text(Vector2(BAG_AT.x, 16), "가방 %d/%d" % [(GameState.bag[who] as Array).size(), Config.BAG_SIZE], 8, SUB)
	if with_stash:
		_text(Vector2(STASH_AT.x, 16), "공용 창고 %d/%d" % [GameState.stash.size(), Config.STASH_SIZE], 8, SUB)
	# 입은 모습 인형 (정면 대기 칸을 2배로)
	var doll := Rect2(DOLL_AT, Vector2(96, 96))
	draw_rect(Rect2(DOLL_AT + Vector2(0, 4), Vector2(94, 100)), Color(0.86, 0.8, 0.66))
	var src := Rect2(0, 0, Character.FRAME_SIZE, Character.FRAME_SIZE)
	draw_texture_rect_region(character.sheet, doll, src)
	for id in Wearables.worn_by(who):
		draw_texture_rect_region(Wearables.item(id).sheet, doll, src)
	for c in _cells():
		var r := cell_rect(c.kind, c.index)
		var id := item_in(c.kind, c.index)
		draw_rect(r, SLOT_BG)
		var edge := EDGE
		var width := 1.0
		if id != &"" and RARITY_EDGE.has(Wearables.rarity(id)):
			edge = RARITY_EDGE[Wearables.rarity(id)]
			width = 1.5
		draw_rect(r, edge, false, width)
		if id != &"":
			_icon(id, r)
			if Wearables.item(id).who != who and c.kind != &"stash":
				# 다른 캐릭터 장비는 흐리게 (들 수만 있고 입지 못함)
				draw_rect(r, Color(0.9, 0.85, 0.75, 0.55))
		elif c.kind == &"equip":
			_text(r.position + Vector2(3, 17), Wearables.SLOT_NAMES[Wearables.SLOTS[c.index]], 8, SUB)
	var cr := cell_rect(cursor.kind, cursor.index)
	draw_rect(cr.grow(1), CURSOR, false, 2.0)
	# 세트 (입은 조각이 하나라도 있을 때)
	var y := BOTTOM_Y
	for set_id: StringName in Wearables.SETS:
		var n := Wearables.set_worn_count(set_id, who)
		if n == 0:
			continue
		var s: Dictionary = Wearables.SETS[set_id]
		y += 12
		var done: bool = n == s.pieces.size()
		_text(Vector2(10, y), "%s %d/%d · %s%s" % [s.name, n, s.pieces.size(), "보너스 " if done else "다 입으면 ", s.effect], 9, SET_GREEN)
	# 고른 칸 설명
	var picked := item_in(cursor.kind, cursor.index)
	y += 13
	var picked_col: Color = RARITY_EDGE.get(Wearables.rarity(picked), INK) if picked != &"" else INK
	var picked_text := Wearables.describe(picked) if picked != &"" else ""
	if sell_mode and picked != &"" and Wearables.is_rolled(picked) and cursor.kind == &"bag":
		picked_text += " · %d원" % Wearables.sell_price(picked)
	# 옵션이 많아 창보다 길면 이름과 효과를 두 줄로 나눈다
	var cut := picked_text.find(") · ")
	if cut >= 0 and ThemeDB.fallback_font.get_string_size(picked_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x > size.x - 20:
		_text(Vector2(10, y), picked_text.substr(0, cut + 1), 9, picked_col)
		y += 12
		_text(Vector2(18, y), picked_text.substr(cut + 4), 9, picked_col)
	else:
		_text(Vector2(10, y), picked_text, 9, picked_col)
		y += 12
	y += 13
	_text(Vector2(10, y), "물약 %d · 젤리 %d · 씨앗 %d · 무 %d · 돈 %d원" % [GameState.potions, GameState.junk, GameState.seeds, GameState.crops, GameState.money], 8, SUB)
	var help := "클릭: 창고로 넣기/꺼내기 · 오른쪽 클릭(R): 입기 · 입은 칸 클릭: 벗기 · I 닫기" if with_stash else "클릭(F): 입기/벗기 · WASD 칸 고르기 · I 닫기"
	if sell_mode:
		help = "클릭(F): 팔기 (사냥터 등급 장비만) · 오른쪽 클릭(R): 입기 · I 닫기"
	_text(Vector2(10, size.y - 6), help, 8, SUB)
