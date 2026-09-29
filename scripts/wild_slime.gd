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
## 숨은 모습이 진짜 그루터기인 척 (도마리 고목 그루터기): 숨은 동안 대부분 6열, 몇 초에 한 번 눈이 번쩍 (7열)
var disguise := false
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

## 부딪히면 잃는 하트 · 맞았을 때 밀려나는 거리 · 달려들기 예고 시간 (구역마다, Config.HUNT_ZONES)
var damage := 1
var knockback := 14.0
var windup_time := 0.6
## 대장 패턴 (&"slam" 내려찍기 · &"tongue" 혀 채찍), 대장만
var pattern := &""
## 대장 내려찍기 때 튀어나온 새끼 (알·드롭 없음)
var minion := false

## 달려들기 (A): 웅크림 남은 시간(-1 = 아님) → 돌진(0~1) → 헐떡임
var _windup := -1.0
var _lunge_dir := Vector2.ZERO
var _lunge_t := -1.0
var _lunge_from := Vector2.ZERO
var _recover := 0.0
var _lunge_cd := 0.0
## 대장 패턴 (C)
var _pattern_cd := 1.5
## 내려찍기: 공중에 뜬 진행(0~1, -1 = 아님), 뛰는 곳 · 떨어질 곳
var _air_t := -1.0
var _air_from := Vector2.ZERO
var _air_to := Vector2.ZERO
## 혀 채찍: 예고 남은 시간(-1 = 아님), 뻗은 채 남은 시간
var _aim := -1.0
var _lash := 0.0
var _tongue_to := Vector2.ZERO

## 참새 (광동리 flyer, 2026-09-29 선택 B): 날아다니다 내려꽂는다. 나는 동안 position 은 그림자(땅) 자리이고 그림만 띄운다.
var flyer := false
## 맴도는 남은 시간 (-1 = 땅에 있음) · 내려꽂기 예고 남은 시간 · 내려꽂는 진행(0~1)
var _fly := -1.0
var _swoop := -1.0
var _dive_t := -1.0
var _dive_from := Vector2.ZERO
var _dive_to := Vector2.ZERO
var _angle := 0.0
## 허수아비 장수 짚단 던지기: 떨어질 짚단들 {at, t = 남은 시간}, 던진 횟수 (두 번에 한 번 참새 부르기)
var _bales: Array[Dictionary] = []
var _throws := 0
## 천하대장군 통나무 굴리기 (도마리): 예고 남은 시간(-1 = 아님) → 굴러가는 진행(0~1, -1 = 아님), 굴러갈 길
var _log_aim := -1.0
var _log_t := -1.0
var _log_from := Vector2.ZERO
var _log_to := Vector2.ZERO

## 참새가 내려꽂았다 (내려앉은 곳). HuntGround 가 받아 원 안의 사냥꾼을 다치게 한다.
signal swooped(at: Vector2)
## 짚단이 떨어졌다. HuntGround 가 받아 원 안의 사냥꾼을 다치게 한다.
signal bale_landed(at: Vector2)
## 허수아비 장수가 참새를 불렀다 (HuntGround 가 참새를 놓는다)
signal called(at: Vector2)
## 대장이 내려찍었다 (떨어진 곳). HuntGround 가 받아 원 안의 사냥꾼을 다치게 하고 새끼를 놓는다.
signal slammed(at: Vector2)
## 통나무가 굴러가는 중 (지금 통나무 자리). HuntGround 가 받아 닿은 사냥꾼을 다치게 한다.
signal rolled(at: Vector2)
## 대장이 혀를 뻗었다 (입 → 혀끝). HuntGround 가 받아 선 위의 사냥꾼을 다치게 하고 금가루를 뿌린다.
signal lashed(from: Vector2, to: Vector2)


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
	disguise = z.get("disguise", false)
	damage = z.get("damage", 1)
	knockback = z.get("knockback", 14.0)
	windup_time = z.get("windup", 0.6)
	flyer = z.get("flyer", false)
	_angle = randf() * TAU


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
	flyer = false
	damage = z.get("damage", 1)
	knockback = z.get("knockback", 14.0)
	pattern = z.get("boss_pattern", &"")
	sheet = load(z.boss_sheet)
	if _sprite:
		_sprite.texture = sheet
		_sprite.hframes = sheet.get_width() / FRAME_SIZE


