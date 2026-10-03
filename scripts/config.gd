class_name Config
extends RefCounted
## 프로토타입 수치 모음.
## 여기 있는 값은 전부 "임시값"이다. 기획에서 확정된 수치가 아니다.

## 아트 기준 (2026-09-27 결정): 기준 해상도 640x360, 타일 24px, 캐릭터 키 48px(타일 2칸)
const TILE := 24
## 640x360 화면 하나에 들어가는 칸 (26 x 24 = 624px, 15 x 24 = 360px). 한 화면 사냥터가 쓴다.
const SCREEN_CELLS := Vector2i(26, 15)
## 마을 맵 크기 (칸). 화면보다 크면 카메라가 주인공을 따라간다 (2026-10-01 마을 넓히기).
const MAP_SIZE := Vector2i(40, 24)
## --- 마을 배치 (2026-10-01 마을 넓히기) ---
## 마을 오브젝트가 차지하는 칸 (왼쪽 위 칸, 크기). 크기는 2026-09-27 결정.
const INCUBATOR_RECT := Rect2i(17, 3, 2, 2)
const SUPPLY_RECT := Rect2i(18, 10, 2, 1)
const HUNT_GATE_RECT := Rect2i(34, 3, 3, 2)
## 마을 공용 창고 궤짝 (2026-09-28 사용자 요청 "창고 기능", 공급함 왼쪽)
const STASH_RECT := Rect2i(17, 10, 1, 1)
## 배경 오브젝트 (2026-09-27 결정: 집 B 양옥, 나무 감나무 + 당산나무 하나)
const HOUSE_RECT := Rect2i(23, 9, 5, 4)
const DANGSAN_RECT := Rect2i(29, 15, 2, 2)
const PERSIMMON_CELLS: Array[Vector2i] = [Vector2i(1, 13), Vector2i(13, 13), Vector2i(15, 4), Vector2i(38, 9), Vector2i(31, 23), Vector2i(9, 21), Vector2i(26, 21), Vector2i(31, 4)]
## 알이 부화하면 크리처가 나타나는 칸 (부화기 왼쪽 아래)
const HATCH_CELL := Vector2i(16, 5)
## 집 현관 앞 흙길 칸. 여기서 F를 누르면 잔다 (2026-09-27 결정 A②).
const DOOR_CELL := Vector2i(25, 13)
## 새 게임에서 주인공이 서는 칸 (밭 울타리 입구 앞)
const PLAYER_START := Vector2i(15, 7)
## 마을 사람 NPC 농부 (밭 아래 풀밭) · 사냥꾼 (사냥터 입구 왼쪽 아래) 자리. 2026-10-03 주인공 하나.
const FARMER_CELL := Vector2i(10, 13)
const HUNTER_CELL := Vector2i(31, 8)
## 테스트용 시작 지점이 채집 크리처를 놓는 풀밭 칸 (공급함 옆)
const FORAGE_CELLS: Array[Vector2i] = [Vector2i(18, 12), Vector2i(17, 8), Vector2i(19, 8), Vector2i(21, 10), Vector2i(17, 12), Vector2i(19, 12), Vector2i(18, 13), Vector2i(16, 8)]
## 밭으로 쓸 수 있는 영역 (타일 좌표)
const FIELD_RECT := Rect2i(2, 3, 12, 8)
## 밭 넓히기 (2026-09-27 후보 A): 밭을 네 구역으로 나눠 처음엔 첫 구역만 쓰고, 나머지는 공급함에서 돈으로 연다.
## 여는 순서는 이 배열 순서. 값은 전부 임시.
const FIELD_PLOTS: Array[Rect2i] = [Rect2i(2, 3, 6, 4), Rect2i(8, 3, 6, 4), Rect2i(2, 7, 6, 4), Rect2i(8, 7, 6, 4)]
const FIELD_PLOT_NAMES: Array[String] = ["처음 밭", "오른쪽 구역", "왼쪽 아래 구역", "오른쪽 아래 구역"]
const FIELD_PLOT_PRICES: Array[int] = [0, 300, 500, 800]
const START_FIELD_PLOTS := 1
## 흙길 (타일 좌표). 2026-10-01 마을 넓히기 A: 위쪽 큰길 = 밭 울타리 입구 → 부화기 · 공급함 → 사냥터 입구 (오른쪽 위),
## 큰길에서 내려오는 길 → 아랫길 (대장간 · 약방 · 당산나무 · 시설 4 · 5 자리), 농부 집 현관은 아랫길에 붙음
const PATH_RECTS: Array[Rect2i] = [Rect2i(14, 7, 24, 1), Rect2i(35, 5, 1, 2), Rect2i(18, 5, 1, 5), Rect2i(22, 8, 1, 6), Rect2i(25, 13, 1, 1), Rect2i(3, 14, 31, 1)]
## 밭 울타리: 밭 한 칸 바깥 둘레 (타일 좌표). 흙길이 들어오는 칸은 비운다.
const FENCE_RECT := Rect2i(1, 2, 14, 10)
const FENCE_GAPS: Array[Vector2i] = [Vector2i(14, 7)]

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
## 아기 까마귀 낟알: 씨앗이 이만큼 있으면 더 물어 온 낟알은 씨앗 대신 공급함에서 개당 GRAIN_PRICE원에 팔린다 (임시)
const GRAIN_SEED_CAP := 30
const GRAIN_PRICE := 5

## 들나물 캐기 (2026-09-29 사용자 선택 A, 핵심 루프 점검 5번 "2~3일째 농부 할 일이 없다"): 아침마다 밭 밖 풀밭에 돋는다.
## 농부가 F로 캐서 공급함에 진열하면 밤사이 팔린다 (무와 같은 방식). 값·수·자리는 전부 임시.
const HERB_NAMES: Array[String] = ["냉이", "쑥", "달래"]
const HERB_PRICE := 20
## 하루에 돋는 포기 수 [최소, 최대]
const HERBS_PER_DAY := Vector2i(5, 6)
## 돋을 수 있는 풀밭 칸 (울타리·흙길·집·나무·마을 오브젝트를 피한 자리. F로 쓰는 오브젝트 둘레 2칸 밖이라 캐기가 오브젝트보다 먼저 잡히지 않음.
## 맵 맨 위 줄 · 아래 두 줄은 비움. 마을 넓히기 배치 도구 design/village-wide/mock/layouts.py 가 고른 자리)
const HERB_SPOTS: Array[Vector2i] = [
	Vector2i(39, 15), Vector2i(11, 21), Vector2i(35, 13), Vector2i(31, 11), Vector2i(27, 18), Vector2i(35, 8),
	Vector2i(24, 21), Vector2i(15, 13), Vector2i(39, 5), Vector2i(31, 6), Vector2i(4, 21), Vector2i(31, 1),
	Vector2i(0, 19), Vector2i(17, 21), Vector2i(8, 13), Vector2i(25, 15), Vector2i(37, 11), Vector2i(37, 16),
	Vector2i(21, 13), Vector2i(21, 3),
]

## 크리처 채집 (2026-09-29 사용자 선택 B 속성별 채집): 채집을 맡긴 크리처는 밭 범위와 상관없이 마을 풀밭을 돌며
## 돋은 들나물을 캐서 공급함에 바로 진열한다. 땅속성은 손으로 못 캐는 땅속 도라지 뿌리도 캐고,
## 물속성은 나물 캔 자리에 물을 줘서 다음 날 들나물이 더 돋는다. 값·수·자리는 전부 임시.
const ROOT_NAME := "도라지"
const ROOT_PRICE := 60
## 하루에 땅속에 드는 뿌리 수 [최소, 최대]
const ROOTS_PER_DAY := Vector2i(2, 3)
## 뿌리가 들 수 있는 풀밭 칸 (들나물 자리와 겹치지 않게)
const ROOT_SPOTS: Array[Vector2i] = [Vector2i(16, 16), Vector2i(29, 21), Vector2i(1, 16), Vector2i(4, 13), Vector2i(29, 9), Vector2i(30, 18)]
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
## 사냥꾼 체력 (2026-10-02 사용자: 하트 대신 "일반 체력방식"). 옛 하트 1 = 체력 HP_PER_HEART.
## 최대 체력 = HUNTER_HP + 레벨마다 HP_PER_LEVEL + 장비 · 세트 (하트 옵션 1 = HP_PER_HEART) + 도시락 · 매운탕
const HP_PER_HEART := 10
const HUNTER_HP := 50
const HP_PER_LEVEL := 2
## 1구역 분원농협 야생 슬라임 수. 넓은 맵(창고 마당)이 되며 3 → 7 (2026-09-28, 임시)
const WILD_SLIME_COUNT := 7
const WILD_SLIME_HP := 2
## 휘두르기: 발 앞 이 거리에 원을 그려 닿은 야생 슬라임을 때린다 (px)
const SWING_REACH := 18.0
const SWING_RADIUS := 18.0
const SWING_COOLDOWN := 0.35
## 무기 (2026-09-29 사용자: "종류는 근거리무기, 원거리 활 무기, 특수효과 지팡이무기 정도이면 좋을거같아").
## 무기 칸이 비어 있으면 사냥칼 (위 SWING_* 그대로). 무기마다 값은 Wearables.ITEMS 의 weapon 사전. 값은 전부 임시.
## 화살: 첫 몬스터에 맞으면 사라진다. 나는 까마귀(공중)도 맞힌다. 모래에 숨은 모래게 위로는 지나간다 (그루터기인 척하는 고목 그루터기는 맞힘).
const ARROW_SPEED := 300.0
const ARROW_HIT_RADIUS := 9.0
## 지팡이 구슬: 느리게 날아가 처음 닿은 몬스터(또는 사거리 끝)에서 터진다. 둘레 blast 안 몬스터 모두 1 피해 + 속성 효과.
const ORB_SPEED := 170.0
const ORB_HIT_RADIUS := 10.0
## 물 = 느려짐 (그동안 모든 움직임 · 예고가 이 배율로), 땅 = 잠깐 멈춤, 불 = 잠시 뒤 한 번 더 피해
const STAFF_SLOW_TIME := 2.5
const STAFF_SLOW_MULT := 0.5
const STAFF_STUN_TIME := 0.9
const STAFF_BURN_DELAY := 1.5
## 처음 주는 무기 (구역 대장을 처음 쓰러뜨리면 이 무기 일반 등급이 반드시 떨어짐, 한 번만): 분원농협 → 활, 금사리 → 지팡이
const FIRST_WEAPON_DROPS := {0: &"hunting_bow", 1: &"water_staff"}
## 장비 드롭 중 무기가 나올 몫 (나머지는 모자 · 옷 · 신발)
const WEAPON_DROP_SHARE := 0.35

## 사냥 손맛 (2026-10-02 사용자: "사냥액션이 너무 루즈해 요즘 로그라이크 액션게임처럼 좀 스피드하고 더 몰아잡는 느낌",
## "지금 게임 구조로는 하데스2같은 느낌이 좋은거같아"). 값은 전부 임시.
## 구르기 (Space): 바라보는 쪽 · 걷는 쪽으로 휙. 구르는 동안과 조금 뒤까지 안 맞는다.
const DASH_DISTANCE := 58.0
const DASH_TIME := 0.14
const DASH_COOLDOWN := 0.5
const DASH_IFRAMES := 0.24
## 근거리 연속 베기: 클릭을 꾹 누르고 있으면 계속 벤다. COMBO_WINDOW 안에 다시 베면 다음 타, 3타째는 넓고 세게 (피해 +1).
## 근거리 무기 쿨에 COMBO_SPEED 를 곱한다 (휘두르기가 빨라짐)
const COMBO_WINDOW := 0.5
const COMBO_SPEED := 0.7
const COMBO_FINISH_RADIUS := 1.45
## 3타째 앞으로 내딛는 거리 (px)
const COMBO_FINISH_STEP := 8.0
## 맞히면 세상이 아주 잠깐 멈춘다 (타격 멈춤, 초) · 쓰러뜨리면 화면이 살짝 흔들린다 (px)
const HITSTOP := 0.045
const HITSTOP_KILL := 0.07
const SHAKE := 2.5
## 맞은 몬스터가 밀려나는 거리 배율 (몰아 베려면 덜 밀려나야 한다)
const HIT_KNOCKBACK_MULT := 0.45
## 떼 (몰아잡기): 몬스터 자리 하나에 SWARM_SIZE 마리가 모여 있다 (구역 swarm 이 있으면 그 수).
## 떼 몬스터는 체력이 SWARM_HP_MULT 배 (반올림, 최소 1). 한 마리 드롭 · 알 확률은 1/떼 수 (사냥 한 번 합은 그대로).
const SWARM_SIZE := 4
const SWARM_HP_MULT := 0.5
const SWARM_SPREAD := 20.0
## 떼 하나가 사냥꾼을 알아채면 (WILD_SLIME_CHASE_DISTANCE 안) 떼 모두가 이 거리 안에서 쫓아오고, 쉬는 시간이 이 배율로 짧아진다
const SWARM_ALERT_CHASE := 240.0
const SWARM_ALERT_REST := 0.45
## 한꺼번에 달려들기 예고를 할 수 있는 몬스터 수 (떼가 한 번에 덮치지 않게, 하데스처럼 차례로)
const MAX_ATTACKERS := 2

