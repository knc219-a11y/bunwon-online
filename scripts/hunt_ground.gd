class_name HuntGround
extends Node2D
## 사냥터 한 화면 (2026-09-27 결정 A. 실시간 한 화면, 첫 조각).
## 숲 공터에 야생 슬라임이 돌아다닌다. 사냥꾼은 걸어 다니며 휘둘러 쓰러뜨린다.
## 알은 게임 전체 첫 처치만 반드시 떨어지고, 그 뒤로는 구역 확률 (2026-09-29 사용자 요청으로 낮춤). 하트가 0이 되면 쓰러져 마을로 돌아가고, 주운 것은 그대로 가진다.
## 그림은 마을 그림을 다시 쓴 임시 배치 (사냥터 전용 그림은 다음 단계).
## 스테이지 (2026-09-28 사용자 선택 B + 웨이포인트): 구역(Config.HUNT_ZONES)을 앞으로 걸어간다.
## 대장을 쓰러뜨리면 위쪽 길이 열리고, 그 길에서 F로 같은 날 다음 구역으로 이어서 간다 (하트는 그대로).
## 웨이포인트가 있는 구역에 처음 도착하면 웨이포인트가 켜지고, 다음 날부터 사냥터 입구에서 거기서 시작할 수 있다.
## 넓은 맵 (2026-09-28 사용자 선택 C): 구역 데이터에 map 이 있으면 칸 지도(HuntMap)로 화면보다 넓은 사냥터를 만들고
## 카메라가 사냥꾼을 따라간다. 입구·위쪽 길·웨이포인트·표지·대장·몬스터 자리는 지도의 표식에서 온다.
## map 이 없는 구역은 예전 한 화면 공터 그대로 (분원농협도 2026-09-28 사용자 선택 C. 창고 마당으로 넓은 맵이 됨).
## 작은 지도 (2026-09-28 추천 M2, 사용자가 따로 말하지 않아 그대로 감): 넓은 맵이면 오른쪽 위 구석에 작은 지도를 띄우고,
## 이번 사냥에서 가 본 곳 둘레만 드러난다. 게임 화면은 가리지 않는다. 구역을 옮기거나 다음 사냥이면 다시 가려진다.

signal knocked_out

## false 면 드롭표를 굴리지 않는다 (알은 그대로 굴림). 드롭과 상관없는 테스트에서 끈다.
static var loot_enabled := true
## 0 이상이면 알 확률 굴림 대신 이 값을 쓴다 (0 = 늘 나옴, 1 = 안 나옴). 테스트에서 쓴다.
static var egg_roll := -1.0

const T := Config.TILE
## 사냥꾼이 걸을 수 있는 공터 (캐릭터 위치 기준, px)
const WALK_AREA := Rect2(3 * T, 3 * T, 20 * T, 9 * T + 12)
## 흙 공터 (칸)
const CLEARING := Rect2i(4, 4, 18, 8)
## 아래쪽 마을로 돌아가는 입구 (그림 아래쪽 가운데, px)와 F가 닿는 범위
const EXIT_AT := Vector2(13 * T, 15 * T)
const EXIT_AREA := Rect2(10 * T, 11 * T, 6 * T, 3 * T)
const SPAWN_AT := Vector2(13 * T, 11 * T)
const SLIME_CELLS: Array[Vector2i] = [Vector2i(7, 6), Vector2i(13, 5), Vector2i(19, 7), Vector2i(10, 9)]
## 대장을 쓰러뜨리면 열리는 위쪽 길 (다음 구역으로). F가 닿는 범위 (px)
const NEXT_AREA := Rect2(11 * T, 3 * T, 5 * T, 2 * T)
## 마을 표지 자리 (아래 입구 오른쪽, 그림 밑 가운데, px). 금사리: 회색 항아리 구조물에 검정 글씨.
const SIGN_AT := Vector2(16 * T + 12, 13 * T + 14)
## 웨이포인트 돌 자리 (웨이포인트가 있는 구역의 아래 입구 왼쪽 위, px)
const WAYPOINT_AT := Vector2(9 * T, 11 * T)
const TREE_SPOTS: Array[Vector2] = [
	Vector2(24, 52), Vector2(72, 44), Vector2(124, 50), Vector2(176, 42), Vector2(228, 48), Vector2(280, 40),
	Vector2(332, 46), Vector2(384, 42), Vector2(436, 50), Vector2(488, 44), Vector2(540, 48), Vector2(592, 42),
	Vector2(20, 130), Vector2(30, 210), Vector2(22, 300), Vector2(616, 130), Vector2(608, 214), Vector2(618, 300),
	Vector2(120, 356), Vector2(200, 362), Vector2(440, 360), Vector2(520, 356),
]

var hunter: Character
## 지금 구역 (Config.HUNT_ZONES 번호)
var zone := 0
## 이번 구역 대장을 쓰러뜨려 위쪽 길이 열렸는지
var path_open := false
var hearts := Config.HUNTER_HEARTS
var slimes: Array[WildSlime] = []
## 땅에 떨어진 알 (자리 → 종)
var drops: Array[Dictionary] = []
## 이번 사냥에서 주운 알
var picked: Array[CreatureSpecies] = []
## 땅에 떨어진 드롭 (HuntLoot 사전 + at)
var loot: Array[Dictionary] = []
var loot_rng := RandomNumberGenerator.new()
var knocked := false
## 이번 사냥에서 대장 슬라임이 나왔는지 (사냥 한 번에 한 마리, 사냥은 하루 한 번)
var boss_spawned := false
## 대장이 나오는 자리 (공터 가운데)
const BOSS_AT := Vector2(13 * T, 7 * T)
## 따라온 크리처 (없으면 혼자). 2026-09-27 결정 A. 따라오는 동료.
var companion: HuntCompanion
## false 면 동행 크리처가 스스로 움직이지 않는다 (공격 간격은 그대로 흐름). 테스트에서 끈다.
var companion_ai := true

var _cooldown := 0.0
var _invulnerable := 0.0
var _swing_time := 0.0
var _swing_dir := Vector2.DOWN
## 이번 휘두르기 반지름 (그리기용, 무기마다 다름)
var _swing_radius := Config.SWING_RADIUS
## 날아가는 화살 · 지팡이 구슬 {kind = &"arrow"/&"orb", at, dir, left = 남은 거리, (orb) blast, element}
var shots: Array[Dictionary] = []
## 지팡이 구슬이 터진 자리 (그리기용) {at, radius, element, t}
var _blasts: Array[Dictionary] = []
## 불 구슬: 잠시 뒤 한 번 더 피해 {slime, t}
var _burns: Array[Dictionary] = []
var _fx: Node2D
var _hud: Node2D
var _ground: Node2D
var _trees: Array[Sprite2D] = []
## 지금 구역의 마을 표지 (없으면 null)
var sign_node: Sprite2D
## 지금 구역의 넓은 맵 칸 지도 (한 화면 구역이면 null)
var map: HuntMap
var camera: Camera2D
var _gate: Sprite2D
## 작은 지도: 한 칸 = 한 픽셀, 가 본 칸만 색이 칠해진다 (안 가 본 칸은 투명)
var _mini_img: Image
var _mini_tex: ImageTexture
var _mini_cell := Vector2i(-999, -999)
## 넓은 맵에 세운 나무 (구역이 바뀌면 치운다)
var _map_trees: Array[Sprite2D] = []
## 금두꺼비 혀가 지나간 자리의 금가루 {at, t = 남은 시간}. 밟으면 느려진다.
var dust: Array[Dictionary] = []
## 밤 구역 (번천): 어둠 · 가로등 · 호롱 불빛 노드 (구역을 옮기면 지운다)
var _night: Array[Node] = []
var _lantern: PointLight2D
## 유령 막차 전조등 불빛 (대장이 있을 때만)
var _bus_light: PointLight2D
## 이번 사냥에 쓴 연금술사 물약 (호롱 기름 · 힘 · 빠르기)
var lamp_oil := false
var strong := false
var quick := false
## 목축인 사냥 도시락을 먹고 들어왔는지 (2026-09-30 축사 닭장): 이번 사냥 동안 하트 칸 +Config.LUNCH_HEARTS
var lunch := false
## 산군 백호 포효에 굳은 남은 시간 (그동안 사냥꾼이 못 움직이고 못 휘두름)
var frozen := 0.0
## 가로등 자리 (불빛 가운데, px)
var lamps: Array[Vector2] = []


func _ready() -> void:
	var ground := Node2D.new()
	ground.z_index = -1000
	ground.draw.connect(_draw_ground.bind(ground))
	add_child(ground)
	_ground = ground
	for p in TREE_SPOTS:
		var tree := Sprite2D.new()
		tree.texture = preload("res://assets/props/tree_persimmon.png")
		tree.centered = false
		tree.offset = Vector2(-24, -72)
		tree.position = p
		tree.z_index = int(p.y)
		add_child(tree)
		_trees.append(tree)
	var gate := Sprite2D.new()
	gate.texture = preload("res://assets/props/hunt_gate.png")
	gate.centered = false
	gate.offset = Vector2(-36, -56)
	gate.position = EXIT_AT
	gate.z_index = int(EXIT_AT.y)
	add_child(gate)
	_gate = gate
	camera = Camera2D.new()
	add_child(camera)
	camera.make_current()
	_fx = Node2D.new()
	_fx.z_index = 4000
	_fx.draw.connect(_draw_fx)
	add_child(_fx)
	var layer := CanvasLayer.new()
	layer.layer = 2
	add_child(layer)
	_hud = Node2D.new()
	_hud.draw.connect(_draw_hud)
	layer.add_child(_hud)
	_fill_zone()


