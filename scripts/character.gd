class_name Character
extends Node2D
## 마을 사람. 조작하는 주인공 하나 (2026-10-03 사용자 선택: 주인공 하나가 밭일 · 사냥을 다 함)와
## 말 거는 마을 사람 NPC (농부 · 사냥꾼 · 대장장이 · 연금술사 · 목축인 · 뱃사공 · 이장).
## 그래픽은 스프라이트 시트 (assets/characters, 규격은 docs/sprites.md).

## 시트 규격: 칸 48x48, 열 0-1 대기 · 2-5 걷기, 행 0 아래 · 1 위 · 2 옆(오른쪽). 왼쪽은 좌우 반전.
const FRAME_SIZE := 48
const IDLE_COLUMNS: Array[int] = [0, 1]
const WALK_COLUMNS: Array[int] = [2, 3, 4, 5]
## 공격 칸 (2026-10-04 공격 모션, tools/make_attack_frames.py): 무기 종류별 열과 칸마다 쓰는 시간 비율.
## 근거리 치켜들기 · 휘두르기 · 내려베기 · 마무리, 활 걸기 · 당기기 · 놓기, 지팡이 치켜들기 · 내뻗기 · 거두기
const ATTACK_COLUMNS := {&"melee": [6, 7, 8, 9], &"bow": [10, 11, 12], &"staff": [13, 14, 15]}
const ATTACK_WEIGHTS := {&"melee": [0.14, 0.14, 0.36, 0.36], &"bow": [0.16, 0.2, 0.64], &"staff": [0.2, 0.45, 0.35]}
## 무기 덧그림 칸 (몸 칸 사방 16px 여유)
const WEAPON_FRAME := 80
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
## 장비 덧그림 폴더 (주인공 모습 B 면 "b", Wearables.sheet_of)
var wear_dir := ""

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
## 넓은 도구가 함께 닿는 칸 (바라보는 칸 말고, main 이 매 프레임 넣음). 옅은 점으로 보인다 (2026-10-03 큰 물뿌리개 · 큰 괭이)
var reach_cells: Array[Vector2i] = []
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
## 사냥터 공격 모션 (2026-10-03 타격감): 치는 쪽으로 그림만 살짝 내딛었다 돌아온다 (발 위치는 그대로)
var _lunge_dir := Vector2.ZERO
var _lunge_px := 0.0
var _lunge_t := -1.0
## 공격 모션: 무기 종류 (&"" 면 안 함), 지난 시간, 길이, 거꾸로 (연속 베기 2타 되베기)
var _atk_kind: StringName = &""
var _atk_t := 0.0
var _atk_dur := 0.0
var _atk_reverse := false
## 공격하는 동안 손에 든 무기 그림 (assets/weapons)
var _weapon: Sprite2D
## 다쳤을 때 붉게 번쩍이는 남은 시간
var _hurt_t := 0.0
## 타격 멈춤 동안 true: 공격 모션 · 번쩍임을 멈춰 둔다 (HuntGround 가 넣음)
var hold := false


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = sheet
	_sprite.centered = false
	_sprite.vframes = 3
	_fit_frames(_sprite)
	_sprite.position = _base_offset()
	_sprite.material = HitFlash.material(HitFlash.HURT_COLOR)
	add_child(_sprite)
	_weapon = Sprite2D.new()
	_weapon.centered = false
	_weapon.vframes = 3
	_weapon.visible = false
	_weapon.material = HitFlash.material(HitFlash.HURT_COLOR)
	add_child(_weapon)
	refresh_wear()


## 시트 폭에 맞춰 가로 칸 수 (주인공은 공격 칸까지 16칸, NPC · 옛 장비 그림은 6칸)
func _fit_frames(sp: Sprite2D, size := FRAME_SIZE) -> void:
	sp.hframes = maxi(1, sp.texture.get_width() / size) if sp.texture else 6


## 몸 시트를 바꾼다 (주인공 모습 고르기)
func set_sheet(t: Texture2D, dir := "") -> void:
	sheet = t
	wear_dir = dir
	if _sprite:
		_sprite.texture = t
		_fit_frames(_sprite)
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
		w.texture = Wearables.sheet_of(id, wear_dir)
		w.centered = false
		w.vframes = 3
		_fit_frames(w)
		w.position = _sprite.position
		w.material = HitFlash.material(HitFlash.HURT_COLOR)
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


## 공격 모션: dir 쪽으로 px 만큼 그림이 휙 나갔다 돌아온다
func lunge(dir: Vector2, px := Config.ATTACK_LUNGE_PX) -> void:
	_lunge_dir = dir.normalized()
	_lunge_px = px
	_lunge_t = 0.0
	_update_sprite()


## 공격 모션을 dur 초 동안 보여 준다 (kind: &"melee" · &"bow" · &"staff"). 시트에 공격 칸이 없으면 (NPC) 아무것도 안 한다.
## reverse 면 칸을 거꾸로 (근거리 2타: 아래에서 위로 되베기)
func attack(kind: StringName, dur: float, reverse := false) -> void:
	if not ATTACK_COLUMNS.has(kind) or _sprite == null or _sprite.hframes <= ATTACK_COLUMNS[kind][-1]:
		return
	_atk_kind = kind
	_atk_t = 0.0
	_atk_dur = maxf(dur, 0.05)
	_atk_reverse = reverse
	var tex := load("res://assets/weapons/%s.png" % kind) as Texture2D
	if _weapon.texture != tex:
		_weapon.texture = tex
		_fit_frames(_weapon, WEAPON_FRAME)
	_update_sprite()


