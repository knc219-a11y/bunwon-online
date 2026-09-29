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

## 들나물 캐기 (2026-09-29 사용자 선택 A, 핵심 루프 점검 5번 "2~3일째 농부 할 일이 없다"): 아침마다 밭 밖 풀밭에 돋는다.
## 농부가 F로 캐서 공급함에 진열하면 밤사이 팔린다 (무와 같은 방식). 값·수·자리는 전부 임시.
const HERB_NAMES: Array[String] = ["냉이", "쑥", "달래"]
const HERB_PRICE := 20
## 하루에 돋는 포기 수 [최소, 최대]
const HERBS_PER_DAY := Vector2i(5, 6)
## 돋을 수 있는 풀밭 칸 (울타리·흙길·집·나무·마을 오브젝트를 피한 자리, 화면 위아래 글 띠에 가리지 않게 1~12줄)
const HERB_SPOTS: Array[Vector2i] = [
	Vector2i(1, 11), Vector2i(5, 11), Vector2i(9, 11), Vector2i(12, 11), Vector2i(4, 12), Vector2i(9, 12),
	Vector2i(16, 12), Vector2i(16, 11), Vector2i(14, 2), Vector2i(19, 1), Vector2i(25, 1), Vector2i(14, 4),
	Vector2i(16, 7), Vector2i(25, 10), Vector2i(24, 12), Vector2i(18, 12),
]

## 크리처 채집 (2026-09-29 사용자 선택 B 속성별 채집): 채집을 맡긴 크리처는 밭 범위와 상관없이 마을 풀밭을 돌며
## 돋은 들나물을 캐서 공급함에 바로 진열한다. 땅속성은 손으로 못 캐는 땅속 도라지 뿌리도 캐고,
## 물속성은 나물 캔 자리에 물을 줘서 다음 날 들나물이 더 돋는다. 값·수·자리는 전부 임시.
const ROOT_NAME := "도라지"
const ROOT_PRICE := 60
## 하루에 땅속에 드는 뿌리 수 [최소, 최대]
const ROOTS_PER_DAY := Vector2i(2, 3)
## 뿌리가 들 수 있는 풀밭 칸 (들나물 자리와 겹치지 않게)
const ROOT_SPOTS: Array[Vector2i] = [
	Vector2i(16, 2), Vector2i(26, 4), Vector2i(25, 7), Vector2i(21, 1), Vector2i(3, 11), Vector2i(10, 12),
]
## 물속성이 물 준 풀밭 한 칸마다 다음 날 들나물 +1포기, 최대 이만큼
const HERB_WATER_BONUS_MAX := 3

## 도구 강화 (2026-09-27 후보 A 첫 조각): 마을 공급함에서 돈으로 한 번 사면 끝. 값은 전부 임시.
## 괭이·물뿌리개 1단계 = 바라보는 방향으로 앞 3칸 일자에 한 번에 쓴다.
const TOOL_UPGRADE_REACH := 3
const HOE_UPGRADE_PRICE := 200
const CAN_UPGRADE_PRICE := 250
## 사냥꾼 튼튼한 사냥칼: 이후 태어나는 크리처 능력치 바닥을 첫 크리처만큼 보장한다
const HUNTER_KNIFE_PRICE := 400

## 크리처 훈련 (2026-09-29 사용자 선택 A, 돈 쓸 곳 2단계): 공급함에서 크리처마다 범위·속도를 한 단계씩 올린다.
## 값은 단계마다 두 배, 크리처·능력마다 따로 낸다. 최대 단계 = 배열 길이. 값은 전부 임시.
const TRAIN_PRICES: Array[int] = [300, 600, 1200]
## 범위 훈련 한 단계 = 범위 +1, 속도 훈련 한 단계 = 일 속도 +25%
const TRAIN_RADIUS_STEP := 1
const TRAIN_SPEED_STEP := 0.25

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
## 1구역 분원농협 야생 슬라임 수. 넓은 맵(창고 마당)이 되며 3 → 7 (2026-09-28, 임시)
const WILD_SLIME_COUNT := 7
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

