class_name HuntGround
extends Node2D
## 사냥터 한 화면 (2026-09-27 결정 A. 실시간 한 화면, 첫 조각).
## 숲 공터에 야생 슬라임이 돌아다닌다. 사냥꾼은 걸어 다니며 휘둘러 쓰러뜨린다.
## 그날 처음 쓰러뜨린 슬라임은 알을 반드시 떨어뜨린다. 하트가 0이 되면 쓰러져 마을로 돌아가고, 주운 것은 그대로 가진다.
## 그림은 마을 그림을 다시 쓴 임시 배치 (사냥터 전용 그림은 다음 단계).

signal knocked_out

const T := Config.TILE
## 사냥꾼이 걸을 수 있는 공터 (캐릭터 위치 기준, px)
const WALK_AREA := Rect2(3 * T, 3 * T, 20 * T, 9 * T + 12)
## 흙 공터 (칸)
const CLEARING := Rect2i(4, 4, 18, 8)
## 아래쪽 마을로 돌아가는 입구 (그림 아래쪽 가운데, px)와 F가 닿는 범위
const EXIT_AT := Vector2(13 * T, 15 * T)
const EXIT_AREA := Rect2(10 * T, 11 * T, 6 * T, 3 * T)
const SPAWN_AT := Vector2(13 * T, 11 * T)
const SLIME_CELLS: Array[Vector2i] = [Vector2i(7, 6), Vector2i(13, 5), Vector2i(19, 7)]
const TREE_SPOTS: Array[Vector2] = [
	Vector2(24, 52), Vector2(72, 44), Vector2(124, 50), Vector2(176, 42), Vector2(228, 48), Vector2(280, 40),
	Vector2(332, 46), Vector2(384, 42), Vector2(436, 50), Vector2(488, 44), Vector2(540, 48), Vector2(592, 42),
	Vector2(20, 130), Vector2(30, 210), Vector2(22, 300), Vector2(616, 130), Vector2(608, 214), Vector2(618, 300),
	Vector2(120, 356), Vector2(200, 362), Vector2(440, 360), Vector2(520, 356),
]

var hunter: Character
var hearts := Config.HUNTER_HEARTS
var slimes: Array[WildSlime] = []
## 땅에 떨어진 알 (자리 → 종)
var drops: Array[Dictionary] = []
## 이번 사냥에서 주운 알
var picked: Array[CreatureSpecies] = []
## 이번 사냥에서 알 보장을 이미 썼는지 (그날 첫 사냥에서 처음 쓰러뜨린 슬라임)
var egg_guaranteed := true
var knocked := false

var _cooldown := 0.0
var _invulnerable := 0.0
var _swing_time := 0.0
var _swing_dir := Vector2.DOWN
var _hud: Node2D


func _ready() -> void:
	var ground := Node2D.new()
	ground.z_index = -1000
	ground.draw.connect(_draw_ground.bind(ground))
	add_child(ground)
	for p in TREE_SPOTS:
		var tree := Sprite2D.new()
		tree.texture = preload("res://assets/props/tree_persimmon.png")
		tree.centered = false
		tree.offset = Vector2(-24, -72)
		tree.position = p
		tree.modulate = Color(0.78, 0.92, 0.78)
		tree.z_index = int(p.y)
		add_child(tree)
	var gate := Sprite2D.new()
	gate.texture = preload("res://assets/props/hunt_gate.png")
	gate.centered = false
	gate.offset = Vector2(-36, -56)
	gate.position = EXIT_AT
	gate.z_index = int(EXIT_AT.y)
	add_child(gate)
	var layer := CanvasLayer.new()
	layer.layer = 2
	add_child(layer)
	_hud = Node2D.new()
	_hud.draw.connect(_draw_hud)
	layer.add_child(_hud)
	for cell in SLIME_CELLS:
		var s := WildSlime.new()
		s.area = Rect2(Vector2(CLEARING.position * T) + Vector2(12, 12), Vector2(CLEARING.size * T) - Vector2(24, 24))
		s.position = Farm.center_of(cell)
		add_child(s)
		slimes.append(s)


## 사냥꾼을 사냥터로 데려온다. first_today 면 처음 쓰러뜨린 슬라임이 알을 반드시 떨어뜨린다.
func start(h: Character, first_today: bool) -> void:
	hunter = h
	egg_guaranteed = not first_today
	hunter.walk_area = WALK_AREA
	hunter.show_facing_cell = false
	hunter.position = SPAWN_AT
	hunter.facing = Vector2i.UP


func set_ai(on: bool) -> void:
	for s in slimes:
		s.ai_enabled = on


func near_exit() -> bool:
	return EXIT_AREA.has_point(hunter.position)


func _process(delta: float) -> void:
	tick(delta)


func tick(delta: float) -> void:
	if hunter == null or knocked:
		return
	_cooldown = maxf(_cooldown - delta, 0.0)
	_invulnerable = maxf(_invulnerable - delta, 0.0)
	_swing_time = maxf(_swing_time - delta, 0.0)
	var feet := hunter.feet()
	for s in slimes:
		s.tick(delta, feet)
		if _invulnerable <= 0.0 and s.position.distance_to(feet) <= Config.WILD_SLIME_TOUCH_DISTANCE:
			_hurt(s.position)
	for i in range(drops.size() - 1, -1, -1):
		if drops[i].at.distance_to(feet) <= 14.0:
			picked.append(drops[i].species)
			drops.remove_at(i)
			GameState.notify("알을 주웠다! 마을로 돌아가 공급함에 넣자.")
	queue_redraw()
	_hud.queue_redraw()


