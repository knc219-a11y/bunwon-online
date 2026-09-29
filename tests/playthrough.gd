extends Node
## 핵심 루프 점검용 자동 플레이 (2026-09-28). 새 게임에서 며칠을 "보통 플레이어"처럼 돌리고 숫자를 남긴다.
## 실행: godot --headless --path . res://tests/playthrough.tscn   (환경변수 DAYS=10 SEED=1 OUT=경로)
## 농사는 칸마다 도구를 쓰는 횟수를 세고, 사냥은 길찾기 봇이 실제 사냥터(실시간 AI)에서 싸운다.
## 봇은 사람보다 서툴 수도 잘할 수도 있으니, 숫자는 흐름을 보는 참고값이다.

const DT := 1.0 / 30.0
var main: Node2D
var farm: Farm
var log_lines: Array[String] = []
var days := 10
var manual_actions := 0
## 사냥 봇이 예고(붉은 띠·그림자 원)를 알아채기까지 걸리는 시간 (사람 반응 속도쯤, 초)
const REACT := 0.3
## 지난 사냥에서 쓰러진 구역 (다음 날은 한 구역 아래 웨이포인트부터)
var knocked_zone := -1
## 사냥 하루 합계 (끝에 요약)
var hunt_days := 0
var hunt_hurt := 0
var hunt_knocked := 0
var cleared_day := {}
## 하루 시계 (2026-09-29): 봇은 도구질을 순간에 끝내므로 실제 걸릴 시간을 어림한다 (초, 임시 어림값).
## 손 도구질 한 번 = 휘두르기 + 한 칸 걷기, 들나물 한 포기 = 풀밭까지 걷기, 공급함·부화기·집 오가기 = 하루 한 번에 묶어서.
const HAND_SEC := 1.0
const HERB_SEC := 4.0
const WALK_SEC := 30.0
## 사람은 봇보다 느리게 움직인다고 보고 두 배로도 적어 둔다
const HUMAN_MULT := 2.0
var hand_sec := 0.0
var creature_sec := 0.0
var hunt_sec := 0.0
var clock_ends: Array[String] = []
## 크리처 채집 (2026-09-29 사용자 선택 B): 들나물을 누가 캤는지, 도라지 뿌리, 손일 합계
var total_manual := 0
var total_hand_herbs := 0
var total_creature_herbs := 0
var total_roots := 0
## 채집 크리처가 사는 자리 (밭이 아니라 공급함 옆 풀밭)
const FORAGE_HOME := Vector2i(15, 7)
## 크리처 일 배분 (2026-09-29 선택 A+B): 열린 밭 구역이 모두 농사 크리처로 찬 첫날, 농사 크리처가 한가할 때 캔 나물,
## 물 준 풀밭 덕분에 더 돋은 포기
var full_day := -1
var total_idle_herbs := 0
var total_water_bonus := 0
## 대장간 (2026-09-29 사용자 선택 A): 터가 나타난 날 · 고친 날 · 복구비를 모으느라 무언가를 안 산 날 ·
## 만든 장비 수 · 크리처가 주운 고철 · 날마다 번 돈(쓰기 전) · 날마다 쓴 돈
var site_day := -1
var restore_day := -1
var held_days: Array[int] = []
var crafted := 0
var craft_spent := 0
var gross: Array[int] = []
var spent_today := 0
var scrap_creature: Creature = null
## 광동리 (2026-09-29 선택 B): 처음 도착한 날 · 광동리에서 사냥한 날 수 · 거기서 맞은 횟수 · 쓰러진 횟수 · 날마다 끝 돈
var gwang_day := -1
var gwang_hunts := 0
var gwang_hurt := 0
var gwang_knocked := 0
var money_by_day := {}
## 도마리 (2026-09-29, 2막 마지막 구역): 처음 도착한 날 · 사냥한 날 수 · 거기서 맞은 횟수 · 쓰러진 횟수
var doma_day := -1
var doma_hunts := 0
var doma_hurt := 0
var doma_knocked := 0
const DOMA := 3


