class_name Prop
extends Node2D
## 고정 오브젝트. 상호작용하는 것(부화기, 마을 공급함, 사냥터 입구)과 배경(집, 나무)을 같이 쓴다.
## position 은 차지하는 칸 묶음의 아래쪽 가운데(땅). 그림은 여기서 위로 그린다 (docs/sprites.md "마을 오브젝트").

@export var label := ""
@export var texture: Texture2D
## 차지하는 칸 수 (가로, 세로)
@export var footprint := Vector2i.ONE

## 캐릭터·크리처가 지나갈 수 없는 범위 (로컬 좌표, 아래쪽 가운데 기준). 비어 있으면 막지 않는다.
var blocker := Rect2()
## 캐릭터·크리처가 뒤로 가면 반투명해진다
var fade_behind := false
var faded := false

var badge := ""


## 칸 묶음의 왼쪽 위 칸과 크기로 자리를 잡는다.
func place(origin: Vector2i, size: Vector2i) -> void:
	footprint = size
	position = Vector2(origin.x + size.x / 2.0, origin.y + size.y) * Config.TILE
	z_index = int(sort_y())


## 앞뒤 가림 기준 y (칸 묶음 아래 끝). 이 값이 작을수록 뒤에 그린다.
func sort_y() -> float:
	return position.y


## 그림이 차지하는 영역 (로컬 좌표)
func picture_rect() -> Rect2:
	if texture == null:
		return footprint_rect()
	var size := texture.get_size()
	return Rect2(Vector2(-size.x / 2, -size.y), size)


func blocker_world() -> Rect2:
	return Rect2(blocker.position + position, blocker.size)


func set_faded(value: bool) -> void:
	faded = value


func _process(delta: float) -> void:
	var target := 0.45 if faded else 1.0
	if not is_equal_approx(modulate.a, target):
		modulate.a = move_toward(modulate.a, target, delta * 4.0)


## 차지하는 칸 영역(로컬 좌표).
func footprint_rect() -> Rect2:
	var s := Vector2(footprint) * Config.TILE
	return Rect2(Vector2(-s.x / 2, -s.y), s)


## 차지하는 칸 가장자리에서 dist 안에 있으면 true.
func is_near(pos: Vector2, dist: float) -> bool:
	return distance_to(pos) <= dist


## 차지하는 칸 가장자리까지 거리
func distance_to(pos: Vector2) -> float:
	var r := footprint_rect()
	var local := pos - position
	return local.clamp(r.position, r.end).distance_to(local)


func set_badge(text: String) -> void:
	badge = text
	queue_redraw()


func _draw() -> void:
	var half_w := footprint.x * Config.TILE / 2.0
	var shadow := PackedVector2Array()
	for i in 16:
		var t := TAU * i / 16
		shadow.append(Vector2(cos(t) * (half_w + 1), sin(t) * 4 - 1))
	draw_colored_polygon(shadow, Color(0.2, 0.1, 0.25, 0.28))
	var top := -footprint.y * Config.TILE
	if texture:
		var size := texture.get_size()
		draw_texture(texture, Vector2(-size.x / 2, -size.y))
		top = -size.y
	draw_string(ThemeDB.fallback_font, Vector2(-40, 11), label, HORIZONTAL_ALIGNMENT_CENTER, 80, 9)
	if badge != "":
		draw_string(ThemeDB.fallback_font, Vector2(-40, top - 3), badge, HORIZONTAL_ALIGNMENT_CENTER, 80, 9)
