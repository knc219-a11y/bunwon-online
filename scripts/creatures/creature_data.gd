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
	return s


func move_speed() -> float:
	var s := species.move_speed
	for e in elements:
		s *= e.move_speed_mult
	if creature_trait:
		s *= creature_trait.move_speed_mult
	return s


func work_radius() -> int:
	return base_radius + (creature_trait.radius_bonus if creature_trait else 0)


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
