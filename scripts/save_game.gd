class_name SaveGame
extends RefCounted
## 저장/불러오기 (2026-09-30 사용자 선택 C 디아2식): 슬롯 3개, 잘 때 · 사냥터에서 돌아올 때 자동 저장,
## Esc 메뉴의 "저장하고 나가기"로 언제든 저장. 사냥터 안에서는 사냥터를 저장하지 않고 마을로 돌아온 채로 저장한다.
##
## 파일: user://save_<슬롯>.sav 하나에 Dictionary 하나 (FileAccess.store_var, 오브젝트는 넣지 않는다).
## GameState 변수는 이름으로 모두 담는다. 나중에 변수가 늘어도 옛 파일은 그 변수만 처음 값으로 읽힌다.
## 알 · 크리처의 종 · 속성 · Trait 같은 리소스는 파일 경로로 담는다.

## 2 = 마을 넓히기 (2026-10-01). 1 은 옛 26x15칸 마을 좌표라 읽을 때 새 배치로 옮긴다 (_migrate_v1).
## 3 = 주인공 하나 (2026-10-03). 2 까지는 조작 캐릭터가 일곱이라 읽을 때 주인공 하나로 옮긴다 (_migrate_v2).
const VERSION := 3
const SLOTS := 3

## 옛 마을 (VERSION 1, 26x15칸) 좌표. 옛 저장 파일의 칸을 새 배치로 옮길 때만 쓴다.
const V1_FIELD_PLOTS: Array[Rect2i] = [Rect2i(1, 2, 6, 4), Rect2i(7, 2, 6, 4), Rect2i(1, 6, 6, 4), Rect2i(7, 6, 6, 4)]
const V1_HATCH_CELL := Vector2i(16, 5)
## 옛 시설 앞 일하는 칸 (Creature.scrap_spot · herb_spot · feed_spot)
const V1_SCRAP_SPOT := Vector2i(8, 12)
const V1_HERB_SPOT := Vector2i(18, 11)
const V1_FEED_SPOT := Vector2i(17, 3)

## 저장 폴더 (테스트는 따로 쓴다)
static var dir := "user://"


static func path(slot: int) -> String:
	return dir.path_join("save_%d.sav" % slot)


static func exists(slot: int) -> bool:
	return FileAccess.file_exists(path(slot))


## 슬롯 목록에 보일 요약: {day, money, minutes}. 없거나 못 읽으면 {}.
static func summary(slot: int) -> Dictionary:
	var d := read(slot)
	if d.is_empty():
		return {}
	var gs: Dictionary = d.get("gs", {})
	return {day = gs.get("day", 1), money = gs.get("money", 0), minutes = gs.get("minutes", 0.0)}


static func read(slot: int) -> Dictionary:
	if not exists(slot):
		return {}
	var f := FileAccess.open(path(slot), FileAccess.READ)
	if f == null:
		return {}
	var d: Variant = f.get_var(false)
	return d if d is Dictionary and d.get("version", 0) >= 1 else {}


static func erase(slot: int) -> void:
	if exists(slot):
		DirAccess.remove_absolute(path(slot))


## main 의 지금 상태를 슬롯에 쓴다. 새 파일에 다 쓴 뒤 바꿔 넣어서, 쓰다가 꺼져도 옛 저장은 남는다.
static func save(main: Node2D, slot: int) -> bool:
	var d := snapshot(main)
	var tmp := path(slot) + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_var(d, false)
	f.close()
	if DirAccess.rename_absolute(tmp, path(slot)) != OK:
		return false
	return true


## 막 시작한 main (1일째 아침) 을 슬롯의 상태로 채운다. 없거나 못 읽으면 false.
static func load_into(main: Node2D, slot: int) -> bool:
	var d := read(slot)
	if d.is_empty():
		return false
	apply(main, d)
	return true


# --- 담기 --------------------------------------------------------------------

