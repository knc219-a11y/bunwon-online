class_name CreatureSpecies
extends Resource
## 몬스터 종 정의. 새 몬스터는 이 리소스(.tres)를 하나 더 만들면 된다.

@export var id: StringName
@export var display_name := ""
@export var elements: Array[CreatureElement] = []
## 종 고유의 일 재능. 일 id → 배율 (없으면 1.0)
@export var job_aptitude: Dictionary = {}

@export_group("부화 시 능력치 범위")
@export var work_speed_range := Vector2(0.8, 1.2)
@export var radius_range := Vector2i(1, 2)
@export var move_speed := 1.0
@export var traits: Array[CreatureTrait] = []

@export_group("임시 그래픽")
@export var color := Color.WHITE