## 지금 구역의 몬스터를 새로 놓고 풍경 색을 바꾼다.
func _fill_zone() -> void:
	for s in slimes:
		s.queue_free()
	slimes.clear()
	dust.clear()
	var z: Dictionary = Config.HUNT_ZONES[zone]
	map = HuntMap.load_map(z.map) if z.has("map") else null
	for t in _map_trees:
		t.queue_free()
	_map_trees.clear()
	if map:
		for p in map.find("T"):
			var tree := Sprite2D.new()
			tree.texture = preload("res://assets/props/tree_persimmon.png")
			tree.centered = false
			tree.offset = Vector2(-24, -72)
			tree.position = p + Vector2(0, 10)
			tree.z_index = int(tree.position.y)
			add_child(tree)
			_map_trees.append(tree)
	var spots: Array[Vector2] = []
	if map:
		spots = map.find("c")
	for i in z.count:
		var s := WildSlime.new()
		s.setup_zone(zone)
		s.area = monster_area()
		s.terrain = map
		s.position = spots[i % spots.size()] if map else Farm.center_of(SLIME_CELLS[i % SLIME_CELLS.size()])
		s.ai_enabled = _ai_on
		s.swooped.connect(_on_swooped.bind(s))
		s.burst.connect(_on_burst.bind(s))
		add_child(s)
		slimes.append(s)
	for tree in _trees + _map_trees:
		tree.modulate = z.tree_tint
	for tree in _trees:
		tree.visible = map == null
	_gate.position = Vector2(map.spot("E").x, map.pixel_size().y) if map else EXIT_AT
	_gate.z_index = int(_gate.position.y)
	var world := map.pixel_size() if map else Vector2(640, 360)
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(world.x)
	camera.limit_bottom = int(world.y)
	if sign_node:
		sign_node.queue_free()
		sign_node = null
	if z.has("sign"):
		sign_node = Sprite2D.new()
		sign_node.texture = preload("res://assets/props/geumsa_jar.png")
		sign_node.centered = false
		sign_node.offset = Vector2(-24, -64)
		sign_node.position = map.spot("J") + Vector2(0, 10) if map else SIGN_AT
		sign_node.z_index = int(sign_node.position.y)
		sign_node.draw.connect(_draw_sign.bind(sign_node, z.sign))
		add_child(sign_node)
	_setup_night(z)
	_ground.queue_redraw()


## 밤 구역 (2026-09-29 번천, 사용자: "주변에 산이랑 도로만있어서 다른데보다 기온이 낮고 어두워"):
## 사냥터 전체를 어둡게 하고 가로등(칸 지도 L) · 사냥꾼 호롱 · 동행 불빛만 밝힌다.
func _setup_night(z: Dictionary) -> void:
	for n in _night:
		n.queue_free()
	_night.clear()
	lamps.clear()
	_lantern = null
	_bus_light = null
	if z.has("shade") and not z.get("night", false):
		# 그늘 구역 (밀목 솔숲): 조금 어둡기만 하고 불빛 규칙은 없다
		var shade := CanvasModulate.new()
		shade.color = z.shade
		add_child(shade)
		_night.append(shade)
	if not z.get("night", false) or map == null:
		return
	var dark := CanvasModulate.new()
	dark.color = Config.NIGHT_ZONE_COLOR
	add_child(dark)
	_night.append(dark)
	for p in map.find("L"):
		var post := Sprite2D.new()
		post.texture = preload("res://assets/props/street_lamp.png")
		post.centered = false
		post.offset = Vector2(-8, -44)
		post.position = p + Vector2(0, 8)
		post.z_index = int(post.position.y)
		add_child(post)
		_night.append(post)
		var head := p + Vector2(0, -26)
		lamps.append(p)
		_night.append(_add_light(head, Config.LAMP_LIGHT_RADIUS * 1.3, Color(1.0, 0.9, 0.6), 1.3))
	_lantern = _add_light(Vector2.ZERO, Config.LANTERN_RADIUS * 1.4, Color(1.0, 0.75, 0.45), 1.1)
	_night.append(_lantern)
	if z.get("boss_pattern", &"") == &"bus":
		_bus_light = _add_light(Vector2.ZERO, Config.BUS_LIGHT_RADIUS * 1.3, Color(1.0, 0.95, 0.7), 1.2)
		_bus_light.visible = false
		_night.append(_bus_light)
	# 호롱 기름 (연금술사): 밤 구역에 들어갈 때 하나 쓴다
	if not lamp_oil and GameState.lamp_oil > 0:
		GameState.lamp_oil -= 1
		lamp_oil = true
		GameState.notify("호롱에 기름을 채웠다. 이번 사냥 동안 불빛이 넓다 (남은 호롱 기름 %d)." % GameState.lamp_oil)


static var _light_tex: GradientTexture2D


func _add_light(at: Vector2, radius: float, col: Color, energy: float) -> PointLight2D:
	if _light_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		_light_tex = GradientTexture2D.new()
		_light_tex.gradient = g
		_light_tex.fill = GradientTexture2D.FILL_RADIAL
		_light_tex.fill_from = Vector2(0.5, 0.5)
		_light_tex.fill_to = Vector2(0.5, 0.0)
		_light_tex.width = 128
		_light_tex.height = 128
	var l := PointLight2D.new()
	l.texture = _light_tex
	l.texture_scale = radius * 2.0 / 128.0
	l.color = col
	l.energy = energy
	l.position = at
	add_child(l)
	return l


## 밤 구역인지 (어둡고 유령이 불빛 안에서만 맞음)
func is_night() -> bool:
	return Config.HUNT_ZONES[zone].get("night", false)


## 이 자리가 불빛 안인지: 가로등 · 사냥꾼 호롱 · 불빛 동행. 밤 구역이 아니면 늘 밝다.
func in_light(p: Vector2) -> bool:
	if not is_night():
		return true
	if hunter and p.distance_to(hunter.feet()) <= lantern_radius():
		return true
	if companion and companion.light_radius() > 0.0 and p.distance_to(companion.position) <= companion.light_radius():
		return true
	if _bus_light and _bus_light.visible and p.distance_to(_bus_light.position) <= Config.BUS_LIGHT_RADIUS:
		return true
	for l in lamps:
		if p.distance_to(l) <= Config.LAMP_LIGHT_RADIUS:
			return true
	return false


## 사냥꾼 호롱 불빛 반지름 (px)
func lantern_radius() -> float:
	return Config.LANTERN_RADIUS * (Config.LAMP_OIL_MULT if lamp_oil else 1.0)


## 사냥꾼 한 번 공격의 피해 (힘 물약을 마셨으면 +1)
func power() -> int:
	return 2 if strong else 1


## 무기 · 동행이 이 몬스터를 맞힐 수 있는지. 유령(ghost 구역)은 불빛 밖에서 반쯤 비쳐 다 지나간다.
func hittable(s: WildSlime) -> bool:
	return not (Config.HUNT_ZONES[zone].get("ghost", false) and not s.boss and not in_light(s.position))


## 사냥꾼을 사냥터로 데려온다.
## start_zone 은 사냥터 입구에서 고른 웨이포인트 구역 (0 = 숲 공터부터).
func start(h: Character, start_zone := 0) -> void:
	hunter = h
	if start_zone != zone:
		zone = start_zone
		_fill_zone()
	loot_rng.randomize()
	hearts = max_hearts()
	hunter.show_facing_cell = false
	hunter.queue_redraw()
	_place_hunter()


## 사냥꾼을 지금 구역 들어오는 자리에 세우고, 걸을 곳과 카메라를 맞춘다.
func _place_hunter() -> void:
	hunter.walk_area = Rect2(Vector2(8, 8), map.pixel_size() - Vector2(16, 16)) if map else WALK_AREA
	hunter.terrain = map
	hunter.position = spawn_at()
	hunter.facing = Vector2i.UP
	_follow_camera()
	_reset_minimap()


func _follow_camera() -> void:
	if hunter:
		camera.position = hunter.position
		camera.reset_smoothing()


func _exit_tree() -> void:
	# 카메라가 사라져도 마을 화면이 밀린 채로 남지 않게 되돌린다 (다른 사냥터 카메라가 이미 켜졌으면 그대로)
	if camera.is_current():
		get_viewport().canvas_transform = Transform2D.IDENTITY


## 사냥꾼이 들어오는 자리 (px)
func spawn_at() -> Vector2:
	return map.spot("S") if map else SPAWN_AT


## 아래 입구 (마을로) F가 닿는 범위 (px)
func exit_area() -> Rect2:
	if map:
		var e := map.spot("E")
		return Rect2(e.x - 3 * T, e.y - 2 * T - 12, 6 * T, 2 * T + 24)
	return EXIT_AREA


## 위쪽 길 (다음 구역) F가 닿는 범위 (px)
func next_area() -> Rect2:
	if map:
		var n := map.spot("N")
		return Rect2(n.x - 2.5 * T, n.y - T, 5 * T, 3 * T)
	return NEXT_AREA


func waypoint_at() -> Vector2:
	return map.spot("W") if map else WAYPOINT_AT


func boss_at() -> Vector2:
	return map.spot("K") if map else BOSS_AT


## 몬스터가 다닐 수 있는 영역 (px). 넓은 맵은 맵 전체 (물·바위는 칸 지도로 막음).
func monster_area() -> Rect2:
	if map:
		return Rect2(Vector2(T, T), map.pixel_size() - Vector2(2 * T, 2 * T))
	return Rect2(Vector2(CLEARING.position * T) + Vector2(12, 12), Vector2(CLEARING.size * T) - Vector2(24, 24))


