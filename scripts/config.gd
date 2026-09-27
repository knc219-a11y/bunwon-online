class_name Config
extends RefCounted
## 프로토타입 수치 모음.
## 여기 있는 값은 전부 "임시값"이다. 기획에서 확정된 수치가 아니다.

## 아트 기준 (2026-09-27 결정): 기준 해상도 640x360, 타일 24px, 캐릭터 키 48px(타일 2칸)
const TILE := 24
## 640x360 화면에 들어가는 크기 (26 x 24 = 624px, 15 x 24 = 360px)
const MAP_SIZE := Vector2i(26, 15)
## 밭으로 쓸 수 있는 영역 (타일 좌표)
const FIELD_RECT := Rect2i(1, 2, 12, 8)
## 흙길 (타일 좌표). 밭 → 부화기·공급함 → 사냥터 입구(오른쪽 위, 정면)를 잇는 임시 배치
## 큰길에서 x=19로 내려와 농부 집 현관(22, 12)까지 잇는 길 포함
const PATH_RECTS: Array[Rect2i] = [Rect2i(13, 6, 10, 1), Rect2i(17, 5, 1, 4), Rect2i(22, 5, 1, 1), Rect2i(19, 7, 1, 6), Rect2i(20, 12, 3, 1)]
## 밭 울타리: 밭 한 칸 바깥 둘레 (타일 좌표). 흙길이 들어오는 칸은 비운다.
const FENCE_RECT := Rect2i(0, 1, 14, 10)
const FENCE_GAPS: Array[Vector2i] = [Vector2i(13, 6)]

const START_SEEDS := 20
## 물을 준 날이 이만큼 쌓이면 수확 가능
const CROP_GROW_DAYS := 3
## 수확하면 돌려받는 씨앗 수
const SEEDS_PER_HARVEST := 1

## 시작할 때 마을 공급함에 들어 있는 알 수 (첫 알 획득 이벤트는 미정이라 임시로 채워 둠)
const START_VILLAGE_EGGS := 1
const EGG_HATCH_DAYS := 1
## 첫 크리처는 운과 상관없이 쓸 만하도록 최저 능력치를 보장한다
const FIRST_CREATURE_MIN_WORK_SPEED := 1.0
const FIRST_CREATURE_MIN_RADIUS := 2
## 사냥꾼은 하루 한 번 사냥을 다녀온다 (전투 구현 전 대체 동작)
const HUNTS_PER_DAY := 1

## 초당 약 3.4타일
const CHARACTER_SPEED := 82.0
const INTERACT_DISTANCE := 30.0
## 마을 오브젝트는 차지하는 칸 가장자리에서 이 거리 안이면 상호작용
const PROP_INTERACT_DISTANCE := 16.0

## 크리처 작업 간격(초). 개체 속도로 나눈다.
const CREATURE_WORK_INTERVAL := 1.6
const CREATURE_HOP_TIME := 0.35
## 도착한 칸에서 일하는 동작 시간(초). 급수 4프레임 x 8fps
const CREATURE_WORK_ANIM_TIME := 0.5
