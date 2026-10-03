class_name VillageHall
extends RefCounted
## 마을회관 · 이장 · 잔치상 (2026-10-03 시설 5, 사용자 선택 A 마을회관 · 이장 + 엔딩 B 잔치상 차리기).
## main.gd 가 너무 길어 시설 5 와 잔치는 여기 모았다. main 의 hall · feast_table · chief 를 다룬다. 값은 Config (HALL_* · FEAST_*).
##
## 흐름: 소내섬 용 첫 처치 (GameState.final_boss_down) → 다음 날 아침 마을회관 터 → 돈 · 무 · 용 비늘로 고침 → 이장 ·
## 게시판 부탁 · 확성기 방송 · 크리처 심부름 → 이장이 잔치를 알리고 당산나무 앞에 빈 잔치상 → 주인공이 재료를 가져오면 일곱 사람이 한 상씩 →
## 잔치 열기 (FeastScene: 잔치 장면 + 크레딧) → 다음 날 아침 평소대로.

const HALL_RUIN_TEX: Texture2D = preload("res://assets/props/hall_ruin.png")
const HALL_TEX: Texture2D = preload("res://assets/props/hall.png")
const TABLE_TEX: Texture2D = preload("res://assets/props/feast_table.png")
const DISHES_TEX: Texture2D = preload("res://assets/props/feast_dishes.png")
const LANTERN_TEX: Texture2D = preload("res://assets/props/lantern.png")
## 사람 id → 화면 이름 · 그 사람이 오는 시설
const PEOPLE := {
	&"farmer": ["농부", ""],
	&"hunter": ["사냥꾼", ""],
	&"smith": ["대장장이", "대장간"],
	&"alchemist": ["연금술사", "약방"],
	&"rancher": ["목축인", "축사"],
	&"ferryman": ["뱃사공", "나루터"],
	&"chief": ["이장", "마을회관"],
}
## 잔치상 재료 이름 (Config.FEAST_DISHES 의 GameState 변수 → 화면 이름)
const STUFF_NAMES := {crops = "무", potatoes = "감자", peppers = "고추", cabbages = "배추", herbs = "나물", junk = "잡템", scrap = "고철", roots = Config.ROOT_NAME, hen_eggs = "달걀", fish = "물고기", money = "원"}


# --- 마을회관 터 · 복구 ---------------------------------------------------------

## 아침에 회관 쪽에서 생긴 일 (아침 카드 한 줄, 없으면 ""). 마지막 대장을 처음 잡은 다음 날 터가 드러나고,
## 고친 뒤로는 아침마다 게시판 부탁이 새로 붙는다 (못 들어준 부탁은 떼어 냄).
static func morning(main: Node2D, rng: RandomNumberGenerator) -> String:
	if GameState.hall_state == 0 and GameState.final_boss_down:
		show_site(main)
		return "용이 물러간 뒤, 아랫길 아래 풀밭에 무너진 마을회관 터가 드러났다. 터에서 F. 귀여리 · 소내섬 몬스터도 용 비늘을 가끔 떨어뜨린다."
	if GameState.hall_state < 2:
		return ""
	GameState.errands = 0
	GameState.hall_rerolled = false
	new_request(rng)
	return "마을회관 확성기 아침 방송 (크리처 일 조금 빨라짐) · 게시판 부탁: %s" % request_text()


static func show_site(main: Node2D) -> void:
	GameState.hall_state = maxi(GameState.hall_state, 1)
	if main.hall == null:
		main.hall = main._add_prop("마을회관 터", HALL_RUIN_TEX, Config.HALL_RECT)
		main.hall.badge_side = true
		main.forage.block(Config.HALL_RECT)
		main.forage.block(Rect2i(Creature.errand_spot(), Vector2i.ONE))
	main._refresh_props()


## 고친 회관을 놓는다 (복구와 불러오기가 함께 쓴다): 회관 그림 · 이장
static func show_restored(main: Node2D) -> void:
	show_site(main)
	main.hall.label = "마을회관"
	main.hall.texture = HALL_TEX
	main.hall.queue_redraw()
	main.chief.visible = true
	main.chief.position = Farm.center_of(Config.CHIEF_CELL)
	main._refresh_props()


## 복구에 드는 것: [이름, 가진 것, 필요한 것]
static func costs() -> Array:
	return [
		["돈", GameState.money, Config.HALL_COST_MONEY],
		["무 (수확해서 들고 있는 것)", GameState.crops, Config.HALL_COST_CROPS],
		[Config.BOSS_MATERIAL5_NAME + " (%s 대장 · 몬스터)" % Config.HUNT_ZONES[Config.HALL_ZONE].name, GameState.material5, Config.HALL_COST_MATERIAL],
	]


