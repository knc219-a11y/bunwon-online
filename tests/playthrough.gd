extends Node
## 핵심 루프 점검용 자동 플레이 (2026-09-28). 새 게임에서 며칠을 "보통 플레이어"처럼 돌리고 숫자를 남긴다.
## 실행: godot --headless --path . res://tests/playthrough.tscn   (환경변수 DAYS=10 SEED=1 OUT=경로 WEAPON=bow BOW=pierce|spread|volley|plain START=시작 지점 id)
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
## 크리처 방패가 대신 막은 횟수 합
var hunt_blocks := 0
var cleared_day := {}
## 하루 시계 (2026-09-29): 봇은 도구질을 순간에 끝내므로 실제 걸릴 시간을 어림한다 (초, 임시 어림값).
## 손 도구질 한 번 = 휘두르기 + 한 칸 걷기, 들나물 한 포기 = 풀밭까지 걷기, 공급함·부화기·집 오가기 = 하루 한 번에 묶어서.
const HAND_SEC := 1.0
const HERB_SEC := 4.0
const WALK_SEC := 30.0
## 주인공 하나 (2026-10-03): 밭 ↔ 사냥터 입구 걸어서 왕복 (20칸쯤 x 2, 걷기 82px/초). 예전엔 Tab 으로 바로 바꿨다.
const GATE_WALK_SEC := 12.0
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
## 장비를 갈아 얻은 고철 (2026-10-03 백로그 8)
var salvaged_scrap := 0
## 광동리 (2026-09-29 선택 B): 처음 도착한 날 · 광동리에서 사냥한 날 수 · 거기서 잃은 체력 · 쓰러진 횟수 · 날마다 끝 돈
var gwang_day := -1
var gwang_hunts := 0
var gwang_hurt := 0
var gwang_knocked := 0
var money_by_day := {}
## 도마리 (2026-09-29, 2막 마지막 구역): 처음 도착한 날 · 사냥한 날 수 · 거기서 잃은 체력 · 쓰러진 횟수
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
## 약방 · 번천 (2026-09-29, 3막): 약방 터 · 복구한 날, 번천 첫 도착 · 사냥 수 · 잃은 체력 · 쓰러짐, 도라지밭 크리처, 만든 것
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
## 밀목 · 축사 (2026-09-30, 3막 둘째 구역): 밀목 첫 도착 · 사냥 수 · 잃은 체력 · 쓰러짐, 축사 터 · 복구한 날, 닭장 기록
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
## 나루터 (2026-10-02 시설 4, 통발): 터 · 복구 날, 잡은 · 판 물고기, 끓인 · 먹은 매운탕, 물고기 몰기 크리처
var naru_site_day := -1
var naru_restore_day := -1
var fish_caught := 0
var fish_sold := 0
var stews_made := 0
var stews_eaten := 0
var fish_creature: Creature = null
var weasel_nights := 0
var tigers_got := {}
## 역동 (2026-10-02, 4막 첫 구역): 첫 도착 · 사냥 수 · 잃은 체력 · 쓰러짐, 아기 망아지 알 · 깊이 간 칸에서 더 거둔 무
const YEOKDONG := 6
var yd_day := -1
var yd_hunts := 0
var yd_hurt := 0
var yd_knocked := 0
var foals_got := 0
var plow_bonus := 0
## 곤지암 (2026-10-02, 4막 대장 구역): 첫 도착 · 사냥 수 · 잃은 체력 · 쓰러짐, 아기 악귀 알 · 밤일 수
const GONJIAM := 7
## 5막 (2026-10-03): 귀여리 (마을 입구) · 소내섬 (나룻배). 둘 다 웨이포인트에서 따로 들어가므로 사냥 한 번 통째로 센다.
## 구역 번호 → {day 첫 도착, hunts, hurt, knocked, boss 처음 잡은 날, dragons 만난 대장 이름별 수}
var act5 := {}
## 마을회관 · 잔치 (2026-10-03 시설 5 · 엔딩): 터 · 복구 · 잔치를 연 날, 들어준 부탁, 심부름 크리처, 잔치상에 쓰려고 따로 둔 것
var hall_site_day := -1
var hall_restore_day := -1
var final_day := -1
var errand_creature: Creature = null
## 시설 공사 (2026-10-03 백로그 4번): 터 공사를 맡긴 크리처 · 시설마다 공사를 시작한 날
var build_creature: Creature = null
var build_start := {}
var feast_hidden := {}
## 밭 작물 (2026-10-03 농사 다양화): 판 수 (작물 id → 수) · 작물이 열린 날
var crops_sold := {}
var crop_open_day := {}
## 작물 등급 (2026-10-03 돌봄 점수): 판 작물 등급별 수 (작물 id → [★1, ★2, ★3]) · 만든 퇴비 (재료별) · 준 퇴비 · 만든 음식 (id → [★1, ★2, ★3]) · 무가 모자라 무를 더 심은 날
var grade_sold := {}
var compost_made := {}
var compost_used := 0
var cooked := {}
var radish_short_days := 0
## 1일째부터 센 사람 어림 시간 (초) · 잔치를 연 날까지의 그 값
var total_human_sec := 0.0
var feast_human_sec := -1.0
var final_human_sec := -1.0
var gj_day := -1
var gj_hunts := 0
var gj_hurt := 0
var gj_knocked := 0
var imps_got := 0
var night_jobs := 0
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
	# BOW (2026-10-02 활 몰아잡기 후보): pierce · spread · volley. 비우면 게임 기본
	if OS.get_environment("BOW") != "":
		HuntGround.bow_style = StringName(OS.get_environment("BOW")) if OS.get_environment("BOW") != "plain" else &""
	seed(rng_seed)
	expedition_on = OS.get_environment("EXPEDITION") != "0"
	skills_on = OS.get_environment("SKILLS") != "0"
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	main._rng.seed = rng_seed
	# START (2026-10-02 곤지암): 테스트용 시작 지점에서 이어 돌린다 (예: START=gonjiam DAYS=8, 구역 값만 빨리 맞출 때)
	if OS.get_environment("START") != "":
		TestStarts.apply(main, StringName(OS.get_environment("START")))
	# LEVEL (2026-10-02 3~4막 난이도): 시작 레벨을 바꿔 스킬을 처음부터 다시 찍는다 (레벨 곡선 후보를 빨리 보려고)
	if OS.get_environment("LEVEL") != "":
		GameState.hunter_level = int(OS.get_environment("LEVEL"))
		GameState.hunter_xp = 0
		GameState.skills = {}
		GameState.skill_points = GameState.hunter_level - 1 + GameState.bosses_beaten.filter(func(z: int) -> bool: return HunterSkills.is_act_boss_zone(z)).size()
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
	_log("\n사냥: %d번 · 잃은 체력 %d (하루 평균 %.1f) · 방패가 막음 %d · 쓰러짐 %d번 · 대장 처음 쓰러뜨린 날 %s" % [hunt_days, hunt_hurt, float(hunt_hurt) / maxi(hunt_days, 1), hunt_blocks, hunt_knocked, cleared_day])
	_log("\n하루 끝 시각 (봇 · 사람 어림 x%.0f, 6시 시작, 실제 1초 = 게임 %s분): %s" % [HUMAN_MULT, Config.CLOCK_MINUTES_PER_SECOND, ", ".join(clock_ends)])
	_log("\n들나물·채집 (14일 합계): 손일 %d번 · 들나물 손으로 %d포기 · 크리처가 %d포기 · 도라지 %d뿌리 (%d원)" % [total_manual, total_hand_herbs, total_creature_herbs, total_roots, total_roots * Config.ROOT_PRICE])
	_log("\n크리처 일 배분 (14일 합계): 밭 4구역이 모두 농사로 찬 날 %s · 농사 크리처가 한가할 때 캔 나물·뿌리 %d · 물 준 풀밭 덕분에 더 돋은 나물 %d포기" % ["%d일" % full_day if full_day > 0 else "없음", total_idle_herbs, total_water_bonus])
	var last := gross.slice(maxi(0, gross.size() - 7))
	var avg := 0.0
	for g in last:
		avg += g
	avg /= maxf(last.size(), 1)
	var scrap_by_creature := 0
	for c: Creature in main.creatures:
		if c.job == CreatureJobs.SCRAP:
			scrap_by_creature += c.scraps
	_log("\n시설 일꾼 (멍석): %s · 장비를 갈아 얻은 고철 %d · 남은 고철 %d" % [" · ".join(FacilityWorkers.FACILITIES.map(func(f: StringName) -> String: return "%s %s" % [FacilityWorkers.NAMES[f], FacilityWorkers.count_text(main, f)])), salvaged_scrap, GameState.scrap])
	_log("\n대장간: 터 %s · 복구 %s · 복구비를 모으느라 안 산 날 %s · 장비 제작 %d번 (%d원) · 크리처가 캔 고철 %d · 마지막 7일 하루 벌이 평균 %.0f원 · 끝에 남은 돈 %d원 = 하루 벌이의 %.1f배" % [
		"%d일" % site_day if site_day > 0 else "없음", "%d일" % restore_day if restore_day > 0 else "없음", held_days, crafted, craft_spent, scrap_by_creature, avg, GameState.money, GameState.money / maxf(avg, 1.0)])
	var money_at := []
	for d in [30, 35, 40]:
		if money_by_day.has(d):
			money_at.append("%d일 %d원" % [d, money_by_day[d]])
	_log("\n광동리: 첫 도착 %s · 첫 대장 처치 %s · 광동리 사냥 %d번 · 거기서 잃은 체력 %d (한 번에 %.1f) · 쓰러짐 %d번 · 끝 돈 %s · 아기 까마귀 %d마리" % [
		"%d일" % gwang_day if gwang_day > 0 else "없음", cleared_day.get(Config.HUNT_ZONES[2].name, "없음"), gwang_hunts, gwang_hurt,
		float(gwang_hurt) / maxi(gwang_hunts, 1), gwang_knocked, money_at, main.creatures.filter(func(c: Creature) -> bool: return c.data.species == CreatureCatalog.SPARROW).size()])
	var money_late := []
	for d in [40, 45, 50]:
		if money_by_day.has(d):
			money_late.append("%d일 %d원" % [d, money_by_day[d]])
	_log("\n도마리: 첫 도착 %s · 2막 대장(장승 한 쌍) 첫 처치 %s · 도마리 사냥 %d번 · 거기서 잃은 체력 %d (한 번에 %.1f) · 쓰러짐 %d번 · 끝 돈 %s · 아기 나무 정령 %d마리" % [
		"%d일" % doma_day if doma_day > 0 else "없음", cleared_day.get(Config.HUNT_ZONES[DOMA].name, "없음"), doma_hunts, doma_hurt,
		float(doma_hurt) / maxi(doma_hunts, 1), doma_knocked, money_late, main.creatures.filter(func(c: Creature) -> bool: return c.data.species == CreatureCatalog.TREE_SPIRIT).size()])
	_log("\n약방 · 번천: 약방 터 %s · 복구 %s (장승 조각 %d · 도라지 %d) · 번천 첫 도착 %s · 유령 막차 첫 처치 %s · 번천 사냥 %d번 · 거기서 잃은 체력 %d (한 번에 %.1f) · 쓰러짐 %d번 · 만든 것 %s · 보약 먹인 날 %d · 도라지밭 %s · 아기 도깨비불 %d마리" % [
		"%d일" % yak_site_day if yak_site_day > 0 else "없음", "%d일" % yak_restore_day if yak_restore_day > 0 else "없음", GameState.material2, GameState.roots,
		"%d일" % bun_day if bun_day > 0 else "없음", cleared_day.get(Config.HUNT_ZONES[BUNJEON].name, "없음"), bun_hunts, bun_hurt,
		float(bun_hurt) / maxi(bun_hunts, 1), bun_knocked, brewed, tonic_days, herb_creature.describe() if herb_creature else "없음",
		main.creatures.filter(func(c: Creature) -> bool: return c.data.species == CreatureCatalog.WILL_O).size()])
	_log("\n밀목 · 축사: 밀목 첫 도착 %s · 산군 백호 첫 처치 %s · 밀목 사냥 %d번 · 거기서 잃은 체력 %d (한 번에 %.1f) · 쓰러짐 %d번 · 산군 발톱 %d · 축사 터 %s · 복구 %s · 암탉 %d (병아리 %d) · 판 달걀 %d · 먹은 도시락 %d · 족제비 %d밤 · 얻은 알 %s · 모이 주기 %s" % [
		"%d일" % mil_day if mil_day > 0 else "없음", cleared_day.get(Config.HUNT_ZONES[MILMOK].name, "없음"), mil_hunts, mil_hurt,
		float(mil_hurt) / maxi(mil_hunts, 1), mil_knocked, GameState.material3, "%d일" % barn_site_day if barn_site_day > 0 else "없음",
		"%d일" % barn_restore_day if barn_restore_day > 0 else "없음", GameState.hens, GameState.chicks.size(), hen_eggs_sold, lunches_eaten, weasel_nights, tigers_got,
		feed_creature.describe() if feed_creature else "없음"])
	_log("\n역동: 첫 도착 %s · 역마 장군 첫 처치 %s · 역동 사냥 %d번 · 거기서 잃은 체력 %d (한 번에 %.1f) · 쓰러짐 %d번 · 아기 망아지 알 %d · 농사 맡은 망아지 %d · 깊이 간 칸에서 더 거둔 무 %d" % [
		"%d일" % yd_day if yd_day > 0 else "없음", cleared_day.get(Config.HUNT_ZONES[YEOKDONG].name, "없음"), yd_hunts, yd_hurt,
		float(yd_hurt) / maxi(yd_hunts, 1), yd_knocked, foals_got,
		main.creatures.filter(func(c: Creature) -> bool: return c.data.species == CreatureCatalog.FOAL and c.job == CreatureJobs.FARM).size(), plow_bonus])
	_log("\n곤지암: 첫 도착 %s · 마왕 첫 처치 %s · 곤지암 사냥 %d번 · 거기서 잃은 체력 %d (한 번에 %.1f) · 쓰러짐 %d번 · 아기 악귀 알 %d · 아기 악귀 %d마리 · 밤일 %d번" % [
		"%d일" % gj_day if gj_day > 0 else "없음", cleared_day.get(Config.HUNT_ZONES[GONJIAM].name, "없음"), gj_hunts, gj_hurt,
		float(gj_hurt) / maxi(gj_hunts, 1), gj_knocked, imps_got,
		main.creatures.filter(func(c: Creature) -> bool: return c.data.species == CreatureCatalog.IMP).size(), night_jobs])
	_log("\n나루터: 터 %s · 복구 %s · 남은 마왕 뿔 %d · 잡은 물고기 %d · 판 물고기 %d · 끓인 매운탕 %d · 먹은 매운탕 %d · 물고기 몰기 %s" % [
		"%d일" % naru_site_day if naru_site_day > 0 else "없음", "%d일" % naru_restore_day if naru_restore_day > 0 else "없음", GameState.material4,
		fish_caught, fish_sold, stews_made, stews_eaten, fish_creature.describe() if fish_creature else "없음"])
	for zi: int in [8, 9]:
		var a: Dictionary = act5.get(zi, {})
		_log("\n%s: 첫 도착 %s · 대장 첫 처치 %s · 사냥 %d번 · 잃은 체력 %d (한 번에 %.1f) · 쓰러짐 %d번 · 방패에 막힌 공격 %d · 만난 대장 %s" % [
			Config.HUNT_ZONES[zi].name, "%d일" % a.day if a.has("day") else "없음", cleared_day.get(Config.HUNT_ZONES[zi].name, "없음"),
			a.get("hunts", 0), a.get("hurt", 0), float(a.get("hurt", 0)) / maxi(a.get("hunts", 0), 1), a.get("knocked", 0), a.get("blocked", 0), a.get("dragons", {})])
	_log("마지막 대장 처치: %s" % ("예" if GameState.final_boss_down else "아니오"))
	_feast_unhide()
	_log("\n마을회관 · 잔치: 마지막 대장 첫 처치 %s (사람 어림 %s) · 회관 터 %s · 복구 %s · 들어준 부탁 %d · 남은 용 비늘 %d · 잔치상 %d/%d · 잔치 %s (사람 어림 %s) · 심부름 %s" % [
		"%d일" % final_day if final_day > 0 else "없음", _hours(final_human_sec), "%d일" % hall_site_day if hall_site_day > 0 else "없음",
		"%d일" % hall_restore_day if hall_restore_day > 0 else "없음", GameState.requests_done, GameState.material5,
		GameState.feast_dishes.size(), Config.FEAST_DISHES.size(), "%d일" % GameState.feast_day if GameState.feast_day > 0 else "없음",
		_hours(feast_human_sec), errand_creature.describe() if errand_creature else "없음"])
	_log("1일째부터 사람 어림 시간 합: %s (%d일)" % [_hours(total_human_sec), GameState.day - 1])
	_log("\n밭 작물: 구역에 심기 시작한 날 %s · 판 수 %s · 구역 작물 %s · 남은 씨앗 무 %d 감자 %d 고추 %d 배추 %d" % [crop_open_day, crops_sold,
		range(GameState.open_plots).map(func(i: int) -> String: return Crops.display_name(Crops.plot_kind(i))), GameState.seeds, GameState.potato_seeds, GameState.pepper_seeds, GameState.cabbage_seeds])
	_log("작물 등급: 판 작물 [★1, ★2, ★3] %s · 퇴비 만든 것 %s · 준 퇴비 %d칸 · 남은 퇴비 %d · 만든 음식 %s · 무가 모자라 무를 더 심은 날 %d" % [grade_sold, compost_made, compost_used, GameState.compost, cooked, radish_short_days])
	var crowd := []
	for d in [20, 40, 60, 80, 100]:
		if crowd_by_day.has(d):
			var c: Array = crowd_by_day[d]
			crowd.append("%d일 전체 %d · 놀고 있는 %d · 원정 %d · 입양 %d" % [d, c[0], c[1], c[2], c[3]])
	_log("\n크리처 원정 · 입양 (%s): %s · 원정 돈 합 %d원 · 원정 장비 %d · 입양 %d마리 %s" % ["켬" if expedition_on else "끔", " / ".join(crowd), expedition_money, expedition_gear, adopted_n,
		GameState.adopted.map(func(a: Dictionary) -> String: return "%s→%s" % [load(a.species).display_name, a.who])])
	var lv := []
	for d in [2, 5, 10, 15, 20, 25, 30, 40, 50, 60, 70, 80, 90, 100, 110]:
		if level_by_day.has(d):
			lv.append("%d일 Lv%d" % [d, level_by_day[d]])
	_log("\n시설 공사 시작한 날 (재료 다 모은 날): %s · 문 연 날: 대장간 %d · 약방 %d · 축사 %d · 나루터 %d · 회관 %d" % [build_start, restore_day, yak_restore_day, barn_restore_day, naru_restore_day, hall_restore_day])
	_log("\n사냥꾼 레벨 (%s): %s · 끝 Lv %d (남은 포인트 %d) · 찍은 스킬 %s" % ["스킬 찍음" if skills_on else "스킬 안 찍음", " · ".join(lv), GameState.hunter_level, GameState.skill_points, GameState.skills])
	_log("직업 %s · 스탯 %s (남은 %d)" % [HunterClass.class_name_of(GameState.hunter_class), GameState.stats, GameState.stat_points])
	_log("무기 (봇이 즐겨 듦: %s): 처음 든 날 %s · 쏜 화살 · 구슬 %d" % [weapon_pref, "%d일" % weapon_day if weapon_day > 0 else "없음", shots_fired])
	_log("입은 장비: 밭 옷 %s · 사냥 옷 %s" % [_worn_text(&"farmer"), _worn_text(&"hunter")])
	_log("\n최종: %d일째, 돈 %d원, 씨앗 %d, 크리처 %d (훈련 단계 합 %d), 밭 구역 %d, 웨이포인트 %s" % [GameState.day, GameState.money, GameState.seeds, main.creatures.size(), trained, GameState.open_plots, GameState.waypoints])
	var out := OS.get_environment("OUT")
	if out != "":
		var f := FileAccess.open(out, FileAccess.WRITE)
		f.store_string("\n".join(log_lines))
	get_tree().quit()


