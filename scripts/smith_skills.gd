class_name SmithSkills
extends RefCounted
## 대장장이 레벨 · 기술 (2026-10-03 백로그 10, 후보 문서 design/smith-level-options.md). 농사 레벨 (FarmSkills) 과 같은 "직업 레벨" 틀:
## 경험치 → 레벨 → 포인트 → 트리에서 고르기. T 창 "대장" 탭 (대장간을 고친 뒤).
## 경험치는 대장장이가 장비를 만들 때 (단계마다) · 갈 때 (등급마다). 대장 Lv 이 오르면 단계 장비 (Config.SMITH_TIERS) 가 열린다.
## 상태는 GameState (smith_level · smith_xp · smith_points · smith_skills) 라 저장 파일에 이름으로 담긴다.

const TREES: Array[Dictionary] = [
	{id = &"temper", name = "담금질", color = Color(0.85, 0.45, 0.3), skills = [
		{id = &"good_steel", name = "좋은 쇠", req = 1, max = 3, desc = "만든 장비의 옵션 값이 커진다", per = "옵션 값 +10%"},
		{id = &"extra_hit", name = "한 번 더", req = 4, max = 3, desc = "만들 때 옵션이 하나 더 붙기도 한다", per = "확률 +15%"},
		{id = &"sharpen", name = "날 세우기", req = 8, max = 3, desc = "새로 만드는 무기의 피해가 커진다", per = "피해 +4%"},
		{id = &"master", name = "명장", req = 12, max = 3, desc = "새로 만드는 장비의 바탕 힘 (단계 힘) 이 커진다", per = "바탕 힘 +15%"},
	]},
	{id = &"thrift", name = "아끼기", color = Color(0.6, 0.6, 0.65), skills = [
		{id = &"save_scrap", name = "고철 아끼기", req = 1, max = 3, desc = "만들 때 고철이 덜 든다", per = "고철 -10%"},
		{id = &"salvage_hand", name = "갈기 솜씨", req = 4, max = 3, desc = "장비를 갈 때 고철이 하나 더 나오기도 한다", per = "확률 +30%"},
		{id = &"save_mat", name = "재료 아끼기", req = 8, max = 3, desc = "만들 때 대장 재료를 하나 덜 쓰기도 한다", per = "확률 +20%"},
		{id = &"regular", name = "단골 값", req = 12, max = 3, desc = "만들 때 돈이 덜 든다", per = "돈 -15%"},
	]},
	{id = &"crew", name = "일꾼", color = Color(0.55, 0.45, 0.75), skills = [
		{id = &"dig", name = "고물 캐기", req = 1, max = 3, desc = "대장간 일꾼 크리처가 고철을 더 캔다", per = "캐는 고철 +25%"},
		{id = &"forge_fire", name = "가마 불", req = 4, max = 3, desc = "대장 경험치를 더 받는다", per = "경험치 +20%"},
		{id = &"mat_find", name = "재료 찾기", req = 8, max = 3, desc = "사냥에서 대장 재료가 더 잘 나온다", per = "확률 +25%"},
		{id = &"iron_collar", name = "쇠 목걸이", req = 12, max = 3, desc = "동행 크리처의 피해가 커진다", per = "피해 +6%"},
	]},
]


static func level() -> int:
	return GameState.smith_level


static func points() -> int:
	return GameState.smith_points


static func xp_to_next(lv: int) -> int:
	return roundi(Config.SMITH_XP_BASE * pow(lv, Config.SMITH_XP_EXP))


