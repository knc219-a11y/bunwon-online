class_name CreatureCatalog
extends RefCounted
## 게임에 등장하는 종 목록과 획득 경로.

const SLIME: CreatureSpecies = preload("res://data/creatures/species/slime.tres")
## 금사리 대장 금두꺼비를 쓰러뜨리면 나오는 알 (2026-09-28 사용자 선택)
const GOLD_TOAD: CreatureSpecies = preload("res://data/creatures/species/gold_toad.tres")

## 게임 시작 시 마을 공급함에 들어 있는 알
const STARTER_EGG := SLIME
## 사냥꾼이 사냥에서 가져오는 알 후보 (전투 구현 전 임시)
const HUNT_TABLE: Array[CreatureSpecies] = [SLIME]
## 첫 크리처가 태어날 때 맡는 일과 속성 (2026-09-27 결정: 급수, 물)
const FIRST_JOB := CreatureJobs.WATER
const FIRST_ELEMENT: CreatureElement = preload("res://data/creatures/elements/water.tres")