## 짝 대장으로 바꾼다 (도마리 지하여장군: 구역 데이터 partner = {name, sheet, pattern}). make_boss 뒤에 부른다.
func make_partner(zone := 0) -> void:
	var p: Dictionary = Config.HUNT_ZONES[zone].partner
	title = p.name
	pattern = p.pattern
	sheet = load(p.sheet)
	_pattern_cd = 3.0
	if _sprite:
		_sprite.texture = sheet
		_sprite.hframes = sheet.get_width() / FRAME_SIZE


func sort_y() -> float:
	return position.y + BOTTOM_Y


## 대장 내려찍기 때 튀어나오는 새끼로 만든다 (트리에 넣기 전에, setup_zone 뒤에)
func make_minion() -> void:
	minion = true
	hp = 1
	max_hp = 1
	title = "새끼 " + title
	scale = Vector2.ONE * Config.MINION_SCALE
	_lunge_cd = 1.0


## 한 대 맞는다. 쓰러지면 true. 웅크리는 중이면 밀려나도 달려들기는 멈추지 않는다.
func hit(from: Vector2) -> bool:
	buried = false
	if flyer:
		if in_air():
			# 날던 참새는 쪼여서 땅에 떨어진다 (아기 참새 동행만 닿음)
			_fly = -1.0
			_swoop = -1.0
			_dive_t = -1.0
			position = _stand(position)
			_rest = Config.SWOOP_RECOVER
		else:
			# 맞으면 조금만 더 쪼다가 날아오른다
			_rest = minf(_rest, Config.SWOOP_HIT_RECOVER)
	hp -= 1
	_flash = 0.25
	var away := (position - from).normalized()
	if away == Vector2.ZERO:
		away = Vector2.UP
	if _air_t < 0.0:
		position = _stand(position + away * knockback)
	_hop_t = -1.0
	if not flyer:
		_rest = Config.WILD_SLIME_REST_TIME
	return hp <= 0


## 공중에 떠 있어 칼·몸이 닿지 않는다 (대장 내려찍기)
func airborne() -> bool:
	return _air_t >= 0.0 or in_air()


## 참새가 공중에 있다 (맴돌기 · 예고 · 내려꽂는 중)
func in_air() -> bool:
	return _fly >= 0.0 or _swoop >= 0.0 or _dive_t >= 0.0


## 헐떡이는 중 (달려들기·대장 패턴 뒤, 때릴 틈)
func recovering() -> bool:
	return _recover > 0.0


func stun(time: float) -> void:
	_stun = maxf(_stun, time)
	_hop_t = -1.0
	# 돌진 중이었으면 거기서 멈춘다. 웅크림·예고는 멈춤이 풀리면 이어진다 (멈춤이 달려들기를 지워 주지는 않음)
	if _lunge_t >= 0.0:
		_lunge_t = -1.0
		_recover = Config.LUNGE_RECOVER
		_lunge_cd = Config.LUNGE_COOLDOWN


## 바닥 예고 (사냥꾼 봇·그리기용). {} 이면 없음.
## lane: from → to 띠 (width), circle: at 둘레 radius, progress 는 예고가 얼마나 찼는지 (0~1)
func telegraph() -> Dictionary:
	var all := telegraphs()
	return all[0] if not all.is_empty() else {}


## 지금 예고 전부 (짚단은 여러 개). 먼저 떨어지는 것부터.
func telegraphs() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if _swoop >= 0.0:
		out.append({kind = &"circle", at = _dive_to, radius = Config.SWOOP_RADIUS, progress = 1.0 - _swoop / windup_time})
	for b in _bales:
		out.append({kind = &"circle", at = b.at, radius = Config.STRAW_RADIUS, progress = clampf(1.0 - b.t / Config.STRAW_WINDUP, 0.0, 1.0), bale = true})
	var one := _telegraph_one()
	if not one.is_empty():
		out.append(one)
	return out