## 농장 크리처를 데려온다. 사냥꾼 뒤에 선다.
func add_companion(from: Creature) -> HuntCompanion:
	companion = HuntCompanion.new()
	companion.setup(from)
	companion.position = hunter.feet() + Vector2(0, Config.COMPANION_FOLLOW_DISTANCE)
	add_child(companion)
	return companion


## 입은 장비와 세트 보너스까지 더한 하트 칸 수
func max_hearts() -> int:
	return Config.HUNTER_HEARTS + Wearables.bonus_hearts(&"hunter") + (Config.LUNCH_HEARTS if lunch else 0)


## 사냥 도시락을 먹는다: 하트 칸이 늘고 늘어난 만큼 찬다.
func eat_lunch() -> void:
	if lunch:
		return
	lunch = true
	hearts = mini(hearts + Config.LUNCH_HEARTS, max_hearts())


## 빨간 물약을 마신다 (1 키). 하트가 가득이면 아끼고 마시지 않는다.
func drink_potion() -> bool:
	if knocked:
		return false
	if GameState.potions <= 0:
		GameState.notify("빨간 물약이 없다.")
		return false
	if hearts >= max_hearts():
		GameState.notify("하트가 가득하다. 물약은 아껴 두자.")
		return false
	GameState.potions -= 1
	hearts = mini(hearts + Config.POTION_HEAL, max_hearts())
	GameState.notify("빨간 물약을 마셨다. 하트 %d/%d (남은 물약 %d)" % [hearts, max_hearts(), GameState.potions])
	return true


var _ai_on := true


func set_ai(on: bool) -> void:
	_ai_on = on
	for s in slimes:
		s.ai_enabled = on


func near_exit() -> bool:
	return exit_area().has_point(hunter.position)


## 열린 위쪽 길 가까이인지
func near_next() -> bool:
	return path_open and next_area().has_point(hunter.position)


## 끊어진 쇠다리 (2026-09-29 사용자 선택 "대장간과 묶기"): 금사리 대장을 잡아도 윗길(광동리 쪽)의 쇠다리가 끊겨 있어
## 대장간을 고쳐야 대장장이가 다리를 이어 준다. 2막이 1막 목표(약 20일)보다 일찍 열리던 것과 사금 덩이를 건너뛰던 것을 막는다.
func bridge_broken() -> bool:
	return zone == Config.FORGE_ZONE and GameState.forge_state < 2


## 캄캄한 번천 길 (2026-09-29 약방 복구 추천): 도마리 장승을 잡아도 번천 쪽은 너무 어두워, 약방을 고쳐 연금술사가
## 호롱을 만들어 줘야 넘어간다. 3막이 로드맵(약방 ≈ 45일째)보다 일찍 열리던 것(활로 장승 14~18일째)을 막는다.
func road_dark() -> bool:
	return zone == Config.YAK_ZONE and GameState.yak_state < 2


## 위쪽 길이 막혔으면 그 까닭 (비었으면 안 막힘)
func path_block() -> String:
	if bridge_broken():
		return "쇠다리가 끊겨 있어 건널 수 없다. 대장간을 고치면 대장장이가 이어 줄 것 같다."
	if road_dark():
		return "번천 쪽은 너무 캄캄해서 한 발짝도 못 가겠다. 약방을 고치면 연금술사가 호롱을 만들어 줄 것 같다."
	return ""


## 위쪽 길로 다음 구역에 들어간다 (같은 날, 하트 그대로). 땅에 남은 것은 챙겨 간다.
func advance() -> bool:
	if not path_open or zone + 1 >= Config.HUNT_ZONES.size():
		return false
	if path_block() != "":
		GameState.notify(path_block())
		return false
	for d in drops:
		picked.append(d.species)
	drops.clear()
	for i in range(loot.size() - 1, -1, -1):
		if _take(loot[i]):
			loot.remove_at(i)
	loot.clear()
	zone += 1
	path_open = false
	boss_spawned = false
	_fill_zone()
	_place_hunter()
	if companion:
		companion.position = hunter.feet() + Vector2(0, Config.COMPANION_FOLLOW_DISTANCE)
	var z: Dictionary = Config.HUNT_ZONES[zone]
	var text := "%d구역 %s에 들어왔다. %s이(가) 더 단단하고 빠르다!" % [zone + 1, z.name, z.monster]
	if z.has("advice"):
		text += " (%s)" % z.advice
	if z.waypoint and not zone in GameState.waypoints:
		GameState.waypoints.append(zone)
		text += " 웨이포인트가 켜졌다. 내일부터 사냥터 입구에서 여기서 시작할 수 있다."
	GameState.notify(text)
	return true


func _process(delta: float) -> void:
	tick(delta)


func tick(delta: float) -> void:
	if hunter == null or knocked:
		return
	_cooldown = maxf(_cooldown - delta, 0.0)
	_invulnerable = maxf(_invulnerable - delta, 0.0)
	_swing_time = maxf(_swing_time - delta, 0.0)
	if frozen > 0.0:
		frozen -= delta
		if frozen <= 0.0:
			frozen = 0.0
			hunter.frozen = false
	_follow_camera()
	_reveal_minimap()
	var feet := hunter.feet()
	if _lantern:
		_lantern.position = feet + Vector2(0, -10)
		_lantern.texture_scale = lantern_radius() * 2.8 / 128.0
	if _bus_light:
		var b := _boss()
		_bus_light.visible = b != null
		if b:
			_bus_light.position = b.position + Vector2(-40.0 if b._sprite.flip_h else 40.0, -12)
	var popped := false
	for s: WildSlime in slimes.duplicate():
		var was_buried := s.buried
		s.lit = in_light(s.position)
		s.tick(delta, feet)
		popped = popped or (was_buried and not s.buried)
		s.modulate.a = 1.0 if hittable(s) else Config.GHOST_FADE
		if knocked:
			return
		# 대장은 몸에 닿아도 안 다친다 (2026-09-29 사용자: "보스몬스터에 부딪히기만 해도 체력이 감소하는건 근거리를 좋아하는 유저에겐 힘들거같아").
		# 대장은 예고가 있는 패턴(내려찍기 · 혀 · 짚단 · 통나무)으로만 다치게 한다.
		# 어둠 속 유령은 몸도 닿지 않는다 (불빛 안에서만 서로 닿음)
		if _invulnerable <= 0.0 and not s.boss and not s.buried and not s.flyer and not s.stunned() and not s.airborne() and hittable(s) and s.position.distance_to(feet) <= Config.WILD_SLIME_TOUCH_DISTANCE * s.scale.x:
			_hurt(s.position, s.damage, s.title)
	if popped:
		_pack_pop()
	_tick_dust(delta)
	_tick_shots(delta)
	if knocked:
		return
	if companion:
		_tick_companion(delta)
	for i in range(drops.size() - 1, -1, -1):
		if drops[i].at.distance_to(feet) <= 14.0:
			picked.append(drops[i].species)
			drops.remove_at(i)
			GameState.notify("알을 주웠다! 마을로 돌아가 공급함에 넣자.")
	for i in range(loot.size() - 1, -1, -1):
		if loot[i].at.distance_to(feet) <= 14.0:
			if _take(loot[i]):
				loot.remove_at(i)
		else:
			loot[i].erase("full")
	queue_redraw()
	_fx.queue_redraw()
	_hud.queue_redraw()


## 공격한다 (클릭). 든 무기에 따라 휘두르기 · 화살 · 지팡이 구슬 (2026-09-29 무기). 무기가 없으면 사냥칼.
## dir 이 비어 있으면 바라보는 쪽으로. 휘두르기는 맞힌 수, 쏘기는 쏘았으면 1 (맞았는지는 날아간 뒤).
func swing(dir := Vector2.ZERO) -> int:
	if knocked or _cooldown > 0.0 or frozen > 0.0:
		return 0
	if dir != Vector2.ZERO:
		# 마우스로 누른 쪽을 바라보게 한다 (4방향)
		hunter.facing = Vector2i(int(signf(dir.x)), 0) if absf(dir.x) > absf(dir.y) else Vector2i(0, int(signf(dir.y)))
	else:
		dir = Vector2(hunter.facing)
	_swing_dir = dir.normalized()
	var w := Wearables.weapon()
	_cooldown = w.cooldown
	var hand := hunter.feet() + Vector2(0, -8)
	if w.kind == &"bow":
		shots.append({kind = &"arrow", at = hand, dir = _swing_dir, left = w.range})
		return 1
	if w.kind == &"staff":
		shots.append({kind = &"orb", at = hand, dir = _swing_dir, left = w.range, blast = w.blast, element = w.element})
		return 1
	_swing_time = 0.15
	_swing_radius = w.radius
	var center: Vector2 = hand + _swing_dir * w.reach
	var hits := 0
	for s in slimes.duplicate():
		if not s.airborne() and hittable(s) and s.position.distance_to(center) <= w.radius:
			hits += 1
			if s.hit(hunter.feet(), power()):
				_defeat(s)
	return hits


