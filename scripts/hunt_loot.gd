class_name HuntLoot
extends RefCounted
## 사냥터 드롭표 (2026-09-27 결정 A + 드롭표).
## 사용자: "A로 가되 장비, 포션, 잡템 등 포함해서 20퍼센트로하고 디아블로2 방식과 유사하면 좋을듯", "장비 보장은 빼고가자".
## 쓰러뜨릴 때마다 20% 확률로 돈 · 빨간 물약 · 잡템 · 장비 중 하나가 떨어진다 (무게는 Config.HUNT_LOOT_WEIGHTS).
## 장비 보장 칸은 없다. 장비는 아직 없는 것만 나온다 (다 모으면 돈으로 바뀜). 알은 따로 굴린다 (Config "알 드롭").
## 땅에 떨어진 이름은 디아블로2처럼 종류별 색으로 보인다 (돈 금색, 물약 빨강, 잡템 회색, 세트 장비 초록).
## 장비 등급 (2026-09-28 사용자 선택 A: 디아블로2 그대로): 세트 조각이 아닌 장비는 기본 장비에 등급과 옵션을 굴린다.
## 일반 흰색 · 마법 파랑 · 레어 노랑. 세트를 다 모아도 장비는 계속 떨어진다.
## 대장 슬라임 (2026-09-28 사용자 선택 B): 반드시 하나. 장비 40% (마법·레어가 잘 나옴), 아니면 돈 주머니.
## 스테이지 사냥터 (2026-09-28 사용자 선택 B + 웨이포인트): 구역(Config.HUNT_ZONES)마다 종류 무게 · 등급 무게 · 돈 범위가 다르다.

const KINDS: Array[StringName] = [&"money", &"potion", &"junk", &"gear"]
const COLORS := {
	&"money": Color(0.95, 0.85, 0.45),
	&"potion": Color(1.0, 0.45, 0.42),
	&"junk": Color(0.78, 0.78, 0.74),
	&"gear": Color(0.45, 0.95, 0.4),
}
## 장비 등급 색 (땅 이름 · 가방 테두리 · 설명 줄)
const RARITY_COLORS := {
	&"normal": Color(0.95, 0.95, 0.92),
	&"magic": Color(0.5, 0.62, 1.0),
	&"rare": Color(1.0, 0.9, 0.35),
	&"set": Color(0.45, 0.95, 0.4),
}


## 한 마리를 쓰러뜨렸을 때 떨어질 것. 없으면 빈 사전.
static func roll_for_kill(rng: RandomNumberGenerator, zone := 0) -> Dictionary:
	var z: Dictionary = Config.HUNT_ZONES[zone]
	var missing := Wearables.missing_hunt_drops()
	if rng.randf() >= loot_chance():
		return {}
	var kind := pick_kind(rng.randf() * 100.0, z.loot)
	if kind == &"gear":
		# 세트 조각이 남아 있으면 절반은 세트 조각, 나머지는 등급을 굴린 장비
		if not missing.is_empty() and rng.randf() < Config.SET_PIECE_SHARE:
			return _gear(missing, rng)
		return {kind = &"gear", roll = Wearables.roll_gear(rng, &"", z.rarity)}
	match kind:
		&"money":
			return _money(rng, z.money[0], z.money[1])
		_:
			return {kind = kind}


## 대장 슬라임을 쓰러뜨렸을 때 떨어질 것 (늘 하나). "드롭 확률 +%p" 옵션은 쓰이지 않는다.
static func roll_for_boss(rng: RandomNumberGenerator, zone := 0) -> Dictionary:
	var z: Dictionary = Config.HUNT_ZONES[zone]
	if rng.randf() >= Config.BOSS_GEAR_CHANCE:
		return _money(rng, z.boss_money[0], z.boss_money[1])
	var missing := Wearables.missing_hunt_drops()
	if not missing.is_empty() and rng.randf() < Config.SET_PIECE_SHARE:
		return _gear(missing, rng)
	return {kind = &"gear", roll = Wearables.roll_gear(rng, &"", z.boss_rarity)}


