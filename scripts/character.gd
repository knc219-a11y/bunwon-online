class_name Character
extends Node2D
## 마을 사람. 조작하는 주인공 하나 (2026-10-03 사용자 선택: 주인공 하나가 밭일 · 사냥을 다 함)와
## 말 거는 마을 사람 NPC (농부 · 사냥꾼 · 대장장이 · 연금술사 · 목축인 · 뱃사공 · 이장).
## 그래픽은 스프라이트 시트 (assets/characters, 규격은 docs/sprites.md).

## 시트 규격: 칸 48x48, 열 0-1 대기 · 2-5 걷기, 행 0 아래 · 1 위 · 2 옆(오른쪽). 왼쪽은 좌우 반전.
const FRAME_SIZE := 48
const IDLE_COLUMNS: Array[int] = [0, 1]
const WALK_COLUMNS: Array[int] = [2, 3, 4, 5]
const IDLE_FPS := 2.0
const WALK_FPS := 8.0
## 발바닥이 캐릭터 위치보다 이만큼 아래 (칸 아래쪽)
const FEET_Y := 10
## 막는 범위와 부딪히는 발밑 상자 크기 (발바닥 가운데 기준)
const FEET_BOX := Vector2(12, 6)

@export var display_name := ""
## 누구인지 (&"player" 주인공, NPC 는 &"farmer" · &"hunter" · &"smith" ...). 저장 · 잔치가 쓴다.
@export var who: StringName = &""
## 지금 입은 옷 벌 (Wearables 의 주인 키). 주인공은 마을에서 &"farmer" (밭 옷), 사냥터에서 &"hunter" (사냥 옷).
## NPC 는 &"" (장비를 안 입음).
@export var outfit: StringName = &""
@export var sheet: Texture2D

var active := false:
	set(v):
		active = v
		_update_sprite()
		queue_redraw()
## 말 거는 마을 사람 (조작하지 않음). 흐리게 그리지 않고, 주인공이 가까이 오면 이름표를 띄운다 (show_tag).
var npc := false
var show_tag := false:
	set(v):
		if show_tag != v:
			show_tag = v
			queue_redraw()
## 막는 범위를 알려 주는 농장. null 이면 어디든 지나간다.
var farm: Farm
## 비어 있지 않으면 이 영역 안에서만 걷는다 (사냥터).
var walk_area := Rect2()
## 넓은 사냥터의 칸 지도. 있으면 깊은 물·바위·나무에 막히고 여울에서 느려진다.
var terrain: HuntMap
## 사냥터에서 금가루를 밟으면 느려진다 (1 = 보통)
var slow_mult := 1.0
## 바라보는 칸 표시 (농사용). 사냥터에서는 끈다.
var show_facing_cell := true
## 선택창이 열려 있는 동안처럼 조작 중이지만 걷지 않을 때 true
var frozen := false
## 사냥터 구르기 중 (HuntGround 가 대신 움직인다, 걷기 입력은 안 받음)
var dashing := false
var facing := Vector2i.DOWN
var moving := false

var _sprite: Sprite2D
## 입은 장비 덧그림. 몸 시트와 같은 칸을 겹쳐 그린다.
var _wear: Array[Sprite2D] = []
var _anim_time := 0.0


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = sheet
	_sprite.centered = false
	_sprite.hframes = 6
	_sprite.vframes = 3
	_sprite.position = Vector2(-FRAME_SIZE / 2.0, FEET_Y - FRAME_SIZE)
	add_child(_sprite)
	refresh_wear()


## 입은 장비에 맞춰 덧그림을 다시 만든다 (산 뒤에 부른다).
func refresh_wear() -> void:
	for w in _wear:
		w.queue_free()
	_wear.clear()
	if outfit == &"":
		_update_sprite()
		return
	for id in Wearables.worn_by(outfit):
		if not Wearables.item(id).has("sheet"):
			continue
		var w := Sprite2D.new()
		w.texture = Wearables.item(id).sheet
		w.centered = false
		w.hframes = 6
		w.vframes = 3
		w.position = _sprite.position
		add_child(w)
		_wear.append(w)
	_update_sprite()