func _ready() -> void:
	days = int(OS.get_environment("DAYS")) if OS.get_environment("DAYS") != "" else 10
	var rng_seed := int(OS.get_environment("SEED")) if OS.get_environment("SEED") != "" else 1
	seed(rng_seed)
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	main._rng.seed = rng_seed
	# 시계는 봇이 어림한 시간으로 돌린다 (크리처를 기다리며 빨리 돌리는 동안 시계가 흐르지 않게)
	main.clock_running = false
	farm = main.farm
	Engine.time_scale = 1.0
	_log("# 자동 플레이 seed=%d" % rng_seed)
	for d in days:
		await play_day()
	var trained := 0
	for s: Creature in main.creatures:
		trained += s.data.train_total()
	_log("\n사냥: %d번 · 맞은 횟수 %d (하루 평균 %.1f) · 쓰러짐 %d번 · 대장 처음 쓰러뜨린 날 %s" % [hunt_days, hunt_hurt, float(hunt_hurt) / maxi(hunt_days, 1), hunt_knocked, cleared_day])
	_log("\n하루 끝 시각 (봇 · 사람 어림 x%.0f, 6시 시작, 실제 1초 = 게임 %s분): %s" % [HUMAN_MULT, Config.CLOCK_MINUTES_PER_SECOND, ", ".join(clock_ends)])
	_log("\n들나물·채집 (14일 합계): 손일 %d번 · 들나물 손으로 %d포기 · 크리처가 %d포기 · 도라지 %d뿌리 (%d원)" % [total_manual, total_hand_herbs, total_creature_herbs, total_roots, total_roots * Config.ROOT_PRICE])
	_log("\n크리처 일 배분 (14일 합계): 밭 4구역이 모두 농사로 찬 날 %s · 농사 크리처가 한가할 때 캔 나물·뿌리 %d · 물 준 풀밭 덕분에 더 돋은 나물 %d포기" % ["%d일" % full_day if full_day > 0 else "없음", total_idle_herbs, total_water_bonus])
	var last := gross.slice(maxi(0, gross.size() - 7))
	var avg := 0.0
	for g in last:
		avg += g
	avg /= maxf(last.size(), 1)
	var scrap_by_creature := scrap_creature.scraps if scrap_creature else 0
	_log("\n대장간: 터 %s · 복구 %s · 복구비를 모으느라 안 산 날 %s · 장비 제작 %d번 (%d원) · 크리처가 주운 고철 %d · 마지막 7일 하루 벌이 평균 %.0f원 · 끝에 남은 돈 %d원 = 하루 벌이의 %.1f배" % [
		"%d일" % site_day if site_day > 0 else "없음", "%d일" % restore_day if restore_day > 0 else "없음", held_days, crafted, craft_spent, scrap_by_creature, avg, GameState.money, GameState.money / maxf(avg, 1.0)])
	var money_at := []
	for d in [30, 35, 40]:
		if money_by_day.has(d):
			money_at.append("%d일 %d원" % [d, money_by_day[d]])
	_log("\n광동리: 첫 도착 %s · 첫 대장 처치 %s · 광동리 사냥 %d번 · 거기서 맞은 횟수 %d (한 번에 %.1f) · 쓰러짐 %d번 · 끝 돈 %s · 아기 참새 %d마리" % [
		"%d일" % gwang_day if gwang_day > 0 else "없음", cleared_day.get(Config.HUNT_ZONES[2].name, "없음"), gwang_hunts, gwang_hurt,
		float(gwang_hurt) / maxi(gwang_hunts, 1), gwang_knocked, money_at, main.creatures.filter(func(c: Creature) -> bool: return c.data.species == CreatureCatalog.SPARROW).size()])
	var money_late := []
	for d in [40, 45, 50]:
		if money_by_day.has(d):
			money_late.append("%d일 %d원" % [d, money_by_day[d]])
	_log("\n도마리: 첫 도착 %s · 2막 대장(장승 한 쌍) 첫 처치 %s · 도마리 사냥 %d번 · 거기서 맞은 횟수 %d (한 번에 %.1f) · 쓰러짐 %d번 · 끝 돈 %s · 아기 나무 정령 %d마리" % [
		"%d일" % doma_day if doma_day > 0 else "없음", cleared_day.get(Config.HUNT_ZONES[DOMA].name, "없음"), doma_hunts, doma_hurt,
		float(doma_hurt) / maxi(doma_hunts, 1), doma_knocked, money_late, main.creatures.filter(func(c: Creature) -> bool: return c.data.species == CreatureCatalog.TREE_SPIRIT).size()])
	_log("입은 장비: 농부 %s · 사냥꾼 %s" % [_worn_text(&"farmer"), _worn_text(&"hunter")])
	_log("\n최종: %d일째, 돈 %d원, 씨앗 %d, 크리처 %d (훈련 단계 합 %d), 밭 구역 %d, 웨이포인트 %s" % [GameState.day, GameState.money, GameState.seeds, main.creatures.size(), trained, GameState.open_plots, GameState.waypoints])
	var out := OS.get_environment("OUT")
	if out != "":
		var f := FileAccess.open(out, FileAccess.WRITE)
		f.store_string("\n".join(log_lines))
	get_tree().quit()


func _worn_text(who: StringName) -> String:
	var out: Array[String] = []
	for id in Wearables.worn_by(who):
		var it := Wearables.item(id)
		out.append("%s(%s)" % [it.name, it.effect])
	return ", ".join(out)


func _log(t: String) -> void:
	print(t)
	log_lines.append(t)


