class_name Slime
extends Node2D
## 부화한 슬라임. 배치된 자리(home) 주변 밭에서 맡은 일을 반복한다.
## 역할, 능력치, Trait 구성은 모두 임시안이다 (첫 슬라임 역할은 미확정).

enum Role { REST, SOW, WATER, HARVEST }

const ROLE_NAMES := {
	Role.REST: "쉬는 중",
	Role.SOW: "파종",
	Role.WATER: "급수",
	Role.HARVEST: "수확",
}
const ROLE_WORK := {
	Role.SOW: Farm.Work.SOW,
	Role.WATER: Farm.Work.WATER,
	Role.HARVEST: Farm.Work.HARVEST,
}
## 임시 Trait: [이름, 속도 배율, 반경 보너스]
const TRAITS := [
	["평범함", 1.0, 0],
	["부지런함", 1.35, 0],
	["넓은 시야", 1.0, 1],
]

var role := Role.REST
## 부화할 때 정해지는 개체 값
var speed := 1.0
var radius := 2
var trait_name := ""
var home := Vector2i.ZERO
## 들고 옮기는 중이면 따라갈 캐릭터
var carried_by: Character = null

var _farm: Farm
var _timer := 0.0
var _busy := false
var _bob := 0.0


## 부화 시점에 능력치와 Trait을 생성한다.
func setup(farm: Farm, at_cell: Vector2i, rng: RandomNumberGenerator) -> void:
	_farm = farm
	home = at_cell
	position = Farm.center_of(at_cell)
	var t: Array = TRAITS[rng.randi_range(0, TRAITS.size() - 1)]
	trait_name = t[0]
	speed = snappedf(rng.randf_range(0.8, 1.2) * t[1], 0.01)
	radius = rng.randi_range(1, 2) + t[2]
	_timer = Config.SLIME_WORK_INTERVAL


## 능력치 최저치 보장 (첫 슬라임용). 더 높게 나온 값은 그대로 둔다.
func guarantee_minimum(min_speed: float, min_radius: int) -> void:
	speed = maxf(speed, min_speed)
	radius = maxi(radius, min_radius)
	_timer = Config.SLIME_WORK_INTERVAL / speed


func describe() -> String:
	return "슬라임 [%s] 속도 %.2f / 범위 %d / %s" % [ROLE_NAMES[role], speed, radius, trait_name]


func next_role() -> void:
	role = (role + 1) % Role.size() as Role
	queue_redraw()


func pick_up(by: Character) -> void:
	carried_by = by


func place(at_cell: Vector2i) -> void:
	carried_by = null
	home = at_cell
	position = Farm.center_of(at_cell)
	_timer = Config.SLIME_WORK_INTERVAL / speed


## 한 번 일한다. 할 일이 있으면 그 칸으로 튀어가서 수행하고 true.
func work_once() -> bool:
	if role == Role.REST or carried_by != null or _busy:
		return false
	var work: Farm.Work = ROLE_WORK[role]
	var target: Variant = _farm.find_work(work, home, radius)
	if target == null:
		return false
	_busy = true
	var tw := create_tween()
	tw.tween_property(self, "position", Farm.center_of(target), Config.SLIME_HOP_TIME)
	tw.tween_callback(func() -> void:
		_farm.do_work(work, target)
		_busy = false)
	return true


func _process(delta: float) -> void:
	_bob += delta * (6.0 if role != Role.REST else 2.0)
	if carried_by != null:
		position = carried_by.position + Vector2(0, -34)
	else:
		_timer -= delta
		if _timer <= 0.0:
			_timer = Config.SLIME_WORK_INTERVAL / speed
			work_once()
	queue_redraw()


func _draw() -> void:
	var squash := 1.0 + 0.08 * sin(_bob)
	var body := Color("6fd3c7")
	draw_set_transform(Vector2(0, 4), 0.0, Vector2(squash, 2.0 - squash))
	draw_circle(Vector2.ZERO, 9.0, body)
	draw_set_transform(Vector2.ZERO)
	draw_circle(Vector2(-3, 2), 1.5, Color.BLACK)
	draw_circle(Vector2(3, 2), 1.5, Color.BLACK)
	if role != Role.REST:
		draw_string(ThemeDB.fallback_font, Vector2(-20, -10), ROLE_NAMES[role], HORIZONTAL_ALIGNMENT_CENTER, 40, 9)
	if carried_by == null and role != Role.REST:
		# 작업 범위 표시
		var r := Rect2(Vector2((home - Vector2i(radius, radius)) * Config.TILE), Vector2.ONE * (radius * 2 + 1) * Config.TILE)
		draw_set_transform(-position)
		draw_rect(r, Color(0.75, 0.96, 0.93, 0.85), false, 1.0)
		draw_set_transform(Vector2.ZERO)