## 화살 · 구슬을 날리고 맞힌다. 화살은 첫 몬스터에 박히고 (나는 참새도 맞힘, 모래에 숨은 모래게는 지나감.
## 그루터기인 척하는 고목 그루터기는 보이니 맞아서 깨어남),
## 구슬은 처음 닿은 몬스터 또는 사거리 끝에서 터져 둘레 모두를 맞힌다.
func _tick_shots(delta: float) -> void:
	for i in range(_blasts.size() - 1, -1, -1):
		_blasts[i].t -= delta
		if _blasts[i].t <= 0.0:
			_blasts.remove_at(i)
	for i in range(_burns.size() - 1, -1, -1):
		var b: Dictionary = _burns[i]
		b.t -= delta
		if b.t > 0.0:
			continue
		_burns.remove_at(i)
		var s: WildSlime = b.slime
		if is_instance_valid(s) and s in slimes and hittable(s) and s.hit(s.position + Vector2(0, -4)):
			_defeat(s)
	for i in range(shots.size() - 1, -1, -1):
		var sh: Dictionary = shots[i]
		var speed := Config.ARROW_SPEED if sh.kind == &"arrow" else Config.ORB_SPEED
		var step := minf(speed * delta, sh.left)
		sh.at += sh.dir * step
		sh.left -= step
		var hit_r := Config.ARROW_HIT_RADIUS if sh.kind == &"arrow" else Config.ORB_HIT_RADIUS
		var target: WildSlime = null
		for s in slimes:
			if (s.buried and not s.disguise) or (s.airborne() and not (sh.kind == &"arrow" and s.in_air())) or not hittable(s):
				continue
			# 몬스터 몸 가운데 (발보다 조금 위, 큰 대장은 더 넓게)
			if (s.position + Vector2(0, -8 * s.scale.y)).distance_to(sh.at) <= hit_r * s.scale.x:
				target = s
				break
		# 나무 · 창고 · 비닐하우스처럼 키 큰 것에 막힌다 (물 · 바위 · 덤불 위로는 날아감)
		var blocked := map != null and SHOT_BLOCK.contains(map.at(Vector2i(floori(sh.at.x / T), floori(sh.at.y / T))))
		if target == null and sh.left > 0.0 and not blocked:
			continue
		shots.remove_at(i)
		if sh.kind == &"arrow":
			if target != null and target.hit(sh.at - sh.dir * 10.0, power()):
				_defeat(target)
		else:
			_burst(sh.at, sh.blast, sh.element)


## 지팡이 구슬이 터진다: 둘레 모두 1 피해 + 속성 효과
func _burst(at: Vector2, radius: float, element: StringName) -> void:
	_blasts.append({at = at, radius = radius, element = element, t = 0.3})
	for s in slimes.duplicate():
		if s.airborne() or not hittable(s) or (s.position + Vector2(0, -6)).distance_to(at) > radius + 8.0 * s.scale.x:
			continue
		if s.hit(at, power()):
			_defeat(s)
			continue
		match element:
			&"water":
				s.slow(Config.STAFF_SLOW_TIME)
			&"earth":
				s.stun(Config.STAFF_STUN_TIME)
			&"fire":
				_burns.append({slime = s, t = Config.STAFF_BURN_DELAY})


var _companion_cooldown := 0.0


## 동행 크리처: 사냥꾼 뒤를 따라가다가 닿는 야생 슬라임이 있으면 공격한다.
func _tick_companion(delta: float) -> void:
	_companion_cooldown = maxf(_companion_cooldown - delta, 0.0)
	var target := _nearest_slime(companion.position, true)
	if companion_ai:
		var chase := companion.style in [HuntCompanion.Style.BUMP, HuntCompanion.Style.ROAR, HuntCompanion.Style.SPIRIT] and target != null \
			and target.position.distance_to(hunter.feet()) <= Config.COMPANION_CHASE_DISTANCE
		if chase:
			companion.move_toward_point(target.position, delta)
		else:
			var behind := hunter.feet() - Vector2(hunter.facing) * Config.COMPANION_FOLLOW_DISTANCE
			if companion.position.distance_to(hunter.feet()) > Config.COMPANION_FOLLOW_DISTANCE * 0.8:
				companion.move_toward_point(behind, delta)
			else:
				companion.move_toward_point(companion.position, delta)
	if target == null or _companion_cooldown > 0.0 or (target.airborne() and companion.style != HuntCompanion.Style.PECK):
		return
	if companion.position.distance_to(target.position) > companion.reach():
		return
	companion_attack(target)


## 동행 크리처가 한 번 공격한다 (1 피해). 쓰러뜨리면 사냥꾼이 쓰러뜨린 것과 똑같이 친다 (알 확률 포함).
func companion_attack(target: WildSlime) -> void:
	_companion_cooldown = companion.attack_interval()
	companion.play_attack(target.position)
	# 아기 백호 번개 발톱 (2026-09-30): 한 방이 2 피해
	var claw := 2 if companion.style == HuntCompanion.Style.SPIRIT else 1
	if companion.style == HuntCompanion.Style.ROAR or companion.style == HuntCompanion.Style.SPIRIT:
		# 포효: 둘레 몬스터 (대장 빼고) 가 잠깐 멈춘다
		for o in slimes:
			if not o.boss and o != target and o.position.distance_to(companion.position) <= Config.COMPANION_ROAR_RADIUS:
				o.stun(Config.COMPANION_ROAR_STUN)
	if target.hit(companion.position, claw):
		_defeat(target)
	elif companion.style == HuntCompanion.Style.ROAR or companion.style == HuntCompanion.Style.SPIRIT:
		if not target.boss:
			target.stun(Config.COMPANION_ROAR_STUN)
	elif companion.style == HuntCompanion.Style.PECK:
		pass
	elif companion.style == HuntCompanion.Style.EMBER:
		# 불씨: 잠시 뒤 한 번 더 맞는다 (불의 지팡이와 같은 불붙음)
		_burns.append({slime = target, t = Config.STAFF_BURN_DELAY})
	elif companion.style == HuntCompanion.Style.BIND:
		# 덩굴 묶기: 잠깐 붙잡는다 (못 움직이고 부딪혀도 안 다침, 사냥꾼 칼 칠 틈)
		target.stun(Config.COMPANION_BIND_STUN)
		companion.pulling = target
	elif companion.style == HuntCompanion.Style.PULL:
		# 혀 당기기: 동행 바로 앞까지 끌어와 잠깐 멈춘다 (사냥꾼 칼 앞으로 데려옴)
		var toward := (target.position - companion.position).normalized()
		target.pull_to((companion.position + toward * Config.COMPANION_PULL_GAP).clamp(target.area.position, target.area.end))
		target.stun(Config.COMPANION_PULL_STUN)
		companion.pulling = target
	elif companion.style == HuntCompanion.Style.BUMP:
		# 박치기는 더 멀리 밀쳐낸다
		var away := (target.position - companion.position).normalized()
		target.position = (target.position + away * 10.0).clamp(target.area.position, target.area.end)


func _nearest_slime(from: Vector2, only_hittable := false) -> WildSlime:
	var best: WildSlime = null
	for s in slimes:
		if only_hittable and not hittable(s):
			continue
		if best == null or s.position.distance_to(from) < best.position.distance_to(from):
			best = s
	return best


