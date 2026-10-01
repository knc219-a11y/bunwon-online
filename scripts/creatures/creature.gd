class_name Creature
extends Node2D
## 농장에 나와 있는 크리처 하나. 배치된 자리(home) 주변 밭에서 맡은 일을 반복한다.
## 종·속성·능력치는 CreatureData 에 있고, 이 노드는 움직임과 그리기만 맡는다.
## 그래픽은 종의 속성별 스프라이트 시트 (규격은 docs/sprites.md).

## 시트 규격: 칸 32x32, 열 0-1 대기 · 2-5 깡충 · 6-9 급수, 행 0 정면 (방향 없음)
const FRAME_SIZE := 32
const SHEET_COLUMNS := 10
const IDLE_COLUMNS: Array[int] = [0, 1]
const HOP_COLUMNS: Array[int] = [2, 3, 4, 5]
const WATER_COLUMNS: Array[int] = [6, 7, 8, 9]
const IDLE_FPS := 2.0
const WORK_FPS := 8.0
## 몸 아래가 크리처 위치보다 이만큼 아래
const BOTTOM_Y := 8

enum Anim { IDLE, HOP, WORK }

var data: CreatureData
var job: StringName = CreatureJobs.REST
var home := Vector2i.ZERO
## 들고 옮기는 중이면 따라갈 캐릭터
var carried_by: Character = null
## 조작 중인 캐릭터 자리 (main 이 매 프레임 넣음). 농사가 아닌 크리처의 일 이름표는 이 근처에서만 보인다
## (채집 크리처가 몰리면 이름표가 겹쳐 쌓여서, 2026-10-01)
static var focus := Vector2.INF
## 원정 중인 구역 (Config.HUNT_ZONES 번호, Expedition). -1 = 마을에 있음
var expedition_zone := -1
## false 면 타이머로 스스로 일하지 않는다 (work_once 를 직접 불러야 함). 테스트에서 끈다.
var auto_work := true

var _farm: Farm
## 채집 일(CreatureJobs.FORAGE)에서 쓰는 마을 풀밭. main 이 부화 때 넣어 준다.
var forage: Forage
var _timer := 0.0
var _busy := false
## 농사 안에서 지금(또는 마지막으로) 한 일: 파종·급수·수확 id. 동작 그림과 다음 일 간격에 쓴다.
var task: StringName = &""
## 지금까지 풀밭에서 캔 나물·뿌리 수 (자동 플레이 봇이 농사 크리처의 한가한 채집을 셀 때 쓴다)
var picks := 0
## 지금까지 고물 더미에서 주운 고철 수 (봇이 센다)
var scraps := 0
var _bob := 0.0
var _anim := Anim.IDLE
var _anim_time := 0.0
var _sprite: Sprite2D


func setup(farm: Farm, creature_data: CreatureData, at_cell: Vector2i) -> void:
	_farm = farm
	data = creature_data
	home = at_cell
	position = Farm.center_of(at_cell)
	_reset_timer()
	var sheet: Texture2D = null
	if not data.elements.is_empty():
		sheet = data.species.sprite_sheets.get(data.elements[0].id)
	if sheet != null:
		_sprite = Sprite2D.new()
		_sprite.texture = sheet
		_sprite.centered = false
		_sprite.hframes = SHEET_COLUMNS
		_sprite.position = Vector2(-FRAME_SIZE / 2.0, BOTTOM_Y - FRAME_SIZE)
		add_child(_sprite)


func describe() -> String:
	var text := "%s [%s] %s · 속도 %s / 범위 %d / %s" % [
		data.species.display_name, CreatureJobs.display_name(job), data.element_names(),
		speed_text(), data.work_radius(), data.trait_name(),
	]
	if data.train_total() > 0:
		text += " / 훈련 범위 %d · 속도 %d단계" % [data.radius_level, data.speed_level]
	return text


## 일 속도 표시. 농사는 수확·파종·급수 속도를 따로 보여 준다 (속성·Trait 재능이 일마다 달라서).
func speed_text() -> String:
	if job == CreatureJobs.FARM:
		return "수확 %.2f·파종 %.2f·급수 %.2f" % [data.work_speed(CreatureJobs.HARVEST), data.work_speed(CreatureJobs.SOW), data.work_speed(CreatureJobs.WATER)]
	return "%.2f" % data.work_speed(job)


func next_job() -> void:
	var jobs := CreatureJobs.jobs()
	job = jobs[(jobs.find(job) + 1) % jobs.size()]
	_reset_timer()