## 사냥 난이도 (2026-09-29 사용자: 후보 A·B·C "셋 다 필요한 기능같아"). 값은 전부 임시.
## A. 달려들기: 몬스터가 가까이 오면 웅크리고(! + 바닥 붉은 띠) 예고한 뒤 그 방향으로 돌진, 돌진 뒤 헐떡임 = 때릴 틈.
## 웅크리는 시간은 구역마다 windup (금사리가 더 짧음). 웅크리는 동안 맞아도 멈추지 않는다.
const LUNGE_TRIGGER := 56.0
const LUNGE_DISTANCE := 64.0
const LUNGE_TIME := 0.22
## 띠 너비 = 몸 닿는 거리 x2 (띠 밖이면 안 맞음)
const LUNGE_WIDTH := 28.0
const LUNGE_RECOVER := 0.8
## 헐떡임이 끝난 뒤 다시 달려들 수 있을 때까지 (초)
const LUNGE_COOLDOWN := 1.6
## C. 대장 패턴
## 대장 슬라임 내려찍기: 높이 뛰어 사냥꾼 발밑에 그림자 원 → SLAM_AIR_TIME 뒤 쿵 (원 안이면 하트 -피해), 새끼 SLAM_MINIONS 마리
const SLAM_RANGE := 150.0
const SLAM_AIR_TIME := 1.0
const SLAM_RADIUS := 32.0
const SLAM_COOLDOWN := 3.5
const SLAM_RECOVER := 0.9
const SLAM_MINIONS := 2
## 새끼가 이보다 많으면 더 안 나온다
const SLAM_MINION_MAX := 4
const MINION_SCALE := 0.65
## 금두꺼비 혀 채찍: 직선 예고 TONGUE_WINDUP 뒤 쭉 (선 위면 하트 -피해), 혀가 지나간 자리에 금가루
const TONGUE_RANGE := 120.0
const TONGUE_WINDUP := 0.7
const TONGUE_LASH_TIME := 0.25
const TONGUE_WIDTH := 14.0
const TONGUE_COOLDOWN := 2.6
const TONGUE_RECOVER := 0.7
## 금가루: 밟고 있으면 사냥꾼 걷기 빠르기 x GOLD_DUST_SLOW, GOLD_DUST_TIME 초 뒤 사라짐
const GOLD_DUST_RADIUS := 16.0
const GOLD_DUST_TIME := 6.0
const GOLD_DUST_SLOW := 0.5
## 광동리 참새 (flyer, 2026-09-29 선택 B): 땅에서 쪼다가 사냥꾼이 FLY_NOTICE 안에 오면 날아오름 →
## 사냥꾼 둘레를 FLY_CIRCLE 거리로 FLY_TIME 동안 맴돎 → 발밑에 그림자 원 (예고 = 구역 windup) → 내려꽂기 (원 안이면 하트 -피해)
## → 땅에서 SWOOP_RECOVER 초 낟알을 쪼음 (이때만 칼에 맞음) → 다시 날아오름. 나는 동안은 물·짚가리·벽을 넘는다.
const FLY_NOTICE := 120.0
const FLY_HEIGHT := 26.0
const FLY_SPEED := 70.0
const FLY_CIRCLE := 46.0
const FLY_TIME := Vector2(0.8, 1.6)
const SWOOP_RADIUS := 22.0
const SWOOP_TIME := 0.22
const SWOOP_RECOVER := 1.6
## 맞으면 이만큼만 더 쪼다가 날아오른다 (맞고 바로 도망)
const SWOOP_HIT_RECOVER := 0.6
## 허수아비 장수 짚단 던지기: 사냥꾼 둘레에 짚단 원 STRAW_BALES 개를 차례로 (하나 예고 STRAW_WINDUP, 간격 STRAW_GAP), 원 안이면 하트 -피해.
## 두 번에 한 번은 참새를 STRAW_CALL 마리 부른다 (최대 SLAM_MINION_MAX)
const STRAW_RANGE := 170.0
const STRAW_BALES := 3
const STRAW_WINDUP := 0.75
const STRAW_GAP := 0.35
const STRAW_RADIUS := 20.0
const STRAW_SPREAD := 34.0
const STRAW_COOLDOWN := 3.0
const STRAW_RECOVER := 1.0
const STRAW_CALL := 2