func _defeat(s: WildSlime) -> void:
	slimes.erase(s)
	var z: Dictionary = Config.HUNT_ZONES[zone]
	# 짝 대장 (도마리 장승 한 쌍): 둘 다 쓰러뜨려야 대장 보상 · 길 · 알. 먼저 쓰러진 쪽은 대장 드롭만.
	var boss_left := s.boss and slimes.any(func(o: WildSlime) -> bool: return o.boss)
	var last_boss := s.boss and not boss_left
	var who := "%s과(와) %s" % [z.boss_monster, z.partner.name] if last_boss and z.has("partner") else s.title
	if s.minion:
		# 대장이 불러낸 새끼는 아무것도 남기지 않는다
		s.queue_free()
		GameState.touch()
		return
	# 대장 재료 (2026-09-29 대장간 복구 A): 금두꺼비를 잡을 때마다 사금 덩이 하나, 처음 잡으면 다음 날 마을에 대장간 터
	var material_text := ""
	if last_boss and z.get("boss_material", false):
		GameState.material += 1
		material_text = " %s을(를) 얻었다 (%d개)." % [Config.BOSS_MATERIAL_NAME, GameState.material]
		if zone == Config.FORGE_ZONE and not GameState.forge_boss_down:
			GameState.forge_boss_down = true
			material_text += " 마을 쪽에서 무언가 무너지는 소리가 들렸다..."
	# 2막 대장 재료 (2026-09-29 약방 복구): 장승 한 쌍을 잡을 때마다 장승 조각 하나, 처음 잡으면 다음 날 마을에 약방 터
	if last_boss and z.get("boss_material2", false):
		GameState.material2 += 1
		material_text += " %s을(를) 얻었다 (%d개)." % [Config.BOSS_MATERIAL2_NAME, GameState.material2]
		if not GameState.yak_boss_down:
			GameState.yak_boss_down = true
			material_text += " 마을 쪽에서 약 달이는 냄새가 희미하게 났다..."
	# 3막 대장 재료 (2026-09-30 축사 닭장): 산군 백호를 잡을 때마다 산군 발톱 하나, 처음 잡으면 다음 날 마을에 축사 터
	if last_boss and z.get("boss_material3", false):
		GameState.material3 += 1
		material_text += " %s을(를) 얻었다 (%d개)." % [Config.BOSS_MATERIAL3_NAME, GameState.material3]
		if not GameState.barn_boss_down:
			GameState.barn_boss_down = true
			material_text += " 마을 쪽에서 닭 우는 소리가 희미하게 들렸다..."
	# 그림자 늑대 (밀목): 하나가 쓰러지면 둘레 늑대가 멈칫한다 (칠 틈)
	if s.wolf:
		for o in slimes:
			if o.wolf and o.position.distance_to(s.position) <= Config.WOLF_FLINCH_RANGE:
				o.stun(Config.WOLF_FLINCH)
	if not s.boss and (not GameState.first_egg_done or _egg_roll() < z.get("egg_chance", 0.0)):
		# 게임 전체 첫 처치는 알을 반드시 떨어뜨린다 (첫 사냥에서 막히지 않게). 그 뒤로는 드물게.
		GameState.first_egg_done = true
		# 구역마다 일반 알 종 (광동리 = 아기 참새). 없으면 슬라임 알.
		var table := CreatureCatalog.HUNT_TABLE
		var sp: CreatureSpecies = load(z.egg) if z.has("egg") and GameState.first_egg_done else table[randi() % table.size()]
		drops.append({at = _reachable(s.position), species = sp})
		GameState.notify("%s을(를) 쓰러뜨리자 알이 떨어졌다!" % s.title)
	elif boss_left:
		GameState.notify("%s이(가) 쓰러졌다! 남은 %s을(를) 마저 쓰러뜨리자." % [s.title, slimes.filter(func(o: WildSlime) -> bool: return o.boss)[0].title])
	elif s.boss and bridge_broken():
		GameState.notify("%s을(를) 쓰러뜨렸다! 위쪽 길이 보이지만 %d구역 %s로 가는 쇠다리가 끊겨 있다. 대장간을 고치면 이어질 것 같다.%s" % [who, zone + 2, Config.HUNT_ZONES[zone + 1].name, material_text])
	elif s.boss and road_dark():
		GameState.notify("%s을(를) 쓰러뜨렸다! 위쪽 길 너머 %d구역 %s 쪽은 캄캄하다. 약방을 고치면 연금술사가 호롱을 만들어 줄 것 같다.%s" % [who, zone + 2, Config.HUNT_ZONES[zone + 1].name, material_text])
	elif s.boss and zone + 1 < Config.HUNT_ZONES.size():
		GameState.notify("%s을(를) 쓰러뜨렸다! 위쪽 길이 열렸다. 길에서 F로 %d구역 %s, 아래 입구 F로 마을.%s" % [who, zone + 2, Config.HUNT_ZONES[zone + 1].name, material_text])
	elif s.boss:
		GameState.notify("%s을(를) 쓰러뜨렸다! 더 깊은 곳은 아직 막혀 있다. 아래 입구에서 F로 마을로 돌아가자.%s" % [who, material_text])
	elif slimes.is_empty() and not boss_spawned:
		GameState.notify("다 쓰러뜨리자 대장이 나타났다!")
	elif slimes.is_empty():
		GameState.notify("모두 쓰러뜨렸다. 아래 입구에서 F로 마을로 돌아가자.")
	else:
		GameState.notify("%s을(를) 쓰러뜨렸다. 남은 %d마리." % [s.title, slimes.size()])
	var boss_egg: String = z.get("boss_egg", "")
	if last_boss and boss_egg != "" and _egg_roll() < z.get("boss_egg_chance", 0.0):
		# 대장은 가끔 알을 남긴다 (금사리 금두꺼비 → 아기 금두꺼비 알, 2026-09-29 반드시 → 확률로 낮춤)
		var sp: CreatureSpecies = load(boss_egg)
		if sp == CreatureCatalog.TIGER and _egg_roll() < Config.WHITE_TIGER_CHANCE:
			# 아기 호랑이 알은 드물게 아기 백호 (2026-09-30 사용자: "낮은 확률로 백호가 나올수도있게하자")
			sp = CreatureCatalog.WHITE_TIGER
		drops.append({at = _reachable(s.position + Vector2(-10, 4)), species = sp})
		GameState.first_egg_done = true
		GameState.notify("%s이(가) 알을 남겼다! 부화하면 %s." % [s.title, sp.display_name])
	if last_boss and zone + 1 < Config.HUNT_ZONES.size():
		path_open = true
		_ground.queue_redraw()
	if loot_enabled:
		var d := HuntLoot.roll_for_boss(loot_rng, zone) if s.boss else HuntLoot.roll_for_kill(loot_rng, zone)
		if not d.is_empty():
			# 알과 겹치지 않게 살짝 옆에 떨어뜨린다
			d.at = _reachable(s.position + Vector2(10, 4))
			loot.append(d)
	s.queue_free()
	if slimes.is_empty() and not boss_spawned:
		spawn_boss()
	# 윗줄의 남은 슬라임 수를 새로 쓴다
	GameState.touch()


## 야생 슬라임을 다 쓰러뜨리면 공터 가운데에 대장 슬라임이 나온다 (디아블로2 챔피언처럼).
func _egg_roll() -> float:
	return egg_roll if egg_roll >= 0.0 else loot_rng.randf()


func spawn_boss() -> WildSlime:
	boss_spawned = true
	var z: Dictionary = Config.HUNT_ZONES[zone]
	var b := _new_boss(boss_at() + (Vector2(-30, 0) if z.has("partner") else Vector2.ZERO))
	if z.has("partner"):
		# 짝 대장 (도마리 천하대장군 · 지하여장군): 둘이 나란히 서 있고, 둘 다 쓰러뜨려야 구역을 깬다
		var p := _new_boss(boss_at() + Vector2(30, 0))
		p.make_partner(zone)
		GameState.notify("%s과(와) %s이(가) 눈을 부릅떴다!" % [b.title, p.title])
	return b


func _new_boss(at: Vector2) -> WildSlime:
	var b := WildSlime.new()
	b.make_boss(zone)
	b.area = monster_area()
	b.terrain = map
	b.position = at
	b.ai_enabled = _ai_on
	b.slammed.connect(_on_slammed.bind(b))
	b.lashed.connect(_on_lashed)
	b.bale_landed.connect(_on_bale_landed)
	b.called.connect(_on_called)
	b.rolled.connect(_on_rolled.bind(b))
	b.rammed.connect(_on_rammed.bind(b))
	b.roared.connect(_on_roared.bind(b))
	add_child(b)
	slimes.append(b)
	return b


## 무리 구역 (금사리): 하나가 모래에서 튀어나오면 근처에 숨은 것도 같이 튀어나와 몰려든다.
func _pack_pop() -> void:
	if not Config.HUNT_ZONES[zone].get("pack", false):
		return
	for s in slimes:
		if not s.buried:
			continue
		for o in slimes:
			if not o.buried and o.position.distance_to(s.position) <= Config.WILD_PACK_DISTANCE:
				s.buried = false
				break


## 대장 슬라임이 내려찍었다: 그림자 원 안이면 다치고, 새끼가 둘 튀어나온다.
func _on_slammed(at: Vector2, boss: WildSlime = null) -> void:
	var d := hunter.feet() - at
	d.y *= 2.0
	if boss == null:
		boss = _boss()
	if _invulnerable <= 0.0 and d.length() <= Config.SLAM_RADIUS and boss:
		_hurt(at, boss.damage, boss.title, "%s이(가) 쿵 내려찍었다!" % boss.title)
	if knocked or (boss and boss.pattern == &"tiger"):
		# 산군 백호의 도약은 새끼를 부르지 않는다
		return
	var minions := slimes.filter(func(o: WildSlime) -> bool: return o.minion).size()
	for i in mini(Config.SLAM_MINIONS, Config.SLAM_MINION_MAX - minions):
		var m := WildSlime.new()
		m.setup_zone(zone)
		m.buried = false
		m.make_minion()
		m.area = monster_area()
		m.terrain = map
		m.position = m._stand(at + Vector2(-34 if i == 0 else 34, 10))
		m.ai_enabled = _ai_on
		add_child(m)
		slimes.append(m)
	GameState.touch()


## 산군 백호가 포효했다: 원 안이면 잠깐 굳는다 (다치지는 않음, 다음 도약을 못 피할 수 있음).
func _on_roared(at: Vector2, boss: WildSlime) -> void:
	if knocked or not _in_circle(at, Config.TIGER_ROAR_RADIUS):
		return
	frozen = Config.TIGER_ROAR_FREEZE
	hunter.frozen = true
	GameState.notify("%s의 포효에 몸이 굳었다!" % boss.title)


## 참새가 내려꽂았다: 그림자 원 안이면 다친다.
func _on_swooped(at: Vector2, s: WildSlime) -> void:
	if _in_circle(at, Config.SWOOP_RADIUS) and _invulnerable <= 0.0 and not knocked:
		_hurt(at, s.damage, s.title, "%s이(가) 내려꽂았다!" % s.title)


## 천하대장군의 통나무가 굴러간다: 통나무에 닿으면 다친다 (다친 뒤 잠깐 무적이라 한 번만).
func _on_rolled(at: Vector2, boss: WildSlime) -> void:
	var feet := hunter.feet()
	if _invulnerable <= 0.0 and not knocked and feet.distance_to(at) <= Config.LOG_WIDTH / 2.0 + 6.0:
		_hurt(at, boss.damage, boss.title, "%s이(가) 굴린 통나무에 치였다!" % boss.title)


## 도깨비불이 불똥을 튀겼다: 원 안이면 다친다.
func _on_burst(at: Vector2, s: WildSlime) -> void:
	if _in_circle(at, Config.WISP_BURST_RADIUS) and _invulnerable <= 0.0 and not knocked:
		_hurt(at, s.damage, s.title, "%s이(가) 불똥을 튀겼다!" % s.title)


## 유령 막차가 달린다: 버스에 닿으면 다친다 (다친 뒤 잠깐 무적이라 한 번만).
func _on_rammed(at: Vector2, boss: WildSlime) -> void:
	var feet := hunter.feet()
	var d := feet - at
	if _invulnerable <= 0.0 and not knocked and absf(d.x) <= 44.0 and absf(d.y) <= Config.BUS_WIDTH / 2.0 + 4.0:
		_hurt(at, boss.damage, boss.title, "%s에 치였다!" % boss.title)


