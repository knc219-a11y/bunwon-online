class_name CreatureCatalog
extends RefCounted
## 게임에 등장하는 종 목록과 획득 경로.

const SLIME: CreatureSpecies = preload("res://data/creatures/species/slime.tres")
## 금사리 대장 금두꺼비를 쓰러뜨리면 나오는 알 (2026-09-28 사용자 선택)
const GOLD_TOAD: CreatureSpecies = preload("res://data/creatures/species/gold_toad.tres")
## 광동리(3구역) 까마귀 · 허수아비 장수를 쓰러뜨리면 가끔 나오는 알 (2026-09-29 사용자 선택 B. 동지벌 군량 벌판). 첫 비행 속성 종.
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
## 역동(7구역, 4막 첫 구역) 켄타우로스 창기병 · 역마 장군을 쓰러뜨리면 가끔 나오는 알 (2026-10-02 사용자 선택 A).
## 땅 속성. 농사를 맡으면 밭 갈기 (깊이 간 칸은 거둘 때 무 하나 더), 사냥 동행 = 뒷발차기 (멀리 밀어내고 잠깐 멈춤).
const FOAL: CreatureSpecies = preload("res://data/creatures/species/foal.tres")
## 곤지암(8구역, 4막 대장 구역) 뿔 악귀 · 마왕을 쓰러뜨리면 가끔 나오는 알 (2026-10-02 사용자 선택 A).
## 불 속성. 밤일: 밤사이 맡은 일 (농사 · 고철 · 도라지 · 모이) 을 한 바퀴 더 해 둔다. 사냥 동행 = 불 할퀴기 + 겁주기.
const IMP: CreatureSpecies = preload("res://data/creatures/species/imp.tres")
## 소내섬(10구역, 5막 대장 구역) 독꼬리 와이번 · 일반 용을 쓰러뜨리면 가끔 나오는 알 (2026-10-03). 비행 속성.
## 채집이 빠르고 원정대에 끼면 하늘 배달 (어느 구역이든 고향 종만큼 잘 맞음), 사냥 동행 = 날아가 쪼기.
const WYVERN: CreatureSpecies = preload("res://data/creatures/species/wyvern.tres")
## 소내섬 희귀 용 (2026-10-03 사용자: "마지막은 기본이 일반용이고 희귀한 확률로 세가지 용이 우연하게나오는 구조로가자") 이
## 드물게 남기는 알. 셋 다 능력치 범위가 높다.
## 아기 청룡 (물): 비 내리기 = 아침마다 밭 전체에 물. 동행 = 물총.
const BLUE_DRAGON: CreatureSpecies = preload("res://data/creatures/species/blue_dragon.tres")
## 아기 운룡 (신령): 농사를 맡으면 밤사이 작물이 절반 확률로 하루 더 자람. 동행 = 포효 + 번개 발톱.
const CLOUD_DRAGON: CreatureSpecies = preload("res://data/creatures/species/cloud_dragon.tres")
## 아기 드래곤 (불): 금 모으기 = 아침마다 돈 40~90원. 동행 = 불빛 + 불씨.
const GOLD_DRAGON: CreatureSpecies = preload("res://data/creatures/species/gold_dragon.tres")

## 게임 시작 시 마을 공급함에 들어 있는 알
const STARTER_EGG := SLIME
## 사냥꾼이 사냥에서 가져오는 알 후보 (전투 구현 전 임시)
const HUNT_TABLE: Array[CreatureSpecies] = [SLIME]
## 첫 크리처가 태어날 때 맡는 일과 속성 (2026-09-27 결정: 급수, 물. 2026-09-29 급수가 농사에 합쳐짐)
const FIRST_JOB := CreatureJobs.FARM
const FIRST_ELEMENT: CreatureElement = preload("res://data/creatures/elements/water.tres")