func _telegraph_one() -> Dictionary:
	if _windup >= 0.0:
		return {kind = &"lane", from = position, to = position + _lunge_dir * Config.LUNGE_DISTANCE, width = Config.LUNGE_WIDTH * scale.x, progress = 1.0 - _windup / windup_time}
	if _air_t >= 0.0:
		return {kind = &"circle", at = _air_to, radius = Config.SLAM_RADIUS, progress = _air_t}
	if _aim >= 0.0:
		return {kind = &"lane", from = position, to = _tongue_to, width = Config.TONGUE_WIDTH, progress = 1.0 - _aim / Config.TONGUE_WINDUP}
	if _log_aim >= 0.0:
		return {kind = &"lane", from = _log_from, to = _log_to, width = Config.LOG_WIDTH, progress = 1.0 - _log_aim / Config.LOG_WINDUP}
	if _log_t >= 0.0:
		# 굴러가는 중: 남은 길을 계속 보여 준다 (봇이 비킬 수 있게)
		return {kind = &"lane", from = log_at(), to = _log_to, width = Config.LOG_WIDTH, progress = 1.0}
	return {}


## 굴러가는 통나무 자리
func log_at() -> Vector2:
	return _log_from.lerp(_log_to, maxf(_log_t, 0.0))


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
	elif ai_enabled and flyer:
		_tick_fly(delta, target)
	elif ai_enabled and _tick_attack(delta, target):
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
	# 돌진·내려찍기도 깡충 그림을 쓴다
	var hop_t := maxf(_hop_t, maxf(_lunge_t, _air_t))
	var hopping := hop_t >= 0.0
	var cols := BURIED_COLUMNS if buried else (HOP_COLUMNS if hopping else IDLE_COLUMNS)
	var col: int = HOP_COLUMNS[mini(int(hop_t * 4), 3)] if hopping else cols[int(_anim_time * 2.0) % 2]
	if buried and disguise:
		col = BURIED_COLUMNS[1] if fmod(_anim_time + _angle, Config.DISGUISE_BLINK_EVERY) < 0.35 else BURIED_COLUMNS[0]
	if flyer:
		# 날갯짓 · 낟알 쪼기 (내려앉은 뒤) · 앉아 있기
		col = HOP_COLUMNS[int(_anim_time * 10.0) % 4] if in_air() else (BURIED_COLUMNS if _rest > 0.0 else IDLE_COLUMNS)[int(_anim_time * 3.0) % 2]
	elif not _bales.is_empty() or _log_aim >= 0.0 or _log_t >= 0.0:
		col = BURIED_COLUMNS[int(_anim_time * 6.0) % 2]
	_sprite.frame = col
	# 내려찍기: 공중에서 그림을 위로 띄운다 (그림자는 제자리). 참새는 나는 동안 FLY_HEIGHT 만큼.
	var lift := sin(_air_t * PI) * 60.0 / scale.y if _air_t >= 0.0 else 0.0
	if flyer and in_air():
		lift = Config.FLY_HEIGHT * (1.0 - maxf(_dive_t, 0.0)) / scale.y
	_sprite.position = Vector2(-FRAME_SIZE / 2.0, BOTTOM_Y - FRAME_SIZE - lift)
	# 웅크림: 납작해졌다가 튀어나간다
	_sprite.scale = Vector2(1.15, 0.85) if _windup >= 0.0 or _aim >= 0.0 or _log_aim >= 0.0 else Vector2.ONE
	_sprite.modulate = Color(1, 1, 1) * 2.0 if _flash > 0.0 and int(_flash * 20) % 2 == 0 else _tint
	z_index = int(sort_y())
	queue_redraw()


