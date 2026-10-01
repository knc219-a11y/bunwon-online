extends Node
## 핵심 루프 점검용 자동 플레이 (2026-09-28). 새 게임에서 며칠을 "보통 플레이어"처럼 돌리고 숫자를 남긴다.
## 실행: godot --headless --path . res://tests/playthrough.tscn   (환경변수 DAYS=10 SEED=1 OUT=경로 WEAPON=bow)
## WEAPON (2026-09-29 무기): 봇이 즐겨 드는 무기 종류. bow (기본) · staff · melee (근거리 무기) · knife (무기 없이 사냥칼만).
## 그 종류 무기가 없으면 사냥칼로 싸운다. DEBUG_KO=1 이면 하트가 줄 때 · 쓰러질 때 까닭을 적는다.
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
const FORAGE_HOME := Config.FORAGE_CELLS[0]
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
## 즐겨 드는 무기 종류 (&"bow" / &"staff" / &"melee" / &"knife")
var weapon_pref := &"bow"
## 활 · 지팡이: 몬스터가 이보다 가까우면 물러서며 쏜다 (달려들기 거리 56쯤)
const KITE_DISTANCE := 64.0
## 첫 무기를 든 날, 사냥에서 쏜 수
var weapon_day := -1
var shots_fired := 0
## 약방 · 번천 (2026-09-29, 3막): 약방 터 · 복구한 날, 번천 첫 도착 · 사냥 수 · 맞은 횟수 · 쓰러짐, 도라지밭 크리처, 만든 것
var yak_site_day := -1
var yak_restore_day := -1
var bun_day := -1
var bun_hunts := 0
var bun_hurt := 0
var bun_knocked := 0
var herb_creature: Creature = null
var brewed := {}
var tonic_days := 0
const BUNJEON := 4
## 밀목 · 축사 (2026-09-30, 3막 둘째 구역): 밀목 첫 도착 · 사냥 수 · 맞은 횟수 · 쓰러짐, 축사 터 · 복구한 날, 닭장 기록
const MILMOK := 5
var mil_day := -1
var mil_hunts := 0
var mil_hurt := 0
var mil_knocked := 0
var barn_site_day := -1
var barn_restore_day := -1
var feed_creature: Creature = null
var lunches_eaten := 0
var hen_eggs_sold := 0
var weasel_nights := 0
var tigers_got := {}
## 크리처 원정 + 입양 (2026-10-01). EXPEDITION=0 이면 끈다 (비교용).
var expedition_on := true
## 채집으로 마을에 남겨 두는 크리처 수 (풀밭 들나물이 하루 7~8포기라 그 정도)
const KEEP_FORAGERS := 6
var expedition_money := 0
var expedition_gear := 0
var adopted_n := 0
## 날짜 → [크리처 전체, 놀고 있는(쉬는 · 채집) 수, 원정 중, 입양]
var crowd_by_day := {}
## 밤 구역: 이보다 가까우면 물러서며 쏜다 (사람처럼 호롱 불빛 44 안에 두려다 불똥 원 40 가장자리에 걸치기도 함)
const NIGHT_KITE := 40.0