static func can_restore() -> bool:
	return GameState.hall_state == 1 and not SiteWork.building(&"hall") and costs().all(func(c: Array) -> bool: return c[1] >= c[2])


static func cost_lines() -> Array[String]:
	return SiteWork.lines(&"hall", costs(), "이장 · 게시판 · 그리고 잔치")


## 한 번에 고친다 (선택창 · 테스트 · 봇이 함께 쓴다). 고치면 이장이 바로 잔치를 알린다.
static func restore(main: Node2D) -> bool:
	if GameState.hall_state != 1:
		return false
	# 공사 중 (2026-10-03): 공사가 다 됐으면 문을 연다 (아침에 저절로도 연다)
	if SiteWork.building(&"hall"):
		if not SiteWork.ready(&"hall"):
			GameState.notify("마을회관 공사 중이다. 크리처에게 R 로 터 공사를 맡기자 (남은 %d일)." % SiteWork.days_left(&"hall"))
			return false
		SiteWork.finish(&"hall")
	else:
		if not can_restore():
			var short: Array[String] = []
			for c: Array in costs():
				if c[1] < c[2]:
					short.append("%s %d" % [String(c[0]).split(" ")[0], c[2] - c[1]])
			GameState.notify("아직 모자라다: %s." % ", ".join(short))
			return false
		GameState.money -= Config.HALL_COST_MONEY
		GameState.crops -= Config.HALL_COST_CROPS
		GameState.material5 -= Config.HALL_COST_MATERIAL
		SiteWork.start(&"hall")
		GameState.notify(SiteWork.start_text(&"hall"))
		return false
	GameState.hall_state = 2
	show_restored(main)
	new_request(main._rng)
	if GameState.feast_state == 0:
		GameState.feast_state = 1
		show_feast(main)
	GameState.notify("마을회관을 고쳤다! 이장이 왔다. 확성기: \"용이 물러갔으니 잔치를 엽시다! 당산나무 앞 잔치상에 집집마다 한 상씩 차려 주시오.\"")
	return true


# --- 게시판 부탁 ---------------------------------------------------------------

## 지금 열린 시설로 낼 수 있는 부탁 id
static func request_pool() -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in Config.HALL_REQUESTS:
		var need: StringName = Config.HALL_REQUESTS[id][3]
		var open := need == &"" or (need == &"forge" and GameState.forge_state >= 2) or (need == &"yak" and GameState.yak_state >= 2) \
			or (need == &"barn" and GameState.barn_state >= 2) or (need == &"naru" and GameState.naru_state >= 2)
		if open:
			out.append(id)
	return out


static func new_request(rng: RandomNumberGenerator, avoid := &"") -> void:
	var pool := request_pool()
	if pool.size() > 1:
		pool.erase(avoid)
	var id: StringName = pool[rng.randi_range(0, pool.size() - 1)]
	GameState.hall_request = {id = id, count = Config.HALL_REQUESTS[id][1]}
	GameState.errands = mini(GameState.errands, Config.HALL_REQUESTS[id][1])


static func reward() -> int:
	if GameState.hall_request.is_empty():
		return 0
	var r: Array = Config.HALL_REQUESTS[GameState.hall_request.id]
	return roundi(r[1] * r[2] * Config.HALL_REWARD_MULT)


## 부탁을 들어주려면 더 내야 하는 수 (심부름 크리처가 모은 만큼 빠짐)
static func still_needed() -> int:
	if GameState.hall_request.is_empty():
		return 0
	return maxi(0, int(GameState.hall_request.count) - GameState.errands)


static func request_text() -> String:
	if GameState.hall_request.is_empty():
		return "없음 (오늘 부탁은 들어줬다)"
	var r: Array = Config.HALL_REQUESTS[GameState.hall_request.id]
	return "%s %d개 → %d원" % [r[0], r[1], reward()]