## 활 몰아잡기 (2026-10-02 후보 비교, 떼가 생긴 뒤 활 사냥이 길어져서). 값은 전부 임시.
## 기본 방식 (HuntGround.bow_style 기본값): &"" 첫 몬스터에 박힘 · &"pierce" · &"spread" · &"volley".
## 2026-10-02 사용자: "이런 공격방식은 레벨제도를 도입해서 스킬을 찍는걸로 가는거어떨까 무조건 고정이 아니고"
## → 셋은 나중에 레벨 · 스킬로 고르게 하고, 그 전까지 기본은 지금 그대로.
const BOW_STYLE := &""
## pierce 관통: 화살이 BOW_PIERCE 마리까지 꿰뚫는다 (마리마다 같은 피해).
const BOW_PIERCE := 3
## spread 부채살: 화살 3발을 이 각도(도)로 벌려 쏜다. 쿨이 이 배율로 길어진다.
const BOW_SPREAD_DEG := 14.0
const BOW_SPREAD_COOLDOWN := 1.3
## volley 3연사: 한 번 쏘면 3발이 BOW_VOLLEY_GAP 초 간격으로 나간다. 쿨이 이 배율로 길어진다.
const BOW_VOLLEY_GAP := 0.08
const BOW_VOLLEY_COOLDOWN := 1.6