## 저장할 모든 상태를 Dictionary 하나로 (테스트는 저장 전후 이것을 비교한다)
static func snapshot(main: Node2D) -> Dictionary:
	var gs := {}
	for name in _state_vars():
		gs[name] = _pack(GameState.get(name))
	var cells := {}
	var farm: Farm = main.farm
	for cell: Vector2i in farm._cells:
		var c: Farm.Cell = farm._cells[cell]
		if c.tilled or c.planted or c.watered or c.growth > 0:
			cells[cell] = [c.tilled, c.planted, c.watered, c.growth, c.plowed, c.kind, c.picks, c.missed, c.fert, c.matched]
	var forage: Forage = main.forage
	var creatures: Array = []
	for s: Creature in main.creatures:
		var data := s.data
		# 들고 옮기는 중이면 든 사람 발밑에 놓은 것으로 담는다
		var home := s.home if s.carried_by == null else Farm.cell_of(s.carried_by.position)
		creatures.append({
			species = data.species.resource_path,
			trait_path = data.creature_trait.resource_path if data.creature_trait else "",
			elements = data.elements.map(func(e: CreatureElement) -> String: return e.resource_path),
			work_speed = data.base_work_speed,
			radius = data.base_radius,
			radius_level = data.radius_level,
			speed_level = data.speed_level,
			level = data.level,
			xp = data.xp,
			train_points = data.train_points,
			job = s.job,
			home = home,
			expedition = s.expedition_zone,
		})
	# 마을 사람 NPC 는 늘 제자리라 담지 않는다. 사냥터 안이면 주인공은 사냥터 입구 앞에 선 것으로 (돌아온 채로 저장)
	var player: Character = main.player
	var at := [player.position, player.facing]
	if main.hunt:
		at = [Farm.center_of(main.HUNT_GATE_RECT.position + Vector2i(1, main.HUNT_GATE_RECT.size.y)), Vector2i.DOWN]
	return {
		version = VERSION,
		gs = gs,
		farm = cells,
		forage = {herbs = forage.herbs.duplicate(), roots = forage.roots.duplicate(), watered = forage.watered.duplicate(), bonus_today = forage.bonus_today},
		creatures = creatures,
		incubating_days = main.incubating_days,
		incubating_species = main.incubating_species.resource_path if main.incubating_species else "",
		player = at,
		tool_index = main.tool_index,
	}


## GameState 에서 저장하는 변수 이름 (스크립트 변수 전부)
static func _state_vars() -> Array[String]:
	var out: Array[String] = []
	for p: Dictionary in GameState.get_script().get_script_property_list():
		if p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			out.append(p.name)
	return out


## 리소스(알의 종)는 경로로 바꾼다
static func _pack(v: Variant) -> Variant:
	if v is Array:
		return v.map(func(x: Variant) -> Variant: return {res = x.resource_path} if x is Resource else _pack(x))
	if v is Dictionary:
		return v.duplicate(true)
	return v


static func _unpack_into(name: String, v: Variant) -> void:
	var cur: Variant = GameState.get(name)
	if cur is Array:
		if not v is Array:
			return
		var items: Array = v.map(func(x: Variant) -> Variant: return load(x.res) if x is Dictionary and x.has("res") else x)
		(cur as Array).assign(items)
	elif cur is Dictionary:
		if v is Dictionary:
			GameState.set(name, v.duplicate(true))
	elif typeof(cur) == typeof(v) or (cur is float and v is int) or (cur is int and v is float):
		GameState.set(name, v)


# --- 되살리기 ----------------------------------------------------------------