## 초당 약 3.4타일
const CHARACTER_SPEED := 82.0
const INTERACT_DISTANCE := 30.0
## 마을 오브젝트는 차지하는 칸 가장자리에서 이 거리 안이면 상호작용
const PROP_INTERACT_DISTANCE := 16.0

## 디아블로식 가방과 마을 공용 창고 칸 수 (2026-09-28, 임시). 장비 하나가 한 칸.
const BAG_COLUMNS := 4
const BAG_SIZE := 12
const STASH_COLUMNS := 5
const STASH_SIZE := 20

## 크리처 작업 간격(초). 개체 속도로 나눈다.
const CREATURE_WORK_INTERVAL := 1.6
const CREATURE_HOP_TIME := 0.35
## 도착한 칸에서 일하는 동작 시간(초). 급수 4프레임 x 8fps
const CREATURE_WORK_ANIM_TIME := 0.5

## 하루 시계 (2026-09-29 사용자: "체력이나 시간 제한 때문에 노동을 못하는 건 원하지 않는데, 시간을 아주 여유 있게 주고
## 정말 하루를 넘기고 싶으면 자러 가게"). 시계는 흐르지만 아무것도 막지 않는다. 하루는 잠을 자야만 넘어간다. 값은 전부 임시.
## 아침 6시에 일어난다 (하루 시작, 분)
const DAY_START_MINUTE := 6 * 60
## 실제 1초에 흐르는 게임 분. 2.0 = 게임 10분이 실제 5초, 6시~자정이 실제 9분.
## 봇 어림 (design/day-time/runs): 사람 속도로 보통 날 일이 오후에, 가장 바쁜 날도 저녁 9시 전에 끝난다. 1.0이면 오전 10시에 끝나 시계가 거의 안 쓰임.
const CLOCK_MINUTES_PER_SECOND := 2.0
## 저녁 노을이 지기 시작하는 시각과 다 어두워지는 시각 (분). 어두워도 일은 다 할 수 있다.
const DUSK_START_MINUTE := 18 * 60
const DUSK_FULL_MINUTE := 21 * 60
const DUSK_ALPHA := 0.35
## 시계는 새벽 2시에서 멈춘다 (쓰러지거나 벌칙 없음, 자러 가면 된다)
const CLOCK_MAX_MINUTE := 26 * 60

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
## 혀 당기기 (아기 금두꺼비, 2026-09-28): 이 거리 안의 몬스터를 동행 바로 앞까지 끌어와 잠깐 멈춘다
const COMPANION_PULL_RANGE := 100.0
const COMPANION_PULL_INTERVAL := 1.8
const COMPANION_PULL_GAP := 18.0
const COMPANION_PULL_STUN := 1.0
## 끌려오는 데 걸리는 시간 (초). 혀도 이만큼 보인다.
const COMPANION_PULL_TIME := 0.25
## 날아가 쪼기 (아기 참새, 2026-09-29 광동리 B): 이 거리 안이면 물·벽 너머 · 날고 있는 몬스터도 쪼음 (피해 1). 날던 참새는 땅에 떨어진다.
const COMPANION_PECK_RANGE := 120.0
const COMPANION_PECK_INTERVAL := 1.4
## 박치기 크리처가 야생 슬라임을 쫓아가기 시작하는 거리 (사냥꾼에게서 너무 멀어지지 않게)
const COMPANION_CHASE_DISTANCE := 90.0

