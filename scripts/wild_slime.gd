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

var hp := Config.WILD_SLIME_HP * Config.DMG_UNIT
var max_hp := Config.WILD_SLIME_HP * Config.DMG_UNIT
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
## 느려진 남은 시간 (물의 지팡이). 그동안 움직임 · 예고 · 공격이 Config.STAFF_SLOW_MULT 배로 흐른다.
var _slow := 0.0

## 부딪히면 잃는 체력 (구역 damage 는 옛 하트 단위, 레벨을 곱해 체력으로) · 맞았을 때 밀려나는 거리 · 달려들기 예고 시간 (구역마다, Config.HUNT_ZONES)
var damage := 1
var knockback := 14.0
var windup_time := 0.6
## 대장 패턴 (&"slam" 내려찍기 · &"tongue" 혀 채찍), 대장만
var pattern := &""
## 대장 내려찍기 때 튀어나온 새끼 (알·드롭 없음)
var minion := false
## 몰아잡기 떼 (2026-10-02): 이 몬스터 한 마리가 예전 한 마리의 몇 몫인지 (드롭 · 알 확률에 곱함). 떼 4마리면 0.25.
var share := 1.0
## 맞았을 때 밀려나는 거리 배율 (몰아 베기, Config.HIT_KNOCKBACK_MULT)
var knock_mult := 1.0
## false 면 새 달려들기 · 내려꽂기 · 불똥 예고를 시작하지 않는다 (이미 예고 중인 몬스터가 Config.MAX_ATTACKERS 마리면 HuntGround 가 끈다)
var may_attack := true
## 몰아잡기 떼: 같은 떼 번호 (-1 = 떼 아님) · 떼가 모여 있는 자리 · 사냥꾼을 알아챘는지 (하나가 알아채면 떼 모두, HuntGround)
var pack_id := -1
var home := Vector2.ZERO
var alert := false

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

## 까마귀 (광동리 flyer, 2026-09-29 선택 B): 날아다니다 내려꽂는다. 나는 동안 position 은 그림자(땅) 자리이고 그림만 띄운다.
var flyer := false
## 맴도는 남은 시간 (-1 = 땅에 있음) · 내려꽂기 예고 남은 시간 · 내려꽂는 진행(0~1)
var _fly := -1.0
var _swoop := -1.0
var _dive_t := -1.0
var _dive_from := Vector2.ZERO
var _dive_to := Vector2.ZERO
var _angle := 0.0
## 도깨비불 (번천 wisp, 2026-09-29 선택 A): 떠다니며 벽 · 물을 지나간다. 불빛 안(lit)에서 가까이 오면 부풀어 불똥을 튀긴다.
var wisp := false
## 지금 불빛 안인지 (HuntGround 가 틱마다 알려 줌. 밤 구역이 아니면 늘 true)
var lit := true
## 부푸는 예고 남은 시간 (-1 = 아님)
var _burst := -1.0
## 뿔 악귀 두 번째 내려찍기 중 (2026-10-02 3~4막 난이도: 한 번 찍고 곧바로 한 걸음 다가와 또 찍음)
var _second := false
## 유령 막차 (번천 대장 bus): 예고 남은 시간(-1 = 아님) → 돌진 진행(0~1, -1 = 아님), 돌진 길, 돌진 횟수 (두 번에 한 번 승객)
var _bus_aim := -1.0
var _bus_t := -1.0
var _bus_from := Vector2.ZERO
var _bus_to := Vector2.ZERO
var _runs := 0
## 그림자 늑대 (밀목 wolf, 2026-09-30): 사냥꾼을 보면 둘레에 둘러서서 돌다가 하나씩 달려든다
var wolf := false
## 켄타우로스 창기병 (역동 lancer, 2026-10-02): 달려들기가 길다 (발 구름 예고 → 들판을 가로지르는 돌격 → 돌아서는 틈)
var lancer := false
## 달려들기 거리 · 시간 (보통 LUNGE_*, 창기병은 LANCER_*)
var _lunge_len := Config.LUNGE_DISTANCE
var _lunge_time := Config.LUNGE_TIME
## 역마 장군 (역동 대장 general): 남은 창 돌격 수, 말발굽 쿵을 이번 차례에 했는지
var _charges_left := 0
var _stomped := false
var _circling := false
## 뿔 악귀 (곤지암 demon, 2026-10-02): 사냥꾼이 바라보는 동안 얼어붙고 (watched, HuntGround 가 틱마다 알려 줌), 아니면 걸어서 다가와 내려찍는다.
## 정전 (blackout, 마왕) 동안엔 바라봐도 움직인다.
var demon := false
var watched := false
var blackout := false
var _walking := false
## 겁먹은 남은 시간 (아기 악귀 동행 겁주기): 그동안 사냥꾼에게서 달아나고 공격하지 않는다
var _fear := 0.0
## 마왕 (곤지암 대장 archdemon): 등불 깜빡임 예고 남은 시간 (-1 = 아님), 다음 패턴 차례 (짝수 정전 · 홀수 지옥불 기둥)
var _dim := -1.0
var _arch_step := 0
## 산군 백호 (밀목 대장 tiger): 다음 패턴 차례 (0 도약 · 1 쓰러지는 나무 · 2 포효), 포효 예고 남은 시간(-1 = 아님)
var _tiger_step := 0
var _roar := -1.0
## 대장 그림이 32칸 시트가 아닐 때 한 장 크기 (유령 막차 96x48). ZERO 면 32칸 시트.
var boss_frame := Vector2i.ZERO
## 시트 한 칸 크기 (32 또는 대장 고해상 58) · 스프라이트를 이 노드 안에서 키우는 배율.
## 2026-10-01 사용자: "보스몬스터의 도트가 너무 깨져보이는 현상" → 화면에서 원본 1px 이 늘 1px (고해상) 또는 2px (32칸 대장) 이 되게.
var _frame := FRAME_SIZE
var _px := 1.0
## 허수아비 장수 짚단 던지기: 떨어질 짚단들 {at, t = 남은 시간}, 던진 횟수 (두 번에 한 번 까마귀 부르기)
var _bales: Array[Dictionary] = []
var _throws := 0
## 천하대장군 통나무 굴리기 (도마리): 예고 남은 시간(-1 = 아님) → 굴러가는 진행(0~1, -1 = 아님), 굴러갈 길
var _log_aim := -1.0
var _log_t := -1.0
var _log_from := Vector2.ZERO
var _log_to := Vector2.ZERO
## 소내섬 용 (dragon, 2026-10-03 사용자: "마지막은 기본이 일반용이고 희귀한 확률로 세가지 용이 우연하게나오는 구조로가자"):
## 어떤 용인지 (&"" 일반 용 · &"blue" 청룡 · &"cloud" 운룡 · &"gold" 황금 드래곤), 다음 패턴 차례
## (일반 용: 0 물어뜯기 돌진 · 1 날개 바람, 희귀 용: 2 자기 기술 = 청룡 물기둥 · 운룡 안개 · 황금 불 숨결 + 금화 비)
var variant := &""
var _dragon_step := 0
## 방금 떨어진 짚단 · 기둥 · 날개 바람 · 금화 (bale_landed 를 받는 HuntGround 가 종류를 본다)
var landing := {}
## 귀여리 방패 도마뱀 (shield, 2026-10-03 임시 A): 바라보는 쪽 (_face) 에서 친 공격은 방패에 막힌다.
## 창을 찌른 뒤 (_recover 동안) 방패가 내려가고, 옆 · 등 뒤는 늘 열려 있다. gold_t 동안 (족장 전쟁 북) 금빛 방패 = 찌른 뒤에도 앞 · 옆을 막음.
var shield := false
var gold_t := 0.0
var _face := Vector2.DOWN
## 도마뱀 족장 (chief): 전쟁 북 예고 남은 시간 (-1 = 없음), 다음 패턴 차례 (0 북 · 1 꼬리 휘두르기 · 2 창 던지기 셋 = 절반부터)
var _drum := -1.0
var _chief_step := 0