## 사냥꾼 레벨 · 스킬 (2026-10-02 사용자 선택: 디아2식 사냥꾼 레벨 + 스킬 포인트). 값은 전부 임시.
## 경험치: 처치마다 KILL_XP_BASE x KILL_XP_GROWTH^구역, 대장은 x BOSS_XP_MULT, 대장을 처음 잡으면 x FIRST_BOSS_XP_MULT 를 더.
## 다음 레벨까지 = XP_BASE x Lv^XP_EXP. 2026-10-02 3~4막 난이도 (사용자 A+C 추천 → 체력 숫자로 이어짐): 1.9 → 2.1 로 늦춰
## 구역에 도착할 때 레벨이 그 구역 몬스터 레벨쯤 (봇: 40일 밀목 Lv 14~15 · 60일 역동 Lv 18 · 곤지암 Lv 21 안팎).
const KILL_XP_BASE := 4.0
const KILL_XP_GROWTH := 1.32
const BOSS_XP_MULT := 10
const FIRST_BOSS_XP_MULT := 60
const XP_BASE := 12.0
const XP_EXP := 2.1
const LEVEL_CAP := 50
## 디아2식 레벨 차 벌칙: 사냥꾼 레벨이 구역 몬스터 레벨 + XP_GAP_FREE 를 넘으면 한 레벨마다 XP_GAP_STEP 씩 줄어든다 (최저 XP_GAP_MIN)
const XP_GAP_FREE := 5
const XP_GAP_STEP := 0.25
const XP_GAP_MIN := 0.05
## 구역 몬스터 레벨 (HUNT_ZONES 순서, 모자라면 마지막 + 3씩)
const ZONE_MONSTER_LEVEL: Array[int] = [1, 3, 6, 9, 12, 15, 18, 21, 24, 27]
## 몬스터 레벨 → 체력 · 피해 (2026-10-02 체력 숫자 + 몬스터 레벨 반영, 임시). 몬스터 Lv 이 MON_LV_BASE 를 넘는 만큼
## 체력 MON_HP_PER_LV · 피해 MON_DMG_PER_LV 씩 오른다 (1 · 2막은 그대로, 3막부터: 번천 x1.27 · 밀목 x1.54 · 역동 x1.81 · 곤지암 x2.08 체력).
## 처음엔 Lv 1 부터 올렸더니 봇 120일에서 도마리 근거리가 한 번에 체력 67 · 19번 중 11번 쓰러짐 → 2막까지는 손대지 않음.
const MON_LV_BASE := 9
const MON_HP_PER_LV := 0.09
const MON_DMG_PER_LV := 0.05
## 막 대장 (막의 두 번째 구역 대장: 금사리 · 도마리 · 밀목) 을 처음 잡으면 스킬 포인트 하나 더 (디아2 퀘스트 보상처럼)
const ACT_BOSS_SKILL_POINT := 1
## 직업 · 스탯 · 초기화 (2026-10-03 2단계, 사용자: "직업도 마법사 궁수 전사로 나누고 … 스텟이랑 스킬 초기화는 조금 자유롭게 가능하도록(골드소모)"). 값은 전부 임시.
## 피해 숫자 단위: 한 대 1 → DMG_UNIT. 몬스터 체력 · 크리처 피해도 같은 배수 (스탯 % 가 숫자로 보이게, 난이도는 그대로).
const DMG_UNIT := 10
## 자기 직업 무기를 들면 피해 + CLASS_WEAPON_BONUS
const CLASS_WEAPON_BONUS := 0.2
## 레벨업마다 스탯 포인트
const STAT_POINTS_PER_LEVEL := 3
## 스탯 1점: 힘 근거리 피해 + · 최대 체력 + / 솜씨 활 피해 + · 걷기 · 구르기 + / 지혜 지팡이 피해 + · 속성 효과 시간 + / 교감 동행 피해 · 공격 빠르기 +
const STAT_DMG := 0.02
const STR_HP := 2
const DEX_SPEED := 0.005
const WIS_ELEMENT := 0.02
const BOND_DMG := 0.04
const BOND_SPEED := 0.01
## 몬스터 체력은 "보통 빌드" (레벨마다 주 스탯 2점 = STAT_DMG x 2, 직업 무기) 가 그 몬스터 레벨에서 낼 피해만큼 함께 오른다.
## = (1 + CLASS_WEAPON_BONUS) x (1 + MON_HP_STAT_PER_LV x (몬스터 Lv - 1)). 스탯 · 직업으로 난이도가 확 쉬워지지 않게.
const MON_HP_STAT_PER_LV := 0.04
## 동행 크리처 피해도 같은 바탕 (x COMPANION_BASE). 교감을 레벨마다 1점 (보통 빌드) 찍으면 몬스터 체력과 함께 오른다.
## (처음엔 바탕 1 · 교감 3% 였더니 봇 근거리 도마리 · 밀목이 한 번에 체력 +35% 더 깎임: 동행이 덜 잡아서)
const COMPANION_BASE := 1.2
## 초기화 (스탯 · 스킬 모두 돌려받기) · 직업 바꾸기: 첫 번은 공짜, 그 뒤 Lv x RESPEC_PRICE_PER_LV 원. 사냥터 입구 메뉴에서.
const RESPEC_PRICE_PER_LV := 100
## 스킬 값 (B 무기 트리 셋 + 조련, 단계마다 per). 전부 임시.
## 활 부채살 · 3연사 쿨 배율이 단계마다 이만큼 (3연사는 두 배) 줄어든다
const SKILL_COOLDOWN_STEP := 0.04
## 회전 베기: 3타 앞쪽 범위에 더해 사냥꾼 둘레 (3타 반지름 x WHIRL_RADIUS) 를 한 바퀴 · 단계마다 +8%
const WHIRL_RADIUS := 1.0
const WHIRL_RADIUS_STEP := 0.08
const DASH_SLASH_STEP := 0.06
const SWORD_MASTERY_SPEED := 0.06
## 대지 가르기 (오른클릭): 길이 · 폭 (px), 기절 (초), 쿨 (초, 단계마다 -0.4)
const EARTH_SPLIT_LENGTH := 70.0
const EARTH_SPLIT_WIDTH := 10.0
const EARTH_SPLIT_STUN := 0.6
const EARTH_SPLIT_COOLDOWN := 4.0
## 화살비 (오른클릭): 반지름 · 세 번 쏟아지는 간격 · 쿨
const ARROW_RAIN_RADIUS := 30.0
const ARROW_RAIN_GAP := 0.3
const ARROW_RAIN_COOLDOWN := 5.0
## 지팡이: 큰 구슬 +10%/단계 · 연쇄 작은 구슬 사거리 · 터짐 배율 · 속성 강화 +20%/단계 · 원소 폭풍
const BIG_ORB_STEP := 0.1
const CHAIN_ORB_RANGE := 40.0
const CHAIN_ORB_BLAST := 0.55
const ELEMENT_BOOST_STEP := 0.2
const ELEMENT_STORM_RADIUS := 44.0
const ELEMENT_STORM_COOLDOWN := 6.0
## 조련: 함께 싸우기 +10%/단계 · 크리처 방패 쿨 (단계마다 -2.5) · 돌격 명령
const FIGHT_TOGETHER_SPEED := 0.1
const GUARD_COOLDOWN := 20.0
const GUARD_COOLDOWN_STEP := 2.5
const CHARGE_PICK_RADIUS := 80.0
const CHARGE_SPEED := 320.0
const CHARGE_STUN := 1.0
const CHARGE_COOLDOWN := 6.0
## 레벨업 띠가 떠 있는 시간 (초)
const LEVEL_UP_BANNER_TIME := 2.5

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
## 광동리 까마귀 (flyer, 2026-09-29 선택 B): 땅에서 쪼다가 사냥꾼이 FLY_NOTICE 안에 오면 날아오름 →
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
## 두 번에 한 번은 까마귀를 STRAW_CALL 마리 부른다 (최대 SLAM_MINION_MAX)
const STRAW_RANGE := 170.0
const STRAW_BALES := 3
const STRAW_WINDUP := 0.75
const STRAW_GAP := 0.35
const STRAW_RADIUS := 20.0
const STRAW_SPREAD := 34.0
const STRAW_COOLDOWN := 3.0
const STRAW_RECOVER := 1.0
const STRAW_CALL := 2
## 천하대장군 통나무 굴리기 (도마리 2막 대장): 사냥꾼 쪽 긴 띠 예고 LOG_WINDUP 뒤 통나무가 LOG_TIME 동안 LOG_LENGTH 만큼 굴러감.
## 굴러가는 통나무에 닿으면 (띠 너비 LOG_WIDTH) 하트 -피해.
const LOG_RANGE := 190.0
const LOG_WINDUP := 0.7
const LOG_LENGTH := 230.0
const LOG_TIME := 0.8
const LOG_WIDTH := 22.0
const LOG_COOLDOWN := 3.2
const LOG_RECOVER := 1.1

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
## 이 시각부터 마을 밤 배경음 (2026-10-01 사운드 첫 단계)
const NIGHT_MUSIC_MINUTE := 19 * 60
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
## 날아가 쪼기 (아기 까마귀, 2026-09-29 광동리 B): 이 거리 안이면 물·벽 너머 · 날고 있는 몬스터도 쪼음 (피해 1). 날던 까마귀는 땅에 떨어진다.
const COMPANION_PECK_RANGE := 120.0
const COMPANION_PECK_INTERVAL := 1.4
## 덩굴 묶기 (아기 나무 정령, 2026-09-29 도마리): 닿는 거리 · 공격 간격 · 묶어 두는 시간 (묶인 몬스터는 못 움직이고 부딪혀도 안 다침)
const COMPANION_BIND_RANGE := 90.0
const COMPANION_BIND_INTERVAL := 2.4
const COMPANION_BIND_STUN := 1.6
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
## 빨간 물약: 1 키로 마시면 체력 회복 (체력 숫자로 바꾸며 하트 1 → 30, 임시)
const POTION_HEAL := 30
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
## 장비 갈기 (2026-10-03 백로그 8 "아이템을 갈아서 고철 얻기"): 대장장이 창 → 가방에서 장비를 누르면 고철. 등급별 고철 수 (임시).
const SALVAGE_SCRAP := {&"normal": 1, &"magic": 2, &"rare": 3, &"crafted": 3, &"set": 5}

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
		name = "분원농협", junk_name = "슬라임 젤리", monster = "야생 슬라임", boss_monster = "대장 슬라임", waypoint = false,
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
		## 2026-09-30 사용자: "금사리 게도 너무 약해 보여" → 요괴 모래게 (그림 · 이름만, 동작 · 수치 · 파일 이름 그대로)
		name = "금사리", junk_name = "모래게 껍데기", monster = "요괴 모래게", boss_monster = "금두꺼비", waypoint = true,
		## 화면보다 넓은 맵 (2026-09-28 사용자 선택 C): data/hunt_maps/geumsa.txt, 카메라가 사냥꾼을 따라간다
		map = "geumsa",
		sheet = "res://assets/creatures/wild_sand_crab.png", boss_sheet = "res://assets/creatures/wild_gold_toad_hd.png", burrow = true,
		sign = "금사리(구터)",
		## 대장을 쓰러뜨리면 boss_egg_chance 확률로 떨어지는 알 (예전엔 반드시 → 2026-09-29 낮춤)
		boss_egg = "res://data/creatures/species/gold_toad.tres",
		egg_chance = 0.03, boss_egg_chance = 0.25,
		## 넓은 맵이라 모래톱마다 한 마리씩 (임시)
		count = 6, hp = 5, speed = 1.25, boss_hp = 9,
		## 금사리부터 확 세다 (2026-09-29 B): 체력 3→5, 하트 -2, 덜 밀림, 모래게가 무리로 튀어나옴. 대장 체력 6→9
		damage = 2, knockback = 6.0, windup = 0.4, pack = true, boss_pattern = &"tongue",
		## 입구 메뉴·들어올 때 보여 주는 권장 준비
		advice = "권장: 사냥칼",
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
		## 추수한 벌판 · 짚가리 · 옛 군량 곳간 · 배수로. 곡식 도둑 요괴 까마귀 떼가 날아다니고, 곳간을 지키던 허수아비 장수가 대장.
		## 2026-09-30 사용자: "몬스터가 참새이면 너무 약하고 짜치지 않나" → 요괴 까마귀로 (id · 파일 이름은 sparrow 그대로, 세이브 호환)
		name = "광동리", junk_name = "까마귀 깃털", monster = "요괴 까마귀", boss_monster = "허수아비 장수", waypoint = true,
		map = "gwangdong",
		labels = [[Vector2(26, 4.3), "군량 곳간"]],
		sheet = "res://assets/creatures/wild_sparrow.png", boss_sheet = "res://assets/creatures/wild_scarecrow_hd.png", burrow = false,
		## 까마귀는 날아다닌다 (flyer): 나는 동안 칼·몸이 닿지 않고, 내려꽂기(그림자 원 예고) 뒤 땅에서 낟알을 쪼는 동안만 칼에 맞는다
		flyer = true,
		## 알 (구역마다 일반 알 종): 까마귀 → 아기 까마귀. 대장도 가끔 같은 알.
		egg = "res://data/creatures/species/sparrow.tres", boss_egg = "res://data/creatures/species/sparrow.tres",
		## 까마귀는 금사리 모래게보다 두 배 넘게 많아서 한 마리 확률은 1% (사냥 한 번에 알 약 15%, 금사리와 비슷하게)
		egg_chance = 0.01, boss_egg_chance = 0.15,
		## 2막부터 한 계단 더 (대장간 제작품으로 금사리가 쉬워진 것을 보고, 2026-09-29): 내려꽂기 하트 -2, 대장 체력 26. windup = 내려꽂기 예고(초)
		count = 15, hp = 4, speed = 1.0, boss_hp = 26,
		## 몰아잡기 떼 (2026-10-02): 까마귀는 이미 많아서 두 마리씩
		swarm = 2,
		damage = 2, knockback = 4.0, windup = 0.35, pack = false, boss_pattern = &"straw",
		advice = "권장: 제작 장비",
		loot = {&"money": 38, &"potion": 25, &"junk": 19, &"gear": 18},
		rarity = {&"normal": 40, &"magic": 42, &"rare": 18}, boss_rarity = {&"normal": 15, &"magic": 55, &"rare": 30},
		money = [30, 60], boss_money = [70, 120],
		monster_tint = Color.WHITE, boss_tint = Color.WHITE, ground_tint = Color(0.92, 0.88, 0.74), tree_tint = Color(0.74, 0.86, 0.68),
	},
	{
		## 2막 둘째 구역 = 2막 마지막 구역 (2026-09-29 사용자: "4구역 이름은 도마리야 여긴 나무꾼 하는사람이 있는데
		## 이거랑 연관지은 나무 관련 몬스터가 있으면 좋겠어", "나무가 쌓여있는 하우스가 구조물로", "비닐하우스").
		## 참나무 숲 속 나무꾼 벌목터 · 장작 쌓인 비닐하우스 · 장작더미 · 그루터기 (칸 지도 data/hunt_maps/doma.txt).
		## 몬스터 고목 그루터기 (사용자: "몬스터는 고목그루터기 몬스터로"): 진짜 그루터기 사이에 그루터기인 척 숨어 있다가
		## (가끔 눈이 번쩍) 가까이 오면 일어나 녹슨 도끼로 달려든다 (금사리 모래게처럼 burrow + 달려들기).
		## 2막 대장 = 장승 한 쌍 (사용자: "보스는 장승", "천하대장군 지하여장군 무섭게 그리자"). 둘 다 쓰러뜨려야 도마리를 깬다.
		## 천하대장군 = 통나무 굴리기 (긴 띠 예고 → 통나무가 굴러감), 지하여장군 (partner) = 쿵 내려찍고 그루터기 새끼를 깨움.
		name = "도마리", junk_name = "고목 옹이", monster = "고목 그루터기", boss_monster = "천하대장군", waypoint = true,
		map = "doma",
		sheet = "res://assets/creatures/wild_old_stump.png", boss_sheet = "res://assets/creatures/wild_cheonha_hd.png", burrow = true,
		partner = {name = "지하여장군", sheet = "res://assets/creatures/wild_jiha_hd.png", pattern = &"slam"},
		## 알: 2막 일반 알 = 아기 까마귀 (광동리와 같음), 2막 대장 알 = 아기 나무 정령 (사용자: "알은 나무정령알")
		egg = "res://data/creatures/species/sparrow.tres", boss_egg = "res://data/creatures/species/tree_spirit.tres",
		egg_chance = 0.03, boss_egg_chance = 0.2,
		## 2막 대장이라 광동리보다 한 계단 더 (임시, 봇 50일로 맞춤). boss_hp 는 장승 하나 체력 (둘이라 합은 두 배)
		count = 10, hp = 7, speed = 1.1, boss_hp = 22,
		damage = 2, knockback = 4.0, windup = 0.4, pack = false, boss_pattern = &"log", disguise = true,
		## 2막 대장 재료 (2026-09-29 약방 복구): 장승 한 쌍을 쓰러뜨릴 때마다 장승 조각 하나, 처음 잡으면 다음 날 마을에 약방 터
		boss_material2 = true,
		advice = "권장: 제작 장비",
		loot = {&"money": 38, &"potion": 25, &"junk": 19, &"gear": 18},
		rarity = {&"normal": 35, &"magic": 44, &"rare": 21}, boss_rarity = {&"normal": 10, &"magic": 55, &"rare": 35},
		money = [35, 70], boss_money = [90, 150],
		monster_tint = Color.WHITE, boss_tint = Color.WHITE, ground_tint = Color(0.78, 0.86, 0.7), tree_tint = Color(0.66, 0.8, 0.6),
	},
	{
		## 3막 첫 구역 (2026-09-29 사용자: "3막 첫구역은 번천이고 삼거리이지만 주변에 산이랑 도로만있어서 다른데보다 기온이 낮고 어두워
		## / 밤에는 버스만다니고 사람이 안다녀 / 여기는 유령타입의 몬스터를 넣자", 후보 A 도깨비불 + 유령 막차 선택).
		## 광주시 유래: 상번천리 = 번천이라는 냇물이 흐르고 산이 울타리. 산으로 둘러싸인 T자 삼거리 · 가드레일 · 가로등 · 버스 정류장 · 번천 냇물.
		## 밤 구역 (night): 어둡고 가로등 · 호롱 불빛만 밝다. 유령 (ghost): 불빛 밖에선 반쯤 비쳐 무기가 지나간다.
		## 도깨비불 (wisp): 둥둥 떠다니며 벽 · 물을 지나간다. 불빛 안에서 가까이 오면 부풀어 불똥 튀기기 (원 예고), 튀긴 뒤 쪼그라든 동안이 칠 틈.
		## 대장 유령 막차 (bus): 전조등 긴 띠 예고 → 도로 따라 돌진, 멈춰 선 동안이 칠 틈, 두 번에 한 번 문이 열려 도깨비불 승객이 내린다.
		name = "번천", junk_name = "도깨비 불씨", monster = "도깨비불", boss_monster = "유령 막차", waypoint = true,
		map = "bunjeon",
		labels = [[Vector2(18, 14.6), "번천"]],
		sheet = "res://assets/creatures/wild_will_o.png", boss_sheet = "res://assets/creatures/ghost_bus.png", burrow = false,
		night = true, ghost = true, wisp = true,
		## 대장 그림 크기 (막차는 32칸 시트가 아니라 96x48 한 장, 대장 배율도 쓰지 않음)
		boss_frame = Vector2i(96, 48),
		## 알: 3막 일반 알 = 아기 도깨비불 (새 속성 불). 대장도 가끔 같은 알.
		egg = "res://data/creatures/species/will_o.tres", boss_egg = "res://data/creatures/species/will_o.tres",
		egg_chance = 0.03, boss_egg_chance = 0.2,
		## 3막이라 도마리보다 한 계단 더 (임시). 도깨비불은 불빛 안에서만 맞아서 체력은 조금 낮게.
		count = 12, hp = 6, speed = 1.2, boss_hp = 40,
		damage = 2, knockback = 4.0, windup = 0.5, pack = false, boss_pattern = &"bus",
		advice = "권장: 호롱 기름",
		loot = {&"money": 36, &"potion": 26, &"junk": 20, &"gear": 18},
		rarity = {&"normal": 30, &"magic": 45, &"rare": 25}, boss_rarity = {&"normal": 5, &"magic": 55, &"rare": 40},
		money = [40, 80], boss_money = [110, 180],
		monster_tint = Color.WHITE, boss_tint = Color.WHITE, ground_tint = Color(0.6, 0.72, 0.74), tree_tint = Color(0.5, 0.66, 0.56),
	},
	{
		## 3막 둘째 구역 = 3막 대장 (2026-09-30 사용자: "다음은 광주시에있는 밀목이야", 후보 B 늑대 + 호랑이,
		## "몬스터를 좀 더 판타지 풍으로 해도 괜찮아 배경이 몬스터 침공 이후 정착한 분원리 이기때문에").
		## 광주시 유래: 송정동 밀목 = "마을 근방에 나무가 빽빽하게 우거졌다" (密木), 솔치(송현) 고개, 경안천 · 탄벌천 어귀.
		## 빽빽한 솔숲 사이 좁은 숲길 (옆으로 비킬 데가 적음), 그늘이라 조금 어두움 (밤 · 유령 규칙은 없음).
		## 그림자 늑대 (wolf): 사냥꾼을 보면 무리가 둘레에 둘러서서 돌고, 하나씩 차례로 달려든다. 하나가 쓰러지면 둘레 늑대가 멈칫.
		## 대장 산군 백호 (tiger): 긴 도약 (착지 원 예고) → 쓰러지는 나무 (띠 예고, 굴러옴) → 포효 (둘레 원 안이면 잠깐 굳음) 를 돌아가며.
		## 번천이 너무 쉬웠던 봇 결과 (한 번에 0.3~0.7번 맞음, 도마리 2.3~2.9) 를 보고 도마리보다 어렵게 (임시).
		name = "밀목", junk_name = "그림자 털", monster = "그림자 늑대", boss_monster = "산군 백호", waypoint = true,
		map = "milmok",
		sheet = "res://assets/creatures/wild_shadow_wolf.png", boss_sheet = "res://assets/creatures/wild_white_tiger.png", burrow = false,
		wolf = true, shade = Color(0.68, 0.76, 0.72),
		## 알: 3막 일반 알 = 아기 도깨비불 (번천과 같음), 3막 대장 알 = 아기 호랑이 (드물게 아기 백호, WHITE_TIGER_CHANCE)
		egg = "res://data/creatures/species/will_o.tres", boss_egg = "res://data/creatures/species/tiger.tres",
		egg_chance = 0.03, boss_egg_chance = 0.2,
		count = 12, hp = 8, speed = 1.3, boss_hp = 50,
		## 몰아잡기 떼 (2026-10-02): 늑대는 둘러서서 돌아 세 마리씩
		swarm = 3,
		damage = 2, knockback = 4.0, windup = 0.35, pack = false, boss_pattern = &"tiger",
		## 3막 대장 재료 (2026-09-30 축사 닭장): 백호를 쓰러뜨릴 때마다 산군 발톱 하나, 처음 잡으면 다음 날 마을에 축사 터
		boss_material3 = true,
		advice = "권장: 사냥 도시락",
		loot = {&"money": 34, &"potion": 26, &"junk": 20, &"gear": 20},
		rarity = {&"normal": 25, &"magic": 45, &"rare": 30}, boss_rarity = {&"normal": 5, &"magic": 50, &"rare": 45},
		money = [45, 90], boss_money = [140, 220],
		monster_tint = Color.WHITE, boss_tint = Color.WHITE, ground_tint = Color(0.62, 0.76, 0.6), tree_tint = Color(0.42, 0.6, 0.46),
	},
	{
		## 4막 첫 구역 (2026-10-02 사용자: "역동에는 말이 유명하니 켄타우로스 같은 것으로", 후보 A 창기병 + 역마 장군 선택).
		## 역동 (驛洞) = 옛 경안역 역참, 역마를 두던 마을 (Claude 지식, 광주시 읍면동 유래 페이지엔 없음). 4막 둘째 구역 곤지암 (신립 장군 · 고양이 바위,
		## 말굽이 땅에서 안 떨어졌다는 설화) 과 "말" 로 이어진다.
		## 아래 입구 → 옛 역로 (모래길) → 넓은 말 들판 (숨을 데가 적음) → 위 왼쪽 경안역 마방 (대장 자리) → 위 오른쪽 곤지암 쪽 길. 오른쪽 아래 경안천.
		## 켄타우로스 창기병 (lancer): 발을 구르며 긴 띠 예고 (구역 windup) → 들판을 가로질러 긴 돌격 (LANCER_DISTANCE), 지나친 뒤
		## 돌아서는 동안 (LANCER_RECOVER, 7열) 이 칠 틈. 구르기로 피하고 돌아서는 틈에 친다.
		## 대장 역마 장군 (general): 사냥꾼 쪽으로 꺾이는 창 돌격 세 번 → 크게 헐떡임, 두 번에 한 번 파발 나팔 (창기병 둘).
		## 체력 절반부터 돌격 전에 말발굽 쿵 (내려찍기 원).
		name = "역동", junk_name = "말갈기", monster = "켄타우로스 창기병", boss_monster = "역마 장군", waypoint = true,
		map = "yeokdong",
		labels = [[Vector2(10, 2.4), "경안역 마방"]],
		sheet = "res://assets/creatures/wild_lancer.png", boss_sheet = "res://assets/creatures/wild_post_general.png", burrow = false,
		lancer = true,
		## 알: 4막 일반 알 = 아기 망아지 (땅, 밭 갈기). 대장도 가끔 같은 알.
		egg = "res://data/creatures/species/foal.tres", boss_egg = "res://data/creatures/species/foal.tres",
		## 창기병이 둘씩 다녀 마릿수가 많으므로 알 확률을 반으로 (첫 봇: 0.03 이면 110일에 망아지 알 17~29개).
		egg_chance = 0.015, boss_egg_chance = 0.2,
		## 밀목보다 한 계단 (임시, 봇으로 맞춤). 창기병은 둘씩 짝지어 (떼 2). 첫 봇에서 51번 사냥에 맞은 횟수 0~2 → 예고를 짧게, 더 단단하게.
		count = 10, hp = 13, speed = 1.3, boss_hp = 80,
		swarm = 2,
		damage = 3, knockback = 4.0, windup = 0.4, pack = false, boss_pattern = &"general",
		advice = "권장: 사냥 도시락",
		loot = {&"money": 34, &"potion": 26, &"junk": 20, &"gear": 20},
		rarity = {&"normal": 22, &"magic": 46, &"rare": 32}, boss_rarity = {&"normal": 5, &"magic": 48, &"rare": 47},
		money = [50, 95], boss_money = [150, 240],
		monster_tint = Color.WHITE, boss_tint = Color.WHITE, ground_tint = Color(0.86, 0.9, 0.7), tree_tint = Color(0.66, 0.82, 0.6),
	},
	{
		## 4막 둘째 구역 = 4막 대장 (2026-10-02 사용자: "곤지암 정신병원 메타로 너가 추천해서 정해줘 고르는건 내가 고를게",
		## 첫 후보를 보고 "몬스터 더 강해보이는걸로하자 4막인만큼 악마타입으로" → 악마형 후보 A 뿔 악귀 + 마왕 선택).
		## 광주시 유래: 신립 장군 묘 가까이 고양이 바위, 말을 타고 지나면 말굽이 안 떨어졌고 장군이 꾸짖자 천둥에 바위가 갈라졌다는 설화.
		## 아래 입구 → 곤지천 (나무 다리 · 여울) → 신립 장군 묘 · 두 쪽 난 고양이 바위 → 가로등 선 진입로 → 무너진 철망 → 위 폐병원
		## (본관 + 양쪽 병동, 시멘트 앞마당, 대장은 본관 문 앞). 괴물은 악마 · 요괴로만 (병원에 있던 사람을 괴물로 그리지 않음).
		## 뿔 악귀 (demon): 사냥꾼이 바라보는 쪽 (DEMON_GAZE 부채꼴) 에선 얼어붙고, 등 뒤 · 옆에선 걸어서 다가온다.
		## 붙으면 두 팔을 치켜들어 (구역 windup) 둘레 내려찍기 (DEMON_SLAM_RADIUS). 정전 동안엔 바라봐도 움직인다.
		## 대장 마왕 (archdemon): 지옥불 등불이 깜빡이다 (ARCH_DIM_WINDUP) 꺼지면 정전 (ARCH_BLACKOUT) + 사냥꾼 등 뒤에 악귀 ARCH_CALL 마리,
		## 다음 차례엔 지옥불 기둥 (원 ARCH_PILLARS 개). 체력 절반부터 정전이 길고 (ARCH_BLACKOUT_ENRAGED) 기둥이 늘어남.
		name = "곤지암", junk_name = "악귀 뿔", monster = "뿔 악귀", boss_monster = "마왕", waypoint = true,
		map = "gonjiam",
		labels = [[Vector2(25.5, 1.3), "폐병원"]],
		sheet = "res://assets/creatures/wild_horn_demon.png", boss_sheet = "res://assets/creatures/wild_archdemon.png", burrow = false,
		demon = true, shade = Color(0.7, 0.66, 0.8),
		## 알: 4막 대장 알 = 아기 악귀 (불, 밤일). 일반 몬스터도 가끔 같은 알.
		egg = "res://data/creatures/species/imp.tres", boss_egg = "res://data/creatures/species/imp.tres",
		egg_chance = 0.012, boss_egg_chance = 0.2,
		## 역동보다 한 계단 (임시, 봇으로 맞춤). 악귀는 넷씩 떼 (등 뒤를 노려 둘러쌈).
		count = 9, hp = 14, speed = 1.3, boss_hp = 100,
		swarm = 5,
		## 함께 덤비는 수 (2026-10-02 3~4막 난이도: 악귀 떼가 등 뒤에서 함께 덮치게, 기본 MAX_ATTACKERS)
		max_attackers = 4,
		damage = 3, knockback = 3.0, windup = 0.3, pack = false, boss_pattern = &"archdemon",
		## 4막 대장 재료 (2026-10-02 나루터): 마왕을 쓰러뜨릴 때마다 마왕 뿔 하나, 처음 잡으면 다음 날 마을 팔당호 물가에 나루터 터
		boss_material4 = true,
		advice = "권장: 사냥 도시락",
		loot = {&"money": 32, &"potion": 26, &"junk": 20, &"gear": 22},
		rarity = {&"normal": 20, &"magic": 46, &"rare": 34}, boss_rarity = {&"normal": 0, &"magic": 45, &"rare": 55},
		money = [55, 105], boss_money = [180, 280],
		monster_tint = Color.WHITE, boss_tint = Color.WHITE, ground_tint = Color(0.62, 0.66, 0.6), tree_tint = Color(0.42, 0.5, 0.44),
	},
	{
		## 5막 첫 구역 (2026-10-03 사용자: "9구역은 귀여리로가자 / 9구역에서는 도마뱀인간 종류 보스는 알아서 후보정해주고").
		## 귀여리 = 분원리 바로 옆 팔당호 물가 마을 (Claude 지식, 광주시 페이지 남종면 설명은 못 불러옴). 5막은 이야기가 마을로 돌아온다:
		## 곤지암 마왕을 잡으면 위쪽 길 대신 마을 사냥터 입구 웨이포인트로 귀여리가 켜진다 (from_village).
		## 아래 입구 → 귀여리 옛 집 · 밭 → 물가 모래길 → 위 · 오른쪽 팔당호 (얕은 물가 · 갈대) → 위 모래톱 도마뱀인간 야영지 (대장 자리).
		name = "귀여리", junk_name = "도마뱀 비늘", monster = "방패 도마뱀", boss_monster = "도마뱀 족장", waypoint = true,
		map = "guiyeo", from_village = true,
		labels = [[Vector2(26.5, 7.3), "도마뱀 야영지"]],
		sheet = "res://assets/creatures/wild_shield_lizard.png", boss_sheet = "res://assets/creatures/wild_lizard_chief.png", burrow = false,
		## 방패 도마뱀 (shield, 2026-10-03 사용자 선택 A): 바라보는 쪽에서 친 공격은 방패에 막힘 (팅!).
		## 창을 당겼다 (구역 windup) 길게 찌른 뒤 (LIZARD_THRUST) 방패가 내려간 틈 (LIZARD_SHIELD_DOWN) · 옆 · 등 뒤를 노린다. 떼 4.
		## 대장 도마뱀 족장 (chief): 전쟁 북 (모든 방패 금빛 CHIEF_GOLD_TIME + 도마뱀 CHIEF_CALL 마리) → 꼬리 휘두르기 (둘레 원),
		## 체력 절반부터 창 던지기 CHIEF_SPEARS 개.
		shield = true,
		## 알: 아기 도마뱀 (땅, 장보기 = 공급함 판매값 +20%, 동행 냄비뚜껑 방패). 대장도 가끔 같은 알.
		egg = "res://data/creatures/species/lizard.tres", boss_egg = "res://data/creatures/species/lizard.tres",
		egg_chance = 0.012, boss_egg_chance = 0.2,
		## 곤지암보다 한 계단 (임시, 봇으로 맞춤)
		count = 9, hp = 15, speed = 1.3, boss_hp = 110,
		swarm = 4, max_attackers = 3,
		damage = 3, knockback = 3.0, windup = 0.45, pack = false, boss_pattern = &"chief",
		advice = "권장: 사냥 도시락",
		loot = {&"money": 32, &"potion": 26, &"junk": 20, &"gear": 22},
		rarity = {&"normal": 18, &"magic": 46, &"rare": 36}, boss_rarity = {&"normal": 0, &"magic": 44, &"rare": 56},
		money = [60, 110], boss_money = [190, 300],
		monster_tint = Color.WHITE, boss_tint = Color.WHITE, ground_tint = Color(0.82, 0.9, 0.74), tree_tint = Color(0.56, 0.72, 0.52),
	},
	{
		## 5막 둘째 구역 = 5막 대장 = 마지막 대장 (2026-10-03 사용자: "나도 마지막은 10구역 소내섬 하려고했어 / 10구역 은 와이번이고
		## 마지막보스는 신비로운 용? 드래곤? 이런걸로 했으면 좋겠어"). 소내섬 = 팔당호 안 섬. 걸어서는 못 가고, 귀여리 대장을 잡은 뒤
		## 고친 나루터에서 뱃사공 나룻배로 건너간다 (ferry: 사냥터 입구 웨이포인트 목록에 없음). 아래 나루 (E = 마을로 가는 배) → 모래 기슭
		## → 솔숲 · 바위 → 가운데 돌계단 → 위 용소 물굽이 (대장 자리).
		name = "소내섬", junk_name = "와이번 비늘", monster = "독꼬리 와이번", boss_monster = "용", waypoint = true,
		map = "sonae", ferry = true, final = true,
		## 5막 대장 재료 (용 비늘, 2026-10-03 시설 5 마을회관)
		boss_material5 = true,
		labels = [[Vector2(26.0, 6.4), "용소"]],
		sheet = "res://assets/creatures/wild_wyvern.png", boss_sheet = "res://assets/creatures/wild_dragon.png", burrow = false,
		## 와이번은 까마귀처럼 날다가 내려꽂는다 (flyer). 나는 동안은 안 맞고, 내려앉아 숨 고를 때 맞는다.
		flyer = true,
		## 알: 와이번 → 아기 와이번 (하늘 배달). 일반 용도 가끔 같은 알.
		egg = "res://data/creatures/species/wyvern.tres", boss_egg = "res://data/creatures/species/wyvern.tres",
		egg_chance = 0.012, boss_egg_chance = 0.25,
		## 마지막 대장 (2026-10-03 사용자: "마지막은 기본이 일반용이고 희귀한 확률로 세가지 용이 우연하게나오는 구조로가자").
		## 처음 만나는 대장은 늘 일반 용. 한 번 잡은 뒤 다시 오면 셋 중 하나가 DRAGON_RARE_CHANCE 씩 대신 나온다.
		## 희귀 용은 자기 기술이 하나 더 있고, egg_chance 확률로 자기 아기 알을 남긴다 (값 임시).
		variants = [
			{id = &"blue", name = "팔당 청룡", sheet = "res://assets/creatures/wild_blue_dragon.png", egg = "res://data/creatures/species/blue_dragon.tres", egg_chance = 0.5},
			{id = &"cloud", name = "운룡", sheet = "res://assets/creatures/wild_cloud_dragon.png", egg = "res://data/creatures/species/cloud_dragon.tres", egg_chance = 0.5},
			{id = &"gold", name = "황금 드래곤", sheet = "res://assets/creatures/wild_gold_dragon.png", egg = "res://data/creatures/species/gold_dragon.tres", egg_chance = 0.5},
		],
		count = 9, hp = 15, speed = 1.3, boss_hp = 200,
		swarm = 3, max_attackers = 3,
		damage = 3, knockback = 3.0, windup = 0.4, pack = false, boss_pattern = &"dragon",
		advice = "권장: 사냥 도시락 · 매운탕",
		loot = {&"money": 30, &"potion": 26, &"junk": 20, &"gear": 24},
		rarity = {&"normal": 15, &"magic": 45, &"rare": 40}, boss_rarity = {&"normal": 0, &"magic": 40, &"rare": 60},
		money = [65, 120], boss_money = [260, 400],
		monster_tint = Color.WHITE, boss_tint = Color.WHITE, ground_tint = Color(0.76, 0.88, 0.76), tree_tint = Color(0.46, 0.64, 0.5),
	},
]
## 나룻배로만 가는 섬 구역 번호 (HUNT_ZONES 에 ferry = true), 없으면 -1
static func ferry_zone() -> int:
	for i in HUNT_ZONES.size():
		if HUNT_ZONES[i].get("ferry", false):
			return i
	return -1


