class_name HunterSkills
extends RefCounted
## 사냥꾼 레벨 · 스킬 (2026-10-02 사용자 선택: 디아2식 사냥꾼 레벨 + 스킬 포인트).
## 레벨은 사냥꾼만. 처치하면 경험치, 레벨업마다 스킬 포인트 1, 막 대장을 처음 잡으면 1 더.
## 상태는 GameState (hunter_level · hunter_xp · skill_points · skills · skill_left) 라 저장 파일에 이름으로 담긴다.


## Lv 에서 다음 레벨까지 필요한 경험치
static func xp_to_next(level: int) -> int:
	return roundi(Config.XP_BASE * pow(level, Config.XP_EXP))


static func monster_level(zone: int) -> int:
	var t := Config.ZONE_MONSTER_LEVEL
	return t[zone] if zone < t.size() else t[-1] + 3 * (zone - t.size() + 1)


## 디아2식 레벨 차 벌칙 배율 (구역 몬스터보다 너무 높으면 경험치가 줄어든다)
static func gap_mult(zone: int, level := -1) -> float:
	if level < 0:
		level = GameState.hunter_level
	var over := level - (monster_level(zone) + Config.XP_GAP_FREE)
	return 1.0 if over <= 0 else maxf(Config.XP_GAP_MIN, 1.0 - Config.XP_GAP_STEP * over)


## 한 마리 처치 경험치 (벌칙 전). first_boss = 이 구역 대장을 처음 잡음
static func kill_xp(zone: int, boss := false, first_boss := false) -> int:
	var base := Config.KILL_XP_BASE * pow(Config.KILL_XP_GROWTH, zone)
	var mult := 1
	if boss:
		mult = Config.BOSS_XP_MULT + (Config.FIRST_BOSS_XP_MULT if first_boss else 0)
	return roundi(base * mult)


## 막 대장 구역 (막마다 두 번째 구역: 금사리 1 · 도마리 3 · 밀목 5 ...)
static func is_act_boss_zone(zone: int) -> bool:
	return zone % 2 == 1


## 경험치를 더한다 (벌칙 적용 뒤의 값). 오른 레벨 수를 돌려준다. 레벨마다 스킬 포인트 1.
static func gain(amount: int) -> int:
	if amount <= 0 or GameState.hunter_level >= Config.LEVEL_CAP:
		return 0
	GameState.hunter_xp += amount
	var ups := 0
	while GameState.hunter_level < Config.LEVEL_CAP and GameState.hunter_xp >= xp_to_next(GameState.hunter_level):
		GameState.hunter_xp -= xp_to_next(GameState.hunter_level)
		GameState.hunter_level += 1
		GameState.skill_points += 1
		ups += 1
	if GameState.hunter_level >= Config.LEVEL_CAP:
		GameState.hunter_xp = 0
	return ups


## 지금 레벨 안에서 모은 비율 (0..1, 경험치 막대)
static func progress() -> float:
	if GameState.hunter_level >= Config.LEVEL_CAP:
		return 1.0
	return clampf(float(GameState.hunter_xp) / xp_to_next(GameState.hunter_level), 0.0, 1.0)