## 까마귀가 내려꽂았다 (내려앉은 곳). HuntGround 가 받아 원 안의 사냥꾼을 다치게 한다.
signal swooped(at: Vector2)
## 짚단이 떨어졌다. HuntGround 가 받아 원 안의 사냥꾼을 다치게 한다.
signal bale_landed(at: Vector2)
## 허수아비 장수가 까마귀를 불렀다 (HuntGround 가 까마귀를 놓는다)
signal called(at: Vector2)
## 대장이 내려찍었다 (떨어진 곳). HuntGround 가 받아 원 안의 사냥꾼을 다치게 하고 새끼를 놓는다.
signal slammed(at: Vector2)
## 통나무가 굴러가는 중 (지금 통나무 자리). HuntGround 가 받아 닿은 사냥꾼을 다치게 한다.
signal rolled(at: Vector2)
## 도깨비불이 불똥을 튀겼다 (도깨비불 자리). HuntGround 가 받아 원 안의 사냥꾼을 다치게 한다.
signal burst(at: Vector2)
## 유령 막차가 달리는 중 (지금 버스 자리). HuntGround 가 받아 닿은 사냥꾼을 다치게 한다.
signal rammed(at: Vector2)
## 산군 백호가 포효했다 (백호 자리). HuntGround 가 받아 원 안의 사냥꾼을 잠깐 굳힌다.
signal roared(at: Vector2)
## 대장이 혀를 뻗었다 (입 → 혀끝). HuntGround 가 받아 선 위의 사냥꾼을 다치게 하고 금가루를 뿌린다.
signal lashed(from: Vector2, to: Vector2)
## 마왕 등불이 꺼졌다 (정전 + 등 뒤에 악귀). 운룡은 안개 (안개 + 등 뒤에 와이번).
signal dimmed(at: Vector2)


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.centered = false
	_sprite.modulate = _tint
	add_child(_sprite)
	_apply_sheet()
	_rest = randf_range(0.3, Config.WILD_SLIME_REST_TIME)


## 구역에 맞춘다: 체력 · 빠르기 · 색 (트리에 넣기 전에 부른다)
func setup_zone(zone: int) -> void:
	var z: Dictionary = Config.HUNT_ZONES[zone]
	title = z.monster
	speed = z.speed
	# 몬스터 레벨 (2026-10-02 체력 숫자): 구역 몬스터 레벨이 높을수록 체력 · 피해가 오른다
	hp = HunterSkills.monster_hp(zone, z.hp)
	max_hp = hp
	_tint = z.monster_tint
	sheet = load(z.sheet)
	buried = z.burrow
	disguise = z.get("disguise", false)
	damage = HunterSkills.monster_damage(zone, z.get("damage", 1))
	knockback = z.get("knockback", 14.0)
	windup_time = z.get("windup", 0.6)
	flyer = z.get("flyer", false)
	wisp = z.get("wisp", false)
	wolf = z.get("wolf", false)
	lancer = z.get("lancer", false)
	demon = z.get("demon", false)
	shield = z.get("shield", false)
	_angle = randf() * TAU
	if shield:
		_lunge_len = Config.LIZARD_THRUST
		_lunge_time = Config.LIZARD_THRUST_TIME
	if lancer:
		_lunge_len = Config.LANCER_DISTANCE
		_lunge_time = Config.LANCER_TIME
		_lunge_cd = randf() * Config.LANCER_COOLDOWN
	if wolf:
		# 둘러선 늑대가 한꺼번에 달려들지 않게 첫 쿨을 어긋나게
		_lunge_cd = Config.WOLF_FIRST_GAP + randf() * Config.WOLF_LUNGE_COOLDOWN


## 대장으로 만든다 (트리에 넣기 전후 모두 가능)
func make_boss(zone := 0) -> void:
	boss = true
	hp = HunterSkills.monster_hp(zone, Config.HUNT_ZONES[zone].boss_hp)
	max_hp = hp
	var z: Dictionary = Config.HUNT_ZONES[zone]
	title = z.boss_monster
	speed = z.speed
	scale = Vector2.ONE * Config.BOSS_SCALE
	_tint = z.boss_tint
	buried = false
	flyer = false
	damage = HunterSkills.monster_damage(zone, z.get("damage", 1))
	knockback = z.get("knockback", 14.0)
	pattern = z.get("boss_pattern", &"")
	wisp = false
	wolf = false
	lancer = false
	demon = false
	shield = false
	_lunge_len = Config.LUNGE_DISTANCE
	_lunge_time = Config.LUNGE_TIME
	sheet = load(z.boss_sheet)
	boss_frame = z.get("boss_frame", Vector2i.ZERO)
	if boss_frame != Vector2i.ZERO:
		# 큰 한 장 그림 (유령 막차): 대장 배율 없이 그대로
		scale = Vector2.ONE
	if _sprite:
		_apply_sheet()


## 시트를 스프라이트에 입힌다 (32칸 시트 또는 큰 한 장)
func _apply_sheet() -> void:
	_sprite.texture = sheet
	if boss_frame != Vector2i.ZERO:
		_sprite.hframes = 1
		_sprite.position = Vector2(-boss_frame.x / 2.0, BOTTOM_Y - boss_frame.y)
	else:
		_frame = sheet.get_height()
		_sprite.hframes = sheet.get_width() / _frame
		# 화면 배율 (노드 배율 x 스프라이트 배율): 32칸이 아닌 시트 (대장 고해상 58 · 새끼 21) 는 1, 32칸 대장 시트는 정수 2, 그 밖은 노드 배율 그대로
		var net := 1.0 if _frame != FRAME_SIZE else (2.0 if boss else scale.x)
		_px = net / scale.x
		_sprite.scale = Vector2.ONE * _px
		_sprite.position = Vector2(-_frame * _px / 2.0, BOTTOM_Y - _frame * _px)


## 짝 대장으로 바꾼다 (도마리 지하여장군: 구역 데이터 partner = {name, sheet, pattern}). make_boss 뒤에 부른다.
func make_partner(zone := 0) -> void:
	var p: Dictionary = Config.HUNT_ZONES[zone].partner
	title = p.name
	pattern = p.pattern
	sheet = load(p.sheet)
	_pattern_cd = 3.0
	if _sprite:
		_apply_sheet()


