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
}

## 세트: 조각을 모두 입으면 보너스 (디아블로2 세트 장비처럼)
const SETS := {
	&"forest": {"name": "숲 공터 세트", "pieces": [&"acorn_helm", &"forest_cape", &"feather_boots"], "effect": "하트 +1 더", "hearts": 1},
}


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
		m *= ITEMS[id].get("speed", 1.0)
	return m


static func sow_reach(who: StringName) -> int:
	var r := 1
	for id in worn_by(who):
		r = maxi(r, ITEMS[id].get("sow_reach", 1))
	return r


static func is_hunt_drop(id: StringName) -> bool:
	return ITEMS[id].get("from", &"") == &"hunt"


## 공급함에서 파는 장비 (사냥터 드롭은 뺀다)
static func shop_items() -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in ITEMS:
		if not is_hunt_drop(id):
			out.append(id)
	return out


## 아직 없는 사냥터 드롭 장비 (중복 없이 떨어뜨린다)
static func missing_hunt_drops() -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in ITEMS:
		if is_hunt_drop(id) and not is_owned(id):
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
		n += ITEMS[id].get("hearts", 0)
	for set_id: StringName in SETS:
		if set_complete(set_id, who):
			n += SETS[set_id].get("hearts", 0)
	return n


static func swing_radius(who: StringName) -> float:
	var r := Config.SWING_RADIUS
	for id in worn_by(who):
		r = maxf(r, ITEMS[id].get("swing_radius", 0.0))
	return r


## 장비를 얻어 입는다 (그 칸에 입던 것은 가방으로). 캐릭터 덧그림은 부른 쪽이 새로 그린다.
static func gain_and_wear(id: StringName) -> void:
	if not is_owned(id):
		GameState.owned_wear.append(id)
	var item: Dictionary = ITEMS[id]
	var old: StringName = GameState.worn[item.who].get(item.slot, &"")
	GameState.worn[item.who][item.slot] = id
	if old != &"" and old != id:
		store(item.who, old)


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
	var item: Dictionary = ITEMS[id]
	if item.who != who:
		return false
	var old: StringName = GameState.worn[who].get(item.slot, &"")
	GameState.worn[who][item.slot] = id
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
	var item: Dictionary = ITEMS[id]
	var text := "%s (%s %s) · %s" % [item.name, "농부" if item.who == &"farmer" else "사냥꾼", SLOT_NAMES[item.slot], item.effect]
	var set_id: StringName = item.get("set", &"")
	if set_id != &"":
		text += " · %s" % SETS[set_id].name
	return text