func _hours(sec: float) -> String:
	return "%.1f시간" % (sec / 3600.0) if sec >= 0.0 else "없음"


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
	if GameState.naru_state >= 1 and naru_site_day < 0:
		naru_site_day = GameState.day
	if GameState.hall_state >= 1 and hall_site_day < 0:
		hall_site_day = GameState.day
	_log("\n## %d일째 (시작 돈 %d, 씨앗 %d, 작물 %d)" % [GameState.day, GameState.money, GameState.seeds, GameState.crops])
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
	_log("손일: 손으로 한 도구질 %d번 %s · 공급함: %s" % [manual_actions, farm_counts, bought])
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
	total_human_sec += human_sec
	if GameState.final_boss_down and final_day < 0:
		final_day = GameState.day
		final_human_sec = total_human_sec
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
		if l.begins_with("아기 악귀가 밤새"):
			var m := RegEx.create_from_string("(\\d+)번").search(l)
			if m:
				night_jobs += m.get_string(1).to_int()
		if l.begins_with("원정대"):
			var m := RegEx.create_from_string("\\+(\\d+)원").search(l)
			if m:
				expedition_money += m.get_string(1).to_int()
	total_water_bonus += main.forage.bonus_today
	gross.append(GameState.money - money0 + spent_today)
	money_by_day[GameState.day - 1] = GameState.money
	_log("하루 수입 %+d원 · 부화 기다리는 알 %d개 (주인공 %d · 공급함 %d)" % [GameState.money - money0, GameState.farmer_eggs.size() + GameState.village_eggs.size(), GameState.farmer_eggs.size(), GameState.village_eggs.size()])


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
	# 아기 망아지 (2026-10-02 역동): 밭이 다 찼으면 슬라임 농사 하나를 채집으로 돌리고 그 밭을 맡긴다 (밭 갈기, 플레이어가 할 법한 배치)
	# 아기 악귀 (2026-10-02 곤지암): 같은 식으로 슬라임 농사 하나 대신 밭을 맡긴다 (밤일)
	for s: Creature in main.creatures:
		if s.home != main.HATCH_CELL or not (s.data.species in [CreatureCatalog.FOAL, CreatureCatalog.IMP]) or farmers < GameState.open_plots:
			continue
		for o: Creature in main.creatures:
			if o.job != CreatureJobs.FARM or o.data.species != CreatureCatalog.SLIME or o.home == main.HATCH_CELL:
				continue
			var plot_i := -1
			for i in GameState.open_plots:
				if Config.FIELD_PLOTS[i].has_point(o.home):
					plot_i = i
			if plot_i < 0:
				continue
			_assign(o, CreatureJobs.FORAGE, 0)
			_assign(s, CreatureJobs.FARM, plot_i)
			break
	for s: Creature in main.creatures:
		if s.home != main.HATCH_CELL:
			continue
		# 아기 까마귀는 채집 재능이라 채집 전담 (플레이어가 할 법한 배치)
		if farmers < GameState.open_plots and s.data.species != CreatureCatalog.SPARROW:
			_assign(s, CreatureJobs.FARM, farmers)
			farmers += 1
		else:
			_assign(s, CreatureJobs.FORAGE, 0)
	# 크리처 시설 배치 (2026-10-03): 고친 시설마다 멍석 (일꾼 자리) 을 채운다. 채집 전담 중 그 일에 잘 맞는 크리처부터,
	# 마을에 채집 전담 MIN_FORAGERS 마리는 남긴다. 더 잘 맞는 크리처 (약방 아기 도깨비불 · 축사 지킴이) 가 생기면 바꿔 앉힌다.
	for fac: StringName in FacilityWorkers.FACILITIES:
		if not FacilityWorkers.is_open(fac):
			continue
		while FacilityWorkers.free_slot(main, fac).x >= 0:
			var pick := _best_worker(fac)
			if pick == null:
				break
			_to_mat(pick, fac)
		var ws := FacilityWorkers.workers(main, fac)
		if ws.is_empty() or ws.any(func(w: Creature) -> bool: return _preferred(fac, w)):
			continue
		var better := _best_worker(fac, true)
		if better != null and _preferred(fac, better):
			_assign(ws[0], CreatureJobs.FORAGE, 0)
			_to_mat(better, fac)
	var firsts := {}
	for fac: StringName in FacilityWorkers.FACILITIES:
		var ws := FacilityWorkers.workers(main, fac)
		firsts[fac] = ws[0] if not ws.is_empty() else null
	scrap_creature = firsts[&"forge"]
	herb_creature = firsts[&"yak"]
	feed_creature = firsts[&"barn"]
	fish_creature = firsts[&"naru"]
	errand_creature = firsts[&"hall"]
	if FacilityWorkers.is_open(&"yak") and GameState.yak_brew == &"":
		# 약방 일꾼에게 맡길 약: 힘 물약 (봇이 가장 많이 쓰는 약, 사람이라면 고를 것)
		while GameState.yak_brew != &"strength":
			main.cycle_yak_brew()
		_log("약방 일꾼이 아침마다 달일 약: 힘 물약")
	# 공사 중인 터가 있으면 채집 전담 하나 (땅속성 먼저) 에게 터 공사, 공사가 없으면 채집으로 돌린다 (2026-10-03)
	if SiteWork.build_site() != &"" and build_creature == null:
		var pick: Creature = null
		for s: Creature in main.creatures:
			if s.home == main.HATCH_CELL or s.job != CreatureJobs.FORAGE or s.expedition_zone >= 0:
				continue
			if pick == null or (s.has_element(&"earth") and not pick.has_element(&"earth")):
				pick = s
		if pick != null:
			build_creature = pick
			while pick.job != CreatureJobs.BUILD:
				pick.next_job()
			_log("크리처 배치: %s → 터 공사 (%s)" % [pick.describe(), SiteWork.NAMES[SiteWork.build_site()]])
	elif SiteWork.build_site() == &"" and build_creature != null:
		_assign(build_creature, CreatureJobs.FORAGE, 0)
		build_creature = null
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