func play_day() -> void:
	manual_actions = 0
	hand_sec = 0.0
	creature_sec = 0.0
	hunt_sec = 0.0
	var money0 := GameState.money
	var herbs0 := GameState.displayed_herbs
	spent_today = 0
	if GameState.forge_state >= 1 and site_day < 0:
		site_day = GameState.day
	_log("\n## %d일째 (시작 돈 %d, 씨앗 %d, 작물 %d)" % [GameState.day, GameState.money, GameState.seeds, GameState.crops])
	main._set_active(main.farmer)
	await place_new_creatures()
	await let_creatures_work()
	var farm_counts := farm_by_hand()
	await let_creatures_work()
	farm_counts.merge(farm_by_hand(), true)
	var herbs := forage()
	if herbs > 0:
		farm_counts["들나물"] = herbs
	var m_shop := GameState.money
	var bought := shop()
	spent_today += m_shop - GameState.money
	# 산 뒤(밭을 넓혔거나 씨앗을 샀으면) 한 번 더 심는다
	var more := farm_by_hand()
	for k in more:
		farm_counts[k] = farm_counts.get(k, 0) + more[k]
	await let_creatures_work()
	incubate()
	_log("농부: 손으로 한 도구질 %d번 %s · 공급함: %s" % [manual_actions, farm_counts, bought])
	var creature_herbs := GameState.displayed_herbs - herbs0 - herbs
	if creature_herbs > 0 or GameState.displayed_roots > 0:
		_log("크리처 채집: 들나물 %d포기 · %s %d뿌리 진열 (내일 물 준 풀밭 %d칸)" % [creature_herbs, Config.ROOT_NAME, GameState.displayed_roots, main.forage.watered.size()])
	total_manual += manual_actions
	total_hand_herbs += herbs
	total_creature_herbs += creature_herbs
	var idle := 0
	for s: Creature in main.creatures:
		if s.job == CreatureJobs.FARM:
			idle += s.picks
		s.picks = 0
	total_idle_herbs += idle
	var farmers: int = main.creatures.filter(func(s: Creature) -> bool: return s.job == CreatureJobs.FARM).size()
	var foragers: int = main.creatures.filter(func(s: Creature) -> bool: return s.job == CreatureJobs.FORAGE).size()
	_log("크리처 일: 농사 %d · 채집 전담 %d (밭 구역 %d) · 농사 크리처가 한가할 때 캔 것 %d" % [farmers, foragers, GameState.open_plots, idle])
	total_roots += GameState.displayed_roots
	var planted := 0
	var watered := 0
	for c: Vector2i in farm._cells:
		var cell: Farm.Cell = farm._cells[c]
		planted += int(cell.planted)
		watered += int(cell.watered)
	_log("밭: 열린 칸 %d · 심은 칸 %d · 물 준 칸 %d" % [farm._cells.size(), planted, watered])
	hand_sec += manual_actions * HAND_SEC + farm_counts.get("들나물", 0) * (HERB_SEC - HAND_SEC) + WALK_SEC
	if GameState.hunter_unlocked:
		await hunt_day()
	# 크리처는 농부가 손일하는 동안 같이 일한다 (더 긴 쪽). 사냥은 그 뒤 따로.
	var bot_sec := maxf(hand_sec, creature_sec) + hunt_sec
	var human_sec := maxf(hand_sec * HUMAN_MULT, creature_sec) + hunt_sec * HUMAN_MULT
	main.advance_clock(bot_sec * Config.CLOCK_MINUTES_PER_SECOND)
	var bot_end := GameState.clock_text(Config.DAY_START_MINUTE + bot_sec * Config.CLOCK_MINUTES_PER_SECOND)
	var human_end := GameState.clock_text(minf(Config.DAY_START_MINUTE + human_sec * Config.CLOCK_MINUTES_PER_SECOND, Config.CLOCK_MAX_MINUTE))
	clock_ends.append("%d일 %s · %s" % [GameState.day, bot_end.split(" ")[1] if bot_end.begins_with("오전") else bot_end, human_end])
	_log("시간: 손일 약 %.0f초 · 크리처 일 %.0f초 · 사냥 %.0f초 → 잠자리 시각 %s (사람 어림 %s)" % [hand_sec, creature_sec, hunt_sec, bot_end, human_end])
	var lines: Array[String] = main.next_day()
	var cap := OS.get_environment("CAPTURE")
	if cap != "":
		# 아침 카드를 실제 게임처럼 띄워 찍는다
		main.show_morning_card(lines)
		for i in 3:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("%s/morning_day%02d.png" % [cap, GameState.day])
		main._morning_card.visible = false
	_log("밤 → 아침 카드: %s" % " / ".join(lines))
	total_water_bonus += main.forage.bonus_today
	gross.append(GameState.money - money0 + spent_today)
	money_by_day[GameState.day - 1] = GameState.money
	_log("하루 수입 %+d원 · 부화 기다리는 알 %d개 (농부 %d · 공급함 %d)" % [GameState.money - money0, GameState.farmer_eggs.size() + GameState.village_eggs.size(), GameState.farmer_eggs.size(), GameState.village_eggs.size()])