## 사냥터 드롭 (2026-09-27 결정 A + 드롭표, 사용자: 디아블로2처럼 장비·포션·잡템을 한 드롭표에, 장비 보장은 뺌). 값은 전부 임시.
## 알 드롭 (2026-09-29 사용자: "알이 나왔을 때 기뻐야 하는데 너무 잘 나와서 흥미가 떨어진다" → 드롭률을 낮춤).
## 예전: 매일 그날 첫 처치 알 보장 + 금사리 대장 알 100% (하루 알 2개). 지금: 게임 전체에서 첫 알 하나만 보장,
## 그 뒤로는 구역의 egg_chance (몬스터 한 마리) · boss_egg_chance (대장) 확률. 값은 임시.
## 야생 슬라임을 쓰러뜨릴 때마다 이 확률로 무언가 떨어진다 (알과는 따로 굴린다)
const HUNT_LOOT_CHANCE := 0.2
## 떨어질 때 종류별 무게 (합 100)
const HUNT_LOOT_WEIGHTS := {&"money": 40, &"potion": 25, &"junk": 20, &"gear": 15}
const HUNT_MONEY_MIN := 10
const HUNT_MONEY_MAX := 30
## 빨간 물약: 1 키로 마시면 하트 회복
const POTION_HEAL := 1
## 잡템(슬라임 젤리)은 사냥꾼이 마을 공급함에서 F로 판다
const JUNK_PRICE := 15

## 장비 등급 (2026-09-28 사용자 선택 A: 디아블로2 그대로). 값은 전부 임시.
## 장비가 떨어지면 등급을 굴린다 (무게, 합 100): 일반 흰색 · 마법 파랑 · 레어 노랑
const GEAR_RARITY_WEIGHTS := {&"normal": 60, &"magic": 32, &"rare": 8}
## 등급별 옵션 수 [최소, 최대]
const GEAR_AFFIX_COUNT := {&"normal": [0, 0], &"magic": [1, 2], &"rare": [3, 4]}
## 세트 조각이 아직 남아 있을 때, 장비 드롭 중 세트 조각이 나올 몫
const SET_PIECE_SHARE := 0.5
## 공급함에서 장비를 팔 때 값 (바로 돈)
const GEAR_SELL_PRICES := {&"normal": 5, &"magic": 20, &"rare": 60, &"crafted": 40}

## 대장 슬라임 (2026-09-28 사용자 선택 B, 디아블로2 챔피언처럼). 값은 전부 임시.
## 야생 슬라임을 다 쓰러뜨리면 공터 가운데에 대장 1마리가 나온다 (사냥 한 번에 한 마리).
const BOSS_HP := 4
const BOSS_SCALE := 1.8
## 대장은 반드시 하나를 떨어뜨린다 (장비는 보장하지 않음): 이 확률로 장비, 아니면 돈 주머니
const BOSS_GEAR_CHANCE := 0.4
## 대장이 떨어뜨린 장비의 등급 무게 (합 100)
const BOSS_RARITY_WEIGHTS := {&"normal": 30, &"magic": 55, &"rare": 15}
const BOSS_MONEY_MIN := 30
const BOSS_MONEY_MAX := 60

