extends Node
## 사냥 손맛 후보 비교 화면 (2026-10-02). 실제 사냥터에서 간단한 봇이 싸우는 모습을 프레임으로 찍는다.
## 실행: xvfb-run godot --path . res://tests/pace_capture.tscn  (환경변수 S=저장 폴더 MODE=now|A|B|C SEC=10)
## now = 지금, A = 손맛 (구르기 · 연속 베기), B = A + 떼, C = B + 습격 터 (목업: 둘레에 울타리가 서고 물결 둘)

const DT := 1.0 / 30.0
var S := OS.get_environment("S")
var mode := OS.get_environment("MODE")
var sec := float(OS.get_environment("SEC")) if OS.get_environment("SEC") != "" else 10.0
var main: Node2D
var kills := 0
var log_lines: Array[String] = []
## C 목업: 울타리 가운데 · 반지름 · 남은 물결
var ring_at := Vector2.ZERO
var ring_r := 0.0
var waves := 0
var ring_node: Node2D


func _ready() -> void:
	HuntGround.loot_enabled = true
	HuntGround.feel = mode != "now"
	HuntGround.swarm = mode in ["B", "C"]
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	GameState.reset()
	GameState.day = 6
	GameState.hunter_unlocked = true
	GameState.first_egg_done = true
	GameState.worn[&"hunter"][&"weapon"] = &"long_sword"
	main._set_active(main.hunter)
	main.hunter.refresh_wear()
	main.enter_hunt(null, 0)
	var h: HuntGround = main.hunt
	h.loot_rng.seed = 7
	seed(7)
	if mode == "C":
		# 습격 터 목업: 떼를 치우고, 사냥꾼이 들어선 자리 둘레에 물결로 솟게 한다
		for o: WildSlime in h.slimes.duplicate():
			h.slimes.erase(o)
			o.queue_free()
		h.boss_spawned = true
		ring_node = Node2D.new()
		ring_node.z_index = 3000
		ring_node.draw.connect(_draw_ring)
		h.add_child(ring_node)
	main.hunter.position = h.map.spot("S") + Vector2(0, -60)
	hunt = h
	spawned = h.slimes.size()
	ready_done = true


var hunt: HuntGround
var ready_done := false
var t := 0.0
var spawned := 0


## Movie Maker (--write-movie --fixed-fps 30) 로 찍는다: 게임은 그대로 돌고, 봇은 키를 누른 것처럼 움직인다
func _process(delta: float) -> void:
	if not ready_done:
		return
	_bot(hunt)
	if mode == "C":
		_tick_ring(hunt)
	t += delta
	kills = spawned - hunt.slimes.size()
	log_lines.append("%d %.2f" % [kills, t])
	if t >= sec:
		ready_done = false
		var f := FileAccess.open("%s/kills.txt" % S, FileAccess.WRITE)
		f.store_string("\n".join(log_lines))
		f.close()
		print("MODE %s kills %d in %.0fs" % [mode, kills, sec])
		get_tree().quit()


## C 목업: 사냥꾼이 공터 가운데쯤 오면 울타리가 서고 둘레에서 떼가 두 물결로 솟는다
func _tick_ring(h: HuntGround) -> void:
	var feet: Vector2 = main.hunter.feet()
	if ring_r == 0.0 and h.map.spot("S").distance_to(feet) > 90.0:
		ring_at = feet + Vector2(0, -20)
		ring_r = 110.0
		waves = 2
	if ring_r > 0.0:
		var d := feet - ring_at
		if d.length() > ring_r - 10.0:
			main.hunter.position -= d.normalized() * (d.length() - (ring_r - 10.0))
		if h.slimes.is_empty() and waves > 0:
			waves -= 1
			for i in 7:
				var s := WildSlime.new()
				s.setup_zone(0)
				s.make_swarm(4)
				s.knock_mult = Config.HIT_KNOCKBACK_MULT
				s.alert = true
				s.pack_id = 99
				s.home = ring_at
				s.area = h.monster_area()
				s.terrain = h.map
				s.position = ring_at + Vector2.from_angle(TAU * i / 7.0 + waves) * (ring_r - 30.0) * Vector2(1, 0.8)
				s.ai_enabled = true
				h.add_child(s)
				h.slimes.append(s)
				spawned += 1
		elif h.slimes.is_empty() and waves == 0:
			ring_r = -1.0
	ring_node.queue_redraw()