func _ready() -> void:
	days = int(OS.get_environment("DAYS")) if OS.get_environment("DAYS") != "" else 10
	var rng_seed := int(OS.get_environment("SEED")) if OS.get_environment("SEED") != "" else 1
	if OS.get_environment("WEAPON") != "":
		weapon_pref = StringName(OS.get_environment("WEAPON"))
	seed(rng_seed)
	expedition_on = OS.get_environment("EXPEDITION") != "0"
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
	_log("\n광동리: 첫 도착 %s · 첫 대장 처치 %s · 광동리 사냥 %d번 · 거기서 맞은 횟수 %d (한 번에 %.1f) · 쓰러짐 %d번 · 끝 돈 %s · 아기 까마귀 %d마리" % [
		"%d일" % gwang_day if gwang_day > 0 else "없음", cleared_day.get(Config.HUNT_ZONES[2].name, "없음"), gwang_hunts, gwang_hurt,
		float(gwang_hurt) / maxi(gwang_hunts, 1), gwang_knocked, money_at, main.creatures.filter(func(c: Creature) -> bool: return c.data.species == CreatureCatalog.SPARROW).size()])
	var money_late := []
	for d in [40, 45, 50]:
		if money_by_day.has(d):
			money_late.append("%d일 %d원" % [d, money_by_day[d]])
	_log("\n도마리: 첫 도착 %s · 2막 대장(장승 한 쌍) 첫 처치 %s · 도마리 사냥 %d번 · 거기서 맞은 횟수 %d (한 번에 %.1f) · 쓰러짐 %d번 · 끝 돈 %s · 아기 나무 정령 %d마리" % [
		"%d일" % doma_day if doma_day > 0 else "없음", cleared_day.get(Config.HUNT_ZONES[DOMA].name, "없음"), doma_hunts, doma_hurt,
		float(doma_hurt) / maxi(doma_hunts, 1), doma_knocked, money_late, main.creatures.filter(func(c: Creature) -> bool: return c.data.species == CreatureCatalog.TREE_SPIRIT).size()])
	_log("\n약방 · 번천: 약방 터 %s · 복구 %s (장승 조각 %d · 도라지 %d) · 번천 첫 도착 %s · 유령 막차 첫 처치 %s · 번천 사냥 %d번 · 거기서 맞은 횟수 %d (한 번에 %.1f) · 쓰러짐 %d번 · 만든 것 %s · 보약 먹인 날 %d · 도라지밭 %s · 아기 도깨비불 %d마리" % [
		"%d일" % yak_site_day if yak_site_day > 0 else "없음", "%d일" % yak_restore_day if yak_restore_day > 0 else "없음", GameState.material2, GameState.roots,
		"%d일" % bun_day if bun_day > 0 else "없음", cleared_day.get(Config.HUNT_ZONES[BUNJEON].name, "없음"), bun_hunts, bun_hurt,
		float(bun_hurt) / maxi(bun_hunts, 1), bun_knocked, brewed, tonic_days, herb_creature.describe() if herb_creature else "없음",
		main.creatures.filter(func(c: Creature) -> bool: return c.data.species == CreatureCatalog.WILL_O).size()])
	_log("\n밀목 · 축사: 밀목 첫 도착 %s · 산군 백호 첫 처치 %s · 밀목 사냥 %d번 · 거기서 맞은 횟수 %d (한 번에 %.1f) · 쓰러짐 %d번 · 산군 발톱 %d · 축사 터 %s · 복구 %s · 암탉 %d (병아리 %d) · 판 달걀 %d · 먹은 도시락 %d · 족제비 %d밤 · 얻은 알 %s · 모이 주기 %s" % [
		"%d일" % mil_day if mil_day > 0 else "없음", cleared_day.get(Config.HUNT_ZONES[MILMOK].name, "없음"), mil_hunts, mil_hurt,
		float(mil_hurt) / maxi(mil_hunts, 1), mil_knocked, GameState.material3, "%d일" % barn_site_day if barn_site_day > 0 else "없음",
		"%d일" % barn_restore_day if barn_restore_day > 0 else "없음", GameState.hens, GameState.chicks.size(), hen_eggs_sold, lunches_eaten, weasel_nights, tigers_got,
		feed_creature.describe() if feed_creature else "없음"])
	var crowd := []
	for d in [20, 40, 60, 80]:
		if crowd_by_day.has(d):
			var c: Array = crowd_by_day[d]
			crowd.append("%d일 전체 %d · 놀고 있는 %d · 원정 %d · 입양 %d" % [d, c[0], c[1], c[2], c[3]])
	_log("\n크리처 원정 · 입양 (%s): %s · 원정 돈 합 %d원 · 원정 장비 %d · 입양 %d마리 %s" % ["켬" if expedition_on else "끔", " / ".join(crowd), expedition_money, expedition_gear, adopted_n,
		GameState.adopted.map(func(a: Dictionary) -> String: return "%s→%s" % [load(a.species).display_name, a.who])])
	_log("무기 (봇이 즐겨 듦: %s): 처음 든 날 %s · 쏜 화살 · 구슬 %d" % [weapon_pref, "%d일" % weapon_day if weapon_day > 0 else "없음", shots_fired])
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
	if GameState.yak_state >= 1 and yak_site_day < 0:
		yak_site_day = GameState.day
	if GameState.barn_state >= 1 and barn_site_day < 0:
		barn_site_day = GameState.day
	_log("\n## %d일째 (시작 돈 %d, 씨앗 %d, 작물 %d)" % [GameState.day, GameState.money, GameState.seeds, GameState.crops])
	main._set_active(main.farmer)
	await place_new_creatures()
	if expedition_on:
		manage_expeditions()
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
	var stash0 := GameState.stash.size()
	var lines: Array[String] = main.next_day()
	expedition_gear += GameState.stash.size() - stash0
	var idle_n: int = main.creatures.filter(func(c: Creature) -> bool: return c.expedition_zone < 0 and (c.job == CreatureJobs.REST or c.job == CreatureJobs.FORAGE)).size()
	crowd_by_day[GameState.day - 1] = [main.creatures.size() + GameState.adopted.size(), idle_n, Expedition.away_count(main), GameState.adopted.size()]
	_log("크리처 무리: 전체 %d · 놀고 있는(쉬는 · 채집) %d · 원정 중 %d · 입양 %d" % crowd_by_day[GameState.day - 1])
	var cap := OS.get_environment("CAPTURE")
	if cap != "":
		# 아침 카드를 실제 게임처럼 띄워 찍는다
		main.show_morning_card(lines)
		for i in 3:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("%s/morning_day%02d.png" % [cap, GameState.day])
		main._morning_card.visible = false
	_log("밤 → 아침 카드: %s" % " / ".join(lines))
	for l in lines:
		if l.contains("족제비가"):
			weasel_nights += 1
		if l.begins_with("원정대"):
			var m := RegEx.create_from_string("\\+(\\d+)원").search(l)
			if m:
				expedition_money += m.get_string(1).to_int()
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
		# 아기 까마귀는 채집 재능이라 채집 전담 (플레이어가 할 법한 배치)
		if farmers < GameState.open_plots and s.data.species != CreatureCatalog.SPARROW:
			_assign(s, CreatureJobs.FARM, farmers)
			farmers += 1
		else:
			_assign(s, CreatureJobs.FORAGE, 0)
	# 대장간을 고쳤으면 크리처 하나에게 고철 줍기 (땅속성 채집 전담 먼저, 없으면 아무 채집 전담 · 가장 늦게 태어난 크리처)
	if GameState.forge_state >= 2 and scrap_creature == null and not main.creatures.is_empty():
		var pick: Creature = null
		for s: Creature in main.creatures:
			if s.home == main.HATCH_CELL or s.job != CreatureJobs.FORAGE or s.data.species == CreatureCatalog.SPARROW or s.expedition_zone >= 0:
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
	# 약방을 고쳤으면 크리처 하나에게 도라지밭 (아기 도깨비불 먼저, 없으면 땅속성 채집 전담 · 아무 채집 전담)
	var want_herb: bool = GameState.yak_state >= 2 and (herb_creature == null or (herb_creature.data.species != CreatureCatalog.WILL_O and main.creatures.any(func(c: Creature) -> bool: return c.data.species == CreatureCatalog.WILL_O and c.home != main.HATCH_CELL and c.expedition_zone < 0)))
	if want_herb:
		var pick: Creature = null
		for s: Creature in main.creatures:
			if s.home == main.HATCH_CELL or s == scrap_creature or s.job == CreatureJobs.FARM or s.data.species == CreatureCatalog.SPARROW or s.expedition_zone >= 0:
				continue
			if pick == null or s.data.species == CreatureCatalog.WILL_O or (s.has_element(&"earth") and pick.data.species != CreatureCatalog.WILL_O and not pick.has_element(&"earth")):
				pick = s
		if pick != null and pick != herb_creature:
			if herb_creature != null:
				_assign(herb_creature, CreatureJobs.FORAGE, 0)
			herb_creature = pick
			main.farmer.position = pick.position
			main.interact()
			main.farmer.position = Farm.center_of(Creature.herb_spot() + Vector2i(1, 0))
			main.interact()
			while pick.job != CreatureJobs.HERB:
				pick.next_job()
			_log("크리처 배치: %s → 도라지밭 (칸 %s)" % [pick.describe(), pick.home])
	# 축사를 고쳤으면 아기 호랑이(없으면 아무 채집 전담)에게 모이 주기 (호랑이는 족제비도 쫓는다)
	if GameState.barn_state >= 2 and (feed_creature == null or not feed_creature.data.species.guards_coop):
		var pick: Creature = null
		for s: Creature in main.creatures:
			if s.home == main.HATCH_CELL or s == scrap_creature or s == herb_creature or s.job == CreatureJobs.FARM or s.expedition_zone >= 0:
				continue
			if pick == null or (s.data.species.guards_coop and not pick.data.species.guards_coop):
				pick = s
		if pick != null and pick != feed_creature and (feed_creature == null or pick.data.species.guards_coop):
			if feed_creature != null:
				_assign(feed_creature, CreatureJobs.FORAGE, 0)
			feed_creature = pick
			main.farmer.position = pick.position
			main.interact()
			main.farmer.position = Farm.center_of(Creature.feed_spot() + Vector2i(1, 0))
			main.interact()
			while pick.job != CreatureJobs.FEED:
				pick.next_job()
			_log("크리처 배치: %s → 모이 주기 (칸 %s)" % [pick.describe(), pick.home])
	if farmers >= Config.FIELD_PLOTS.size() and full_day < 0:
		full_day = GameState.day


