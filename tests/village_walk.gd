extends Node
## 마을 동선 재기 (2026-10-01 넓어진 마을 동선 점검). 게임의 실제 막힘(울타리 · 집 · 나무 · 시설, Farm.is_free)으로
## 농부가 설 수 있는 자리를 4px 격자로 뽑고, 장소마다 "여기 서면 F 가 닿는" 자리, 아침마다 돋는 들나물 판을 JSON 으로 남긴다.
## 걷는 거리 계산 · 하루 일과 합계는 tools/village_walk.py 가 한다 (GDScript 로 길찾기를 돌리면 너무 느려서).
## 실행: OUT=/tmp/new.json godot --headless --path . res://tests/village_walk.tscn   (환경변수 START=barn 시험 시작 지점 · RUNS=200 들나물 판 수)
##       python3 tools/village_walk.py /tmp/new.json [옛 마을 json]
## 옛 26x15 마을과 비교하려면 옛 커밋 체크아웃에 이 파일을 복사해 똑같이 돌린다 (옛 코드에도 있는 것만 쓴다).

## 길찾기 격자 (px)
const G := 4


func _ready() -> void:
	var main: Node2D = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	main._rng.seed = 1
	if "clock_running" in main:
		main.clock_running = false
	var start := StringName(OS.get_environment("START")) if OS.get_environment("START") != "" else &"barn"
	TestStarts.apply(main, start)
	await get_tree().process_frame
	var farm: Farm = main.farm
	var who: Character = main.farmer
	var door_cell: Vector2i = main.get_script().get_script_constant_map()["DOOR_CELL"]
	var cols := Config.MAP_SIZE.x * Config.TILE / G
	var rows := Config.MAP_SIZE.y * Config.TILE / G
	var area := Rect2(Vector2(8, 8), Vector2(Config.MAP_SIZE * Config.TILE) - Vector2(16, 16))
	var free := PackedByteArray()
	free.resize(cols * rows)
	var pos: Array[Vector2] = []
	for i in cols * rows:
		var p := Vector2((i % cols) * G + G / 2.0, (i / cols) * G + G / 2.0)
		pos.append(p)
		free[i] = 1 if area.has_point(p) and farm.is_free(who.feet_rect(p)) else 0

	var places := {}
	var door := Farm.center_of(door_cell)
	places["집 현관"] = _nodes(free, pos, func(p: Vector2) -> bool: return p.distance_to(door) <= Config.PROP_INTERACT_DISTANCE)
	var plot0: Rect2i = Config.FIELD_PLOTS[0]
	places["밭"] = _nodes(free, pos, func(p: Vector2) -> bool: return _near_cell(p, plot0))
	for pair: Array in [["공급함", "supply_box"], ["부화기", "incubator"], ["사냥터 입구", "hunt_gate"], ["창고", "stash_box"], ["대장간", "forge"], ["약방", "yak"], ["축사", "barn"]]:
		var prop: Prop = main.get(pair[1])
		if prop != null:
			places[pair[0]] = _nodes(free, pos, func(p: Vector2) -> bool: return prop.is_near(p, Config.PROP_INTERACT_DISTANCE))
	var herbs := {}
	for c: Vector2i in Config.HERB_SPOTS:
		herbs["%d,%d" % [c.x, c.y]] = _nodes(free, pos, func(p: Vector2) -> bool: return _near_cell(p, Rect2i(c, Vector2i.ONE)))

	var runs := int(OS.get_environment("RUNS")) if OS.get_environment("RUNS") != "" else 200
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var forage: Forage = main.forage
	var sprouts := []
	for k in runs:
		forage.sprout(rng)
		sprouts.append(forage.herbs.keys().map(func(c: Vector2i) -> String: return "%d,%d" % [c.x, c.y]))

	var data := {
		map = [Config.MAP_SIZE.x, Config.MAP_SIZE.y], start = start, grid = G, cols = cols, rows = rows,
		speed = Config.CHARACTER_SPEED, min_per_sec = Config.CLOCK_MINUTES_PER_SECOND if "CLOCK_MINUTES_PER_SECOND" in Config else 2.0,
		free = Array(free), places = places, herbs = herbs, sprouts = sprouts,
	}
	var out := OS.get_environment("OUT") if OS.get_environment("OUT") != "" else "user://village_walk.json"
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()
	print("village_walk: wrote %s (%dx%d, %d places, %d runs)" % [out, Config.MAP_SIZE.x, Config.MAP_SIZE.y, places.size(), runs])
	get_tree().quit()


## 캐릭터 position p 에서 발이 rect 안 어느 칸 가운데에서 F 거리 안인가
static func _near_cell(p: Vector2, r: Rect2i) -> bool:
	var feet := p + Vector2(0, Character.FEET_Y)
	var c := Farm.cell_of(feet)
	for x in range(c.x - 2, c.x + 3):
		for y in range(c.y - 2, c.y + 3):
			if r.has_point(Vector2i(x, y)) and feet.distance_to(Farm.center_of(Vector2i(x, y))) <= Config.INTERACT_DISTANCE:
				return true
	return false


static func _nodes(free: PackedByteArray, pos: Array[Vector2], cond: Callable) -> Array:
	var out := []
	for i in free.size():
		if free[i] and cond.call(pos[i]):
			out.append(i)
	return out
