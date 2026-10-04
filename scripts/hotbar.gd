class_name Hotbar
extends RefCounted
## 사냥터 단축키 바 (2026-10-04 백로그 11, 사용자: "WoW · 로스트아크처럼 쿨타임 표시").
## 화면 아래 가운데에 칸을 늘어놓는다: 왼클릭 방식 (Q/E) · 오른클릭 큰 스킬 · Space 구르기 · R 돌격 · 1 물약,
## 그 옆에 저절로 도는 것 (크리처 방패 · 냄비뚜껑) 은 작은 칸으로.
## 쿨이 돌면 칸이 어두워졌다가 시계 방향으로 걷히고 남은 초가 뜬다. 다 돌면 칸 테두리가 반짝,
## 쿨 중에 누르면 칸이 붉게 깜빡인다. HuntGround 가 하나 들고 tick · draw 를 부른다.

const SLOT := 30.0
const SMALL := 20.0
const GAP := 3.0
## 아래 알림 두 줄 바로 위
const BOTTOM := 326.0
const READY_FLASH := 0.35
const DENY_FLASH := 0.25

const FRAME := Color(0.2, 0.13, 0.1, 0.92)
const SHADE := Color(0.05, 0.03, 0.03, 0.62)
const GOLD := Color(1.0, 0.85, 0.35)

## 칸 id → 이번 쿨의 처음 길이 (돌기 시작할 때 잡아 둔다)
var _full := {}
## 칸 id → 남은 반짝 시간
var _ready := {}
var _deny := {}


## 쿨 중에 눌렀다 (칸이 붉게 깜빡)
func deny(id: StringName) -> void:
	_deny[id] = DENY_FLASH


## 지금 보일 칸들. {id, key, label, tint, cd, small, icon, count, off}
static func slots(h: HuntGround) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var wk: StringName = Wearables.weapon().kind
	var left := HunterSkills.left_mode(wk)
	var many := HunterSkills.modes_for(wk).size() > 1
	out.append({id = &"left", key = "Q/E" if many else "클릭", label = short_name(left), tint = tint_of(left, wk), cd = 0.0})
	var rs := HunterSkills.right_skill(wk)
	if rs != &"":
		out.append({id = &"right", key = "우클릭", label = short_name(rs), tint = tint_of(rs, wk), cd = h.right_cd})
	if HuntGround.feel:
		out.append({id = &"dash", key = "Space", label = "구르기", tint = Color(0.55, 0.5, 0.45), cd = h.dash_cd})
	if HunterSkills.rank(&"charge_order") > 0:
		out.append({id = &"order", key = "R", label = "돌격", tint = tint_of(&"charge_order", wk), cd = h.order_cd, off = h.companion == null})
	out.append({id = &"potion", key = "1", label = "", icon = UiSkin.Icon.POTION, count = GameState.potions, tint = Color(0.6, 0.3, 0.3), cd = 0.0, off = GameState.potions <= 0})
	if h.companion != null and HunterSkills.rank(&"creature_guard") > 0:
		out.append({id = &"guard", key = "", label = "방패", tint = tint_of(&"creature_guard", wk), cd = h.guard_cd, small = true})
	if h.companion != null and h.companion.data.species.lid:
		out.append({id = &"lid", key = "", label = "뚜껑", tint = Color(0.55, 0.6, 0.5), cd = h.lid_cd, small = true})
	return out


## 칸에 쓸 짧은 이름 (세 글자 안)
static func short_name(id: StringName) -> String:
	if id == &"":
		return "기본"
	var n := HunterSkills.skill_name(id)
	return n.replace(" ", "").left(3) if n.length() > 3 else n


static func tint_of(id: StringName, weapon: StringName) -> Color:
	var f := HunterSkills.find(id)
	if not f.is_empty():
		return f.tree.color
	return {&"melee": Color(0.85, 0.45, 0.35), &"bow": Color(0.4, 0.65, 0.35), &"staff": Color(0.4, 0.55, 0.9)}.get(weapon, Color(0.6, 0.55, 0.5))


func tick(delta: float, h: HuntGround) -> void:
	for s in slots(h):
		var id: StringName = s.id
		var cd: float = s.cd
		if cd > 0.0:
			if cd > _full.get(id, 0.0):
				_full[id] = cd
		elif _full.get(id, 0.0) > 0.0:
			_full[id] = 0.0
			_ready[id] = READY_FLASH
	for d: Dictionary in [_ready, _deny]:
		for id: StringName in d.keys():
			d[id] -= delta
			if d[id] <= 0.0:
				d.erase(id)


## 바 전체 칸 (가운데 정렬). 칸 id → Rect2
static func layout(list: Array[Dictionary]) -> Dictionary:
	var w := 0.0
	for s in list:
		w += (SMALL if s.get("small", false) else SLOT) + GAP
	w -= GAP
	var x := 320.0 - w / 2.0
	var out := {}
	for s in list:
		var sz := SMALL if s.get("small", false) else SLOT
		out[s.id] = Rect2(x, BOTTOM - sz, sz, sz)
		x += sz + GAP
	return out


## 남은 쿨 비율 (0 = 다 돔, 1 = 막 쓰기 시작)
func frac(id: StringName, cd: float) -> float:
	var full: float = _full.get(id, 0.0)
	return clampf(cd / full, 0.0, 1.0) if full > 0.0 and cd > 0.0 else 0.0