## 바라보는 동안 얼어붙은 뿔 악귀 (정전 · 겁먹음 · 대장은 아님)
func gazed_frozen() -> bool:
	return demon and watched and not blackout and not boss and _fear <= 0.0


## 마왕 체력 절반 아래 (정전이 길고 지옥불 기둥이 늘어남)
func enraged() -> bool:
	return hp * 2 < max_hp


## 겁먹는다 (아기 악귀 동행): seconds 동안 사냥꾼에게서 달아나고, 하던 예고는 멈춘다. 대장은 겁먹지 않는다.
func scare(seconds: float) -> void:
	if boss:
		return
	_fear = maxf(_fear, seconds)
	_windup = -1.0
	_burst = -1.0
	_second = false
	_hop_t = -1.0


func _flee(delta: float, target: Vector2) -> void:
	var away := (position - target).normalized()
	if away == Vector2.ZERO:
		away = Vector2.UP
	position = _stand(position + away * Config.IMP_FLEE_SPEED * delta)


## 오른쪽을 보는 네발 짐승 그림 (늑대 · 백호 · 창기병 · 역마 장군 · 소내섬 용)
func _quad() -> bool:
	return wolf or lancer or pattern == &"tiger" or _charger()


## 꺾어 잇는 돌격을 하는 대장 (역마 장군 창 돌격 · 소내섬 용 물어뜯기 돌진)
func _charger() -> bool:
	return pattern == &"general" or pattern == &"dragon"


## 소내섬 용을 희귀 용으로 바꾼다 (구역 데이터 variants 의 하나: {id, name, sheet}). make_boss 뒤에 부른다.
func make_variant(v: Dictionary) -> void:
	variant = v.id
	title = v.name
	sheet = load(v.sheet)
	if _sprite:
		_apply_sheet()


## 방패 도마뱀이 from 에서 온 공격을 방패로 막는지 (앞 = _face 쪽, 금빛이면 옆까지 · 찌른 뒤에도)
func blocks(from: Vector2) -> bool:
	if not shield or _stun > 0.0:
		return false
	var to := (from - position).normalized()
	if gold_t > 0.0:
		return to.dot(_face) > Config.LIZARD_GOLD_DOT
	return _recover <= 0.0 and _lunge_t < 0.0 and to.dot(_face) > Config.LIZARD_FRONT_DOT


func sort_y() -> float:
	return position.y + BOTTOM_Y


## 대장 내려찍기 때 튀어나오는 새끼로 만든다 (트리에 넣기 전에, setup_zone 뒤에)
func make_minion(zone := 0) -> void:
	minion = true
	hp = HunterSkills.minion_hp(zone, 1)
	max_hp = hp
	title = "새끼 " + title
	scale = Vector2.ONE * Config.MINION_SCALE
	# 새끼용 작은 시트 (<이름>_mini.png, 21칸)가 있으면 그걸 줄이지 않고 그린다 (줄이면 도트가 깨짐)
	var small := sheet.resource_path.get_basename() + "_mini.png" if sheet else ""
	if small != "" and ResourceLoader.exists(small):
		sheet = load(small)
	if _sprite:
		_apply_sheet()
	_lunge_cd = 1.0


## 한 대 맞는다. 쓰러지면 true. 웅크리는 중이면 밀려나도 달려들기는 멈추지 않는다.
func hit(from: Vector2, amount := Config.DMG_UNIT) -> bool:
	buried = false
	if flyer:
		if in_air():
			# 날던 까마귀는 쪼여서 땅에 떨어진다 (아기 까마귀 동행만 닿음)
			_fly = -1.0
			_swoop = -1.0
			_dive_t = -1.0
			position = _stand(position)
			_rest = Config.SWOOP_RECOVER
		else:
			# 맞으면 조금만 더 쪼다가 날아오른다
			_rest = minf(_rest, Config.SWOOP_HIT_RECOVER)
	hp -= amount
	_flash = 0.25
	# 쓰러뜨리는 마지막 한 방은 조금 낮고 묵직하게
	Sound.sfx(&"hit", 0.0, 0.8 if hp <= 0 else 1.0)
	var away := (position - from).normalized()
	if away == Vector2.ZERO:
		away = Vector2.UP
	if _air_t < 0.0 and _bus_t < 0.0 and boss_frame == Vector2i.ZERO:
		position = _stand(position + away * knockback * knock_mult)
	_hop_t = -1.0
	if not flyer:
		_rest = Config.WILD_SLIME_REST_TIME
	return hp <= 0


## 공중에 떠 있어 칼·몸이 닿지 않는다 (대장 내려찍기)
func airborne() -> bool:
	return _air_t >= 0.0 or in_air()


## 까마귀가 공중에 있다 (맴돌기 · 예고 · 내려꽂는 중)
func in_air() -> bool:
	return _fly >= 0.0 or _swoop >= 0.0 or _dive_t >= 0.0


## 몰아잡기 떼 한 마리로 만든다 (setup_zone 뒤에): 체력을 낮추고 드롭 몫을 1/n 로
func make_swarm(n: int) -> void:
	hp = maxi(Config.DMG_UNIT, roundi(hp * Config.SWARM_HP_MULT))
	max_hp = hp
	share = 1.0 / n


## 달려들기 · 내려꽂기 · 불똥을 예고하거나 하는 중 (한꺼번에 덮치는 수를 셀 때)
func attacking() -> bool:
	return _windup >= 0.0 or _lunge_t >= 0.0 or _burst >= 0.0 or _swoop >= 0.0 or _dive_t >= 0.0


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
		var w: float = b.get("w", Config.STRAW_WINDUP)
		var plain: bool = not (b.get("pillar", false) or b.get("gust", false) or b.get("coin", false) or b.get("tail", false) or b.get("spear", false))
		out.append({kind = &"circle", at = b.at, radius = b.get("r", Config.STRAW_RADIUS), progress = clampf(1.0 - b.t / w, 0.0, 1.0), bale = plain, pillar = b.get("pillar", false),
			water = b.get("water", false), coin = b.get("coin", false), gust = b.get("gust", false), tail = b.get("tail", false), spear = b.get("spear", false)})
	var one := _telegraph_one()
	if not one.is_empty():
		out.append(one)
	return out