## 원정 · 입양 (2026-10-01): 대장을 잡은 구역마다 원정대를 보내고 (채집 KEEP_FORAGERS 마리는 마을에 남김),
## 모든 구역에 원정대가 있는데도 남는 크리처는 주민에게 입양 (일 속도가 낮은 크리처부터). 플레이어가 할 법한 배치.
func manage_expeditions() -> void:
	var zones := Expedition.zones()
	zones.reverse()
	for z in zones:
		if not Expedition.team(main, z).is_empty():
			continue
		var spare := Expedition.idle(main).size() - KEEP_FORAGERS
		if spare < Config.EXPEDITION_TEAM_MIN:
			break
		var n := Expedition.send(main, z, spare)
		if n > 0:
			_log("원정대: %s로 %d마리 (%s)" % [Config.HUNT_ZONES[z].name, n, ", ".join(Expedition.team(main, z).map(func(c: Creature) -> String: return "%s %s" % [c.data.element_names(), c.data.species.display_name]))])
	if zones.any(func(z: int) -> bool: return Expedition.team(main, z).is_empty()):
		return
	var spare_list := Expedition.idle(main)
	spare_list.sort_custom(func(a: Creature, b: Creature) -> bool: return a.data.base_work_speed < b.data.base_work_speed)
	while spare_list.size() > KEEP_FORAGERS and Expedition.next_villager() != &"":
		var c: Creature = spare_list.pop_front()
		var desc := c.describe()
		var who := Expedition.adopt(main, c)
		if who == &"":
			break
		adopted_n += 1
		_log("입양: %s → %s" % [desc, who])


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
			elif s.job == CreatureJobs.HERB and (GameState.herb_bed > 0 or s.position.distance_to(Farm.center_of(s.home)) > 1.0):
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
	# 약방 (2026-09-29): 장승 조각이 다 모이면 돈을 남겨 두고, 도라지까지 모이면 고친다
	if GameState.yak_state == 1 and GameState.material2 >= Config.YAK_COST_MATERIAL:
		if main.can_restore_yak() and main.restore_yak():
			yak_restore_day = GameState.day
			did.append("약방 복구(%d원 · %s %d · %s %d)" % [Config.YAK_COST_MONEY, Config.ROOT_NAME, Config.YAK_COST_ROOTS, Config.BOSS_MATERIAL2_NAME, Config.YAK_COST_MATERIAL])
		else:
			reserve = maxi(reserve, Config.YAK_COST_MONEY)
	# 축사 (2026-09-30 선택 A 닭장): 산군 발톱이 다 모이면 무 · 돈을 남겨 두고 고친다
	var barn_saving := GameState.barn_state == 1 and GameState.material3 >= Config.BARN_COST_MATERIAL
	if barn_saving:
		if main.can_restore_barn() and main.restore_barn():
			barn_restore_day = GameState.day
			did.append("축사 복구(%d원 · 무 %d · %s %d)" % [Config.BARN_COST_MONEY, Config.BARN_COST_CROPS, Config.BOSS_MATERIAL3_NAME, Config.BARN_COST_MATERIAL])
		else:
			reserve = maxi(reserve, Config.BARN_COST_MONEY)
			keep_crops = maxi(keep_crops, mini(GameState.crops, Config.BARN_COST_CROPS))
	if GameState.barn_state >= 2:
		coop_day(did)
	if GameState.yak_state >= 2:
		brew_day(did)
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


