class_name Crops
extends RefCounted
## 밭 작물 (2026-10-03 백로그 5번 "농사가 무만이라 재미없음"). 값은 Config.CROPS.
## 무 · 감자 · 고추 · 배추. 막 대장을 처음 쓰러뜨린 다음 아침 그 땅 씨앗을 얻어 열리고,
## 공급함 "밭 작물 · 씨앗 · 음식 ▶" 에서 밭 구역마다 심을 작물을 정한다 (농부 · 크리처 모두 그 구역 작물을 심는다).

const ORDER: Array[StringName] = [&"radish", &"potato", &"pepper", &"cabbage"]


static func info(kind: StringName) -> Dictionary:
	return Config.CROPS.get(kind, Config.CROPS[&"radish"])


static func display_name(kind: StringName) -> String:
	return info(kind).name


## 심을 수 있는 작물 (무 + 씨앗을 얻은 것), ORDER 순
static func unlocked() -> Array[StringName]:
	var out: Array[StringName] = []
	for k in ORDER:
		if k == &"radish" or k in GameState.crop_unlocked:
			out.append(k)
	return out


static func seeds(kind: StringName) -> int:
	return int(GameState.get(info(kind).seed_var))


static func add_seeds(kind: StringName, n: int) -> void:
	GameState.set(info(kind).seed_var, seeds(kind) + n)


static func held(kind: StringName) -> int:
	return int(GameState.get(info(kind).held))


static func add_held(kind: StringName, n: int) -> void:
	GameState.set(info(kind).held, held(kind) + n)


## cell 이 든 밭 구역 번호. 밭 밖이면 -1.
static func plot_of(cell: Vector2i) -> int:
	for i in Config.FIELD_PLOTS.size():
		if Config.FIELD_PLOTS[i].has_point(cell):
			return i
	return -1


## 그 구역에 심을 작물 (정하지 않았으면 무)
static func plot_kind(i: int) -> StringName:
	if i < 0 or i >= GameState.plot_crops.size() or GameState.plot_crops[i] == &"":
		return &"radish"
	return GameState.plot_crops[i]


static func kind_at(cell: Vector2i) -> StringName:
	return plot_kind(plot_of(cell))


static func set_plot(i: int, kind: StringName) -> void:
	while GameState.plot_crops.size() <= i:
		GameState.plot_crops.append(&"radish")
	GameState.plot_crops[i] = kind
	GameState.touch()


## 그 구역 작물을 열린 작물 중 다음 것으로 바꾼다
static func cycle_plot(i: int) -> StringName:
	var list := unlocked()
	var next := list[(list.find(plot_kind(i)) + 1) % list.size()]
	set_plot(i, next)
	return next


## 아침: 대장을 처음 쓰러뜨린 땅의 씨앗을 연다. 아침 카드 줄들.
static func morning_unlocks() -> Array[String]:
	var lines: Array[String] = []
	for k in ORDER:
		var zone: int = info(k).zone
		if zone < 0 or k in GameState.crop_unlocked or not zone in GameState.bosses_beaten:
			continue
		GameState.crop_unlocked.append(k)
		add_seeds(k, Config.CROP_UNLOCK_SEEDS)
		lines.append("%s 대장이 물러간 땅에서 %s 씨앗 %d개를 주웠다! (%s) 공급함 \"밭 작물 · 씨앗 · 음식\" 에서 구역마다 심을 작물을 고른다." % [
			Config.HUNT_ZONES[zone].name, display_name(k), Config.CROP_UNLOCK_SEEDS, info(k).note])
	return lines


## 가진 작물 (무 포함) 을 모두 공급함에 진열한다. 진열한 수.
static func display_all() -> int:
	var n := 0
	for k in ORDER:
		var h := held(k)
		if h <= 0:
			continue
		n += h
		GameState.displayed_star_bonus += star_bonus(k)
		GameState.crop_stars.erase(k)
		if k == &"radish":
			GameState.displayed_crops += h
		else:
			GameState.displayed_harvest[k] = int(GameState.displayed_harvest.get(k, 0)) + h
		add_held(k, -h)
	return n


static func held_total() -> int:
	var n := 0
	for k in ORDER:
		n += held(k)
	return n


