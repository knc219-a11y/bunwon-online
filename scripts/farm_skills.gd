class_name FarmSkills
extends RefCounted
## 농사 레벨 · 기술 (2026-10-03 백로그 9, 후보 문서 design/farm-level-options.md). 사냥꾼 레벨 (HunterSkills) 과 같은 "직업 레벨" 틀:
## 경험치 → 레벨 → 포인트 → 트리에서 고르기. T 창 "농사" 탭.
## 경험치는 밭에서 거둔 작물마다 ★ 만큼 (주인공 · 크리처 모두, 2026-10-03 사용자 선택 "거둔 작물 모두"). 값은 Config.FARM_*.
## 상태는 GameState (farm_level · farm_xp · farm_points · farm_skills) 라 저장 파일에 이름으로 담긴다.

## 갈래마다 위에서 아래로 Lv 1 · 4 · 8 · 12 에 열리고, 바로 위 기술을 1 이상 찍어야 다음을 찍는다. 기술마다 최대 3단계. 값은 전부 임시.
const TREES: Array[Dictionary] = [
	{id = &"tools", name = "손일", color = Color(0.45, 0.6, 0.85), skills = [
		{id = &"wide_can", name = "큰 물뿌리개", req = 1, max = 3, desc = "물 주는 칸이 넓어진다", per = "3줄 → 앞으로 +2칸 → 5줄"},
		{id = &"wide_hoe", name = "큰 괭이", req = 4, max = 3, desc = "갈기 · 심기 · 거두기도 넓게 한다", per = "3줄 → 앞으로 +2칸 → 5줄"},
		{id = &"quick_step", name = "날랜 걸음", req = 8, max = 3, desc = "마을에서 더 빨리 걷는다", per = "걷기 +8%"},
		{id = &"dawn_dew", name = "새벽 이슬", req = 12, max = 3, desc = "아침마다 심은 칸 몇 곳에 물이 들어 있다", per = "20% → 35% → 50%"},
	]},
	{id = &"care", name = "돌봄", color = Color(0.5, 0.72, 0.35), skills = [
		{id = &"compost_hand", name = "퇴비 솜씨", req = 1, max = 3, desc = "퇴비를 만들 때 하나 더 나오기도 한다", per = "확률 +25%"},
		{id = &"hand_touch", name = "손맛", req = 4, max = 3, desc = "주인공이 손으로 거둔 작물이 ★ 한 단계 더 오르기도 한다", per = "확률 +15%"},
		{id = &"bounty", name = "풍년", req = 8, max = 3, desc = "거둘 때 작물이 하나 더 나오기도 한다 (크리처 밭도)", per = "확률 +15%"},
		{id = &"food_hand", name = "손맛 음식", req = 12, max = 3, desc = "사냥 음식 효과가 세진다", per = "효과 +20%"},
	]},
	{id = &"together", name = "함께 짓기", color = Color(0.85, 0.6, 0.35), skills = [
		{id = &"kind_hand", name = "다정한 손", req = 1, max = 3, desc = "크리처가 경험치를 더 받는다", per = "경험치 +20%"},
		{id = &"buddy_farm", name = "짝꿍 농사", req = 4, max = 3, desc = "속성 맞는 크리처가 돌본 작물이 ★ 더 잘 오른다", per = "30%에서 +15%"},
		{id = &"field_snack", name = "새참", req = 8, max = 3, desc = "모든 크리처가 더 빨리 일한다", per = "일 속도 +5%"},
		{id = &"warm_egg", name = "알 품기", req = 12, max = 3, desc = "갓 태어난 크리처가 높은 레벨로 시작한다", per = "Lv 2 → 3 → 4 로 태어남"},
	]},
]


## Lv 에서 다음 레벨까지 필요한 경험치
static func xp_to_next(level: int) -> int:
	return roundi(Config.FARM_XP_BASE * pow(level, Config.FARM_XP_EXP))


## 거두기 경험치 (★ 등급마다)
static func gain_harvest(grade: int) -> int:
	return gain(Config.FARM_XP_HARVEST[clampi(grade, 1, 3) - 1])