func _draw_ring() -> void:
	if ring_r <= 0.0:
		return
	# 나무 말뚝 울타리
	for i in 28:
		var p := ring_at + Vector2.from_angle(TAU * i / 28.0) * ring_r * Vector2(1, 0.8)
		ring_node.draw_rect(Rect2(p + Vector2(-2, -12), Vector2(4, 12)), Color(0.45, 0.3, 0.18))
		ring_node.draw_rect(Rect2(p + Vector2(-2, -12), Vector2(4, 2)), Color(0.65, 0.48, 0.3))
	var font := ThemeDB.fallback_font
	var text := "습격! 물결 %d/2" % (2 - waves)
	ring_node.draw_string_outline(font, ring_at + Vector2(-40, -ring_r * 0.8 - 18), text, HORIZONTAL_ALIGNMENT_CENTER, 80, 10, 3, Color(0.1, 0, 0))
	ring_node.draw_string(font, ring_at + Vector2(-40, -ring_r * 0.8 - 18), text, HORIZONTAL_ALIGNMENT_CENTER, 80, 10, Color(1, 0.8, 0.4))


## 간단한 봇: 예고를 보면 비키거나 구르고, 가까운 몬스터에게 다가가 벤다
func _bot(h: HuntGround) -> void:
	var hunter: Character = main.hunter
	var feet := hunter.feet()
	var escape := Vector2.ZERO
	for s: WildSlime in h.slimes:
		for tg: Dictionary in s.telegraphs():
			if tg.progress < 0.45:
				continue
			if tg.kind == &"lane":
				var near := Geometry2D.get_closest_point_to_segment(feet, tg.from, tg.to)
				if near.distance_to(feet) <= tg.width / 2.0 + 6.0:
					var side: Vector2 = (tg.to - tg.from).normalized().orthogonal()
					escape += side * (1.0 if (feet - tg.from).dot(side) >= 0.0 else -1.0)
			else:
				var d: Vector2 = feet - tg.at
				if d.length() <= tg.radius + 8.0:
					escape += d.normalized() if d != Vector2.ZERO else Vector2.DOWN
	var w := Wearables.weapon()
	var hand := feet + Vector2(0, -8)
	# 닿는 몬스터가 있으면 그 무리 가운데로 벤다 (예고가 떠도 구르기가 안 되면 베기부터)
	var in_reach := h.slimes.filter(func(o: WildSlime) -> bool: return not o.airborne() and o.position.distance_to(hand) <= w.reach + w.radius - 2)
	if escape != Vector2.ZERO and h.dash(escape.normalized()):
		return
	if not in_reach.is_empty():
		var c := Vector2.ZERO
		for o: WildSlime in in_reach:
			c += o.position
		_walk(Vector2.ZERO)
		h.swing(c / in_reach.size() - hand)
		return
	if escape != Vector2.ZERO:
		_walk(escape.normalized())
		return
	var target: WildSlime = h._nearest_slime(feet)
	if target == null:
		# 습격 터 목업: 아직 울타리 전이면 위로 걸어간다
		_walk(Vector2.UP if mode == "C" and ring_r == 0.0 else Vector2.ZERO)
		return
	var dir := _path_dir(h, feet, target.position)
	# 멀면 구르며 다가간다 (하데스처럼)
	if target.position.distance_to(feet) > 100.0 and h.dash(dir):
		return
	_walk(dir)


func _walk(dir: Vector2) -> void:
	for a: String in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(a)
	if dir.x < 0.0:
		Input.action_press("move_left", -dir.x)
	if dir.x > 0.0:
		Input.action_press("move_right", dir.x)
	if dir.y < 0.0:
		Input.action_press("move_up", -dir.y)
	if dir.y > 0.0:
		Input.action_press("move_down", dir.y)


## 칸 지도 위 BFS로 다음 칸 방향 (tests/playthrough.gd 와 같음)
func _path_dir(h: HuntGround, from: Vector2, to: Vector2) -> Vector2:
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