## 사냥칼을 휘두른다. dir 이 비어 있으면 바라보는 쪽으로. 맞힌 수를 돌려준다.
func swing(dir := Vector2.ZERO) -> int:
	if knocked or _cooldown > 0.0:
		return 0
	if dir != Vector2.ZERO:
		# 마우스로 누른 쪽을 바라보게 한다 (4방향)
		hunter.facing = Vector2i(int(signf(dir.x)), 0) if absf(dir.x) > absf(dir.y) else Vector2i(0, int(signf(dir.y)))
	else:
		dir = Vector2(hunter.facing)
	_swing_dir = dir.normalized()
	_cooldown = Config.SWING_COOLDOWN
	_swing_time = 0.15
	var center := hunter.feet() + Vector2(0, -8) + _swing_dir * Config.SWING_REACH
	var hits := 0
	for s in slimes.duplicate():
		if s.position.distance_to(center) <= Config.SWING_RADIUS:
			hits += 1
			if s.hit(hunter.feet()):
				_defeat(s)
	return hits


func _defeat(s: WildSlime) -> void:
	slimes.erase(s)
	if not egg_guaranteed:
		# 그날 첫 사냥에서 처음 쓰러뜨린 슬라임은 알을 반드시 떨어뜨린다 (운 때문에 막히지 않게)
		egg_guaranteed = true
		var table := CreatureCatalog.HUNT_TABLE
		drops.append({at = s.position, species = table[randi() % table.size()]})
		GameState.notify("야생 슬라임을 쓰러뜨리자 알이 떨어졌다!")
	elif slimes.is_empty():
		GameState.notify("야생 슬라임을 모두 쓰러뜨렸다. 아래 입구에서 F로 마을로 돌아가자.")
	else:
		GameState.notify("야생 슬라임을 쓰러뜨렸다. 남은 슬라임 %d마리." % slimes.size())
	s.queue_free()


func _hurt(from: Vector2) -> void:
	hearts -= 1
	_invulnerable = Config.HURT_INVULNERABLE_TIME
	var away := (hunter.feet() - from).normalized()
	if away == Vector2.ZERO:
		away = Vector2.DOWN
	hunter.step(away * 16.0)
	if hearts <= 0:
		knocked = true
		GameState.notify("사냥꾼이 쓰러졌다... 마을 입구로 돌아왔다. 주운 것은 그대로 있다.")
		knocked_out.emit()
	else:
		GameState.notify("야생 슬라임에게 부딪혔다! 남은 하트 %d." % hearts)


## 떠날 때 아직 줍지 않은 알도 챙긴다 (알 보장이 헛되지 않게). 가져갈 알 목록을 돌려준다.
func collect_all() -> Array[CreatureSpecies]:
	for d in drops:
		picked.append(d.species)
	drops.clear()
	return picked


func _draw() -> void:
	for d in drops:
		var p: Vector2 = d.at
		draw_set_transform(p + Vector2(0, 6), 0.0, Vector2(1.0, 0.4))
		draw_circle(Vector2.ZERO, 7.0, Color(0.27, 0.16, 0.33, 0.25))
		draw_set_transform(Vector2.ZERO)
		draw_circle(p + Vector2(0, 1), 6, Color(0.97, 0.93, 0.8))
		draw_circle(p + Vector2(0, -3), 5, Color(0.97, 0.93, 0.8))
		draw_circle(p + Vector2(-2, 0), 1.5, Color(0.55, 0.8, 0.95))
		draw_circle(p + Vector2(2, 2), 1.2, Color(0.55, 0.8, 0.95))
	if _swing_time > 0.0 and hunter:
		var c := hunter.feet() + Vector2(0, -12)
		var a := _swing_dir.angle()
		draw_arc(c, 20, a - 1.0, a + 1.0, 10, Color(1, 1, 1, 0.85), 2.5)


func _draw_ground(n: Node2D) -> void:
	var tiles: Texture2D = preload("res://assets/tiles/farm_tiles.png")
	for x in Config.MAP_SIZE.x + 1:
		for y in Config.MAP_SIZE.y:
			var h := (x * 73856093) ^ (y * 19349663)
			var v := [0, 0, 0, 1, 1, 2, 3][absi(h) % 7] as int
			n.draw_texture_rect_region(tiles, Rect2(x * T, y * T, T, T), Rect2(v * T, 0, T, T), Color(0.82, 0.9, 0.8))
	for x in range(CLEARING.position.x, CLEARING.end.x):
		for y in range(CLEARING.position.y, CLEARING.end.y + 3 if x >= 11 and x <= 13 else CLEARING.end.y):
			n.draw_texture_rect_region(tiles, Rect2(x * T, y * T, T, T), Rect2(4 * T, 0, T, T))


func _draw_hud() -> void:
	for i in Config.HUNTER_HEARTS:
		var c := Color(0.9, 0.3, 0.35) if i < hearts else Color(0.45, 0.38, 0.38)
		var p := Vector2(8 + i * 13, 34)
		_hud.draw_circle(p + Vector2(3, 3), 3, c)
		_hud.draw_circle(p + Vector2(7, 3), 3, c)
		_hud.draw_colored_polygon(PackedVector2Array([p + Vector2(0, 4), p + Vector2(10, 4), p + Vector2(5, 10)]), c)
