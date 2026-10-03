class_name SiteWork
extends RefCounted
## 시설 복구: 재료 모으기 → 크리처 공사 (2026-10-03 백로그 4번, 사용자 안). 값은 Config.SITE_TASKS.
## 터가 드러나면 대장 재료가 그 막 두 구역 일반 몬스터에서도 나온다. 재료 · 돈 · 무를 다 모아 터에서 F → 공사 시작.
## 그 뒤 R "터 공사" 를 맡긴 크리처가 하루 Config.BUILD_CAP 번씩 공사해서 days 일을 채우면 다음 날 아침 시설이 선다.
## 상태: GameState.site_work (시설 id → 공사한 수, 이 키가 있으면 공사 중), GameState.build_today (오늘 공사 수).

## 터가 드러나는 순서 (공사 크리처는 이 순서로 공사 중인 터부터 간다)
const ORDER: Array[StringName] = [&"forge", &"yak", &"barn", &"naru", &"hall"]
const NAMES := {&"forge": "대장간", &"yak": "약방", &"barn": "축사", &"naru": "나루터", &"hall": "마을회관"}
const MASTERS := {&"forge": "대장장이", &"yak": "연금술사", &"barn": "목축인", &"naru": "뱃사공", &"hall": "이장"}


static func task(fac: StringName) -> Dictionary:
	return Config.SITE_TASKS[fac]


## 0 = 없음, 1 = 무너진 터 (공사 중 포함), 2 = 고침
static func state(fac: StringName) -> int:
	return GameState.get(String(fac) + "_state")


static func building(fac: StringName) -> bool:
	return state(fac) == 1 and GameState.site_work.has(fac)


static func work(fac: StringName) -> int:
	return GameState.site_work.get(fac, 0)


## 공사에 드는 수 (하루 BUILD_CAP 번 x days 일)
static func work_need(fac: StringName) -> int:
	return task(fac).days * Config.BUILD_CAP


## 공사가 다 됐는지 (다음 날 아침 시설이 선다)
static func ready(fac: StringName) -> bool:
	return building(fac) and work(fac) >= work_need(fac)


## 남은 공사 날 (크리처가 하루 BUILD_CAP 번을 다 채운다고 칠 때)
static func days_left(fac: StringName) -> int:
	return ceili(float(work_need(fac) - work(fac)) / Config.BUILD_CAP)


static func material_name(fac: StringName) -> String:
	match fac:
		&"forge":
			return Config.BOSS_MATERIAL_NAME
		&"yak":
			return Config.BOSS_MATERIAL2_NAME
		&"barn":
			return Config.BOSS_MATERIAL3_NAME
		&"naru":
			return Config.BOSS_MATERIAL4_NAME
	return Config.BOSS_MATERIAL5_NAME


## 터 배지 · 윗줄 ("사금 덩이 3/12", "공사 2/7일")
static func badge(fac: StringName) -> String:
	if not building(fac):
		var t := task(fac)
		return "%s %d/%d" % [material_name(fac), int(GameState.get(t.material)), t.need]
	if ready(fac):
		return "공사 끝 · 내일 아침"
	return "공사 %d/%d일" % [work(fac) / Config.BUILD_CAP, task(fac).days]


static func status_text(fac: StringName) -> String:
	return "%s 터 %s" % [NAMES[fac], badge(fac)]


static func zone_names(fac: StringName) -> String:
	return " · ".join(task(fac).zones.map(func(z: int) -> String: return Config.HUNT_ZONES[z].name))