## 마을에 남기는 채집 전담 수 (시설 멍석을 채울 때)
const MIN_FORAGERS := 3


## 시설에 더 잘 맞는 크리처 (약방 = 아기 도깨비불, 축사 = 족제비 지킴이)
func _preferred(fac: StringName, c: Creature) -> bool:
	match fac:
		&"yak":
			return c.data.species == CreatureCatalog.WILL_O
		&"barn":
			return c.data.species.guards_coop
	return false


## 그 시설 일꾼으로 고를 채집 전담 (잘 맞는 순). any_count 면 채집 전담 수를 안 따진다 (바꿔 앉힐 때).
func _best_worker(fac: StringName, any_count := false) -> Creature:
	var pool: Array[Creature] = []
	for c: Creature in main.creatures:
		if c.home == main.HATCH_CELL or c.job != CreatureJobs.FORAGE or c.expedition_zone >= 0 or c == build_creature or c.carried_by != null:
			continue
		pool.append(c)
	if pool.size() <= MIN_FORAGERS and not any_count:
		return null
	if pool.is_empty():
		return null
	var job: StringName = FacilityWorkers.JOBS[fac]
	var best: Creature = null
	var best_score := -1.0
	for c in pool:
		var score := c.data.work_speed(job) * (c.data.move_speed() if fac == &"hall" else 1.0)
		if _preferred(fac, c):
			score += 100.0
		# 아기 까마귀는 채집 재능이라 웬만하면 채집에 남긴다
		if c.data.species == CreatureCatalog.SPARROW and fac != &"hall":
			score *= 0.5
		if score > best_score:
			best_score = score
			best = c
	return best


