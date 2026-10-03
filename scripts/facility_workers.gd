class_name FacilityWorkers
extends RefCounted
## 크리처 시설 배치 (2026-10-03 "조작 캐릭터는 주인공 하나 · 시설 일은 크리처를 배치해서 돌린다").
## 시설마다 앞에 일꾼 자리 (Config.WORKER_SLOTS, 멍석) 가 있다. 크리처를 들고 (F) 그 근처에서 내려놓으면 빈 자리에 앉아
## 그 시설 일꾼이 된다. 일꾼은 시설 일 (CreatureJobs.SCRAP 등) 을 맡고, 아침에는 시설마다 정해진 일을 저절로 해 둔다:
##  - 대장간: 고물 캐기 (한 마리가 하루 몇 개, Creature.dig_cap)
##  - 약방: 도라지밭 + 달이기 (연금술사 창에서 정한 약을 일꾼 한 마리가 아침마다 한 번, 재료가 있으면)
##  - 축사: 모이 주기 + 달걀 거두기 (아침에 둥지 달걀을 꺼내 둠, 닭장에 자리가 있으면 병아리용 하나는 남김)
##  - 나루터: 물고기 몰기 + 통발 다시 놓기 (아침에 걷힌 통발을 무 미끼로 다시)
##  - 마을회관: 심부름
## 일꾼을 시설 밖에 내려놓으면 시설 일을 그만두고 쉰다. R 은 밭 일 (쉬기 · 농사 · 채집 · 터 공사) 만 고른다.

const FACILITIES: Array[StringName] = [&"forge", &"yak", &"barn", &"naru", &"hall"]
const JOBS := {
	&"forge": CreatureJobs.SCRAP,
	&"yak": CreatureJobs.HERB,
	&"barn": CreatureJobs.FEED,
	&"naru": CreatureJobs.FISH,
	&"hall": CreatureJobs.ERRAND,
}
const NAMES := {&"forge": "대장간", &"yak": "약방", &"barn": "축사", &"naru": "나루터", &"hall": "마을회관"}
## 내려놓으면 그 시설 자리로 가는 거리 (칸, 가장 가까운 일꾼 자리에서)
const DROP_REACH := 2


static func is_open(fac: StringName) -> bool:
	match fac:
		&"forge":
			return GameState.forge_state >= 2
		&"yak":
			return GameState.yak_state >= 2
		&"barn":
			return GameState.barn_state >= 2
		&"naru":
			return GameState.naru_state >= 2
		&"hall":
			return GameState.hall_state >= 2
	return false


static func slots(fac: StringName) -> Array:
	return Config.WORKER_SLOTS[fac]


static func is_facility_job(job: StringName) -> bool:
	return job in JOBS.values()


## 일꾼 자리 칸 → 시설 (&"" = 일꾼 자리가 아님)
static func facility_at(cell: Vector2i) -> StringName:
	for fac: StringName in FACILITIES:
		if cell in slots(fac):
			return fac
	return &""


## 이 크리처가 일꾼이면 그 시설 (자리에 앉아 시설 일을 맡음), 아니면 &""
static func facility_of(c: Creature) -> StringName:
	var fac := facility_at(c.home)
	if fac != &"" and c.job == JOBS[fac] and c.carried_by == null:
		return fac
	return &""


## 시설 일꾼 (원정 · 들림 제외)
static func workers(main: Node, fac: StringName) -> Array[Creature]:
	var out: Array[Creature] = []
	for c: Creature in main.creatures:
		if c.expedition_zone < 0 and facility_of(c) == fac:
			out.append(c)
	return out


## 빈 일꾼 자리 (없으면 (-1, -1)). near 에서 가까운 자리부터.
static func free_slot(main: Node, fac: StringName, near := Vector2i(-1, -1)) -> Vector2i:
	var taken: Array[Vector2i] = []
	for c: Creature in main.creatures:
		if c.carried_by == null and c.expedition_zone < 0:
			taken.append(c.home)
	var best := Vector2i(-1, -1)
	for cell: Vector2i in slots(fac):
		if cell in taken:
			continue
		if best.x < 0 or (near.x >= 0 and Vector2(cell - near).length() < Vector2(best - near).length()):
			best = cell
	return best


## 이 칸에서 내려놓으면 들어갈 시설 (고친 시설의 일꾼 자리가 DROP_REACH 칸 안에 있으면). 없으면 &"".
static func drop_target(cell: Vector2i) -> StringName:
	var best := &""
	var best_d := 999
	for fac: StringName in FACILITIES:
		if not is_open(fac):
			continue
		for s: Vector2i in slots(fac):
			var d := maxi(absi(s.x - cell.x), absi(s.y - cell.y))
			if d <= DROP_REACH and d < best_d:
				best = fac
				best_d = d
	return best


