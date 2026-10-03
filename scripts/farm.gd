class_name Farm
extends Node2D
## 농장 타일 상태와 농사 동작. 바닥은 assets/tiles 의 타일셋으로 그린다 (docs/sprites.md "농장 바닥 타일").

## PLOW 깊이 갈기 (2026-10-02 아기 망아지): 심지 않은 칸을 깊이 갈아 두면 거둘 때 무 Config.PLOW_BONUS 개 더
enum Work { TILL, SOW, WATER, HARVEST, PLOW }

const TILES := preload("res://assets/tiles/farm_tiles.png")
const CROPS := preload("res://assets/tiles/crops.png")
## 밭 울타리 (열 = 이웃 연결 비트, docs/sprites.md "마을 배경 오브젝트")
const FENCE := preload("res://assets/tiles/fence.png")
## 풀밭 장식 (2026-09-30 그래픽 시범): 16x16 10칸, tools/make_polish_sprites.py
const DECO := preload("res://assets/tiles/ground_deco.png")
const PLOT_SIGN := preload("res://assets/props/plot_sign.png")
## 타일셋 행: 0 풀·흙길 속 채움, 1 갈아 둔 밭, 2 물 준 밭, 3 흙길 가장자리 (열 = 이웃 연결 비트)
const ROW_TILLED := 1
const ROW_WATERED := 2
const ROW_PATH := 3
## 풀 변형 0-3이 나올 누적 확률(%)
const GRASS_WEIGHTS: Array[int] = [60, 80, 92, 100]
## 이웃 연결 비트: 위 1, 오른쪽 2, 아래 4, 왼쪽 8
const NEIGHBORS := {1: Vector2i.UP, 2: Vector2i.RIGHT, 4: Vector2i.DOWN, 8: Vector2i.LEFT}


class Cell:
	var tilled := false
	var planted := false
	var watered := false
	## 물을 준 채로 지난 날 수
	var growth := 0
	## 깊이 간 칸 (아기 망아지 밭 갈기): 거두면 무가 더 나오고 보통 칸으로 돌아간다
	var plowed := false

	func is_ripe() -> bool:
		return planted and growth >= Config.CROP_GROW_DAYS


var _cells: Dictionary[Vector2i, Cell] = {}
var _path: Dictionary[Vector2i, bool] = {}
var _fence: Dictionary[Vector2i, bool] = {}
## 캐릭터·크리처가 지나갈 수 없는 영역 (월드 좌표 px). 울타리 칸과 집·나무·마을 오브젝트의 막는 범위.
var _blockers: Array[Rect2] = []
## 오브젝트가 선 칸. 풀밭 장식을 그리지 않는다.
var deco_skip: Array[Rect2i] = []


func _ready() -> void:
	for i in GameState.open_plots:
		_add_plot_cells(Config.FIELD_PLOTS[i])
	for r in Config.PATH_RECTS:
		for x in r.size.x:
			for y in r.size.y:
				_path[r.position + Vector2i(x, y)] = true
	var f := Config.FENCE_RECT
	for x in range(f.position.x, f.end.x):
		_fence[Vector2i(x, f.position.y)] = true
		_fence[Vector2i(x, f.end.y - 1)] = true
	for y in range(f.position.y, f.end.y):
		_fence[Vector2i(f.position.x, y)] = true
		_fence[Vector2i(f.end.x - 1, y)] = true
	for gap in Config.FENCE_GAPS:
		_fence.erase(gap)
	for cell: Vector2i in _fence:
		_add_fence_blockers(cell)


## 잠긴 밭 구역은 칸이 없어서 갈거나 심을 수 없다. 여기서 연다.
func _add_plot_cells(plot: Rect2i) -> void:
	for x in range(plot.position.x, plot.end.x):
		for y in range(plot.position.y, plot.end.y):
			_cells[Vector2i(x, y)] = Cell.new()


## GameState.open_plots 만큼 구역 칸이 있게 한다 (불러오기). 이미 있는 칸은 그대로.
func sync_plots() -> void:
	for i in GameState.open_plots:
		var plot := Config.FIELD_PLOTS[i]
		if not _cells.has(plot.position):
			_add_plot_cells(plot)
	queue_redraw()


