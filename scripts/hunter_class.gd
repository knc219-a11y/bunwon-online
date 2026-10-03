class_name HunterClass
extends RefCounted
## 사냥꾼 직업 · 스탯 · 초기화 (2026-10-03 2단계, 사용자: "직업도 마법사 궁수 전사로 나누고 대신에 스텟이랑 스킬 초기화는
## 조금 자유롭게 가능하도록(골드소모)", "스텟도 찍는방식").
## 직업: 처음 사냥 갈 때 사냥터 입구에서 고른다. 무기는 아무거나 들 수 있지만 스킬은 자기 무기 트리 + 조련만 찍히고,
## 자기 직업 무기를 들면 피해 + Config.CLASS_WEAPON_BONUS.
## 스탯: 레벨업마다 Config.STAT_POINTS_PER_LEVEL 점, T 창 아래 줄에서 찍는다.
## 초기화 · 직업 바꾸기: 사냥터 입구 메뉴. 첫 번은 공짜, 그 뒤 Lv x Config.RESPEC_PRICE_PER_LV 원.
## 상태는 GameState (hunter_class · stats · stat_points · free_respec_used) 라 저장 파일에 이름으로 담긴다.

## id → {name, weapon (무기 종류), tree (스킬 트리 id), stat (주 스탯), gift (처음 고를 때 주는 무기, &"" 없음), desc}
const CLASSES := {
	&"warrior": {name = "전사", weapon = &"melee", tree = &"sword", stat = &"str", gift = &"",
		desc = "근거리 무기 · 검 트리"},
	&"archer": {name = "궁수", weapon = &"bow", tree = &"bow", stat = &"dex", gift = &"hunting_bow",
		desc = "활 · 활 트리"},
	&"mage": {name = "마법사", weapon = &"staff", tree = &"staff", stat = &"wis", gift = &"water_staff",
		desc = "지팡이 · 지팡이 트리"},
}
const ORDER: Array[StringName] = [&"warrior", &"archer", &"mage"]

## 스탯 (T 창 아래 줄, 트리 칸 순서 검 · 활 · 지팡이 · 조련과 같은 자리)
const STATS: Array[Dictionary] = [
	{id = &"str", name = "힘", desc = "근거리 피해 +%d%% · 최대 체력 +%d" % [roundi(Config.STAT_DMG * 100), Config.STR_HP]},
	{id = &"dex", name = "솜씨", desc = "활 피해 +%d%% · 걷기 · 구르기 +%.1f%%" % [roundi(Config.STAT_DMG * 100), Config.DEX_SPEED * 100]},
	{id = &"wis", name = "지혜", desc = "지팡이 피해 +%d%% · 속성 효과 시간 +%d%%" % [roundi(Config.STAT_DMG * 100), roundi(Config.WIS_ELEMENT * 100)]},
	{id = &"bond", name = "교감", desc = "동행 크리처 피해 +%d%% · 공격 빠르기 +%d%%" % [roundi(Config.BOND_DMG * 100), roundi(Config.BOND_SPEED * 100)]},
]
## 무기 종류 → 피해를 올리는 스탯
const WEAPON_STAT := {&"melee": &"str", &"bow": &"dex", &"staff": &"wis"}
## 직업마다 묶이는 무기 트리 (조련은 모두)
const WEAPON_TREES: Array[StringName] = [&"sword", &"bow", &"staff"]


static func chosen() -> bool:
	return GameState.hunter_class != &""


static func class_name_of(id: StringName) -> String:
	return CLASSES[id].name if CLASSES.has(id) else "직업 없음"


static func stat(id: StringName) -> int:
	return GameState.stats.get(id, 0)


## 이 트리를 지금 직업이 찍을 수 있는지 (조련은 모두. 직업을 아직 안 골랐으면 무기 트리는 못 찍음)
static func tree_open(tree_id: StringName) -> bool:
	if not tree_id in WEAPON_TREES:
		return true
	return chosen() and CLASSES[GameState.hunter_class].tree == tree_id


## 무기 종류 피해 배율 (스탯 x 직업 무기)
static func weapon_mult(kind: StringName) -> float:
	var m := 1.0 + Config.STAT_DMG * stat(WEAPON_STAT.get(kind, &""))
	if chosen() and CLASSES[GameState.hunter_class].weapon == kind:
		m *= 1.0 + Config.CLASS_WEAPON_BONUS
	return m


## 사냥꾼 한 대 피해 (units = 옛 피해 1 · 2 ...)
static func hunter_damage(units: int, kind: StringName) -> int:
	return maxi(1, roundi(units * Config.DMG_UNIT * weapon_mult(kind)))


## 동행 크리처 한 대 피해
static func companion_damage(units: int) -> int:
	return maxi(1, roundi(units * Config.DMG_UNIT * Config.COMPANION_BASE * (1.0 + Config.BOND_DMG * stat(&"bond"))))


static func companion_speed() -> float:
	return 1.0 + Config.BOND_SPEED * stat(&"bond")


static func bonus_hp() -> int:
	return Config.STR_HP * stat(&"str")


static func move_mult() -> float:
	return 1.0 + Config.DEX_SPEED * stat(&"dex")