# --- 스킬 판 (2026-10-02 B: 무기 트리 셋 + 조련 트리) ---------------------------
## 트리마다 위에서 아래로 Lv 1 · 6 · 12 · 18 에 열리고, 바로 위 스킬을 1 이상 찍어야 다음을 찍는다.
## kind: &"mode" = 왼클릭 공격 방식 (사냥터 Q/E 로 고름) · &"passive" = 늘 · &"right" = 오른클릭 큰 스킬 · &"order" = R 키 명령
## weapon: 그 무기를 들었을 때만 듦 (&"" = 무기 상관없음). 값은 전부 임시.
const TREES: Array[Dictionary] = [
	{id = &"sword", name = "검", color = Color(0.85, 0.45, 0.35), skills = [
		{id = &"whirl", name = "회전 베기", req = 1, max = 5, kind = &"mode", weapon = &"melee",
			desc = "3타째가 한 바퀴 돌며 둘레를 모두 벤다", per = "범위 +8%"},
		{id = &"dash_slash", name = "돌진 베기", req = 6, max = 5, kind = &"passive", weapon = &"melee",
			desc = "구르기가 끝나는 자리에서 앞을 벤다", per = "범위 +6% · 3 · 5단계 피해 +1"},
		{id = &"sword_mastery", name = "검 숙련", req = 12, max = 5, kind = &"passive", weapon = &"melee",
			desc = "근거리 무기가 빨라진다", per = "공격 빠르기 +6% · 5단계 피해 +1"},
		{id = &"earth_split", name = "대지 가르기", req = 18, max = 5, kind = &"right", weapon = &"melee",
			desc = "오른클릭: 앞으로 땅이 갈라지며 줄 위 모두를 치고 잠깐 기절", per = "길이 +12 · 쿨 -0.4초"},
	]},
	{id = &"bow", name = "활", color = Color(0.4, 0.65, 0.35), skills = [
		{id = &"pierce", name = "관통 화살", req = 1, max = 5, kind = &"mode", weapon = &"bow",
			desc = "화살이 몬스터를 꿰뚫고 날아간다", per = "꿰뚫는 수 +1 (1단계 3마리)"},
		{id = &"spread", name = "부채살", req = 6, max = 5, kind = &"mode", weapon = &"bow",
			desc = "화살 여러 발을 부채꼴로 쏜다", per = "3 · 5단계 화살 +1 · 쿨 조금 짧게"},
		{id = &"volley", name = "3연사", req = 12, max = 5, kind = &"mode", weapon = &"bow",
			desc = "한 번 쏘면 화살이 잇달아 나간다", per = "3 · 5단계 화살 +1 · 쿨 조금 짧게"},
		{id = &"arrow_rain", name = "화살비", req = 18, max = 5, kind = &"right", weapon = &"bow",
			desc = "오른클릭: 가리킨 곳에 화살비가 세 번 쏟아진다", per = "범위 +4 · 쿨 -0.4초"},
	]},
	{id = &"staff", name = "지팡이", color = Color(0.4, 0.55, 0.9), skills = [
		{id = &"big_orb", name = "큰 구슬", req = 1, max = 5, kind = &"passive", weapon = &"staff",
			desc = "구슬이 더 넓게 터진다", per = "터지는 범위 +10%"},
		{id = &"chain_orb", name = "연쇄 구슬", req = 6, max = 5, kind = &"mode", weapon = &"staff",
			desc = "구슬이 터지면 작은 구슬이 사방으로 튄다", per = "작은 구슬 2개 + 2단계마다 1"},
		{id = &"element_boost", name = "속성 강화", req = 12, max = 5, kind = &"passive", weapon = &"staff",
			desc = "느려짐 · 기절 · 불붙음이 세진다", per = "효과 시간 +20% · 5단계 불이 두 번"},
		{id = &"element_storm", name = "원소 폭풍", req = 18, max = 5, kind = &"right", weapon = &"staff",
			desc = "오른클릭: 가리킨 곳에 큰 구슬이 떨어져 넓게 터진다", per = "범위 +6 · 쿨 -0.5초"},
	]},
	{id = &"tame", name = "조련", color = Color(0.85, 0.65, 0.3), skills = [
		{id = &"fight_together", name = "함께 싸우기", req = 1, max = 5, kind = &"passive", weapon = &"",
			desc = "동행 크리처가 더 자주 공격한다", per = "공격 빠르기 +10% · 5단계 피해 +1"},
		{id = &"creature_guard", name = "크리처 방패", req = 6, max = 5, kind = &"passive", weapon = &"",
			desc = "동행 크리처가 사냥꾼 대신 한 번 맞아 준다", per = "다시 막기까지 20초에서 -2.5초"},
		{id = &"charge_order", name = "돌격 명령", req = 12, max = 5, kind = &"order", weapon = &"",
			desc = "R: 동행이 마우스 가까운 몬스터에 달려가 들이받고 기절시킨다", per = "기절 +0.2초 · 쿨 -0.5초 · 3 · 5단계 피해 +1"},
		{id = &"two_together", name = "둘이 함께", req = 18, max = 1, kind = &"passive", weapon = &"",
			desc = "사냥에 동행 크리처를 둘 데려간다 (두 번째는 알아서 고름)", per = ""},
	]},
]


static func rank(id: StringName) -> int:
	return GameState.skills.get(id, 0)


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
		return "없는 스킬"
	var s: Dictionary = f.skill
	if rank(id) >= s.max:
		return "다 찍음"
	if GameState.hunter_level < s.req:
		return "Lv %d 부터" % s.req
	if f.index > 0 and rank(f.tree.skills[f.index - 1].id) < 1:
		return "%s 먼저" % f.tree.skills[f.index - 1].name
	if GameState.skill_points <= 0:
		return "스킬 포인트 없음"
	return ""


static func learn(id: StringName) -> bool:
	if why_not(id) != "":
		return false
	GameState.skills[id] = rank(id) + 1
	GameState.skill_points -= 1
	var s: Dictionary = find(id).skill
	# 처음 찍은 왼클릭 방식은 바로 건다
	if s.kind == &"mode" and rank(id) == 1:
		GameState.skill_left[s.weapon] = id
	GameState.touch()
	return true


## 이 무기 종류로 고를 수 있는 왼클릭 방식: [&"" (기본), 찍은 mode 스킬...]
static func modes_for(weapon: StringName) -> Array[StringName]:
	var out: Array[StringName] = [&""]
	for t in TREES:
		for s in t.skills:
			if s.kind == &"mode" and s.weapon == weapon and rank(s.id) > 0:
				out.append(s.id)
	return out


## 지금 왼클릭에 건 방식 (찍지 않았거나 없으면 &"")
static func left_mode(weapon: StringName) -> StringName:
	var id: StringName = GameState.skill_left.get(weapon, &"")
	return id if id in modes_for(weapon) else &""


## 왼클릭 방식을 다음 (step 1) / 앞 (-1) 것으로. 바뀐 방식을 돌려준다.
static func cycle_mode(weapon: StringName, step := 1) -> StringName:
	var m := modes_for(weapon)
	var i := m.find(left_mode(weapon))
	var next: StringName = m[(i + step + m.size()) % m.size()]
	GameState.skill_left[weapon] = next
	return next


static func skill_name(id: StringName) -> String:
	if id == &"":
		return "기본 공격"
	var f := find(id)
	return f.skill.name if not f.is_empty() else String(id)


## 이 무기의 오른클릭 스킬 id (찍었으면, 아니면 &"")
static func right_skill(weapon: StringName) -> StringName:
	for t in TREES:
		for s in t.skills:
			if s.kind == &"right" and s.weapon == weapon and rank(s.id) > 0:
				return s.id
	return &""