## 켄타우로스 창기병 (역동 lancer, 2026-10-02): 사냥꾼이 LANCER_TRIGGER 안이면 발을 구르며 (구역 windup) 긴 띠 예고 →
## LANCER_TIME 동안 LANCER_DISTANCE 만큼 돌격 (나무 · 바위에 막히면 거기서 멈춤). 돌격 뒤 LANCER_RECOVER 초 돌아섬 = 칠 틈.
## 2026-10-02 3~4막 난이도: 돌격 쿨 1.8 → 1.2, 돌아서는 틈 1.1 → 0.8 (임시)
const LANCER_TRIGGER := 150.0
const LANCER_DISTANCE := 170.0
const LANCER_TIME := 0.45
const LANCER_RECOVER := 0.8
const LANCER_COOLDOWN := 1.2
## 역마 장군 (역동 대장 general): GENERAL_RANGE 안이면 창 돌격 GENERAL_CHARGES 번. 첫 돌격 예고 GENERAL_WINDUP, 다음은 GENERAL_NEXT_WINDUP
## (그때 사냥꾼 쪽으로 다시 꺾음). 돌격에 닿으면 (GENERAL_HIT_RADIUS) 하트 -피해. 다 달린 뒤 GENERAL_RECOVER 초 헐떡임 = 칠 틈.
## 두 번에 한 번 파발 나팔: 창기병 GENERAL_CALL 마리 (원래 크기, 체력 낮음, 드롭 · 알 없음, 최대 SLAM_MINION_MAX).
## 체력이 절반 아래면 돌격 앞에 말발굽 쿵 (내려찍기 원 SLAM_RADIUS, 새끼 안 나옴).
const GENERAL_RANGE := 240.0
const GENERAL_CHARGES := 3
const GENERAL_WINDUP := 0.8
const GENERAL_NEXT_WINDUP := 0.35
const GENERAL_LENGTH := 150.0
const GENERAL_TIME := 0.45
const GENERAL_HIT_RADIUS := 20.0
const GENERAL_RECOVER := 1.8
const GENERAL_COOLDOWN := 2.2
const GENERAL_CALL := 2
const GENERAL_MINION_HP := 3
## 귀여리 방패 도마뱀 (shield, 2026-10-03 사용자 선택 A): 창 찌르기 길이 · 시간, 찌른 뒤 방패가 내려가 있는 시간 (= 앞에서도 칠 틈).
## 방패는 바라보는 쪽 LIZARD_FRONT_DOT (cos, 약 ±70도) 안을 막고, 금빛 (족장 북) 이면 LIZARD_GOLD_DOT (약 ±115도) 까지 · 찌른 뒤에도 막음.
const LIZARD_THRUST := 64.0
const LIZARD_THRUST_TIME := 0.22
const LIZARD_SHIELD_DOWN := 1.3
const LIZARD_FRONT_DOT := 0.35
const LIZARD_GOLD_DOT := -0.4
## 도마뱀 족장 (chief): CHIEF_RANGE 안이면 전쟁 북 (예고 CHIEF_DRUM_WINDUP) → 꼬리 휘두르기 (원 CHIEF_TAIL_RADIUS) → (절반부터) 창 던지기.
const CHIEF_RANGE := 220.0
const CHIEF_DRUM_WINDUP := 1.0
const CHIEF_GOLD_TIME := 4.0
const CHIEF_CALL := 2
const CHIEF_MINION_HP := 3
const CHIEF_TAIL_WINDUP := 0.7
const CHIEF_TAIL_RADIUS := 56.0
const CHIEF_SPEARS := 3
const CHIEF_SPEAR_WINDUP := 0.8
const CHIEF_SPEAR_RADIUS := 18.0
const CHIEF_RECOVER := 1.2
const CHIEF_COOLDOWN := 1.4
## 아기 도마뱀 장보기: 공급함 밤사이 판매값 +20% · 냄비뚜껑 방패 쿨 (초)
const MARKET_BONUS := 0.2
const LID_COOLDOWN := 6.0
## 소내섬 용 (dragon, 2026-10-03, 값 전부 임시): DRAGON_RANGE 안이면 물어뜯기 돌진 → 날개 바람 (→ 희귀 용은 자기 기술) 을 돌아가며.
## 돌진은 역마 장군 창 돌격과 같은 식 (첫 예고 DRAGON_WINDUP, 꺾어 잇는 돌진 DRAGON_NEXT_WINDUP, DRAGON_CHARGES 번, 절반부터 +1),
## 몸통 반지름 DRAGON_HIT_RADIUS. 다 달리면 DRAGON_RECOVER 초 숨 고름 = 칠 틈, 두 번에 한 번 와이번 DRAGON_CALL 마리를 부름.
## 날개 바람: 용 둘레 원 DRAGON_GUST_RADIUS (예고 DRAGON_GUST_WINDUP), 안이면 다치고 DRAGON_GUST_PUSH 만큼 밀려남.
const DRAGON_RANGE := 260.0
const DRAGON_CHARGES := 2
const DRAGON_WINDUP := 0.8
const DRAGON_NEXT_WINDUP := 0.4
const DRAGON_LENGTH := 170.0
const DRAGON_TIME := 0.5
const DRAGON_HIT_RADIUS := 26.0
const DRAGON_RECOVER := 1.6
const DRAGON_SPECIAL_RECOVER := 1.0
const DRAGON_COOLDOWN := 1.6
const DRAGON_CALL := 2
const DRAGON_MINION_HP := 3
const DRAGON_GUST_WINDUP := 0.9
const DRAGON_GUST_RADIUS := 70.0
const DRAGON_GUST_PUSH := 40.0
## 희귀 용 (variants): 첫 만남은 늘 일반 용, 그 뒤 찾아갈 때마다 하나씩 DRAGON_RARE_CHANCE 확률 (셋 합 15%)
const DRAGON_RARE_CHANCE := 0.05
## 청룡 물기둥 (마왕 지옥불 기둥과 같은 식): 수 (절반부터 +2) · 예고
const DRAGON_PILLARS := 3
const DRAGON_PILLAR_WINDUP := 0.9
## 운룡 안개 (마왕 정전과 같은 식, 흰 안개): 여의주 빛 예고
const DRAGON_FOG_WINDUP := 0.8
## 황금 드래곤 불 숨결 (굴러가는 불덩이) 예고 · 절반부터 금화 비 (원 수, 떨어진 자리에 돈)
const DRAGON_BREATH_WINDUP := 0.7
const DRAGON_COINS := 4
const DRAGON_COIN_MONEY := [20, 40]