## 허수아비 장수의 짚단이 떨어졌다: 원 안이면 다친다.
func _on_bale_landed(at: Vector2) -> void:
	var boss := _boss()
	if boss and _in_circle(at, Config.STRAW_RADIUS) and _invulnerable <= 0.0 and not knocked:
		_hurt(at, boss.damage, boss.title, "%s이(가) 던진 짚단에 맞았다!" % boss.title)


## 허수아비 장수가 참새를 불렀다 (최대 SLAM_MINION_MAX 마리, 알·드롭 없음)
func _on_called(at: Vector2) -> void:
	if knocked:
		return
	var minions := slimes.filter(func(o: WildSlime) -> bool: return o.minion).size()
	for i in mini(Config.STRAW_CALL, Config.SLAM_MINION_MAX - minions):
		var m := WildSlime.new()
		m.setup_zone(zone)
		m.make_minion()
		m.area = monster_area()
		m.terrain = map
		m.position = (at + Vector2(-40 if i == 0 else 40, -20)).clamp(m.area.position, m.area.end)
		m.ai_enabled = _ai_on
		m.swooped.connect(_on_swooped.bind(m))
		m.burst.connect(_on_burst.bind(m))
		add_child(m)
		if m.flyer:
			m._fly = 1.0
		slimes.append(m)
	GameState.notify("허수아비 장수가 깃발을 흔들자 참새가 몰려왔다!" if Config.HUNT_ZONES[zone].get("boss_pattern") == &"straw" else "막차 문이 열리고 도깨비불 승객이 내렸다!")
	GameState.touch()


## 사냥꾼 발이 at 둘레 원(3/4 시점 납작한 원) 안인지
func _in_circle(at: Vector2, radius: float) -> bool:
	var d := hunter.feet() - at
	d.y *= 2.0
	return d.length() <= radius


## 금두꺼비가 혀를 뻗었다: 선 위면 다치고, 혀가 지나간 자리에 금가루가 남는다.
func _on_lashed(from: Vector2, to: Vector2) -> void:
	var feet := hunter.feet()
	var boss := _boss()
	var near := Geometry2D.get_closest_point_to_segment(feet, from, to)
	if _invulnerable <= 0.0 and near.distance_to(feet) <= Config.TONGUE_WIDTH / 2.0 + 4.0 and boss:
		_hurt(from, boss.damage, boss.title, "%s의 혀 채찍에 맞았다!" % boss.title)
	for k in [0.45, 0.75, 1.0]:
		dust.append({at = from.lerp(to, k), t = Config.GOLD_DUST_TIME})


## 사냥꾼 발이 설 수 있는 가까운 자리 (몬스터가 울타리·벽에 붙어 쓰러져도 떨어진 것을 주울 수 있게)
func _reachable(p: Vector2) -> Vector2:
	if map == null:
		return p
	for r in [0.0, 6.0, 12.0, 18.0, 24.0, 36.0]:
		for k in 8:
			var q: Vector2 = p + Vector2.RIGHT.rotated(k * TAU / 8.0) * r
			if map.is_free(Rect2(q - Character.FEET_BOX / 2.0, Character.FEET_BOX)):
				return q
			if r == 0.0:
				break
	return p


func _boss() -> WildSlime:
	for s in slimes:
		if s.boss:
			return s
	return null


## 금가루가 사라져 가고, 밟고 있으면 사냥꾼이 느려진다.
func _tick_dust(delta: float) -> void:
	var slow := false
	for i in range(dust.size() - 1, -1, -1):
		dust[i].t -= delta
		if dust[i].t <= 0.0:
			dust.remove_at(i)
		elif (dust[i].at as Vector2).distance_to(hunter.feet()) <= Config.GOLD_DUST_RADIUS:
			slow = true
	hunter.slow_mult = (Config.GOLD_DUST_SLOW if slow else 1.0) * (Config.SPEED_POTION_MULT if quick else 1.0)


## 드롭을 줍는다. 장비면 바로 입거나 가방에 넣고, 늘어난 하트 칸만큼 하트도 채운다.
## 가방과 창고가 다 차서 못 주우면 false (땅에 남기고, 그 자리에 서 있는 동안 한 번만 알린다).
func _take(d: Dictionary) -> bool:
	var before := max_hearts()
	var text := HuntLoot.take(d)
	if text == "":
		if not d.has("full"):
			d.full = true
			GameState.notify("가방과 창고가 모두 가득 차서 %s을(를) 주울 수 없다." % HuntLoot.label(d))
		return false
	GameState.notify(text)
	if d.kind == &"gear":
		hearts += max_hearts() - before
		hunter.refresh_wear()
	return true


## what: 무엇에 다쳤는지 알림 첫마디 (비우면 "<who>에게 부딪혔다!")
func _hurt(from: Vector2, damage := 1, who := "야생 슬라임", what := "") -> void:
	hearts -= damage
	_invulnerable = Config.HURT_INVULNERABLE_TIME
	var away := (hunter.feet() - from).normalized()
	if away == Vector2.ZERO:
		away = Vector2.DOWN
	hunter.step(away * 16.0)
	if hearts <= 0:
		knocked = true
		GameState.notify("사냥꾼이 쓰러졌다... 마을 입구로 돌아왔다. 주운 것은 그대로 있다.")
		knocked_out.emit()
	else:
		GameState.notify("%s 하트 -%d, 남은 하트 %d." % [what if what != "" else "%s에게 부딪혔다!" % who, damage, hearts])


## 떠날 때 아직 줍지 않은 알도 챙긴다 (알 보장이 헛되지 않게). 가져갈 알 목록을 돌려준다.
func collect_all() -> Array[CreatureSpecies]:
	for d in drops:
		picked.append(d.species)
	drops.clear()
	var left := 0
	for d in loot:
		if not _take(d):
			left += 1
	loot.clear()
	if left > 0:
		GameState.notify("가방과 창고가 모두 차서 장비 %d개를 두고 왔다." % left)
	return picked


func _draw() -> void:
	# 금가루 (밟으면 느려짐)
	for d in dust:
		var a := minf(d.t / 1.0, 1.0)
		var p: Vector2 = d.at
		draw_set_transform(p, 0.0, Vector2(1.0, 0.5))
		draw_circle(Vector2.ZERO, Config.GOLD_DUST_RADIUS, Color(0.95, 0.8, 0.3, 0.35 * a))
		draw_set_transform(Vector2.ZERO)
		for k in 6:
			var r := Vector2(cos(k * 2.1), sin(k * 1.3) * 0.5) * (4.0 + k * 1.8)
			draw_circle(p + r, 1.2, Color(1.0, 0.9, 0.45, a))
	# 몬스터 공격 예고: 붉은 띠 (달려들기·혀) · 그림자 원 (내려찍기). 찰수록 진해진다.
	for s in slimes:
		for tg: Dictionary in s.telegraphs():
			var fill := Color(1, 0.25, 0.2, 0.15 + 0.25 * tg.progress)
			var edge := Color(1, 0.35, 0.3, 0.9)
			if tg.kind == &"lane":
				var from: Vector2 = tg.from
				var to: Vector2 = tg.to
				var side: Vector2 = (to - from).normalized().orthogonal() * tg.width / 2.0
				var poly := PackedVector2Array([from + side, to + side, to - side, from - side])
				draw_colored_polygon(poly, fill)
				poly.append(from + side)
				draw_polyline(poly, edge, 1.0)
			else:
				draw_set_transform(tg.at, 0.0, Vector2(1.0, 0.5))
				draw_circle(Vector2.ZERO, tg.radius, fill)
				draw_arc(Vector2.ZERO, tg.radius, 0, TAU, 40, edge, 1.5)
				draw_arc(Vector2.ZERO, tg.radius * tg.progress, 0, TAU, 40, Color(1, 0.35, 0.3, 0.6), 1.0)
				draw_set_transform(Vector2.ZERO)
			if tg.get("bale", false):
				# 날아오는 짚단: 떨어질수록 낮아진다
				var p: Vector2 = tg.at + Vector2(0, -60.0 * (1.0 - tg.progress))
				draw_circle(p, 6.0, Color(0.72, 0.58, 0.31))
				draw_circle(p + Vector2(-1, -1), 5.0, Color(0.89, 0.76, 0.44))
				draw_line(p + Vector2(-5, 0), p + Vector2(5, 0), Color(0.6, 0.45, 0.25), 1.0)
	for d in drops:
		var p: Vector2 = d.at
		draw_set_transform(p + Vector2(0, 6), 0.0, Vector2(1.0, 0.4))
		draw_circle(Vector2.ZERO, 7.0, Color(0.27, 0.16, 0.33, 0.25))
		draw_set_transform(Vector2.ZERO)
		var sp: CreatureSpecies = d.species
		draw_texture_rect_region(DROPS, Rect2(p + Vector2(-8, -10), Vector2(16, 16)), Rect2(0, 0, 16, 16), sp.egg_color)
		draw_circle(p + Vector2(-2, -2), 1.2, sp.egg_spot_color)
		draw_circle(p + Vector2(1, 1), 1.0, sp.egg_spot_color)
	var font := ThemeDB.fallback_font
	for d in loot:
		var p: Vector2 = d.at
		var col := HuntLoot.color(d)
		draw_set_transform(p + Vector2(0, 5), 0.0, Vector2(1.0, 0.4))
		draw_circle(Vector2.ZERO, 6.0, Color(0.27, 0.16, 0.33, 0.25))
		draw_set_transform(Vector2.ZERO)
		match d.kind:
			&"money":
				draw_texture_rect_region(DROPS, Rect2(p + Vector2(-8, -10), Vector2(16, 16)), Rect2(48, 0, 16, 16))
			&"potion":
				draw_texture_rect_region(DROPS, Rect2(p + Vector2(-8, -11), Vector2(16, 16)), Rect2(16, 0, 16, 16))
			&"junk":
				# 분원농협 잡템은 슬라임 젤리, 다른 구역은 보따리
				var jx := 32 if zone == 0 else 64
				draw_texture_rect_region(DROPS, Rect2(p + Vector2(-8, -10), Vector2(16, 16)), Rect2(jx, 0, 16, 16))
			_ when Wearables.ITEMS[d.roll.base if d.has("roll") else d.id].slot == &"weapon":
				draw_line(p + Vector2(-6, 2), p + Vector2(6, -8), Color(0.75, 0.75, 0.8), 2.0)
				draw_line(p + Vector2(-6, -4), p + Vector2(-1, 2), Color(0.55, 0.38, 0.2), 2.0)
			_:
				draw_rect(Rect2(p + Vector2(-5, -8), Vector2(10, 10)), Color(0.2, 0.35, 0.2))
				var sheet: Texture2D = Wearables.ITEMS[d.roll.base if d.has("roll") else d.id].sheet
				draw_texture_rect_region(sheet, Rect2(p + Vector2(-12, -20), Vector2(24, 24)), Rect2(0, 0, 48, 48))
		# 디아블로2처럼 떨어진 것의 이름을 종류별 색으로 띄운다
		var text := HuntLoot.label(d)
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		draw_rect(Rect2(p + Vector2(-w / 2 - 2, -22), Vector2(w + 4, 11)), Color(0, 0, 0, 0.55))
		draw_string(font, p + Vector2(-w / 2, -14), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, col)
	if _swing_time > 0.0 and hunter:
		var c := hunter.feet() + Vector2(0, -12)
		var a := _swing_dir.angle()
		draw_arc(c, _swing_radius + 2.0, a - 1.0, a + 1.0, 10, Color(1, 1, 1, 0.85), 2.5)