static func held_value() -> int:
	var v := 0
	for k in ORDER:
		v += held(k) * int(info(k).price) + star_bonus(k)
	return v


## "무 3 · 감자 4" (가진 것만)
static func held_text() -> String:
	var parts: Array[String] = []
	for k in ORDER:
		if held(k) > 0:
			var st := stars_text(k)
			parts.append("%s %d%s" % [display_name(k), held(k), (" (%s)" % st) if st != "" else ""])
	return " · ".join(parts)


## 밤사이 팔린 무 말고 작물. 아침 카드 줄들 (무는 main 이 따로 적는다).
static func sell_displayed() -> Array[String]:
	var lines: Array[String] = []
	for k in ORDER:
		var n := int(GameState.displayed_harvest.get(k, 0))
		if n <= 0:
			continue
		var earned := n * int(info(k).price)
		GameState.money += earned
		lines.append("공급함의 %s %d개가 팔렸다. 돈통에 +%d원" % [display_name(k), n, earned])
	GameState.displayed_harvest = {}
	if GameState.displayed_star_bonus > 0:
		GameState.money += GameState.displayed_star_bonus
		lines.append("★2 · ★3 작물은 값을 더 쳐 받았다. +%d원" % GameState.displayed_star_bonus)
		GameState.displayed_star_bonus = 0
	return lines


# --- 공급함 "밭 작물 · 씨앗 · 음식" 선택창 ---------------------------------------------

static func options() -> Array[StringName]:
	var out: Array[StringName] = []
	if unlocked().size() > 1:
		for i in GameState.open_plots:
			out.append(StringName("plot_%d" % i))
	for k in unlocked():
		if k != &"radish":
			out.append(StringName("seeds_%s" % k))
	out.append(&"compost")
	for id in Config.FOOD_ORDER:
		if Config.FOODS[id].main in unlocked():
			out.append(StringName("food_%s" % id))
	out.append(&"back")
	return out


static func option_text(id: StringName) -> String:
	var s := String(id)
	if s.begins_with("plot_"):
		var i := s.trim_prefix("plot_").to_int()
		var k := plot_kind(i)
		return "%s: %s (씨앗 %d) ▶ 바꾸기" % [Config.FIELD_PLOT_NAMES[i], display_name(k), seeds(k)]
	if s.begins_with("seeds_"):
		var k := StringName(s.trim_prefix("seeds_"))
		var d := info(k)
		return "%s 씨앗 %d개 사기 (%d원, 가진 씨앗 %d) · %s" % [d.name, d.pack, d.pack_price, seeds(k), d.note]
	if id == &"compost":
		return "퇴비 만들기 (들나물 · 진열한 들나물 · 잡템 %d → 1, 가진 퇴비 %d) · 심은 칸에 씨앗 주머니로 주면 ★ +1" % [Config.COMPOST_COST, GameState.compost]
	if s.begins_with("food_"):
		var f := StringName(s.trim_prefix("food_"))
		var fd: Dictionary = Config.FOODS[f]
		var cost: Array[String] = []
		for k: StringName in fd.cost:
			cost.append("%s %d" % [display_name(k), fd.cost[k]])
		var g := best_grade(fd.main)
		return "%s 만들기 (%s → %s) · 가진 것 %s" % [fd.name, " · ".join(cost),
			("★%d %s" % [g, food_effect_text(f, g)]) if g > 0 else "%s ★1~3" % food_effect_text(f, 1), food_text(f)]
	return "뒤로"


## 한 가지 한다. 성공하면 true.
static func act(id: StringName) -> bool:
	var s := String(id)
	if s.begins_with("plot_"):
		var i := s.trim_prefix("plot_").to_int()
		var k := cycle_plot(i)
		GameState.notify("%s에는 이제 %s을(를) 심는다 (%s). 이미 심은 칸은 그대로 자란다." % [Config.FIELD_PLOT_NAMES[i], display_name(k), info(k).note])
		return true
	if s.begins_with("seeds_"):
		return buy_seeds(StringName(s.trim_prefix("seeds_")))
	if id == &"compost":
		return make_compost()
	if s.begins_with("food_"):
		return cook(StringName(s.trim_prefix("food_"))) > 0
	return false