func _telegraph_one() -> Dictionary:
	if _windup >= 0.0:
		return {kind = &"lane", from = position, to = _stand_line(position, _lunge_dir, _lunge_len), width = Config.LUNGE_WIDTH * scale.x, progress = 1.0 - _windup / windup_time}
	if _air_t >= 0.0:
		return {kind = &"circle", at = _air_to, radius = Config.SLAM_RADIUS, progress = _air_t}
	if _aim >= 0.0:
		return {kind = &"lane", from = position, to = _tongue_to, width = Config.TONGUE_WIDTH, progress = 1.0 - _aim / Config.TONGUE_WINDUP}
	if _log_aim >= 0.0:
		return {kind = &"lane", from = _log_from, to = _log_to, width = Config.LOG_WIDTH, progress = 1.0 - _log_aim / Config.LOG_WINDUP}
	if _burst >= 0.0:
		return {kind = &"circle", at = position, radius = Config.DEMON_SLAM_RADIUS if demon else Config.WISP_BURST_RADIUS, progress = 1.0 - _burst / (Config.DEMON_SECOND_WINDUP if _second else windup_time)}
	if _roar >= 0.0:
		return {kind = &"circle", at = position, radius = Config.TIGER_ROAR_RADIUS, progress = 1.0 - _roar / Config.TIGER_ROAR_WINDUP, roar = true}
	if _bus_aim >= 0.0 and _charger():
		return {kind = &"lane", from = _bus_from, to = _bus_to, width = _charge_radius() * 2.0, progress = 1.0 - _bus_aim / _general_windup()}
	if _bus_t >= 0.0 and _charger():
		return {kind = &"lane", from = position, to = _bus_to, width = _charge_radius() * 2.0, progress = 1.0}
	if _bus_aim >= 0.0:
		return {kind = &"lane", from = _bus_from, to = _bus_to, width = Config.BUS_WIDTH, progress = 1.0 - _bus_aim / Config.BUS_WINDUP}
	if _bus_t >= 0.0:
		return {kind = &"lane", from = position, to = _bus_to, width = Config.BUS_WIDTH, progress = 1.0}
	if _log_t >= 0.0:
		# 굴러가는 중: 남은 길을 계속 보여 준다 (봇이 비킬 수 있게)
		return {kind = &"lane", from = log_at(), to = _log_to, width = Config.LOG_WIDTH, progress = 1.0}
	return {}


## 역마 장군 돌격 예고 시간 (첫 돌격은 길게, 꺾어 잇는 돌격은 짧게). 소내섬 용도 같은 식 (DRAGON_*).
func _general_windup() -> float:
	if pattern == &"dragon":
		return Config.DRAGON_WINDUP if _charges_left >= _dragon_charges() else Config.DRAGON_NEXT_WINDUP
	return Config.GENERAL_WINDUP if _charges_left >= Config.GENERAL_CHARGES else Config.GENERAL_NEXT_WINDUP


## 돌격에 닿는 반지름 (역마 장군 창 · 용 몸통)
func _charge_radius() -> float:
	return Config.DRAGON_HIT_RADIUS if pattern == &"dragon" else Config.GENERAL_HIT_RADIUS


## 용 물어뜯기 돌진 횟수 (체력 절반 아래면 하나 더)
func _dragon_charges() -> int:
	return Config.DRAGON_CHARGES + (1 if enraged() else 0)


## from 에서 dir 쪽으로 length 만큼 가되, 막힌 칸 (나무 · 바위 · 마방) 앞에서 멈춘 자리 (창기병 · 장군 돌격 띠 끝)
func _stand_line(from: Vector2, dir: Vector2, length: float) -> Vector2:
	var at := from
	var step := 6.0
	var went := 0.0
	while went < length:
		var nxt := (at + dir * minf(step, length - went)).clamp(area.position, area.end) if area.has_area() else at + dir * minf(step, length - went)
		if terrain and not terrain.monster_ok(nxt):
			break
		if nxt == at:
			break
		at = nxt
		went += step
	return at


## 역마 장군이 사냥꾼 쪽으로 창 돌격을 겨눈다
func _aim_general(target: Vector2) -> void:
	var dir := (target - position).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.LEFT
	_bus_from = position
	_bus_to = _stand_line(position, dir, Config.DRAGON_LENGTH if pattern == &"dragon" else Config.GENERAL_LENGTH)
	_bus_aim = _general_windup()


## 굴러가는 통나무 자리
func log_at() -> Vector2:
	return _log_from.lerp(_log_to, maxf(_log_t, 0.0))


## 혀에 끌려 to 까지 짧게 미끄러진다 (금두꺼비 혀 당기기). 멈춤과 함께 쓴다.
func pull_to(to: Vector2) -> void:
	_pull_from = position
	_pull_to = to
	_pull_t = 0.0
	_hop_t = -1.0


func slow(time: float) -> void:
	_slow = maxf(_slow, time)


func slowed() -> bool:
	return _slow > 0.0


func stunned() -> bool:
	return _stun > 0.0


