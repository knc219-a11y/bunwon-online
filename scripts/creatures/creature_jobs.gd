class_name CreatureJobs
extends RefCounted
## 크리처가 맡을 수 있는 일의 id 목록.
## 새 직업의 일(전투, 대장장이, 연금술 등)은 여기에 id를 추가하고,
## 종·속성·Trait 데이터의 job_aptitude 에 같은 id로 재능 배율을 적는다.

const REST := &"rest"
## 농사 (2026-09-29 사용자 선택 A+B): 범위 안 밭의 수확 → 파종 → 급수를 한 마리가 다 맡고,
## 밭에 할 일이 없으면 풀밭으로 채집하러 간다 (Creature._farm_once). 아래 셋은 재능 배율을 적는 id로 남는다.
const FARM := &"farm"
## 파종·급수·수확: 농사 안의 작은 일. 속성·Trait 의 job_aptitude 가 이 id로 재능 배율을 적는다.
const SOW := &"sow"
const WATER := &"water"
const HARVEST := &"harvest"
## 들나물 채집 (2026-09-29 사용자 선택 B): 밭이 아니라 마을 풀밭 전체에서 일한다 (Creature._forage_once)
const FORAGE := &"forage"

const NAMES := {
	REST: "쉬는 중",
	FARM: "농사",
	SOW: "파종",
	WATER: "급수",
	HARVEST: "수확",
	FORAGE: "채집",
}

## 농장에서 R 키로 돌아가며 고르는 일
const FARM_JOBS: Array[StringName] = [REST, FARM, FORAGE]

## 농사가 밭 일을 찾는 순서 (익은 무 먼저 거두고, 빈 칸에 심고, 마른 칸에 물)
const FARM_ORDER: Array[StringName] = [HARVEST, SOW, WATER]

## 농사 안의 일 id → 밭 작업
const FARM_WORK := {
	SOW: Farm.Work.SOW,
	WATER: Farm.Work.WATER,
	HARVEST: Farm.Work.HARVEST,
}


static func display_name(job: StringName) -> String:
	return NAMES.get(job, String(job))