## 닭장: 모이를 맡은 크리처가 없으면 무로 모이를 주고, 닭이 다 찼으면 둥지 달걀을 꺼내
## 목축인이 도시락 하나를 싸 두고 나머지는 공급함에 진열한다. 덜 찼으면 병아리가 되게 둥지에 둔다.
func coop_day(did: Array[String]) -> void:
	var made: Array[String] = []
	if GameState.fed < GameState.hens and (feed_creature == null or feed_creature.job != CreatureJobs.FEED) and main.coop_action(&"feed"):
		made.append("모이")
	# 암탉이 넷이 될 때까지는 둥지 달걀을 병아리로 두고, 그 뒤로 꺼낸다 (사람이라면 먼저 닭을 늘릴 것)
	if GameState.nest > 0 and GameState.hens + GameState.chicks.size() >= Config.HEN_CAP / 2:
		made.append("달걀 %d" % GameState.nest)
		main.coop_action(&"take_nest")
	if GameState.lunches == 0 and GameState.hen_eggs >= Config.LUNCH_EGGS:
		main._set_active(main.rancher)
		if main.coop_action(&"lunch"):
			made.append("도시락")
		main._set_active(main.farmer)
	# 다음 도시락 몫은 남기고 나머지만 판다
	var keep_eggs := Config.LUNCH_EGGS
	if GameState.hen_eggs > keep_eggs:
		var sell := GameState.hen_eggs - keep_eggs
		GameState.hen_eggs = sell
		hen_eggs_sold += sell
		made.append("달걀 %d 진열" % sell)
		main.supply_action(&"display_hen_eggs")
		GameState.hen_eggs = keep_eggs
	if not made.is_empty():
		did.append("닭장 %s" % ", ".join(made))


