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
## false 면 타이머로 스스로 일하지 않는다 (work_once 를 직접 불러야 함). 테스트에서 끈다.
var auto_work := true

var _farm: Farm
var _timer := 0.0
var _busy := false
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
	return "%s [%s] %s · 속도 %.2f / 범위 %d / %s" % [
		data.species.display_name, CreatureJobs.display_name(job), data.element_names(),
		data.work_speed(job), data.work_radius(), data.trait_name(),
	]


func next_job() -> void:
	var jobs := CreatureJobs.FARM_JOBS
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
	if not CreatureJobs.FARM_WORK.has(job) or carried_by != null or _busy:
		return false
	var work: Farm.Work = CreatureJobs.FARM_WORK[job]
	var target: Variant = _farm.find_work(work, home, data.work_radius())
	if target == null:
		return false
	_busy = true
	_play(Anim.HOP)
	var tw := create_tween()
	tw.tween_property(self, "position", Farm.center_of(target), hop_time())
	tw.tween_callback(_play.bind(Anim.WORK))
	tw.tween_interval(Config.CREATURE_WORK_ANIM_TIME)
	tw.tween_callback(func() -> void:
		_farm.do_work(work, target)
		_busy = false
		_play(Anim.IDLE))
	return true


## 시트에서 지금 보여 줄 열
func frame_column() -> int:
	match _anim:
		Anim.HOP:
			var i := int(_anim_time / hop_time() * HOP_COLUMNS.size())
			return HOP_COLUMNS[mini(i, HOP_COLUMNS.size() - 1)]
		Anim.WORK:
			# 급수 외의 일(파종·수확)은 아직 전용 동작이 없어 대기 동작을 빠르게 재생
			var columns := WATER_COLUMNS if job == CreatureJobs.WATER else IDLE_COLUMNS
			var i := int(_anim_time * WORK_FPS)
			if job == CreatureJobs.WATER:
				return columns[mini(i, columns.size() - 1)]
			return columns[i % columns.size()]
	return IDLE_COLUMNS[int(_anim_time * IDLE_FPS) % IDLE_COLUMNS.size()]


func _play(anim: Anim) -> void:
	_anim = anim
	_anim_time = 0.0


## 한 칸 이동에 걸리는 시간. 이동 속도(비행 등)가 빠를수록 짧다.
func hop_time() -> float:
	return Config.CREATURE_HOP_TIME / data.move_speed()


func _reset_timer() -> void:
	_timer = Config.CREATURE_WORK_INTERVAL / maxf(data.work_speed(job), 0.01)


func _process(delta: float) -> void:
	_bob += delta * (2.0 if job == CreatureJobs.REST else 6.0)
	_anim_time += delta
	if _sprite != null:
		_sprite.frame = frame_column()
	if carried_by != null:
		position = carried_by.position + Vector2(0, -48)
	elif auto_work:
		_timer -= delta
		if _timer <= 0.0:
			_reset_timer()
			work_once()
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
	draw_string(ThemeDB.fallback_font, Vector2(-20, -26), CreatureJobs.display_name(job), HORIZONTAL_ALIGNMENT_CENTER, 40, 9)
	if carried_by == null:
		# 작업 범위 표시
		var radius := data.work_radius()
		var r := Rect2(Vector2((home - Vector2i(radius, radius)) * Config.TILE), Vector2.ONE * (radius * 2 + 1) * Config.TILE)
		draw_set_transform(-position)
		draw_rect(r, Color(0.75, 0.96, 0.93, 0.85), false, 1.0)
		draw_set_transform(Vector2.ZERO)
