class_name Expedition
extends RefCounted
## 크리처 원정 + 입양 (2026-10-01 사용자 선택 B + D, "바글바글한 크리처 쓰기").
##
## 원정: 농부가 사냥터 입구에서 F → 대장을 한 번이라도 잡은 구역(GameState.bosses_beaten)마다 원정대 하나.
## 쉬는 · 채집 크리처 중 그 구역과 잘 맞는 크리처부터 3~5마리가 한 팀으로 떠나고 마을에서 사라진다.
## 원정대는 밤마다 다녀와서 아침 카드에 그 구역 돈 · 잡템 · 가끔 대장 재료 · 드물게 장비(공용 창고)를 내놓고,
## 불러들일 때까지 날마다 다시 떠난다 (Claude 기본값: 날마다 다시 보내는 손일이 없게).
## 알은 가져오지 않는다 (규칙: 알은 늘 사냥꾼이 야생에서). 돈은 5마리 보통 팀이 그 구역 사냥 한 번의 약 1/3 (사용자 기본값).
##
## 입양: 공급함에서 "크리처 입양 보내기" → 쉬는 · 채집 크리처를 고친 시설의 주민(대장장이 · 연금술사 · 목축인)에게 보낸다.
## 주민 곁에서 지내며 (일은 안 함, 마을 크리처 수에서 빠짐) 그 자리에서 한 번 작은 보답을 받는다. 되돌릴 수 없다.

const JOB := &"expedition"


# --- 원정 ---------------------------------------------------------------------

## 원정을 보낼 수 있는 구역 (대장을 잡은 구역, 번호 순)
static func zones() -> Array[int]:
	var out: Array[int] = []
	for z in Config.HUNT_ZONES.size():
		if z in GameState.bosses_beaten:
			out.append(z)
	return out


## 원정대 · 입양에 쓸 수 있는 크리처: 마을에 있고 들려 있지 않으며 쉬는 중 · 채집 중.
## 마지막으로 사냥에 데려간 크리처는 빼 둔다 (아끼는 동행이 떠나지 않게, Claude 기본값).
static func idle(main: Node2D) -> Array[Creature]:
	var out: Array[Creature] = []
	for s: Creature in main.creatures:
		if s != main.last_companion and s.carried_by == null and s.expedition_zone < 0 and (s.job == CreatureJobs.REST or s.job == CreatureJobs.FORAGE):
			out.append(s)
	return out


static func team(main: Node2D, zone: int) -> Array[Creature]:
	var out: Array[Creature] = []
	for s: Creature in main.creatures:
		if s.expedition_zone == zone:
			out.append(s)
	return out


static func away_count(main: Node2D) -> int:
	return main.creatures.filter(func(s: Creature) -> bool: return s.expedition_zone >= 0).size()


## 그 구역과 얼마나 잘 맞나: 그 구역 알에서 나온 종 x1.5, 속성이 맞으면 x1.25, 아니면 1
static func fit(data: CreatureData, zone: int) -> float:
	var e: Dictionary = Config.EXPEDITION_ZONES[zone]
	if data.species.id in e.species or data.species.courier:
		return Config.EXPEDITION_HOME_MULT
	for el in data.elements:
		if el.id in e.elements:
			return Config.EXPEDITION_ELEMENT_MULT
	return 1.0


## 팀 힘 = 크리처마다 fit 의 합 (5마리 보통 팀 = 5)
static func power(members: Array[Creature], zone: int) -> float:
	var p := 0.0
	for s in members:
		p += fit(s.data, zone)
	return p


## 원정대를 보낸다. 쉬는 · 채집 크리처 중 잘 맞는 크리처부터 limit (최대 EXPEDITION_TEAM_MAX) 마리. 보낸 수 (못 보내면 0).
static func send(main: Node2D, zone: int, limit := Config.EXPEDITION_TEAM_MAX) -> int:
	if zone not in zones() or not team(main, zone).is_empty():
		return 0
	var pool := idle(main)
	if mini(pool.size(), limit) < Config.EXPEDITION_TEAM_MIN:
		GameState.notify("원정대는 %d마리부터. 쉬는 · 채집 크리처가 %d마리뿐이다." % [Config.EXPEDITION_TEAM_MIN, pool.size()])
		return 0
	# 잘 맞는 크리처 먼저, 같으면 늦게 태어난 크리처 먼저 (오래 일한 크리처는 마을에 남게)
	var order := range(pool.size())
	order.sort_custom(func(a: int, b: int) -> bool:
		var fa := fit(pool[a].data, zone)
		var fb := fit(pool[b].data, zone)
		return fa > fb if fa != fb else a > b)
	var picked: Array[Creature] = []
	for i in order.slice(0, mini(limit, Config.EXPEDITION_TEAM_MAX)):
		picked.append(pool[i])
	for s in picked:
		depart(s, zone)
	var good := picked.filter(func(s: Creature) -> bool: return fit(s.data, zone) > 1.0).size()
	GameState.notify("%s 원정대 %d마리가 떠났다%s. 밤마다 다녀와서 아침에 가져온 것을 내놓는다 (알은 안 가져온다)." % [
		Config.HUNT_ZONES[zone].name, picked.size(), (" (잘 맞는 크리처 %d)" % good) if good > 0 else ""])
	return picked.size()


