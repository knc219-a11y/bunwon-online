class_name CreatureTrait
extends Resource
## 개체 특성. 부화할 때 종의 후보 중 하나가 정해진다.

@export var id: StringName
@export var display_name := ""
@export var work_speed_mult := 1.0
@export var move_speed_mult := 1.0
@export var radius_bonus := 0
## 일 id → 재능 배율
@export var job_aptitude: Dictionary = {}