## 아기 망아지 동행 뒷발차기 (kick): 맞은 몬스터가 KICK_PUSH 만큼 밀려나며 KICK_STUN 초 멈춤 (대장은 안 밀림)
const COMPANION_KICK_PUSH := 44.0
const COMPANION_KICK_STUN := 0.5
const COMPANION_KICK_INTERVAL := 1.3
const COMPANION_KICK_RANGE := 18.0
## 아기 망아지 밭 갈기 (plow, 2026-10-02): 농사를 맡으면 수확한 빈 칸을 깊이 갈아 둔다 (안 간 칸이면 갈기까지).
## 깊이 간 칸에서 거둔 무는 PLOW_BONUS 개 더 (거두면 다시 보통 칸).
const PLOW_BONUS := 1
## 뿔 악귀 (곤지암 demon, 2026-10-02): 사냥꾼이 바라보는 쪽 (바라보는 방향에서 DEMON_GAZE 라디안 안, DEMON_GAZE_RANGE 거리 안) 에선
## 얼어붙는다 (예고 중이어도 멈춤). 아니면 DEMON_NOTICE 안에서 DEMON_WALK 빠르기로 걸어 다가와, DEMON_TRIGGER 안이면 팔을 치켜들고
## (구역 windup) 둘레 DEMON_SLAM_RADIUS 를 내려찍는다. 찍은 뒤 DEMON_RECOVER 초 숨 고름 = 칠 틈.
## 2026-10-02 3~4막 난이도: 봇 기준 악귀가 거의 닿지 못해 (사냥 한 번에 내려찍기 0번) 바라보는 폭을 좁히고, 안 볼 때 더 빨리 걷고,
## 한 번 더 내려찍게 함 (돌아서서 바라보면 이것도 얼어붙음 = 피하는 법). 값은 임시.
const DEMON_GAZE := 0.6
const DEMON_GAZE_RANGE := 150.0
const DEMON_NOTICE := 200.0
const DEMON_WALK := 150.0
const DEMON_TRIGGER := 36.0
const DEMON_SLAM_RADIUS := 42.0
const DEMON_RECOVER := 1.1
const DEMON_COOLDOWN := 1.6
## 둘째 내려찍기 (2026-10-02 3~4막 난이도): 첫 내려찍기 뒤 DEMON_SECOND_STEP 만큼 다가와 DEMON_SECOND_WINDUP 예고로 한 번 더
const DEMON_SECOND_WINDUP := 0.45
const DEMON_SECOND_STEP := 18.0
## 마왕 (곤지암 대장 archdemon): ARCH_RANGE 안이면 등불 깜빡임 (ARCH_DIM_WINDUP) → 정전 ARCH_BLACKOUT 초 (절반 아래 ARCH_BLACKOUT_ENRAGED)
## + 사냥꾼 등 뒤에 악귀 ARCH_CALL 마리 (원래 크기, 체력 ARCH_MINION_HP, 드롭 · 알 없음, 최대 SLAM_MINION_MAX).
## 다음 차례는 지옥불 기둥: 사냥꾼 발밑 + 둘레에 원 ARCH_PILLARS 개 (절반 아래 ARCH_PILLARS_ENRAGED), 예고 ARCH_PILLAR_WINDUP, 원 안이면 하트 -피해.
## 정전 동안 화면은 사냥꾼 둘레 ARCH_DARK_RADIUS 만 보인다.
const ARCH_RANGE := 260.0
const ARCH_DIM_WINDUP := 0.9
const ARCH_BLACKOUT := 1.4
const ARCH_BLACKOUT_ENRAGED := 2.6
const ARCH_CALL := 2
const ARCH_MINION_HP := 4
const ARCH_PILLARS := 2
const ARCH_PILLARS_ENRAGED := 4
const ARCH_PILLAR_WINDUP := 0.8
const ARCH_PILLAR_GAP := 0.25
const ARCH_PILLAR_RADIUS := 22.0
const ARCH_PILLAR_SPREAD := 40.0
const ARCH_RECOVER := 1.4
const ARCH_COOLDOWN := 2.4
const ARCH_DARK_RADIUS := 70.0
## 아기 악귀 동행 불 할퀴기 + 겁주기 (scare, 2026-10-02 곤지암): 맞은 몬스터가 IMP_FEAR 초 동안 사냥꾼에게서 달아난다 (공격 안 함, 대장은 안 겁먹음)
const COMPANION_IMP_INTERVAL := 1.2
const COMPANION_IMP_RANGE := 18.0
const IMP_FEAR := 1.2
const IMP_FLEE_SPEED := 60.0
## 아기 악귀 밤일 (night, 2026-10-02): 밤사이 맡은 일 (농사 · 고철 · 도라지 · 모이) 을 한 바퀴 더 해 둔다. 한 마리가 하룻밤에 하는 일 최대 NIGHT_WORK_MAX 번.
const NIGHT_WORK_MAX := 12
## 그림자 늑대 (밀목 wolf, 2026-09-30): 사냥꾼이 WOLF_NOTICE 안이면 사냥꾼 둘레 WOLF_RING 거리에 둘러서서 천천히 돈다.
## 돌다가 달려들기 쿨이 끝나면 (첫 쿨은 늑대마다 어긋나게) 보통 달려들기 (구역 windup 예고 → 돌진). 달려든 뒤 WOLF_LUNGE_COOLDOWN.
## 하나가 쓰러지면 WOLF_FLINCH_RANGE 안의 늑대가 WOLF_FLINCH 초 멈칫 (칠 틈).
const WOLF_NOTICE := 150.0
const WOLF_RING := 58.0
const WOLF_CIRCLE_SPEED := 0.6
const WOLF_MOVE_SPEED := 70.0
const WOLF_LUNGE_COOLDOWN := 3.0
const WOLF_FIRST_GAP := 0.9
const WOLF_FLINCH_RANGE := 140.0
const WOLF_FLINCH := 0.9
## 산군 백호 (밀목 대장 tiger): 도약 (SLAM 과 같은 착지 원, 새끼 없음) → 쓰러지는 나무 (LOG 와 같은 띠) → 포효 를 돌아가며.
## 포효: TIGER_ROAR_WINDUP 동안 둘레 TIGER_ROAR_RADIUS 원 예고 → 원 안의 사냥꾼은 TIGER_ROAR_FREEZE 초 굳음 (움직이기 · 공격 못 함).
const TIGER_RANGE := 200.0
const TIGER_LEAP_COOLDOWN := 2.8
const TIGER_ROAR_WINDUP := 0.9
const TIGER_ROAR_RADIUS := 70.0
const TIGER_ROAR_FREEZE := 0.7
const TIGER_ROAR_RECOVER := 1.2
const TIGER_ROAR_COOLDOWN := 2.6
## 3막 대장 알이 아기 백호일 확률 (대장 알이 나왔을 때, 임시)
const WHITE_TIGER_CHANCE := 0.1
## 아기 호랑이 동행 포효 (roar): 공격할 때 둘레 COMPANION_ROAR_RADIUS 몬스터가 COMPANION_ROAR_STUN 초 멈춤.
## 아기 백호 (spirit): 포효 + 번개 발톱 (그 한 방이 2 피해)
const COMPANION_ROAR_RADIUS := 48.0
const COMPANION_ROAR_STUN := 0.8
const COMPANION_ROAR_INTERVAL := 1.6
const COMPANION_ROAR_RANGE := 30.0
## 밤 구역 (2026-09-29 번천, 사용자: "주변에 산이랑 도로만있어서 다른데보다 기온이 낮고 어두워 / 밤에는 버스만다니고 사람이 안다녀").
## 구역 데이터 night 면 화면 전체를 이 색으로 어둡게 하고, 가로등(칸 지도 L) · 사냥꾼 호롱 불빛만 밝다. 값은 전부 임시.
const NIGHT_ZONE_COLOR := Color(0.2, 0.22, 0.36)
## 가로등 · 호롱 불빛 반지름 (px). 이 안이 "불빛 안".
const LAMP_LIGHT_RADIUS := 64.0
const LANTERN_RADIUS := 44.0
## 유령 (구역 데이터 ghost, 사용자: "여기는 유령타입의 몬스터를 넣자"): 불빛 밖에선 반쯤 비쳐 칼 · 화살 · 구슬 · 동행이 모두 지나간다.
## 불빛(가로등 · 호롱) 안에 들어와야 맞는다. 대장은 늘 맞는다.
const GHOST_FADE := 0.35
## 도깨비불 (번천 wisp): 불빛 안에서 이 거리 안에 오면 부풀어 (구역 windup 초 예고) 둘레 WISP_BURST_RADIUS 에 불똥을 튀긴다.
## 튀긴 뒤 WISP_RECOVER 초 쪼그라들어 멈춘다 (칠 틈). 도깨비불은 벽 · 물 · 가드레일을 지나 떠다닌다.
const WISP_TRIGGER := 48.0
const WISP_BURST_RADIUS := 40.0
const WISP_RECOVER := 1.2
const WISP_COOLDOWN := 1.8
## 유령 막차 (번천 대장 bus): 사냥꾼 쪽 (가로 · 세로 중 먼 쪽 = 도로 방향) 긴 띠 예고 BUS_WINDUP 뒤 BUS_TIME 동안 BUS_LENGTH 만큼 돌진.
## 버스에 닿으면 (띠 너비 BUS_WIDTH) 하트 -피해. 멈춰 선 BUS_RECOVER 초가 칠 틈. 두 번에 한 번 문이 열려 도깨비불 BUS_RIDERS 마리가 내린다.
const BUS_RANGE := 260.0
const BUS_WINDUP := 1.0
const BUS_LENGTH := 260.0
const BUS_TIME := 0.9
const BUS_WIDTH := 40.0
const BUS_COOLDOWN := 2.6
const BUS_RECOVER := 1.8
const BUS_RIDERS := 2
## 막차 전조등 불빛 반지름 (px, 버스 앞)
const BUS_LIGHT_RADIUS := 60.0
## 호롱 기름 (연금술사, 2026-09-29 약방 A+B): 밤 구역에 들어갈 때 하나 쓰면 그 사냥 동안 호롱 불빛이 이 배율로 넓어진다
const LAMP_OIL_MULT := 1.6
## 아기 도깨비불 동행 (불빛 + 불씨): 둘레 COMPANION_EMBER_LIGHT 가 불빛 안이 되고, 불씨가 닿은 몬스터는 STAFF_BURN_DELAY 뒤 한 번 더 맞는다
const COMPANION_EMBER_RANGE := 70.0
const COMPANION_EMBER_INTERVAL := 1.8
const COMPANION_EMBER_LIGHT := 56.0
## 넓은 맵의 여울(얕은 물)에서 걷기 빠르기 배율 (임시)
const HUNT_FORD_SPEED := 0.6
## 넓은 맵의 물 댄 논에서 사냥꾼 걷기 빠르기 배율 (임시). 슬라임은 느려지지 않는다.
const HUNT_PADDY_SPEED := 0.6
## 그루터기인 척 숨은 고목 그루터기가 눈을 번쩍이는 간격 (초, 임시)
const DISGUISE_BLINK_EVERY := 3.0
## 숨은 몬스터가 튀어나오는 거리 (px)
const WILD_BURROW_POP_DISTANCE := 60.0
## 무리(pack) 구역에서 하나가 튀어나오면 이 거리 안의 숨은 몬스터도 같이 튀어나온다 (px)
const WILD_PACK_DISTANCE := 110.0

