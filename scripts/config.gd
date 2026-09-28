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
## 밭 넓히기 (2026-09-27 후보 A): 밭을 네 구역으로 나눠 처음엔 첫 구역만 쓰고, 나머지는 공급함에서 돈으로 연다.
## 여는 순서는 이 배열 순서. 값은 전부 임시.
const FIELD_PLOTS: Array[Rect2i] = [Rect2i(1, 2, 6, 4), Rect2i(7, 2, 6, 4), Rect2i(1, 6, 6, 4), Rect2i(7, 6, 6, 4)]
const FIELD_PLOT_NAMES: Array[String] = ["처음 밭", "오른쪽 구역", "왼쪽 아래 구역", "오른쪽 아래 구역"]
const FIELD_PLOT_PRICES: Array[int] = [0, 300, 500, 800]
const START_FIELD_PLOTS := 1
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

## 경제 첫 단계 (2026-09-27 결정 C): 공급함에 무를 진열하면 밤사이 팔리고 아침 카드에서 정산.
## 씨앗은 공급함에서 바로 산다. 값은 전부 임시.
const START_MONEY := 0
const CROP_PRICE := 50
const SEED_PACK_SIZE := 5
const SEED_PACK_PRICE := 100

## 도구 강화 (2026-09-27 후보 A 첫 조각): 마을 공급함에서 돈으로 한 번 사면 끝. 값은 전부 임시.
## 괭이·물뿌리개 1단계 = 바라보는 방향으로 앞 3칸 일자에 한 번에 쓴다.
const TOOL_UPGRADE_REACH := 3
const HOE_UPGRADE_PRICE := 200
const CAN_UPGRADE_PRICE := 250
## 사냥꾼 튼튼한 사냥칼: 이후 태어나는 크리처 능력치 바닥을 첫 크리처만큼 보장한다
const HUNTER_KNIFE_PRICE := 400

## 시작할 때 마을 공급함에 들어 있는 알 수 (첫 알 획득 이벤트는 미정이라 임시로 채워 둠)
const START_VILLAGE_EGGS := 1
const EGG_HATCH_DAYS := 1
## 첫 크리처는 운과 상관없이 쓸 만하도록 최저 능력치를 보장한다
const FIRST_CREATURE_MIN_WORK_SPEED := 1.0
const FIRST_CREATURE_MIN_RADIUS := 2
## 사냥꾼은 하루 한 번 사냥터에 들어간다
const HUNTS_PER_DAY := 1

## 사냥터 첫 조각 (2026-09-27 결정 A. 실시간 한 화면). 값은 전부 임시.
## 사냥꾼 하트 수, 야생 슬라임 수와 맞아야 쓰러지는 횟수
const HUNTER_HEARTS := 5
const WILD_SLIME_COUNT := 3
const WILD_SLIME_HP := 2
## 휘두르기: 발 앞 이 거리에 원을 그려 닿은 야생 슬라임을 때린다 (px)
const SWING_REACH := 18.0
const SWING_RADIUS := 18.0
const SWING_COOLDOWN := 0.35
## 부딪히면 하트 -1, 그 뒤 이 시간 동안은 다시 맞지 않는다 (초)
const HURT_INVULNERABLE_TIME := 1.0
const WILD_SLIME_TOUCH_DISTANCE := 14.0
## 야생 슬라임 움직임: 쉬었다가 한 번 깡충 (초, px). 사냥꾼이 가까우면 그쪽으로 뛴다.
const WILD_SLIME_REST_TIME := 1.2
const WILD_SLIME_HOP_TIME := 0.35
const WILD_SLIME_HOP_DISTANCE := 20.0
const WILD_SLIME_CHASE_DISTANCE := 90.0

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

## 잠자기 (2026-09-27 결정 A②): 현관 F → 밤으로 어두워짐 → 아침 카드 → F로 일어남
const SLEEP_FADE_TIME := 1.0
const WAKE_FADE_TIME := 0.4
const NIGHT_ALPHA := 0.85

## 크리처 동행 (2026-09-27 결정 A. 따라오는 동료, 첫 조각). 값은 전부 임시.
## 사냥꾼 뒤 이만큼 떨어져 따라온다 (px)
const COMPANION_FOLLOW_DISTANCE := 22.0
const COMPANION_SPEED := 90.0
## 물 = 멀리서 물총, 땅 = 붙어서 박치기. 간격(초)은 개체 일 속도로 나눈다.
const COMPANION_SHOT_RANGE := 110.0
const COMPANION_SHOT_INTERVAL := 1.6
const COMPANION_BUMP_RANGE := 16.0
const COMPANION_BUMP_INTERVAL := 1.0
## 박치기 크리처가 야생 슬라임을 쫓아가기 시작하는 거리 (사냥꾼에게서 너무 멀어지지 않게)
const COMPANION_CHASE_DISTANCE := 90.0

## 사냥터 드롭 (2026-09-27 결정 A + 드롭표, 사용자: 디아블로2처럼 장비·포션·잡템을 한 드롭표에, 장비 보장은 뺌). 값은 전부 임시.
## 야생 슬라임을 쓰러뜨릴 때마다 이 확률로 무언가 떨어진다 (그날 첫 알 보장과는 따로)
const HUNT_LOOT_CHANCE := 0.2
## 떨어질 때 종류별 무게 (합 100)
const HUNT_LOOT_WEIGHTS := {&"money": 40, &"potion": 25, &"junk": 20, &"gear": 15}
const HUNT_MONEY_MIN := 10
const HUNT_MONEY_MAX := 30
## 빨간 물약: 1 키로 마시면 하트 회복
const POTION_HEAL := 1
## 잡템(슬라임 젤리)은 사냥꾼이 마을 공급함에서 F로 판다
const JUNK_PRICE := 15
