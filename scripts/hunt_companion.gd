class_name HuntCompanion
extends Node2D
## 사냥터에 따라온 농장 크리처 (2026-09-27 결정 A. 따라오는 동료, 첫 조각).
## 사냥꾼 뒤를 따라다니다가 가까운 야생 슬라임을 스스로 공격한다. 다치지 않는다.
## 공격 방식은 종에 정해져 있으면 그것 (금두꺼비 = 혀 당기기), 아니면 첫 번째 속성으로 정한다:
## 물 = 멀리서 물총, 그 밖(땅) = 붙어서 박치기. 아기 참새 = 날아가 쪼기 (2026-09-29 광동리 B).
## 아기 나무 정령 = 덩굴 묶기 (2026-09-29 도마리): 덩굴을 뻗어 몬스터를 잠깐 붙잡는다.
## 누구를 언제 때릴지는 HuntGround 가 정하고, 이 노드는 움직임과 그리기만 맡는다.

enum Style { SHOT, BUMP, PULL, PECK, BIND, EMBER }

const STYLE_NAMES := {Style.SHOT: "멀리서 물총", Style.BUMP: "붙어서 박치기", Style.PULL: "혀로 끌어오기", Style.PECK: "날아가 쪼기", Style.BIND: "덩굴 묶기", Style.EMBER: "불빛 + 불씨"}

## 농장에 있는 크리처 (돌아가면 그 자리·그 일로 복귀)
var source: Creature
var data: CreatureData
var style := Style.BUMP
## 물총이 날아가는 모습을 그릴 끝점과 남은 시간
var shot_to := Vector2.ZERO
var shot_time := 0.0
## 혀로 끌어오는 몬스터 (혀 끝이 따라간다)
var pulling: WildSlime

var _sprite: Sprite2D
var _anim_time := 0.0
var _moving := false
var _attack_time := 0.0


func setup(from: Creature) -> void:
	source = from
	data = from.data
	var element: StringName = data.elements[0].id if not data.elements.is_empty() else &""
	style = style_for(data)
	var sheet: Texture2D = data.species.sprite_sheets.get(element)
	if sheet != null:
		_sprite = Sprite2D.new()
		_sprite.texture = sheet
		_sprite.centered = false
		_sprite.hframes = Creature.SHEET_COLUMNS
		_sprite.position = Vector2(-Creature.FRAME_SIZE / 2.0, Creature.BOTTOM_Y - Creature.FRAME_SIZE)
		add_child(_sprite)


static func style_for(d: CreatureData) -> Style:
	if d.species.companion_style == &"pull":
		return Style.PULL
	if d.species.companion_style == &"peck":
		return Style.PECK
	if d.species.companion_style == &"bind":
		return Style.BIND
	if d.species.companion_style == &"ember":
		return Style.EMBER
	var element: StringName = d.elements[0].id if not d.elements.is_empty() else &""
	return Style.SHOT if element == &"water" else Style.BUMP


static func style_name(d: CreatureData) -> String:
	return STYLE_NAMES[style_for(d)]


func display_name() -> String:
	return "%s %s" % [data.element_names(), data.species.display_name]


## 공격 한 번에 걸리는 시간. 일 속도가 빠른 개체일수록 조금 짧다 (절반~두 배 사이). 속도 훈련도 반영.
func attack_interval() -> float:
	var base: float = {Style.SHOT: Config.COMPANION_SHOT_INTERVAL, Style.BUMP: Config.COMPANION_BUMP_INTERVAL, Style.PULL: Config.COMPANION_PULL_INTERVAL, Style.PECK: Config.COMPANION_PECK_INTERVAL, Style.BIND: Config.COMPANION_BIND_INTERVAL, Style.EMBER: Config.COMPANION_EMBER_INTERVAL}[style]
	return base / clampf(data.base_work_speed * data.train_speed_mult(), 0.5, 2.0)


## 공격이 닿는 거리 (px)
## 동행이 들고 다니는 불빛 반지름 (px, 밤 구역). 0 = 불빛 없음.
func light_radius() -> float:
	return Config.COMPANION_EMBER_LIGHT if style == Style.EMBER else 0.0


func reach() -> float:
	return {Style.SHOT: Config.COMPANION_SHOT_RANGE, Style.BUMP: Config.COMPANION_BUMP_RANGE, Style.PULL: Config.COMPANION_PULL_RANGE, Style.PECK: Config.COMPANION_PECK_RANGE, Style.BIND: Config.COMPANION_BIND_RANGE, Style.EMBER: Config.COMPANION_EMBER_RANGE}[style]


func speed() -> float:
	return Config.COMPANION_SPEED * data.move_speed()


## to 쪽으로 이번 프레임만큼 걷는다. 도착하면 true.
func move_toward_point(to: Vector2, delta: float) -> bool:
	var d := position.distance_to(to)
	_moving = d > 2.0
	position = position.move_toward(to, speed() * delta)
	return not _moving


