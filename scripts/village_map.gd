class_name VillageMap
extends Control
## 마을 지도 (2026-10-04 백로그 2). 사냥터 넓은 맵의 오른쪽 위 작은 지도처럼, 마을에서도
## 시설 · 밭 · 사람 · 크리처 자리를 보여 준다.
##  - 작은 지도: 오른쪽 위 (윗줄 아래)에 늘 뜬다. 마을은 처음부터 다 보이므로 가린 칸이 없다.
##  - 큰 지도: M 으로 열고 닫는다. 화면 가운데 큰 판에 시설 · 사람 이름을 붙인다.
## 메뉴 · 가방 · 아침 카드 · 잠 · 잔치 · 사냥터에서는 숨긴다.

## 작은 지도 한 칸 크기 (px). 40x24 마을 → 120x72 (사냥터 작은 지도와 비슷한 크기)
const MINI_SCALE := 3
## 큰 지도 한 칸 크기 (px). 40x24 → 320x192
const BIG_SCALE := 8
## 작은 지도 위 끝 (윗줄 30px 아래)
const MINI_TOP := 36.0
## 지도 색을 다시 그리는 간격 (초). 밭 · 시설이 바뀌는 것은 느려서 자주 안 그려도 된다
const REFRESH := 0.5

const GRASS := Color(0.5, 0.68, 0.42)
const GRASS_DARK := Color(0.46, 0.63, 0.39)
const PATH := Color(0.82, 0.72, 0.53)
const FENCE := Color(0.55, 0.4, 0.27)
const LAKE := Color(0.36, 0.55, 0.72)
const LOCKED := Color(0.38, 0.5, 0.32)
const SOIL := Color(0.66, 0.52, 0.36)
const TILLED := Color(0.5, 0.35, 0.22)
const WATERED := Color(0.36, 0.24, 0.16)
const SPROUT := Color(0.33, 0.47, 0.2)
const RIPE := Color(1.0, 0.78, 0.25)
const TREE := Color(0.27, 0.45, 0.28)
const ROOF := Color(0.72, 0.38, 0.3)
const FACILITY := Color(0.62, 0.48, 0.34)
const RUIN := Color(0.48, 0.44, 0.42)
const PLAYER := Color(0.9, 0.3, 0.35)
const PERSON := Color(0.35, 0.55, 0.95)
const CREATURE := Color(1.0, 0.95, 0.6)

## 큰 지도 열림
var big := false
var main: Node2D
var _img: Image
var _tex: ImageTexture
var _wait := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(640, 360)


func _ready() -> void:
	_img = Image.create(Config.MAP_SIZE.x, Config.MAP_SIZE.y, false, Image.FORMAT_RGBA8)
	_tex = ImageTexture.create_from_image(_img)
	refresh()


func _process(delta: float) -> void:
	visible = shown()
	if not visible:
		big = false
		return
	_wait -= delta
	if _wait <= 0.0:
		refresh()
	queue_redraw()


## 지금 지도를 보여도 되는지 (마을을 걷는 중일 때만)
func shown() -> bool:
	if main == null or main.hunt != null or main.sleeping or main.menu_open or main._feast_scene:
		return false
	if main.inventory.visible or main.skill_panel.visible or main._morning_card.visible:
		return false
	return true


func toggle_big() -> void:
	big = not big
	queue_redraw()


## 칸 색을 다시 칠한다 (땅 · 길 · 울타리 · 호수 · 밭 · 시설)
func refresh() -> void:
	_wait = REFRESH
	if main == null or main.farm == null:
		return
	var farm: Farm = main.farm
	for y in Config.MAP_SIZE.y:
		for x in Config.MAP_SIZE.x:
			_img.set_pixel(x, y, cell_color(farm, Vector2i(x, y)))
	for p: Prop in main.props:
		if not is_instance_valid(p) or not p.visible:
			continue
		var r := prop_cells(p)
		var col := _prop_color(p)
		for y in range(maxi(r.position.y, 0), mini(r.end.y, Config.MAP_SIZE.y)):
			for x in range(maxi(r.position.x, 0), mini(r.end.x, Config.MAP_SIZE.x)):
				_img.set_pixel(x, y, col)
	_tex.update(_img)


## 칸 하나의 땅 색 (오브젝트 빼고)
static func cell_color(farm: Farm, c: Vector2i) -> Color:
	if Config.LAKE_ROWS.has(c.y) and c.x >= Config.LAKE_ROWS[c.y]:
		return LAKE
	if farm._is_fence(c):
		return FENCE
	if farm._is_path(c):
		return PATH
	var cell := farm.get_cell(c)
	if cell:
		if cell.is_ripe():
			return RIPE
		if cell.planted:
			return SPROUT
		if cell.tilled:
			return WATERED if cell.watered else TILLED
		return SOIL
	if Config.FIELD_RECT.has_point(c):
		return LOCKED
	return GRASS if (c.x + c.y) % 2 == 0 else GRASS_DARK


## 오브젝트가 차지한 칸 (Prop.place 의 거꾸로)
static func prop_cells(p: Prop) -> Rect2i:
	var origin := Vector2i(roundi(p.position.x / Config.TILE - p.footprint.x / 2.0), roundi(p.position.y / Config.TILE) - p.footprint.y)
	return Rect2i(origin, p.footprint)


func _prop_color(p: Prop) -> Color:
	if p.label == "":
		return ROOF if p == main.house else TREE
	if p.label.ends_with(" 터"):
		return RUIN
	return FACILITY