const SHOT_BLOCK := "THGP"
const ELEMENT_COLORS := {&"water": Color(0.4, 0.65, 1.0), &"earth": Color(0.7, 0.5, 0.25), &"fire": Color(1.0, 0.5, 0.2)}


## 화살 · 구슬 · 터짐 (몬스터 위에 그린다)
func _draw_fx() -> void:
	for sh in shots:
		if sh.kind == &"arrow":
			# 어두운 테두리 위에 밝은 화살 (풀밭 · 흙길 어디서나 보이게)
			var tail: Vector2 = sh.at - sh.dir * 14.0
			var o: Vector2 = sh.dir.orthogonal()
			_fx.draw_line(tail, sh.at, Color(0.15, 0.1, 0.05, 0.8), 3.5)
			_fx.draw_line(tail, sh.at, Color(0.95, 0.85, 0.6), 1.5)
			_fx.draw_colored_polygon(PackedVector2Array([sh.at + sh.dir * 3.0, sh.at - sh.dir * 2.0 + o * 3.0, sh.at - sh.dir * 2.0 - o * 3.0]), Color(0.9, 0.9, 0.95))
			_fx.draw_line(tail, tail - sh.dir * 3.0 + o * 3.0, Color(1, 1, 1), 1.0)
			_fx.draw_line(tail, tail - sh.dir * 3.0 - o * 3.0, Color(1, 1, 1), 1.0)
		else:
			var col: Color = ELEMENT_COLORS[sh.element]
			_fx.draw_circle(sh.at, 8.0, Color(col, 0.3))
			_fx.draw_circle(sh.at, 5.0, col)
			_fx.draw_circle(sh.at + Vector2(-1.5, -1.5), 2.0, Color(1, 1, 1, 0.85))
	for b in _blasts:
		var col: Color = ELEMENT_COLORS[b.element]
		_fx.draw_set_transform(b.at, 0.0, Vector2(1.0, 0.6))
		_fx.draw_circle(Vector2.ZERO, b.radius, Color(col, 0.3 * b.t / 0.3))
		_fx.draw_arc(Vector2.ZERO, b.radius, 0, TAU, 24, col, 1.5)
		_fx.draw_set_transform(Vector2.ZERO)
	for b in _burns:
		var s: WildSlime = b.slime
		if is_instance_valid(s):
			_fx.draw_circle(s.position + Vector2(0, -20 * s.scale.y), 2.5, ELEMENT_COLORS[&"fire"])


## 마을 표지 글씨: 항아리 몸통에 검정 글씨 (사용자: "금사리(구터)", 구조물은 회색 · 글씨는 검정)
## n: 그 표지 노드 (구역을 옮겨 sign_node 가 비워진 뒤 지워지기 전에 한 번 더 그려질 수 있어 따로 받는다)
func _draw_sign(n: Sprite2D, text: String) -> void:
	var font := ThemeDB.fallback_font
	var i := text.find("(")
	var lines := [text.substr(0, i), text.substr(i)] if i > 0 else [text]
	var y := -36.0 if lines.size() > 1 else -30.0
	for line: String in lines:
		var size := 9 if line == lines[0] else 7
		var w := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		n.draw_string(font, Vector2(-w / 2, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0.08, 0.08, 0.08))
		y += size + 3


func _draw_ground(n: Node2D) -> void:
	if map:
		n.draw_texture(map.ground, Vector2.ZERO)
		if zone == 0:
			_draw_yard_deco(n)
		_draw_labels(n)
		if zone == Config.FORGE_ZONE:
			_draw_bridge(n)
		_draw_waypoint(n)
		return
	var tiles: Texture2D = preload("res://assets/tiles/farm_tiles.png")
	for x in Config.MAP_SIZE.x + 1:
		for y in Config.MAP_SIZE.y:
			var h := (x * 73856093) ^ (y * 19349663)
			var v := [0, 0, 0, 1, 1, 2, 3][absi(h) % 7] as int
			n.draw_texture_rect_region(tiles, Rect2(x * T, y * T, T, T), Rect2(v * T, 0, T, T), Config.HUNT_ZONES[zone].ground_tint)
	for x in range(CLEARING.position.x, CLEARING.end.x):
		var top := 0 if path_open and x >= 12 and x <= 14 else CLEARING.position.y
		for y in range(top, CLEARING.end.y + 3 if x >= 11 and x <= 13 else CLEARING.end.y):
			n.draw_texture_rect_region(tiles, Rect2(x * T, y * T, T, T), Rect2(4 * T, 0, T, T))
	_draw_waypoint(n)


const YARD_DECO := preload("res://assets/tiles/yard_deco.png")
const GROUND_DECO := preload("res://assets/tiles/ground_deco.png")
const DROPS := preload("res://assets/hunt/drops.png")


## 분원농협 바닥 장식 (2026-09-30 그래픽 시범): 시멘트 마당(%)엔 금 · 잡초 · 기름 얼룩 · 웅덩이 · 볏짚 · 낙엽, 풀밭(.)엔 풀꽃 · 풀포기
func _draw_yard_deco(n: Node2D) -> void:
	for y in map.size.y:
		for x in map.size.x:
			var ch := map.rows[y][x]
			if ch != "%" and ch != ".":
				continue
			var h := absi((x * 92837111) ^ (y * 689287499) ^ 0x2f1a) % 1000
			var off := Vector2((h / 16) % 9, (h / 144) % 7)
			if ch == "%" and h < 170:
				var k: int = [0, 1, 0, 2, 4, 5, 1, 3, 0, 4][h % 10]
				n.draw_texture_rect_region(YARD_DECO, Rect2(Vector2(x, y) * T + off, Vector2(16, 16)), Rect2(k * 16, 0, 16, 16))
			elif ch == "." and h < 300:
				var k: int = [4, 5, 4, 0, 8, 3, 6, 4][h % 8]
				n.draw_texture_rect_region(GROUND_DECO, Rect2(Vector2(x, y) * T + off, Vector2(16, 16)), Rect2(k * 16, 0, 16, 16))


## 금사리 윗길 쇠다리 (임시 그림): 대장간을 고치기 전엔 가운데가 끊겨 있다
func _draw_bridge(n: Node2D) -> void:
	var p := map.spot("N") + Vector2(0, T * 0.5)
	var broken := bridge_broken()
	var rail := Color(0.42, 0.44, 0.5)
	var plank := Color(0.55, 0.57, 0.62)
	for i in 5:
		var y := p.y - T * 0.5 + i * 6.0
		if broken and i >= 2 and i <= 3:
			continue
		n.draw_rect(Rect2(p.x - 18, y, 36, 4), plank)
	for sx in [-20.0, 18.0]:
		if broken:
			n.draw_rect(Rect2(p.x + sx, p.y - T * 0.5 - 2, 2, 12), rail)
			n.draw_rect(Rect2(p.x + sx, p.y + 8, 2, 10), rail)
		else:
			n.draw_rect(Rect2(p.x + sx, p.y - T * 0.5 - 2, 2, 32), rail)
	if broken:
		n.draw_line(p + Vector2(-16, 0), p + Vector2(-8, 5), Color(0.3, 0.25, 0.22), 1.0)
		n.draw_line(p + Vector2(10, 1), p + Vector2(16, 6), Color(0.3, 0.25, 0.22), 1.0)


## 창고 벽 간판 (구역 데이터 labels: 칸 자리 + 글씨)
func _draw_labels(n: Node2D) -> void:
	var font := ThemeDB.fallback_font
	for l in Config.HUNT_ZONES[zone].get("labels", []):
		var text: String = l[1]
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		var r := Rect2(Vector2(l[0]) * T + Vector2(-w / 2 - 3, -1), Vector2(w + 6, 11))
		n.draw_rect(r, Color(0.98, 0.97, 0.93))
		n.draw_rect(r, Color(0.35, 0.45, 0.6), false, 1.0)
		n.draw_string(font, r.position + Vector2(3, 9), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.15, 0.3, 0.55))