## 발이 딛고 있는 칸
func cell() -> Vector2i:
	return Farm.cell_of(feet())


func feet() -> Vector2:
	return position + Vector2(0, FEET_Y)


## 앞뒤 가림 기준 y (발바닥). 이 값이 작을수록 뒤에 그린다.
func sort_y() -> float:
	return feet().y


## at 에 서 있을 때 발밑 상자
func feet_rect(at: Vector2) -> Rect2:
	return Rect2(at + Vector2(-FEET_BOX.x / 2, FEET_Y - FEET_BOX.y / 2), FEET_BOX)


## 한 걸음 움직인다. 가로·세로를 따로 막아 벽을 따라 미끄러지게 한다.
func step(motion: Vector2) -> void:
	var area := walk_area if walk_area.has_area() else Rect2(Vector2(8, 8), Vector2(Config.MAP_SIZE * Config.TILE) - Vector2(16, 16))
	for axis: Vector2 in [Vector2(motion.x, 0), Vector2(0, motion.y)]:
		if axis == Vector2.ZERO:
			continue
		var to := (position + axis).clamp(area.position, area.end)
		if (farm == null or farm.is_free(feet_rect(to))) and (terrain == null or terrain.is_free(feet_rect(to))):
			position = to


func facing_cell() -> Vector2i:
	return cell() + facing


func _process(delta: float) -> void:
	var dir := Vector2.ZERO
	if active and not frozen and not dashing:
		dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var was_moving := moving
	moving = dir != Vector2.ZERO
	if moving != was_moving:
		_anim_time = 0.0
	_anim_time += delta
	_update_sprite()
	z_index = int(sort_y())
	if not moving:
		return
	if absf(dir.x) > absf(dir.y):
		facing = Vector2i(int(signf(dir.x)), 0)
	else:
		facing = Vector2i(0, int(signf(dir.y)))
	var ground_mult := terrain.speed_at(feet()) if terrain else 1.0
	step(dir * Config.CHARACTER_SPEED * Wearables.speed_mult(outfit) * ground_mult * slow_mult * delta)
	queue_redraw()


## 시트에서 지금 보여 줄 칸 (열, 행)과 좌우 반전 여부
func frame_coords() -> Vector3i:
	var row := 0
	if facing == Vector2i.UP:
		row = 1
	elif facing.x != 0:
		row = 2
	var columns := WALK_COLUMNS if moving else IDLE_COLUMNS
	var fps := WALK_FPS if moving else IDLE_FPS
	var col: int = columns[int(_anim_time * fps) % columns.size()]
	return Vector3i(col, row, 1 if facing == Vector2i.LEFT else 0)


func _update_sprite() -> void:
	if _sprite == null:
		return
	var f := frame_coords()
	for sp: Sprite2D in [_sprite] + _wear:
		sp.frame_coords = Vector2i(f.x, f.y)
		sp.flip_h = f.z == 1
		sp.modulate.a = 1.0 if active or npc else 0.55


func _draw() -> void:
	var alpha := 1.0 if active or npc else 0.55
	# 발밑 그림자 (시트에는 그림자를 넣지 않는다)
	draw_set_transform(Vector2(0, FEET_Y - 1), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, 11.0, Color(0.27, 0.16, 0.33, 0.25 * alpha))
	draw_set_transform(Vector2.ZERO)
	if active and show_facing_cell:
		# 바라보는 칸 표시
		var target := Farm.center_of(facing_cell()) - position
		var r := Rect2(target - Vector2(11, 11), Vector2(22, 22))
		for corner: Vector2 in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
			var sx := 1.0 if corner.x == r.position.x else -1.0
			var sy := 1.0 if corner.y == r.position.y else -1.0
			draw_polyline(PackedVector2Array([corner + Vector2(0, sy * 5), corner, corner + Vector2(sx * 5, 0)]), Color(1, 1, 1, 0.85), 2.0)
	if active or (npc and show_tag):
		UiSkin.draw_tag(self, Vector2(-30, -42), display_name, 60)