## 부화기 옆에 나온 새 크리처를 밭에 놓고 일을 정한다.
## 크리처 일 배분 (2026-09-29 선택 A+B): 열린 밭 구역마다 농사 한 마리, 남는 크리처는 채집 전담.
## 밭 구역이 새로 열리면 채집 전담 하나를 그 구역 농사로 옮긴다 (플레이어가 할 법한 배치).
func place_new_creatures() -> void:
	var farmers := 0
	for s: Creature in main.creatures:
		if s.home != main.HATCH_CELL and s.job == CreatureJobs.FARM:
			farmers += 1
	for s: Creature in main.creatures:
		if farmers >= GameState.open_plots:
			break
		if s.home != main.HATCH_CELL and s.job == CreatureJobs.FORAGE and s != scrap_creature and s.data.species != CreatureCatalog.SPARROW:
			_assign(s, CreatureJobs.FARM, farmers)
			farmers += 1
	for s: Creature in main.creatures:
		if s.home != main.HATCH_CELL:
			continue
		# 아기 참새는 채집 재능이라 채집 전담 (플레이어가 할 법한 배치)
		if farmers < GameState.open_plots and s.data.species != CreatureCatalog.SPARROW:
			_assign(s, CreatureJobs.FARM, farmers)
			farmers += 1
		else:
			_assign(s, CreatureJobs.FORAGE, 0)
	# 대장간을 고쳤으면 크리처 하나에게 고철 줍기 (땅속성 채집 전담 먼저, 없으면 아무 채집 전담 · 가장 늦게 태어난 크리처)
	if GameState.forge_state >= 2 and scrap_creature == null and not main.creatures.is_empty():
		var pick: Creature = null
		for s: Creature in main.creatures:
			if s.home == main.HATCH_CELL or s.job != CreatureJobs.FORAGE or s.data.species == CreatureCatalog.SPARROW:
				continue
			if pick == null or (s.has_element(&"earth") and not pick.has_element(&"earth")):
				pick = s
		if pick == null:
			pick = main.creatures[-1]
		scrap_creature = pick
		main.farmer.position = pick.position
		main.interact()
		main.farmer.position = Farm.center_of(Creature.scrap_spot() + Vector2i(0, -1))
		main.interact()
		while pick.job != CreatureJobs.SCRAP:
			pick.next_job()
		_log("크리처 배치: %s → 고철 줍기" % pick.describe())
	if farmers >= Config.FIELD_PLOTS.size() and full_day < 0:
		full_day = GameState.day


## 크리처를 들어 옮기고 (F 두 번) 일을 R로 바꾼다. 농사면 plot_i 구역 가운데, 채집이면 풀밭.
func _assign(s: Creature, want: StringName, plot_i: int) -> void:
	var plot := Config.FIELD_PLOTS[plot_i]
	var at := plot.position + Vector2i(plot.size.x / 2, plot.size.y / 2)
	if want == CreatureJobs.FORAGE:
		at = FORAGE_HOME
	main.farmer.position = s.position
	main.interact()
	main.farmer.position = Farm.center_of(at)
	main.interact()
	while s.job != want:
		s.next_job()
	_log("크리처 배치: %s → %s 칸 %s" % [s.describe(), "풀밭" if want == CreatureJobs.FORAGE else Config.FIELD_PLOT_NAMES[plot_i], at])


func let_creatures_work() -> void:
	Engine.time_scale = 20.0
	for i in 600:
		await get_tree().process_frame
		creature_sec += get_process_delta_time()
		var busy := false
		for s: Creature in main.creatures:
			if s._busy:
				busy = true
			elif s.job == CreatureJobs.FARM and CreatureJobs.FARM_ORDER.any(func(t: StringName) -> bool: return farm.find_work(CreatureJobs.FARM_WORK[t], s.home, s.data.work_radius(), [], Farm.center_of(s.home)) != null):
				busy = true
			elif s.job in [CreatureJobs.FARM, CreatureJobs.FORAGE] and main.forage.nearest_target(s.position, s.has_element(&"earth")) != null:
				busy = true
			elif s.job == CreatureJobs.SCRAP and (GameState.scrap_pile > 0 or s.position.distance_to(Farm.center_of(s.home)) > 1.0):
				busy = true
			elif s.job == CreatureJobs.FARM and s.position.distance_to(Farm.center_of(s.home)) > 1.0:
				# 채집하고 제자리로 돌아가는 중
				busy = true
		if not busy:
			break
	Engine.time_scale = 1.0


## 밭 밖 풀밭의 들나물을 다 캔다 (2026-09-29 선택 A). 한 포기 = F 한 번.
func forage() -> int:
	var n := 0
	for cell: Vector2i in main.forage.herbs.keys():
		main.farmer.position = Farm.center_of(cell) - Vector2(0, main.farmer.FEET_Y)
		# 크리처를 들지 않도록 들나물만 캔다
		main.forage.pick(cell)
		GameState.herbs += 1
		n += 1
	manual_actions += n
	return n


## 손으로 수확 → 갈기 → 심기 → 물주기. 도구를 쓴 횟수(강화 도구는 3칸에 한 번)를 센다.
func farm_by_hand() -> Dictionary:
	var counts := {}
	for work: Farm.Work in [Farm.Work.HARVEST, Farm.Work.TILL, Farm.Work.SOW, Farm.Work.WATER]:
		var cells: Array[Vector2i] = []
		for c: Vector2i in farm._cells:
			if farm.can_do(work, c):
				cells.append(c)
		if cells.is_empty():
			continue
		cells.sort()
		var reach := 1
		if work in [Farm.Work.TILL, Farm.Work.WATER] and GameState.tool_level(work) > 0:
			reach = Config.TOOL_UPGRADE_REACH
		if work in [Farm.Work.TILL, Farm.Work.WATER]:
			reach += Wearables.stat_sum(&"farmer", "reach_add")
		if work == Farm.Work.SOW:
			reach = Wearables.sow_reach(&"farmer")
		var n := 0
		for c in cells:
			if farm.do_work(work, c):
				n += 1
		var uses := ceili(float(n) / reach)
		manual_actions += uses
		counts[main.TOOL_NAMES[work]] = uses
	return counts