## 연금술사 (2026-09-29 선택 A+B): 번천에 갈 만큼 호롱 기름 · 빨간 물약을 채우고, 무가 넉넉하면 보약을 먹인다.
## 잡템은 판매 대신 여기 먼저 쓴다 (사람이라면 그럴 것).
func brew_day(did: Array[String]) -> void:
	var made: Array[String] = []
	var wants: Array = [[&"lamp_oil", "lamp_oil", 2], [&"potion", "potions", 4], [&"strength", "strength", 1 if BUNJEON in GameState.waypoints else 0]]
	for w: Array in wants:
		while GameState.get(w[1]) < w[2] and main.brew(w[0]):
			brewed[w[0]] = brewed.get(w[0], 0) + 1
			made.append(Config.BREWS[w[0]].name)
	if GameState.crops >= 20 and GameState.tonic_day != GameState.day and main.brew(&"tonic"):
		brewed[&"tonic"] = brewed.get(&"tonic", 0) + 1
		made.append(Config.BREWS[&"tonic"].name)
	if GameState.tonics > 0 and main.feed_tonic():
		tonic_days += 1
		made.append("보약 먹임")
	if not made.is_empty():
		did.append("연금술사 %s" % ", ".join(made))


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
		if i >= 0 and it.slot == &"weapon":
			pick_weapon()
		elif i >= 0:
			var worn: StringName = GameState.worn[who].get(it.slot, &"")
			if worn == &"" or _score(id) > _score(worn):
				Wearables.wear_from_bag(who, i)
		# 가방의 제작품은 판다 (입지 않은 것. 즐겨 드는 종류 무기는 남김)
		for j in range(b.size() - 1, -1, -1):
			if Wearables.is_rolled(b[j]) and Wearables.rarity(b[j]) == &"crafted" and not _wanted_weapon(b[j]):
				Wearables.sell(who, j)
		main.farmer.refresh_wear()
		main.hunter.refresh_wear()
	if not made.is_empty():
		did.append("제작 %s" % ", ".join(made))