## 크리처를 들어 (F) 시설 멍석 근처에서 내려놓는다 (F). 플레이어가 할 법한 그대로.
func _to_mat(c: Creature, fac: StringName) -> void:
	# 풀밭 크리처는 몰려 있어서 F 로 들면 옆 크리처를 들 수 있다: 이 크리처를 바로 든다
	main.player.position = c.position
	c.pick_up(main.player)
	var slot := FacilityWorkers.free_slot(main, fac)
	main.player.position = Farm.center_of(slot + Vector2i(0, 1))
	main.interact()
	_log("크리처 배치: %s → %s 일꾼 (멍석 %s · %s)" % [c.describe(), FacilityWorkers.NAMES[fac], c.home, FacilityWorkers.count_text(main, fac)])


## 크리처를 들어 옮기고 (F 두 번) 일을 R로 바꾼다. 농사면 plot_i 구역 가운데, 채집이면 풀밭.
func _assign(s: Creature, want: StringName, plot_i: int) -> void:
	var plot := Config.FIELD_PLOTS[plot_i]
	var at := plot.position + Vector2i(plot.size.x / 2, plot.size.y / 2)
	if want == CreatureJobs.FORAGE:
		at = FORAGE_HOME
	main.player.position = s.position
	main.interact()
	main.player.position = Farm.center_of(at)
	main.interact()
	while s.job != want:
		s.next_job()
	_log("크리처 배치: %s → %s 칸 %s" % [s.describe(), "풀밭" if want == CreatureJobs.FORAGE else Config.FIELD_PLOT_NAMES[plot_i], at])


func let_creatures_work() -> void:
	# 깊이 간 칸의 익은 무 (오늘 거두면 무가 더 나옴, 역동 아기 망아지)
	for c: Farm.Cell in farm._cells.values():
		if c.plowed and c.is_ripe():
			plow_bonus += Config.PLOW_BONUS
	Engine.time_scale = 20.0
	for i in 600:
		await get_tree().process_frame
		creature_sec += get_process_delta_time()
		var busy := false
		for s: Creature in main.creatures:
			if s._busy:
				busy = true
			elif s.job == CreatureJobs.FARM and (CreatureJobs.PLOW_ORDER if s.data.species.job_aptitude.has(CreatureJobs.PLOW) else CreatureJobs.FARM_ORDER).any(func(t: StringName) -> bool: return farm.find_work(CreatureJobs.FARM_WORK[t], s.home, s.data.work_radius(), [], Farm.center_of(s.home)) != null):
				busy = true
			elif s.job in [CreatureJobs.FARM, CreatureJobs.FORAGE] and main.forage.nearest_target(s.position, s.has_element(&"earth")) != null:
				busy = true
			elif s.job == CreatureJobs.SCRAP and (s.dug_today < s.dig_cap() or s.position.distance_to(Farm.center_of(s.home)) > 1.0):
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
		main.player.position = Farm.center_of(cell) - Vector2(0, main.player.FEET_Y)
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
	var fert := fertilize_by_hand()
	if fert > 0:
		manual_actions += fert
		counts["퇴비"] = fert
	return counts


## 문이 열린 날 (공사가 끝난 다음 날 아침 저절로 열림)
func _record_restores() -> void:
	if restore_day < 0 and GameState.forge_state >= 2:
		restore_day = GameState.day
	if yak_restore_day < 0 and GameState.yak_state >= 2:
		yak_restore_day = GameState.day
	if barn_restore_day < 0 and GameState.barn_state >= 2:
		barn_restore_day = GameState.day
	if naru_restore_day < 0 and GameState.naru_state >= 2:
		naru_restore_day = GameState.day
	if hall_restore_day < 0 and GameState.hall_state >= 2:
		hall_restore_day = GameState.day