## 다음 잠긴 밭 구역 번호. 모두 열렸으면 -1.
static func next_plot() -> int:
	return GameState.open_plots if GameState.open_plots < Config.FIELD_PLOTS.size() else -1


## 다음 구역을 연다 (돈은 부르는 쪽에서 치른다). 열렸으면 true.
func open_next_plot() -> bool:
	var i := next_plot()
	if i < 0:
		return false
	_add_plot_cells(Config.FIELD_PLOTS[i])
	GameState.open_plots += 1
	queue_redraw()
	GameState.touch()
	return true


static func cell_of(pos: Vector2) -> Vector2i:
	return Vector2i((pos / Config.TILE).floor())


static func center_of(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * Config.TILE


func get_cell(cell: Vector2i) -> Cell:
	return _cells.get(cell)


func can_do(work: Work, cell: Vector2i) -> bool:
	var c := get_cell(cell)
	if c == null:
		return false
	match work:
		Work.TILL:
			return not c.tilled
		Work.SOW:
			return c.tilled and not c.planted and GameState.seeds > 0
		Work.WATER:
			return c.planted and not c.watered and not c.is_ripe()
		Work.HARVEST:
			return c.is_ripe()
		Work.PLOW:
			return not c.planted and not c.plowed
	return false


## 작업을 수행한다. 성공하면 true.
func do_work(work: Work, cell: Vector2i) -> bool:
	if not can_do(work, cell):
		return false
	var c := get_cell(cell)
	match work:
		Work.TILL:
			c.tilled = true
		Work.SOW:
			c.planted = true
			c.growth = 0
			GameState.seeds -= 1
		Work.WATER:
			c.watered = true
		Work.PLOW:
			c.tilled = true
			c.plowed = true
		Work.HARVEST:
			c.planted = false
			c.watered = false
			c.growth = 0
			GameState.crops += 1 + (Config.PLOW_BONUS if c.plowed else 0)
			c.plowed = false
			GameState.seeds += Config.SEEDS_PER_HARVEST
	queue_redraw()
	GameState.touch()
	return true


## 하루가 지난다. 물 준 작물만 자라고, 방치해도 죽지 않는다.
## 하루를 넘긴다. 물을 받아 자란 작물 수를 돌려준다.
func advance_day() -> int:
	var grown := 0
	for c: Cell in _cells.values():
		if c.planted and c.watered:
			c.growth += 1
			grown += 1
		c.watered = false
	queue_redraw()
	return grown


## 비 내리기 (아기 청룡, 2026-10-03): 심은 칸 중 아직 안 익은 칸에 모두 물이 든다. 물이 든 칸 수를 돌려준다.
func rain() -> int:
	var n := 0
	for c: Cell in _cells.values():
		if c.planted and not c.watered and not c.is_ripe():
			c.watered = true
			n += 1
	queue_redraw()
	return n


## 키우기 (아기 나무 정령): center 둘레 radius 칸 안에서 오늘 밤 자란(물 준) 작물이 chance 확률로 하루 더 자란다.
## advance_day 앞에 부른다 (물 준 칸만 = 그날 밤 자라는 칸). 더 자란 수를 돌려준다.
func boost_growth(center: Vector2i, radius: int, chance: float, rng: RandomNumberGenerator) -> int:
	var n := 0
	for dx in range(-radius, radius + 1):
		for dy in range(-radius, radius + 1):
			var c: Cell = _cells.get(center + Vector2i(dx, dy))
			if c and c.planted and c.watered and not c.is_ripe() and c.growth + 1 < Config.CROP_GROW_DAYS and rng.randf() < chance:
				c.growth += 1
				n += 1
	return n


func ripe_count() -> int:
	var n := 0
	for c: Cell in _cells.values():
		if c.is_ripe():
			n += 1
	return n


## center 기준 반경 안에서 해당 작업이 가능한 가장 가까운 칸. 없으면 null.
## from 을 주면 거기서 곧게 갈 수 없는 칸(울타리·집 너머)은 뺀다.
func find_work(work: Work, center: Vector2i, radius: int, exclude: Array[Vector2i] = [], from: Variant = null) -> Variant:
	var best: Variant = null
	var best_dist := INF
	for dx in range(-radius, radius + 1):
		for dy in range(-radius, radius + 1):
			var cell := center + Vector2i(dx, dy)
			if cell in exclude or not can_do(work, cell):
				continue
			if from != null and not line_clear(from, center_of(cell)):
				continue
			var d := Vector2(dx, dy).length()
			if d < best_dist:
				best_dist = d
				best = cell
	return best


## 울타리 한 칸이 막는 범위: 그림처럼 가운데 기둥 발(y=18 근처)과 이웃 쪽으로 뻗은 가로대만 막는다.
## 칸 전체를 막으면 흙길 입구가 너무 좁아진다.
func _add_fence_blockers(cell: Vector2i) -> void:
	var o := Vector2(cell * Config.TILE)
	var m := _mask(cell, _is_fence)
	add_blocker(Rect2(o + Vector2(8, 12), Vector2(8, 10)))
	if m & 1:
		add_blocker(Rect2(o + Vector2(9, 0), Vector2(6, 12)))
	if m & 4:
		add_blocker(Rect2(o + Vector2(9, 22), Vector2(6, 2)))
	if m & 8:
		add_blocker(Rect2(o + Vector2(0, 12), Vector2(8, 10)))
	if m & 2:
		add_blocker(Rect2(o + Vector2(16, 12), Vector2(8, 10)))


func add_blocker(rect: Rect2) -> void:
	_blockers.append(rect)


func blockers() -> Array[Rect2]:
	return _blockers


## 영역이 막는 범위와 겹치지 않으면 true.
func is_free(rect: Rect2) -> bool:
	for b in _blockers:
		if b.intersects(rect):
			return false
	return true


## a 에서 b 까지 곧게 가는 길에 막는 범위가 없으면 true. 크리처가 울타리·집을 넘어 깡충 뛰지 않게 한다.
func line_clear(a: Vector2, b: Vector2) -> bool:
	var steps := ceili(a.distance_to(b) / 4.0)
	for i in steps + 1:
		var p := a.lerp(b, float(i) / maxi(steps, 1))
		for r in _blockers:
			if r.has_point(p):
				return false
	return true


## 이웃 중 같은 바닥인 쪽의 비트를 모은다. 타일셋 열 번호가 된다.
func _mask(cell: Vector2i, same: Callable) -> int:
	var m := 0
	for bit: int in NEIGHBORS:
		if same.call(cell + NEIGHBORS[bit]):
			m |= bit
	return m


func _is_tilled(cell: Vector2i) -> bool:
	var c := get_cell(cell)
	return c != null and c.tilled


func _is_fence(cell: Vector2i) -> bool:
	return _fence.has(cell)


func _is_path(cell: Vector2i) -> bool:
	return _path.has(cell)


## 성장 단계 0 씨앗, 1 싹, 2 자람, 3 다 자람
static func crop_stage(c: Cell) -> int:
	if c.is_ripe():
		return 3
	if c.growth == 0:
		return 0
	return mini(2, 1 + (c.growth - 1) * 2 / maxi(1, Config.CROP_GROW_DAYS - 1))


func _tile(cell: Vector2i, texture: Texture2D, col: int, row: int) -> void:
	var t := Config.TILE
	draw_texture_rect_region(texture, Rect2(Vector2(cell * t), Vector2(t, t)), Rect2(col * t, row * t, t, t))


func _draw() -> void:
	var t := Config.TILE
	# 맵(624px)이 화면(640px)보다 조금 좁아서 남는 오른쪽도 풀밭으로 채운다
	var cols := ceili(get_viewport_rect().size.x / t)
	for x in maxi(cols, Config.MAP_SIZE.x):
		for y in Config.MAP_SIZE.y:
			var h := absi((x * 73856093) ^ (y * 19349663)) % 100
			var v := GRASS_WEIGHTS.find_custom(func(w: int) -> bool: return h < w)
			_tile(Vector2i(x, y), TILES, v, 0)
	_draw_ground_deco(cols)
	for cell: Vector2i in _path:
		_tile(cell, TILES, _mask(cell, _is_path), ROW_PATH)
	for i in range(GameState.open_plots, Config.FIELD_PLOTS.size()):
		_draw_locked_plot(i)
	for cell: Vector2i in _cells:
		var c: Cell = _cells[cell]
		if c.tilled:
			# 마른 밭과 젖은 밭은 서로 이어진다 (물 주기로 밭 모양이 바뀌지 않게)
			_tile(cell, TILES, _mask(cell, _is_tilled), ROW_WATERED if c.watered else ROW_TILLED)
		if c.plowed:
			# 깊이 간 칸: 흙이 짙고 가장자리에 흙덩이 (거두면 무가 더 나옴)
			var o := Vector2(cell * Config.TILE)
			draw_rect(Rect2(o, Vector2(Config.TILE, Config.TILE)), Color(0.22, 0.12, 0.06, 0.24))
			for k in 3:
				draw_rect(Rect2(o + Vector2(3 + k * 8, Config.TILE - 4), Vector2(3, 2)), Color(0.36, 0.22, 0.13))
		if c.planted:
			_tile(cell, CROPS, crop_stage(c), 0)
	# 울타리는 위 줄부터 그려 아래 칸 기둥이 위 칸 가로대를 덮게 한다
	var fence_cells := _fence.keys()
	fence_cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y)
	for cell: Vector2i in fence_cells:
		_tile(cell, FENCE, _mask(cell, _is_fence), 0)