func play_attack(at: Vector2) -> void:
	_attack_time = Creature.WATER_COLUMNS.size() / Creature.WORK_FPS
	if style == Style.SHOT:
		shot_to = at
		shot_time = 0.2
	elif style == Style.PULL:
		shot_to = at
		shot_time = Config.COMPANION_PULL_TIME
	elif style == Style.PECK:
		shot_to = at
		shot_time = 0.3
	elif style == Style.BIND:
		shot_to = at
		shot_time = Config.COMPANION_BIND_STUN
	elif style == Style.EMBER:
		shot_to = at
		shot_time = 0.35
	else:
		# 박치기: 상대 쪽으로 살짝 튀어 나갔다 돌아온다 (그림만)
		shot_to = at


func sort_y() -> float:
	return position.y + Creature.BOTTOM_Y


func _process(delta: float) -> void:
	_anim_time += delta
	_attack_time = maxf(_attack_time - delta, 0.0)
	shot_time = maxf(shot_time - delta, 0.0)
	if _sprite != null:
		var col: int
		if _attack_time > 0.0 and style != Style.BUMP:
			var i := Creature.WATER_COLUMNS.size() - 1 - int(_attack_time * Creature.WORK_FPS)
			col = Creature.WATER_COLUMNS[clampi(i, 0, Creature.WATER_COLUMNS.size() - 1)]
		elif _moving or _attack_time > 0.0:
			col = Creature.HOP_COLUMNS[int(_anim_time * Creature.WORK_FPS) % Creature.HOP_COLUMNS.size()]
		else:
			col = Creature.IDLE_COLUMNS[int(_anim_time * Creature.IDLE_FPS) % Creature.IDLE_COLUMNS.size()]
		_sprite.frame = col
		# 박치기 순간 상대 쪽으로 몸을 내민다
		var lunge := Vector2.ZERO
		if style == Style.BUMP and _attack_time > 0.0:
			lunge = (shot_to - position).normalized() * 6.0 * sin(_attack_time / (Creature.WATER_COLUMNS.size() / Creature.WORK_FPS) * PI)
		_sprite.position = Vector2(-Creature.FRAME_SIZE / 2.0, Creature.BOTTOM_Y - Creature.FRAME_SIZE) + lunge
	z_index = int(sort_y())
	queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2(0, Creature.BOTTOM_Y - 1), 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, 10.0, Color(0.27, 0.16, 0.33, 0.25))
	draw_set_transform(Vector2.ZERO)
	if _sprite == null:
		var body := data.elements[0].color if not data.elements.is_empty() else data.species.color
		draw_circle(Vector2(0, 4), 11.0, body)
	if shot_time > 0.0 and style == Style.PULL:
		# 혀 당기기: 입에서 상대까지 분홍 혀
		var at := pulling.position if is_instance_valid(pulling) else shot_to
		var tip := at - position + Vector2(0, -2)
		draw_line(Vector2(0, -2), tip, Color(0.9, 0.42, 0.48), 3.0)
		draw_circle(tip, 3.5, Color(0.95, 0.55, 0.6))
	elif shot_time > 0.0 and style == Style.BIND:
		# 덩굴 묶기: 상대까지 구불구불한 초록 덩굴, 끝에 잎 (전용 그림은 다음 단계)
		var at := pulling.position if is_instance_valid(pulling) else shot_to
		var to := at - position
		var pts := PackedVector2Array()
		for i in 9:
			var k := i / 8.0
			pts.append(Vector2(0, -4).lerp(to, k) + to.orthogonal().normalized() * sin(k * TAU * 1.5 + _anim_time * 6.0) * 3.0)
		draw_polyline(pts, Color(0.36, 0.62, 0.3), 2.0)
		draw_arc(to, 7.0, 0, TAU, 12, Color(0.4, 0.7, 0.32), 2.0)
		draw_circle(to + Vector2(5, -5), 2.5, Color(0.6, 0.85, 0.45))
	elif shot_time > 0.0 and style == Style.EMBER:
		# 불씨: 상대까지 날아가는 불똥 (전용 그림은 다음 단계)
		var to := shot_to - position + Vector2(0, -8)
		var k := 1.0 - shot_time / 0.35
		draw_circle(Vector2(0, -8).lerp(to, k), 3.0, Color(1.0, 0.6, 0.25))
		draw_circle(Vector2(0, -8).lerp(to, k), 1.5, Color(1.0, 0.92, 0.6))
	elif shot_time > 0.0 and style == Style.PECK:
		# 날아가 쪼기: 상대까지 날아간 자국 (점선)과 쪼는 부리 반짝임 (전용 그림은 다음 단계)
		var to := shot_to - position + Vector2(0, -10)
		draw_dashed_line(Vector2(0, -8), to, Color(0.75, 0.55, 0.35, 0.9), 1.5, 3.0)
		draw_circle(to, 3.0, Color(1.0, 0.85, 0.45))
	elif shot_time > 0.0:
		# 물총: 입에서 상대까지 물줄기 (전용 그림은 다음 단계)
		var from := Vector2(0, -6)
		var to := shot_to - position + Vector2(0, -6)
		draw_line(from, to, Color(0.55, 0.85, 1.0, 0.9), 2.5)
		draw_circle(to, 4.0, Color(0.72, 0.92, 1.0, 0.9))