## 공급함: 알 받기 · 무 진열 · 살 수 있는 것 사기 (밭 넓히기 → 물뿌리개 → 괭이 → 부족한 씨앗 → 사냥칼 → 크리처 훈련)
func shop() -> Array[String]:
	var did: Array[String] = []
	if not GameState.village_eggs.is_empty():
		main.supply_action(&"take_eggs")
		did.append("알 받기")
	# 시설 공사 (2026-10-03 백로그 4번): 재료가 다 모이면 돈 · 무를 남겨 두고 공사를 시작한다. 문은 공사가 끝난 다음 날 아침 저절로 열린다.
	_record_restores()
	var saving := GameState.forge_state == 1 and not SiteWork.building(&"forge") and GameState.material >= Config.FORGE_COST_MATERIAL
	if saving and GameState.crops >= Config.FORGE_COST_CROPS and GameState.money >= Config.FORGE_COST_MONEY:
		main.player.position = Farm.center_of(Config.FORGE_RECT.position + Vector2i(1, Config.FORGE_RECT.size.y))
		main.restore_forge()
		if SiteWork.building(&"forge"):
			build_start[&"forge"] = GameState.day
			did.append("대장간 공사 시작(%d원 · 무 %d · %s %d)" % [Config.FORGE_COST_MONEY, Config.FORGE_COST_CROPS, Config.BOSS_MATERIAL_NAME, Config.FORGE_COST_MATERIAL])
			saving = false
	var keep_crops := mini(GameState.crops, Config.FORGE_COST_CROPS) if saving else 0
	var reserve := Config.FORGE_COST_MONEY if saving else 0
	if GameState.yak_state == 1 and not SiteWork.building(&"yak") and GameState.material2 >= Config.YAK_COST_MATERIAL:
		if main.can_restore_yak():
			main.restore_yak()
			build_start[&"yak"] = GameState.day
			did.append("약방 공사 시작(%d원 · %s %d · %s %d)" % [Config.YAK_COST_MONEY, Config.ROOT_NAME, Config.YAK_COST_ROOTS, Config.BOSS_MATERIAL2_NAME, Config.YAK_COST_MATERIAL])
		else:
			reserve = maxi(reserve, Config.YAK_COST_MONEY)
	if GameState.hall_state == 1 and not SiteWork.building(&"hall") and GameState.material5 >= Config.HALL_COST_MATERIAL:
		if VillageHall.can_restore():
			VillageHall.restore(main)
			build_start[&"hall"] = GameState.day
			did.append("마을회관 공사 시작(%d원 · 무 %d · %s %d)" % [Config.HALL_COST_MONEY, Config.HALL_COST_CROPS, Config.BOSS_MATERIAL5_NAME, Config.HALL_COST_MATERIAL])
		else:
			reserve = maxi(reserve, Config.HALL_COST_MONEY)
			keep_crops = maxi(keep_crops, mini(GameState.crops, Config.HALL_COST_CROPS))
	hall_day(did)
	if GameState.barn_state == 1 and not SiteWork.building(&"barn") and GameState.material3 >= Config.BARN_COST_MATERIAL:
		if main.can_restore_barn():
			main.restore_barn()
			build_start[&"barn"] = GameState.day
			did.append("축사 공사 시작(%d원 · 무 %d · %s %d)" % [Config.BARN_COST_MONEY, Config.BARN_COST_CROPS, Config.BOSS_MATERIAL3_NAME, Config.BARN_COST_MATERIAL])
		else:
			reserve = maxi(reserve, Config.BARN_COST_MONEY)
			keep_crops = maxi(keep_crops, mini(GameState.crops, Config.BARN_COST_CROPS))
	if GameState.barn_state >= 2:
		coop_day(did)
	if GameState.naru_state == 1 and not SiteWork.building(&"naru") and GameState.material4 >= Config.NARU_COST_MATERIAL:
		if main.can_restore_naru():
			main.restore_naru()
			build_start[&"naru"] = GameState.day
			did.append("나루터 공사 시작(%d원 · 무 %d · %s %d)" % [Config.NARU_COST_MONEY, Config.NARU_COST_CROPS, Config.BOSS_MATERIAL4_NAME, Config.NARU_COST_MATERIAL])
		else:
			reserve = maxi(reserve, Config.NARU_COST_MONEY)
			keep_crops = maxi(keep_crops, mini(GameState.crops, Config.NARU_COST_CROPS))
	if GameState.naru_state >= 2:
		dock_day(did)
	if GameState.yak_state >= 2:
		brew_day(did)
	var held := false
	plan_plots(did)
	cook_day(did)
	# 무는 복구용 · 고추는 매운탕 두 그릇 몫을 남기고 나머지 작물은 모두 진열 (2026-10-03 밭 작물)
	var keep_peppers := mini(GameState.peppers, 2 * Config.STEW_PEPPERS) if GameState.naru_state >= 1 else 0
	GameState.crops -= keep_crops
	GameState.peppers -= keep_peppers
	if Crops.held_total() > 0:
		for k in Crops.ORDER:
			crops_sold[k] = int(crops_sold.get(k, 0)) + Crops.held(k)
			var st := Crops.stars(k)
			var g: Array = grade_sold.get(k, [0, 0, 0])
			grade_sold[k] = [g[0] + st[0], g[1] + st[1], g[2] + st[2]]
		did.append("작물 진열 %s%s" % [Crops.held_text(), (" (무 복구용 %d 남김)" % keep_crops) if keep_crops > 0 else ""])
		main.supply_action(&"display_crops")
	elif keep_crops > 0:
		did.append("무 %d 복구용으로 남김" % keep_crops)
	GameState.crops += keep_crops
	GameState.peppers += keep_peppers
	if GameState.forge_state >= 2:
		craft_day(did)
	if GameState.herbs > 0:
		did.append("들나물 %d 진열" % GameState.herbs)
		main.supply_action(&"display_herbs")
	var keep := true
	while keep:
		keep = false
		var empty := {}
		for c: Vector2i in farm._cells:
			var cell: Farm.Cell = farm._cells[c]
			if not cell.planted:
				var k := Crops.kind_at(c)
				empty[k] = int(empty.get(k, 0)) + 1
		var bought_seed := false
		for k: StringName in empty:
			if empty[k] > Crops.seeds(k) and GameState.money >= int(Crops.info(k).pack_price) and Crops.buy_seeds(k):
				did.append("%s 씨앗" % Crops.display_name(k))
				bought_seed = true
				break
		if bought_seed:
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


## 밭 구역 작물 (2026-10-03 농사 다양화): 사람처럼 열린 작물을 구역마다 하나씩 (처음 밭은 시설 복구에 드는 무 그대로).
## 구역 순서 = 열린 순서: 오른쪽 구역 감자 · 왼쪽 아래 고추 · 오른쪽 아래 배추.
## 무가 모자라면 (PR #69 봇: 잔치가 안 열림) 배추 구역 · 감자 구역도 무로 돌린다. 모자람 = 공사 몫으로 남겨 둘 무보다 적음 (반도 안 되면 감자 구역까지).
## 회관을 고친 뒤 잔치 배추가 모자라면 배추 구역은 배추.
func plan_plots(did: Array[String]) -> void:
	var want: Array[StringName] = [&"radish", &"potato", &"pepper", &"cabbage"]
	var need := _radish_need()
	if GameState.crops < need:
		radish_short_days += 1
		want[3] = &"radish"
		if GameState.crops * 2 < need:
			want[1] = &"radish"
	if GameState.hall_state >= 2 and GameState.cabbages + int(feast_hidden.get("cabbages", 0)) < 4:
		want[3] = &"cabbage"
	for i in GameState.open_plots:
		var k := want[i] if want[i] == &"radish" or want[i] in GameState.crop_unlocked else &"radish"
		if Crops.plot_kind(i) != k:
			Crops.set_plot(i, k)
			if not crop_open_day.has(k):
				crop_open_day[k] = GameState.day
			did.append("%s → %s" % [Config.FIELD_PLOT_NAMES[i], Crops.display_name(k)])


## 무가 들 곳: 터가 드러났는데 아직 공사를 안 시작한 시설의 무 (가장 큰 것) · 잔치 농부 상
func _radish_need() -> int:
	var need := 0
	for f: Array in [[GameState.forge_state, &"forge", Config.FORGE_COST_CROPS], [GameState.barn_state, &"barn", Config.BARN_COST_CROPS],
			[GameState.naru_state, &"naru", Config.NARU_COST_CROPS], [GameState.hall_state, &"hall", Config.HALL_COST_CROPS]]:
		if f[0] == 1 and not SiteWork.building(f[1]):
			need = maxi(need, f[2])
	if GameState.hall_state >= 2 and not GameState.feast_dishes.has(&"greens"):
		need = maxi(need, 20)
	return need


## 퇴비 · 사냥 음식 (2026-10-03 작물 등급): 손으로 캔 들나물 · 채집 크리처가 진열해 둔 들나물, 잡템이 넉넉하면 (30 넘게) 잡템으로 퇴비를 만들고,
## 사냥 음식은 종류마다 하나씩 들고 있게 만든다 (고추는 매운탕 몫을 먼저 남김).
func cook_day(did: Array[String]) -> void:
	var made: Array[String] = []
	while GameState.compost < 30 and (GameState.herbs >= Config.COMPOST_COST or GameState.displayed_herbs >= Config.COMPOST_COST or GameState.junk > 30 + Config.COMPOST_COST):
		var key := "herbs" if GameState.herbs >= Config.COMPOST_COST else ("displayed_herbs" if GameState.displayed_herbs >= Config.COMPOST_COST else "junk")
		Crops.make_compost()
		compost_made[key] = int(compost_made.get(key, 0)) + 1
	for id in Config.FOOD_ORDER:
		if Crops.food_count(id) > 0 or not Crops.can_cook(id):
			continue
		var cost: Dictionary = Config.FOODS[id].cost
		if cost.has(&"pepper") and GameState.naru_state >= 2 and GameState.peppers - int(cost.pepper) < 2 * Config.STEW_PEPPERS:
			continue
		var g := Crops.cook(id)
		var c: Array = cooked.get(id, [0, 0, 0])
		c[g - 1] += 1
		cooked[id] = c
		made.append("%s ★%d" % [Config.FOODS[id].name, g])
	if not made.is_empty():
		did.append("음식 %s" % ", ".join(made))