static func element_mult() -> float:
	return 1.0 + Config.WIS_ELEMENT * stat(&"wis")


## 몬스터 체력 배율: 보통 빌드가 그 몬스터 레벨에서 내는 피해만큼 (Config.MON_HP_STAT_PER_LV)
static func monster_hp_mult(monster_level: int) -> float:
	return (1.0 + Config.CLASS_WEAPON_BONUS) * (1.0 + Config.MON_HP_STAT_PER_LV * maxi(0, monster_level - 1))


static func spend(id: StringName) -> bool:
	if GameState.stat_points <= 0 or not STATS.any(func(d: Dictionary) -> bool: return d.id == id):
		return false
	GameState.stats[id] = stat(id) + 1
	GameState.stat_points -= 1
	GameState.touch()
	return true


## 다음 초기화 값 (첫 번은 공짜)
static func respec_price() -> int:
	return 0 if not GameState.free_respec_used else GameState.hunter_level * Config.RESPEC_PRICE_PER_LV


## 찍은 스탯 · 스킬을 모두 포인트로 돌려준다 (돈은 받지 않음)
static func refund_all() -> void:
	var sp := 0
	for id in GameState.skills:
		sp += GameState.skills[id]
	GameState.skill_points += sp
	GameState.skills = {}
	GameState.skill_left = {}
	var st := 0
	for id in GameState.stats:
		st += GameState.stats[id]
	GameState.stat_points += st
	GameState.stats = {}


## 처음 직업을 고른다. 옛 저장 (직업 전에 찍은 스킬) 은 모두 돌려받고, 지금 레벨까지의 스탯 포인트를 받는다.
## 직업 무기가 없으면 기본 무기 하나 (일반) 를 준다. 줄 알림 문장을 돌려준다.
static func choose(id: StringName, rng: RandomNumberGenerator = null) -> String:
	if chosen() or not CLASSES.has(id):
		return ""
	refund_all()
	GameState.stat_points = Config.STAT_POINTS_PER_LEVEL * (GameState.hunter_level - 1)
	GameState.hunter_class = id
	var c: Dictionary = CLASSES[id]
	var text := "%s의 길을 골랐다. %s 피해 +%d%%." % [c.name, c.desc, roundi(Config.CLASS_WEAPON_BONUS * 100)]
	if c.gift != &"" and not _owns_weapon_kind(c.weapon):
		if rng == null:
			rng = RandomNumberGenerator.new()
		var roll := Wearables.roll_gear(rng, &"normal", {}, c.gift)
		var where := Wearables.gain_rolled(roll)
		# 첫 대장이 같은 무기를 또 주지 않게
		for z: int in Config.FIRST_WEAPON_DROPS:
			if Config.FIRST_WEAPON_DROPS[z] == c.gift and not z in GameState.weapon_gifts:
				GameState.weapon_gifts.append(z)
		if where == &"worn" or (where == &"bag" and _wear_gift(StringName("gear_%d" % GameState.gear_serial))):
			text += " %s을(를) 받아 들었다." % roll.name
		elif where != &"":
			text += " %s을(를) 받아 가방에 넣었다 (I)." % roll.name
	if GameState.stat_points > 0 or GameState.skill_points > 0:
		text += " T 창에서 스탯 %d · 스킬 %d 포인트를 찍자." % [GameState.stat_points, GameState.skill_points]
	GameState.touch()
	return text


## 받은 무기가 가방에 들어갔으면 (다른 직업 무기를 들고 있었으면) 바로 바꿔 든다
static func _wear_gift(id: StringName) -> bool:
	return Wearables.wear_from_bag(&"hunter", GameState.bag[&"hunter"].find(id))


static func _owns_weapon_kind(kind: StringName) -> bool:
	var ids: Array[StringName] = []
	var w: StringName = GameState.worn[&"hunter"].get(&"weapon", &"")
	if w != &"":
		ids.append(w)
	ids.append_array(GameState.bag[&"hunter"])
	ids.append_array(GameState.stash)
	for id in ids:
		var it := Wearables.item(id)
		if it.get("slot", &"") == &"weapon" and it.weapon.kind == kind:
			return true
	return false


## 초기화 (직업 그대로, to = &"") 또는 직업 바꾸기. 값이 모자라면 "" 대신 까닭을 담은 문장, ok 는 성공 여부.
static func respec(to := &"") -> Dictionary:
	if not chosen():
		return {ok = false, text = "아직 직업을 고르지 않았다."}
	if to != &"" and (not CLASSES.has(to) or to == GameState.hunter_class):
		return {ok = false, text = "이미 %s이다." % class_name_of(to)}
	var price := respec_price()
	if GameState.money < price:
		return {ok = false, text = "돈이 모자라다. %d원 (가진 돈 %d원)." % [price, GameState.money]}
	GameState.money -= price
	GameState.free_respec_used = true
	refund_all()
	var what := "초기화"
	if to != &"":
		GameState.hunter_class = to
		what = "%s로 직업을 바꿨다" % CLASSES[to].name
	GameState.touch()
	return {ok = true, text = "%s! %s스탯 %d · 스킬 %d 포인트를 다시 찍자 (T)." % [what, "" if price == 0 else "-%d원. " % price, GameState.stat_points, GameState.skill_points]}