## 복구 창 아래 줄: 모을 것 (공사 전) 또는 공사 진척. costs = [이름, 가진 것, 필요한 것] 줄들
static func lines(fac: StringName, costs: Array, after: String) -> Array[String]:
	var out: Array[String] = []
	if building(fac):
		out.append("  크리처 터 공사 (R)  %d / %d일 %s" % [mini(work(fac), work_need(fac)) / Config.BUILD_CAP, task(fac).days, "✔" if ready(fac) else ""])
		out.append("  오늘 공사 %d / %d번" % [GameState.build_today, Config.BUILD_CAP])
		out.append(("공사 끝! 내일 아침 문을 연다 → %s" if ready(fac) else "공사가 다 되면 다음 날 아침 문을 연다 → %s") % after)
		return out
	for c: Array in costs:
		out.append("  %s  %d / %d %s" % [c[0], mini(c[1], c[2]), c[2], "✔" if c[1] >= c[2] else ""])
	out.append("%s은(는) %s 일반 몬스터도 가끔 떨어뜨린다." % [material_name(fac), zone_names(fac)])
	out.append("다 모으면 공사 시작 → 크리처에게 R 터 공사 (%d일) → %s" % [task(fac).days, after])
	return out


## 선택창 줄 (&"restore" 자리)
static func option_text(fac: StringName, can_pay: bool) -> String:
	if not building(fac):
		return "공사 시작 (재료를 냄)" if can_pay else "공사 시작 (아직 모자람)"
	return "공사 끝 (내일 아침 문을 엶)" if ready(fac) else "공사 중 (남은 %d일, 크리처 R 터 공사)" % days_left(fac)


## 공사 시작 표시 (값은 각 시설이 낸다)
static func start(fac: StringName) -> void:
	GameState.site_work[fac] = 0
	GameState.touch()


static func start_text(fac: StringName) -> String:
	return "%s 공사를 시작했다! 크리처에게 R 로 터 공사를 맡기자 (하루 %d번 · %d일)." % [NAMES[fac], Config.BUILD_CAP, task(fac).days]


## 시설이 서면 공사 기록을 지운다
static func finish(fac: StringName) -> void:
	GameState.site_work.erase(fac)


## 테스트 · 시작 지점: 공사까지 다 끝난 것으로
static func fill(fac: StringName) -> void:
	GameState.site_work[fac] = work_need(fac)


## 사냥터에서 일반 몬스터를 쓰러뜨렸을 때: 그 구역이 터의 재료 구역이면 drop 확률로 대장 재료 하나.
## 공사를 시작했거나 다 모은 터는 더 안 준다. 얻은 것 글 ("사금 덩이 (3/12)") 을 돌려준다 (없으면 "").
static func mob_drop(zone: int, roll: float) -> String:
	for fac in ORDER:
		var t := task(fac)
		if state(fac) != 1 or building(fac) or not zone in t.zones or int(GameState.get(t.material)) >= t.need:
			continue
		if roll < t.drop:
			GameState.set(t.material, int(GameState.get(t.material)) + 1)
			return "%s (%d/%d)" % [material_name(fac), int(GameState.get(t.material)), t.need]
	return ""


## 크리처가 공사하러 갈 터 (공사 중이고 덜 된 첫 시설). 없으면 &"".
static func build_site() -> StringName:
	for fac in ORDER:
		if building(fac) and work(fac) < work_need(fac):
			return fac
	return &""


static func build_open() -> bool:
	return build_site() != &"" and GameState.build_today < Config.BUILD_CAP


## 공사 한 번 (크리처가 터에 닿았을 때)
static func build_once() -> bool:
	if not build_open():
		return false
	var fac := build_site()
	GameState.site_work[fac] = work(fac) + 1
	GameState.build_today += 1
	GameState.touch()
	return true


static func rect(fac: StringName) -> Rect2i:
	match fac:
		&"forge":
			return Config.FORGE_RECT
		&"yak":
			return Config.YAK_RECT
		&"barn":
			return Config.BARN_RECT
		&"naru":
			return Config.NARU_RECT
	return Config.HALL_RECT


## 크리처가 서서 공사하는 칸 (터 왼쪽 아래 옆 칸)
static func build_spot() -> Vector2i:
	var f := build_site()
	var r := rect(f if f != &"" else &"forge")
	return Vector2i(r.position.x - 1, r.end.y - 1)