func tick(delta: float, target: Vector2) -> void:
	if _slow > 0.0:
		_slow = maxf(_slow - delta, 0.0)
		delta *= Config.STAFF_SLOW_MULT
	var gazed := gazed_frozen()
	if not gazed:
		# 바라보는 동안 얼어붙은 악귀는 그림도 멈춘다
		_anim_time += delta
	_flash = maxf(_flash - delta, 0.0)
	_stun = maxf(_stun - delta, 0.0)
	_fear = maxf(_fear - delta, 0.0)
	gold_t = maxf(gold_t - delta, 0.0)
	if shield and _windup < 0.0 and _lunge_t < 0.0 and _recover <= 0.0 and _stun <= 0.0 and target != position:
		# 방패는 사냥꾼 쪽을 본다 (찌르는 중 · 찌른 뒤엔 찌른 쪽 그대로)
		_face = (target - position).normalized()
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
	elif ai_enabled and gazed:
		_walking = false
	elif ai_enabled and _fear > 0.0 and not boss:
		_flee(delta, target)
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
				_rest = Config.WILD_SLIME_REST_TIME * randf_range(0.7, 1.3) / speed * (Config.SWARM_ALERT_REST if alert else 1.0)
		else:
			_rest -= delta
			if _rest <= 0.0:
				_start_hop(target)
	# 돌진·내려찍기도 깡충 그림을 쓴다
	var hop_t := maxf(_hop_t, maxf(_lunge_t, _air_t))
	if _charger() and _bus_t >= 0.0:
		hop_t = fmod(_bus_t * 3.0, 1.0)
	var hopping := hop_t >= 0.0
	var cols := BURIED_COLUMNS if buried else (HOP_COLUMNS if hopping else IDLE_COLUMNS)
	var col: int = HOP_COLUMNS[mini(int(hop_t * 4), 3)] if hopping else cols[int(_anim_time * 2.0) % 2]
	if buried and disguise:
		col = BURIED_COLUMNS[1] if fmod(_anim_time + _angle, Config.DISGUISE_BLINK_EVERY) < 0.35 else BURIED_COLUMNS[0]
	if flyer:
		# 날갯짓 · 낟알 쪼기 (내려앉은 뒤) · 앉아 있기
		col = HOP_COLUMNS[int(_anim_time * 10.0) % 4] if in_air() else (BURIED_COLUMNS if _rest > 0.0 else IDLE_COLUMNS)[int(_anim_time * 3.0) % 2]
	elif not _bales.is_empty() or _log_aim >= 0.0 or _log_t >= 0.0 or _roar >= 0.0:
		col = BURIED_COLUMNS[int(_anim_time * 6.0) % 2]
	elif _quad() and (_windup >= 0.0 or (_charger() and _bus_aim >= 0.0)):
		# 네발 짐승 (밀목 · 역동): 6열 웅크림 (창기병 · 장군은 앞발 들어 발 구름) · 7열 지침, 둘러서서 돌 땐 걷기
		col = BURIED_COLUMNS[0]
	elif _quad() and (_recover > 0.0 or _stun > 0.0):
		col = BURIED_COLUMNS[1]
	elif wolf and _circling:
		col = HOP_COLUMNS[int(_anim_time * 8.0) % 4]
	if demon:
		# 뿔 악귀: 걸을 때 2-5열, 팔 치켜듦 (예고) 6열, 숨 고름 7열
		if _burst >= 0.0:
			col = BURIED_COLUMNS[0]
		elif _recover > 0.0 or _stun > 0.0:
			col = BURIED_COLUMNS[1]
		elif _walking or _fear > 0.0:
			col = HOP_COLUMNS[int(_anim_time * 7.0) % 4]
		else:
			col = IDLE_COLUMNS[int(_anim_time * 2.0) % 2]
	if pattern == &"archdemon":
		# 마왕: 등불 깜빡임 (6열 · 0열 번갈아), 지옥불 기둥 6열, 숨 고름 7열 (꺼진 등불)
		if _dim >= 0.0:
			col = BURIED_COLUMNS[0] if int(_anim_time * 12.0) % 2 == 0 else IDLE_COLUMNS[0]
		elif not _bales.is_empty():
			col = BURIED_COLUMNS[0]
		elif _recover > 0.0:
			col = BURIED_COLUMNS[1]
	if wisp:
		# 도깨비불: 부푸는 동안 6열, 튀긴 뒤 쪼그라든 동안 7열
		if _burst >= 0.0:
			col = BURIED_COLUMNS[0]
		elif _recover > 0.0:
			col = BURIED_COLUMNS[1]
		else:
			col = HOP_COLUMNS[int(_anim_time * 4.0) % 4] if _hop_t >= 0.0 else IDLE_COLUMNS[int(_anim_time * 3.0) % 2]
	if boss_frame != Vector2i.ZERO:
		col = 0
		if _bus_t >= 0.0 or _bus_aim >= 0.0:
			_sprite.flip_h = _bus_to.x < position.x
	_sprite.frame = col
	if boss and pattern == &"tongue":
		# 금두꺼비 대장 그림은 오른쪽을 본다 (2026-10-01 사용자: "두꺼비들이 한방향만 바라보니까 어색해"): 혀 겨누는 쪽 · 사냥꾼 쪽으로
		_sprite.flip_h = (_tongue_to.x < position.x) if _aim >= 0.0 else (target.x < position.x)
	elif flyer:
		# 요괴 까마귀 그림은 왼쪽을 본다: 내려찍는 쪽 · 사냥꾼 쪽으로
		_sprite.flip_h = (_dive_to.x > position.x) if in_air() else (target.x > position.x)
	if _charger():
		_sprite.flip_h = (_bus_to.x < _bus_from.x) if (_bus_aim >= 0.0 or _bus_t >= 0.0) else (target.x < position.x)
	elif (demon or pattern == &"archdemon") and not gazed:
		# 악귀 · 마왕 그림은 오른쪽을 본다: 사냥꾼 쪽으로 (달아날 땐 반대쪽)
		_sprite.flip_h = (target.x > position.x) if _fear > 0.0 else (target.x < position.x)
	elif _quad():
		# 네발 짐승 그림은 오른쪽을 본다: 사냥꾼 쪽 (달려드는 중이면 달려드는 쪽) 으로 뒤집는다
		_sprite.flip_h = (_lunge_dir.x < 0.0) if (_windup >= 0.0 or _lunge_t >= 0.0) else (target.x < position.x)
		if lancer and _recover > 0.0:
			# 돌격 뒤 돌아서는 동안은 달려온 쪽을 그대로 본다
			_sprite.flip_h = _lunge_dir.x < 0.0
	if boss_frame != Vector2i.ZERO:
		z_index = int(sort_y())
		_sprite.modulate = Color(1, 1, 1) * 2.0 if _flash > 0.0 and int(_flash * 20) % 2 == 0 else _tint
		queue_redraw()
		return
	# 내려찍기: 공중에서 그림을 위로 띄운다 (그림자는 제자리). 까마귀는 나는 동안 FLY_HEIGHT 만큼.
	var lift := sin(_air_t * PI) * 60.0 / scale.y if _air_t >= 0.0 else 0.0
	if flyer and in_air():
		lift = Config.FLY_HEIGHT * (1.0 - maxf(_dive_t, 0.0)) / scale.y
	var crouch := (_windup >= 0.0 and not lancer) or _aim >= 0.0 or _log_aim >= 0.0
	_sprite.position = Vector2(-_frame * _px / 2.0, BOTTOM_Y - _frame * _px - lift)
	# 웅크림: 납작해졌다가 튀어나간다. 대장은 배율을 바꾸면 도트가 깨져서 대신 2px 내려앉는다.
	if boss:
		_sprite.scale = Vector2.ONE * _px
		if crouch:
			_sprite.position.y += 2.0 / scale.y
	else:
		_sprite.scale = Vector2(1.15, 0.85) * _px if crouch else Vector2.ONE * _px
	if wisp:
		# 도깨비불은 둥둥 떠 있다
		_sprite.position.y -= 3.0 + sin(_anim_time * 3.0 + _angle) * 2.0
		_sprite.scale = Vector2.ONE * _px
	_sprite.modulate = Color(1, 1, 1) * 2.0 if _flash > 0.0 and int(_flash * 20) % 2 == 0 else _tint
	if _slow > 0.0 and _flash <= 0.0:
		# 물의 지팡이에 느려진 동안 푸르게
		_sprite.modulate = _tint * Color(0.7, 0.85, 1.4)
	elif gold_t > 0.0 and _flash <= 0.0:
		# 족장 전쟁 북: 금빛 방패 (몸 전체가 금빛으로 번쩍)
		_sprite.modulate = _tint * Color(1.35, 1.15, 0.55) if int(_anim_time * 6.0) % 2 == 0 else _tint * Color(1.2, 1.05, 0.6)
	elif gazed and _flash <= 0.0:
		# 바라보는 동안 얼어붙은 악귀: 잿빛으로
		_sprite.modulate = _tint * Color(0.72, 0.72, 0.84)
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
		_lunge_t = minf(_lunge_t + delta / _lunge_time, 1.0)
		var to := _stand(_lunge_from + _lunge_dir * _lunge_len * _lunge_t)
		var blocked := to == position and _lunge_t < 1.0
		position = to
		if _lunge_t >= 1.0 or blocked:
			_lunge_t = -1.0
			_recover = Config.LANCER_RECOVER if lancer else (Config.LIZARD_SHIELD_DOWN if shield else Config.LUNGE_RECOVER)
			_lunge_cd = Config.WOLF_LUNGE_COOLDOWN if wolf else (Config.LANCER_COOLDOWN if lancer else Config.LUNGE_COOLDOWN)
		return true
	if _air_t >= 0.0:
		_air_t = minf(_air_t + delta / Config.SLAM_AIR_TIME, 1.0)
		position = _air_from.lerp(_air_to, _air_t)
		if _air_t >= 1.0:
			_air_t = -1.0
			position = _stand(_air_to)
			_recover = Config.SLAM_RECOVER
			_pattern_cd = Config.TIGER_LEAP_COOLDOWN if pattern == &"tiger" else Config.SLAM_COOLDOWN
			if pattern == &"general":
				# 말발굽 쿵 뒤엔 바로 창 돌격으로 잇는다 (헐떡임만 잠깐)
				_pattern_cd = 0.0
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
	if _burst >= 0.0:
		_burst -= delta
		if _burst < 0.0:
			burst.emit(position)
			if demon and not _second:
				# 둘째 내려찍기: 사냥꾼 쪽으로 한 걸음 다가와 짧은 예고로 한 번 더 (바라보면 이것도 얼어붙음)
				_second = true
				_burst = Config.DEMON_SECOND_WINDUP
				position = _stand(position.move_toward(target, Config.DEMON_SECOND_STEP))
				return true
			_second = false
			_recover = Config.DEMON_RECOVER if demon else Config.WISP_RECOVER
			_lunge_cd = Config.DEMON_COOLDOWN if demon else Config.WISP_COOLDOWN
		return true
	if _bus_aim >= 0.0:
		_bus_aim -= delta
		if _bus_aim < 0.0:
			_bus_t = 0.0
		return true
	if _dim >= 0.0:
		_dim -= delta
		if _dim < 0.0:
			dimmed.emit(position)
			_recover = Config.ARCH_RECOVER
			_pattern_cd = Config.ARCH_COOLDOWN
		return true
	if _roar >= 0.0:
		_roar -= delta
		if _roar < 0.0:
			roared.emit(position)
			_recover = Config.TIGER_ROAR_RECOVER
			_pattern_cd = Config.TIGER_ROAR_COOLDOWN
		return true
	if _bus_t >= 0.0 and _charger():
		# 역마 장군 창 돌격 · 용 물어뜯기 돌진: 막힌 칸 앞에서 멈춘다. 다 달리면 사냥꾼 쪽으로 꺾어 다음 돌격, 다 하면 헐떡임.
		_bus_t = minf(_bus_t + delta / (Config.DRAGON_TIME if pattern == &"dragon" else Config.GENERAL_TIME), 1.0)
		var to := _stand(_bus_from.lerp(_bus_to, _bus_t))
		var blocked := to == position and _bus_t < 1.0 and _bus_t > 0.2
		position = to
		rammed.emit(position)
		if _bus_t >= 1.0 or blocked:
			_bus_t = -1.0
			_charges_left -= 1
			if _charges_left > 0:
				_aim_general(target)
			else:
				_recover = Config.DRAGON_RECOVER if pattern == &"dragon" else Config.GENERAL_RECOVER
				_pattern_cd = Config.DRAGON_COOLDOWN if pattern == &"dragon" else Config.GENERAL_COOLDOWN
				_stomped = false
				_runs += 1
				if _runs % 2 == 0:
					called.emit(position)
		return true
	if _bus_t >= 0.0:
		_bus_t = minf(_bus_t + delta / Config.BUS_TIME, 1.0)
		# 유령 버스는 가드레일 · 나무도 뚫고 지나간다 (영역 안에서만)
		position = _bus_from.lerp(_bus_to, _bus_t)
		rammed.emit(position)
		if _bus_t >= 1.0:
			_bus_t = -1.0
			_recover = Config.BUS_RECOVER
			_pattern_cd = Config.BUS_COOLDOWN
			_runs += 1
			if _runs % 2 == 0:
				called.emit(position)
		return true
	if _drum >= 0.0:
		_drum -= delta
		if _drum < 0.0:
			# 전쟁 북: 도마뱀 둘을 부르고 모든 방패가 금빛 (HuntGround._on_called)
			called.emit(position)
			_recover = Config.CHIEF_RECOVER
			_pattern_cd = Config.CHIEF_COOLDOWN
		return true
	if not _bales.is_empty():
		for i in range(_bales.size() - 1, -1, -1):
			_bales[i].t -= delta
			if _bales[i].t <= 0.0:
				landing = _bales[i]
				bale_landed.emit(_bales[i].at)
				_bales.remove_at(i)
		if _bales.is_empty() and pattern == &"dragon":
			_recover = Config.DRAGON_SPECIAL_RECOVER
			_pattern_cd = Config.DRAGON_COOLDOWN
		elif _bales.is_empty() and pattern == &"chief":
			_recover = Config.CHIEF_RECOVER
			_pattern_cd = Config.CHIEF_COOLDOWN
		elif _bales.is_empty() and pattern == &"archdemon":
			_recover = Config.ARCH_RECOVER
			_pattern_cd = Config.ARCH_COOLDOWN
		elif _bales.is_empty():
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
		if pattern == &"bus" and _pattern_cd <= 0.0 and d <= Config.BUS_RANGE:
			# 도로 방향으로: 가로 · 세로 중 사냥꾼이 더 먼 쪽으로 달린다
			var v := target - position
			var dir := Vector2(signf(v.x), 0) if absf(v.x) >= absf(v.y) else Vector2(0, signf(v.y))
			if dir == Vector2.ZERO:
				dir = Vector2.LEFT
			_bus_from = position
			_bus_to = (position + dir * Config.BUS_LENGTH).clamp(area.position, area.end)
			_bus_aim = Config.BUS_WINDUP
			return true
		if pattern == &"tiger" and _pattern_cd <= 0.0 and d <= Config.TIGER_RANGE:
			# 도약 → 쓰러지는 나무 → 포효 를 돌아가며 (포효는 가까이 있을 때만, 멀면 도약으로)
			var step := _tiger_step % 3
			if step == 2 and d > Config.TIGER_ROAR_RADIUS * 1.6:
				step = 0
			_tiger_step += 1
			match step:
				0:
					_air_from = position
					_air_to = _stand(target)
					_air_t = 0.0
				1:
					var dir := (target - position).normalized()
					if dir == Vector2.ZERO:
						dir = Vector2.DOWN
					_log_from = position + dir * 16.0
					_log_to = (_log_from + dir * Config.LOG_LENGTH).clamp(area.position, area.end)
					_log_aim = Config.LOG_WINDUP
				2:
					_roar = Config.TIGER_ROAR_WINDUP
			return true
		if pattern == &"general" and _pattern_cd <= 0.0 and d <= Config.GENERAL_RANGE:
			# 체력 절반 아래면 돌격 앞에 말발굽 쿵 (도약 → 착지 원)
			if hp * 2 < max_hp and not _stomped:
				_stomped = true
				_air_from = position
				_air_to = _stand(target)
				_air_t = 0.0
				return true
			_charges_left = Config.GENERAL_CHARGES
			_aim_general(target)
			return true
		if pattern == &"archdemon" and _pattern_cd <= 0.0 and d <= Config.ARCH_RANGE:
			# 등불 깜빡 → 정전 (+ 등 뒤 악귀) 과 지옥불 기둥을 번갈아. 체력 절반 아래면 정전이 길고 기둥이 늘어남
			if _arch_step % 2 == 0:
				_dim = Config.ARCH_DIM_WINDUP
			else:
				var n := Config.ARCH_PILLARS_ENRAGED if enraged() else Config.ARCH_PILLARS
				var turn := randf() * TAU
				for i in n:
					var at := target if i == 0 else target + Vector2.from_angle(turn + TAU * i / maxf(n - 1, 1)) * Config.ARCH_PILLAR_SPREAD * Vector2(1.0, 0.7)
					_bales.append({at = at, t = Config.ARCH_PILLAR_WINDUP + i * Config.ARCH_PILLAR_GAP, w = Config.ARCH_PILLAR_WINDUP, r = Config.ARCH_PILLAR_RADIUS, pillar = true})
			_arch_step += 1
			return true
		if pattern == &"dragon" and _pattern_cd <= 0.0 and d <= Config.DRAGON_RANGE:
			# 물어뜯기 돌진 → 날개 바람 (→ 희귀 용은 자기 기술) 을 돌아가며
			var step := _dragon_step % (2 if variant == &"" else 3)
			_dragon_step += 1
			if step == 0:
				_charges_left = _dragon_charges()
				_aim_general(target)
			elif step == 1:
				_bales.append({at = position, t = Config.DRAGON_GUST_WINDUP, w = Config.DRAGON_GUST_WINDUP, r = Config.DRAGON_GUST_RADIUS, gust = true})
			else:
				_dragon_special(target)
			return true
		if pattern == &"chief" and _pattern_cd <= 0.0 and d <= Config.CHIEF_RANGE:
			# 전쟁 북 → 꼬리 휘두르기 (→ 체력 절반부터 창 던지기 셋) 를 돌아가며
			var step := _chief_step % (3 if enraged() else 2)
			_chief_step += 1
			if step == 0:
				_drum = Config.CHIEF_DRUM_WINDUP
			elif step == 1:
				_bales.append({at = position, t = Config.CHIEF_TAIL_WINDUP, w = Config.CHIEF_TAIL_WINDUP, r = Config.CHIEF_TAIL_RADIUS, tail = true})
			else:
				var turn := randf() * TAU
				for i in Config.CHIEF_SPEARS:
					var at := target if i == 0 else target + Vector2.from_angle(turn + TAU * i / maxf(Config.CHIEF_SPEARS - 1, 1)) * Config.ARCH_PILLAR_SPREAD * Vector2(1.0, 0.7)
					_bales.append({at = at.clamp(area.position, area.end), t = Config.CHIEF_SPEAR_WINDUP + i * 0.25, w = Config.CHIEF_SPEAR_WINDUP, r = Config.CHIEF_SPEAR_RADIUS, spear = true})
			return true
		if pattern == &"tongue" and _pattern_cd <= 0.0 and d <= Config.TONGUE_RANGE:
			_tongue_to = position + (target - position).normalized() * Config.TONGUE_RANGE
			_aim = Config.TONGUE_WINDUP
			return true
		return false
	if wisp:
		# 도깨비불: 불빛 안에서만 부풀어 튀긴다 (어둠 속에선 그냥 떠다님)
		if lit and may_attack and _lunge_cd <= 0.0 and d <= Config.WISP_TRIGGER:
			_burst = windup_time
			return true
		return false
	_circling = false
	_walking = false
	if demon:
		# 뿔 악귀: 붙으면 팔을 치켜들고 내려찍기, 아니면 걸어서 다가온다 (내려찍기 거리 조금 안쪽에서 멈춤 = 몸으로 밀지 않음)
		if may_attack and _lunge_cd <= 0.0 and d <= Config.DEMON_TRIGGER:
			_burst = windup_time
			return true
		if d <= Config.DEMON_NOTICE or alert:
			if d > Config.DEMON_TRIGGER * 0.8:
				var to := _stand(position.move_toward(target, Config.DEMON_WALK * speed * delta))
				_walking = to != position
				position = to
			return true
		return false
	if wolf and d <= Config.WOLF_NOTICE:
		if may_attack and _lunge_cd <= 0.0 and d <= Config.WOLF_RING + 16.0:
			_lunge_dir = (target - position).normalized()
			if _lunge_dir == Vector2.ZERO:
				_lunge_dir = Vector2.DOWN
			_windup = windup_time
			return true
		# 둘러서서 돈다 (자기 자리 각도가 천천히 돈다)
		_angle += delta * Config.WOLF_CIRCLE_SPEED
		var ring := Vector2(cos(_angle), sin(_angle) * 0.7) * Config.WOLF_RING
		var goal := target + ring
		if not area.has_point(goal):
			# 사냥꾼이 구역 가장자리에 서 있으면 둘레 자리가 밖으로 나간다: 안쪽 맞은편에 선다
			goal = target - ring
		var next := position.move_toward(goal, Config.WOLF_MOVE_SPEED * speed * delta)
		var to := _stand(next)
		if to == position and next != position:
			# 나무에 막히면 바깥 둘레로 비껴 돈다
			_angle += delta * 2.0
		position = to
		_circling = true
		return true
	if may_attack and _lunge_cd <= 0.0 and d <= (Config.LANCER_TRIGGER if lancer else Config.LUNGE_TRIGGER):
		_lunge_dir = (target - position).normalized()
		if _lunge_dir == Vector2.ZERO:
			_lunge_dir = Vector2.DOWN
		if lancer and position.distance_to(_stand_line(position, _lunge_dir, _lunge_len)) < Config.LANCER_DISTANCE * 0.4:
			# 창기병: 앞이 나무 · 바위로 막혀 짧으면 돌격하지 않고 자리를 옮긴다
			_lunge_cd = 0.5
			return false
		_windup = windup_time
		return true
	return false


