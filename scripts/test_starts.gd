class_name TestStarts
extends RefCounted
## 테스트용 시작 지점 (2026-09-29 사용자: "매번 처음부터 시작하는게 조금 어려운거같아").
## 개발용 빌드(에디터 F5)에서만 게임을 켜면 고르는 창이 뜬다. 진짜 저장/불러오기가 아니라
## 그 시점쯤의 상태를 매번 새로 채운다 (크리처 능력치 · 장비 옵션은 매번 조금씩 다르다).
## 숫자는 자동 플레이 봇(근거리 무기) 기록에서 어림한 임시값 (design/weapons/runs/knife1.md).

## 크리처: [종, 일, 속성 (&"" = 부화 때 굴린 대로), 훈련 범위 단계, 훈련 속도 단계]
## 농사 크리처는 열린 밭 구역 가운데에 차례로, 채집은 공급함 옆 풀밭, 고철 줍기는 고물 더미 옆에 놓는다.
## 무기: 앞의 것부터 얻어 첫 무기를 든다. 사냥꾼 방어구: [기본 장비, 등급]. 농부 제작품: 대장간 기본 장비.
const STARTS: Array[Dictionary] = [
	{id = &"fresh", name = "처음부터", note = "지금과 똑같이 1일째"},
	{
		id = &"hunter", name = "사냥꾼 막 열림", note = "2일 · 물 슬라임 1 · 첫 사냥 전",
		day = 2, money = 100, seeds = 4, plots = 1, planted = true,
		creatures = [[&"slime", &"farm", &"water", 0, 0]],
		waypoints = [0],
	},
	{
		id = &"day5", name = "5일째", note = "밭 2구역 · 슬라임 3 · 사냥 활",
		day = 5, money = 600, seeds = 10, plots = 2, planted = true,
		creatures = [[&"slime", &"farm", &"water", 0, 0], [&"slime", &"forage", &"water", 0, 0], [&"slime", &"forage", &"earth", 0, 0]],
		waypoints = [0, 1], weapons = [&"hunting_bow"], shop = [&"rain_boots"],
	},
	{
		id = &"forge_ready", name = "대장간 고치기 직전", note = "12일 · 복구 재료 다 모음",
		day = 12, money = 2400, seeds = 10, crops = 40, material = 12, plots = 4, planted = true,
		creatures = [
			[&"slime", &"farm", &"water", 0, 0], [&"slime", &"farm", &"", 0, 0], [&"slime", &"farm", &"", 0, 0], [&"slime", &"farm", &"", 0, 0],
			[&"slime", &"forage", &"earth", 0, 0], [&"gold_toad", &"forage", &"", 0, 0],
		],
		waypoints = [0, 1], forge = 1, tools = true, knife = true,
		weapons = [&"hunting_bow", &"water_staff"], shop = [&"rain_boots", &"seed_vest", &"hiking_shoes"],
		armor = [[&"leather_hood", &"magic"]],
	},
	{
		id = &"forge_done", name = "20일째 대장간 복구 뒤", note = "대장장이 · 광동리 열림 · 무기 3종",
		day = 20, money = 2600, seeds = 10, plots = 4, planted = true, scrap = 10,
		creatures = [
			[&"slime", &"farm", &"water", 1, 1], [&"slime", &"farm", &"", 1, 0], [&"slime", &"farm", &"", 0, 1], [&"slime", &"farm", &"", 0, 0],
			[&"slime", &"forage", &"earth", 0, 0], [&"slime", &"forage", &"water", 0, 0], [&"gold_toad", &"forage", &"", 0, 0],
			[&"slime", &"forage", &"earth", 0, 0], [&"slime", &"scrap", &"earth", 0, 0],
		],
		waypoints = [0, 1, 2], forge = 2, tools = true, knife = true,
		weapons = [&"hunting_bow", &"water_staff", &"long_sword"], shop = [&"rain_boots", &"seed_vest", &"hiking_shoes"],
		armor = [[&"leather_hood", &"magic"], [&"hunter_jerkin", &"magic"]],
	},
	{
		id = &"doma", name = "30일째 도마리 앞", note = "도마리 웨이포인트 · 크리처 12 · 장비 한 벌",
		day = 30, money = 4200, seeds = 20, plots = 4, planted = true, scrap = 6,
		creatures = [
			[&"slime", &"farm", &"water", 2, 2], [&"slime", &"farm", &"", 2, 1], [&"slime", &"farm", &"", 1, 1], [&"slime", &"farm", &"", 1, 1],
			[&"slime", &"forage", &"earth", 1, 0], [&"slime", &"forage", &"water", 0, 0], [&"gold_toad", &"forage", &"", 1, 0],
			[&"gold_toad", &"forage", &"", 0, 0], [&"sparrow", &"forage", &"", 0, 0], [&"sparrow", &"forage", &"", 0, 0],
			[&"slime", &"forage", &"earth", 0, 0], [&"slime", &"scrap", &"earth", 1, 1],
		],
		waypoints = [0, 1, 2, 3], forge = 2, tools = true, knife = true,
		weapons = [&"hunting_bow", &"water_staff", &"long_sword", &"crossbow"], shop = [&"straw_hat", &"ball_cap"],
		armor = [[&"leather_hood", &"rare"], [&"hunter_jerkin", &"magic"], [&"leather_shoes", &"magic"]],
		crafted = [&"work_cap", &"rain_suit", &"work_boots"],
	},
	{
		id = &"act3", name = "3막 입구", note = "45일 · 약방 · 연금술사 · 번천 웨이포인트",
		day = 45, money = 5200, seeds = 20, plots = 4, planted = true, scrap = 6, roots = 6, junk = 8, potions = 4, lamp_oil = 2,
		creatures = [
			[&"slime", &"farm", &"water", 2, 2], [&"slime", &"farm", &"", 2, 2], [&"slime", &"farm", &"", 2, 1], [&"tree_spirit", &"farm", &"", 1, 1],
			[&"slime", &"forage", &"earth", 1, 1], [&"slime", &"forage", &"water", 0, 0], [&"gold_toad", &"forage", &"", 1, 0],
			[&"gold_toad", &"forage", &"", 0, 0], [&"sparrow", &"forage", &"", 0, 0], [&"sparrow", &"forage", &"", 0, 0],
			[&"slime", &"forage", &"earth", 0, 0], [&"slime", &"scrap", &"earth", 1, 1], [&"slime", &"herb", &"earth", 0, 0],
		],
		waypoints = [0, 1, 2, 3, 4], forge = 2, yak = 2, tools = true, knife = true,
		weapons = [&"hunting_bow", &"water_staff", &"long_sword", &"crossbow"], shop = [&"straw_hat", &"ball_cap"],
		armor = [[&"leather_hood", &"rare"], [&"hunter_jerkin", &"rare"], [&"leather_shoes", &"magic"]],
		crafted = [&"work_cap", &"rain_suit", &"work_boots"],
	},
	{
		## 2026-09-30 밀목 스레드: 3막 둘째 구역을 바로 해 보는 자리 (번천 막차를 잡아 밀목 웨이포인트가 켜진 뒤)
		id = &"milmok", name = "밀목 앞", note = "55일 · 밀목 웨이포인트 · 아기 도깨비불 · 물약",
		day = 55, money = 6500, seeds = 20, plots = 4, planted = true, scrap = 6, roots = 8, junk = 10, potions = 6, lamp_oil = 1, strength = 2,
		creatures = [
			[&"slime", &"farm", &"water", 2, 2], [&"slime", &"farm", &"", 2, 2], [&"slime", &"farm", &"", 2, 2], [&"tree_spirit", &"farm", &"", 1, 1],
			[&"slime", &"forage", &"earth", 1, 1], [&"slime", &"forage", &"water", 0, 0], [&"gold_toad", &"forage", &"", 1, 0],
			[&"gold_toad", &"forage", &"", 0, 0], [&"sparrow", &"forage", &"", 0, 0], [&"will_o", &"herb", &"", 1, 0],
			[&"will_o", &"forage", &"", 0, 0], [&"slime", &"scrap", &"earth", 1, 1], [&"slime", &"herb", &"earth", 0, 0],
		],
		waypoints = [0, 1, 2, 3, 4, 5], forge = 2, yak = 2, tools = true, knife = true,
		weapons = [&"hunting_bow", &"water_staff", &"long_sword", &"crossbow", &"long_bow"], shop = [&"straw_hat", &"ball_cap"],
		armor = [[&"leather_hood", &"rare"], [&"hunter_jerkin", &"rare"], [&"leather_shoes", &"rare"]],
		crafted = [&"work_cap", &"rain_suit", &"work_boots"],
	},
	{
		## 2026-09-30 밀목 스레드: 축사를 고친 직후 (닭장 · 목축인 · 아기 호랑이 모이 주기)
		id = &"barn", name = "70일째 축사 복구 뒤", note = "목축인 · 암탉 3 · 아기 호랑이 · 도시락 1",
		day = 70, money = 3000, seeds = 20, crops = 10, plots = 4, planted = true, scrap = 6, roots = 8, junk = 10, potions = 6, lamp_oil = 1,
		creatures = [
			[&"slime", &"farm", &"water", 2, 2], [&"slime", &"farm", &"", 2, 2], [&"slime", &"farm", &"", 2, 2], [&"tree_spirit", &"farm", &"", 2, 1],
			[&"slime", &"forage", &"earth", 1, 1], [&"slime", &"forage", &"water", 0, 0], [&"gold_toad", &"forage", &"", 1, 0],
			[&"gold_toad", &"forage", &"", 0, 0], [&"sparrow", &"forage", &"", 0, 0], [&"will_o", &"herb", &"", 1, 0],
			[&"tiger", &"feed", &"", 0, 0], [&"slime", &"scrap", &"earth", 1, 1], [&"slime", &"herb", &"earth", 0, 0],
		],
		waypoints = [0, 1, 2, 3, 4, 5], forge = 2, yak = 2, barn = 2, hens = 3, lunches = 1, tools = true, knife = true,
		weapons = [&"hunting_bow", &"water_staff", &"long_sword", &"crossbow", &"long_bow"], shop = [&"straw_hat", &"ball_cap"],
		armor = [[&"leather_hood", &"rare"], [&"hunter_jerkin", &"rare"], [&"leather_shoes", &"rare"]],
		crafted = [&"work_cap", &"rain_suit", &"work_boots"],
	},
]