## 크리처를 시설 일꾼 자리에 앉힌다 (내려놓기 · 봇 · 테스트 · 불러오기가 함께 쓴다). 자리가 없으면 false.
static func assign(main: Node, c: Creature, fac: StringName, near := Vector2i(-1, -1)) -> bool:
	if not is_open(fac):
		return false
	var cell := free_slot(main, fac, near)
	if cell.x < 0:
		return false
	c.place(cell)
	c.job = JOBS[fac]
	c._reset_timer()
	return true


## 시설 창 · 배지에 붙는 한 줄
static func count_text(main: Node, fac: StringName) -> String:
	return "일꾼 %d/%d" % [workers(main, fac).size(), slots(fac).size()]


## 아침에 일꾼이 해 둔 일 (next_day 끝, 시설 아침 일 다음). 아침 카드 줄들.
static func morning(main: Node) -> Array[String]:
	var lines: Array[String] = []
	# 약방 달이기: 정해 둔 약을 일꾼 한 마리가 한 번씩 (재료가 모자라면 멈춤)
	var brewers := workers(main, &"yak").size()
	if brewers > 0 and GameState.yak_brew != &"" and Config.BREWS.has(GameState.yak_brew):
		var made := 0
		for i in brewers:
			if not main.brew(GameState.yak_brew, true):
				break
			made += 1
		var b: Dictionary = Config.BREWS[GameState.yak_brew]
		if made > 0:
			lines.append("약방 일꾼이 %s을(를) %d번 달여 뒀다." % [b.name, made])
		else:
			lines.append("약방 일꾼이 %s을(를) 달이려 했지만 재료가 모자랐다." % b.name)
	# 축사 달걀 거두기
	if not workers(main, &"barn").is_empty() and GameState.nest > 0:
		var keep := 1 if GameState.hens + GameState.chicks.size() < Config.HEN_CAP else 0
		var take := GameState.nest - keep
		if take > 0:
			GameState.nest -= take
			GameState.hen_eggs += take
			lines.append("축사 일꾼이 둥지 달걀 %d개를 꺼내 뒀다%s." % [take, " (병아리용 하나는 남김)" if keep > 0 else ""])
	# 나루터 통발 다시 놓기
	if not workers(main, &"naru").is_empty() and GameState.traps < Config.TRAP_MAX:
		var n := mini(Config.TRAP_MAX - GameState.traps, GameState.crops / Config.TRAP_BAIT)
		if n > 0:
			GameState.crops -= n * Config.TRAP_BAIT
			GameState.traps += n
			lines.append("나루터 일꾼이 무 미끼로 통발 %d개를 다시 놓았다." % n)
	return lines


## 불러온 뒤: 시설 일을 맡았는데 일꾼 자리에 없는 크리처 (옛 저장) 는 빈 자리로, 자리가 없으면 쉰다.
static func fix_after_load(main: Node) -> void:
	for c: Creature in main.creatures:
		if not is_facility_job(c.job) or c.expedition_zone >= 0:
			continue
		var fac: StringName = JOBS.find_key(c.job)
		if facility_at(c.home) == fac:
			continue
		if not assign(main, c, fac):
			c.job = CreatureJobs.REST


## 일꾼 자리 멍석을 그린다 (고친 시설만). 크리처를 들고 있으면 빈 자리를 밝게.
static func draw_mats(node: Node2D, main: Node) -> void:
	var carrying: bool = main._carried_creature() != null
	var taken := {}
	for c: Creature in main.creatures:
		if c.carried_by == null and c.expedition_zone < 0:
			taken[c.home] = true
	for fac: StringName in FACILITIES:
		if not is_open(fac):
			continue
		for cell: Vector2i in slots(fac):
			var r := Rect2(Farm.center_of(cell) + Vector2(-9, 1), Vector2(18, 9))
			node.draw_rect(r, Color(0.78, 0.66, 0.42, 0.85))
			for k in 4:
				node.draw_line(r.position + Vector2(2 + k * 4.5, 1), r.position + Vector2(2 + k * 4.5, 8), Color(0.62, 0.5, 0.3, 0.9), 1.0)
			node.draw_rect(r, Color(0.5, 0.38, 0.22, 0.9), false, 1.0)
			if carrying and not taken.has(cell):
				node.draw_rect(r.grow(2), Color(1.0, 0.95, 0.55, 0.9), false, 1.5)