## 손으로 퇴비 주기: 음식 작물 (감자 · 고추 · 배추) 칸만 (무는 ★3 웃돈이 퇴비 재료값보다 작다). 씨앗 주머니 한 번에 sow_reach 칸.
func fertilize_by_hand() -> int:
	if GameState.compost <= 0:
		return 0
	var cells: Array[Vector2i] = []
	for c: Vector2i in farm._cells:
		var cell: Farm.Cell = farm._cells[c]
		if cell.planted and not cell.fert and not cell.is_ripe() and cell.kind != &"radish":
			cells.append(c)
	cells.sort()
	var n := 0
	for c in cells:
		if farm.fertilize(c):
			n += 1
	compost_used += n
	return ceili(float(n) / Wearables.sow_reach(&"farmer"))


## 마을회관 · 잔치 (2026-10-03): 용 비늘이 다 모이면 고치고, 게시판 부탁은 가진 것으로 되면 들어주고,
## 잔치상은 차릴 수 있는 상부터 그 사람으로 바꿔 차린다. 아직 못 차린 상에 들 재료는 따로 빼 두어 (feast_hidden)
## 팔거나 다른 데 쓰지 않는다 (사람이라면 잔치 재료를 모을 것). 다 차면 바로 잔치를 연다 (장면은 건너뜀).
func hall_day(did: Array[String]) -> void:
	_feast_unhide()
	if GameState.hall_state >= 2 and not GameState.hall_request.is_empty():
		var id: StringName = GameState.hall_request.id
		if int(GameState.get(String(id))) - VillageHall.still_needed() >= _feast_need(String(id)) and VillageHall.turn_in(main):
			did.append("부탁 (%s)" % Config.HALL_REQUESTS[id][0])
	if GameState.feast_state == 1:
		for d: Array in Config.FEAST_DISHES:
			if d[0] in GameState.feast_dishes or not VillageHall.person_open(d[1]):
				continue
			if VillageHall.set_dish(main, d[0]):
				did.append("잔치상 %s" % d[2])
		if VillageHall.feast_full():
			main.feast_instant = true
			if main.start_feast():
				feast_human_sec = total_human_sec
				did.append("잔치!")
	_feast_hide()
	if not feast_hidden.is_empty():
		did.append("잔치 재료 따로 둠 %s" % feast_hidden)


## 아직 못 차린 상에 드는 그 재료 수
func _feast_need(key: String) -> int:
	if GameState.feast_state != 1:
		return 0
	var n := 0
	for d: Array in Config.FEAST_DISHES:
		if not d[0] in GameState.feast_dishes and d[3].has(key) and key != "money":
			n += int(d[3][key])
	return n


func _feast_hide() -> void:
	for key: String in ["crops", "potatoes", "peppers", "cabbages", "herbs", "junk", "scrap", "roots", "hen_eggs", "fish"]:
		var k := mini(int(GameState.get(key)), _feast_need(key))
		if k > 0:
			feast_hidden[key] = k
			GameState.set(key, int(GameState.get(key)) - k)


func _feast_unhide() -> void:
	for key: String in feast_hidden:
		GameState.set(key, int(GameState.get(key)) + int(feast_hidden[key]))
	feast_hidden.clear()


## 나루터: 바구니 물고기를 꺼내 매운탕이 없으면 뱃사공이 하나 끓이고 나머지는 진열, 통발은 날마다 다시 놓는다.
func dock_day(did: Array[String]) -> void:
	var made: Array[String] = []
	if GameState.basket > 0:
		fish_caught += GameState.basket
		made.append("물고기 %d" % GameState.basket)
		main.dock_action(&"take_fish")
	# 잔치상 매운탕 큰 솥에 들 물고기는 끓이거나 팔지 않고 남긴다 (사람이라면 그럴 것)
	var keep_fish := mini(GameState.fish, _feast_need("fish"))
	GameState.fish -= keep_fish
	if GameState.stews == 0 and GameState.fish >= Config.STEW_FISH:
		if main.dock_action(&"stew"):
			stews_made += 1
			made.append("매운탕")
	if GameState.fish > 0:
		fish_sold += GameState.fish
		made.append("물고기 %d 진열" % GameState.fish)
		main.supply_action(&"display_fish")
	GameState.fish += keep_fish
	if GameState.traps < Config.TRAP_MAX and main.dock_action(&"set_traps"):
		made.append("통발 %d" % GameState.traps)
	if not made.is_empty():
		did.append("나루터: " + " · ".join(made))


## 닭장: 모이를 맡은 크리처가 없으면 무로 모이를 주고, 닭이 다 찼으면 둥지 달걀을 꺼내
## 목축인이 도시락 하나를 싸 두고 나머지는 공급함에 진열한다. 덜 찼으면 병아리가 되게 둥지에 둔다.
func coop_day(did: Array[String]) -> void:
	var made: Array[String] = []
	if GameState.fed < GameState.hens and FacilityWorkers.workers(main, &"barn").is_empty() and main.coop_action(&"feed"):
		made.append("모이")
	# 암탉이 넷이 될 때까지는 둥지 달걀을 병아리로 두고, 그 뒤로 꺼낸다 (사람이라면 먼저 닭을 늘릴 것)
	if GameState.nest > 0 and GameState.hens + GameState.chicks.size() >= Config.HEN_CAP / 2:
		made.append("달걀 %d" % GameState.nest)
		main.coop_action(&"take_nest")
	if GameState.lunches == 0 and GameState.hen_eggs >= Config.LUNCH_EGGS:
		if main.coop_action(&"lunch"):
			made.append("도시락")
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
	if GameState.crops >= 50 and GameState.tonic_day != GameState.day and main.brew(&"tonic"):
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
	# 사냥꾼 가방의 사냥터 일반 장비는 대장장이에게 갈아 고철로 (2026-10-03 백로그 8, 팔면 5원 · 갈면 고철 1)
	var hb: Array[StringName] = GameState.bag[&"hunter"]
	for j in range(hb.size() - 1, -1, -1):
		if Wearables.is_rolled(hb[j]) and Wearables.rarity(hb[j]) == &"normal":
			salvaged_scrap += Wearables.salvage(&"hunter", j)
	while true:
		var base: StringName = bases[crafted % bases.size()]
		var cost: Array = Config.CRAFT_COSTS[base]
		if GameState.scrap < cost[0] or GameState.money < cost[1]:
			break
		# 마을회관 복구비를 모으는 중이면 그만큼은 남긴다
		if GameState.hall_state == 1 and not SiteWork.building(&"hall") and GameState.material5 >= Config.HALL_COST_MATERIAL and GameState.money - cost[1] < Config.HALL_COST_MONEY:
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
		# 가방의 제작품은 갈아서 고철로 (입지 않은 것. 즐겨 드는 종류 무기는 남김)
		for j in range(b.size() - 1, -1, -1):
			if Wearables.is_rolled(b[j]) and Wearables.rarity(b[j]) == &"crafted" and not _wanted_weapon(b[j]):
				salvaged_scrap += Wearables.salvage(who, j)
		main.player.refresh_wear()
		main.player.refresh_wear()
	if not made.is_empty():
		did.append("제작 %s" % ", ".join(made))


func _debug_msg(t: String) -> void:
	if "하트" in t or "쓰러" in t:
		_log("  . %s (사냥꾼 칸 %s)" % [t, Vector2i(main.player.feet() / Config.TILE)])


## 즐겨 드는 종류 무기인지
func _wanted_weapon(id: StringName) -> bool:
	var it := Wearables.item(id)
	return it.slot == &"weapon" and it.weapon.kind == weapon_pref


## 즐겨 드는 종류 무기 중 가장 좋은 것을 든다 (가방 · 창고에서). knife 면 무기를 내려놓는다.
## 다른 종류 무기는 들지 않는다 (주울 때 빈 칸이라 바로 들었으면 내려놓음).
## 사냥꾼 스킬 (2026-10-02 B): 봇은 든 무기 트리를 먼저, 그다음 조련을 찍는다 (SKILLS=0 이면 안 찍음)
const SKILL_ORDER := {
	&"melee": [&"whirl", &"dash_slash", &"fight_together", &"sword_mastery", &"creature_guard", &"earth_split", &"two_together", &"charge_order"],
	&"bow": [&"pierce", &"spread", &"volley", &"fight_together", &"creature_guard", &"arrow_rain", &"two_together", &"charge_order"],
	&"staff": [&"big_orb", &"chain_orb", &"element_boost", &"fight_together", &"creature_guard", &"element_storm", &"two_together", &"charge_order"],
}
var skills_on := true
var level_by_day := {}