## 경험치를 더한다. 오른 레벨 수를 돌려준다 (레벨업이면 알림까지 한다).
static func gain(amount: int) -> int:
	if amount <= 0 or GameState.farm_level >= Config.FARM_LEVEL_CAP:
		return 0
	GameState.farm_xp += amount
	var ups := 0
	while GameState.farm_level < Config.FARM_LEVEL_CAP and GameState.farm_xp >= xp_to_next(GameState.farm_level):
		GameState.farm_xp -= xp_to_next(GameState.farm_level)
		GameState.farm_level += 1
		GameState.farm_points += 1
		ups += 1
	if GameState.farm_level >= Config.FARM_LEVEL_CAP:
		GameState.farm_xp = 0
	if ups > 0:
		Sound.sfx(&"hatch", 0.0, 1.5)
		GameState.notify("농사 레벨 %d! 농사 포인트 +%d (T 창 \"농사\" 탭에서 찍는다)." % [GameState.farm_level, ups])
	GameState.touch()
	return ups


## 지금 레벨 안에서 모은 비율 (0..1)
static func progress() -> float:
	if GameState.farm_level >= Config.FARM_LEVEL_CAP:
		return 1.0
	return clampf(float(GameState.farm_xp) / xp_to_next(GameState.farm_level), 0.0, 1.0)


static func rank(id: StringName) -> int:
	return GameState.farm_skills.get(id, 0)


## {tree, index, skill} 를 찾는다
static func find(id: StringName) -> Dictionary:
	for t in TREES:
		for i in t.skills.size():
			if t.skills[i].id == id:
				return {tree = t, index = i, skill = t.skills[i]}
	return {}


## 찍을 수 없는 까닭 ("" = 찍을 수 있음)
static func why_not(id: StringName) -> String:
	var f := find(id)
	if f.is_empty():
		return "없는 기술"
	var s: Dictionary = f.skill
	if rank(id) >= s.max:
		return "다 찍음"
	if GameState.farm_level < s.req:
		return "농사 Lv %d 부터" % s.req
	if f.index > 0 and rank(f.tree.skills[f.index - 1].id) < 1:
		return "%s 먼저" % f.tree.skills[f.index - 1].name
	if GameState.farm_points <= 0:
		return "농사 포인트 없음"
	return ""


static func learn(id: StringName) -> bool:
	if why_not(id) != "":
		return false
	GameState.farm_skills[id] = rank(id) + 1
	GameState.farm_points -= 1
	GameState.touch()
	return true


# --- 기술 효과 ------------------------------------------------------------------

## 큰 물뿌리개 (물) · 큰 괭이 (갈기 · 심기 · 거두기 · 깊이 갈기): [옆으로 한쪽 줄, 앞으로 더 닿는 칸]
static func wide(work: int) -> Vector2i:
	var id := &"wide_can" if work == Farm.Work.WATER else &"wide_hoe"
	return Config.FARM_WIDE[rank(id)]


static func walk_mult() -> float:
	return 1.0 + Config.FARM_WALK_STEP * rank(&"quick_step")


static func dew_chance() -> float:
	return Config.FARM_DEW[rank(&"dawn_dew")]


static func compost_extra_chance() -> float:
	return Config.FARM_COMPOST_STEP * rank(&"compost_hand")


static func hand_star_chance() -> float:
	return Config.FARM_HAND_STAR_STEP * rank(&"hand_touch")


static func bounty_chance() -> float:
	return Config.FARM_BOUNTY_STEP * rank(&"bounty")


static func food_mult() -> float:
	return 1.0 + Config.FARM_FOOD_STEP * rank(&"food_hand")


static func creature_xp_mult() -> float:
	return 1.0 + Config.FARM_CREATURE_XP_STEP * rank(&"kind_hand")


static func match_chance() -> float:
	return Config.CROP_MATCH_CHANCE + Config.FARM_MATCH_STEP * rank(&"buddy_farm")


static func snack_mult() -> float:
	return 1.0 + Config.FARM_SNACK_STEP * rank(&"field_snack")


## 알 품기: 갓 태어난 크리처의 레벨 (1 = 기술 없음)
static func hatch_level() -> int:
	return 1 + rank(&"warm_egg")
