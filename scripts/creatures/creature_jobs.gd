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
## 고철 줍기 (2026-09-29 대장간 복구 A): 대장간을 고치면 생기는 고물 더미에서 고철을 주워 대장장이에게 (Creature._scrap_once).
## 땅속성이 빠르다 (earth.tres job_aptitude). 대장간을 고친 뒤에만 R 목록에 나온다.
const SCRAP := &"scrap"
## 도라지밭 가꾸기 (2026-09-29 약방 복구): 약방을 고치면 생기는 도라지밭에서 도라지를 캐 약방에 둔다 (Creature._herb_once).
## 불속성(아기 도깨비불)이 두 배 빠르다 (fire.tres job_aptitude). 약방을 고친 뒤에만 R 목록에 나온다.
const HERB := &"herb"
## 모이 주기 (2026-09-30 축사 닭장): 축사를 고치면 생기는 닭장에서 암탉에게 모이를 하나씩 준다 (Creature._feed_once).
## 무 없이 먹인다. 아기 호랑이가 두 배 빠르고, 모이를 주는 아기 호랑이가 있으면 밤에 족제비가 안 온다.
const FEED := &"feed"
## 밭 갈기 (2026-10-02 역동 아기 망아지): 농사를 맡은 아기 망아지가 수확한 빈 칸을 깊이 갈아 둔다 (거두면 무 하나 더).
## 따로 고르는 일이 아니라 농사 안의 작은 일. 종의 job_aptitude 에 이 id 가 있는 크리처만 한다.
const PLOW := &"plow"

const NAMES := {
	REST: "쉬는 중",
	FARM: "농사",
	SOW: "파종",
	WATER: "급수",
	HARVEST: "수확",
	FORAGE: "채집",
	SCRAP: "고철 줍기",
	HERB: "도라지밭",
	FEED: "모이 주기",
	PLOW: "밭 갈기",
	&"expedition": "원정",
}

## 농장에서 R 키로 돌아가며 고르는 일
const FARM_JOBS: Array[StringName] = [REST, FARM, FORAGE]

## 농사가 밭 일을 찾는 순서 (익은 무 먼저 거두고, 빈 칸에 심고, 마른 칸에 물)
const FARM_ORDER: Array[StringName] = [HARVEST, SOW, WATER]
## 밭 갈기를 하는 크리처 (아기 망아지): 거둔 뒤 심기 전에 깊이 간다
const PLOW_ORDER: Array[StringName] = [HARVEST, PLOW, SOW, WATER]

## 농사 안의 일 id → 밭 작업
const FARM_WORK := {
	SOW: Farm.Work.SOW,
	WATER: Farm.Work.WATER,
	HARVEST: Farm.Work.HARVEST,
	PLOW: Farm.Work.PLOW,
}


## 지금 R 로 고를 수 있는 일. 대장간을 고쳤으면 고철 줍기가 붙는다.
static func jobs() -> Array[StringName]:
	var out := FARM_JOBS.duplicate()
	if GameState.forge_state >= 2:
		out.append(SCRAP)
	if GameState.yak_state >= 2:
		out.append(HERB)
	if GameState.barn_state >= 2:
		out.append(FEED)
	return out


static func display_name(job: StringName) -> String:
	return NAMES.get(job, String(job))