const SPECIES := {
	&"slime": "res://data/creatures/species/slime.tres",
	&"gold_toad": "res://data/creatures/species/gold_toad.tres",
	&"sparrow": "res://data/creatures/species/sparrow.tres",
	&"tree_spirit": "res://data/creatures/species/tree_spirit.tres",
	&"will_o": "res://data/creatures/species/will_o.tres",
	&"tiger": "res://data/creatures/species/tiger.tres",
}
const ELEMENTS := {
	&"water": "res://data/creatures/elements/water.tres",
	&"earth": "res://data/creatures/elements/earth.tres",
}
## 채집 크리처를 놓는 풀밭 칸 (공급함 옆, 봇이 쓰는 (15, 7) 둘레)
const FORAGE_CELLS: Array[Vector2i] = [Vector2i(15, 7), Vector2i(14, 7), Vector2i(15, 8), Vector2i(14, 8), Vector2i(13, 7), Vector2i(13, 8), Vector2i(16, 7), Vector2i(16, 8)]


static func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for s: Dictionary in STARTS:
		out.append(s.id)
	return out


static func find(id: StringName) -> Dictionary:
	for s: Dictionary in STARTS:
		if s.id == id:
			return s
	return {}


static func option_text(id: StringName) -> String:
	var s := find(id)
	return "%d. %s   (%s)" % [STARTS.find(s) + 1, s.name, s.note]


