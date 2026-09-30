class_name CreatureSpecies
extends Resource
## 몬스터 종 정의. 새 몬스터는 이 리소스(.tres)를 하나 더 만들면 된다.

@export var id: StringName
@export var display_name := ""
## 이 종이 가질 수 있는 속성 후보. 개체의 속성은 부화할 때 이 안에서 정해진다.
## (예: 슬라임은 물·땅만 가능하고 비행은 불가)
@export var possible_elements: Array[CreatureElement] = []
## 한 개체가 가지는 속성 수
@export var element_count := 1
## 종 고유의 일 재능. 일 id → 배율 (없으면 1.0)
@export var job_aptitude: Dictionary = {}

@export_group("부화 시 능력치 범위")
@export var work_speed_range := Vector2(0.8, 1.2)
@export var radius_range := Vector2i(1, 2)
@export var move_speed := 1.0
@export var traits: Array[CreatureTrait] = []

@export_group("사냥 동행")
## 동행 공격 방식. 비우면 첫 속성으로 정한다 (물 = 멀리서 물총, 그 밖 = 붙어서 박치기).
## &"pull" = 혀 당기기 (멀리 있는 몬스터를 끌어와 잠깐 멈춤, 금두꺼비)
## &"peck" = 날아가 쪼기 (물·벽 너머, 날고 있는 몬스터도. 날던 참새는 떨어짐, 아기 참새)
## &"bind" = 덩굴 묶기 (아기 나무 정령), &"ember" = 불빛 + 불씨 (둘레를 밝히고, 불씨 맞은 몬스터는 잠시 뒤 한 번 더 맞음, 아기 도깨비불)
@export var companion_style: StringName = &""

@export_group("특기")
## 사금 줍기 (금두꺼비): 밭에서 일하는 개체가 밤마다 주워 오는 돈 범위. (0, 0)이면 없음.
@export var daily_gold := Vector2i.ZERO
## 낟알 줍기 (아기 참새, 2026-09-29 광동리 B): 채집을 맡은 개체가 아침마다 벌판에서 물어 오는 씨앗 범위. (0, 0)이면 없음.
@export var daily_seeds := Vector2i.ZERO
## 키우기 (아기 나무 정령, 2026-09-29 도마리): 농사를 맡은 개체의 범위 안 밭에서 밤사이 자란 작물이 이 확률로 하루 더 자란다.
@export var grow_chance := 0.0
## 축사 지킴이 (아기 호랑이, 2026-09-30 밀목): 모이 주기를 맡은 개체가 있으면 밤에 족제비가 닭장에 안 온다
@export var guards_coop := false

@export_group("그래픽")
## 속성 id → 스프라이트 시트 (규격은 docs/sprites.md). 시트가 없으면 color 로 도형을 그린다.
@export var sprite_sheets: Dictionary = {}
## 알 껍데기와 점 색 (사냥터 땅에 떨어진 알)
@export var egg_color := Color(0.97, 0.93, 0.8)
@export var egg_spot_color := Color(0.55, 0.8, 0.95)
## 임시 도형 색 (시트가 없을 때)
@export var color := Color.WHITE