func pick_up(by: Character) -> void:
	carried_by = by


func place(at_cell: Vector2i) -> void:
	carried_by = null
	home = at_cell
	position = Farm.center_of(at_cell)
	_reset_timer()


## 한 번 일한다. 할 일이 있으면 그 칸으로 이동해서 수행하고 true.
func work_once() -> bool:
	if carried_by != null or _busy:
		return false
	if job == CreatureJobs.FORAGE:
		return _forage_once()
	if job == CreatureJobs.FARM:
		return _farm_once()
	if job == CreatureJobs.SCRAP:
		return _scrap_once()
	if job == CreatureJobs.HERB:
		return _herb_once()
	if job == CreatureJobs.FEED:
		return _feed_once()
	return false


## 모이 주기 한 번 (2026-09-30 축사 닭장): 닭장 앞까지 건너가 오늘 아직 못 먹은 암탉 하나에게 모이를 준다 (GameState.fed).
## 다 먹였으면 제자리로 돌아가 쉰다. 모이는 아침마다 새로 센다.
func _feed_once() -> bool:
	if GameState.barn_state < 2:
		return false
	if GameState.fed >= GameState.hens:
		if position.distance_to(Farm.center_of(home)) > 1.0:
			_hop_to(Farm.center_of(home), func() -> void: pass)
			return true
		return false
	var at := Farm.center_of(feed_spot()) + Vector2((scraps % 3 - 1) * 5, 0)
	_hop_to(at, func() -> void:
		if GameState.fed < GameState.hens:
			GameState.fed += 1
			scraps += 1
			GameState.touch())
	return true


## 닭장 왼쪽 아래 칸 (크리처가 서서 모이를 주는 자리)
static func feed_spot() -> Vector2i:
	return Config.BARN_RECT.position + Vector2i(0, Config.BARN_RECT.size.y)


## 도라지밭 가꾸기 한 번 (2026-09-29 약방 복구): 도라지밭까지 건너가 도라지 하나를 캐 약방에 둔다 (GameState.roots).
## 밭이 비면 제자리로 돌아가 쉰다. 아침마다 다시 돋는다. 불속성은 두 배 빠르다 (fire.tres job_aptitude).
func _herb_once() -> bool:
	if GameState.yak_state < 2:
		return false
	if GameState.herb_bed <= 0:
		if position.distance_to(Farm.center_of(home)) > 1.0:
			_hop_to(Farm.center_of(home), func() -> void: pass)
			return true
		return false
	var at := Farm.center_of(herb_spot()) + Vector2((scraps % 3 - 1) * 5, 0)
	_hop_to(at, func() -> void:
		if GameState.herb_bed > 0:
			GameState.herb_bed -= 1
			GameState.roots += 1
			scraps += 1
			GameState.touch())
	return true


## 도라지밭 오른쪽 칸 (크리처가 서서 캐는 자리. 2026-10-01 마을 넓히기: 약방 배지 · 밭 이름표와 안 겹치게)
static func herb_spot() -> Vector2i:
	return Config.HERB_BED_RECT.position + Vector2i.RIGHT


## 고철 줍기 한 번 (2026-09-29 대장간 복구 A): 고물 더미까지 건너가 고철 하나를 주워 대장간에 둔다 (GameState.scrap).
## 더미가 비면 제자리로 돌아가 쉰다. 아침마다 더미가 다시 쌓인다.
func _scrap_once() -> bool:
	if GameState.forge_state < 2:
		return false
	if GameState.scrap_pile <= 0:
		if position.distance_to(Farm.center_of(home)) > 1.0:
			_hop_to(Farm.center_of(home), func() -> void: pass)
			return true
		return false
	var at := Farm.center_of(scrap_spot()) + Vector2((scraps % 3 - 1) * 5, 0)
	_hop_to(at, func() -> void:
		if GameState.scrap_pile > 0:
			GameState.scrap_pile -= 1
			GameState.scrap += 1
			scraps += 1
			GameState.touch())
	return true


## 고물 더미 오른쪽 한 칸 띄운 자리 (크리처가 서서 줍는 자리. 2026-10-01 마을 넓히기: 더미 배지와 일 이름표가 안 겹치게)
static func scrap_spot() -> Vector2i:
	return Config.SCRAP_RECT.position + Vector2i(Config.SCRAP_RECT.size.x + 1, 0)