## 부탁을 들어준다: 가진 것에서 (심부름으로 모인 것을 뺀) 남은 수를 내고 보상을 받는다.
static func turn_in(main: Node2D) -> bool:
	if GameState.hall_state < 2 or GameState.hall_request.is_empty():
		return false
	var id: StringName = GameState.hall_request.id
	var name: String = Config.HALL_REQUESTS[id][0]
	var need := still_needed()
	var have: int = GameState.get(String(id))
	if have < need:
		GameState.notify("%s이(가) 모자라다 (%d / %d, 심부름으로 모인 것 %d)." % [name, have, need, GameState.errands])
		return false
	GameState.set(String(id), have - need)
	var pay := reward()
	GameState.money += pay
	GameState.requests_done += 1
	var gift := ""
	if main._rng.randf() < Config.HALL_GEAR_CHANCE and GameState.stash.size() < Config.STASH_SIZE:
		var roll := Wearables.roll_gear(main._rng, &"", Config.HUNT_ZONES[Config.HALL_ZONE].rarity)
		GameState.gear_serial += 1
		var gid := StringName("gear_%d" % GameState.gear_serial)
		GameState.gear[gid] = roll
		GameState.stash.append(gid)
		gift = " 고맙다며 장비 하나도 줬다 (공용 창고)."
	GameState.hall_request = {}
	GameState.notify("부탁을 들어줬다! %s %d개 → +%d원.%s" % [name, need, pay, gift])
	return true


## 이장에게 부탁해 하루 한 번 오늘 부탁을 다른 것으로 바꾼다
static func reroll(main: Node2D) -> bool:
	if GameState.hall_rerolled or GameState.hall_request.is_empty():
		return false
	new_request(main._rng, GameState.hall_request.id)
	GameState.hall_rerolled = true
	GameState.notify("이장이 게시판 부탁을 바꿔 붙였다: %s" % request_text())
	return true


# --- 회관 선택창 ---------------------------------------------------------------