## 대장간 복구 · 대장장이 (2026-09-29 사용자 선택 A: 한 번에 복구 + 사람 장비 제작). 본편 첫 조각. 값·자리·그림 전부 임시.
## 1막 대장(금사리 금두꺼비)을 처음 쓰러뜨린 다음 날 아침, 마을 아랫길 왼쪽 풀밭에 무너진 대장간 터가 드러난다.
## 터에서 F → 복구에 드는 것 (돈 · 무 · 1막 대장 재료 사금 덩이)을 다 모았으면 한 번에 고친다.
## 고치면 대장장이(마을 사람)가 열리고, 옆에 고물 더미가 생겨 크리처에게 고철 줍기를 맡길 수 있다.
## 대장장이는 모루에서 고철 + 돈으로 현대풍 장비를 만든다. 만들 때마다 디아블로2 제작처럼 옵션을 무작위로 굴린다.
## 자리: 아랫길 왼쪽 풀밭 (3칸 x 2칸). 고물 더미는 오른쪽 (2칸 x 1칸), 대장장이는 그 사이 (2026-10-01 마을 넓히기 A).
const FORGE_RECT := Rect2i(4, 16, 3, 2)
const SCRAP_RECT := Rect2i(11, 17, 2, 1)
## 대장장이가 처음 서는 칸 (대장간 오른쪽 앞, 한 칸 띄움. 대장간 그림 · 배지와 이름표가 안 겹치게)
const SMITH_CELL := Vector2i(8, 17)
## 대장 재료를 주는 구역 (Config.HUNT_ZONES 번호) = 대장간 터를 여는 구역
const FORGE_ZONE := 1
const BOSS_MATERIAL_NAME := "사금 덩이"
## 복구에 드는 것. 복구 속도는 사금 덩이(대장을 잡을 때마다 1개)가 정한다 (봇: 터 → 복구 열흘 남짓).
## 돈으로 막으면 훈련을 못 사는 날이 생겨서 돈은 무 한 번 판 값쯤으로 둔다.
## 후보 목업에 있던 슬라임 젤리 10개는 뺐다: 젤리는 처치당 약 4%라 열흘에 두세 개밖에 안 모인다.
const FORGE_COST_MONEY := 2000
const FORGE_COST_CROPS := 40
const FORGE_COST_MATERIAL := 12
## 고물 캐기 (2026-10-03 백로그 3 "고철이 하루 6개 그냥 생기는 게 별로 → 남는 크리처로 고철"): 고물 더미는 저절로 차지 않는다.
## 대장간 일꾼 한 마리가 하루 SCRAP_DIG_PER_DAY x 고물 캐기 재능 (땅 1.5) x 속도 훈련 개를 캐 대장간에 둔다 (반올림, 최소 1).
## 일꾼 셋이면 하루 약 3~9개 (예전 저절로 6개쯤). 처음 값 2 는 봇에서 150일 동안 2천 개 넘게 쌓여서 1 로 (2026-10-03).
const SCRAP_DIG_PER_DAY := 1
## 제작 (대장장이 모루 F). 기본 장비마다 고철 · 돈. 옵션 수는 무게로 굴린다 {개수: 무게}.
const CRAFT_COSTS := {
	&"work_cap": [3, 200], &"rain_suit": [5, 300], &"work_boots": [4, 250],
	&"hard_hat": [4, 250], &"hiking_vest": [5, 300], &"safety_shoes": [4, 250],
	# 무기 (2026-09-29): 판타지풍도 괜찮다는 사용자 말에 따라 대장간도 검 · 쇠뇌를 만든다. 지팡이는 대장간 몫이 아님 (드롭만).
	&"steel_sword": [5, 300], &"crossbow": [6, 350],
}
const CRAFT_AFFIX_WEIGHTS := {1: 50, 2: 35, 3: 15}