## 희귀 용의 자기 기술 (청룡 물기둥 · 운룡 안개 · 황금 드래곤 불 숨결 + 체력 절반부터 금화 비)
func _dragon_special(target: Vector2) -> void:
	match variant:
		&"blue":
			var n := Config.DRAGON_PILLARS + (2 if enraged() else 0)
			var turn := randf() * TAU
			for i in n:
				var at := target if i == 0 else target + Vector2.from_angle(turn + TAU * i / maxf(n - 1, 1)) * Config.ARCH_PILLAR_SPREAD * Vector2(1.0, 0.7)
				_bales.append({at = at, t = Config.DRAGON_PILLAR_WINDUP + i * Config.ARCH_PILLAR_GAP, w = Config.DRAGON_PILLAR_WINDUP, r = Config.ARCH_PILLAR_RADIUS, pillar = true, water = true})
		&"cloud":
			_dim = Config.DRAGON_FOG_WINDUP
		&"gold":
			var dir := (target - position).normalized()
			if dir == Vector2.ZERO:
				dir = Vector2.DOWN
			_log_from = position + dir * 20.0
			_log_to = (_log_from + dir * Config.LOG_LENGTH).clamp(area.position, area.end)
			_log_aim = Config.DRAGON_BREATH_WINDUP
			if enraged():
				for i in Config.DRAGON_COINS:
					var at := target + Vector2(randf_range(-1, 1), randf_range(-0.7, 0.7)) * Config.ARCH_PILLAR_SPREAD * 1.4
					_bales.append({at = at.clamp(area.position, area.end), t = Config.DRAGON_BREATH_WINDUP + 0.6 + i * 0.25, w = 1.0, r = Config.STRAW_RADIUS, coin = true})