static func options(main: Node2D, kind: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	if kind == &"hall":
		out.append(&"restore")
	elif kind == &"board":
		if not GameState.hall_request.is_empty():
			out.append(&"turn_in")
			if not GameState.hall_rerolled:
				out.append(&"reroll")
	elif kind == &"feast":
		for d: Array in Config.FEAST_DISHES:
			out.append(d[0])
		if feast_full():
			out.append(&"open_feast")
	out.append(&"close")
	return out


static func option_text(main: Node2D, id: StringName) -> String:
	match id:
		&"restore":
			return SiteWork.option_text(&"hall", can_restore())
		&"turn_in":
			return "부탁 들어주기 (%s, 더 낼 것 %d)" % [request_text(), still_needed()]
		&"reroll":
			return "이장에게 부탁 바꿔 달라기 (하루 한 번)"
		&"open_feast":
			return "잔치 열기!"
		&"close":
			return "닫기"
	var i := dish_index(id)
	if i < 0:
		return "닫기"
	var d: Array = Config.FEAST_DISHES[i]
	if id in GameState.feast_dishes:
		return "%s · %s ✔ 차림" % [PEOPLE[d[1]][0], d[2]]
	if not person_open(d[1]):
		return "%s · %s (%s을(를) 고치면 옴)" % [PEOPLE[d[1]][0], d[2], PEOPLE[d[1]][1]]
	return "%s · %s (%s)" % [PEOPLE[d[1]][0], d[2], stuff_text(d[3])]


static func head(kind: StringName) -> String:
	match kind:
		&"hall":
			return "무너진 마을회관 터"
		&"board":
			return "마을회관 게시판   들어준 부탁 %d" % GameState.requests_done
	return "당산나무 앞 잔치상   %d / %d 상" % [GameState.feast_dishes.size(), Config.FEAST_DISHES.size()]


static func lines(kind: StringName) -> Array[String]:
	var out: Array[String] = []
	match kind:
		&"hall":
			out.append_array(cost_lines())
		&"board":
			out.append("오늘 부탁: %s" % request_text())
			out.append("심부름 크리처가 모은 것 %d (하루 %d번까지) · 아침마다 새 부탁" % [GameState.errands, Config.ERRAND_CAP])
			out.append("들어주면 이따금 장비도 준다 (공용 창고)")
		&"feast":
			out.append("상마다 그 사람 몫 재료를 가져오면 그 사람이 차린다")
			out.append("일곱 상이 다 차면 잔치를 연다 · 잔치 뒤에도 계속 놀 수 있다")
	return out


## 선택창에서 하나 골랐을 때 (선택창 · 테스트 · 봇이 함께 쓴다). 창을 닫아야 하면 true.
static func act(main: Node2D, kind: StringName, id: StringName) -> bool:
	match id:
		&"close":
			return true
		&"restore":
			return restore(main)
		&"turn_in":
			turn_in(main)
			return false
		&"reroll":
			reroll(main)
			return false
		&"open_feast":
			return main.start_feast()
	if kind == &"feast":
		set_dish(main, id)
	return false


# --- 잔치상 --------------------------------------------------------------------

static func dish_index(id: StringName) -> int:
	for i in Config.FEAST_DISHES.size():
		if Config.FEAST_DISHES[i][0] == id:
			return i
	return -1


static func person_open(who: StringName) -> bool:
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
	return true


static func stuff_text(stuff: Dictionary) -> String:
	var parts: Array[String] = []
	for k: String in stuff:
		parts.append(("%d%s" if k == "money" else "%s %d") % ([stuff[k], STUFF_NAMES[k]] if k == "money" else [STUFF_NAMES[k], stuff[k]]))
	return " · ".join(parts)


static func feast_full() -> bool:
	return GameState.feast_dishes.size() >= Config.FEAST_DISHES.size()


## 한 상 차린다. 그 상을 맡은 사람이 마을에 있어야 하고, 주인공이 재료를 가져와야 한다.
static func set_dish(main: Node2D, id: StringName) -> bool:
	var i := dish_index(id)
	if i < 0 or GameState.feast_state != 1 or id in GameState.feast_dishes:
		return false
	var d: Array = Config.FEAST_DISHES[i]
	if not person_open(d[1]):
		GameState.notify("%s이(가) 아직 마을에 없다. %s을(를) 고치면 온다." % [PEOPLE[d[1]][0], PEOPLE[d[1]][1]])
		return false
	var stuff: Dictionary = d[3]
	for k: String in stuff:
		if int(GameState.get(k)) < int(stuff[k]):
			GameState.notify("모자라다. %s: %s (가진 %s %d)." % [d[2], stuff_text(stuff), STUFF_NAMES[k], GameState.get(k)])
			return false
	for k: String in stuff:
		GameState.set(k, int(GameState.get(k)) - int(stuff[k]))
	GameState.feast_dishes.append(id)
	main._feast_node.queue_redraw()
	if feast_full():
		GameState.notify("%s이(가) %s을(를) 올렸다. 잔치상이 다 찼다! 잔치상에서 F → 잔치 열기." % [PEOPLE[d[1]][0], d[2]])
	else:
		GameState.notify("%s이(가) %s을(를) 올렸다 (%d / %d 상)." % [PEOPLE[d[1]][0], d[2], GameState.feast_dishes.size(), Config.FEAST_DISHES.size()])
	return true


## 당산나무 앞 잔치상을 놓는다 (복구 · 불러오기가 함께 쓴다). 음식 · 잔치 뒤 청사초롱은 main._feast_node 가 그린다.
static func show_feast(main: Node2D) -> void:
	if main.feast_table == null:
		main.feast_table = main._add_prop("잔치상", TABLE_TEX, Config.FEAST_RECT)
		main.forage.block(Config.FEAST_RECT)
	main._feast_node.z_index = int(main.feast_table.position.y) + 1
	main._feast_node.queue_redraw()
	main._refresh_props()


## 잔치상 위 음식 (차린 상만) · 잔치를 연 뒤 당산나무에서 늘어뜨린 청사초롱 줄
static func draw_feast(main: Node2D, n: Node2D) -> void:
	if main.feast_table == null or GameState.feast_state == 0:
		return
	var base: Vector2 = main.feast_table.position + Vector2(-56, -26)
	for i in Config.FEAST_DISHES.size():
		if not Config.FEAST_DISHES[i][0] in GameState.feast_dishes:
			continue
		var at := base + Vector2(i * 16, -2 if i % 2 else 2)
		n.draw_texture_rect_region(DISHES_TEX, Rect2(at, Vector2(16, 16)), Rect2(i * 16, 0, 16, 16))
	if GameState.feast_state >= 2:
		var a: Vector2 = Vector2(Config.FEAST_RECT.position * Config.TILE) + Vector2(-10, -40)
		var b: Vector2 = Farm.center_of(Config.DANGSAN_RECT.position) + Vector2(4, -30)
		n.draw_line(a, b, Color(0.3, 0.2, 0.15), 1.0)
		for k in 6:
			var p := a.lerp(b, (k + 0.5) / 6.0) + Vector2(0, 4 * sin(PI * (k + 0.5) / 6.0))
			n.draw_texture(LANTERN_TEX, p - Vector2(4, 0))


static func badge_text(kind: StringName) -> String:
	if kind == &"hall":
		if GameState.hall_state == 1:
			return SiteWork.badge(&"hall")
		return "부탁 %s" % (Config.HALL_REQUESTS[GameState.hall_request.id][0] if not GameState.hall_request.is_empty() else "끝")
	if GameState.feast_state >= 2:
		return ""
	return "%d / %d 상" % [GameState.feast_dishes.size(), Config.FEAST_DISHES.size()]