## 크리처 하나를 원정 중으로 (마을에서 숨기고 멈춤). 불러오기도 쓴다.
static func depart(s: Creature, zone: int) -> void:
	s.expedition_zone = zone
	s.job = JOB
	s.visible = false
	s.process_mode = Node.PROCESS_MODE_DISABLED


## 원정대를 불러들인다. 돌아온 크리처는 제자리에서 채집을 한다. 돌아온 수.
static func recall(main: Node2D, zone: int) -> int:
	var members := team(main, zone)
	for s in members:
		s.expedition_zone = -1
		s.job = CreatureJobs.FORAGE
		s.visible = true
		s.process_mode = Node.PROCESS_MODE_INHERIT
		s.position = Farm.center_of(s.home)
		s._reset_timer()
	if not members.is_empty():
		GameState.notify("%s 원정대 %d마리를 불러들였다. 제자리에서 채집을 한다." % [Config.HUNT_ZONES[zone].name, members.size()])
	return members.size()


## 밤사이 원정 (next_day 가 부른다). 원정대마다 가져온 것을 더하고 아침 카드 한 줄을 돌려준다. 원정대가 없으면 "".
static func night(main: Node2D, rng: RandomNumberGenerator) -> String:
	var teams := 0
	var members := 0
	var money := 0
	var junk := 0
	var mats := {}
	var gear := 0
	var gear_sold := 0
	for z in zones():
		var t := team(main, z)
		if t.is_empty():
			continue
		teams += 1
		members += t.size()
		var p := power(t, z) / float(Config.EXPEDITION_TEAM_MAX)
		# 크리처 레벨 (2026-10-03): 원정대는 밤마다 구역만큼 경험치
		for s in t:
			s.data.gain_xp(Config.CREATURE_XP_EXPEDITION * (z + 1))
		var e: Dictionary = Config.EXPEDITION_ZONES[z]
		money += roundi(rng.randi_range(e.money[0], e.money[1]) * p)
		junk += rng.randi_range(Config.EXPEDITION_JUNK[0], Config.EXPEDITION_JUNK[1])
		var zd: Dictionary = Config.HUNT_ZONES[z]
		if rng.randf() < Config.EXPEDITION_MATERIAL_CHANCE * p:
			if zd.get("boss_material", false):
				GameState.material += 1
				mats[Config.BOSS_MATERIAL_NAME] = mats.get(Config.BOSS_MATERIAL_NAME, 0) + 1
			elif zd.get("boss_material2", false):
				GameState.material2 += 1
				mats[Config.BOSS_MATERIAL2_NAME] = mats.get(Config.BOSS_MATERIAL2_NAME, 0) + 1
			elif zd.get("boss_material3", false):
				GameState.material3 += 1
				mats[Config.BOSS_MATERIAL3_NAME] = mats.get(Config.BOSS_MATERIAL3_NAME, 0) + 1
			elif zd.get("boss_material4", false):
				GameState.material4 += 1
				mats[Config.BOSS_MATERIAL4_NAME] = mats.get(Config.BOSS_MATERIAL4_NAME, 0) + 1
			elif zd.get("boss_material5", false):
				GameState.material5 += 1
				mats[Config.BOSS_MATERIAL5_NAME] = mats.get(Config.BOSS_MATERIAL5_NAME, 0) + 1
		if rng.randf() < Config.EXPEDITION_GEAR_CHANCE * p:
			# 원정 장비는 공용 창고로. 창고가 차 있으면 그 자리에서 판다.
			var roll := Wearables.roll_gear(rng, &"", zd.rarity)
			if GameState.stash.size() < Config.STASH_SIZE:
				GameState.gear_serial += 1
				var id := StringName("gear_%d" % GameState.gear_serial)
				GameState.gear[id] = roll
				GameState.stash.append(id)
				gear += 1
			else:
				gear_sold += Config.GEAR_SELL_PRICES[roll.rarity]
	if teams == 0:
		return ""
	GameState.money += money + gear_sold
	GameState.junk += junk
	var got: Array[String] = ["+%d원" % (money + gear_sold), "잡템 %d" % junk]
	for k: String in mats:
		got.append("%s %d" % [k, mats[k]])
	if gear > 0:
		got.append("장비 %d (공용 창고)" % gear)
	if gear_sold > 0:
		got.append("창고가 차서 장비를 팔았다")
	return "원정대 %d팀 (%d마리)이 돌아왔다가 다시 떠났다: %s" % [teams, members, " · ".join(got)]


