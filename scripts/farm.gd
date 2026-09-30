class_name Farm
extends Node2D
## 농장 타일 상태와 농사 동작. 바닥은 assets/tiles 의 타일셋으로 그린다 (docs/sprites.md "농장 바닥 타일").

enum Work { TILL, SOW, WATER, HARVEST }

const TILES := preload("res://assets/tiles/farm_tiles.png")
const CROPS := preload("res://assets/tiles/crops.png")
## 밭 울타리 (열 = 이웃 연결 비트, docs/sprites.md "마을 배경 오브젝트")
const FENCE := preload("res://assets/tiles/fence.png")
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

	func is_ripe() -> bool:
		return planted and growth >= Config.CROP_GROW_DAYS


var _cells: Dictionary[Vector2i, Cell] = {}
var _path: Dictionary[Vector2i, bool] = {}
var _fence: Dictionary[Vector2i, bool] = {}
## 캐릭터·크리처가 지나갈 수 없는 영역 (월드 좌표 px). 울타리 칸과 집·나무·마을 오브젝트의 막는 범위.
var _blockers: Array[Rect2] = []


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
		Work.HARVEST:
			c.planted = false
			c.watered = false
			c.growth = 0
			GameState.crops += 1
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
	for cell: Vector2i in _path:
		_tile(cell, TILES, _mask(cell, _is_path), ROW_PATH)
	# 밭을 갈 수 있는 영역 표시 (옅게)
	var field := Rect2(Vector2(Config.FIELD_RECT.position * t), Vector2(Config.FIELD_RECT.size * t))
	draw_rect(field.grow(1), Color(0.25, 0.35, 0.2, 0.25), false, 1.0)
	for i in range(GameState.open_plots, Config.FIELD_PLOTS.size()):
		_draw_locked_plot(i)
	for cell: Vector2i in _cells:
		var c: Cell = _cells[cell]
		if c.tilled:
			# 마른 밭과 젖은 밭은 서로 이어진다 (물 주기로 밭 모양이 바뀌지 않게)
			_tile(cell, TILES, _mask(cell, _is_tilled), ROW_WATERED if c.watered else ROW_TILLED)
		if c.planted:
			_tile(cell, CROPS, crop_stage(c), 0)
	# 울타리는 위 줄부터 그려 아래 칸 기둥이 위 칸 가로대를 덮게 한다
	var fence_cells := _fence.keys()
	fence_cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y)
	for cell: Vector2i in fence_cells:
		_tile(cell, FENCE, _mask(cell, _is_fence), 0)


## 잠긴 밭 구역: 잡초와 돌이 덮인 풀밭 + 값 (임시 그림)
func _draw_locked_plot(i: int) -> void:
	var t := Config.TILE
	var r := Config.FIELD_PLOTS[i]
	var px := Rect2(Vector2(r.position * t), Vector2(r.size * t))
	draw_rect(px, Color(0.30, 0.36, 0.22, 0.45))
	var rng := RandomNumberGenerator.new()
	rng.seed = r.position.x * 100 + r.position.y
	for n in 22:
		var p := px.position + Vector2(rng.randf_range(6, px.size.x - 6), rng.randf_range(8, px.size.y - 4))
		if n % 3 == 0:
			draw_circle(p, 3, Color(0.62, 0.6, 0.55))
			draw_circle(p + Vector2(-1, -1), 1.5, Color(0.75, 0.73, 0.68))
		else:
			draw_line(p, p + Vector2(-2, -5), Color(0.25, 0.45, 0.18), 1.5)
			draw_line(p, p + Vector2(2, -5), Color(0.25, 0.45, 0.18), 1.5)
	draw_rect(px.grow(-1), Color(0.95, 0.9, 0.7, 0.8), false, 1.0)
	var font := ThemeDB.fallback_font
	var c := px.get_center()
	draw_string(font, c + Vector2(-50, -2), "잠긴 밭", HORIZONTAL_ALIGNMENT_CENTER, 100, 10, Color(1, 0.98, 0.9))
	draw_string(font, c + Vector2(-50, 12), "%d원" % Config.FIELD_PLOT_PRICES[i], HORIZONTAL_ALIGNMENT_CENTER, 100, 10, Color(1, 0.9, 0.5))
