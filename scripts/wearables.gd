class_name Wearables
extends RefCounted
## 입는 장비 (2026-09-27 결정: A 도구 강화 + B 입는 장비, 겉모습은 덧그림).
## 칸은 모자 · 옷 · 신발. 마을 공급함에서 사면 바로 입는다 (옷장은 다음 단계).
## 마을에서 사는 물건이라 현대풍. 판타지풍 완제품은 나중에 사냥터에서 떨어진다 (사용자 방향).
## 그림은 캐릭터 시트와 같은 규격의 덧그림 (assets/wear, tools/make_wear_sheets.py). 값과 효과는 전부 임시.

const SLOTS: Array[StringName] = [&"hat", &"clothes", &"shoes"]
const SLOT_NAMES := {&"hat": "모자", &"clothes": "옷", &"shoes": "신발"}

## who: 누가 입는지 (&"farmer" / &"hunter"). speed: 걷기 배율. sow_reach: 씨앗 뿌리는 칸 수.
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
