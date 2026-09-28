class_name Wearables
extends RefCounted
## 입는 장비 (2026-09-27 결정: A 도구 강화 + B 입는 장비, 겉모습은 덧그림).
## 칸은 모자 · 옷 · 신발. 사거나 주우면 바로 입고, 벗은 것은 가방(I 키)으로 간다.
## 가방이 차면 마을 공용 창고로 보낸다 (잃어버리는 일 없음, 2026-09-28 사용자 요청 디아블로식 가방 + 창고).
## 마을에서 사는 물건은 현대풍. 사냥터에서 떨어지는 완제품(from: hunt)은 판타지풍 (사용자 방향).
## 그림은 캐릭터 시트와 같은 규격의 덧그림 (assets/wear, tools/make_wear_sheets.py). 값과 효과는 전부 임시.

const SLOTS: Array[StringName] = [&"hat", &"clothes", &"shoes"]
const SLOT_NAMES := {&"hat": "모자", &"clothes": "옷", &"shoes": "신발"}

## who: 누가 입는지 (&"farmer" / &"hunter"). speed: 걷기 배율. sow_reach: 씨앗 뿌리는 칸 수.
## from: &"hunt" 면 공급함에서 팔지 않고 사냥터에서만 떨어진다. set: 세트 id (SETS).
## hearts: 사냥터 하트 +. swing_radius: 휘두르기 반지름 (px, 큰 값 하나만).
const ITEMS := {
	&"straw_hat": {"name": "밀짚모자", "who": &"farmer", "slot": &"hat", "price": 80, "effect": "꾸미기",
		"sheet": preload("res://assets/wear/straw_hat.png")},
	&"seed_vest": {"name": "씨앗 주머니 조끼", "who": &"farmer", "slot": &"clothes", "price": 300, "effect": "씨앗도 앞 3칸 한 번에", "sow_reach": 3,
		"sheet": preload("res://assets/wear/seed_vest.png")},
	&"rain_boots": {"name": "장화", "who": &"farmer", "slot": &"shoes", "price": 150, "effect": "걷기 +15%", "speed": 1.15,
		"sheet": preload("res://assets/wear/rain_boots.png")},
	&"ball_cap": {"name": "캡모자", "who": &"hunter", "slot": &"hat", "price": 80, "effect": "꾸미기",
		"sheet": preload("res://assets/wear/ball_cap.png")},
	&"hiking_shoes": {"name": "등산화", "who": &"hunter", "slot": &"shoes", "price": 150, "effect": "걷기 +15%", "speed": 1.15,
		"sheet": preload("res://assets/wear/hiking_shoes.png")},
	# 사냥터 드롭 숲 공터 세트 (2026-09-27 결정 A + 드롭표). 판타지풍, 디아블로2처럼 세트 장비는 초록 이름.
	&"acorn_helm": {"name": "도토리 투구", "who": &"hunter", "slot": &"hat", "from": &"hunt", "set": &"forest", "effect": "하트 +1", "hearts": 1,
		"sheet": preload("res://assets/wear/acorn_helm.png")},
	&"forest_cape": {"name": "숲지기 망토", "who": &"hunter", "slot": &"clothes", "from": &"hunt", "set": &"forest", "effect": "휘두르기 범위 넓게", "swing_radius": 24.0,
		"sheet": preload("res://assets/wear/forest_cape.png")},
	&"feather_boots": {"name": "깃털 장화", "who": &"hunter", "slot": &"shoes", "from": &"hunt", "set": &"forest", "effect": "걷기 +25%", "speed": 1.25,
		"sheet": preload("res://assets/wear/feather_boots.png")},
	# 사냥터 기본 장비 (2026-09-28 사용자 선택 A: 디아블로2식 등급). 떨어질 때마다 등급과 옵션을 새로 굴려
	# 한 개 한 개가 따로 생긴다 (GameState.gear). 일반은 효과 없음. base: 이 id 로는 직접 입지 않는다.
	&"leather_hood": {"name": "가죽 두건", "who": &"hunter", "slot": &"hat", "from": &"hunt", "base": true, "effect": "",
		"sheet": preload("res://assets/wear/leather_hood.png")},
	&"hunter_jerkin": {"name": "사냥꾼 조끼", "who": &"hunter", "slot": &"clothes", "from": &"hunt", "base": true, "effect": "",
		"sheet": preload("res://assets/wear/hunter_jerkin.png")},
	&"leather_shoes": {"name": "사냥꾼 가죽 신", "who": &"hunter", "slot": &"shoes", "from": &"hunt", "base": true, "effect": "",
		"sheet": preload("res://assets/wear/leather_shoes.png")},
}