## 스테이지 사냥터 (2026-09-28 사용자 선택 B + 웨이포인트, 디아블로2처럼 앞으로 걸어가기). 값·몬스터 이름은 임시.
## 구역 이름은 사용자가 정함: 1 분원농협, 2 금사리 (분원리 옆 동네. 마을 앞 하천에서 사금이 많이 나와 붙은 이름). 다음 구역 이름도 사용자가 정한다.
## 사용자: "B 방식으로 진행하고 특정 이상 구간부터 이어서 하고싶으면 특정 웨이포인트에서 시작하는게 더 탐험하는 맛이 나고 좋을거같아"
## 구역마다 몬스터가 세지고 장비 등급이 오른다. 대장을 쓰러뜨리면 위쪽 길이 열려 같은 날 다음 구역으로 이어서 간다.
## waypoint 가 있는 구역은 처음 도착하면 웨이포인트가 켜지고, 다음 날부터 사냥터 입구에서 거기서 시작할 수 있다.
## 드롭 확률 20% · 장비 보장 없음. 알은 egg_chance · boss_egg_chance (위 "알 드롭" 참고).
## sheet · boss_sheet 는 몬스터 시트 (32x32 칸, 0-1 대기 · 2-5 이동, 모래게는 6-7 모래에 숨음). monster_tint · boss_tint · ground_tint 는 물들이는 색.
## 금사리 (2026-09-28 사용자 선택): 하천 모래에서 사금이 나와 붙은 이름. 모래 속에 숨었다 튀어나오는 모래게 + 대장 금두꺼비.
## burrow 면 몬스터가 모래에 숨어 있다가 사냥꾼이 WILD_BURROW_POP_DISTANCE 안에 오면 튀어나온다 (숨어 있는 동안은 부딪혀도 안 다침).
## sign 이 있으면 아래 입구 오른쪽에 그 마을 표지 (금사리: 회색 항아리 구조물에 검정 글씨, 사용자 설명).
const HUNT_ZONES: Array[Dictionary] = [
	{
		name = "분원농협", monster = "야생 슬라임", boss_monster = "대장 슬라임", waypoint = false,
		## 넓은 맵 (2026-09-28 사용자 선택 C. 창고 마당): 아래는 농협 창고 마당, 철망 너머 위는 논밭, 대장은 곳간 앞
		map = "nonghyup",
		## 창고 벽 간판 (칸 자리, 글씨). 그림은 칸 지도에서 그린 임시 그림
		labels = [[Vector2(10.5, 21.3), "분원농협"], [Vector2(40, 20.3), "분원농협 2창고"], [Vector2(22, 18.3), "농기계"], [Vector2(19.5, 9.3), "곳간"]],
		sheet = "res://assets/creatures/slime_earth.png", boss_sheet = "res://assets/creatures/slime_earth.png", burrow = false,
		count = WILD_SLIME_COUNT, hp = WILD_SLIME_HP, speed = 1.0, boss_hp = BOSS_HP,
		## B. 구역 세기 (2026-09-29): 부딪히면 잃는 하트 · 맞았을 때 밀려나는 거리(px) · 달려들기 예고(초) · 무리(하나가 튀어나오면 근처도 같이)
		damage = 1, knockback = 14.0, windup = 0.6, pack = false, boss_pattern = &"slam",
		loot = HUNT_LOOT_WEIGHTS, rarity = GEAR_RARITY_WEIGHTS, boss_rarity = BOSS_RARITY_WEIGHTS,
		money = [HUNT_MONEY_MIN, HUNT_MONEY_MAX], boss_money = [BOSS_MONEY_MIN, BOSS_MONEY_MAX],
		## 대장 슬라임도 가끔 슬라임 알을 남긴다 (임시)
		boss_egg = "res://data/creatures/species/slime.tres",
		egg_chance = 0.03, boss_egg_chance = 0.15,
		monster_tint = Color(1, 0.8, 0.75), boss_tint = Color(1.0, 0.82, 0.4), ground_tint = Color(0.82, 0.9, 0.8), tree_tint = Color(0.78, 0.92, 0.78),
	},
	{
		name = "금사리", monster = "모래게", boss_monster = "금두꺼비", waypoint = true,
		## 화면보다 넓은 맵 (2026-09-28 사용자 선택 C): data/hunt_maps/geumsa.txt, 카메라가 사냥꾼을 따라간다
		map = "geumsa",
		sheet = "res://assets/creatures/wild_sand_crab.png", boss_sheet = "res://assets/creatures/wild_gold_toad.png", burrow = true,
		sign = "금사리(구터)",
		## 대장을 쓰러뜨리면 boss_egg_chance 확률로 떨어지는 알 (예전엔 반드시 → 2026-09-29 낮춤)
		boss_egg = "res://data/creatures/species/gold_toad.tres",
		egg_chance = 0.03, boss_egg_chance = 0.25,
		## 넓은 맵이라 모래톱마다 한 마리씩 (임시)
		count = 6, hp = 5, speed = 1.25, boss_hp = 9,
		## 금사리부터 확 세다 (2026-09-29 B): 체력 3→5, 하트 -2, 덜 밀림, 모래게가 무리로 튀어나옴. 대장 체력 6→9
		damage = 2, knockback = 6.0, windup = 0.4, pack = true, boss_pattern = &"tongue",
		## 입구 메뉴·들어올 때 보여 주는 권장 준비
		advice = "권장: 하트 7 · 사냥칼",
		## 대장 재료 (2026-09-29 대장간 복구 A): 대장을 쓰러뜨릴 때마다 하나 (1막 대장 재료 사금 덩이)
		boss_material = true,
		loot = {&"money": 38, &"potion": 25, &"junk": 19, &"gear": 18},
		rarity = {&"normal": 50, &"magic": 38, &"rare": 12}, boss_rarity = {&"normal": 20, &"magic": 55, &"rare": 25},
		money = [20, 45], boss_money = [45, 80],
		monster_tint = Color.WHITE, boss_tint = Color.WHITE, ground_tint = Color(0.9, 0.86, 0.72), tree_tint = Color(0.72, 0.86, 0.7),
	},
	{
		## 2막 첫 구역 (2026-09-29 사용자: "3구역은 광동리다", 후보 B. 동지벌 군량 벌판 선택).
		## 광동리 = 광복동(광백이) + 동지벌촌 (광주시 유래: 병자호란 때 군량미를 가장 많이 낸 넓은 벌판 마을).
		## 추수한 벌판 · 짚가리 · 옛 군량 곳간 · 배수로. 곡식 도둑 참새 떼가 날아다니고, 곳간을 지키던 허수아비 장수가 대장.
		name = "광동리", monster = "참새", boss_monster = "허수아비 장수", waypoint = true,
		map = "gwangdong",
		labels = [[Vector2(26, 4.3), "군량 곳간"]],
		sheet = "res://assets/creatures/wild_sparrow.png", boss_sheet = "res://assets/creatures/wild_scarecrow.png", burrow = false,
		## 참새는 날아다닌다 (flyer): 나는 동안 칼·몸이 닿지 않고, 내려꽂기(그림자 원 예고) 뒤 땅에서 낟알을 쪼는 동안만 칼에 맞는다
		flyer = true,
		## 알 (구역마다 일반 알 종): 참새 → 아기 참새. 대장도 가끔 같은 알.
		egg = "res://data/creatures/species/sparrow.tres", boss_egg = "res://data/creatures/species/sparrow.tres",
		## 참새는 금사리 모래게보다 두 배 넘게 많아서 한 마리 확률은 1% (사냥 한 번에 알 약 15%, 금사리와 비슷하게)
		egg_chance = 0.01, boss_egg_chance = 0.15,
		## 2막부터 한 계단 더 (대장간 제작품으로 금사리가 쉬워진 것을 보고, 2026-09-29): 내려꽂기 하트 -2, 대장 체력 26. windup = 내려꽂기 예고(초)
		count = 15, hp = 4, speed = 1.0, boss_hp = 26,
		damage = 2, knockback = 4.0, windup = 0.35, pack = false, boss_pattern = &"straw",
		advice = "권장: 하트 9 · 제작 장비",
		loot = {&"money": 38, &"potion": 25, &"junk": 19, &"gear": 18},
		rarity = {&"normal": 40, &"magic": 42, &"rare": 18}, boss_rarity = {&"normal": 15, &"magic": 55, &"rare": 30},
		money = [30, 60], boss_money = [70, 120],
		monster_tint = Color.WHITE, boss_tint = Color.WHITE, ground_tint = Color(0.92, 0.88, 0.74), tree_tint = Color(0.74, 0.86, 0.68),
	},
]
## 넓은 맵의 여울(얕은 물)에서 걷기 빠르기 배율 (임시)
const HUNT_FORD_SPEED := 0.6
## 넓은 맵의 물 댄 논에서 사냥꾼 걷기 빠르기 배율 (임시). 슬라임은 느려지지 않는다.
const HUNT_PADDY_SPEED := 0.6
## 숨은 몬스터가 튀어나오는 거리 (px)
const WILD_BURROW_POP_DISTANCE := 60.0
## 무리(pack) 구역에서 하나가 튀어나오면 이 거리 안의 숨은 몬스터도 같이 튀어나온다 (px)
const WILD_PACK_DISTANCE := 110.0