static func apply(main: Node2D, d: Dictionary) -> void:
	if d.get("version", 1) < 2:
		d = _migrate_v1(d)
	if d.get("version", 1) < 3:
		d = _migrate_v2(d)
	var gs: Dictionary = d.get("gs", {})
	for name in _state_vars():
		if gs.has(name):
			_unpack_into(name, gs[name])
	# 옛 저장 (VERSION 2): 사냥꾼이 들고 있던 알은 이제 주인공 손에 (공급함을 거치지 않음)
	for x: Variant in gs.get("hunter_eggs", []):
		if x is Dictionary and x.has("res"):
			GameState.farmer_eggs.append(load(x.res))
	_refund_removed(gs)

	var farm: Farm = main.farm
	farm.sync_plots()
	for cell: Vector2i in d.get("farm", {}):
		var c := farm.get_cell(cell)
		if c == null:
			continue
		var v: Array = d.farm[cell]
		c.tilled = v[0]
		c.planted = v[1]
		c.watered = v[2]
		c.growth = v[3]
		# 깊이 간 칸 (2026-10-02 역동, 옛 저장 파일엔 없음)
		c.plowed = v[4] if v.size() > 4 else false
		# 밭 작물 (2026-10-03 농사 다양화, 옛 저장 파일은 모두 무)
		c.kind = StringName(v[5]) if v.size() > 5 and Config.CROPS.has(StringName(v[5])) else &"radish"
		c.picks = v[6] if v.size() > 6 else 0
		# 돌봄 점수 (2026-10-03 작물 등급, 옛 저장 파일엔 없음)
		c.missed = v[7] if v.size() > 7 else false
		c.fert = v[8] if v.size() > 8 else false
		c.matched = v[9] if v.size() > 9 else false
	farm.queue_redraw()

	# 시설: 터 → 고친 모습 (값은 이미 GameState 에 있으니 치르지 않는다)
	if GameState.forge_state >= 2:
		main.show_forge_restored()
	elif GameState.forge_state == 1:
		main.show_forge_site()
	if GameState.yak_state >= 2:
		main.show_yak_restored()
	elif GameState.yak_state == 1:
		main.show_yak_site()
	if GameState.barn_state >= 2:
		main.show_barn_restored()
	elif GameState.barn_state == 1:
		main.show_barn_site()
	if GameState.naru_state >= 2:
		main.show_naru_restored()
	elif GameState.naru_state == 1:
		main.show_naru_site()
	# 마을회관 · 잔치상 (2026-10-03 시설 5 · 엔딩)
	if GameState.hall_state >= 2:
		VillageHall.show_restored(main)
	elif GameState.hall_state == 1:
		VillageHall.show_site(main)
	if GameState.feast_state >= 1:
		VillageHall.show_feast(main)
	if GameState.feast_state >= 2:
		main.ambience.add_light(Vector2(Config.FEAST_RECT.position * Config.TILE) + Vector2(30, -30), 60, Color(1.0, 0.7, 0.45))

	# 들나물 자리 (시설 터를 놓은 뒤에 넣어야 막힌 칸에서 지워지지 않는다)
	var forage: Forage = main.forage
	var fd: Dictionary = d.get("forage", {})
	if fd.is_empty():
		# 옛 마을 저장: 들나물 자리가 바뀌어서 오늘 것을 새 풀밭에 다시 돋운다
		forage.watered.clear()
		forage.sprout(main._rng)
	else:
		_apply_forage(forage, fd)

	for cd: Dictionary in d.get("creatures", []):
		var data := CreatureData.new()
		data.species = load(cd.species)
		if cd.trait_path != "":
			data.creature_trait = load(cd.trait_path)
		for e: String in cd.elements:
			data.elements.append(load(e))
		data.base_work_speed = cd.work_speed
		data.base_radius = cd.radius
		data.radius_level = cd.radius_level
		data.speed_level = cd.speed_level
		# 크리처 레벨 (2026-10-03): 옛 저장은 훈련한 단계만큼 레벨이 오른 것으로 (남은 포인트 없음)
		data.level = cd.get("level", 1 + data.train_total())
		data.xp = cd.get("xp", 0)
		data.train_points = cd.get("train_points", 0)
		var s := main.add_creature(data, cd.home, cd.job) as Creature
		# 원정 중이던 크리처는 다시 원정 중으로 (Expedition)
		if cd.get("expedition", -1) >= 0:
			Expedition.depart(s, cd.expedition)
	# 시설 일을 맡았는데 일꾼 자리에 없는 크리처 (2026-10-03 전 저장) 는 빈 멍석으로, 자리가 없으면 쉰다
	FacilityWorkers.fix_after_load(main)
	# 입양 보낸 크리처는 GameState.adopted 로 담겨 있으니 주민 곁에 다시 그린다
	Expedition.rebuild_adopted(main)

	main.incubating_days = d.get("incubating_days", -1)
	var inc: String = d.get("incubating_species", "")
	main.incubating_species = load(inc) if inc != "" else null

	var player: Character = main.player
	var at: Array = d.get("player", [])
	if not at.is_empty():
		player.position = at[0]
		player.facing = at[1]
	# 주인공 모습 (2026-10-04, 옛 저장 파일엔 없음 = A)
	if not gs.has("look") or not Config.LOOKS.has(GameState.look):
		GameState.look = &"a"
	main.apply_look()
	main.tool_index = d.get("tool_index", 0)
	main._update_dusk()
	main._refresh_props()


static func _apply_forage(forage: Forage, fd: Dictionary) -> void:
	forage.herbs.assign(fd.get("herbs", {}))
	forage.roots.assign(fd.get("roots", {}))
	forage.watered.assign(fd.get("watered", {}))
	forage.claimed.clear()
	forage.bonus_today = fd.get("bonus_today", 0)
	forage.queue_redraw()