## 까마귀 한 틱: 땅에서 쪼기 → 날아올라 맴돌기 → 그림자 원 예고 → 내려꽂기 → 다시 쪼기.
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
		elif _fly < 0.0 and not may_attack:
			# 다른 까마귀가 내려꽂는 중이면 조금 더 맴돈다
			_fly = 0.3
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
	if wisp:
		# 도깨비불은 떠다녀서 물 · 나무 · 가드레일을 지나간다
		return to
	# 이미 못 서는 곳에 있으면 (혀에 끌려 물가에 떨어졌을 때) 어디로든 빠져나오게 둔다
	var feet := Vector2(0, BOTTOM_Y - 2)
	if terrain and not terrain.monster_ok(to + feet) and terrain.monster_ok(position + feet):
		return position
	return to


## dir 쪽으로 한 번 뛸 자리. 내려앉을 곳만이 아니라 뛰는 길 중간이 물 위면 (물가 모퉁이를 가로지름) 못 뜀.
func _hop_dest(dir: Vector2) -> Vector2:
	var to := _stand(position + dir * Config.WILD_SLIME_HOP_DISTANCE)
	if wisp or terrain == null or to == position or not terrain.monster_ok(position + Vector2(0, BOTTOM_Y - 2)):
		return to
	for k in [0.25, 0.5, 0.75]:
		if not terrain.monster_ok(position.lerp(to, k) + Vector2(0, BOTTOM_Y - 2)):
			return position
	return to


