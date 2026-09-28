class_name WildSlime
extends Node2D
## 사냥터의 야생 슬라임. 쉬었다가 깡충 뛰고, 사냥꾼이 가까우면 그쪽으로 뛴다.
## 맞으면 뒤로 밀리고 깜빡이며, 체력이 0이 되면 쓰러진다.
## 그림은 땅속성 슬라임 시트를 붉게 물들여 쓴다 (야생 전용 그림은 다음 단계).

const SHEET: Texture2D = preload("res://assets/creatures/slime_earth.png")
## 모래에 숨은 모습 (burrow 몬스터의 시트 6-7열)
const BURIED_COLUMNS: Array[int] = [6, 7]
const TINT := Color(1, 0.8, 0.75)
const FRAME_SIZE := 32
const IDLE_COLUMNS: Array[int] = [0, 1]
const HOP_COLUMNS: Array[int] = [2, 3, 4, 5]
const BOTTOM_Y := 8

var hp := Config.WILD_SLIME_HP
var max_hp := Config.WILD_SLIME_HP
## 대장 슬라임 (크고 금빛, 체력 Config.BOSS_HP). make_boss() 로 만든다.
var boss := false
## 이름 (대장 이름표에 쓴다). 구역마다 다르다 (Config.HUNT_ZONES).
var title := "야생 슬라임"
## 빠르기 배율 (쉬는 시간과 뛰는 시간을 나눈다)
var speed := 1.0
## 몬스터 시트 (구역마다 다름, 32x32 칸)
var sheet: Texture2D = SHEET
## 모래에 숨어 있는지 (금사리 모래게). 사냥꾼이 가까이 오거나 맞으면 튀어나온다.
var buried := false
var _tint := TINT
## 움직일 수 있는 영역 (사냥터 공터)
var area := Rect2()
## 넓은 사냥터의 칸 지도. 있으면 깊은 물·징검다리·바위·나무로는 가지 않는다.
var terrain: HuntMap
## false 면 스스로 움직이지 않는다 (테스트에서 끈다)
var ai_enabled := true

var _sprite: Sprite2D
var _rest := 0.0
var _hop_from := Vector2.ZERO
var _hop_to := Vector2.ZERO
var _hop_t := -1.0
var _flash := 0.0
var _anim_time := 0.0
## 혀에 끌려가는 중 (0~1, -1 = 아님)
var _pull_t := -1.0
var _pull_from := Vector2.ZERO
var _pull_to := Vector2.ZERO
## 멈춘 남은 시간 (금두꺼비 혀 당기기). 멈춘 동안은 움직이지 않고 부딪혀도 다치지 않는다.
var _stun := 0.0


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = sheet
	_sprite.centered = false
	_sprite.hframes = sheet.get_width() / FRAME_SIZE
	_sprite.modulate = _tint
	_sprite.position = Vector2(-FRAME_SIZE / 2.0, BOTTOM_Y - FRAME_SIZE)
	add_child(_sprite)
	_rest = randf_range(0.3, Config.WILD_SLIME_REST_TIME)


## 구역에 맞춘다: 체력 · 빠르기 · 색 (트리에 넣기 전에 부른다)
func setup_zone(zone: int) -> void:
	var z: Dictionary = Config.HUNT_ZONES[zone]
	title = z.monster
	speed = z.speed
	hp = z.hp
	max_hp = z.hp
	_tint = z.monster_tint
	sheet = load(z.sheet)
	buried = z.burrow


## 대장으로 만든다 (트리에 넣기 전후 모두 가능)
func make_boss(zone := 0) -> void:
	boss = true
	hp = Config.HUNT_ZONES[zone].boss_hp
	max_hp = hp
	var z: Dictionary = Config.HUNT_ZONES[zone]
	title = z.boss_monster
	speed = z.speed
	scale = Vector2.ONE * Config.BOSS_SCALE
	_tint = z.boss_tint
	buried = false
	sheet = load(z.boss_sheet)
	if _sprite:
		_sprite.texture = sheet
		_sprite.hframes = sheet.get_width() / FRAME_SIZE


func sort_y() -> float:
	return position.y + BOTTOM_Y


## 한 대 맞는다. 쓰러지면 true.
func hit(from: Vector2) -> bool:
	buried = false
	hp -= 1
	_flash = 0.25
	var away := (position - from).normalized()
	if away == Vector2.ZERO:
		away = Vector2.UP
	position = _stand(position + away * 14.0)
	_hop_t = -1.0
	_rest = Config.WILD_SLIME_REST_TIME
	return hp <= 0


func stun(time: float) -> void:
	_stun = maxf(_stun, time)
	_hop_t = -1.0