static func buy_seeds(kind: StringName) -> bool:
	var d := info(kind)
	if kind != &"radish" and not kind in GameState.crop_unlocked:
		return false
	if GameState.money < int(d.pack_price):
		GameState.notify("돈이 모자라다. %s 씨앗 %d개에 %d원 (가진 돈 %d원)." % [d.name, d.pack, d.pack_price, GameState.money])
		return false
	GameState.money -= int(d.pack_price)
	add_seeds(kind, int(d.pack))
	GameState.notify("%s 씨앗 %d개를 샀다. -%d원" % [d.name, d.pack, d.pack_price])
	return true


# --- 등급 ★1~3 (2026-10-03 사용자 선택: 돌봄 점수) --------------------------------

## 가진 작물의 등급별 수 [★1, ★2, ★3]. 다른 곳에서 가진 수를 그냥 줄이면 (공사 · 모이 · 미끼 · 잔치상)
## ★1 부터 쓴 것으로 보고, ★1 이 모자라면 ★2, ★3 순으로 깎는다.
static func stars(kind: StringName) -> Array[int]:
	var total := maxi(held(kind), 0)
	var s: Array = GameState.crop_stars.get(kind, [0, 0])
	var n2: int = s[0]
	var n3: int = s[1]
	var over := n2 + n3 - total
	if over > 0:
		var cut := mini(over, n2)
		n2 -= cut
		n3 = maxi(n3 - (over - cut), 0)
	if n2 != s[0] or n3 != s[1]:
		GameState.crop_stars[kind] = [n2, n3]
	return [total - n2 - n3, n2, n3]


## 거둔 작물을 등급과 함께 더한다
static func add_graded(kind: StringName, n: int, grade: int) -> void:
	var st := stars(kind)
	add_held(kind, n)
	if grade >= 2:
		var s: Array = [st[1], st[2]]
		s[grade - 2] += n
		GameState.crop_stars[kind] = s


## n 개를 낮은 등급부터 뺀다 (가진 수가 모자라면 false, 아무것도 안 뺌)
static func take_low(kind: StringName, n: int) -> bool:
	if held(kind) < n:
		return false
	stars(kind)
	add_held(kind, -n)
	stars(kind)
	return true


## 가장 좋은 등급 하나를 빼고 그 등급을 돌려준다. 없으면 0.
static func take_best(kind: StringName) -> int:
	var st := stars(kind)
	for g in [3, 2]:
		if st[g - 1] > 0:
			var s: Array = [st[1], st[2]]
			s[g - 2] -= 1
			GameState.crop_stars[kind] = s
			add_held(kind, -1)
			return g
	if st[0] > 0:
		add_held(kind, -1)
		return 1
	return 0


static func best_grade(kind: StringName) -> int:
	var st := stars(kind)
	return 3 if st[2] > 0 else (2 if st[1] > 0 else (1 if st[0] > 0 else 0))


## "★2 3 · ★3 1" (★2 이상만, 없으면 빈 글)
static func stars_text(kind: StringName) -> String:
	var st := stars(kind)
	var parts: Array[String] = []
	for g in [2, 3]:
		if st[g - 1] > 0:
			parts.append("★%d %d" % [g, st[g - 1]])
	return " · ".join(parts)


## 등급 웃돈: ★2 · ★3 이 ★1 값보다 더 받는 돈
static func star_bonus(kind: StringName) -> int:
	var st := stars(kind)
	var p := int(info(kind).price)
	return (st[1] * p * (Config.STAR_PRICE_PCT[1] - 100) + st[2] * p * (Config.STAR_PRICE_PCT[2] - 100)) / 100


## 거둘 때 등급: 1 + 물 안 빠뜨림 + 퇴비, 속성 맞는 크리처가 돌봤으면 CROP_MATCH_CHANCE 로 +1 (3 까지)
static func harvest_grade(c: Farm.Cell, roll: float) -> int:
	var g := 1 + (0 if c.missed else 1) + (1 if c.fert else 0)
	if c.matched and roll < FarmSkills.match_chance():
		g += 1
	return mini(g, 3)


# --- 퇴비 · 사냥 음식 ----------------------------------------------------------