static func zone_text(main: Node2D, zone: int) -> String:
	var zd: Dictionary = Config.HUNT_ZONES[zone]
	var t := team(main, zone)
	if not t.is_empty():
		var good := t.filter(func(s: Creature) -> bool: return fit(s.data, zone) > 1.0).size()
		return "%s 원정대 %d마리 (잘 맞음 %d) · 불러들이기" % [zd.name, t.size(), good]
	return "%s 원정 보내기 (잘 맞음: %s)" % [zd.name, Config.EXPEDITION_ZONES[zone].hint]


# --- 입양 ---------------------------------------------------------------------

## 크리처를 받아 줄 주민 (시설을 고친 주민, 정원이 남은 주민). 입양한 수가 적은 주민 먼저.
static func next_villager() -> StringName:
	var best := &""
	var best_n := Config.ADOPT_CAP
	for who: StringName in [&"smith", &"alchemist", &"rancher", &"ferryman", &"chief"]:
		if not villager_open(who):
			continue
		var n := adopted_by(who)
		if n < best_n:
			best = who
			best_n = n
	return best


static func villager_open(who: StringName) -> bool:
	match who:
		&"smith":
			return GameState.forge_state >= 2
		&"alchemist":
			return GameState.yak_state >= 2
		&"rancher":
			return GameState.barn_state >= 2
		&"ferryman":
			return GameState.naru_state >= 2
		&"chief":
			return GameState.hall_state >= 2
	return false


static func any_villager() -> bool:
	return [&"smith", &"alchemist", &"rancher", &"ferryman", &"chief"].any(func(w: StringName) -> bool: return villager_open(w))


static func adopted_by(who: StringName) -> int:
	return GameState.adopted.filter(func(a: Dictionary) -> bool: return a.who == who).size()


static func gift_text(who: StringName) -> String:
	var g: Dictionary = Config.ADOPT_GIFTS[who]
	return "%s %s" % [g.name, g.text]


## 크리처 하나를 다음 주민에게 입양 보낸다 (되돌릴 수 없음). 받은 주민 id, 못 보내면 &"".
static func adopt(main: Node2D, s: Creature) -> StringName:
	if s == null or s not in idle(main):
		return &""
	var who := next_villager()
	if who == &"":
		GameState.notify("받아 줄 주민이 없다 (시설을 고친 주민마다 %d마리까지)." % Config.ADOPT_CAP)
		return &""
	var d := s.data
	GameState.adopted.append({
		species = d.species.resource_path,
		elements = d.elements.map(func(e: CreatureElement) -> String: return e.resource_path),
		who = who,
	})
	main.creatures.erase(s)
	s.queue_free()
	var g: Dictionary = Config.ADOPT_GIFTS[who]
	match who:
		&"smith":
			GameState.scrap += g.count
		&"alchemist":
			GameState.potions += g.count
		&"rancher":
			GameState.lunches += g.count
		&"ferryman":
			GameState.fish += g.count
		&"chief":
			GameState.money += g.count
	spawn_adopted(main, GameState.adopted.size() - 1)
	GameState.notify("%s %s이(가) %s 곁에서 지내게 됐다. 보답으로 %s." % [d.element_names(), d.species.display_name, g.name, g.text])
	return who


## 입양된 크리처를 주민 곁에 그린다 (일은 안 함). 불러오기 때는 전부 다시 만든다.
static func spawn_adopted(main: Node2D, i: int) -> Creature:
	var a: Dictionary = GameState.adopted[i]
	var data := CreatureData.new()
	data.species = load(a.species)
	for e: String in a.elements:
		data.elements.append(load(e))
	var s := Creature.new()
	s.auto_work = false
	main.add_child(s)
	var n := GameState.adopted.slice(0, i).filter(func(o: Dictionary) -> bool: return o.who == a.who).size()
	var spots: Array = Config.ADOPT_SPOTS[a.who]
	s.setup(main.farm, data, spots[n % spots.size()])
	main.adoptees.append(s)
	return s


static func rebuild_adopted(main: Node2D) -> void:
	for s: Creature in main.adoptees:
		s.queue_free()
	main.adoptees.clear()
	for i in GameState.adopted.size():
		spawn_adopted(main, i)
