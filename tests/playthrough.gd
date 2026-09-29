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


func _ready() -> void:
	days = int(OS.get_environment("DAYS")) if OS.get_environment("DAYS") != "" else 10
	var rng_seed := int(OS.get_environment("SEED")) if OS.get_environment("SEED") != "" else 1
	seed(rng_seed)
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	main._rng.seed = rng_seed
	farm = main.farm
	Engine.time_scale = 1.0
	_log("# 자동 플레이 seed=%d" % rng_seed)
	for d in days:
		await play_day()
	var trained := 0
	for s: Creature in main.creatures:
		trained += s.data.train_total()
	_log("\n최종: %d일째, 돈 %d원, 씨앗 %d, 크리처 %d (훈련 단계 합 %d), 밭 구역 %d, 웨이포인트 %s" % [GameState.day, GameState.money, GameState.seeds, main.creatures.size(), trained, GameState.open_plots, GameState.waypoints])
	var out := OS.get_environment("OUT")
	if out != "":
		var f := FileAccess.open(out, FileAccess.WRITE)
		f.store_string("\n".join(log_lines))
	get_tree().quit()


func _log(t: String) -> void:
	print(t)
	log_lines.append(t)


func play_day() -> void:
	manual_actions = 0
	var money0 := GameState.money
	_log("\n## %d일째 (시작 돈 %d, 씨앗 %d, 작물 %d)" % [GameState.day, GameState.money, GameState.seeds, GameState.crops])
	main._set_active(main.farmer)
	await place_new_creatures()
	await let_creatures_work()
	var farm_counts := farm_by_hand()
	await let_creatures_work()
	farm_counts.merge(farm_by_hand(), true)
	var bought := shop()
	# 산 뒤(밭을 넓혔거나 씨앗을 샀으면) 한 번 더 심는다
	var more := farm_by_hand()
	for k in more:
		farm_counts[k] = farm_counts.get(k, 0) + more[k]
	await let_creatures_work()
	incubate()
	_log("농부: 손으로 한 도구질 %d번 %s · 공급함: %s" % [manual_actions, farm_counts, bought])
	var planted := 0
	var watered := 0
	for c: Vector2i in farm._cells:
		var cell: Farm.Cell = farm._cells[c]
		planted += int(cell.planted)
		watered += int(cell.watered)
	_log("밭: 열린 칸 %d · 심은 칸 %d · 물 준 칸 %d" % [farm._cells.size(), planted, watered])
	if GameState.hunter_unlocked:
		await hunt_day()
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
	_log("하루 수입 %+d원 · 부화 기다리는 알 %d개 (농부 %d · 공급함 %d)" % [GameState.money - money0, GameState.farmer_eggs.size() + GameState.village_eggs.size(), GameState.farmer_eggs.size(), GameState.village_eggs.size()])


## 부화기 옆에 나온 새 크리처를 밭에 놓고 일을 정한다
func place_new_creatures() -> void:
	var jobs_have := {}
	for s: Creature in main.creatures:
		if s.home != main.HATCH_CELL:
			jobs_have[s.job] = jobs_have.get(s.job, 0) + 1
	for s: Creature in main.creatures:
		if s.home != main.HATCH_CELL:
			continue
		# 첫 슬라임은 급수. 다음부터는 수확 → 파종 → 새 구역 급수 순으로 채운다 (플레이어가 할 법한 순서)
		var want: StringName = s.job
		if s.job == CreatureJobs.REST:
			for j in [CreatureJobs.HARVEST, CreatureJobs.SOW, CreatureJobs.WATER]:
				if jobs_have.get(j, 0) < GameState.open_plots:
					want = j
					break
		var plot_i := clampi(jobs_have.get(want, 0), 0, GameState.open_plots - 1)
		var plot := Config.FIELD_PLOTS[plot_i]
		var at := plot.position + Vector2i(plot.size.x / 2, plot.size.y / 2)
		main.farmer.position = Farm.center_of(s.home)
		main.interact()
		main.farmer.position = Farm.center_of(at)
		main.interact()
		while s.job != want:
			s.next_job()
		jobs_have[want] = jobs_have.get(want, 0) + 1
		_log("크리처 배치: %s → %s 칸 %s" % [s.describe(), Config.FIELD_PLOT_NAMES[plot_i], at])


func let_creatures_work() -> void:
	Engine.time_scale = 20.0
	for i in 600:
		await get_tree().process_frame
		var busy := false
		for s: Creature in main.creatures:
			if s._busy:
				busy = true
			elif CreatureJobs.FARM_WORK.has(s.job) and farm.find_work(CreatureJobs.FARM_WORK[s.job], s.home, s.data.work_radius(), [], s.position) != null:
				busy = true
		if not busy:
			break
	Engine.time_scale = 1.0


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
	if GameState.crops > 0:
		did.append("무 %d 진열" % GameState.crops)
		main.supply_action(&"display_crops")
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
		if best != &"" and GameState.money >= best_price:
			var pick: Array = main.train_from_option(best)
			main.train(pick[0], pick[1])
			did.append("훈련 %s(%d원)" % [String(best).trim_prefix("train_"), best_price])
			keep = true
	return did


func incubate() -> void:
	if main.incubating_days < 0 and not GameState.farmer_eggs.is_empty():
		main.farmer.position = main.incubator.position + Vector2(10, 40)
		main.farmer.position = Farm.center_of(main.INCUBATOR_RECT.position + Vector2i(0, 2))
		main.interact()
		_log("부화기: %s" % GameState.message if false else "부화기에 알 넣음 (%d일)" % main.incubating_days)


# --- 사냥 봇 -----------------------------------------------------------

func hunt_day() -> void:
	main._set_active(main.hunter)
	var pick: Creature = null
	for s: Creature in main.creatures:
		# 동행: 금두꺼비 > 땅 슬라임 > 아무나 (플레이어가 할 법한 선택)
		if pick == null or s.data.species.id == &"gold_toad" or (s.data.elements[0].id == &"earth" and pick.data.species.id != &"gold_toad"):
			pick = s
	var zone: int = GameState.waypoints.max()
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
	while t < 900.0:
		if h.knocked:
			break
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
			if not d.has("full"):
				pickups.append(d.at)
		var nearest_s: WildSlime = h._nearest_slime(feet)
		if not pickups.is_empty():
			pickups.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_to(feet) < b.distance_to(feet))
			target = pickups[0]
			goal = &"pick"
		elif nearest_s != null:
			target = nearest_s.position
			goal = &"fight"
		elif h.path_open and h.hearts >= 3:
			target = h.next_area().get_center()
			goal = &"next"
		else:
			target = h.exit_area().get_center()
			goal = &"exit"
		if goal == &"next" and h.near_next():
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
			var mult: float = (h.map.speed_at(feet) if h.map else 1.0) * Wearables.speed_mult(&"hunter")
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
	var hearts_left := h.hearts
	var knocked := h.knocked
	var comp := h.companion.display_name() if h.companion else "혼자"
	var picked := h.picked.size()
	if main.hunt:
		main.leave_hunt()
	var eggs: Array[String] = []
	for sp in GameState.hunter_eggs:
		eggs.append(sp.display_name)
	_log("사냥: 시작 %s · 동행 %s · %s · 처치 %d · 맞은 횟수 %d · 남은 하트 %d%s · 알 %s · 돈 %+d · 물약 %+d · 젤리 %+d · 장비 %+d" % [
		Config.HUNT_ZONES[zone].name, comp, " → ".join(zone_times), kills, hurt, hearts_left, " (쓰러짐)" if knocked else "",
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