## 퇴비 하나 만들기: 손에 든 들나물 → 공급함에 진열한 들나물 (채집 크리처가 캔 것) → 사냥 잡템 순으로 COMPOST_COST 개
static func make_compost() -> bool:
	for key: String in ["herbs", "displayed_herbs", "junk"]:
		if int(GameState.get(key)) >= Config.COMPOST_COST:
			GameState.set(key, int(GameState.get(key)) - Config.COMPOST_COST)
			GameState.compost += 1
			# 퇴비 솜씨 (농사 기술, 2026-10-03): 가끔 하나 더
			if randf() < FarmSkills.compost_extra_chance():
				GameState.compost += 1
			GameState.notify("%s %d개로 퇴비를 만들었다 (퇴비 %d). 씨앗 주머니를 이미 심은 칸에 쓰면 한 줌씩 준다 (★ +1)." % [
				{"herbs": "들나물", "displayed_herbs": "진열해 둔 들나물", "junk": "잡템"}[key], Config.COMPOST_COST, GameState.compost])
			return true
	GameState.notify("모자라다. 퇴비: 들나물 또는 잡템 %d개 (든 나물 %d · 진열한 나물 %d · 잡템 %d)." % [Config.COMPOST_COST, GameState.herbs, GameState.displayed_herbs, GameState.junk])
	return false


static func food_count(id: StringName) -> int:
	var f: Array = GameState.foods.get(id, [0, 0, 0])
	return f[0] + f[1] + f[2]


static func food_text(id: StringName) -> String:
	var f: Array = GameState.foods.get(id, [0, 0, 0])
	var parts: Array[String] = []
	for g in 3:
		if f[g] > 0:
			parts.append("★%d %d" % [g + 1, f[g]])
	return " · ".join(parts) if not parts.is_empty() else "0"


static func food_effect_text(id: StringName, grade: int) -> String:
	var d: Dictionary = Config.FOODS[id]
	var v = d.values[grade - 1]
	v = roundi(v * FarmSkills.food_mult()) if d.effect == &"hp" else v * FarmSkills.food_mult()
	match d.effect:
		&"hp":
			return "체력 +%d" % v
		&"attack":
			return "공격 +%d%%" % roundi(v * 100)
		&"luck":
			return "경험치 · 드롭 +%d%%" % roundi(v * 100)
	return ""


static func can_cook(id: StringName) -> bool:
	var cost: Dictionary = Config.FOODS[id].cost
	for k: StringName in cost:
		if held(k) < int(cost[k]):
			return false
	return true


## 음식 하나 만들기. 등급 = 주재료 중 가장 좋은 것. 만든 등급 (못 만들면 0).
static func cook(id: StringName) -> int:
	var d: Dictionary = Config.FOODS[id]
	if not can_cook(id):
		var need: Array[String] = []
		for k: StringName in d.cost:
			need.append("%s %d (가진 것 %d)" % [display_name(k), d.cost[k], held(k)])
		GameState.notify("모자라다. %s: %s." % [d.name, " · ".join(need)])
		return 0
	var main_kind: StringName = d.main
	var grade := take_best(main_kind)
	for k: StringName in d.cost:
		take_low(k, int(d.cost[k]) - (1 if k == main_kind else 0))
	var f: Array = GameState.foods.get(id, [0, 0, 0]).duplicate()
	f[grade - 1] += 1
	GameState.foods[id] = f
	GameState.touch()
	GameState.notify("%s ★%d 을(를) 만들었다 (%s). 다음 사냥에 들어갈 때 먹는다: %s." % [d.name, grade, food_text(id), food_effect_text(id, grade)])
	FarmSkills.gain_for(&"cook")
	return grade


## 사냥에 들어갈 때: 음식마다 가장 좋은 것 하나를 뺀다. [[음식 id, 등급], ...]
static func eat_for_hunt() -> Array:
	var out: Array = []
	for id in Config.FOOD_ORDER:
		var f: Array = GameState.foods.get(id, [0, 0, 0]).duplicate()
		for g in [3, 2, 1]:
			if f[g - 1] > 0:
				f[g - 1] -= 1
				GameState.foods[id] = f
				out.append([id, g])
				break
	return out