func _draw_waypoint(n: Node2D) -> void:
	if Config.HUNT_ZONES[zone].waypoint:
		# 웨이포인트 돌: 납작한 돌판에 푸른 빛
		var p := waypoint_at()
		n.draw_set_transform(p, 0.0, Vector2(1.0, 0.5))
		n.draw_circle(Vector2.ZERO, 16, Color(0.45, 0.45, 0.5))
		n.draw_circle(Vector2.ZERO, 12, Color(0.6, 0.62, 0.68))
		n.draw_arc(Vector2.ZERO, 8, 0, TAU, 20, Color(0.55, 0.85, 1.0), 2.0)
		n.draw_set_transform(Vector2.ZERO)


func _draw_hud() -> void:
	# 하트 · 빨간 물약 · 지금 구역 (그래픽 시범 2026-09-30: 아이콘 + 한지 알약)
	var font := ThemeDB.fallback_font
	var hw := max_hearts() * 13.0 + 6
	_hud.draw_style_box(UiSkin.chip_box(), Rect2(4, 30, hw, 17))
	for i in max_hearts():
		UiSkin.draw_icon(_hud, UiSkin.Icon.HEART if i < hearts else UiSkin.Icon.HEART_EMPTY, Vector2(7 + i * 13, 32))
	UiSkin.draw_chip(_hud, Vector2(7 + hw, 30), UiSkin.Icon.POTION, "x%d (1)" % GameState.potions, 17)
	var zt := "%d구역 %s" % [zone + 1, Config.HUNT_ZONES[zone].name]
	var zw := font.get_string_size(zt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + 22
	UiSkin.draw_chip(_hud, Vector2(636 - zw, 30), UiSkin.Icon.FLAG, zt, 17)
	_draw_offscreen_hint(font)
	_draw_minimap()
	if path_open:
		var pt := "▲ 위쪽 길: %d구역 %s (F)" % [zone + 2, Config.HUNT_ZONES[zone + 1].name]
		if bridge_broken():
			pt = "▲ 위쪽 길: 쇠다리가 끊김 (대장간을 고치면 이어짐)"
		elif road_dark():
			pt = "▲ 위쪽 길: 캄캄함 (약방을 고치면 연금술사가 호롱을 만들어 줌)"
		var pw := font.get_string_size(pt, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
		_hud.draw_rect(Rect2(13 * T - pw / 2 - 3, 2 * T - 10, pw + 6, 13), Color(0, 0, 0, 0.55))
		_hud.draw_string(font, Vector2(13 * T - pw / 2, 2 * T), pt, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1.0, 0.9, 0.35))


## 작은 지도 칸 색 (칸 글자 → 색). 없는 글자는 풀색
const MINI_COLORS := {
	".": Color(0.5, 0.68, 0.42), "J": Color(0.5, 0.68, 0.42), "T": Color(0.3, 0.48, 0.3), "B": Color(0.3, 0.5, 0.3), "R": Color(0.55, 0.53, 0.55),
	",": Color(0.8, 0.7, 0.52), "S": Color(0.8, 0.7, 0.52), "E": Color(0.8, 0.7, 0.52), "N": Color(0.8, 0.7, 0.52), "W": Color(0.8, 0.7, 0.52),
	"K": Color(0.8, 0.7, 0.52), "c": Color(0.8, 0.7, 0.52),
	"~": Color(0.36, 0.55, 0.72), "=": Color(0.55, 0.72, 0.8), "o": Color(0.6, 0.6, 0.62), "b": Color(0.62, 0.48, 0.34),
	"p": Color(0.48, 0.66, 0.64), "x": Color(0.84, 0.75, 0.56), "r": Color(0.6, 0.45, 0.33), "%": Color(0.78, 0.78, 0.75),
	"m": Color(0.78, 0.66, 0.4), "H": Color(0.5, 0.58, 0.68), "F": Color(0.55, 0.55, 0.6), "s": Color(0.9, 0.88, 0.8),
	"h": Color(0.85, 0.72, 0.4), "w": Color(0.95, 0.95, 0.95),
	"G": Color(0.85, 0.9, 0.88), "l": Color(0.62, 0.45, 0.3), "u": Color(0.7, 0.55, 0.38),
	"a": Color(0.36, 0.37, 0.42), "g": Color(0.75, 0.77, 0.8), "L": Color(1.0, 0.9, 0.55), "P": Color(0.3, 0.45, 0.65),
}
## 사냥꾼 둘레 이만큼(칸, 가로·세로 반지름)이 작은 지도에 드러난다. 화면 절반쯤 (임시)
const MINI_REVEAL := Vector2i(12, 7)
## 작은 지도 한 칸 크기 (px)
const MINI_SCALE := 2


func _reset_minimap() -> void:
	_mini_cell = Vector2i(-999, -999)
	if map == null:
		_mini_img = null
		_mini_tex = null
		return
	_mini_img = Image.create(map.size.x, map.size.y, false, Image.FORMAT_RGBA8)
	_mini_tex = ImageTexture.create_from_image(_mini_img)
	_reveal_minimap()


## 사냥꾼이 칸을 옮기면 둘레 칸을 작은 지도에 드러낸다
func _reveal_minimap() -> void:
	if _mini_img == null or hunter == null:
		return
	var c := Vector2i((hunter.feet() / T).floor())
	if c == _mini_cell:
		return
	_mini_cell = c
	var changed := false
	for y in range(maxi(c.y - MINI_REVEAL.y, 0), mini(c.y + MINI_REVEAL.y + 1, map.size.y)):
		for x in range(maxi(c.x - MINI_REVEAL.x, 0), mini(c.x + MINI_REVEAL.x + 1, map.size.x)):
			if _mini_img.get_pixel(x, y).a == 0.0:
				_mini_img.set_pixel(x, y, MINI_COLORS.get(map.at(Vector2i(x, y)), MINI_COLORS["."]))
				changed = true
	if changed:
		_mini_tex.update(_mini_img)


## 이번 사냥에서 이 칸을 작은 지도에 드러냈는지
func minimap_seen(c: Vector2i) -> bool:
	return _mini_img != null and c.x >= 0 and c.y >= 0 and c.x < map.size.x and c.y < map.size.y and _mini_img.get_pixel(c.x, c.y).a > 0.0


## 작은 지도 자리 (화면 px): 오른쪽 위, 구역 이름 아래
func minimap_rect() -> Rect2:
	var size := Vector2(map.size * MINI_SCALE)
	return Rect2(Vector2(636 - size.x, 50), size)


func _draw_minimap() -> void:
	if _mini_tex == null or hunter == null:
		return
	var r := minimap_rect()
	_hud.draw_rect(r.grow(1), Color(0.2, 0.15, 0.18, 0.8))
	_hud.draw_texture_rect(_mini_tex, r, false, Color(1, 1, 1, 0.95))
	_hud.draw_style_box(UiSkin.frame_box(), r.grow(4))
	# 아래 입구는 늘 보이고, 위쪽 길은 가 본 뒤에 보인다
	var gold := Color(1, 0.95, 0.6)
	var e := r.position + map.spot("E") / T * MINI_SCALE
	_hud.draw_rect(Rect2(e - Vector2(2, 3), Vector2(4, 3)), gold)
	var n := map.spot("N")
	if minimap_seen(Vector2i(n / T)):
		var np := r.position + n / T * MINI_SCALE
		_hud.draw_rect(Rect2(np - Vector2(2, 1), Vector2(4, 3)), gold)
	var hp := r.position + hunter.feet() / T * MINI_SCALE
	_hud.draw_circle(hp, 2.5, Color.WHITE)
	_hud.draw_circle(hp, 1.5, Color(0.9, 0.3, 0.35))


## 넓은 맵: 가장 가까운 몬스터가 화면 밖이면 화면 가장자리에 그쪽 화살표와 이름을 띄운다.
func _draw_offscreen_hint(font: Font) -> void:
	if map == null or hunter == null:
		return
	var s := _nearest_slime(hunter.feet())
	if s == null:
		return
	var view := Rect2(Vector2(0, 48), Vector2(640, 276))
	var sp := get_viewport().canvas_transform * s.position
	if view.has_point(sp):
		return
	var center := view.get_center()
	var dir := (sp - center).normalized()
	# 화면 가장자리에서 조금 안쪽
	var inner := view.grow(-18)
	var t := INF
	if dir.x != 0.0:
		t = minf(t, ((inner.end.x if dir.x > 0 else inner.position.x) - center.x) / dir.x)
	if dir.y != 0.0:
		t = minf(t, ((inner.end.y if dir.y > 0 else inner.position.y) - center.y) / dir.y)
	var at := center + dir * t
	var col := Color(0.95, 0.85, 0.45) if s.boss else Color(1, 0.97, 0.85)
	var side := dir.orthogonal()
	_hud.draw_colored_polygon(PackedVector2Array([at + dir * 9, at - dir * 5 + side * 6, at - dir * 5 - side * 6]), col)
	var text := s.title
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	var tp := (at - dir * 18 - Vector2(w / 2, -3)).clamp(Vector2(4, 56), Vector2(636 - w, 320))
	_hud.draw_rect(Rect2(tp + Vector2(-2, -8), Vector2(w + 4, 11)), Color(0, 0, 0, 0.55))
	_hud.draw_string(font, tp, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, col)