## 0~100 사이 값으로 종류를 고른다 (무게 순서대로). weights 가 비면 숲 공터 무게.
static func pick_kind(roll: float, weights := {}) -> StringName:
	if weights.is_empty():
		weights = Config.HUNT_LOOT_WEIGHTS
	var acc := 0.0
	for kind: StringName in KINDS:
		acc += weights[kind]
		if roll < acc:
			return kind
	return KINDS[-1]


## 드롭 확률 (사냥꾼이 입은 "드롭 확률 +%p" 옵션을 더한다)
static func loot_chance() -> float:
	return Config.HUNT_LOOT_CHANCE + Wearables.stat_sum(&"hunter", "find") / 100.0


## 땅에 보이는 이름 색
static func color(d: Dictionary) -> Color:
	if d.kind == &"gear":
		return RARITY_COLORS[d.roll.rarity] if d.has("roll") else RARITY_COLORS[&"set"]
	return COLORS[d.kind]


static func _gear(missing: Array[StringName], rng: RandomNumberGenerator) -> Dictionary:
	return {kind = &"gear", id = missing[rng.randi() % missing.size()]}


static func _money(rng: RandomNumberGenerator, lo := Config.HUNT_MONEY_MIN, hi := Config.HUNT_MONEY_MAX) -> Dictionary:
	var amount := rng.randi_range(lo, hi)
	# "돈 드롭 +%" 옵션
	amount = roundi(amount * (1.0 + Wearables.stat_sum(&"hunter", "money") / 100.0))
	return {kind = &"money", amount = amount}


## 땅에 보이는 이름
static func label(d: Dictionary) -> String:
	match d.kind:
		&"money":
			return "%d원" % d.amount
		&"potion":
			return "빨간 물약"
		&"junk":
			return "슬라임 젤리"
		_:
			return d.roll.name if d.has("roll") else Wearables.ITEMS[d.id].name


## 주운 것을 가진 것에 넣고 알림 문장을 돌려준다. 세트 조각은 바로 입고, 등급 장비는 칸이 비었으면 입고 아니면 가방으로.
## 가방과 창고가 모두 차 있으면 줍지 못하고 빈 문장을 돌려준다 (땅에 남는다). 덧그림은 부른 쪽이 새로 그린다.
static func take(d: Dictionary) -> String:
	match d.kind:
		&"money":
			GameState.money += d.amount
			return "%d원을 주웠다." % d.amount
		&"potion":
			GameState.potions += 1
			return "빨간 물약을 주웠다! 1 키로 마시면 하트 +%d. (가진 물약 %d)" % [Config.POTION_HEAL, GameState.potions]
		&"junk":
			GameState.junk += 1
			return "슬라임 젤리를 주웠다. 마을 공급함에서 사냥꾼이 F로 팔 수 있다."
		_ when d.has("roll"):
			var where := Wearables.gain_rolled(d.roll)
			var what := "%s %s" % [Wearables.RARITY_NAMES[d.roll.rarity], d.roll.name]
			match where:
				&"worn":
					return "%s을(를) 주워 바로 입었다! %s" % [what, Wearables.affix_text(d.roll.affixes)]
				&"bag":
					return "%s을(를) 주워 가방에 넣었다. (I 키)" % what
				&"stash":
					return "가방이 가득 차서 %s을(를) 마을 창고로 보냈다." % what
			return ""
		_:
			var item: Dictionary = Wearables.ITEMS[d.id]
			Wearables.gain_and_wear(d.id)
			var text := "세트 장비 %s을(를) 주워 바로 입었다! %s" % [item.name, item.effect]
			var set_id: StringName = item.get("set", &"")
			if set_id != &"" and Wearables.set_complete(set_id, item.who):
				text += " · %s 완성! %s" % [Wearables.SETS[set_id].name, Wearables.SETS[set_id].effect]
			return text
