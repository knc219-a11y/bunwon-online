class_name HuntLoot
extends RefCounted
## 사냥터 드롭표 (2026-09-27 결정 A + 드롭표).
## 사용자: "A로 가되 장비, 포션, 잡템 등 포함해서 20퍼센트로하고 디아블로2 방식과 유사하면 좋을듯", "장비 보장은 빼고가자".
## 쓰러뜨릴 때마다 20% 확률로 돈 · 빨간 물약 · 잡템 · 장비 중 하나가 떨어진다 (무게는 Config.HUNT_LOOT_WEIGHTS).
## 장비 보장 칸은 없다. 장비는 아직 없는 것만 나온다 (다 모으면 돈으로 바뀜). 그날 첫 알 보장은 따로 그대로.
## 땅에 떨어진 이름은 디아블로2처럼 종류별 색으로 보인다 (돈 금색, 물약 빨강, 잡템 회색, 세트 장비 초록).

const KINDS: Array[StringName] = [&"money", &"potion", &"junk", &"gear"]
const COLORS := {
	&"money": Color(0.95, 0.85, 0.45),
	&"potion": Color(1.0, 0.45, 0.42),
	&"junk": Color(0.78, 0.78, 0.74),
	&"gear": Color(0.45, 0.95, 0.4),
}


## 한 마리를 쓰러뜨렸을 때 떨어질 것. 없으면 빈 사전.
static func roll_for_kill(rng: RandomNumberGenerator) -> Dictionary:
	var missing := Wearables.missing_hunt_drops()
	if rng.randf() >= Config.HUNT_LOOT_CHANCE:
		return {}
	var kind := pick_kind(rng.randf() * 100.0)
	if kind == &"gear":
		# 세트를 다 모았으면 장비 대신 돈
		return _gear(missing, rng) if not missing.is_empty() else _money(rng)
	match kind:
		&"money":
			return _money(rng)
		_:
			return {kind = kind}


## 0~100 사이 값으로 종류를 고른다 (무게 순서대로)
static func pick_kind(roll: float) -> StringName:
	var acc := 0.0
	for kind: StringName in KINDS:
		acc += Config.HUNT_LOOT_WEIGHTS[kind]
		if roll < acc:
			return kind
	return KINDS[-1]


static func _gear(missing: Array[StringName], rng: RandomNumberGenerator) -> Dictionary:
	return {kind = &"gear", id = missing[rng.randi() % missing.size()]}


static func _money(rng: RandomNumberGenerator) -> Dictionary:
	return {kind = &"money", amount = rng.randi_range(Config.HUNT_MONEY_MIN, Config.HUNT_MONEY_MAX)}


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
			return Wearables.ITEMS[d.id].name


## 주운 것을 가진 것에 넣고 알림 문장을 돌려준다. 장비는 바로 입는다 (덧그림은 부른 쪽이 새로 그린다).
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
		_:
			var item: Dictionary = Wearables.ITEMS[d.id]
			Wearables.gain_and_wear(d.id)
			var text := "세트 장비 %s을(를) 주워 바로 입었다! %s" % [item.name, item.effect]
			var set_id: StringName = item.get("set", &"")
			if set_id != &"" and Wearables.set_complete(set_id, item.who):
				text += " · %s 완성! %s" % [Wearables.SETS[set_id].name, Wearables.SETS[set_id].effect]
			return text
