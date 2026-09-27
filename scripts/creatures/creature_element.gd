class_name CreatureElement
extends Resource
## 몬스터 속성 (예: 물, 비행). 한 종이 여러 속성을 가질 수 있다.

@export var id: StringName
@export var display_name := ""
## 일 id → 재능 배율. 예: { &"water": 1.5 } 이면 급수를 1.5배 빠르게 한다.
@export var job_aptitude: Dictionary = {}
## 이동 속도 배율 (비행 등)
@export var move_speed_mult := 1.0
## 임시 그래픽에서 이 속성 개체의 몸 색
@export var color := Color.WHITE
