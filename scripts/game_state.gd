extends Node
## 전역 상태 (autoload: GameState). 인벤토리, 날짜, 마을 공급함.

signal changed
signal message(text: String)

var day := 1
var seeds := Config.START_SEEDS
var crops := 0
var money := Config.START_MONEY
## 마을 공급함에 진열한 작물. 밤사이 팔리고 아침에 돈이 들어온다.
var displayed_crops := 0
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
## 강화한 농사 도구 (Farm.Work 값 → 단계). 0이면 처음 도구.
var tool_levels := {}
## 사냥꾼 튼튼한 사냥칼을 샀는지
var hunter_knife := false
## 입는 장비 (Wearables). 산 장비 id, 캐릭터별 입은 장비 (칸 → id)
var owned_wear: Array[StringName] = []
var worn := {&"farmer": {}, &"hunter": {}}
## 사냥꾼 조작 해금 여부. 첫 슬라임을 밭에 배치하면 열린다 (임시 조건).
var hunter_unlocked := false


func _ready() -> void:
	_register_inputs()


func notify(text: String) -> void:
	message.emit(text)
	changed.emit()


func tool_level(work: int) -> int:
	return tool_levels.get(work, 0)


func touch() -> void:
	changed.emit()


func reset() -> void:
	day = 1
	seeds = Config.START_SEEDS
	crops = 0
	money = Config.START_MONEY
	displayed_crops = 0
	open_plots = Config.START_FIELD_PLOTS
	farmer_eggs = []
	hunter_eggs = []
	village_eggs = []
	for i in Config.START_VILLAGE_EGGS:
		village_eggs.append(CreatureCatalog.STARTER_EGG)
	hunts_today = 0
	tool_levels = {}
	hunter_knife = false
	owned_wear = []
	worn = {&"farmer": {}, &"hunter": {}}
	hunter_unlocked = false
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
