class_name WildSlime
extends Node2D
## 사냥터의 야생 슬라임. 쉬었다가 깡충 뛰고, 사냥꾼이 가까우면 그쪽으로 뛴다.
## 맞으면 뒤로 밀리고 깜빡이며, 체력이 0이 되면 쓰러진다.
## 그림은 땅속성 슬라임 시트를 붉게 물들여 쓴다 (야생 전용 그림은 다음 단계).

const SHEET: Texture2D = preload("res://assets/creatures/slime_earth.png")
const TINT := Color(1, 0.8, 0.75)
const FRAME_SIZE := 32
const IDLE_COLUMNS: Array[int] = [0, 1]
const HOP_COLUMNS: Array[int] = [2, 3, 4, 5]
const BOTTOM_Y := 8

var hp := Config.WILD_SLIME_HP
var max_hp := Config.WILD_SLIME_HP
## 대장 슬라임 (크고 금빛, 체력 Config.BOSS_HP). make_boss() 로 만든다.
var boss := false
var _tint := TINT
## 움직일 수 있는 영역 (사냥터 공터)
var area := Rect2()
## false 면 스스로 움직이지 않는다 (테스트에서 끈다)
var ai_enabled := true

var _sprite: Sprite2D
var _rest := 0.0
var _hop_from := Vector2.ZERO
var _hop_to := Vector2.ZERO
var _hop_t := -1.0
var _flash := 0.0
var _anim_time := 0.0


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = SHEET
	_sprite.centered = false
	_sprite.hframes = 10
	_sprite.modulate = _tint
	_sprite.position = Vector2(-FRAME_SIZE / 2.0, BOTTOM_Y - FRAME_SIZE)
	add_child(_sprite)
	_rest = randf_range(0.3, Config.WILD_SLIME_REST_TIME)


## 대장 슬라임으로 만든다 (트리에 넣기 전후 모두 가능)
func make_boss() -> void:
	boss = true
	hp = Config.BOSS_HP
	max_hp = Config.BOSS_HP
	scale = Vector2.ONE * Config.BOSS_SCALE
	_tint = Color(1.0, 0.82, 0.4)


func sort_y() -> float:
	return position.y + BOTTOM_Y


## 한 대 맞는다. 쓰러지면 true.
func hit(from: Vector2) -> bool:
	hp -= 1
	_flash = 0.25
	var away := (position - from).normalized()
	if away == Vector2.ZERO:
		away = Vector2.UP
	position = (position + away * 14.0).clamp(area.position, area.end)
	_hop_t = -1.0
	_rest = Config.WILD_SLIME_REST_TIME
	return hp <= 0


func tick(delta: float, target: Vector2) -> void:
	_anim_time += delta
	_flash = maxf(_flash - delta, 0.0)
	if ai_enabled:
		if _hop_t >= 0.0:
			_hop_t += delta / Config.WILD_SLIME_HOP_TIME
			position = _hop_from.lerp(_hop_to, minf(_hop_t, 1.0))
			if _hop_t >= 1.0:
				_hop_t = -1.0
				_rest = Config.WILD_SLIME_REST_TIME * randf_range(0.7, 1.3)
		else:
			_rest -= delta
			if _rest <= 0.0:
				_start_hop(target)
	var hopping := _hop_t >= 0.0
	var cols := HOP_COLUMNS if hopping else IDLE_COLUMNS
	var col: int = HOP_COLUMNS[mini(int(_hop_t * 4), 3)] if hopping else cols[int(_anim_time * 2.0) % 2]
	_sprite.frame = col
	_sprite.modulate = Color(1, 1, 1) * 2.0 if _flash > 0.0 and int(_flash * 20) % 2 == 0 else _tint
	z_index = int(sort_y())
	queue_redraw()


func _start_hop(target: Vector2) -> void:
	var dir: Vector2
	if position.distance_to(target) <= Config.WILD_SLIME_CHASE_DISTANCE:
		dir = (target - position).normalized()
	else:
		dir = Vector2.RIGHT.rotated(randf() * TAU)
	_hop_from = position
	_hop_to = (position + dir * Config.WILD_SLIME_HOP_DISTANCE).clamp(area.position, area.end)
	_hop_t = 0.0


func _draw() -> void:
	draw_set_transform(Vector2(0, BOTTOM_Y - 1), 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, 10.0, Color(0.27, 0.16, 0.33, 0.25))
	draw_set_transform(Vector2.ZERO)
	# 남은 체력 (맞은 뒤에만 보임)
	if hp < max_hp:
		draw_rect(Rect2(-10, -24, 20, 3), Color(0.25, 0.2, 0.2))
		draw_rect(Rect2(-10, -24, 20.0 * hp / max_hp, 3), Color(0.9, 0.5, 0.3))
	# 대장 이름표 (디아블로2 챔피언처럼 금색)
	if boss:
		var font := ThemeDB.fallback_font
		var w := font.get_string_size("대장 슬라임", HORIZONTAL_ALIGNMENT_LEFT, -1, 6).x
		draw_rect(Rect2(-w / 2 - 1.5, -35.5, w + 3, 7), Color(0, 0, 0, 0.55))
		draw_string(font, Vector2(-w / 2, -30), "대장 슬라임", HORIZONTAL_ALIGNMENT_LEFT, -1, 6, Color(0.95, 0.85, 0.45))