## 옵션 (디아블로2 접두·접미). 첫 조각은 효과가 이미 있는 것만. 수치는 전부 임시.
## stat: hearts 하트 + · speed 걷기 +% · swing 휘두르기 반지름 + · money 돈 드롭 +% · find 드롭 확률 +%p
## prefix: 마법 이름 앞말, suffix: 옵션이 둘일 때 맨 앞에 붙는 말
const AFFIXES := {
	&"hearts": {"min": 1, "max": 1, "prefix": "튼튼한", "suffix": "생명의"},
	&"speed": {"min": 10, "max": 20, "prefix": "날랜", "suffix": "바람의"},
	&"swing": {"min": 2, "max": 6, "prefix": "넓게 베는", "suffix": "회오리의"},
	&"money": {"min": 20, "max": 50, "prefix": "황금빛", "suffix": "행운의"},
	&"find": {"min": 2, "max": 5, "prefix": "보물 찾는", "suffix": "보물의"},
}
## 레어 이름 (무작위 두 단어, 뒤 단어는 칸마다)
const RARE_WORDS := ["이끼", "도토리", "달빛", "여우", "안개", "참나무", "반딧불", "들꽃"]
const RARE_TAILS := {&"hat": ["관", "두건", "투구"], &"clothes": ["외투", "망토", "가죽"], &"shoes": ["발굽", "걸음", "장화"]}
const RARITY_NAMES := {&"normal": "일반", &"magic": "마법", &"rare": "레어", &"set": "세트"}
const RARITIES: Array[StringName] = [&"normal", &"magic", &"rare"]

## 세트: 조각을 모두 입으면 보너스 (디아블로2 세트 장비처럼)
const SETS := {
	&"forest": {"name": "숲 공터 세트", "pieces": [&"acorn_helm", &"forest_cape", &"feather_boots"], "effect": "하트 +1 더", "hearts": 1},
}


## 장비 한 개의 정보. 정해진 장비(마을 · 세트)는 ITEMS 그대로, 사냥터에서 굴린 장비는
## 기본 장비에 등급 · 이름 · 옵션 효과를 얹어 돌려준다.
static func item(id: StringName) -> Dictionary:
	if ITEMS.has(id):
		return ITEMS[id]
	var roll: Dictionary = GameState.gear[id]
	var out: Dictionary = ITEMS[roll.base].duplicate()
	out.erase("base")
	out.name = roll.name
	out.rarity = roll.rarity
	out.affixes = roll.affixes
	var speed := 1.0
	for a: Dictionary in roll.affixes:
		match a.stat:
			&"speed":
				speed *= 1.0 + a.value / 100.0
			&"hearts":
				out.hearts = out.get("hearts", 0) + a.value
			&"swing":
				out.swing_add = out.get("swing_add", 0.0) + a.value
			&"money":
				out.money = out.get("money", 0) + a.value
			&"find":
				out.find = out.get("find", 0) + a.value
	if speed != 1.0:
		out.speed = speed
	out.effect = affix_text(roll.affixes)
	return out


static func has_item(id: StringName) -> bool:
	return ITEMS.has(id) or GameState.gear.has(id)


## 등급: &"normal" / &"magic" / &"rare" / &"set". 마을 장비는 일반.
static func rarity(id: StringName) -> StringName:
	if ITEMS.has(id):
		return &"set" if ITEMS[id].has("set") else &"normal"
	return GameState.gear[id].rarity


## 사냥터에서 굴린 장비인지 (팔 수 있는 것)
static func is_rolled(id: StringName) -> bool:
	return GameState.gear.has(id)


static func affix_line(a: Dictionary) -> String:
	match a.stat:
		&"hearts":
			return "하트 +%d" % a.value
		&"speed":
			return "걷기 +%d%%" % a.value
		&"swing":
			return "휘두르기 범위 +%d" % a.value
		&"money":
			return "돈 드롭 +%d%%" % a.value
		_:
			return "드롭 확률 +%d%%p" % a.value


static func affix_text(affixes: Array) -> String:
	var parts: Array[String] = []
	for a: Dictionary in affixes:
		parts.append(affix_line(a))
	return " · ".join(parts) if not parts.is_empty() else "꾸미기"