## 경험치를 더한다 (가마 불 배율). 오른 레벨 수를 돌려준다 (레벨업이면 알림까지 한다).
static func gain(amount: int) -> int:
	amount = roundi(amount * (1.0 + Config.SMITH_XP_STEP * rank(&"forge_fire")))
	if amount <= 0 or GameState.smith_level >= Config.SMITH_LEVEL_CAP:
		return 0
	GameState.smith_xp += amount
	var ups := 0
	while GameState.smith_level < Config.SMITH_LEVEL_CAP and GameState.smith_xp >= xp_to_next(GameState.smith_level):
		GameState.smith_xp -= xp_to_next(GameState.smith_level)
		GameState.smith_level += 1
		GameState.smith_points += 1
		ups += 1
	if GameState.smith_level >= Config.SMITH_LEVEL_CAP:
		GameState.smith_xp = 0
	if ups > 0:
		Sound.sfx(&"hatch", 0.0, 1.2)
		var text := "대장장이 레벨 %d! 대장 포인트 +%d (T 창 \"대장\" 탭)." % [GameState.smith_level, ups]
		var t := tier_opened_at(GameState.smith_level)
		if t > 0:
			text += " 이제 %d단계 %s 장비를 만들 수 있다." % [t + 1, Config.SMITH_TIERS[t].name]
		GameState.notify(text)
	GameState.touch()
	return ups


## 그 레벨에 막 열린 단계 (0 기준 번호, 없으면 -1). 1단계 (0) 는 처음부터라 -1.
static func tier_opened_at(lv: int) -> int:
	for t in range(1, Config.SMITH_TIERS.size()):
		if Config.SMITH_TIERS[t].req == lv:
			return t
	return -1


static func progress() -> float:
	if GameState.smith_level >= Config.SMITH_LEVEL_CAP:
		return 1.0
	return clampf(float(GameState.smith_xp) / xp_to_next(GameState.smith_level), 0.0, 1.0)


static func rank(id: StringName) -> int:
	return GameState.smith_skills.get(id, 0)


static func find(id: StringName) -> Dictionary:
	for t in TREES:
		for i in t.skills.size():
			if t.skills[i].id == id:
				return {tree = t, index = i, skill = t.skills[i]}
	return {}


static func why_not(id: StringName) -> String:
	var f := find(id)
	if f.is_empty():
		return "없는 기술"
	var s: Dictionary = f.skill
	if rank(id) >= s.max:
		return "다 찍음"
	if GameState.smith_level < s.req:
		return "대장 Lv %d 부터" % s.req
	if f.index > 0 and rank(f.tree.skills[f.index - 1].id) < 1:
		return "%s 먼저" % f.tree.skills[f.index - 1].name
	if GameState.smith_points <= 0:
		return "대장 포인트 없음"
	return ""


static func learn(id: StringName) -> bool:
	if why_not(id) != "":
		return false
	GameState.smith_skills[id] = rank(id) + 1
	GameState.smith_points -= 1
	GameState.touch()
	return true


# --- 단계 장비 ------------------------------------------------------------------

## 지금 만들 수 있는 가장 높은 단계 (0 기준)
static func top_tier() -> int:
	var top := 0
	for t in Config.SMITH_TIERS.size():
		if GameState.smith_level >= Config.SMITH_TIERS[t].req:
			top = t
	return top


## base 를 tier 단계로 만드는 데 드는 것 (기술 반영): {scrap, money, material (GameState 변수, "" = 없음), mat_count}
static func cost(base: StringName, tier: int) -> Dictionary:
	var c: Array = Config.CRAFT_COSTS[base]
	var td: Dictionary = Config.SMITH_TIERS[tier]
	var scrap: int = c[0] if tier == 0 else c[0] + td.scrap
	var money: int = c[1] if tier == 0 else td.money
	scrap = maxi(1, ceili(scrap * (1.0 - Config.SMITH_SCRAP_SAVE_STEP * rank(&"save_scrap"))))
	money = roundi(money * (1.0 - Config.SMITH_PRICE_STEP * rank(&"regular")))
	return {scrap = scrap, money = money, material = td.material, mat_count = td.mat_count}