## 달려들기·대장 패턴을 한 틱 진행한다. 이번 틱에 공격 동작 중이었으면 true (깡충 뛰기는 쉼).
func _tick_attack(delta: float, target: Vector2) -> bool:
	_lunge_cd = maxf(_lunge_cd - delta, 0.0)
	_pattern_cd = maxf(_pattern_cd - delta, 0.0)
	if _recover > 0.0:
		_recover -= delta
		return true
	if _windup >= 0.0:
		_windup -= delta
		if _windup < 0.0:
			_lunge_from = position
			_lunge_t = 0.0
		return true
	if _lunge_t >= 0.0:
		_lunge_t = minf(_lunge_t + delta / Config.LUNGE_TIME, 1.0)
		var to := _stand(_lunge_from + _lunge_dir * Config.LUNGE_DISTANCE * _lunge_t)
		var blocked := to == position and _lunge_t < 1.0
		position = to
		if _lunge_t >= 1.0 or blocked:
			_lunge_t = -1.0
			_recover = Config.LUNGE_RECOVER
			_lunge_cd = Config.LUNGE_COOLDOWN
		return true
	if _air_t >= 0.0:
		_air_t = minf(_air_t + delta / Config.SLAM_AIR_TIME, 1.0)
		position = _air_from.lerp(_air_to, _air_t)
		if _air_t >= 1.0:
			_air_t = -1.0
			position = _stand(_air_to)
			_recover = Config.SLAM_RECOVER
			_pattern_cd = Config.SLAM_COOLDOWN
			slammed.emit(position)
		return true
	if _aim >= 0.0:
		_aim -= delta
		if _aim < 0.0:
			_lash = Config.TONGUE_LASH_TIME
			lashed.emit(position, _tongue_to)
		return true
	if _lash > 0.0:
		_lash -= delta
		if _lash <= 0.0:
			_recover = Config.TONGUE_RECOVER
			_pattern_cd = Config.TONGUE_COOLDOWN
		return true
	if _log_aim >= 0.0:
		_log_aim -= delta
		if _log_aim < 0.0:
			_log_t = 0.0
		return true
	if _log_t >= 0.0:
		_log_t = minf(_log_t + delta / Config.LOG_TIME, 1.0)
		rolled.emit(log_at())
		if _log_t >= 1.0:
			_log_t = -1.0
			_recover = Config.LOG_RECOVER
			_pattern_cd = Config.LOG_COOLDOWN
		return true
	if not _bales.is_empty():
		for i in range(_bales.size() - 1, -1, -1):
			_bales[i].t -= delta
			if _bales[i].t <= 0.0:
				bale_landed.emit(_bales[i].at)
				_bales.remove_at(i)
		if _bales.is_empty():
			_recover = Config.STRAW_RECOVER
			_pattern_cd = Config.STRAW_COOLDOWN
			_throws += 1
			if _throws % 2 == 0:
				called.emit(position)
		return true
	if _hop_t >= 0.0:
		return false
	var d := position.distance_to(target)
	if boss:
		if pattern == &"slam" and _pattern_cd <= 0.0 and d <= Config.SLAM_RANGE:
			_air_from = position
			_air_to = _stand(target)
			_air_t = 0.0
			return true
		if pattern == &"straw" and _pattern_cd <= 0.0 and d <= Config.STRAW_RANGE:
			# 짚단 셋: 발밑 → 양옆 (비켜서도 한 번 더 노림)
			var side := (target - position).normalized().orthogonal() * Config.STRAW_SPREAD
			var spots := [target, target + side, target - side]
			for i in Config.STRAW_BALES:
				_bales.append({at = spots[i % spots.size()], t = Config.STRAW_WINDUP + i * Config.STRAW_GAP})
			return true
		if pattern == &"log" and _pattern_cd <= 0.0 and d <= Config.LOG_RANGE:
			var dir := (target - position).normalized()
			if dir == Vector2.ZERO:
				dir = Vector2.DOWN
			_log_from = position + dir * 16.0
			_log_to = (_log_from + dir * Config.LOG_LENGTH).clamp(area.position, area.end)
			_log_aim = Config.LOG_WINDUP
			return true
		if pattern == &"tongue" and _pattern_cd <= 0.0 and d <= Config.TONGUE_RANGE:
			_tongue_to = position + (target - position).normalized() * Config.TONGUE_RANGE
			_aim = Config.TONGUE_WINDUP
			return true
		return false
	if _lunge_cd <= 0.0 and d <= Config.LUNGE_TRIGGER:
		_lunge_dir = (target - position).normalized()
		if _lunge_dir == Vector2.ZERO:
			_lunge_dir = Vector2.DOWN
		_windup = windup_time
		return true
	return false


