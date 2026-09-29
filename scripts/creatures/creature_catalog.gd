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

## 게임 시작 시 마을 공급함에 들어 있는 알
const STARTER_EGG := SLIME
## 사냥꾼이 사냥에서 가져오는 알 후보 (전투 구현 전 임시)
const HUNT_TABLE: Array[CreatureSpecies] = [SLIME]
## 첫 크리처가 태어날 때 맡는 일과 속성 (2026-09-27 결정: 급수, 물. 2026-09-29 급수가 농사에 합쳐짐)
const FIRST_JOB := CreatureJobs.FARM
const FIRST_ELEMENT: CreatureElement = preload("res://data/creatures/elements/water.tres")
