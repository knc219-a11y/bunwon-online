class_name Forage
extends Node2D
## 들나물 캐기 (2026-09-29 사용자 선택 A, 초반 며칠 할 일): 아침마다 밭 밖 풀밭에 냉이·쑥·달래가 몇 포기 돋는다.
## 농부가 가까이서 F로 캐고, 마을 공급함에 진열하면 밤사이 팔린다. 그림은 assets/props/forage.png.
## 크리처 채집 (2026-09-29 사용자 선택 B): 채집 크리처가 캐서 바로 진열한다. 땅속 도라지 뿌리, 물 준 풀밭도 여기서 관리.

## 돋은 들나물: 칸 → 종류 번호 (Config.HERB_NAMES)
var herbs: Dictionary[Vector2i, int] = {}
## 땅속 도라지 뿌리 (2026-09-29 사용자 선택 B): 손으로는 못 캐고 땅속성 채집 크리처만 캔다
var roots: Dictionary[Vector2i, bool] = {}
## 오늘 물속성 채집 크리처가 물 준 풀밭 칸. 다음 날 아침 들나물이 그만큼 (최대 Config.HERB_WATER_BONUS_MAX) 더 돋는다.
var watered: Dictionary[Vector2i, bool] = {}
## 채집 크리처가 가는 중인 칸 (둘이 같은 칸으로 가지 않게)
var claimed: Dictionary[Vector2i, bool] = {}
## 오늘 아침 물 덕분에 더 돋은 포기 수 (아침 카드에 쓴다)
var bonus_today := 0
## 건물이 들어선 곳 (2026-09-29 대장간 터 · 고물 더미). 여기에는 나물 · 뿌리가 돋지 않는다.
var blocked: Array[Rect2i] = []


func _ready() -> void:
	# 바닥(밭) 바로 위, 캐릭터·오브젝트보다 항상 뒤
	z_index = -999


## 아침마다 새로 돋는다. 어제 캐지 않은 것은 시들어 없어진다.
## 물 준 풀밭이 있으면 그 칸부터 먼저 돋고 포기 수가 는다. 도라지 뿌리도 새로 든다.
func sprout(rng: RandomNumberGenerator) -> void:
	herbs.clear()
	claimed.clear()
	var spots := _shuffled(_open_spots(Config.HERB_SPOTS), rng)
	# 물 준 칸을 앞으로
	spots.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return watered.has(a) and not watered.has(b))
	bonus_today = mini(watered.size(), Config.HERB_WATER_BONUS_MAX)
	watered.clear()
	var n := rng.randi_range(Config.HERBS_PER_DAY.x, Config.HERBS_PER_DAY.y) + bonus_today
	for i in mini(n, spots.size()):
		herbs[spots[i]] = rng.randi_range(0, Config.HERB_NAMES.size() - 1)
	roots.clear()
	var root_spots := _shuffled(_open_spots(Config.ROOT_SPOTS), rng)
	for i in mini(rng.randi_range(Config.ROOTS_PER_DAY.x, Config.ROOTS_PER_DAY.y), root_spots.size()):
		roots[root_spots[i]] = true
	queue_redraw()


## 건물이 들어선 자리 (rect) 는 앞으로 쓰지 않는다. 지금 돋아 있는 것도 걷어 낸다.
func block(rect: Rect2i) -> void:
	blocked.append(rect)
	for c: Vector2i in herbs.keys():
		if rect.has_point(c):
			herbs.erase(c)
	for c: Vector2i in roots.keys():
		if rect.has_point(c):
			roots.erase(c)
	queue_redraw()


func _open_spots(from: Array[Vector2i]) -> Array[Vector2i]:
	if blocked.is_empty():
		return from
	var out: Array[Vector2i] = []
	out.assign(from.filter(func(c: Vector2i) -> bool: return not blocked.any(func(r: Rect2i) -> bool: return r.has_point(c))))
	return out


func _shuffled(from: Array[Vector2i], rng: RandomNumberGenerator) -> Array[Vector2i]:
	var spots := from.duplicate()
	for i in spots.size():
		var j := rng.randi_range(i, spots.size() - 1)
		var t: Vector2i = spots[i]
		spots[i] = spots[j]
		spots[j] = t
	return spots


## 채집 크리처가 갈 칸: pos 에서 가장 가까운 들나물 (dig_roots 면 도라지 뿌리도). 다른 크리처가 가는 칸은 뺀다. 없으면 null.
func nearest_target(pos: Vector2, dig_roots: bool) -> Variant:
	var best: Variant = null
	var best_d := INF
	var cells: Array[Vector2i] = herbs.keys()
	if dig_roots:
		cells.append_array(roots.keys())
	for cell in cells:
		if claimed.has(cell):
			continue
		var d := pos.distance_to(Farm.center_of(cell))
		if d < best_d:
			best_d = d
			best = cell
	return best


## 손이 닿는 거리 안의 도라지 뿌리 칸 (농부에게 "손으로는 못 캔다"고 알려 줄 때). 없으면 null.
func nearest_root(pos: Vector2) -> Variant:
	for cell: Vector2i in roots:
		if pos.distance_to(Farm.center_of(cell)) <= Config.INTERACT_DISTANCE:
			return cell
	return null


## 도라지 뿌리를 캔다
func dig_root(cell: Vector2i) -> void:
	roots.erase(cell)
	claimed.erase(cell)
	queue_redraw()


## 풀밭 칸에 물을 준다 (물속성 채집). 다음 날 아침 들나물이 더 돋는다.
func water(cell: Vector2i) -> void:
	watered[cell] = true
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
	claimed.erase(cell)
	queue_redraw()
	return Config.HERB_NAMES[kind]


## 이름 끝 글자에 받침이 있으면 "을", 없으면 "를" (냉이를 · 쑥을 · 달래를)
static func object_particle(word: String) -> String:
	var code := word.unicode_at(word.length() - 1) - 0xAC00
	return "을" if code >= 0 and code < 11172 and code % 28 != 0 else "를"


const SHEET := preload("res://assets/props/forage.png")
## forage.png 칸: 0 냉이 · 1 쑥 · 2 달래 · 3 도라지 싹 · 4 물 준 풀밭 (tools/make_polish_sprites.py)
const ROOT_FRAME := 3
const WET_FRAME := 4


func _draw() -> void:
	for cell: Vector2i in watered:
		_frame(cell, WET_FRAME)
	for cell: Vector2i in roots:
		_frame(cell, ROOT_FRAME)
	for cell: Vector2i in herbs:
		_frame(cell, herbs[cell])


func _frame(cell: Vector2i, i: int) -> void:
	var t := Config.TILE
	draw_texture_rect_region(SHEET, Rect2(Vector2(cell * t), Vector2(t, t)), Rect2(i * 24, 0, 24, 24))
