class_name CreatureData
extends Resource
## 부화로 태어난 개체 하나의 데이터. 능력치와 Trait은 부화할 때 정해진다.
## 노드(Creature)와 분리해 두어 저장, 입양, 다른 직업에서의 활용에 그대로 쓸 수 있다.

@export var species: CreatureSpecies
@export var creature_trait: CreatureTrait
## 부화 때 종의 속성 후보 중에서 정해진 속성
@export var elements: Array[CreatureElement] = []
## 부화 때 굴린 기본 능력치 (속성·Trait 배율 적용 전)
@export var base_work_speed := 1.0
@export var base_radius := 1
## 크리처 훈련 단계 (2026-09-29 사용자 선택 A). 공급함에서 돈으로 올린다.
@export var radius_level := 0
@export var speed_level := 0
## 크리처 레벨 (2026-10-03 백로그 9, 고르는 동안 Claude 추천 A 포인트 + 돈): 일할수록 경험치 → 레벨, 레벨업마다 훈련 포인트 1.
## 훈련 한 단계에 포인트 1 + 돈. xp 는 지금 레벨 안에서 모은 경험치.
@export var level := 1
@export var xp := 0
@export var train_points := 0


static func hatch(from_species: CreatureSpecies, rng: RandomNumberGenerator) -> CreatureData:
	var d := CreatureData.new()
	d.species = from_species
	var r := from_species.work_speed_range
	d.base_work_speed = snappedf(rng.randf_range(r.x, r.y), 0.01)
	d.base_radius = rng.randi_range(from_species.radius_range.x, from_species.radius_range.y)
	if not from_species.traits.is_empty():
		d.creature_trait = from_species.traits[rng.randi_range(0, from_species.traits.size() - 1)]
	var pool := from_species.possible_elements.duplicate()
	for i in mini(from_species.element_count, pool.size()):
		d.elements.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
	return d


## 속성을 지정한다 (첫 슬라임 등). 종이 가질 수 없는 속성이면 false.
func set_element(element: CreatureElement) -> bool:
	if element not in species.possible_elements:
		return false
	elements = [element]
	return true


## 해당 일의 재능 배율 = 종 × 모든 속성 × Trait
func aptitude(job: StringName) -> float:
	var a: float = species.job_aptitude.get(job, 1.0)
	for e in elements:
		a *= e.job_aptitude.get(job, 1.0)
	if creature_trait:
		a *= creature_trait.job_aptitude.get(job, 1.0)
	return a


func work_speed(job: StringName) -> float:
	var s := base_work_speed * aptitude(job)
	if creature_trait:
		s *= creature_trait.work_speed_mult
	# 새참 (농사 기술): 모든 크리처 일 속도
	return s * train_speed_mult() * FarmSkills.snack_mult()


## 속도 훈련 배율
func train_speed_mult() -> float:
	return 1.0 + Config.TRAIN_SPEED_STEP * speed_level


## 다음 레벨까지 필요한 경험치
static func xp_to_next(lv: int) -> int:
	return roundi(Config.CREATURE_XP_BASE * pow(lv, Config.CREATURE_XP_EXP))


## 경험치를 더한다 (다정한 손 배율 포함). 오른 레벨 수. 레벨업마다 훈련 포인트 1.
func gain_xp(amount: float) -> int:
	if amount <= 0.0 or level >= Config.CREATURE_LEVEL_CAP:
		return 0
	xp += maxi(1, roundi(amount * FarmSkills.creature_xp_mult()))
	var ups := 0
	while level < Config.CREATURE_LEVEL_CAP and xp >= xp_to_next(level):
		xp -= xp_to_next(level)
		level += 1
		train_points += 1
		ups += 1
	if level >= Config.CREATURE_LEVEL_CAP:
		xp = 0
	return ups


## 처음부터 이 레벨로 (알 품기 · 옛 저장). 오른 만큼 훈련 포인트.
func start_at_level(lv: int) -> void:
	lv = clampi(lv, 1, Config.CREATURE_LEVEL_CAP)
	if lv > level:
		train_points += lv - level
		level = lv
		xp = 0


## 훈련 단계 합 (겉에 ★로 보인다)
func train_total() -> int:
	return radius_level + speed_level


func move_speed() -> float:
	var s := species.move_speed
	for e in elements:
		s *= e.move_speed_mult
	if creature_trait:
		s *= creature_trait.move_speed_mult
	return s


func work_radius() -> int:
	return base_radius + (creature_trait.radius_bonus if creature_trait else 0) + radius_level * Config.TRAIN_RADIUS_STEP


## 최저 능력치 보장 (첫 슬라임 등). 더 높게 나온 값은 그대로 둔다.
func guarantee_minimum(min_work_speed: float, min_radius: int) -> void:
	base_work_speed = maxf(base_work_speed, min_work_speed)
	base_radius = maxi(base_radius, min_radius)


func element_names() -> String:
	if elements.is_empty():
		return "무속성"
	return ", ".join(elements.map(func(e: CreatureElement) -> String: return e.display_name))


func trait_name() -> String:
	return creature_trait.display_name if creature_trait else "-"
