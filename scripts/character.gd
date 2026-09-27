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
	# 키 48px(타일 2칸). 발이 칸 아래쪽(y=+10), 머리가 약간 큰 비율.
	draw_circle(Vector2(0, 10), 9.0, Color(0, 0, 0, 0.2 * alpha))
	draw_rect(Rect2(-6, -2, 12, 10), Color(Color("4c6896"), alpha))
	draw_rect(Rect2(-7, 8, 14, 2), Color(Color("2c2c34"), alpha))
	draw_rect(Rect2(-8, -18, 16, 17), Color(body_color, alpha))
	draw_circle(Vector2(0, -27), 10.0, Color(Color("f2cca9"), alpha))
	draw_rect(Rect2(-10, -38, 20, 8), Color(Color("2b2b2b"), alpha))
	draw_circle(Vector2(-4, -26), 2.5, Color(Color("1e1e28"), alpha))
	draw_circle(Vector2(4, -26), 2.5, Color(Color("1e1e28"), alpha))
	if active:
		# 바라보는 칸 표시
		var target := Farm.center_of(facing_cell()) - position
		draw_rect(Rect2(target - Vector2(11, 11), Vector2(22, 22)), Color(1, 1, 1, 0.6), false, 1.5)
		draw_string(ThemeDB.fallback_font, Vector2(-30, -42), display_name, HORIZONTAL_ALIGNMENT_CENTER, 60, 10)