## 공급함: 알 받기 · 무 진열 · 살 수 있는 것 사기 (밭 넓히기 → 물뿌리개 → 괭이 → 부족한 씨앗 → 사냥칼 → 크리처 훈련)
func shop() -> Array[String]:
	var did: Array[String] = []
	if not GameState.village_eggs.is_empty():
		main.supply_action(&"take_eggs")
		did.append("알 받기")
	# 대장간 (2026-09-29 선택 A): 사금 덩이가 다 모이면 무 · 돈을 남겨 두고 고친다 (사람이라면 그럴 것)
	var saving := GameState.forge_state == 1 and GameState.material >= Config.FORGE_COST_MATERIAL
	if saving and GameState.crops >= Config.FORGE_COST_CROPS and GameState.money >= Config.FORGE_COST_MONEY:
		main.farmer.position = Farm.center_of(Config.FORGE_RECT.position + Vector2i(1, Config.FORGE_RECT.size.y))
		if main.restore_forge():
			restore_day = GameState.day
			did.append("대장간 복구(%d원 · 무 %d · %s %d)" % [Config.FORGE_COST_MONEY, Config.FORGE_COST_CROPS, Config.BOSS_MATERIAL_NAME, Config.FORGE_COST_MATERIAL])
			saving = false
	var keep_crops := mini(GameState.crops, Config.FORGE_COST_CROPS) if saving else 0
	var reserve := Config.FORGE_COST_MONEY if saving else 0
	var held := false
	if GameState.crops > keep_crops:
		var shown := GameState.crops - keep_crops
		GameState.crops = shown
		did.append("무 %d 진열%s" % [shown, (" (복구용 %d 남김)" % keep_crops) if keep_crops > 0 else ""])
		main.supply_action(&"display_crops")
		GameState.crops = keep_crops
	elif keep_crops > 0:
		did.append("무 %d 복구용으로 남김" % keep_crops)
	if GameState.forge_state >= 2:
		craft_day(did)
	if GameState.herbs > 0:
		did.append("들나물 %d 진열" % GameState.herbs)
		main.supply_action(&"display_herbs")
	var keep := true
	while keep:
		keep = false
		var empty := 0
		for c: Vector2i in farm._cells:
			var cell: Farm.Cell = farm._cells[c]
			empty += int(not cell.planted)
		if empty > GameState.seeds and GameState.money >= Config.SEED_PACK_PRICE:
			main.supply_action(&"buy_seeds")
			did.append("씨앗")
			keep = true
			continue
		for id: StringName in [&"expand_field", &"upgrade_can", &"upgrade_hoe", &"buy_knife", &"seed_vest", &"rain_boots", &"hiking_shoes", &"straw_hat", &"ball_cap"]:
			if main.supply_options().has(id):
				var m := GameState.money
				if reserve > 0 and GameState.money - _price_of(id) < reserve:
					held = true
					continue
				if main.supply_action(id):
					did.append("%s(%d원)" % [id, m - GameState.money])
					keep = true
					break
		if keep:
			continue
		# 다 사고 남은 돈은 크리처 훈련 (2026-09-29 선택 A): 가장 싼 단계부터
		var best := &""
		var best_price := 1 << 30
		for id: StringName in main.train_options():
			if id == &"back":
				continue
			var pick: Array = main.train_from_option(id)
			var price: int = main.train_price(pick[0], pick[1])
			if price < best_price:
				best = id
				best_price = price
		if best != &"" and GameState.money >= best_price and GameState.money - best_price < reserve:
			held = true
		elif best != &"" and GameState.money >= best_price:
			var pick: Array = main.train_from_option(best)
			main.train(pick[0], pick[1])
			did.append("훈련 %s(%d원)" % [String(best).trim_prefix("train_"), best_price])
			keep = true
	if held:
		held_days.append(GameState.day)
	return did


## 공급함 물건 값 (복구비를 남겨 둘 때 본다)
func _price_of(id: StringName) -> int:
	match id:
		&"expand_field":
			return Config.FIELD_PLOT_PRICES[Farm.next_plot()]
		&"upgrade_can", &"upgrade_hoe":
			return main.TOOL_UPGRADES[id][1]
		&"buy_knife":
			return Config.HUNTER_KNIFE_PRICE
	return Wearables.ITEMS[id].price if Wearables.ITEMS.has(id) else 0