func attacking() -> bool:
	return _atk_kind != &""


## 공격 모션을 바로 끝낸다
func stop_attack() -> void:
	_atk_kind = &""
	_update_sprite()


## 다쳤다: 붉게 번쩍
func hurt_flash() -> void:
	_hurt_t = Config.HURT_FLASH
	_update_sprite()


func _base_offset() -> Vector2:
	return Vector2(-FRAME_SIZE / 2.0, FEET_Y - FRAME_SIZE)


## 공격 모션 지금 밀린 거리 (빨리 나가고 천천히 돌아옴, 도트가 번지지 않게 정수 px)
func lunge_offset() -> Vector2:
	if _lunge_t < 0.0:
		return Vector2.ZERO
	var k := _lunge_t / Config.ATTACK_LUNGE_TIME
	var out := k / 0.25 if k < 0.25 else 1.0 - (k - 0.25) / 0.75
	return (_lunge_dir * _lunge_px * out).round()


func _process(delta: float) -> void:
	if not hold:
		if _lunge_t >= 0.0:
			_lunge_t += delta
			if _lunge_t >= Config.ATTACK_LUNGE_TIME:
				_lunge_t = -1.0
		_hurt_t = maxf(_hurt_t - delta, 0.0)
		if _atk_kind != &"":
			_atk_t += delta
			if _atk_t >= _atk_dur:
				_atk_kind = &""
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
	# 공격하는 동안은 치는 쪽을 계속 본다 (걸어도 몸이 돌지 않게)
	if _atk_kind == &"":
		if absf(dir.x) > absf(dir.y):
			facing = Vector2i(int(signf(dir.x)), 0)
		else:
			facing = Vector2i(0, int(signf(dir.y)))
	var ground_mult := terrain.speed_at(feet()) if terrain else 1.0
	# 날랜 걸음 (농사 기술, 2026-10-03): 주인공이 마을 (밭 옷) 에서 걸을 때만
	var farm_mult := FarmSkills.walk_mult() if who == &"player" and outfit == &"farmer" else 1.0
	step(dir * Config.CHARACTER_SPEED * Wearables.speed_mult(outfit) * ground_mult * slow_mult * farm_mult * delta)
	queue_redraw()


## 시트에서 지금 보여 줄 칸 (열, 행)과 좌우 반전 여부
func frame_coords() -> Vector3i:
	var row := 0
	if facing == Vector2i.UP:
		row = 1
	elif facing.x != 0:
		row = 2
	if _atk_kind != &"":
		var cols: Array = ATTACK_COLUMNS[_atk_kind]
		var weights: Array = ATTACK_WEIGHTS[_atk_kind]
		var k := clampf(_atk_t / _atk_dur, 0.0, 0.999)
		var i := 0
		var acc: float = weights[0]
		while k >= acc and i < weights.size() - 1:
			i += 1
			acc += weights[i]
		if _atk_reverse:
			i = cols.size() - 1 - i
		return Vector3i(cols[i], row, 1 if facing == Vector2i.LEFT else 0)
	var columns := WALK_COLUMNS if moving else IDLE_COLUMNS
	var fps := WALK_FPS if moving else IDLE_FPS
	var col: int = columns[int(_anim_time * fps) % columns.size()]
	return Vector3i(col, row, 1 if facing == Vector2i.LEFT else 0)


func _update_sprite() -> void:
	if _sprite == null:
		return
	var f := frame_coords()
	var at := _base_offset() + lunge_offset()
	var red := clampf(_hurt_t / Config.HURT_FLASH, 0.0, 1.0) * 0.75
	for sp: Sprite2D in [_sprite] + _wear:
		# 옛 6칸 장비 그림은 공격 칸이 없으니 그동안 숨긴다
		sp.visible = f.x < sp.hframes
		if not sp.visible:
			continue
		sp.frame_coords = Vector2i(f.x, f.y)
		sp.flip_h = f.z == 1
		sp.modulate.a = 1.0 if active or npc else 0.55
		sp.position = at
		HitFlash.set_amount(sp, red)
	if _weapon:
		_weapon.visible = _atk_kind != &"" and _weapon.texture != null and f.x < _weapon.hframes
		if _weapon.visible:
			_weapon.frame_coords = Vector2i(f.x, f.y)
			_weapon.flip_h = f.z == 1
			_weapon.position = at - Vector2.ONE * (WEAPON_FRAME - FRAME_SIZE) / 2.0
			# 뒷모습은 무기가 몸 뒤로 (앞으로 내미는 칼 · 활이 등에 가려진다)
			_weapon.z_index = -1 if f.y == 1 else 0
			HitFlash.set_amount(_weapon, red)


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
		for c in reach_cells:
			if c != facing_cell():
				var p := Farm.center_of(c) - position
				draw_rect(Rect2(p - Vector2(9, 9), Vector2(18, 18)), Color(1, 1, 1, 0.35), false, 1.0)
	if active or (npc and show_tag):
		UiSkin.draw_tag(self, Vector2(-30, -42), display_name, 60)