## 막 시작한 main (1일째 아침) 을 시작 지점 id 의 상태로 채운다. 모르는 id 면 false.
static func apply(main: Node2D, id: StringName) -> bool:
	var s := find(id)
	if s.is_empty():
		return false
	if id == &"fresh":
		return true
	var rng: RandomNumberGenerator = main._rng
	GameState.day = s.day
	GameState.money = s.get("money", 0)
	GameState.seeds = s.get("seeds", 0)
	GameState.crops = s.get("crops", 0)
	GameState.material = s.get("material", 0)
	# 처음 공급함에 든 알은 이미 받아 부화시킨 뒤
	GameState.village_eggs.clear()
	GameState.hunter_unlocked = true
	GameState.first_egg_done = true
	GameState.waypoints.assign(s.get("waypoints", [0]))
	# 구역 대장 첫 처치 선물(무기)은 들고 시작하는 만큼 이미 받은 것으로 친다
	for z: int in Config.FIRST_WEAPON_DROPS:
		if Config.FIRST_WEAPON_DROPS[z] in s.get("weapons", []):
			GameState.weapon_gifts.append(z)
	if s.get("tools", false):
		# 넓은 괭이 · 큰 물뿌리개
		GameState.tool_levels[Farm.Work.TILL] = 1
		GameState.tool_levels[Farm.Work.WATER] = 1
	GameState.hunter_knife = s.get("knife", false)

	var farm: Farm = main.farm
	for i in s.get("plots", 1) - GameState.open_plots:
		farm.open_next_plot()
	if s.get("planted", false):
		_plant_open_plots(farm, rng)

	var forage_i := 0
	for c: Array in s.get("creatures", []):
		var at := Vector2i.ZERO
		match c[1]:
			CreatureJobs.FARM:
				var plot := Config.FIELD_PLOTS[mini(main.creatures.filter(func(x: Creature) -> bool: return x.job == CreatureJobs.FARM).size(), GameState.open_plots - 1)]
				at = plot.position + plot.size / 2
			CreatureJobs.SCRAP:
				at = Creature.scrap_spot()
			CreatureJobs.HERB:
				at = Creature.herb_spot()
			CreatureJobs.FEED:
				at = Creature.feed_spot()
			_:
				at = FORAGE_CELLS[forage_i % FORAGE_CELLS.size()]
				forage_i += 1
		var cr: Creature = main._hatch(load(SPECIES[c[0]]), at, load(ELEMENTS[c[2]]) if c[2] != &"" else null)
		cr.job = c[1]
		cr.data.radius_level = c[3]
		cr.data.speed_level = c[4]

	var forge_state: int = s.get("forge", 0)
	if forge_state >= 1:
		GameState.forge_boss_down = true
		main.show_forge_site()
	if forge_state >= 2:
		# 복구비만큼 잠깐 채워서 실제 복구 흐름으로 고친다
		GameState.money += Config.FORGE_COST_MONEY
		GameState.crops += Config.FORGE_COST_CROPS
		GameState.material += Config.FORGE_COST_MATERIAL
		main.restore_forge()
	GameState.scrap = s.get("scrap", 0)
	var yak_state: int = s.get("yak", 0)
	if yak_state >= 1:
		GameState.yak_boss_down = true
		main.show_yak_site()
	if yak_state >= 2:
		GameState.money += Config.YAK_COST_MONEY
		GameState.roots += Config.YAK_COST_ROOTS
		GameState.material2 += Config.YAK_COST_MATERIAL
		main.restore_yak()
	var barn_state: int = s.get("barn", 0)
	if barn_state >= 1:
		GameState.barn_boss_down = true
		main.show_barn_site()
	if barn_state >= 2:
		GameState.money += Config.BARN_COST_MONEY
		GameState.crops += Config.BARN_COST_CROPS
		GameState.material3 += Config.BARN_COST_MATERIAL
		main.restore_barn()
		GameState.hens = s.get("hens", Config.START_HENS)
	GameState.lunches = s.get("lunches", 0)
	GameState.strength = s.get("strength", 0)
	GameState.roots = s.get("roots", 0)
	GameState.junk = s.get("junk", 0)
	GameState.potions = s.get("potions", 0)
	GameState.lamp_oil = s.get("lamp_oil", 0)

	for item: StringName in s.get("shop", []):
		Wearables.gain_and_wear(item)
	for base: StringName in s.get("weapons", []):
		var roll := Wearables.roll_crafted(rng, base) if Wearables.ITEMS[base].get("from") == &"forge" else Wearables.roll_gear(rng, &"normal", {}, base)
		Wearables.gain_rolled(roll)
	for a: Array in s.get("armor", []):
		Wearables.gain_rolled(Wearables.roll_gear(rng, a[1], {}, a[0]))
	for base: StringName in s.get("crafted", []):
		Wearables.gain_rolled(Wearables.roll_crafted(rng, base))
	main.farmer.refresh_wear()
	main.hunter.refresh_wear()

	main._refresh_props()
	GameState.notify("테스트 시작: %s (%d일째). 개발용 빌드에서만 고를 수 있다." % [s.name, GameState.day])
	return true


## 열린 밭을 모두 갈고 심어 둔다 (자라는 정도는 칸마다 다르게, 물은 아침이라 아직)
static func _plant_open_plots(farm: Farm, rng: RandomNumberGenerator) -> void:
	for p in GameState.open_plots:
		var plot := Config.FIELD_PLOTS[p]
		for x in range(plot.position.x, plot.end.x):
			for y in range(plot.position.y, plot.end.y):
				var cell := farm.get_cell(Vector2i(x, y))
				cell.tilled = true
				cell.planted = true
				cell.watered = false
				cell.growth = rng.randi_range(0, Config.CROP_GROW_DAYS - 1)
	farm.queue_redraw()