## 대장장이 (2026-09-29 선택 A): 고철이 있는 만큼 돌아가며 장비를 만들고, 옵션이 더 많은 것을 입고 나머지는 판다.
## 돈은 훈련보다 먼저 쓴다 (새 쓸 곳을 쓰는지 보려고).
func craft_day(did: Array[String]) -> void:
	var bases := Wearables.craft_bases()
	var made: Array[String] = []
	# 사냥꾼 가방이 사냥터 일반 장비로 차 있으면 제작품이 창고로 가 버리니 먼저 판다 (사람이라면 그럴 것)
	Wearables.sell_all_normal(&"hunter")
	while true:
		var base: StringName = bases[crafted % bases.size()]
		var cost: Array = Config.CRAFT_COSTS[base]
		if GameState.scrap < cost[0] or GameState.money < cost[1]:
			break
		var id: StringName = main.craft(base)
		if id == &"":
			break
		crafted += 1
		craft_spent += cost[1]
		var it := Wearables.item(id)
		made.append("%s[%s]" % [it.name, it.effect])
		var who: StringName = it.who
		var b: Array[StringName] = GameState.bag[who]
		var i := b.find(id)
		if i >= 0:
			var worn: StringName = GameState.worn[who].get(it.slot, &"")
			if worn == &"" or _score(id) > _score(worn):
				Wearables.wear_from_bag(who, i)
		# 가방의 제작품은 판다 (입지 않은 것)
		for j in range(b.size() - 1, -1, -1):
			if Wearables.is_rolled(b[j]) and Wearables.rarity(b[j]) == &"crafted":
				Wearables.sell(who, j)
		main.farmer.refresh_wear()
		main.hunter.refresh_wear()
	if not made.is_empty():
		did.append("제작 %s" % ", ".join(made))


## 장비 점수 (봇이 더 좋은 쪽을 입을 때): 옵션 수, 같으면 수치 합
func _score(id: StringName) -> float:
	var it := Wearables.item(id)
	var sc := 0.0
	for a: Dictionary in it.get("affixes", []):
		sc += 1.0 + a.value / 100.0
	return sc


func incubate() -> void:
	if main.incubating_days < 0 and not GameState.farmer_eggs.is_empty():
		main.farmer.position = main.incubator.position + Vector2(10, 40)
		main.farmer.position = Farm.center_of(main.INCUBATOR_RECT.position + Vector2i(0, 2))
		main.interact()
		_log("부화기: %s" % GameState.message if false else "부화기에 알 넣음 (%d일)" % main.incubating_days)


# --- 사냥 봇 -----------------------------------------------------------

## 구역 대장을 처음 쓰러뜨린 날을 적는다
func _cleared(zone: int) -> void:
	if not cleared_day.has(Config.HUNT_ZONES[zone].name):
		cleared_day[Config.HUNT_ZONES[zone].name] = "%d일" % GameState.day