## 풀밭 장식: 칸마다 정해진 무늬로 꽃 · 풀포기 · 돌을 흩뿌린다 (늘 같은 자리)
func _draw_ground_deco(cols: int) -> void:
	for x in maxi(cols, Config.MAP_SIZE.x):
		for y in Config.MAP_SIZE.y:
			var cell := Vector2i(x, y)
			var h := absi((x * 92837111) ^ (y * 689287499) ^ 0x5bd1e995) % 1000
			if h >= 200 or _path.has(cell) or _fence.has(cell) or Config.FIELD_RECT.has_point(cell):
				continue
			if deco_skip.any(func(r: Rect2i) -> bool: return r.grow(1).has_point(cell)):
				continue
			# 꽃은 드물게, 풀포기는 흔하게
			var kind: int = [4, 4, 3, 0, 4, 1, 2, 6, 3, 0, 4, 7, 1, 2, 4, 6][h % 16]
			var off := Vector2((h / 16) % 9, (h / 144) % 7)
			draw_texture_rect_region(DECO, Rect2(Vector2(cell * Config.TILE) + off, Vector2(16, 16)), Rect2(kind * 16, 0, 16, 16))


## 잠긴 밭 구역: 잡초 덤불 · 돌이 덮인 풀밭 + 값 팻말
func _draw_locked_plot(i: int) -> void:
	var t := Config.TILE
	var r := Config.FIELD_PLOTS[i]
	var px := Rect2(Vector2(r.position * t), Vector2(r.size * t))
	draw_rect(px, Color(0.30, 0.36, 0.22, 0.18))
	var rng := RandomNumberGenerator.new()
	rng.seed = r.position.x * 100 + r.position.y
	var c := px.get_center()
	for n in 16:
		var p := px.position + Vector2(rng.randf_range(0, px.size.x - 16), rng.randf_range(0, px.size.y - 16))
		if absf(p.x + 8 - c.x) < 34 and absf(p.y + 8 - c.y) < 26:
			continue
		var kind: int = [8, 6, 9, 4, 7, 8, 6][n % 7]
		draw_texture_rect_region(DECO, Rect2(p.round(), Vector2(16, 16)), Rect2(kind * 16, 0, 16, 16))
	draw_texture(PLOT_SIGN, c - Vector2(12, 20))
	var font := ThemeDB.fallback_font
	draw_string(font, c + Vector2(-50, -9), "%d원" % Config.FIELD_PLOT_PRICES[i], HORIZONTAL_ALIGNMENT_CENTER, 100, 8, Color(0.4, 0.25, 0.15))
	draw_string(font, c + Vector2(-50, 16), "잠긴 밭", HORIZONTAL_ALIGNMENT_CENTER, 100, 9, Color(1, 0.98, 0.9))
