class_name Prop
extends Node2D
## 상호작용 가능한 고정 오브젝트 (부화기, 마을 공급함, 사냥터 입구). 임시 도형.

@export var label := ""
@export var color := Color.WHITE
@export var size := Vector2(28, 28)

var badge := ""


func set_badge(text: String) -> void:
	badge = text
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(-size / 2, size), color)
	draw_rect(Rect2(-size / 2, size), Color(0, 0, 0, 0.4), false, 1.0)
	draw_string(ThemeDB.fallback_font, Vector2(-40, size.y / 2 + 11), label, HORIZONTAL_ALIGNMENT_CENTER, 80, 9)
	if badge != "":
		draw_string(ThemeDB.fallback_font, Vector2(-40, -size.y / 2 - 3), badge, HORIZONTAL_ALIGNMENT_CENTER, 80, 9)
