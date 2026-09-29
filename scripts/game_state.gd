extends Node
## 전역 상태 (autoload: GameState). 인벤토리, 날짜, 마을 공급함.

signal changed
signal message(text: String)

var day := 1
## 하루 시계 (2026-09-29 사용자): 자정부터 센 게임 분. 막는 건 없고 자면 아침 6시로 돌아간다.
var minutes := float(Config.DAY_START_MINUTE)
var seeds := Config.START_SEEDS
var crops := 0
var money := Config.START_MONEY
## 마을 공급함에 진열한 작물. 밤사이 팔리고 아침에 돈이 들어온다.
var displayed_crops := 0
## 캔 들나물 (농부가 들고 있음) · 공급함에 진열한 들나물 (밤사이 팔림)
var herbs := 0
var displayed_herbs := 0
## 채집 크리처(땅속성)가 캐서 공급함에 진열한 도라지 뿌리 (밤사이 팔림)
var displayed_roots := 0
## 열린 밭 구역 수 (Config.FIELD_PLOTS 앞에서부터)
var open_plots := Config.START_FIELD_PLOTS
## 알은 종 정보만 가진다. 능력치와 Trait은 부화할 때 정해진다.
## 농부가 들고 있는 알
var farmer_eggs: Array[CreatureSpecies] = []
## 사냥꾼이 들고 있는 알 (마을 공급함에 넣기 전)
var hunter_eggs: Array[CreatureSpecies] = []
## 마을 공급함에 있는 알
var village_eggs: Array[CreatureSpecies] = []
var hunts_today := 0
## 켜진 사냥터 웨이포인트 (Config.HUNT_ZONES 번호). 0 = 숲 공터 (처음부터 입구에서 시작).
var waypoints: Array[int] = [0]
## 강화한 농사 도구 (Farm.Work 값 → 단계). 0이면 처음 도구.
var tool_levels := {}
## 사냥꾼 튼튼한 사냥칼을 샀는지
var hunter_knife := false
## 입는 장비 (Wearables). 산 장비 id, 캐릭터별 입은 장비 (칸 → id)
var owned_wear: Array[StringName] = []
var worn := {&"farmer": {}, &"hunter": {}}
## 디아블로식 가방 (2026-09-28 사용자 요청): 캐릭터마다 입지 않은 장비를 들고 다닌다 (Config.BAG_SIZE 칸)
var bag := {&"farmer": [] as Array[StringName], &"hunter": [] as Array[StringName]}
## 마을 공용 창고 (농부·사냥꾼이 함께 쓴다, Config.STASH_SIZE 칸)
var stash: Array[StringName] = []
## 사냥터에서 굴린 장비 한 개 한 개 (2026-09-28 사용자 선택 A: 디아블로2식 등급).
## id(&"gear_n") → {base, rarity, name, affixes}. 가방 · 창고 · 입은 칸에는 이 id 가 들어간다.
var gear := {}
var gear_serial := 0
## 처음 주는 무기를 이미 떨어뜨린 구역 (Config.FIRST_WEAPON_DROPS)
var weapon_gifts: Array[int] = []
## 사냥터 드롭 (2026-09-27 결정 A + 드롭표): 빨간 물약, 잡템(슬라임 젤리)
var potions := 0
var junk := 0
## 사냥꾼 조작 해금 여부. 첫 슬라임을 밭에 배치하면 열린다 (임시 조건).
var hunter_unlocked := false
## 게임 전체에서 첫 알을 이미 얻었는지. 첫 알 하나만 보장하고, 그 뒤로는 확률 (2026-09-29).
var first_egg_done := false
## 대장간 (2026-09-29 사용자 선택 A): 0 = 없음, 1 = 무너진 터, 2 = 고침 (대장장이 열림)
var forge_state := 0
## 1막 대장(금두꺼비)을 쓰러뜨린 적이 있는지. 다음 날 아침 대장간 터가 드러난다.
var forge_boss_down := false
## 1막 대장 재료 (사금 덩이), 대장장이 제작 재료 (고철), 고물 더미에 남은 고철
var material := 0
var scrap := 0
var scrap_pile := 0


func _ready() -> void:
	_register_inputs()


func notify(text: String) -> void:
	message.emit(text)
	changed.emit()


func tool_level(work: int) -> int:
	return tool_levels.get(work, 0)


## 시계 글씨 (10분 단위): "오전 6:00", "오후 2:40", "밤 11:50", "새벽 1:00"
static func clock_text(at_minutes: float) -> String:
	var m := int(at_minutes) / 10 * 10
	var h := (m / 60) % 24
	var part := "오전"
	if m >= 24 * 60:
		part = "새벽"
	elif h >= 21:
		part = "밤"
	elif h >= 12:
		part = "오후"
	var h12 := h % 12
	if h12 == 0:
		h12 = 12
	return "%s %d:%02d" % [part, h12, m % 60]


func touch() -> void:
	changed.emit()


func reset() -> void:
	day = 1
	minutes = float(Config.DAY_START_MINUTE)
	seeds = Config.START_SEEDS
	crops = 0
	money = Config.START_MONEY
	displayed_crops = 0
	herbs = 0
	displayed_herbs = 0
	displayed_roots = 0
	open_plots = Config.START_FIELD_PLOTS
	farmer_eggs = []
	hunter_eggs = []
	village_eggs = []
	for i in Config.START_VILLAGE_EGGS:
		village_eggs.append(CreatureCatalog.STARTER_EGG)
	hunts_today = 0
	waypoints = [0]
	tool_levels = {}
	hunter_knife = false
	owned_wear = []
	worn = {&"farmer": {}, &"hunter": {}}
	bag = {&"farmer": [] as Array[StringName], &"hunter": [] as Array[StringName]}
	stash = []
	gear = {}
	gear_serial = 0
	weapon_gifts = []
	potions = 0
	junk = 0
	hunter_unlocked = false
	first_egg_done = false
	forge_state = 0
	forge_boss_down = false
	material = 0
	scrap = 0
	scrap_pile = 0
	changed.emit()


## 입력 매핑. 에디터의 Input Map 대신 코드로 등록해 둔다.
func _register_inputs() -> void:
	var map := {
		"move_up": [KEY_W, KEY_UP],
		"move_down": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"use_tool": [KEY_SPACE, KEY_J],
		"attack": [],
		"interact": [KEY_F, KEY_K],
		"tool_prev": [KEY_Q],
		"tool_next": [KEY_E],
		"creature_job": [KEY_R],
		"switch_character": [KEY_TAB],
		"next_day": [KEY_N],
		"menu_close": [KEY_ESCAPE],
		"use_potion": [KEY_1],
		"inventory": [KEY_I],
	}
	for action: String in map:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key: Key in map[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
	# 사냥터 공격은 마우스 왼쪽 클릭 (사용자 요청 2026-09-27). 누른 쪽을 향해 휘두른다.
	if InputMap.action_get_events("attack").is_empty():
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("attack", click)
