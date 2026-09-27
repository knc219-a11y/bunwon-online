class_name Farm
extends Node2D
## 농장 타일 상태와 농사 동작. 그래픽은 임시로 도형을 그린다.

enum Work { TILL, SOW, WATER, HARVEST }


class Cell:
	var tilled := false
	var planted := false
	var watered := false
	## 물을 준 채로 지난 날 수
	var growth := 0

	func is_ripe() -> bool:
		return planted and growth >= Config.CROP_GROW_DAYS


var _cells: Dictionary[Vector2i, Cell] = {}


func _ready() -> void:
	for x in Config.FIELD_RECT.size.x:
		for y in Config.FIELD_RECT.size.y:
			_cells[Config.FIELD_RECT.position + Vector2i(x, y)] = Cell.new()


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


func _draw() -> void:
	var t := Config.TILE
	# 맵(624px)이 화면(640px)보다 조금 좁아서 남는 오른쪽도 풀밭으로 채운다
	draw_rect(get_viewport_rect().merge(Rect2(Vector2.ZERO, Vector2(Config.MAP_SIZE * t))), Color("7fb069"))
	var field := Rect2(Vector2(Config.FIELD_RECT.position * t), Vector2(Config.FIELD_RECT.size * t))
	draw_rect(field.grow(2), Color("5d7f45"), false, 2.0)
	for cell: Vector2i in _cells:
		var c: Cell = _cells[cell]
		var r := Rect2(Vector2(cell * t), Vector2(t, t)).grow(-1)
		if c.tilled:
			draw_rect(r, Color("6b4a2f") if c.watered else Color("9c7148"))
		if c.planted:
			var p := center_of(cell)
			if c.is_ripe():
				draw_circle(p, 7.0, Color("f2a541"))
				draw_circle(p + Vector2(0, -5), 3.0, Color("3f8f3a"))
			else:
				var size := 2.0 + 2.0 * c.growth
				draw_circle(p, size, Color("3f8f3a"))