## 기본 장비 하나를 굴린다 (디아블로2식). 아직 가진 것에 넣지 않은 정보만 돌려준다.
static func roll_gear(rng: RandomNumberGenerator, force_rarity := &"") -> Dictionary:
	var bases: Array[StringName] = []
	for id: StringName in ITEMS:
		if ITEMS[id].get("base", false):
			bases.append(id)
	var base := bases[rng.randi() % bases.size()]
	var r: StringName = force_rarity if force_rarity != &"" else pick_rarity(rng.randf() * 100.0)
	var count_range: Array = Config.GEAR_AFFIX_COUNT[r]
	var stats: Array = AFFIXES.keys()
	# 섞어서 앞에서부터 (한 장비에 같은 옵션은 한 번만)
	for i in range(stats.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var t = stats[i]
		stats[i] = stats[j]
		stats[j] = t
	var affixes: Array[Dictionary] = []
	for i in rng.randi_range(count_range[0], count_range[1]):
		var def: Dictionary = AFFIXES[stats[i]]
		affixes.append({stat = stats[i], value = rng.randi_range(def.min, def.max)})
	var base_name: String = ITEMS[base].name
	var name := base_name
	match r:
		&"magic":
			name = "%s %s" % [AFFIXES[affixes[0].stat].prefix, base_name]
			if affixes.size() > 1:
				name = "%s %s" % [AFFIXES[affixes[1].stat].suffix, name]
		&"rare":
			var tails: Array = RARE_TAILS[ITEMS[base].slot]
			name = "%s %s" % [RARE_WORDS[rng.randi() % RARE_WORDS.size()], tails[rng.randi() % tails.size()]]
	return {base = base, rarity = r, name = name, affixes = affixes}


## 0~100 사이 값으로 등급을 고른다 (무게 순서대로)
static func pick_rarity(roll: float) -> StringName:
	var acc := 0.0
	for r: StringName in RARITIES:
		acc += Config.GEAR_RARITY_WEIGHTS[r]
		if roll < acc:
			return r
	return RARITIES[-1]


## 굴린 장비를 가진 것에 넣는다. 칸이 비었으면 바로 입고, 아니면 가방 → 창고.
## 어디로 갔는지 돌려준다 (&"worn" / &"bag" / &"stash"). 둘 다 차 있으면 &"" (넣지 않음, 땅에 남는다).
static func gain_rolled(roll: Dictionary) -> StringName:
	GameState.gear_serial += 1
	var id := StringName("gear_%d" % GameState.gear_serial)
	GameState.gear[id] = roll
	var it := item(id)
	if not GameState.worn[it.who].has(it.slot):
		GameState.worn[it.who][it.slot] = id
		return &"worn"
	var where := store(it.who, id)
	if where == &"":
		GameState.gear.erase(id)
	return where


static func sell_price(id: StringName) -> int:
	return Config.GEAR_SELL_PRICES[rarity(id)]


## who 가방 i 번째 장비를 판다 (사냥터에서 굴린 장비만). 받은 돈, 못 팔면 0.
static func sell(who: StringName, i: int) -> int:
	var b: Array[StringName] = GameState.bag[who]
	if i < 0 or i >= b.size() or not is_rolled(b[i]):
		return 0
	var id := b[i]
	var price := sell_price(id)
	b.remove_at(i)
	GameState.gear.erase(id)
	GameState.money += price
	return price


## 가방의 일반 장비를 한꺼번에 판다. [판 개수, 받은 돈]
static func sell_all_normal(who: StringName) -> Array[int]:
	var b: Array[StringName] = GameState.bag[who]
	var n := 0
	var total := 0
	for i in range(b.size() - 1, -1, -1):
		if is_rolled(b[i]) and rarity(b[i]) == &"normal":
			total += sell(who, i)
			n += 1
	return [n, total]


static func normal_in_bag(who: StringName) -> int:
	var n := 0
	for id in GameState.bag[who]:
		if is_rolled(id) and rarity(id) == &"normal":
			n += 1
	return n


static func rolled_in_bag(who: StringName) -> int:
	var n := 0
	for id in GameState.bag[who]:
		if is_rolled(id):
			n += 1
	return n


## 입은 장비 옵션을 더한 값 (돈 드롭 %, 드롭 확률 %p)
static func stat_sum(who: StringName, stat: String) -> int:
	var n := 0
	for id in worn_by(who):
		n += item(id).get(stat, 0)
	return n


## who 가 입고 있는 장비 id 목록 (칸 순서)
static func worn_by(who: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	var worn: Dictionary = GameState.worn.get(who, {})
	for slot in SLOTS:
		if worn.has(slot):
			out.append(worn[slot])
	return out


static func is_owned(id: StringName) -> bool:
	return id in GameState.owned_wear


## 입은 장비 효과를 곱한 걷기 배율
static func speed_mult(who: StringName) -> float:
	var m := 1.0
	for id in worn_by(who):
		m *= item(id).get("speed", 1.0)
	return m


static func sow_reach(who: StringName) -> int:
	var r := 1
	for id in worn_by(who):
		r = maxi(r, item(id).get("sow_reach", 1))
	return r


static func is_hunt_drop(id: StringName) -> bool:
	return item(id).get("from", &"") == &"hunt"


## 공급함에서 파는 장비 (사냥터 드롭은 뺀다)
static func shop_items() -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in ITEMS:
		if not is_hunt_drop(id):
			out.append(id)
	return out


## 아직 없는 세트 조각 (중복 없이 떨어뜨린다)
static func missing_hunt_drops() -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in ITEMS:
		if is_hunt_drop(id) and ITEMS[id].has("set") and not is_owned(id):
			out.append(id)
	return out


static func set_complete(set_id: StringName, who: StringName) -> bool:
	var worn := worn_by(who)
	for id: StringName in SETS[set_id].pieces:
		if not id in worn:
			return false
	return true


## 입은 장비와 완성한 세트가 더하는 사냥터 하트
static func bonus_hearts(who: StringName) -> int:
	var n := 0
	for id in worn_by(who):
		n += item(id).get("hearts", 0)
	for set_id: StringName in SETS:
		if set_complete(set_id, who):
			n += SETS[set_id].get("hearts", 0)
	return n


static func swing_radius(who: StringName) -> float:
	var r := Config.SWING_RADIUS
	var add := 0.0
	for id in worn_by(who):
		var it := item(id)
		r = maxf(r, it.get("swing_radius", 0.0))
		add += it.get("swing_add", 0.0)
	return r + add


## 장비를 얻어 입는다 (그 칸에 입던 것은 가방으로). 캐릭터 덧그림은 부른 쪽이 새로 그린다.
static func gain_and_wear(id: StringName) -> void:
	if not is_owned(id):
		GameState.owned_wear.append(id)
	var it: Dictionary = ITEMS[id]
	var old: StringName = GameState.worn[it.who].get(it.slot, &"")
	GameState.worn[it.who][it.slot] = id
	if old != &"" and old != id:
		store(it.who, old)


## 입지 않은 장비를 who 의 가방에 넣는다. 가방이 차면 창고로. 어디로 갔는지 돌려준다 (&"bag" / &"stash" / &"").
static func store(who: StringName, id: StringName) -> StringName:
	var b: Array[StringName] = GameState.bag[who]
	if b.size() < Config.BAG_SIZE:
		b.append(id)
		return &"bag"
	if GameState.stash.size() < Config.STASH_SIZE:
		GameState.stash.append(id)
		return &"stash"
	return &""


## 가방 i 번째 장비를 입는다. 그 칸에 입던 것은 같은 가방 자리로 바꿔 넣는다.
static func wear_from_bag(who: StringName, i: int) -> bool:
	var b: Array[StringName] = GameState.bag[who]
	if i < 0 or i >= b.size():
		return false
	var id := b[i]
	var it := item(id)
	if it.who != who:
		return false
	var old: StringName = GameState.worn[who].get(it.slot, &"")
	GameState.worn[who][it.slot] = id
	if old != &"":
		b[i] = old
	else:
		b.remove_at(i)
	return true


## 입은 장비를 벗어 가방에 넣는다 (가방이 차면 창고로). 둘 다 차 있으면 못 벗는다.
static func take_off(who: StringName, slot: StringName) -> bool:
	var id: StringName = GameState.worn[who].get(slot, &"")
	if id == &"":
		return false
	if store(who, id) == &"":
		return false
	GameState.worn[who].erase(slot)
	return true


## 가방 i 번째를 창고로
static func bag_to_stash(who: StringName, i: int) -> bool:
	var b: Array[StringName] = GameState.bag[who]
	if i < 0 or i >= b.size() or GameState.stash.size() >= Config.STASH_SIZE:
		return false
	GameState.stash.append(b[i])
	b.remove_at(i)
	return true


## 창고 i 번째를 who 의 가방으로 (다른 캐릭터 장비도 들 수는 있다. 입는 건 주인만)
static func stash_to_bag(who: StringName, i: int) -> bool:
	var b: Array[StringName] = GameState.bag[who]
	if i < 0 or i >= GameState.stash.size() or b.size() >= Config.BAG_SIZE:
		return false
	b.append(GameState.stash[i])
	GameState.stash.remove_at(i)
	return true


## 세트를 몇 조각 입었는지
static func set_worn_count(set_id: StringName, who: StringName) -> int:
	var worn := worn_by(who)
	var n := 0
	for id: StringName in SETS[set_id].pieces:
		if id in worn:
			n += 1
	return n


## 장비 설명 한 줄 (가방 창 아래에 보여 준다)
static func describe(id: StringName) -> String:
	var it := item(id)
	var kind := "%s %s" % ["농부" if it.who == &"farmer" else "사냥꾼", SLOT_NAMES[it.slot]]
	if is_rolled(id):
		# 사냥터 등급 장비는 모두 사냥꾼 것이라 짧게. 레어는 디아블로2처럼 기본 장비 이름도 함께.
		kind = "%s %s" % [RARITY_NAMES[it.rarity], ITEMS[GameState.gear[id].base].name if it.rarity == &"rare" else SLOT_NAMES[it.slot]]
	var text := "%s (%s) · %s" % [it.name, kind, it.effect]
	var set_id: StringName = it.get("set", &"")
	if set_id != &"":
		text += " · %s" % SETS[set_id].name
	return text
