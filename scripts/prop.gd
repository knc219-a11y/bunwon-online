class_name Prop
extends Node2D
## 고정 오브젝트. 상호작용하는 것(부화기, 마을 공급함, 사냥터 입구)과 배경(집, 나무)을 같이 쓴다.
## position 은 차지하는 칸 묶음의 아래쪽 가운데(땅). 그림은 여기서 위로 그린다 (docs/sprites.md "마을 오브젝트").

@export var label := ""
@export var texture: Texture2D
## 차지하는 칸 수 (가로, 세로)
@export var footprint := Vector2i.ONE

var badge := ""


## 칸 묶음의 왼쪽 위 칸과 크기로 자리를 잡는다.
func place(origin: Vector2i, size: Vector2i) -> void:
	footprint = size
	position = Vector2(origin.x + size.x / 2.0, origin.y + size.y) * Config.TILE


## 차지하는 칸 영역(로컬 좌표).
func footprint_rect() -> Rect2:
	var s := Vector2(footprint) * Config.TILE
	return Rect2(Vector2(-s.x / 2, -s.y), s)


## 차지하는 칸 가장자리에서 dist 안에 있으면 true.
func is_near(pos: Vector2, dist: float) -> bool:
	var r := footprint_rect()
	var local := pos - position
	return local.clamp(r.position, r.end).distance_to(local) <= dist


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