## 혀에 끌려 to 까지 짧게 미끄러진다 (금두꺼비 혀 당기기). 멈춤과 함께 쓴다.
func pull_to(to: Vector2) -> void:
	_pull_from = position
	_pull_to = to
	_pull_t = 0.0
	_hop_t = -1.0


func stunned() -> bool:
	return _stun > 0.0


func tick(delta: float, target: Vector2) -> void:
	_anim_time += delta
	_flash = maxf(_flash - delta, 0.0)
	_stun = maxf(_stun - delta, 0.0)
	if buried and position.distance_to(target) <= Config.WILD_BURROW_POP_DISTANCE:
		# 사냥꾼이 다가오면 모래에서 튀어나온다
		buried = false
		_rest = 0.4
	if _pull_t >= 0.0:
		_pull_t = minf(_pull_t + delta / Config.COMPANION_PULL_TIME, 1.0)
		position = _pull_from.lerp(_pull_to, _pull_t)
		if _pull_t >= 1.0:
			_pull_t = -1.0
	if buried or _stun > 0.0:
		pass
	elif ai_enabled:
		if _hop_t >= 0.0:
			_hop_t += delta * speed / Config.WILD_SLIME_HOP_TIME
			position = _hop_from.lerp(_hop_to, minf(_hop_t, 1.0))
			if _hop_t >= 1.0:
				_hop_t = -1.0
				_rest = Config.WILD_SLIME_REST_TIME * randf_range(0.7, 1.3) / speed
		else:
			_rest -= delta
			if _rest <= 0.0:
				_start_hop(target)
	var hopping := _hop_t >= 0.0
	var cols := BURIED_COLUMNS if buried else (HOP_COLUMNS if hopping else IDLE_COLUMNS)
	var col: int = HOP_COLUMNS[mini(int(_hop_t * 4), 3)] if hopping else cols[int(_anim_time * 2.0) % 2]
	_sprite.frame = col
	_sprite.modulate = Color(1, 1, 1) * 2.0 if _flash > 0.0 and int(_flash * 20) % 2 == 0 else _tint
	z_index = int(sort_y())
	queue_redraw()


## to 로 옮길 수 있으면 to, 못 서는 곳(물 등)이면 지금 자리. 영역 밖은 안으로 당긴다.
func _stand(to: Vector2) -> Vector2:
	to = to.clamp(area.position, area.end)
	# 이미 못 서는 곳에 있으면 (혀에 끌려 물가에 떨어졌을 때) 어디로든 빠져나오게 둔다
	var feet := Vector2(0, BOTTOM_Y - 2)
	if terrain and not terrain.monster_ok(to + feet) and terrain.monster_ok(position + feet):
		return position
	return to


func _start_hop(target: Vector2) -> void:
	var dir: Vector2
	if position.distance_to(target) <= Config.WILD_SLIME_CHASE_DISTANCE:
		dir = (target - position).normalized()
	else:
		dir = Vector2.RIGHT.rotated(randf() * TAU)
	var to := _stand(position + dir * Config.WILD_SLIME_HOP_DISTANCE)
	if to == position:
		# 물가에 막히면 옆으로 비껴 뛴다
		to = _stand(position + dir.rotated(PI / 2 * (1 if randf() < 0.5 else -1)) * Config.WILD_SLIME_HOP_DISTANCE)
	_hop_from = position
	_hop_to = to
	_hop_t = 0.0


func _draw() -> void:
	draw_set_transform(Vector2(0, BOTTOM_Y - 1), 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, 10.0, Color(0.27, 0.16, 0.33, 0.25))
	draw_set_transform(Vector2.ZERO)
	# 남은 체력 (맞은 뒤에만 보임)
	if hp < max_hp:
		draw_rect(Rect2(-10, -24, 20, 3), Color(0.25, 0.2, 0.2))
		draw_rect(Rect2(-10, -24, 20.0 * hp / max_hp, 3), Color(0.9, 0.5, 0.3))
	# 멈춤 (혀 당기기): 머리 위에 빙글 도는 별 셋
	if _stun > 0.0:
		for i in 3:
			var a := _anim_time * 6.0 + i * TAU / 3.0
			draw_circle(Vector2(cos(a) * 8.0, -22 + sin(a) * 2.0), 2.0, Color(1.0, 0.92, 0.45))
	# 대장 이름표 (디아블로2 챔피언처럼 금색)
	if boss:
		var font := ThemeDB.fallback_font
		var w := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 6).x
		draw_rect(Rect2(-w / 2 - 1.5, -35.5, w + 3, 7), Color(0, 0, 0, 0.55))
		draw_string(font, Vector2(-w / 2, -30), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 6, Color(0.95, 0.85, 0.45))
