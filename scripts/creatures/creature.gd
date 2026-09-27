class_name Creature
extends Node2D
## 농장에 나와 있는 크리처 하나. 배치된 자리(home) 주변 밭에서 맡은 일을 반복한다.
## 종·속성·능력치는 CreatureData 에 있고, 이 노드는 움직임과 그리기만 맡는다.

var data: CreatureData
var job: StringName = CreatureJobs.REST
var home := Vector2i.ZERO
## 들고 옮기는 중이면 따라갈 캐릭터
var carried_by: Character = null

var _farm: Farm
var _timer := 0.0
var _busy := false
var _bob := 0.0


func setup(farm: Farm, creature_data: CreatureData, at_cell: Vector2i) -> void:
	_farm = farm
	data = creature_data
	home = at_cell
	position = Farm.center_of(at_cell)
	_reset_timer()


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
	var tw := create_tween()
	tw.tween_property(self, "position", Farm.center_of(target), hop_time())
	tw.tween_callback(func() -> void:
		_farm.do_work(work, target)
		_busy = false)
	return true


## 한 칸 이동에 걸리는 시간. 이동 속도(비행 등)가 빠를수록 짧다.
func hop_time() -> float:
	return Config.CREATURE_HOP_TIME / data.move_speed()


func _reset_timer() -> void:
	_timer = Config.CREATURE_WORK_INTERVAL / maxf(data.work_speed(job), 0.01)


func _process(delta: float) -> void:
	_bob += delta * (2.0 if job == CreatureJobs.REST else 6.0)
	if carried_by != null:
		position = carried_by.position + Vector2(0, -34)
	else:
		_timer -= delta
		if _timer <= 0.0:
			_reset_timer()
			work_once()
	queue_redraw()


func _draw() -> void:
	var squash := 1.0 + 0.08 * sin(_bob)
	draw_set_transform(Vector2(0, 4), 0.0, Vector2(squash, 2.0 - squash))
	draw_circle(Vector2.ZERO, 9.0, data.species.color)
	draw_set_transform(Vector2.ZERO)
	draw_circle(Vector2(-3, 2), 1.5, Color.BLACK)
	draw_circle(Vector2(3, 2), 1.5, Color.BLACK)
	if job == CreatureJobs.REST:
		return
	draw_string(ThemeDB.fallback_font, Vector2(-20, -10), CreatureJobs.display_name(job), HORIZONTAL_ALIGNMENT_CENTER, 40, 9)
	if carried_by == null:
		# 작업 범위 표시
		var radius := data.work_radius()
		var r := Rect2(Vector2((home - Vector2i(radius, radius)) * Config.TILE), Vector2.ONE * (radius * 2 + 1) * Config.TILE)
		draw_set_transform(-position)
		draw_rect(r, Color(0.75, 0.96, 0.93, 0.85), false, 1.0)
		draw_set_transform(Vector2.ZERO)