## 2026-10-05 시스템 줄이기(가볍게)로 없앤 것을 옛 저장 파일에서 돌려준다.
## 도구 손보기 · 튼튼한 사냥칼 → 산 값, 남은 힘 · 빠르기 물약 · 사냥 도시락 · 매운탕 → 하나에 빨간 물약 하나.
## (마을 옷 가게에서 산 옷은 그대로 가방 · 입은 칸에 남는다. 입양 보낸 크리처도 주민 곁에 그대로.)
static func _refund_removed(gs: Dictionary) -> void:
	var tools: Variant = gs.get("tool_levels", {})
	if tools is Dictionary:
		for work: Variant in tools:
			if int(tools[work]) > 0:
				GameState.money += Config.OLD_TOOL_REFUND if int(work) == Farm.Work.TILL else Config.OLD_CAN_REFUND if int(work) == Farm.Work.WATER else 0
	if gs.get("hunter_knife", false) == true:
		GameState.money += Config.OLD_KNIFE_REFUND
	for k: String in ["strength", "speed", "lunches", "stews"]:
		GameState.potions += maxi(0, int(gs.get(k, 0)))
	if GameState.yak_brew != &"" and not Config.BREWS.has(GameState.yak_brew):
		GameState.yak_brew = &""


# --- 옛 저장 파일 (VERSION 1) ---------------------------------------------------

## 옛 26x15칸 마을의 칸을 새 배치의 칸으로. 밭 칸은 같은 구역 같은 자리로, 시설 앞 일하는 칸 · 부화 칸은 새 자리로,
## 나머지 풀밭은 새 마을 공급함 옆 풀밭 칸으로 (채집 크리처는 어디서든 마을 풀밭을 돈다).
static func v1_cell(cell: Vector2i, spare_index := 0) -> Vector2i:
	for i in V1_FIELD_PLOTS.size():
		if V1_FIELD_PLOTS[i].has_point(cell):
			return cell - V1_FIELD_PLOTS[i].position + Config.FIELD_PLOTS[i].position
	match cell:
		V1_HATCH_CELL:
			return Config.HATCH_CELL
		V1_SCRAP_SPOT:
			return Creature.scrap_spot()
		V1_HERB_SPOT:
			return Creature.herb_spot()
		V1_FEED_SPOT:
			return Creature.feed_spot()
	return Config.FORAGE_CELLS[spare_index % Config.FORAGE_CELLS.size()]


## 옛 저장 Dictionary 를 새 배치 좌표로 바꾼 사본. 들나물은 비워서 다시 돋게 하고, 사람은 새 마을 처음 자리에 세운다.
static func _migrate_v1(d: Dictionary) -> Dictionary:
	var out := d.duplicate(true)
	var cells := {}
	for cell: Vector2i in d.get("farm", {}):
		cells[v1_cell(cell)] = d.farm[cell]
	out.farm = cells
	out.forage = {}
	var spare := 0
	for cd: Dictionary in out.get("creatures", []):
		var home: Vector2i = cd.home
		var moved := v1_cell(home, spare)
		if moved == Config.FORAGE_CELLS[spare % Config.FORAGE_CELLS.size()] and not _v1_special(home):
			spare += 1
		cd.home = moved
	out.people = {}
	out.version = 2
	return out


# --- 옛 저장 파일 (VERSION 2, 2026-10-03 주인공 하나 전) -----------------------

## 조작 캐릭터 일곱 → 주인공 하나. 주인공은 저장할 때 조작하던 사람 자리에 선다 (사람 자리가 없으면 새 게임 자리).
## 사냥꾼 레벨 · 직업 · 스탯 · 장비 (worn · bag 의 &"hunter" 벌)는 GameState 그대로 주인공의 사냥 옷이 되고,
## 농부 장비 (&"farmer" 벌)는 밭 옷이 된다. 사냥꾼이 들고 있던 알은 apply 가 주인공 손으로 옮긴다.
static func _migrate_v2(d: Dictionary) -> Dictionary:
	var out := d.duplicate(true)
	var people: Dictionary = d.get("people", {})
	var who: StringName = d.get("active", &"farmer")
	if people.has(who):
		out.player = people[who]
	elif people.has(&"farmer"):
		out.player = people[&"farmer"]
	out.erase("people")
	out.erase("active")
	out.version = VERSION
	return out


static func _v1_special(cell: Vector2i) -> bool:
	return V1_FIELD_PLOTS.any(func(r: Rect2i) -> bool: return r.has_point(cell)) or cell in [V1_HATCH_CELL, V1_SCRAP_SPOT, V1_HERB_SPOT, V1_FEED_SPOT]
