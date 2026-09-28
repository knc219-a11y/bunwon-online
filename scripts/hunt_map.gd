class_name HuntMap
extends RefCounted
## 화면보다 넓은 사냥터의 칸 지도 (2026-09-28 사용자 선택 C. 넓은 맵 + 카메라).
## data/hunt_maps/<이름>.txt 한 글자 = 한 칸 (24px). 글자 뜻은 tools/make_hunt_maps.py 맨 위 설명과 같다.
## 막힘 · 여울 느려짐 · 몬스터가 설 수 있는 곳을 칸으로 판정한다. 바닥 그림은 같은 지도로 만든 PNG.

const T := Config.TILE
## 사냥꾼이 못 들어가는 칸: 깊은 물 · 바위 · 덤불 · 나무
const HUNTER_BLOCK := "~RBT"
## 몬스터가 못 들어가는 칸: 위 + 징검다리 (몬스터는 냇물을 여울로만 건넌다)
const MONSTER_BLOCK := "~RBTo"

var rows: PackedStringArray = []
var size := Vector2i.ZERO
var ground: Texture2D


static func load_map(id: String) -> HuntMap:
	var m := HuntMap.new()
	var text := FileAccess.get_file_as_string("res://data/hunt_maps/%s.txt" % id)
	for line in text.split("\n"):
		if line.strip_edges() != "":
			m.rows.append(line.strip_edges())
	m.size = Vector2i(m.rows[0].length(), m.rows.size())
	m.ground = load("res://assets/hunt/%s_ground.png" % id)
	return m


## 맵 전체 크기 (px)
func pixel_size() -> Vector2:
	return Vector2(size * T)


func at(c: Vector2i) -> String:
	if c.x < 0 or c.y < 0 or c.x >= size.x or c.y >= size.y:
		return "T"
	return rows[c.y][c.x]


func at_point(p: Vector2) -> String:
	return at(Vector2i(floori(p.x / T), floori(p.y / T)))


## 이 글자가 있는 칸들 (칸 가운데, px)
func find(ch: String) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for y in size.y:
		for x in size.x:
			if rows[y][x] == ch:
				out.append(Vector2(x * T + T / 2.0, y * T + T / 2.0))
	return out


## 하나뿐인 표식 자리 (칸 가운데, px)
func spot(ch: String) -> Vector2:
	var all := find(ch)
	return all[0] if not all.is_empty() else pixel_size() / 2


## 사냥꾼 발밑 상자가 막힌 칸에 닿지 않는지
func is_free(r: Rect2) -> bool:
	for p in [r.position, Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), r.end]:
		if HUNTER_BLOCK.contains(at_point(p)):
			return false
	return true


## 몬스터가 이 자리에 설 수 있는지
func monster_ok(p: Vector2) -> bool:
	return not MONSTER_BLOCK.contains(at_point(p))


## 걷기 빠르기 배율 (여울은 느려짐)
func speed_at(p: Vector2) -> float:
	return Config.HUNT_FORD_SPEED if at_point(p) == "=" else 1.0
