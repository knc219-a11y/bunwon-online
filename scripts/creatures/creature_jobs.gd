class_name CreatureJobs
extends RefCounted
## 크리처가 맡을 수 있는 일의 id 목록.
## 새 직업의 일(전투, 대장장이, 연금술 등)은 여기에 id를 추가하고,
## 종·속성·Trait 데이터의 job_aptitude 에 같은 id로 재능 배율을 적는다.

const REST := &"rest"
const SOW := &"sow"
const WATER := &"water"
const HARVEST := &"harvest"
## 들나물 채집 (2026-09-29 사용자 선택 B): 밭이 아니라 마을 풀밭 전체에서 일한다 (Creature._forage_once)
const FORAGE := &"forage"

const NAMES := {
	REST: "쉬는 중",
	SOW: "파종",
	WATER: "급수",
	HARVEST: "수확",
	FORAGE: "채집",
}

## 농장에서 R 키로 돌아가며 고르는 일
const FARM_JOBS: Array[StringName] = [REST, SOW, WATER, HARVEST, FORAGE]

## 농장 일 id → 밭 작업
const FARM_WORK := {
	SOW: Farm.Work.SOW,
	WATER: Farm.Work.WATER,
	HARVEST: Farm.Work.HARVEST,
}


static func display_name(job: StringName) -> String:
	return NAMES.get(job, String(job))