## 농사 한 번 (2026-09-29 사용자 선택 A+B): 범위 안 밭에서 수확 → 파종 → 급수 순으로 할 일을 찾는다.
## 밭에 할 일이 없으면 한가한 동안 풀밭으로 채집하러 간다 (속성 효과 그대로). 풀밭에서도 할 게 없으면 제자리로.
func _farm_once() -> bool:
	var home_pos := Farm.center_of(home)
	for t in CreatureJobs.FARM_ORDER:
		var work: Farm.Work = CreatureJobs.FARM_WORK[t]
		# 채집하러 나가 있어도 밭 일은 제자리 기준으로 찾는다
		var target: Variant = _farm.find_work(work, home, data.work_radius(), [], home_pos)
		if target == null:
			continue
		task = t
		# 풀밭에서 돌아오는 길이면 먼 만큼 오래 걸린다. 제 범위 안에서는 한 번 깡충.
		var away := position.distance_to(home_pos) > (data.work_radius() + 1.5) * Config.TILE
		_hop_to(Farm.center_of(target), func() -> void: _farm.do_work(work, target), away)
		return true
	task = &""
	return _forage_once()


## 속성 id 가 있는지 (땅 = 도라지 뿌리, 물 = 풀밭 물주기)
func has_element(id: StringName) -> bool:
	return data.elements.any(func(e: CreatureElement) -> bool: return e.id == id)


## 채집 한 번 (2026-09-29 사용자 선택 B 속성별 채집): 밭 범위와 상관없이 마을 풀밭에서 가장 가까운 들나물로 가서 캐고
## 공급함에 바로 진열한다. 땅속성은 도라지 뿌리도 캐고, 물속성은 캔 자리에 물을 준다. 할 게 없으면 제자리로 돌아간다.
func _forage_once() -> bool:
	if forage == null:
		return false
	var dig := has_element(&"earth")
	var target: Variant = forage.nearest_target(position, dig)
	if target == null:
		if position.distance_to(Farm.center_of(home)) > 1.0:
			_hop_to(Farm.center_of(home), func() -> void: pass)
			return true
		return false
	forage.claimed[target] = true
	_hop_to(Farm.center_of(target), func() -> void:
		forage.claimed.erase(target)
		if forage.herbs.has(target) or forage.roots.has(target):
			picks += 1
		if forage.herbs.has(target):
			forage.pick(target)
			GameState.displayed_herbs += 1
			if has_element(&"water"):
				forage.water(target)
		elif forage.roots.has(target):
			forage.dig_root(target)
			# 약방 터가 드러난 뒤로는 도라지를 팔지 않고 약방에 모은다 (복구 · 연금술 재료)
			if GameState.yak_state >= 1:
				GameState.roots += 1
			else:
				GameState.displayed_roots += 1
		GameState.touch())
	return true


## 여러 칸을 깡충깡충 건너가 일 동작을 하고 done 을 부른다. by_distance 면 멀수록 오래 걸리고, 아니면 한 번 깡충.
func _hop_to(to: Vector2, done: Callable, by_distance := true) -> void:
	_busy = true
	_play(Anim.HOP)
	face(to.x - position.x)
	var tiles := maxf(position.distance_to(to) / Config.TILE, 1.0) if by_distance else 1.0
	var tw := create_tween()
	tw.tween_property(self, "position", to, hop_time() * tiles)
	tw.tween_callback(_play.bind(Anim.WORK))
	tw.tween_interval(Config.CREATURE_WORK_ANIM_TIME)
	tw.tween_callback(func() -> void:
		done.call()
		_busy = false
		_play(Anim.IDLE))


## 옆을 보는 그림 (species.faces) 이면 dx 쪽을 보게 좌우 반전한다. 정면 그림은 그대로.
func face(dx: float) -> void:
	face_sprite(_sprite, data.species.faces, dx)


static func face_sprite(sprite: Sprite2D, faces: int, dx: float) -> void:
	if sprite != null and faces != 0 and absf(dx) > 0.5:
		sprite.flip_h = (dx > 0.0) != (faces > 0)


## 시트에서 지금 보여 줄 열
func frame_column() -> int:
	match _anim:
		Anim.HOP:
			# 여러 칸을 건너가면(채집) 깡충 동작을 칸마다 되풀이한다
			var i := int(_anim_time / hop_time() * HOP_COLUMNS.size())
			return HOP_COLUMNS[i % HOP_COLUMNS.size()]
		Anim.WORK:
			# 급수 외의 일(파종·수확)은 아직 전용 동작이 없어 대기 동작을 빠르게 재생
			var watering := job == CreatureJobs.FARM and task == CreatureJobs.WATER
			var columns := WATER_COLUMNS if watering else IDLE_COLUMNS
			var i := int(_anim_time * WORK_FPS)
			if watering:
				return columns[mini(i, columns.size() - 1)]
			return columns[i % columns.size()]
	return IDLE_COLUMNS[int(_anim_time * IDLE_FPS) % IDLE_COLUMNS.size()]