## 대장 재료 이름 (GameState 변수 → 이름)
static func material_name(key: String) -> String:
	return {"material": Config.BOSS_MATERIAL_NAME, "material2": Config.BOSS_MATERIAL2_NAME, "material3": Config.BOSS_MATERIAL3_NAME,
		"material4": Config.BOSS_MATERIAL4_NAME, "material5": Config.BOSS_MATERIAL5_NAME}.get(key, "")


## 대장 재료 순서 (막 순서). 모자라면 더 뒤 막 재료로 대신한다 (2026-10-03 Claude 기본: 지나간 막 사냥터로 돌아가지 않아도 단계를 올리게).
## 아직 안 연 시설의 재료는 시설 복구 몫이라 대장간에서 쓰지 않는다.
const MATERIAL_KEYS: Array[String] = ["material", "material2", "material3", "material4", "material5"]
const MATERIAL_FACILITY := {"material": &"forge", "material2": &"yak", "material3": &"barn", "material4": &"naru", "material5": &"hall"}


## 대장간에서 쓸 수 있는 재료들 (key 부터 뒤 막까지, 시설을 연 것만)
static func usable_keys(key: String) -> Array[String]:
	var out: Array[String] = []
	for k in MATERIAL_KEYS.slice(MATERIAL_KEYS.find(key)):
		if SiteWork.state(MATERIAL_FACILITY[k]) == 2:
			out.append(k)
	return out


## tier 단계에 쓸 수 있는 대장 재료 수 (그 재료 + 뒤 막 재료, 연 시설 것만)
static func mat_have(key: String) -> int:
	if key == "":
		return 0
	var n := 0
	for k in usable_keys(key):
		n += int(GameState.get(k))
	return n


## 대장 재료 count 개를 쓴다: 그 재료부터, 모자라면 뒤 막 재료 순서로
static func spend_mat(key: String, count: int) -> void:
	for k in usable_keys(key):
		var take := mini(count, int(GameState.get(k)))
		GameState.set(k, int(GameState.get(k)) - take)
		count -= take
		if count <= 0:
			return


## 옵션 값 배율 (단계 x 좋은 쇠)
static func affix_mult(tier: int) -> float:
	return Config.SMITH_TIERS[tier].affix * (1.0 + Config.SMITH_AFFIX_STEP * rank(&"good_steel"))


## 바탕 힘 배율 (명장)
static func base_mult() -> float:
	return 1.0 + Config.SMITH_MASTER_STEP * rank(&"master")


static func extra_affix_chance() -> float:
	return Config.SMITH_EXTRA_AFFIX_STEP * rank(&"extra_hit")


static func save_mat_chance() -> float:
	return Config.SMITH_MAT_SAVE_STEP * rank(&"save_mat")


static func salvage_extra_chance() -> float:
	return Config.SMITH_SALVAGE_STEP * rank(&"salvage_hand")


static func dig_mult() -> float:
	return 1.0 + Config.SMITH_DIG_STEP * rank(&"dig")


static func find_mult() -> float:
	return 1.0 + Config.SMITH_FIND_STEP * rank(&"mat_find")


static func collar_mult() -> float:
	return 1.0 + Config.SMITH_COLLAR_STEP * rank(&"iron_collar")


## 만들 때 굳히는 바탕 힘 (단계 x 명장, 무기는 날 세우기 더함). 만든 뒤 기술을 찍어도 이미 만든 장비는 그대로.
static func roll_power(base: StringName, tier: int) -> Dictionary:
	var td: Dictionary = Config.SMITH_TIERS[tier]
	var it: Dictionary = Wearables.ITEMS[base]
	var m := base_mult()
	if it.slot == &"weapon":
		var dmg := snappedf(td.dmg * m + Config.SMITH_SHARPEN_STEP * rank(&"sharpen"), 0.01)
		return {dmg = dmg} if dmg > 0.0 else {}
	if it.who == &"farmer":
		return {walk = snappedf(td.walk * m, 0.01)} if td.walk > 0.0 else {}
	return {hp = roundi(td.hp * Config.HP_PER_HEART * m)} if td.hp > 0 else {}
