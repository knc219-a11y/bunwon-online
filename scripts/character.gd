class_name Character
extends Node2D
## 조작 가능한 캐릭터 (농부, 사냥꾼). 그래픽은 임시 도형.

@export var display_name := ""
@export var body_color := Color.GRAY

var active := false:
	set(v):
		active = v
		queue_redraw()
var facing := Vector2i.DOWN


func cell() -> Vector2i:
	return Farm.cell_of(position)


func facing_cell() -> Vector2i:
	return cell() + facing


func _process(delta: float) -> void:
	if not active:
		return
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if dir == Vector2.ZERO:
		return
	if absf(dir.x) > absf(dir.y):
		facing = Vector2i(int(signf(dir.x)), 0)
	else:
		facing = Vector2i(0, int(signf(dir.y)))
	var bounds := Vector2(Config.MAP_SIZE * Config.TILE)
	position = (position + dir * Config.CHARACTER_SPEED * delta).clamp(Vector2(8, 8), bounds - Vector2(8, 8))
	queue_redraw()


func _draw() -> void:
	var alpha := 1.0 if active else 0.55
	# 그림자, 몸통, 머리 (머리가 약간 큰 비율)
	draw_circle(Vector2(0, 12), 8.0, Color(0, 0, 0, 0.2 * alpha))
	draw_rect(Rect2(-7, -6, 14, 18), Color(body_color, alpha))
	draw_circle(Vector2(0, -12), 8.0, Color(Color("f1c7a0"), alpha))
	draw_rect(Rect2(-8, -21, 16, 6), Color(Color("2b2b2b"), alpha))
	if active:
		# 바라보는 칸 표시
		var target := Farm.center_of(facing_cell()) - position
		draw_rect(Rect2(target - Vector2(15, 15), Vector2(30, 30)), Color(1, 1, 1, 0.6), false, 1.5)
		draw_string(ThemeDB.fallback_font, Vector2(-30, -26), display_name, HORIZONTAL_ALIGNMENT_CENTER, 60, 10)