## 대장간 복구 · 대장장이 (2026-09-29 사용자 선택 A: 한 번에 복구 + 사람 장비 제작). 본편 첫 조각. 값·자리·그림 전부 임시.
## 1막 대장(금사리 금두꺼비)을 처음 쓰러뜨린 다음 날 아침, 마을 아래쪽 풀밭에 무너진 대장간 터가 드러난다.
## 터에서 F → 복구에 드는 것 (돈 · 무 · 1막 대장 재료 사금 덩이)을 다 모았으면 한 번에 고친다.
## 고치면 대장장이(셋째 캐릭터, Tab)가 열리고, 옆에 고물 더미가 생겨 크리처에게 고철 줍기를 맡길 수 있다.
## 대장장이는 모루에서 고철 + 돈으로 현대풍 장비를 만든다. 만들 때마다 디아블로2 제작처럼 옵션을 무작위로 굴린다.
## 자리: 왼쪽 감나무 두 그루 사이 풀밭 (3칸 x 2칸). 고물 더미는 오른쪽 (2칸 x 1칸).
const FORGE_RECT := Rect2i(3, 11, 3, 2)
const SCRAP_RECT := Rect2i(9, 12, 2, 1)
## 대장장이가 처음 서는 칸 (대장간 오른쪽 앞)
const SMITH_CELL := Vector2i(6, 12)
## 대장 재료를 주는 구역 (Config.HUNT_ZONES 번호) = 대장간 터를 여는 구역
const FORGE_ZONE := 1
const BOSS_MATERIAL_NAME := "사금 덩이"
## 복구에 드는 것. 복구 속도는 사금 덩이(대장을 잡을 때마다 1개)가 정한다 (봇: 터 → 복구 열흘 남짓).
## 돈으로 막으면 훈련을 못 사는 날이 생겨서 돈은 무 한 번 판 값쯤으로 둔다.
## 후보 목업에 있던 슬라임 젤리 10개는 뺐다: 젤리는 처치당 약 4%라 열흘에 두세 개밖에 안 모인다.
const FORGE_COST_MONEY := 2000
const FORGE_COST_CROPS := 40
const FORGE_COST_MATERIAL := 12
## 고물 더미: 아침마다 이만큼 쌓인다 (안 가져간 것은 그대로 두지 않고 새로 채움). 농부가 F로 하나씩 주워도 된다.
const SCRAP_PER_DAY := 6
## 제작 (대장장이 모루 F). 기본 장비마다 고철 · 돈. 옵션 수는 무게로 굴린다 {개수: 무게}.
const CRAFT_COSTS := {
	&"work_cap": [3, 200], &"rain_suit": [5, 300], &"work_boots": [4, 250],
	&"hard_hat": [4, 250], &"hiking_vest": [5, 300], &"safety_shoes": [4, 250],
}
const CRAFT_AFFIX_WEIGHTS := {1: 50, 2: 35, 3: 15}
