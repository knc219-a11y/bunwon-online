class_name SaveGame
extends RefCounted
## 저장/불러오기 (2026-09-30 사용자 선택 C 디아2식): 슬롯 3개, 잘 때 · 사냥터에서 돌아올 때 자동 저장,
## Esc 메뉴의 "저장하고 나가기"로 언제든 저장. 사냥터 안에서는 사냥터를 저장하지 않고 마을로 돌아온 채로 저장한다.
##
## 파일: user://save_<슬롯>.sav 하나에 Dictionary 하나 (FileAccess.store_var, 오브젝트는 넣지 않는다).
## GameState 변수는 이름으로 모두 담는다. 나중에 변수가 늘어도 옛 파일은 그 변수만 처음 값으로 읽힌다.
## 알 · 크리처의 종 · 속성 · Trait 같은 리소스는 파일 경로로 담는다.

const VERSION := 1
const SLOTS := 3

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
			cells[cell] = [c.tilled, c.planted, c.watered, c.growth]
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
			job = s.job,
			home = home,
			expedition = s.expedition_zone,
		})
	var people := {}
	for c: Character in [main.farmer, main.hunter, main.smith, main.alchemist, main.rancher]:
		people[c.who] = [c.position, c.facing]
	# 사냥터 안이면 사냥꾼은 사냥터 입구 앞에 선 것으로 (돌아온 채로 저장)
	if main.hunt:
		people[&"hunter"] = [Farm.center_of(main.HUNT_GATE_RECT.position + Vector2i(1, main.HUNT_GATE_RECT.size.y)), Vector2i.DOWN]
	return {
		version = VERSION,
		gs = gs,
		farm = cells,
		forage = {herbs = forage.herbs.duplicate(), roots = forage.roots.duplicate(), watered = forage.watered.duplicate(), bonus_today = forage.bonus_today},
		creatures = creatures,
		incubating_days = main.incubating_days,
		incubating_species = main.incubating_species.resource_path if main.incubating_species else "",
		people = people,
		active = main.active.who if main.hunt == null else &"hunter",
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
	var gs: Dictionary = d.get("gs", {})
	for name in _state_vars():
		if gs.has(name):
			_unpack_into(name, gs[name])

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

	# 들나물 자리 (시설 터를 놓은 뒤에 넣어야 막힌 칸에서 지워지지 않는다)
	var forage: Forage = main.forage
	var fd: Dictionary = d.get("forage", {})
	forage.herbs.assign(fd.get("herbs", {}))
	forage.roots.assign(fd.get("roots", {}))
	forage.watered.assign(fd.get("watered", {}))
	forage.claimed.clear()
	forage.bonus_today = fd.get("bonus_today", 0)
	forage.queue_redraw()

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
		var s := main.add_creature(data, cd.home, cd.job) as Creature
		# 원정 중이던 크리처는 다시 원정 중으로 (Expedition)
		if cd.get("expedition", -1) >= 0:
			Expedition.depart(s, cd.expedition)
	# 입양 보낸 크리처는 GameState.adopted 로 담겨 있으니 주민 곁에 다시 그린다
	Expedition.rebuild_adopted(main)

	main.incubating_days = d.get("incubating_days", -1)
	var inc: String = d.get("incubating_species", "")
	main.incubating_species = load(inc) if inc != "" else null

	var people: Dictionary = d.get("people", {})
	for c: Character in [main.farmer, main.hunter, main.smith, main.alchemist, main.rancher]:
		if people.has(c.who):
			c.position = people[c.who][0]
			c.facing = people[c.who][1]
		c.refresh_wear()
	var who: StringName = d.get("active", &"farmer")
	for c: Character in [main.farmer, main.hunter, main.smith, main.alchemist, main.rancher]:
		if c.who == who and c.visible:
			main._set_active(c)
	main.tool_index = d.get("tool_index", 0)
	main._update_dusk()
	main._refresh_props()