## 약방 복구 · 연금술사 (2026-09-29 사용자 선택: 대장간처럼 한 번에 복구 + 연금술사 A+B "물약 · 크리처 보약"). 본편 둘째 시설. 값·자리·그림 전부 임시.
## 2막 대장(도마리 장승 한 쌍)을 처음 쓰러뜨린 다음 날 아침, 아랫길 가운데 풀밭에 무너진 약방 터가 드러난다.
## 터가 드러난 뒤로 땅 크리처가 캔 도라지는 공급함에 팔지 않고 약방에 모아 둔다 (GameState.roots).
## 터에서 F → 돈 · 도라지 · 2막 대장 재료 장승 조각을 다 모았으면 한 번에 고친다.
## 고치면 연금술사(마을 사람)가 오고, 호롱을 만들어 줘서 도마리 윗길 너머 캄캄한 번천으로 갈 수 있다.
## 약방 옆에 도라지밭이 생겨 크리처에게 도라지밭 가꾸기를 맡길 수 있다 (불속성이 두 배 빠름).
## 2막 대장 재료를 주는 구역 (Config.HUNT_ZONES 번호) = 약방 터를 여는 구역 = 번천 길이 캄캄한 구역
const YAK_ZONE := 3
const BOSS_MATERIAL2_NAME := "장승 조각"
const YAK_RECT := Rect2i(19, 17, 3, 2)
const HERB_BED_RECT := Rect2i(22, 18, 1, 1)
## 연금술사가 처음 서는 칸 (약방 왼쪽 앞, 한 칸 띄움. 약방 배지 · 이름표와 안 겹치게)
const ALCHEMIST_CELL := Vector2i(17, 18)
## 복구에 드는 것 (로드맵: 약방 ≈ 4.5시간 ≈ 45일째). 장승 조각(장승 한 쌍을 잡을 때마다 1개)이 속도를 정한다.
const YAK_COST_MONEY := 4000
const YAK_COST_ROOTS := 20
const YAK_COST_MATERIAL := 20
## 약방을 고친 뒤 공급함에서 잡템을 팔 때 연금술사 재료로 남기는 수
const JUNK_KEEP := 10
## 도라지밭: 아침마다 이만큼 돋는다 (안 캔 것은 새로 채움). 농부가 F로 하나씩 캐도 된다.
const HERB_BED_PER_DAY := 6
## 연금술사 제작 (약방에서 연금술사 F). 재료: herbs 들나물 (농부가 든 것) · roots 도라지 · junk 잡템 · crops 무.
## 만드는 것: potion 빨간 물약 · lamp_oil 호롱 기름 (밤 구역 불빛 x LAMP_OIL_MULT) · strength 힘 물약 (다음 사냥 한 번 공격 피해 +1)
## · speed 빠르기 물약 (다음 사냥 한 번 걸음 x SPEED_POTION_MULT) · tonic 크리처 보약 (먹인 날 모든 크리처 일 속도 x TONIC_SPEED_MULT)
const BREWS := {
	&"potion": {name = "빨간 물약", count = 2, cost = {herbs = 2, junk = 1}, effect = "체력 +30 (1 키), 두 병"},
	&"lamp_oil": {name = "호롱 기름", count = 1, cost = {roots = 2}, effect = "밤 구역 호롱 불빛이 넓어짐 (들어갈 때 하나)"},
	&"strength": {name = "힘 물약", count = 1, cost = {roots = 3, junk = 1}, effect = "다음 사냥 한 번 공격 피해 +1"},
	&"speed": {name = "빠르기 물약", count = 1, cost = {herbs = 2, junk = 1}, effect = "다음 사냥 한 번 걸음 +25%"},
	&"tonic": {name = "크리처 보약", count = 1, cost = {crops = 5, roots = 2}, effect = "먹인 날 모든 크리처 일 속도 x2"},
}
const SPEED_POTION_MULT := 1.25
const TONIC_SPEED_MULT := 2.0

## 축사 복구 · 목축인 (2026-09-30 사용자 선택 A 닭장). 본편 셋째 시설. 값·자리·그림 전부 임시.
## 3막 대장(밀목)을 처음 쓰러뜨린 다음 날 아침, 부화기 오른쪽 큰길 위 풀밭에 무너진 축사 터가 드러난다.
## 터에서 F → 돈 · 무 · 3막 대장 재료를 다 모았으면 한 번에 고친다 (대장간 · 약방처럼, Claude 기본값).
## 고치면 목축인(마을 사람)이 오고 닭장에 수탉 · 암탉 한 쌍이 들어온다.
## 규칙 (사용자): 가축은 짝이 있으면 새끼를 낳는다. 크리처 알은 지금처럼 사냥터에서만 나온다 (가축은 크리처가 아니라 마을 동물).
## 3막 대장 재료를 주는 구역 (Config.HUNT_ZONES 번호) = 축사 터를 여는 구역
const BARN_ZONE := 5
const BOSS_MATERIAL3_NAME := "산군 발톱"
const BARN_RECT := Rect2i(24, 3, 4, 2)
## 목축인이 처음 서는 칸 (축사 왼쪽 아래)
const RANCHER_CELL := Vector2i(23, 5)
## 복구에 드는 것 (로드맵: 축사 ≈ 7시간 ≈ 70일째). 3막 대장 재료(대장을 잡을 때마다 1개)가 속도를 정한다.
const BARN_COST_MONEY := 6000
const BARN_COST_CROPS := 60
const BARN_COST_MATERIAL := 20
## 닭장: 암탉은 아침마다 둥지에 달걀 하나 (전날 모이를 먹었으면 반드시, 안 먹었으면 HEN_HUNGRY_LAY 확률).
## 둥지에 하룻밤 남긴 달걀은 CHICK_HATCH_CHANCE 로 병아리가 된다 (수탉이 있으니까). 병아리는 CHICK_GROW_DAYS 뒤 암탉.
## 닭장에는 암탉 + 병아리가 HEN_CAP 마리까지. 꺼낸 달걀은 공급함에 진열해 팔거나 목축인이 도시락을 싼다.
const START_HENS := 1
const HEN_CAP := 8
const HEN_HUNGRY_LAY := 0.5
const CHICK_HATCH_CHANCE := 0.5
const CHICK_GROW_DAYS := 3
const HEN_EGG_PRICE := 25
## 족제비: 모이 주기를 맡은 아기 호랑이(축사 지킴이)가 없으면 밤마다 이 확률로 와서 둥지 달걀 절반 (없으면 병아리 하나)을 물어 간다
const WEASEL_CHANCE := 0.3
## 모이 주기: 닭장에서 F로 한 번에 다 먹이면 무 FEED_CROP_COST 개. 크리처에게 모이 주기(R)를 맡기면 무 없이 한 마리씩 먹인다.
const FEED_CROP_COST := 1
## 목축인 제작 (닭장에서 목축인 F): 사냥 도시락 = 다음 사냥 한 번 최대 체력 +LUNCH_HP (늘어난 만큼 참)
const LUNCH_EGGS := 2
const LUNCH_CROPS := 1
const LUNCH_HP := 20

## 팔당호 물가 (2026-10-02 나루터): 마을 오른쪽 아래 구석은 처음부터 물이다 (분원리는 팔당호 옆 마을). 줄 번호: 그 줄에서 물이 시작하는 칸.
## 물 칸은 아무도 못 들어가고 들나물도 안 돋는다. 그림 assets/props/lake.png (칸 31~39 · 16~23, tools/make_naru_sheets.py).
const LAKE_ORIGIN := Vector2i(31, 16)
const LAKE_ROWS := {16: 39, 17: 38, 18: 37, 19: 36, 20: 35, 21: 34, 22: 33, 23: 33}

## 나루터 복구 · 뱃사공 (2026-10-02 시설 4, 사용자 선택 A 나루터 + 낚시 B 통발). 본편 넷째 시설. 값·자리·그림 전부 임시.
## 4막 대장(곤지암 마왕)을 처음 쓰러뜨린 다음 날 아침, 팔당호 물가에 무너진 나루터 터가 드러난다.
## 터에서 F → 돈 · 무 · 4막 대장 재료를 다 모았으면 한 번에 고친다 (대장간 · 약방 · 축사처럼).
## 고치면 뱃사공(마을 사람)이 오고 잔교 · 나룻배가 놓인다. 나룻배는 5막 팔당호 섬 뱃길 (그때 엶).
## 통발 (사용자 선택 B): 나루터에서 F로 통발 놓기 (미끼 무 하나, TRAP_MAX 개까지) → 다음 날 아침 통발마다 물고기 0~2마리가
## 나루터 바구니에 (통발은 걷혀서 다시 놓아야 함). 바구니에서 꺼낸 물고기는 공급함에 진열해 팔거나 뱃사공이 매운탕을 끓인다.
const NARU_ZONE := 7
const BOSS_MATERIAL4_NAME := "마왕 뿔"
const NARU_RECT := Rect2i(32, 17, 3, 2)
## 뱃사공이 처음 서는 칸 (나룻집 왼쪽 아래)
const FERRYMAN_CELL := Vector2i(31, 19)
## 복구에 드는 것 (로드맵: 시설 4 ≈ 9.5시간 ≈ 95일째). 4막 대장 재료 (대장을 잡을 때마다 1개) 가 속도를 정한다.
const NARU_COST_MONEY := 12000
const NARU_COST_CROPS := 80
const NARU_COST_MATERIAL := 25
## 통발: 한 번에 놓을 수 있는 수 · 미끼 (무) · 통발 하나가 아침에 거두는 물고기 [0, 1, 2] 무게
const TRAP_MAX := 3
const TRAP_BAIT := 1
const TRAP_CATCH_WEIGHTS := [1, 2, 1]
## 통발을 놓는 물 칸 (그림 자리, 놓은 순서대로)
const TRAP_CELLS: Array[Vector2i] = [Vector2i(37, 19), Vector2i(36, 21), Vector2i(38, 21)]
const FISH_PRICE := 45
## 물고기 몰기 (크리처 일): 통발이 놓여 있으면 한 번 할 때마다 내일 아침 물고기 +1 (하루 FISH_DRIVE_CAP 번까지). 물속성이 두 배 빠르다.
const FISH_DRIVE_CAP := 4
## 뱃사공 매운탕 (나루터에서 뱃사공 F): 다음 사냥 한 번 최대 체력 +STEW_HP · 경험치 xSTEW_XP_MULT (들어갈 때 먹음)
const STEW_FISH := 2
const STEW_CROPS := 1
const STEW_HP := 10
const STEW_XP_MULT := 1.5