func _debug_msg(t: String) -> void:
	if "하트" in t or "쓰러" in t:
		_log("  . %s (사냥꾼 칸 %s)" % [t, Vector2i(main.hunter.feet() / Config.TILE)])


## 즐겨 드는 종류 무기인지
func _wanted_weapon(id: StringName) -> bool:
	var it := Wearables.item(id)
	return it.slot == &"weapon" and it.weapon.kind == weapon_pref


## 즐겨 드는 종류 무기 중 가장 좋은 것을 든다 (가방 · 창고에서). knife 면 무기를 내려놓는다.
## 다른 종류 무기는 들지 않는다 (주울 때 빈 칸이라 바로 들었으면 내려놓음).
func pick_weapon() -> void:
	var worn: StringName = GameState.worn[&"hunter"].get(&"weapon", &"")
	if worn != &"" and not _wanted_weapon(worn):
		if not Wearables.take_off(&"hunter", &"weapon"):
			# 가방 · 창고가 차 있으면 일반 장비를 팔고 다시, 그래도 안 되면 그 무기를 판다
			Wearables.sell_all_normal(&"hunter")
			if not Wearables.take_off(&"hunter", &"weapon"):
				GameState.worn[&"hunter"].erase(&"weapon")
				GameState.money += Wearables.sell_price(worn)
				GameState.gear.erase(worn)
		worn = &""
	for i in range(GameState.stash.size() - 1, -1, -1):
		if _wanted_weapon(GameState.stash[i]):
			Wearables.stash_to_bag(&"hunter", i)
	var b: Array[StringName] = GameState.bag[&"hunter"]
	var best := -1
	for i in b.size():
		if _wanted_weapon(b[i]) and (best < 0 or _weapon_score(b[i]) > _weapon_score(b[best])):
			best = i
	if best >= 0 and (worn == &"" or _weapon_score(b[best]) > _weapon_score(worn)):
		Wearables.wear_from_bag(&"hunter", best)
	if weapon_day < 0 and GameState.worn[&"hunter"].has(&"weapon"):
		weapon_day = GameState.day


## 무기 점수: 초당 공격 수 · 사거리 (옵션 포함)
func _weapon_score(id: StringName) -> float:
	var it := Wearables.item(id)
	var w: Dictionary = it.weapon
	var sc: float = (1.0 + it.get("atk_speed", 0) / 100.0) / w.cooldown + w.get("range", w.get("radius", 0.0) * 4.0) / 200.0 * (1.0 + it.get("range_add", 0) / 100.0)
	return sc + _score(id) * 0.1