func spend_skill_points() -> void:
	if not skills_on:
		return
	var kind: StringName = Wearables.weapon().kind
	var order: Array = SKILL_ORDER[kind]
	var learned := true
	while GameState.skill_points > 0 and learned:
		learned = false
		# 앞 스킬일수록 먼저, 다 찍었거나 못 찍으면 다음
		for id: StringName in order:
			if HunterSkills.learn(id):
				learned = true
				break
	# 왼클릭은 찍은 방식 중 가장 뒤 것 (활은 3연사 > 부채살 > 관통)
	var modes := HunterSkills.modes_for(kind)
	GameState.skill_left[kind] = modes[-1]


## 직업 (2026-10-03 B): 봇이 즐겨 드는 무기의 직업. 스탯은 "보통 빌드" (주 스탯 2 : 교감 1, 몬스터 체력이 이 빌드에 맞춰 오름)
const CLASS_FOR := {&"melee": &"warrior", &"bow": &"archer", &"staff": &"mage"}


func choose_class() -> void:
	if not HunterClass.chosen():
		HunterClass.choose(CLASS_FOR.get(weapon_pref, &"warrior"), main._rng)


func spend_stat_points() -> void:
	if not skills_on:
		return
	var main_stat: StringName = HunterClass.CLASSES[GameState.hunter_class].stat if HunterClass.chosen() else &"str"
	while GameState.stat_points > 0:
		HunterClass.spend(main_stat if HunterClass.stat(main_stat) < 2 * HunterClass.stat(&"bond") + 2 else &"bond")


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
		main.player.position = main.incubator.position + Vector2(10, 40)
		main.player.position = Farm.center_of(main.INCUBATOR_RECT.position + Vector2i(0, 2))
		main.interact()
		_log("부화기: %s" % GameState.message if false else "부화기에 알 넣음 (%d일)" % main.incubating_days)


# --- 사냥 봇 -----------------------------------------------------------

## 구역 대장을 처음 쓰러뜨린 날을 적는다
func _cleared(zone: int) -> void:
	if not cleared_day.has(Config.HUNT_ZONES[zone].name):
		cleared_day[Config.HUNT_ZONES[zone].name] = "%d일" % GameState.day