func draw(ci: CanvasItem, h: HuntGround) -> void:
	var font := ThemeDB.fallback_font
	var list := slots(h)
	var rects := layout(list)
	# 사냥꾼이 바 뒤에 있으면 흐리게
	var a := 1.0
	var all: Rect2 = rects[list[0].id]
	for s in list:
		all = all.merge(rects[s.id])
	if h.hunter != null and all.grow(6).has_point(h.hunter.get_global_transform_with_canvas().origin):
		a = 0.4
	for s in list:
		var r: Rect2 = rects[s.id]
		var small: bool = s.get("small", false)
		var cd: float = s.cd
		var off: bool = s.get("off", false)
		# 바탕: 트리 색 칸 + 먹색 테두리
		ci.draw_rect(r.grow(1), Color(FRAME, FRAME.a * a))
		var tint: Color = s.tint
		if off:
			tint = tint.lerp(Color(0.35, 0.35, 0.35), 0.7)
		ci.draw_rect(r, Color(tint.darkened(0.35), a))
		ci.draw_rect(Rect2(r.position + Vector2(1, 1), r.size - Vector2(2, 2)), Color(tint, a), false, 1.0)
		var f := frac(s.id, cd)
		if s.has("icon"):
			UiSkin.draw_icon(ci, s.icon, r.get_center() - Vector2(6, 7))
			ci.draw_string_outline(font, Vector2(r.position.x, r.end.y - 2), "%d" % s.count, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 2, 9, 3, Color(0, 0, 0, a))
			ci.draw_string(font, Vector2(r.position.x, r.end.y - 2), "%d" % s.count, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 2, 9, Color(1, 1, 1, a))
		elif f <= 0.0:
			# 쿨 중엔 이름 대신 남은 초만 (겹치지 않게)
			var fs := 9 if small or s.label.length() >= 3 else 10
			var ty := r.get_center().y + (4 if small or s.key == "" else 8)
			ci.draw_string_outline(font, Vector2(r.position.x, ty), s.label, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, fs, 3, Color(0.1, 0.06, 0.04, a))
			ci.draw_string(font, Vector2(r.position.x, ty), s.label, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, fs, Color(1, 0.97, 0.88, a))
		# 쿨: 어둠 + 남은 초
		if f > 0.0:
			_draw_shade(ci, r, f, a)
			var t := "%.1f" % (ceilf(cd * 10.0) / 10.0) if cd < 3.0 else "%d" % ceili(cd)
			var big := 10 if not small else 9
			var cy := r.get_center().y + (4 if small or s.key == "" else 8)
			ci.draw_string_outline(font, Vector2(r.position.x, cy), t, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, big, 3, Color(0, 0, 0, a))
			ci.draw_string(font, Vector2(r.position.x, cy), t, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, big, Color(GOLD, a))
		# 다 돌았음: 금빛 테두리 반짝
		if _ready.has(s.id):
			var k: float = _ready[s.id] / READY_FLASH
			ci.draw_rect(r.grow(1), Color(GOLD, k * a), false, 2.0)
			ci.draw_rect(r, Color(1, 1, 0.8, 0.35 * k * a))
		if _deny.has(s.id):
			ci.draw_rect(r, Color(0.9, 0.15, 0.1, 0.45 * _deny[s.id] / DENY_FLASH * a))
		# 단축키 (왼쪽 위)
		if s.key != "":
			ci.draw_string_outline(font, r.position + Vector2(1, 8), s.key, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, 2, Color(0, 0, 0, 0.85 * a))
			ci.draw_string(font, r.position + Vector2(1, 8), s.key, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.95, 0.95, 0.85, a))


## 남은 비율 f 만큼 칸을 어둡게: 12시에서 시작해 시계 방향으로 걷힌다 (남은 부분 = 바늘 → 12시)
static func _draw_shade(ci: CanvasItem, r: Rect2, f: float, a: float) -> void:
	var c := r.get_center()
	var rad := r.size.length()
	var start := -PI / 2 + TAU * (1.0 - f)
	# 네모 칸에 맞춘 부채꼴: 바늘 각과 끝 각 사이에 든 칸 모서리를 꼭짓점으로 넣는다
	var angs: Array[float] = [start, start + TAU * f]
	for k in 4:
		var corner := -PI * 3 / 4 + PI / 2 * k
		while corner < start:
			corner += TAU
		if corner < start + TAU * f:
			angs.append(corner)
	angs.sort()
	var pts := PackedVector2Array([c])
	for ang in angs:
		pts.append(_clip_ray(c, c + Vector2(cos(ang), sin(ang)) * rad, r))
	ci.draw_colored_polygon(pts, Color(SHADE, SHADE.a * a))
	# 바늘
	ci.draw_line(c, pts[1], Color(GOLD, 0.6 * a), 1.0)


## c 에서 p 쪽으로 뻗은 선이 칸 r 테두리와 만나는 점 (p 가 칸 안이면 그대로)
static func _clip_ray(c: Vector2, p: Vector2, r: Rect2) -> Vector2:
	if r.has_point(p) or p == c:
		return p
	var d := p - c
	var t := 1.0
	if d.x != 0.0:
		t = minf(t, ((r.end.x if d.x > 0 else r.position.x) - c.x) / d.x)
	if d.y != 0.0:
		t = minf(t, ((r.end.y if d.y > 0 else r.position.y) - c.y) / d.y)
	return c + d * t