func _start_hop(target: Vector2) -> void:
	var dir: Vector2
	if position.distance_to(target) <= (Config.SWARM_ALERT_CHASE if alert else Config.WILD_SLIME_CHASE_DISTANCE):
		dir = (target - position).normalized()
	elif pack_id >= 0 and position.distance_to(home) > Config.SWARM_SPREAD * 1.5:
		# 떼는 흩어지지 않고 모인 자리 둘레에서 논다
		dir = (home - position).normalized()
	else:
		dir = Vector2.RIGHT.rotated(randf() * TAU)
	var to := _hop_dest(dir)
	if to == position:
		# 물가에 막히면 옆으로 비껴 뛴다
		to = _hop_dest(dir.rotated(PI / 2 * (1 if randf() < 0.5 else -1)))
	_hop_from = position
	_hop_to = to
	_hop_t = 0.0


func _draw() -> void:
	draw_set_transform(Vector2(0, BOTTOM_Y - 1), 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, 10.0, Color(0.27, 0.16, 0.33, 0.25))
	draw_set_transform(Vector2.ZERO)
	# 남은 체력 (맞은 뒤에만 보임)
	var top := -boss_frame.y + 4.0 if boss_frame != Vector2i.ZERO else 0.0
	if hp < max_hp:
		draw_rect(Rect2(-10, -24 + top, 20, 3), Color(0.25, 0.2, 0.2))
		draw_rect(Rect2(-10, -24 + top, 20.0 * hp / max_hp, 3), Color(0.9, 0.5, 0.3))
	if _drum >= 0.0:
		# 전쟁 북: 북 치는 손 위에 퍼지는 고리
		var k := 1.0 - _drum / Config.CHIEF_DRUM_WINDUP
		draw_arc(Vector2(0, -16), 6.0 + 18.0 * fmod(k * 3.0, 1.0), 0.0, TAU, 20, Color(1.0, 0.85, 0.35, 0.8), 1.5)
	# 멈춤 (혀 당기기): 머리 위에 빙글 도는 별 셋
	if _stun > 0.0:
		for i in 3:
			var a := _anim_time * 6.0 + i * TAU / 3.0
			draw_circle(Vector2(cos(a) * 8.0, -22 + sin(a) * 2.0), 2.0, Color(1.0, 0.92, 0.45))
	# 달려들기·혀 채찍 예고: 머리 위 느낌표
	if _bus_aim >= 0.0:
		# 막차 전조등: 앞쪽에 노란 빛 두 줄
		var fw := signf(_bus_to.x - position.x) if absf(_bus_to.x - position.x) > 1.0 else 0.0
		draw_circle(Vector2(fw * 44.0, -12), 5.0, Color(1.0, 0.95, 0.6, 0.9))
	if _dim >= 0.0:
		# 마왕 등불 깜빡임: 손에 든 등불 자리에 초록 불이 꺼졌다 켜졌다
		var fw := -1.0 if _sprite.flip_h else 1.0
		draw_circle(Vector2(fw * 18.0, -22.0) / scale.x, (7.0 if int(_anim_time * 12.0) % 2 == 0 else 3.0) / scale.x, Color(0.5, 1.0, 0.55, 0.45))
	if _windup >= 0.0 or _aim >= 0.0 or _log_aim >= 0.0 or _dim >= 0.0:
		draw_circle(Vector2(0, -30), 6.0, Color(1.0, 0.92, 0.5))
		draw_arc(Vector2(0, -30), 6.0, 0, TAU, 16, Color(0.6, 0.15, 0.1), 1.0)
		draw_string(ThemeDB.fallback_font, Vector2(-2.5, -25), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.85, 0.15, 0.1))
	# 혀 채찍: 뻗은 혀 (입 → 혀끝, 크기 배율을 되돌려 월드 길이로)
	if _lash > 0.0:
		var tip := (_tongue_to - position) / scale.x
		draw_line(Vector2(0, -4), tip, Color(0.95, 0.45, 0.55), 3.0 / scale.x)
		draw_circle(tip, 3.0 / scale.x, Color(0.95, 0.45, 0.55))
	# 굴러가는 통나무 (임시 그림: 갈색 통나무 + 나이테 끝)
	if _log_t >= 0.0 and variant == &"gold":
		# 황금 드래곤 불 숨결: 굴러가는 불덩이
		var fat := (log_at() - position) / scale.x
		draw_circle(fat, 13.0 / scale.x, Color(1.0, 0.45, 0.1, 0.8))
		draw_circle(fat, 7.0 / scale.x, Color(1.0, 0.85, 0.4))
	elif _log_t >= 0.0:
		var at := (log_at() - position) / scale.x
		var dir := (_log_to - _log_from).normalized()
		var side := dir.orthogonal() * 11.0 / scale.x
		var roll := _log_t * 10.0
		draw_line(at - side, at + side, Color(0.45, 0.32, 0.22), 8.0 / scale.x)
		draw_line(at - side + dir * sin(roll) / scale.x, at + side + dir * sin(roll) / scale.x, Color(0.6, 0.44, 0.3), 3.0 / scale.x)
		for e in [at - side, at + side]:
			draw_circle(e, 4.0 / scale.x, Color(0.86, 0.74, 0.55))
			draw_circle(e, 1.5 / scale.x, Color(0.6, 0.44, 0.3))
	# 대장 이름표 (디아블로2 챔피언처럼 금색). 대장은 1.8배로 키워져 있어서 글씨는 키움을 되돌려 갈무리9 제 크기(10)로 쓴다.
	# (예전엔 크기 6 을 1.8배로 늘려 픽셀 글꼴이 깨져 보였다, 2026-09-30 사용자: "허수아비 장군 글씨 깨진거")
	if boss:
		var font := ThemeDB.fallback_font
		var k := 1.0 / scale.x
		var y := (-30.0 + top) * scale.x + 4.0
		var w := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(k, k))
		draw_rect(Rect2(roundf(-w / 2) - 2, roundf(y) - 10, w + 4, 13), Color(0, 0, 0, 0.55))
		draw_string(font, Vector2(roundf(-w / 2), roundf(y)), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.95, 0.85, 0.45))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
