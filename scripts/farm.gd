class_name Farm
extends Node2D
## 농장 타일 상태와 농사 동작. 바닥은 assets/tiles 의 타일셋으로 그린다 (docs/sprites.md "농장 바닥 타일").

enum Work { TILL, SOW, WATER, HARVEST }

const TILES := preload("res://assets/tiles/farm_tiles.png")
const CROPS := preload("res://assets/tiles/crops.png")
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


func _ready() -> void:
	for x in Config.FIELD_RECT.size.x:
		for y in Config.FIELD_RECT.size.y:
			_cells[Config.FIELD_RECT.position + Vector2i(x, y)] = Cell.new()
	for r in Config.PATH_RECTS:
		for x in r.size.x:
			for y in r.size.y:
				_path[r.position + Vector2i(x, y)] = true


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
func advance_day() -> void:
	for c: Cell in _cells.values():
		if c.planted and c.watered:
			c.growth += 1
		c.watered = false
	queue_redraw()


## center 기준 반경 안에서 해당 작업이 가능한 가장 가까운 칸. 없으면 null.
func find_work(work: Work, center: Vector2i, radius: int, exclude: Array[Vector2i] = []) -> Variant:
	var best: Variant = null
	var best_dist := INF
	for dx in range(-radius, radius + 1):
		for dy in range(-radius, radius + 1):
			var cell := center + Vector2i(dx, dy)
			if cell in exclude or not can_do(work, cell):
				continue
			var d := Vector2(dx, dy).length()
			if d < best_dist:
				best_dist = d
				best = cell
	return best


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
	for cell: Vector2i in _cells:
		var c: Cell = _cells[cell]
		if c.tilled:
			# 마른 밭과 젖은 밭은 서로 이어진다 (물 주기로 밭 모양이 바뀌지 않게)
			_tile(cell, TILES, _mask(cell, _is_tilled), ROW_WATERED if c.watered else ROW_TILLED)
		if c.planted:
			_tile(cell, CROPS, crop_stage(c), 0)