func hunt_day() -> void:
	main._set_active(main.hunter)
	var pick: Creature = null
	for s: Creature in main.creatures:
		# 동행: 금두꺼비 > 땅 슬라임 > 아무나 (플레이어가 할 법한 선택)
		if pick == null or s.data.species.id == &"gold_toad" or (s.data.elements[0].id == &"earth" and pick.data.species.id != &"gold_toad"):
			pick = s
	var zone: int = GameState.waypoints.max()
	if zone == knocked_zone and zone > 0:
		# 어제 여기서 쓰러졌으면 한 구역 아래부터 (사람이라면 그럴 것)
		zone = GameState.waypoints.filter(func(z: int) -> bool: return z < knocked_zone).max()
	# 대장간을 아직 못 고쳤으면 사금 덩이(금사리 금두꺼비)를 모으러 금사리 웨이포인트부터 걸어간다 (광동리로 건너뛰지 않음)
	if GameState.forge_state < 2 and zone > Config.FORGE_ZONE and Config.FORGE_ZONE in GameState.waypoints:
		zone = Config.FORGE_ZONE
	# 광동리 참새는 날아다녀서 혀 · 박치기가 안 닿는다: 광동리로 가면 아기 참새를 데려간다
	if GameState.waypoints.max() >= 2 or zone >= 1:
		for s: Creature in main.creatures:
			if s.data.species == CreatureCatalog.SPARROW and (pick == null or pick.data.species != CreatureCatalog.SPARROW):
				pick = s
	# 도마리 고목 그루터기는 땅 몬스터: 아기 나무 정령(덩굴 묶기)이 있으면 데려가고, 없으면 금두꺼비 · 땅 슬라임
	if zone >= DOMA:
		var best: Creature = null
		for s: Creature in main.creatures:
			if s.data.species == CreatureCatalog.TREE_SPIRIT or (best == null and s.data.species == CreatureCatalog.GOLD_TOAD):
				best = s if best == null or best.data.species != CreatureCatalog.TREE_SPIRIT else best
		if best != null:
			pick = best
	main.enter_hunt(pick, zone)
	var h: HuntGround = main.hunt
	h.set_process(false)
	var t := 0.0
	var kills := 0
	var zones_seen: Array[String] = [Config.HUNT_ZONES[h.zone].name]
	var hurt := 0
	var last_hearts := h.hearts
	var stuck_t := 0.0
	var money0 := GameState.money
	var potions0 := GameState.potions
	var junk0 := GameState.junk
	var gear0 := GameState.gear.size() + GameState.owned_wear.size()
	var zone_times: Array[String] = []
	var zone_t := 0.0
	var seen := {}
	var dodges := 0
	var gwang_hurt0 := -1
	var doma_hurt0 := -1
	## 가방 · 창고가 차서 못 주운 드롭 자리 (이번 사냥에선 다시 가지 않음. 안 그러면 한 걸음 떨어졌다 돌아가기를 되풀이)
	var full_at := {}
	while t < 900.0:
		if h.zone == 2 and gwang_hurt0 < 0:
			gwang_hurt0 = hurt
			gwang_hunts += 1
			if gwang_day < 0:
				gwang_day = GameState.day
		if h.zone == DOMA and doma_hurt0 < 0:
			doma_hurt0 = hurt
			doma_hunts += 1
			if doma_day < 0:
				doma_day = GameState.day
		if h.knocked:
			break
		if t + 2 * DT >= 900.0 and t < 900.0 - DT:
			for d in h.drops + h.loot:
				_log("  ! 줍지 못한 것 칸 %s" % Vector2i(d.at / Config.TILE))
			for s: WildSlime in h.slimes:
				var c := Vector2i(s.position / Config.TILE)
				_log("  ! 남은 %s%s 칸 %s '%s' · 사냥꾼 칸 %s" % [s.title, " (대장)" if s.boss else "", c, h.map.at(c) if h.map else "", Vector2i(main.hunter.feet() / Config.TILE)])
		var hunter: Character = main.hunter
		var feet := hunter.feet()
		# 물약: 하트 2 이하면 마신다
		if h.hearts <= 2 and GameState.potions > 0:
			h.drink_potion()
		var target: Vector2
		var goal := &""
		# 땅에 떨어진 알·드롭부터 줍는다
		var pickups: Array[Vector2] = []
		for d in h.drops:
			pickups.append(d.at)
		for d in h.loot:
			if d.has("full"):
				full_at[d.at] = true
			elif not full_at.has(d.at):
				pickups.append(d.at)
		var nearest_s: WildSlime = h._nearest_slime(feet)
		# 나는 참새는 칼이 안 닿으니 땅에 앉은 것부터 노린다 (다 날고 있으면 가장 가까운 것을 따라감)
		var grounded := h.slimes.filter(func(o: WildSlime) -> bool: return not o.airborne())
		if not grounded.is_empty() and nearest_s != null and nearest_s.airborne():
			grounded.sort_custom(func(a: WildSlime, b: WildSlime) -> bool: return a.position.distance_to(feet) < b.position.distance_to(feet))
			nearest_s = grounded[0]
		# 공격 예고: REACT 초가 지나야 알아채고, 그 안에 서 있으면 비켜선다
		var escape := Vector2.ZERO
		for s: WildSlime in h.slimes:
			var tgs := s.telegraphs()
			if tgs.is_empty():
				seen.erase(s)
				continue
			seen[s] = seen.get(s, 0.0) + DT
			if seen[s] < REACT:
				continue
			for tg: Dictionary in tgs:
				if tg.kind == &"lane":
					var near := Geometry2D.get_closest_point_to_segment(feet, tg.from, tg.to)
					if near.distance_to(feet) <= tg.width / 2.0 + 6.0:
						var axis: Vector2 = (tg.to - tg.from).normalized()
						var side := axis.orthogonal()
						escape += side * (1.0 if (feet - tg.from).dot(side) >= 0.0 else -1.0)
				else:
					var d: Vector2 = feet - tg.at
					if Vector2(d.x, d.y * 2.0).length() <= tg.radius + 8.0:
						escape += d.normalized() if d != Vector2.ZERO else Vector2.DOWN
		if escape != Vector2.ZERO:
			dodges += 1
			var mult: float = (h.map.speed_at(feet) if h.map else 1.0) * Wearables.speed_mult(&"hunter") * hunter.slow_mult
			var p0 := hunter.position
			hunter.step(escape.normalized() * Config.CHARACTER_SPEED * mult * DT)
			if hunter.position.distance_to(p0) < 0.01:
				hunter.step(-escape.normalized().orthogonal() * Config.CHARACTER_SPEED * mult * DT)
			h.tick(DT)
			if h.hearts < last_hearts:
				hurt += last_hearts - h.hearts
			last_hearts = h.hearts
			t += DT
			zone_t += DT
			continue
		if not pickups.is_empty():
			pickups.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_to(feet) < b.distance_to(feet))
			target = pickups[0]
			goal = &"pick"
		elif nearest_s != null:
			target = nearest_s.position
			goal = &"fight"
		elif h.path_open and not h.bridge_broken() and h.hearts >= (6 if h.zone + 1 >= 2 else 3):
			# 2막 구역(광동리 · 도마리)엔 하트가 넉넉할 때만 넘어간다 (사람이라면 반쯤 남은 하트로 더 센 구역에 들어가지 않음)
			target = h.next_area().get_center()
			goal = &"next"
		else:
			target = h.exit_area().get_center()
			goal = &"exit"
		if goal == &"next" and h.near_next():
			_cleared(h.zone)
			zone_times.append("%s %.0f초" % [Config.HUNT_ZONES[h.zone].name, zone_t])
			zone_t = 0.0
			h.advance()
			zones_seen.append(Config.HUNT_ZONES[h.zone].name)
			continue
		if goal == &"exit" and h.near_exit():
			break
		if goal == &"fight" and nearest_s.position.distance_to(feet + Vector2(0, -8)) <= Config.SWING_REACH + Wearables.swing_radius(&"hunter") - 2:
			if nearest_s.buried and nearest_s.position.distance_to(feet) > Config.WILD_BURROW_POP_DISTANCE:
				pass
			var before := h.slimes.size()
			h.swing(nearest_s.position - (feet + Vector2(0, -8)))
			if h.slimes.size() < before:
				kills += 1
		else:
			var dir := _path_dir(h, feet, target)
			var mult: float = (h.map.speed_at(feet) if h.map else 1.0) * Wearables.speed_mult(&"hunter") * hunter.slow_mult
			var p0 := hunter.position
			hunter.step(dir * Config.CHARACTER_SPEED * mult * DT)
			if hunter.position.distance_to(p0) < 0.01:
				stuck_t += DT
				hunter.step(Vector2(dir.y, -dir.x) * Config.CHARACTER_SPEED * DT)
			else:
				stuck_t = 0.0
			if dir.length() > 0:
				hunter.facing = Vector2i(int(signf(dir.x)), 0) if absf(dir.x) > absf(dir.y) else Vector2i(0, int(signf(dir.y)))
		var before_k := h.slimes.size()
		h.tick(DT)
		if h.slimes.size() < before_k and goal != &"fight":
			kills += before_k - h.slimes.size()
		if h.hearts < last_hearts:
			hurt += last_hearts - h.hearts
		last_hearts = h.hearts
		t += DT
		zone_t += DT
	zone_times.append("%s %.0f초" % [Config.HUNT_ZONES[h.zone].name, zone_t])
	hunt_sec = t
	var hearts_left := h.hearts
	var knocked := h.knocked
	hunt_days += 1
	hunt_hurt += hurt
	hunt_knocked += int(knocked)
	knocked_zone = h.zone if knocked else -1
	if gwang_hurt0 >= 0:
		gwang_hurt += (doma_hurt0 if doma_hurt0 >= 0 else hurt) - gwang_hurt0
		gwang_knocked += int(knocked and h.zone == 2)
	if doma_hurt0 >= 0:
		doma_hurt += hurt - doma_hurt0
		doma_knocked += int(knocked and h.zone == DOMA)
	if h.boss_spawned and h._boss() == null:
		_cleared(h.zone)
	var comp := h.companion.display_name() if h.companion else "혼자"
	var picked := h.picked.size()
	if main.hunt:
		main.leave_hunt()
	var eggs: Array[String] = []
	for sp in GameState.hunter_eggs:
		eggs.append(sp.display_name)
	_log("사냥: 시작 %s · 동행 %s · %s · 처치 %d · 맞은 횟수 %d · 비킨 틱 %d · 남은 하트 %d%s · 알 %s · 돈 %+d · 물약 %+d · 젤리 %+d · 장비 %+d" % [
		Config.HUNT_ZONES[zone].name, comp, " → ".join(zone_times), kills, hurt, dodges, hearts_left, " (쓰러짐)" if knocked else "",
		eggs, GameState.money - money0, GameState.potions - potions0, GameState.junk - junk0, GameState.gear.size() + GameState.owned_wear.size() - gear0])
	if t >= 900.0:
		_log("  ! 사냥 봇이 15분 안에 끝내지 못함 (막힘?)")
	# 알 넣기 · 젤리 팔기
	main.hunter.position = Farm.center_of(main.SUPPLY_RECT.position + Vector2i(1, 1))
	main._hunter_interact()
	main.close_menu()
	main._set_active(main.farmer)
	# 같은 날 농부가 알을 받아 부화기에 넣는다 (부화기가 비어 있으면)
	if not GameState.village_eggs.is_empty():
		main.supply_action(&"take_eggs")
	incubate()


## 칸 지도 위 BFS로 다음 칸 방향. 한 화면 구역이면 곧장.
func _path_dir(h: HuntGround, from: Vector2, to: Vector2) -> Vector2:
	if h.map == null:
		return (to - from).normalized()
	var T := Config.TILE
	var start := Vector2i(floori(from.x / T), floori(from.y / T))
	var goal := Vector2i(floori(to.x / T), floori(to.y / T))
	if start == goal:
		return (to - from).normalized()
	var prev := {start: start}
	var q: Array[Vector2i] = [start]
	var found := false
	while not q.is_empty():
		var c: Vector2i = q.pop_front()
		if c == goal:
			found = true
			break
		for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var n: Vector2i = c + d
			if prev.has(n) or HuntMap.HUNTER_BLOCK.contains(h.map.at(n)):
				continue
			prev[n] = c
			q.append(n)
	if not found:
		return (to - from).normalized()
	var step := goal
	while prev[step] != start:
		step = prev[step]
	var center := Vector2(step * T) + Vector2(T / 2.0, T / 2.0 - 4)
	return (center - from).normalized()
