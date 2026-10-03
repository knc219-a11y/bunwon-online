class_name Crops
extends RefCounted
## 밭 작물 (2026-10-03 백로그 5번 "농사가 무만이라 재미없음"). 값은 Config.CROPS.
## 무 · 감자 · 고추 · 배추. 막 대장을 처음 쓰러뜨린 다음 아침 그 땅 씨앗을 얻어 열리고,
## 공급함 "밭 작물 · 씨앗 ▶" 에서 밭 구역마다 심을 작물을 정한다 (농부 · 크리처 모두 그 구역 작물을 심는다).

const ORDER: Array[StringName] = [&"radish", &"potato", &"pepper", &"cabbage"]


static func info(kind: StringName) -> Dictionary:
	return Config.CROPS.get(kind, Config.CROPS[&"radish"])


static func display_name(kind: StringName) -> String:
	return info(kind).name


## 심을 수 있는 작물 (무 + 씨앗을 얻은 것), ORDER 순
static func unlocked() -> Array[StringName]:
	var out: Array[StringName] = []
	for k in ORDER:
		if k == &"radish" or k in GameState.crop_unlocked:
			out.append(k)
	return out


static func seeds(kind: StringName) -> int:
	return int(GameState.get(info(kind).seed_var))


static func add_seeds(kind: StringName, n: int) -> void:
	GameState.set(info(kind).seed_var, seeds(kind) + n)


static func held(kind: StringName) -> int:
	return int(GameState.get(info(kind).held))


static func add_held(kind: StringName, n: int) -> void:
	GameState.set(info(kind).held, held(kind) + n)


## cell 이 든 밭 구역 번호. 밭 밖이면 -1.
static func plot_of(cell: Vector2i) -> int:
	for i in Config.FIELD_PLOTS.size():
		if Config.FIELD_PLOTS[i].has_point(cell):
			return i
	return -1


## 그 구역에 심을 작물 (정하지 않았으면 무)
static func plot_kind(i: int) -> StringName:
	if i < 0 or i >= GameState.plot_crops.size() or GameState.plot_crops[i] == &"":
		return &"radish"
	return GameState.plot_crops[i]


static func kind_at(cell: Vector2i) -> StringName:
	return plot_kind(plot_of(cell))


static func set_plot(i: int, kind: StringName) -> void:
	while GameState.plot_crops.size() <= i:
		GameState.plot_crops.append(&"radish")
	GameState.plot_crops[i] = kind
	GameState.touch()


## 그 구역 작물을 열린 작물 중 다음 것으로 바꾼다
static func cycle_plot(i: int) -> StringName:
	var list := unlocked()
	var next := list[(list.find(plot_kind(i)) + 1) % list.size()]
	set_plot(i, next)
	return next


## 아침: 대장을 처음 쓰러뜨린 땅의 씨앗을 연다. 아침 카드 줄들.
static func morning_unlocks() -> Array[String]:
	var lines: Array[String] = []
	for k in ORDER:
		var zone: int = info(k).zone
		if zone < 0 or k in GameState.crop_unlocked or not zone in GameState.bosses_beaten:
			continue
		GameState.crop_unlocked.append(k)
		add_seeds(k, Config.CROP_UNLOCK_SEEDS)
		lines.append("%s 대장이 물러간 땅에서 %s 씨앗 %d개를 주웠다! (%s) 공급함 \"밭 작물 · 씨앗\" 에서 구역마다 심을 작물을 고른다." % [
			Config.HUNT_ZONES[zone].name, display_name(k), Config.CROP_UNLOCK_SEEDS, info(k).note])
	return lines


## 가진 작물 (무 포함) 을 모두 공급함에 진열한다. 진열한 수.
static func display_all() -> int:
	var n := 0
	for k in ORDER:
		var h := held(k)
		if h <= 0:
			continue
		n += h
		if k == &"radish":
			GameState.displayed_crops += h
		else:
			GameState.displayed_harvest[k] = int(GameState.displayed_harvest.get(k, 0)) + h
		add_held(k, -h)
	return n


static func held_total() -> int:
	var n := 0
	for k in ORDER:
		n += held(k)
	return n


static func held_value() -> int:
	var v := 0
	for k in ORDER:
		v += held(k) * int(info(k).price)
	return v


## "무 3 · 감자 4" (가진 것만)
static func held_text() -> String:
	var parts: Array[String] = []
	for k in ORDER:
		if held(k) > 0:
			parts.append("%s %d" % [display_name(k), held(k)])
	return " · ".join(parts)


## 밤사이 팔린 무 말고 작물. 아침 카드 줄들 (무는 main 이 따로 적는다).
static func sell_displayed() -> Array[String]:
	var lines: Array[String] = []
	for k in ORDER:
		var n := int(GameState.displayed_harvest.get(k, 0))
		if n <= 0:
			continue
		var earned := n * int(info(k).price)
		GameState.money += earned
		lines.append("공급함의 %s %d개가 팔렸다. 돈통에 +%d원" % [display_name(k), n, earned])
	GameState.displayed_harvest = {}
	return lines


# --- 공급함 "밭 작물 · 씨앗" 선택창 ---------------------------------------------

static func options() -> Array[StringName]:
	var out: Array[StringName] = []
	for i in GameState.open_plots:
		out.append(StringName("plot_%d" % i))
	for k in unlocked():
		if k != &"radish":
			out.append(StringName("seeds_%s" % k))
	out.append(&"back")
	return out


static func option_text(id: StringName) -> String:
	var s := String(id)
	if s.begins_with("plot_"):
		var i := s.trim_prefix("plot_").to_int()
		var k := plot_kind(i)
		return "%s: %s (씨앗 %d) ▶ 바꾸기" % [Config.FIELD_PLOT_NAMES[i], display_name(k), seeds(k)]
	if s.begins_with("seeds_"):
		var k := StringName(s.trim_prefix("seeds_"))
		var d := info(k)
		return "%s 씨앗 %d개 사기 (%d원, 가진 씨앗 %d) · %s" % [d.name, d.pack, d.pack_price, seeds(k), d.note]
	return "뒤로"


## 한 가지 한다. 성공하면 true.
static func act(id: StringName) -> bool:
	var s := String(id)
	if s.begins_with("plot_"):
		var i := s.trim_prefix("plot_").to_int()
		var k := cycle_plot(i)
		GameState.notify("%s에는 이제 %s을(를) 심는다 (%s). 이미 심은 칸은 그대로 자란다." % [Config.FIELD_PLOT_NAMES[i], display_name(k), info(k).note])
		return true
	if s.begins_with("seeds_"):
		return buy_seeds(StringName(s.trim_prefix("seeds_")))
	return false


static func buy_seeds(kind: StringName) -> bool:
	var d := info(kind)
	if kind != &"radish" and not kind in GameState.crop_unlocked:
		return false
	if GameState.money < int(d.pack_price):
		GameState.notify("돈이 모자라다. %s 씨앗 %d개에 %d원 (가진 돈 %d원)." % [d.name, d.pack, d.pack_price, GameState.money])
		return false
	GameState.money -= int(d.pack_price)
	add_seeds(kind, int(d.pack))
	GameState.notify("%s 씨앗 %d개를 샀다. -%d원" % [d.name, d.pack, d.pack_price])
	return true
