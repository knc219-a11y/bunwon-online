class_name CreatureCatalog
extends RefCounted
## 게임에 등장하는 종 목록과 획득 경로.

const SLIME: CreatureSpecies = preload("res://data/creatures/species/slime.tres")
## 금사리 대장 금두꺼비를 쓰러뜨리면 나오는 알 (2026-09-28 사용자 선택)
const GOLD_TOAD: CreatureSpecies = preload("res://data/creatures/species/gold_toad.tres")
## 광동리(3구역) 참새 · 허수아비 장수를 쓰러뜨리면 가끔 나오는 알 (2026-09-29 사용자 선택 B. 동지벌 군량 벌판). 첫 비행 속성 종.
const SPARROW: CreatureSpecies = preload("res://data/creatures/species/sparrow.tres")
## 도마리(4구역) 2막 대장 장승 한 쌍을 쓰러뜨리면 가끔 나오는 알 (2026-09-29 사용자: "알은 나무정령알"). 농사 = 키우기.
const TREE_SPIRIT: CreatureSpecies = preload("res://data/creatures/species/tree_spirit.tres")
## 번천(5구역, 3막 첫 구역) 도깨비불 · 유령 막차를 쓰러뜨리면 가끔 나오는 알 (2026-09-29 사용자 선택 A). 첫 불 속성 종.
## 사냥 동행 = 불빛 + 불씨, 약방 도라지밭 가꾸기가 두 배 (fire.tres job_aptitude).
const WILL_O: CreatureSpecies = preload("res://data/creatures/species/will_o.tres")
## 밀목(6구역, 3막 둘째 구역) 3막 대장 산군 백호를 쓰러뜨리면 가끔 나오는 알 (2026-09-30 사용자 선택 B: "아기 호랑이가 귀여울거같으니").
## 땅 속성. 축사 모이 주기가 두 배 + 축사 지킴이 (족제비를 막음), 사냥 동행 = 포효 (둘레 몬스터 잠깐 멈춤).
const TIGER: CreatureSpecies = preload("res://data/creatures/species/tiger.tres")
## 같은 대장 알이 드물게 (Config.WHITE_TIGER_CHANCE) 아기 백호가 된다 (사용자: "낮은 확률로 백호가 나올수도있게하자
## 백호의 옵션은 얻기 힘든만큼 더 좋게 하고(스킬이 2개라던지) 속성도 좀 더 영험한 기운이 보이는걸로").
## 새 속성 신령 (모든 일 1.5배, 걸음 1.2배), 능력치 범위가 높음, 사냥 동행 = 포효 + 번개 발톱 (스킬 둘), 축사 지킴이.
const WHITE_TIGER: CreatureSpecies = preload("res://data/creatures/species/white_tiger.tres")

## 게임 시작 시 마을 공급함에 들어 있는 알
const STARTER_EGG := SLIME
## 사냥꾼이 사냥에서 가져오는 알 후보 (전투 구현 전 임시)
const HUNT_TABLE: Array[CreatureSpecies] = [SLIME]
## 첫 크리처가 태어날 때 맡는 일과 속성 (2026-09-27 결정: 급수, 물. 2026-09-29 급수가 농사에 합쳐짐)
const FIRST_JOB := CreatureJobs.FARM
const FIRST_ELEMENT: CreatureElement = preload("res://data/creatures/elements/water.tres")