## 화살 · 구슬이 나무 · 창고 · 비닐하우스에 막히지 않는지
func _clear_shot(h: HuntGround, from: Vector2, to: Vector2) -> bool:
	if h.map == null:
		return true
	var n := int(from.distance_to(to) / 8.0) + 1
	for k in n:
		var p := from.lerp(to, float(k) / n)
		if HuntGround.SHOT_BLOCK.contains(h.map.at(Vector2i(floori(p.x / Config.TILE), floori(p.y / Config.TILE)))):
			return false
	return true


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
	var pool: Array[Creature] = main.companion_candidates()
	for s: Creature in pool:
		# 동행: 금두꺼비 > 땅 슬라임 > 아무나 (플레이어가 할 법한 선택)
		if pick == null or s.data.species.id == &"gold_toad" or (s.data.elements[0].id == &"earth" and pick.data.species.id != &"gold_toad"):
			pick = s
	var zone: int = GameState.waypoints.max()
	# 2막 구역(웨이포인트)에서 쓰러졌으면 다음 날 하트를 채워 같은 웨이포인트에서 다시 (아래 구역부터 걸어오면 하트가 깎인 채 들어가 또 쓰러짐)
	if zone == knocked_zone and zone > 0 and zone < 2:
		# 어제 여기서 쓰러졌으면 한 구역 아래부터 (사람이라면 그럴 것)
		zone = GameState.waypoints.filter(func(z: int) -> bool: return z < knocked_zone).max()
	# 대장간을 아직 못 고쳤으면 사금 덩이(금사리 금두꺼비)를 모으러 금사리 웨이포인트부터 걸어간다 (광동리로 건너뛰지 않음)
	if GameState.forge_state < 2 and zone > Config.FORGE_ZONE and Config.FORGE_ZONE in GameState.waypoints:
		zone = Config.FORGE_ZONE
	# 광동리 까마귀는 날아다녀서 혀 · 박치기가 안 닿는다: 광동리로 가면 아기 까마귀를 데려간다
	if GameState.waypoints.max() >= 2 or zone >= 1:
		for s: Creature in pool:
			if s.data.species == CreatureCatalog.SPARROW and (pick == null or pick.data.species != CreatureCatalog.SPARROW):
				pick = s
	# 도마리 고목 그루터기는 땅 몬스터: 아기 나무 정령(덩굴 묶기)이 있으면 데려가고, 없으면 금두꺼비 · 땅 슬라임
	if zone >= DOMA:
		var best: Creature = null
		for s: Creature in pool:
			if s.data.species == CreatureCatalog.TREE_SPIRIT or (best == null and s.data.species == CreatureCatalog.GOLD_TOAD):
				best = s if best == null or best.data.species != CreatureCatalog.TREE_SPIRIT else best
		if best != null:
			pick = best
	# 번천은 캄캄하다: 아기 도깨비불(불빛 + 불씨)이 있으면 데려간다
	if zone >= BUNJEON or (zone == DOMA and GameState.yak_state >= 2):
		for s: Creature in pool:
			if s.data.species == CreatureCatalog.WILL_O and s != herb_creature:
				pick = s
				break
	# 밀목은 그늘일 뿐 밤이 아니다: 아기 백호 > 아기 호랑이 (포효로 늑대를 멈춘다), 없으면 위에서 고른 그대로
	if zone >= MILMOK:
		for s: Creature in pool:
			if s.data.species == CreatureCatalog.WHITE_TIGER or (s.data.species == CreatureCatalog.TIGER and (pick == null or pick.data.species != CreatureCatalog.WHITE_TIGER)):
				pick = s
	pick_weapon()
	if GameState.lunches > 0:
		lunches_eaten += 1
	main.enter_hunt(pick, zone)
	var h: HuntGround = main.hunt
	if OS.get_environment("DEBUG_KO") != "" and not GameState.message.is_connected(_debug_msg):
		GameState.message.connect(_debug_msg)
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
	var bun_hurt0 := -1
	var mil_hurt0 := -1
	## 가방 · 창고가 차서 못 주운 드롭 자리 (이번 사냥에선 다시 가지 않음. 안 그러면 한 걸음 떨어졌다 돌아가기를 되풀이)
	var full_at := {}
	while t < 900.0:
		if h.zone == 2 and gwang_hurt0 < 0:
			gwang_hurt0 = hurt
			gwang_hunts += 1
			if gwang_day < 0:
				gwang_day = GameState.day
		if h.zone == BUNJEON and bun_hurt0 < 0:
			bun_hurt0 = hurt
			bun_hunts += 1
			if bun_day < 0:
				bun_day = GameState.day
		if h.zone == MILMOK and mil_hurt0 < 0:
			mil_hurt0 = hurt
			mil_hunts += 1
			if mil_day < 0:
				mil_day = GameState.day
		if h.zone == DOMA and doma_hurt0 < 0:
			doma_hurt0 = hurt
			doma_hunts += 1
			if doma_day < 0:
				doma_day = GameState.day
		if h.knocked:
			if OS.get_environment("DEBUG_KO") != "":
				for s: WildSlime in h.slimes:
					_log("  ! 쓰러질 때 남은 %s%s 체력 %d · 거리 %.0f" % [s.title, " (대장)" if s.boss else "", s.hp, s.position.distance_to(main.hunter.feet())])
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
		# 번천 유령: 불빛 안(맞힐 수 있는) 것부터, 없으면 가장 가까운 것에 다가가 호롱으로 비춘다
		var lit_s: WildSlime = h._nearest_slime(feet, true)
		if lit_s != null and h.is_night():
			nearest_s = lit_s
		# 나는 까마귀는 칼이 안 닿으니 땅에 앉은 것부터 노린다 (다 날고 있으면 가장 가까운 것을 따라감)
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
		# 더 깊은 구역으로 넘어가기 전, 하트가 모자라면 물약을 마신다 (사람이라면 그럴 것)
		var need_hearts := 5 if h.zone + 1 >= 2 else 3
		if nearest_s == null and h.path_open and h.path_block() == "" and h.hearts < need_hearts and GameState.potions > 0:
			h.drink_potion()
		if not pickups.is_empty():
			pickups.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_to(feet) < b.distance_to(feet))
			target = pickups[0]
			goal = &"pick"
		elif nearest_s != null:
			target = nearest_s.position
			goal = &"fight"
		elif h.path_open and h.path_block() == "" and h.hearts >= (5 if h.zone + 1 >= 2 else 3):
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
		# 주운 무기를 빈 칸이라 바로 들었으면 즐겨 드는 종류로 바꾼다
		var worn_w: StringName = GameState.worn[&"hunter"].get(&"weapon", &"")
		if worn_w != &"" and not _wanted_weapon(worn_w):
			pick_weapon()
		var w := Wearables.weapon()
		var ranged: bool = w.kind != &"melee"
		# 활 · 지팡이: 사거리 안이고 막힌 게 없으면 서서 쏘고, 너무 가까우면 물러선다. 숨은 몬스터는 다가가 깨운다.
		var away := false
		var shoot := false
		if goal == &"fight" and ranged and not h.hittable(nearest_s):
			pass
		elif goal == &"fight" and ranged and not (nearest_s.buried and not nearest_s.disguise):
			var hand := feet + Vector2(0, -8)
			var body := nearest_s.position + Vector2(0, -8 * nearest_s.scale.y)
			var d := hand.distance_to(body)
			var clear := _clear_shot(h, hand, body)
			if clear and d <= w.range * 0.85 and h._cooldown <= 0.0:
				shoot = true
			elif d < (NIGHT_KITE if h.is_night() and not nearest_s.boss else minf(KITE_DISTANCE * nearest_s.scale.x, w.range * 0.6)) and not nearest_s.stunned():
				away = true
			elif clear and d <= w.range * 0.85:
				# 쏠 틈을 기다린다 (제자리)
				target = feet
		if shoot:
			h.swing(nearest_s.position + Vector2(0, -8 * nearest_s.scale.y) - (feet + Vector2(0, -8)))
			shots_fired += 1
		elif goal == &"fight" and not ranged and nearest_s.position.distance_to(feet + Vector2(0, -8)) <= w.reach + w.radius - 2:
			if nearest_s.buried and nearest_s.position.distance_to(feet) > Config.WILD_BURROW_POP_DISTANCE:
				pass
			var before := h.slimes.size()
			h.swing(nearest_s.position - (feet + Vector2(0, -8)))
			if h.slimes.size() < before:
				kills += 1
		elif target == feet:
			pass
		else:
			var dir := _path_dir(h, feet, target)
			if away:
				dir = (feet - nearest_s.position).normalized()
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
		if h.slimes.size() < before_k and (goal != &"fight" or ranged):
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
		doma_hurt += (bun_hurt0 if bun_hurt0 >= 0 else hurt) - doma_hurt0
		doma_knocked += int(knocked and h.zone == DOMA)
	if bun_hurt0 >= 0:
		bun_hurt += (mil_hurt0 if mil_hurt0 >= 0 else hurt) - bun_hurt0
		bun_knocked += int(knocked and h.zone == BUNJEON)
	if mil_hurt0 >= 0:
		mil_hurt += hurt - mil_hurt0
		mil_knocked += int(knocked and h.zone == MILMOK)
	if h.boss_spawned and h._boss() == null:
		_cleared(h.zone)
	var comp := h.companion.display_name() if h.companion else "혼자"
	var picked := h.picked.size()
	if main.hunt:
		main.leave_hunt()
	var eggs: Array[String] = []
	for sp in GameState.hunter_eggs:
		eggs.append(sp.display_name)
		if sp == CreatureCatalog.TIGER or sp == CreatureCatalog.WHITE_TIGER:
			tigers_got[sp.display_name] = tigers_got.get(sp.display_name, 0) + 1
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
