class_name Forage
extends Node2D
## 들나물 캐기 (2026-09-29 사용자 선택 A, 초반 며칠 할 일): 아침마다 밭 밖 풀밭에 냉이·쑥·달래가 몇 포기 돋는다.
## 농부가 가까이서 F로 캐고, 마을 공급함에 진열하면 밤사이 팔린다. 그림은 임시 (코드로 그림).

## 돋은 들나물: 칸 → 종류 번호 (Config.HERB_NAMES)
var herbs: Dictionary[Vector2i, int] = {}


func _ready() -> void:
	# 바닥(밭) 바로 위, 캐릭터·오브젝트보다 항상 뒤
	z_index = -999


## 아침마다 새로 돋는다. 어제 캐지 않은 것은 시들어 없어진다.
func sprout(rng: RandomNumberGenerator) -> void:
	herbs.clear()
	var spots := Config.HERB_SPOTS.duplicate()
	for i in spots.size():
		var j := rng.randi_range(i, spots.size() - 1)
		var t: Vector2i = spots[i]
		spots[i] = spots[j]
		spots[j] = t
	var n := rng.randi_range(Config.HERBS_PER_DAY.x, Config.HERBS_PER_DAY.y)
	for i in mini(n, spots.size()):
		herbs[spots[i]] = rng.randi_range(0, Config.HERB_NAMES.size() - 1)
	queue_redraw()


## pos(발) 에서 가장 가까운, 닿는 거리 안의 들나물 칸. 없으면 null.
func nearest(pos: Vector2) -> Variant:
	var best: Variant = null
	var best_d := Config.INTERACT_DISTANCE
	for cell: Vector2i in herbs:
		var d := pos.distance_to(Farm.center_of(cell))
		if d <= best_d:
			best_d = d
			best = cell
	return best


## 캔다. 종류 이름을 돌려준다.
func pick(cell: Vector2i) -> String:
	var kind: int = herbs[cell]
	herbs.erase(cell)
	queue_redraw()
	return Config.HERB_NAMES[kind]


## 이름 끝 글자에 받침이 있으면 "을", 없으면 "를" (냉이를 · 쑥을 · 달래를)
static func object_particle(word: String) -> String:
	var code := word.unicode_at(word.length() - 1) - 0xAC00
	return "을" if code >= 0 and code < 11172 and code % 28 != 0 else "를"


func _draw() -> void:
	for cell: Vector2i in herbs:
		_draw_herb(Farm.center_of(cell) + Vector2(0, 2), herbs[cell])


## 한 포기 (임시 그림): 0 냉이 흰 꽃 · 1 쑥 회녹색 잎 · 2 달래 가는 잎 + 흰 알뿌리
func _draw_herb(at: Vector2, kind: int) -> void:
	draw_set_transform(at, 0, Vector2(1.5, 1.5))
	draw_circle(Vector2(0, 3), 6, Color(0.45, 0.32, 0.2))
	draw_circle(Vector2(0, 3), 6, Color(0.2, 0.12, 0.06), false, 1.0)
	match kind:
		0:
			for a in 6:
				draw_line(Vector2.ZERO, Vector2.from_angle(a * TAU / 6) * 5, Color(0.15, 0.6, 0.15), 2.0)
			for p: Vector2 in [Vector2(-2, -5), Vector2(2, -6), Vector2(0, -8)]:
				draw_circle(p, 1.6, Color(1, 1, 0.95))
		1:
			for a in 5:
				draw_line(Vector2(0, 3), Vector2.from_angle(-PI / 2 + (a - 2) * 0.6) * 7, Color(0.62, 0.82, 0.62), 3.0)
		_:
			for a in 4:
				draw_line(Vector2(0, 3), Vector2(-4 + a * 2.5, -8), Color(0.2, 0.75, 0.2), 1.5)
			draw_circle(Vector2(0, 4), 2.2, Color(0.95, 0.92, 0.85))
	draw_set_transform(Vector2.ZERO)