## 큰 지도에 이름을 안 붙이는 작은 오브젝트 (옆 시설 이름과 겹침)
const SMALL_PROPS: Array[String] = ["창고", "고물 더미", "도라지밭"]


## 지도 위 이름 (큰 지도). 이름 없는 집은 "집", 나무는 이름 없음
func prop_name(p: Prop) -> String:
	if p == main.house:
		return "집"
	return p.label


## 작은 지도 자리 (화면 px): 오른쪽 위, 윗줄 아래
static func mini_rect() -> Rect2:
	var s := Vector2(Config.MAP_SIZE * MINI_SCALE)
	return Rect2(Vector2(636 - s.x, MINI_TOP), s)


static func big_rect() -> Rect2:
	var s := Vector2(Config.MAP_SIZE * BIG_SCALE)
	return Rect2(((Vector2(640, 360) - s) / 2).floor() + Vector2(0, -6), s)


func _draw() -> void:
	if main == null:
		return
	if big:
		_draw_big()
	else:
		_draw_mini()


func _draw_mini() -> void:
	var r := mini_rect()
	draw_rect(r.grow(1), Color(0.2, 0.15, 0.18, 0.8))
	draw_texture_rect(_tex, r, false, Color(1, 1, 1, 0.92))
	# 지금 화면에 보이는 곳 (흰 테)
	var view := Rect2(main.view_center() - Vector2(320, 180), Vector2(640, 360))
	var vr := Rect2(r.position + view.position / Config.TILE * MINI_SCALE, view.size / Config.TILE * MINI_SCALE).intersection(r)
	draw_rect(vr, Color(1, 1, 1, 0.55), false, 1.0)
	_draw_dots(r, MINI_SCALE)
	draw_style_box(UiSkin.frame_box(), r.grow(4))


func _draw_big() -> void:
	var r := big_rect()
	draw_rect(Rect2(Vector2.ZERO, Vector2(640, 360)), Color(0.05, 0.04, 0.08, 0.45))
	draw_rect(r.grow(8), Color(0.98, 0.93, 0.8))
	draw_texture_rect(_tex, r, false)
	_draw_dots(r, BIG_SCALE)
	draw_style_box(UiSkin.frame_box(), r.grow(10))
	# 이름표: 시설 먼저, 그다음 사람. 겹치는 자리는 위 · 아래로 옮겨 보고, 그래도 겹치면 안 쓴다
	var taken: Array[Rect2] = []
	for p: Prop in main.props:
		if not is_instance_valid(p) or not p.visible:
			continue
		var n := prop_name(p)
		if n == "" or n in SMALL_PROPS:
			continue
		var c := prop_cells(p)
		var mid := r.position + Vector2(c.position.x + c.size.x / 2.0, c.position.y + c.size.y / 2.0) * BIG_SCALE
		_label(mid, [-c.size.y * BIG_SCALE / 2.0 - 4, c.size.y * BIG_SCALE / 2.0 + 10, 4], n, Color(1, 0.92, 0.6), taken)
	var k := float(BIG_SCALE) / Config.TILE
	_label(r.position + main.player.position * k, [-6, 14], "나", Color(1, 0.75, 0.75), taken)
	for ch: Character in main.people():
		if ch.visible:
			_label(r.position + ch.position * k, [14, -6], ch.display_name, Color(0.8, 0.88, 1), taken)
	UiSkin.draw_tag(self, Vector2(r.position.x, r.position.y - 14), "분원리 마을 지도", r.size.x)
	var hint := "주황 익은 밭 · 파랑 마을 사람 · 노랑 크리처 · 빨강 나 · M 닫기"
	var font := ThemeDB.fallback_font
	draw_string_outline(font, Vector2(r.position.x, r.end.y + 22), hint, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 9, 3, UiSkin.TAG_EDGE)
	draw_string(font, Vector2(r.position.x, r.end.y + 22), hint, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 9, Color(1, 0.96, 0.86))


## 이름표 하나: mid 가운데에서 dy 후보 (글씨 바닥 y) 순서로 빈자리를 찾아 쓴다. 다 겹치면 안 씀
func _label(mid: Vector2, dys: Array, text: String, col: Color, taken: Array[Rect2]) -> bool:
	var w := ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + 4
	for dy: float in dys:
		var box := Rect2(mid.x - w / 2, mid.y + dy - 10, w, 12)
		if taken.any(func(t: Rect2) -> bool: return t.intersects(box)):
			continue
		taken.append(box)
		UiSkin.draw_tag(self, Vector2(mid.x - 60, mid.y + dy), text, 120, col)
		return true
	return false


## 크리처 · 마을 사람 · 나 점
func _draw_dots(r: Rect2, scale: int) -> void:
	var k := float(scale) / Config.TILE
	var small := 1.5 if scale <= MINI_SCALE else 2.5
	for s: Creature in main.creatures:
		if is_instance_valid(s) and s.visible:
			var at := r.position + s.position * k
			draw_rect(Rect2(at - Vector2(small, small) / 2, Vector2(small, small) + Vector2.ONE), CREATURE)
	for c: Character in main.people():
		if not c.visible:
			continue
		var at := r.position + c.position * k
		draw_circle(at, small + 1.0, Color(0.1, 0.08, 0.15))
		draw_circle(at, small, PERSON)
	var me: Vector2 = r.position + main.player.position * k
	draw_circle(me, small + 2.0, Color.WHITE)
	draw_circle(me, small + 1.0, PLAYER)