## 앞뒤 가림 기준 y (몸 아래). 이 값이 작을수록 뒤에 그린다.
func sort_y() -> float:
	return position.y + BOTTOM_Y


func _play(anim: Anim) -> void:
	_anim = anim
	_anim_time = 0.0


## 한 칸 이동에 걸리는 시간. 이동 속도(비행 등)가 빠를수록 짧다.
func hop_time() -> float:
	return Config.CREATURE_HOP_TIME / data.move_speed()


## 다음 일까지 기다리는 시간. 농사는 방금 한 일(수확·파종·급수)의 속도를 따른다.
func _reset_timer() -> void:
	var speed_job := task if job == CreatureJobs.FARM and task != &"" else job
	_timer = Config.CREATURE_WORK_INTERVAL / maxf(data.work_speed(speed_job), 0.01)
	# 크리처 보약 (연금술사, 2026-09-29): 먹인 날은 모두 두 배 빠르다
	if GameState.tonic_day == GameState.day:
		_timer /= Config.TONIC_SPEED_MULT


func _process(delta: float) -> void:
	_bob += delta * (2.0 if job == CreatureJobs.REST else 6.0)
	_anim_time += delta
	if _sprite != null:
		_sprite.frame = frame_column()
	if carried_by != null:
		position = carried_by.position + Vector2(0, -48)
		# 들고 있으면 든 캐릭터 바로 앞에 그린다
		z_index = carried_by.z_index + 1
	else:
		z_index = int(sort_y())
		if auto_work:
			_timer -= delta
			if _timer <= 0.0:
				work_once()
				_reset_timer()
	queue_redraw()


func _draw() -> void:
	if carried_by == null:
		# 발밑 그림자 (시트에는 그림자를 넣지 않는다). 깡충 뛰어도 땅에 남는다.
		draw_set_transform(Vector2(0, BOTTOM_Y - 1), 0.0, Vector2(1.0, 0.35))
		draw_circle(Vector2.ZERO, 10.0, Color(0.27, 0.16, 0.33, 0.25))
		draw_set_transform(Vector2.ZERO)
	if _sprite == null:
		# 시트가 없는 종·속성은 도형으로 그린다
		var squash := 1.0 + 0.08 * sin(_bob)
		draw_set_transform(Vector2(0, 4), 0.0, Vector2(squash, 2.0 - squash))
		var body := data.elements[0].color if not data.elements.is_empty() else data.species.color
		draw_circle(Vector2.ZERO, 11.0, body)
		draw_set_transform(Vector2.ZERO)
		draw_circle(Vector2(-4, 2), 1.5, Color.BLACK)
		draw_circle(Vector2(4, 2), 1.5, Color.BLACK)
	if job == CreatureJobs.REST:
		return
	if job != CreatureJobs.FARM and carried_by == null and position.distance_to(focus) > Config.CREATURE_TAG_DISTANCE:
		return
	var label := CreatureJobs.display_name(job)
	if data.train_total() > 0:
		label += " ★%d" % data.train_total()
	UiSkin.draw_tag(self, Vector2(-30, -26), label, 60, Color(0.85, 1.0, 0.95))
	# 채집은 범위 없이 마을 풀밭 전체를 돌므로 범위 네모를 그리지 않는다
	if carried_by == null and job != CreatureJobs.FORAGE and job != CreatureJobs.SCRAP and job != CreatureJobs.HERB and job != CreatureJobs.FEED:
		# 작업 범위 표시
		var radius := data.work_radius()
		var r := Rect2(Vector2((home - Vector2i(radius, radius)) * Config.TILE), Vector2.ONE * (radius * 2 + 1) * Config.TILE)
		draw_set_transform(-position)
		# 네 귀퉁이 꺾쇠 (그래픽 시범 2026-09-30)
		var col := Color(0.75, 0.96, 0.93, 0.9)
		var k := 6.0
		for corner: Vector2 in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
			var sx := 1.0 if corner.x == r.position.x else -1.0
			var sy := 1.0 if corner.y == r.position.y else -1.0
			draw_polyline(PackedVector2Array([corner + Vector2(0, sy * k), corner, corner + Vector2(sx * k, 0)]), col, 2.0)
		draw_set_transform(Vector2.ZERO)