func hunt_day() -> void:
	var pick: Creature = null
	var pool: Array[Creature] = main.companion_candidates()
	for s: Creature in pool:
		# 동행: 금두꺼비 > 땅 슬라임 > 아무나 (플레이어가 할 법한 선택)
		if pick == null or s.data.species.id == &"gold_toad" or (s.data.elements[0].id == &"earth" and pick.data.species.id != &"gold_toad"):
			pick = s
	# 5막 소내섬 (2026-10-03): 귀여리 대장을 잡고 나루터를 고쳤으면 사냥꾼이 나루터 나룻배로 섬에 간다 (main._ferry_interact 와 같은 조건)
	var fz := Config.ferry_zone()
	if fz >= 0 and not fz in GameState.waypoints and fz - 1 in GameState.bosses_beaten and GameState.naru_state >= 2:
		GameState.waypoints.append(fz)
	var zone: int = GameState.waypoints.max()
	# ZONE (2026-10-02 3~4막 난이도): 이 구역 웨이포인트에서만 사냥 (역동처럼 봇이 지나쳐 버리는 구역을 재려고)
	if OS.get_environment("ZONE") != "" and int(OS.get_environment("ZONE")) in GameState.waypoints:
		zone = int(OS.get_environment("ZONE"))
	# 2막 구역(웨이포인트)에서 쓰러졌으면 다음 날 하트를 채워 같은 웨이포인트에서 다시 (아래 구역부터 걸어오면 하트가 깎인 채 들어가 또 쓰러짐)
	if zone == knocked_zone and zone > 0 and zone < 2:
		# 어제 여기서 쓰러졌으면 한 구역 아래부터 (사람이라면 그럴 것)
		zone = GameState.waypoints.filter(func(z: int) -> bool: return z < knocked_zone).max()
	# 대장간을 아직 못 고쳤으면 사금 덩이(금사리 금두꺼비)를 모으러 금사리 웨이포인트부터 걸어간다 (광동리로 건너뛰지 않음)
	if GameState.forge_state < 2 and zone > Config.FORGE_ZONE and Config.FORGE_ZONE in GameState.waypoints:
		zone = Config.FORGE_ZONE
	# 나루터를 아직 못 고쳤으면 마왕 뿔 (곤지암 마왕) 을 모으러 곤지암으로 (2026-10-03: 귀여리가 마을 입구에 생긴 뒤로 봇이 곤지암을 다시 안 가서
	# 나루터 · 소내섬에 못 감. 사람이라면 뿔을 모으러 갈 것)
	if GameState.naru_state < 2 and zone > Config.NARU_ZONE and Config.NARU_ZONE in GameState.waypoints:
		zone = Config.NARU_ZONE
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
	choose_class()
	pick_weapon()
	spend_skill_points()
	spend_stat_points()
	if GameState.lunches > 0:
		lunches_eaten += 1
	if GameState.stews > 0:
		stews_eaten += 1
	main.enter_hunt(pick, zone)
	var h: HuntGround = main.hunt
	if OS.get_environment("DEBUG_KO") != "" and not GameState.message.is_connected(_debug_msg):
		GameState.message.connect(_debug_msg)
	h.set_process(false)
	var t := 0.0
	var kills := 0
	var zones_seen: Array[String] = [Config.HUNT_ZONES[h.zone].name]
	var hurt := 0
	var last_life := h.life
	var stuck_t := 0.0
	var ignored := {}
	var stuck_s: WildSlime = null
	var stuck_hp := 0
	var boss_names: Array[String] = []
	var stuck_s_t := 0.0
	var money0 := GameState.money
	var potions0 := GameState.potions
	var junk0 := GameState.junk
	var gear0 := GameState.gear.size() + GameState.owned_wear.size()
	var zone_times: Array[String] = []
	var zone_t := 0.0
	var seen := {}
	var dodges := 0
	## 몬스터가 남아 있는 동안 흐른 시간 (2026-10-02 활 몰아잡기: 걷기 · 줍기 빼고 싸움 빠르기만 보려고)
	var fight_t := 0.0
	var gwang_hurt0 := -1
	var doma_hurt0 := -1
	var bun_hurt0 := -1
	var mil_hurt0 := -1
	var yd_hurt0 := -1
	var gj_hurt0 := -1
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
		if h.zone == YEOKDONG and yd_hurt0 < 0:
			yd_hurt0 = hurt
			yd_hunts += 1
			if yd_day < 0:
				yd_day = GameState.day
		var b0 := h._boss()
		if b0 and not b0.title in boss_names:
			boss_names.append(b0.title)
		if h.zone == GONJIAM and gj_hurt0 < 0:
			gj_hurt0 = hurt
			gj_hunts += 1
			if gj_day < 0:
				gj_day = GameState.day
		if h.zone == DOMA and doma_hurt0 < 0:
			doma_hurt0 = hurt
			doma_hunts += 1
			if doma_day < 0:
				doma_day = GameState.day
		if h.knocked:
			if OS.get_environment("DEBUG_KO") != "":
				for s: WildSlime in h.slimes:
					_log("  ! 쓰러질 때 남은 %s%s 체력 %d · 거리 %.0f" % [s.title, " (대장)" if s.boss else "", s.hp, s.position.distance_to(main.player.feet())])
			break
		if t + 2 * DT >= 900.0 and t < 900.0 - DT:
			for d in h.drops + h.loot:
				_log("  ! 줍지 못한 것 칸 %s" % Vector2i(d.at / Config.TILE))
			for s: WildSlime in h.slimes:
				var c := Vector2i(s.position / Config.TILE)
				_log("  ! 남은 %s%s 칸 %s '%s' · 사냥꾼 칸 %s" % [s.title, " (대장)" if s.boss else "", c, h.map.at(c) if h.map else "", Vector2i(main.player.feet() / Config.TILE)])
			# 2026-10-03 소내섬: 드물게 막히는 원인을 찾으려고 사냥꾼 상태도 남긴다
			_log("  ! 사냥꾼 발 %s · 느려짐 %.2f · 구르기 %.2f · 막힌 시간 %.1f · 무시한 몬스터 %d · 정전 %.1f" % [main.player.feet(), main.player.slow_mult, h.dash_t, stuck_t, ignored.size(), h.blackout_t])
		var hunter: Character = main.player
		var feet := hunter.feet()
		# 물약: 하트 2 이하면 마신다
		if h.life * 4 <= h.max_life() and GameState.potions > 0:
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
		# 막힌 몬스터 (2026-10-02): 20초 넘게 같은 몬스터 체력이 그대로면 (화살이 안 닿는 자리 등) 이번 사냥에선 건너뛴다
		if nearest_s != null and ignored.has(nearest_s):
			nearest_s = null
			var best_d := INF
			for o: WildSlime in h.slimes:
				if not ignored.has(o) and o.position.distance_to(feet) < best_d:
					best_d = o.position.distance_to(feet)
					nearest_s = o
		if nearest_s != null:
			fight_t += DT
			if nearest_s != stuck_s or nearest_s.hp != stuck_hp:
				stuck_s = nearest_s
				stuck_hp = nearest_s.hp
				stuck_s_t = 0.0
			else:
				stuck_s_t += DT
				if stuck_s_t > 20.0:
					ignored[nearest_s] = true
					stuck_s_t = 0.0
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
			# 구르기 (2026-10-02 손맛): 쓸 수 있으면 비킬 쪽으로 구른다 (사람도 그럴 것)
			if h.dash(escape.normalized()):
				h.tick(DT)
				if h.life < last_life:
					hurt += last_life - h.life
				last_life = h.life
				t += DT
				zone_t += DT
				continue
			var mult: float = (h.map.speed_at(feet) if h.map else 1.0) * Wearables.speed_mult(&"hunter") * hunter.slow_mult
			var p0 := hunter.position
			hunter.step(escape.normalized() * Config.CHARACTER_SPEED * mult * DT)
			if hunter.position.distance_to(p0) < 0.01:
				hunter.step(-escape.normalized().orthogonal() * Config.CHARACTER_SPEED * mult * DT)
			h.tick(DT)
			if h.life < last_life:
				hurt += last_life - h.life
			last_life = h.life
			t += DT
			zone_t += DT
			continue
		# 더 깊은 구역으로 넘어가기 전, 하트가 모자라면 물약을 마신다 (사람이라면 그럴 것)
		var need_life := h.max_life() * (0.5 if h.zone + 1 >= 2 else 0.3)
		if nearest_s == null and h.path_open and h.path_block() == "" and h.life < need_life and GameState.potions > 0:
			h.drink_potion()
		if not pickups.is_empty():
			pickups.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_to(feet) < b.distance_to(feet))
			target = pickups[0]
			goal = &"pick"
		elif nearest_s != null:
			target = nearest_s.position
			goal = &"fight"
		elif h.path_open and h.path_block() == "" and h.life >= h.max_life() * (0.5 if h.zone + 1 >= 2 else 0.3):
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
		if OS.get_environment("DEBUG_STUCK") != "" and fmod(t, 20.0) < DT:
			_log("  @ %.0f초 칸 %s goal %s target %s 대상 %s %s air %s" % [t, hunter.cell(), goal, Vector2i(target / Config.TILE), nearest_s.title if nearest_s else "-", Vector2i(nearest_s.position / Config.TILE) if nearest_s else Vector2i.ZERO, nearest_s.airborne() if nearest_s else false])
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
		# 귀여리 방패 도마뱀 (2026-10-03): 방패가 이쪽이면 옆 · 뒤로 돌아간다 (찌른 뒤 방패가 내려가면 그대로 침)
		var flank: bool = goal == &"fight" and nearest_s.blocks(feet)
		if flank:
			shoot = false
			away = false
			var side: Vector2 = nearest_s._face.orthogonal()
			if (feet - nearest_s.position).dot(side) < 0.0:
				side = -side
			target = nearest_s.position + side * 56.0 - nearest_s._face * 24.0
		# 오른클릭 큰 스킬: 쓸 수 있으면 가까운 몬스터에 (봇은 쿨마다 바로)
		var rs := HunterSkills.right_skill(w.kind)
		if skills_on and goal == &"fight" and rs != &"" and h.right_cd <= 0.0 and h.hittable(nearest_s) and not (nearest_s.buried and not nearest_s.disguise) \
				and nearest_s.position.distance_to(feet) <= (Config.EARTH_SPLIT_LENGTH if w.kind == &"melee" else w.range * 0.8):
			h.skill_right(nearest_s.position + Vector2(0, -6))
		if shoot:
			h.swing(nearest_s.position + Vector2(0, -8 * nearest_s.scale.y) - (feet + Vector2(0, -8)))
			shots_fired += 1
		elif goal == &"fight" and not ranged and not flank and nearest_s.position.distance_to(feet + Vector2(0, -8)) <= w.reach + w.radius - 2:
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
		if h.life < last_life:
			hurt += last_life - h.life
		last_life = h.life
		t += DT
		zone_t += DT
	zone_times.append("%s %.0f초" % [Config.HUNT_ZONES[h.zone].name, zone_t])
	hunt_sec = t + GATE_WALK_SEC
	var life_left := h.life
	var knocked := h.knocked
	hunt_days += 1
	hunt_hurt += hurt
	hunt_blocks += h.guard_blocks
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
		mil_hurt += (yd_hurt0 if yd_hurt0 >= 0 else hurt) - mil_hurt0
		mil_knocked += int(knocked and h.zone == MILMOK)
	if yd_hurt0 >= 0:
		yd_hurt += (gj_hurt0 if gj_hurt0 >= 0 else hurt) - yd_hurt0
		yd_knocked += int(knocked and h.zone == YEOKDONG)
	if gj_hurt0 >= 0:
		gj_hurt += hurt - gj_hurt0
		gj_knocked += int(knocked and h.zone == GONJIAM)
	if h.boss_spawned and h._boss() == null:
		_cleared(h.zone)
	if h.zone >= 8:
		var a: Dictionary = act5.get(h.zone, {day = GameState.day, hunts = 0, hurt = 0, knocked = 0, dragons = {}, blocked = 0})
		a.hunts += 1
		a.blocked += h.blocked_hits
		a.hurt += hurt
		a.knocked += int(knocked)
		for nm: String in boss_names:
			a.dragons[nm] = a.dragons.get(nm, 0) + 1
		act5[h.zone] = a
	var comp := h.companion.display_name() if h.companion else "혼자"
	var picked := h.picked.size()
	var eggs0 := GameState.farmer_eggs.size()
	if main.hunt:
		main.leave_hunt()
	var eggs: Array[String] = []
	for sp in GameState.farmer_eggs.slice(eggs0):
		eggs.append(sp.display_name)
		if sp == CreatureCatalog.TIGER or sp == CreatureCatalog.WHITE_TIGER:
			tigers_got[sp.display_name] = tigers_got.get(sp.display_name, 0) + 1
		if sp == CreatureCatalog.FOAL:
			foals_got += 1
		if sp == CreatureCatalog.IMP:
			imps_got += 1
	_log("사냥: 시작 %s · 동행 %s · %s · 싸움 %.0f초 · 처치 %d · 잃은 체력 %d · 방패 %d · 비킨 틱 %d · 남은 체력 %d/%d%s · 알 %s · 돈 %+d · 물약 %+d · 젤리 %+d · 장비 %+d · Lv %d" % [
		Config.HUNT_ZONES[zone].name, comp, " → ".join(zone_times), fight_t, kills, hurt, h.guard_blocks, dodges, life_left, h.max_life(), " (쓰러짐)" if knocked else "",
		eggs, GameState.money - money0, GameState.potions - potions0, GameState.junk - junk0, GameState.gear.size() + GameState.owned_wear.size() - gear0, GameState.hunter_level])
	level_by_day[GameState.day] = GameState.hunter_level
	if t >= 900.0:
		_log("  ! 사냥 봇이 15분 안에 끝내지 못함 (막힘?)")
	# 젤리 팔기 (주운 알은 주인공이 들고 와 바로 부화기에 넣는다)
	main.player.position = Farm.center_of(main.SUPPLY_RECT.position + Vector2i(1, 1))
	main._supply_interact()
	main.close_menu()
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