## 참새 한 틱: 땅에서 쪼기 → 날아올라 맴돌기 → 그림자 원 예고 → 내려꽂기 → 다시 쪼기.
func _tick_fly(delta: float, target: Vector2) -> void:
	var d := position.distance_to(target)
	if _dive_t >= 0.0:
		_dive_t = minf(_dive_t + delta / Config.SWOOP_TIME, 1.0)
		position = _dive_from.lerp(_dive_to, _dive_t)
		if _dive_t >= 1.0:
			_dive_t = -1.0
			swooped.emit(position)
			if terrain and not terrain.monster_ok(position + Vector2(0, BOTTOM_Y - 2)):
				# 물·짚가리 위에는 못 앉으니 곧장 다시 날아오른다
				_fly = randf_range(Config.FLY_TIME.x, Config.FLY_TIME.y)
			else:
				_rest = Config.SWOOP_RECOVER
		return
	if _swoop >= 0.0:
		_swoop -= delta
		if _swoop < 0.0:
			_dive_from = position
			_dive_t = 0.0
		return
	if _fly >= 0.0:
		_fly -= delta
		_angle += delta * 1.8
		var goal := target + Vector2(cos(_angle), sin(_angle) * 0.6) * Config.FLY_CIRCLE
		position = position.move_toward(goal, Config.FLY_SPEED * speed * delta).clamp(area.position, area.end)
		if d > Config.FLY_NOTICE * 2.0 and (terrain == null or terrain.monster_ok(position + Vector2(0, BOTTOM_Y - 2))):
			# 사냥꾼이 멀리 가 버리면 내려앉아 다시 쫀다
			_fly = -1.0
			_rest = randf_range(0.5, 1.5)
		elif _fly < 0.0:
			_swoop = windup_time
			_dive_to = target.clamp(area.position, area.end)
		return
	_rest -= delta
	if _rest <= 0.0 and d <= Config.FLY_NOTICE:
		_fly = randf_range(Config.FLY_TIME.x, Config.FLY_TIME.y)


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
	# 달려들기·혀 채찍 예고: 머리 위 느낌표
	if _windup >= 0.0 or _aim >= 0.0 or _log_aim >= 0.0:
		draw_circle(Vector2(0, -30), 6.0, Color(1.0, 0.92, 0.5))
		draw_arc(Vector2(0, -30), 6.0, 0, TAU, 16, Color(0.6, 0.15, 0.1), 1.0)
		draw_string(ThemeDB.fallback_font, Vector2(-2.5, -25), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.85, 0.15, 0.1))
	# 혀 채찍: 뻗은 혀 (입 → 혀끝, 크기 배율을 되돌려 월드 길이로)
	if _lash > 0.0:
		var tip := (_tongue_to - position) / scale.x
		draw_line(Vector2(0, -4), tip, Color(0.95, 0.45, 0.55), 3.0 / scale.x)
		draw_circle(tip, 3.0 / scale.x, Color(0.95, 0.45, 0.55))
	# 굴러가는 통나무 (임시 그림: 갈색 통나무 + 나이테 끝)
	if _log_t >= 0.0:
		var at := (log_at() - position) / scale.x
		var dir := (_log_to - _log_from).normalized()
		var side := dir.orthogonal() * 11.0 / scale.x
		var roll := _log_t * 10.0
		draw_line(at - side, at + side, Color(0.45, 0.32, 0.22), 8.0 / scale.x)
		draw_line(at - side + dir * sin(roll) / scale.x, at + side + dir * sin(roll) / scale.x, Color(0.6, 0.44, 0.3), 3.0 / scale.x)
		for e in [at - side, at + side]:
			draw_circle(e, 4.0 / scale.x, Color(0.86, 0.74, 0.55))
			draw_circle(e, 1.5 / scale.x, Color(0.6, 0.44, 0.3))
	# 대장 이름표 (디아블로2 챔피언처럼 금색)
	if boss:
		var font := ThemeDB.fallback_font
		var w := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 6).x
		draw_rect(Rect2(-w / 2 - 1.5, -35.5, w + 3, 7), Color(0, 0, 0, 0.55))
		draw_string(font, Vector2(-w / 2, -30), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 6, Color(0.95, 0.85, 0.45))