## 마을회관 · 이장 (2026-10-03 시설 5, 사용자 선택 A 마을회관 · 이장). 본편 마지막 시설. 값 · 자리 · 그림 전부 임시.
## 5막 대장 (소내섬 용, 마지막 대장) 을 처음 쓰러뜨린 다음 날 아침, 마을 아랫길 아래 풀밭에 무너진 마을회관 터가 드러난다.
## 터에서 F → 돈 · 무 · 용 비늘을 다 모았으면 한 번에 고친다. 고치면 이장 (마을 사람) 이 오고:
##  - 게시판: 아침마다 주민 부탁 하나 (HALL_REQUESTS 중 열린 시설 것). 회관에서 F 로 들어주면 돈 + 가끔 장비 (공용 창고)
##  - 확성기 아침 방송: 크리처 일이 HALL_BROADCAST_MULT 배 빠름
##  - 크리처 일 심부름: 부탁 물건을 하나씩 대신 모아 감 (하루 ERRAND_CAP 번)
##  - 이장이 잔치를 알린다 → 당산나무 앞 잔치상 (사용자 선택 B 잔치상 차리기, FEAST_*)
const HALL_ZONE := 9
const BOSS_MATERIAL5_NAME := "용 비늘"
const HALL_RECT := Rect2i(11, 20, 4, 2)
## 이장이 처음 서는 칸 (회관 오른쪽 아래)
const CHIEF_CELL := Vector2i(15, 22)
## 복구에 드는 것. 용 비늘은 5개만 (2026-10-03 사용자: "의미없이 보스를 10번잡아야 다음 시설로 넘어가는 부분 재미없음" →
## 대장 재료 반복 사냥은 다음 주제에서 새로 정함. 그 전까지 회관만이라도 대장 반복을 짧게)
const HALL_COST_MONEY := 15000
const HALL_COST_CROPS := 100
## 용 비늘: 대장만 주던 때는 5, 일반 와이번도 주게 되어 12 (2026-10-03 시설 복구 바꿈)
const HALL_COST_MATERIAL := 12
## 시설 복구: 재료 모으기 → 크리처 공사 (2026-10-03 백로그 4번 "의미 없이 보스를 10번 잡아야 다음 시설로 넘어가는 게 재미없음").
## 사용자 (2026-10-03): "자재를 얻는 수단이 보스뿐 아니고 일반몹한테도 나오게 하고 모든 재료를 모으면 크리쳐보고 고치도록 일을 시켜서
## 특정일자가 지나도록 하는거 어떨까" → SiteWork.
##  - 막 대장을 처음 잡으면 다음 날 터 (예전 그대로). 대장 재료는 대장 처치마다 1개 + 터가 있는 동안 그 막 두 구역 일반 몬스터가 drop 확률로 1개.
##  - 재료 · 돈 · 무 (약방은 도라지) 를 다 모으면 터에서 F → 공사 시작 (그때 낸다).
##  - 공사는 R 로 "터 공사" 를 맡긴 크리처가 한다. 하루 BUILD_CAP 번까지라 days 일이 걸린다 (맡긴 크리처가 없으면 안 늚). 땅속성이 빠르다.
##  - 공사가 다 된 다음 날 아침 시설이 서고 주인이 온다. 값은 전부 임시 (봇 기준 예전과 비슷한 날수).
const BUILD_CAP := 5
const SITE_TASKS := {
	&"forge": {zones = [0, 1], material = "material", need = FORGE_COST_MATERIAL, drop = 0.04, days = 7},
	&"yak": {zones = [2, 3], material = "material2", need = YAK_COST_MATERIAL, drop = 0.025, days = 10},
	&"barn": {zones = [4, 5], material = "material3", need = BARN_COST_MATERIAL, drop = 0.03, days = 10},
	&"naru": {zones = [6, 7], material = "material4", need = NARU_COST_MATERIAL, drop = 0.025, days = 14},
	&"hall": {zones = [8, 9], material = "material5", need = HALL_COST_MATERIAL, drop = 0.03, days = 7},
}

## 게시판 부탁: id → [이름, 개수, 한 개 값 (보상 계산), 필요한 시설 (&"" = 처음부터)]. 보상 = 개수 x 값 x HALL_REWARD_MULT
const HALL_REQUESTS := {
	&"crops": ["무", 20, CROP_PRICE, &""],
	&"herbs": ["들나물", 8, HERB_PRICE, &""],
	&"junk": ["사냥 잡템", 10, JUNK_PRICE, &""],
	&"scrap": ["고철", 10, 20, &"forge"],
	&"roots": [ROOT_NAME, 8, ROOT_PRICE, &"yak"],
	&"hen_eggs": ["달걀", 6, HEN_EGG_PRICE, &"barn"],
	&"fish": ["물고기", 4, FISH_PRICE, &"naru"],
}
const HALL_REWARD_MULT := 2.5
## 부탁을 들어주면 이 확률로 장비 하나 (소내섬 등급, 공용 창고)
const HALL_GEAR_CHANCE := 0.25
const HALL_BROADCAST_MULT := 1.2
const ERRAND_CAP := 4

## 잔치 (2026-10-03 엔딩, 사용자 선택 B 잔치상 차리기). 마을회관을 고치면 이장이 잔치를 알리고 당산나무 앞에 빈 잔치상이 놓인다.
## 마을 사람마다 한 상씩: 주인공이 그 사람 몫 재료를 가져와 잔치상에서 F 하면 그 사람이 차린다 (2026-10-03 주인공 하나). 다 차리면 잔치 열기 → 잔치 장면 + 크레딧 → 다음 날 평소대로.
## 상: [id, 차리는 사람, 이름, {GameState 변수: 개수}] (그림 assets/props/feast_dishes.png 순서)
const FEAST_RECT := Rect2i(25, 17, 3, 1)
const FEAST_DISHES: Array = [
	## 농부 상은 무만 (2026-10-03 봇: 늦게는 채집 크리처가 들나물을 다 캐서 농부 손에 나물이 안 모인다)
	[&"greens", &"farmer", "무생채 · 뭇국", {crops = 40}],
	[&"skewer", &"hunter", "사냥꾼 꼬치", {junk = 15}],
	[&"cauldron", &"smith", "가마솥", {scrap = 20}],
	[&"wine", &"alchemist", "약주", {roots = 10}],
	[&"eggs", &"rancher", "달걀찜", {hen_eggs = 12}],
	[&"stew_pot", &"ferryman", "매운탕 큰 솥", {fish = 8}],
	[&"rice_cake", &"chief", "떡 · 막걸리", {money = 3000}],
]
## 잔치 장면: 제목만 보이는 시간 · 크레딧이 올라가는 시간 (초)
const FEAST_TITLE_TIME := 4.0
const FEAST_CREDITS_TIME := 16.0
## 잔치 장면의 시각 (게임 분, 저녁 8시)
const FEAST_MINUTE := 20 * 60

## 크리처 원정 + 입양 (2026-10-01 사용자 선택 B + D, Expedition). 값은 전부 임시.
## 원정대 크기 (쉬는 · 채집 크리처 중 잘 맞는 크리처부터)
const EXPEDITION_TEAM_MIN := 3
const EXPEDITION_TEAM_MAX := 5
## 잘 맞음: 그 구역 알에서 나온 종 (고향) x1.5, 속성이 맞으면 x1.25. 팀 힘 = 합 / 5 가 돈 · 재료 · 장비 확률에 곱해진다.
const EXPEDITION_HOME_MULT := 1.5
const EXPEDITION_ELEMENT_MULT := 1.25
## 구역마다 (Config.HUNT_ZONES 번호 순): 5마리 보통 팀이 하룻밤에 가져오는 돈 = 봇 run1~3 의 그 구역 사냥 한 번 돈 평균의 약 1/3
## (분원농협 38 · 금사리 67 · 광동리 230 · 도마리 280 · 번천 약 300 · 밀목 227원, design/act3/runs). 알은 안 가져온다.
const EXPEDITION_ZONES: Array[Dictionary] = [
	{money = [8, 18], elements = [&"water"], species = [&"slime"], hint = "물 · 슬라임"},
	{money = [15, 30], elements = [&"earth"], species = [&"gold_toad"], hint = "땅 · 아기 금두꺼비"},
	{money = [55, 100], elements = [&"flying"], species = [&"sparrow"], hint = "비행 · 아기 까마귀"},
	{money = [70, 120], elements = [&"earth"], species = [&"tree_spirit"], hint = "땅 · 아기 나무 정령"},
	{money = [75, 125], elements = [&"fire"], species = [&"will_o"], hint = "불 · 아기 도깨비불"},
	{money = [55, 100], elements = [&"spirit"], species = [&"tiger", &"white_tiger"], hint = "신령 · 아기 호랑이"},
	{money = [60, 110], elements = [&"earth"], species = [&"foal"], hint = "땅 · 아기 망아지"},
	{money = [70, 125], elements = [&"fire"], species = [&"imp"], hint = "불 · 아기 악귀"},
	{money = [75, 135], elements = [&"earth"], species = [&"lizard"], hint = "땅 · 아기 도마뱀"},
	{money = [85, 150], elements = [&"flying"], species = [&"wyvern", &"blue_dragon", &"cloud_dragon", &"gold_dragon"], hint = "비행 · 아기 와이번 · 아기 용"},
]
## 원정대 하나가 하룻밤에 가져오는 잡템 (그 구역 잡템, 공급함에서 사냥꾼 잡템처럼 판다)
const EXPEDITION_JUNK := [1, 2]
## 대장 재료 (막 대장 구역만) · 장비 (그 구역 등급 무게, 공용 창고로) 확률, 팀 힘을 곱한다
const EXPEDITION_MATERIAL_CHANCE := 0.1
const EXPEDITION_GEAR_CHANCE := 0.06
## 입양: 시설을 고친 주민마다 받아 주는 수 · 보답 (한 번) · 지내는 칸
const ADOPT_CAP := 4
const ADOPT_GIFTS := {
	&"smith": {name = "대장장이", text = "고철 5개", count = 5},
	&"alchemist": {name = "연금술사", text = "빨간 물약 2병", count = 2},
	&"rancher": {name = "목축인", text = "사냥 도시락 1개", count = 1},
	&"ferryman": {name = "뱃사공", text = "물고기 4마리", count = 4},
	&"chief": {name = "이장", text = "2000원", count = 2000},
}
const ADOPT_SPOTS := {
	&"smith": [Vector2i(3, 17), Vector2i(2, 17), Vector2i(3, 18), Vector2i(2, 18)],
	&"alchemist": [Vector2i(18, 19), Vector2i(17, 19), Vector2i(16, 18), Vector2i(16, 19)],
	&"rancher": [Vector2i(21, 6), Vector2i(22, 6), Vector2i(21, 5), Vector2i(21, 7)],
	&"ferryman": [Vector2i(30, 19), Vector2i(30, 20), Vector2i(31, 20), Vector2i(29, 20)],
	&"chief": [Vector2i(16, 22), Vector2i(16, 21), Vector2i(10, 22), Vector2i(17, 22)]}

## 크리처 시설 배치 (2026-10-03 사용자 구조 결정 "시설 일은 크리처를 배치해서 돌린다", FacilityWorkers): 시설마다 일꾼 자리 (멍석) 3칸.
## 크리처를 들고 이 근처에서 내려놓으면 빈 자리에 앉아 그 시설 일꾼이 된다. 자리 · 수는 임시.
const WORKER_SLOTS := {
	&"forge": [Vector2i(11, 18), Vector2i(12, 18), Vector2i(13, 18)],
	&"yak": [Vector2i(22, 20), Vector2i(23, 20), Vector2i(24, 20)],
	&"barn": [Vector2i(25, 6), Vector2i(26, 6), Vector2i(27, 6)],
	&"naru": [Vector2i(32, 20), Vector2i(33, 20), Vector2i(34, 20)],
	&"hall": [Vector2i(11, 22), Vector2i(12, 22), Vector2i(13, 22)],
}

## 농사가 아닌 크리처 (채집 · 고철 · 도라지밭 · 모이) 의 일 이름표는 조작 중인 캐릭터가 이 거리 (px) 안일 때만 보인다
const CREATURE_TAG_DISTANCE := 56.0
