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
## 밭 작물 (2026-10-03 농사 다양화, Config.CROPS): 무 말고 가진 수 · 씨앗 · 공급함에 진열한 것 (작물 id → 수)
var potatoes := 0
var peppers := 0
var cabbages := 0
var potato_seeds := 0
var pepper_seeds := 0
var cabbage_seeds := 0
var displayed_harvest := {}
## 열린 작물 (무 빼고, 씨앗을 얻은 순서) · 밭 구역마다 심을 작물 (번호 = Config.FIELD_PLOTS, 없으면 무)
var crop_unlocked: Array[StringName] = []
var plot_crops: Array[StringName] = []
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
## 대장을 한 번이라도 쓰러뜨린 구역 (Config.HUNT_ZONES 번호). 이런 구역은 다음부터 들어가면 대장이 처음부터 나와 있다
## (2026-10-01 사용자: "보스를 한번 잡으면 그담부터는 일반 몬스터 안잡아도 보스가 팝업되어있도록").
var bosses_beaten: Array[int] = []
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
## 약방 (2026-09-29): 0 = 없음, 1 = 무너진 터, 2 = 고침 (연금술사 열림 · 번천 길 호롱)
var yak_state := 0
## 2막 대장(도마리 장승 한 쌍)을 쓰러뜨린 적이 있는지. 다음 날 아침 약방 터가 드러난다.
var yak_boss_down := false
## 2막 대장 재료 (장승 조각), 약방에 모아 둔 도라지, 도라지밭에 남은 도라지
var material2 := 0
var roots := 0
var herb_bed := 0
## 연금술사가 만든 것: 호롱 기름 · 힘 물약 · 빠르기 물약 · 크리처 보약 (빨간 물약은 potions)
var lamp_oil := 0
var strength := 0
var speed := 0
var tonics := 0
## 크리처 보약을 먹인 날 (그날 모든 크리처가 두 배 빠름). -1 = 없음
var tonic_day := -1
## 축사 (2026-09-30 닭장): 0 = 없음, 1 = 무너진 터, 2 = 고침 (목축인 열림)
var barn_state := 0
## 3막 대장(밀목)을 쓰러뜨린 적이 있는지. 다음 날 아침 축사 터가 드러난다.
var barn_boss_down := false
## 3막 대장 재료
var material3 := 0
## 닭장: 암탉 수 · 병아리 (암탉이 되기까지 남은 날) · 둥지에 있는 달걀 · 어제 모이를 먹은 암탉 수
var hens := 0
var chicks: Array[int] = []
var nest := 0
var fed := 0
## 꺼내 든 달걀 · 공급함에 진열한 달걀 · 목축인이 싼 사냥 도시락
var hen_eggs := 0
var displayed_hen_eggs := 0
var lunches := 0
## 나루터 (2026-10-02 시설 4): 0 = 없음, 1 = 무너진 터, 2 = 고침 (뱃사공 열림)
var naru_state := 0
## 4막 대장(곤지암 마왕)을 쓰러뜨린 적이 있는지. 다음 날 아침 나루터 터가 드러난다.
var naru_boss_down := false
## 4막 대장 재료
var material4 := 0
## 5막 대장 (소내섬, 마지막 대장) 을 쓰러뜨린 적이 있는지 (2026-10-03). 다음 날 아침 마을회관 터가 드러난다 (VillageHall).
var final_boss_down := false
## 마을회관 (2026-10-03 시설 5): 0 = 없음, 1 = 무너진 터, 2 = 고침 (이장 열림). 터는 final_boss_down 다음 날 아침에 드러난다.
var hall_state := 0
## 5막 대장 재료 (용 비늘)
var material5 := 0
## 시설 공사 (2026-10-03 백로그 4번, SiteWork): 시설 id → 크리처가 한 공사 수 (키가 있으면 공사 중, 시설이 서면 지움).
## build_today = 오늘 크리처가 한 공사 수 (아침마다 0, 하루 Config.BUILD_CAP).
var site_work := {}
var build_today := 0
## 게시판 오늘 부탁: {id = Config.HALL_REQUESTS 키, count = 개수} (없으면 {}), 오늘 크리처 심부름으로 모인 수, 이장이 오늘 부탁을 바꿨는지
var hall_request := {}
var errands := 0
var hall_rerolled := false
## 들어준 부탁 수 (모두)
var requests_done := 0
## 잔치 (2026-10-03 엔딩 B 잔치상 차리기): 0 = 아직, 1 = 잔치상 차리는 중, 2 = 잔치를 열었음 (엔딩 봄).
## feast_dishes = 차린 상 id (Config.FEAST_DISHES), feast_day = 잔치를 연 날
var feast_state := 0
var feast_dishes: Array[StringName] = []
var feast_day := -1
## 통발: 지금 물에 놓은 수 · 나루터 바구니의 물고기 · 꺼내 든 물고기 · 공급함에 진열한 물고기 · 뱃사공 매운탕
var traps := 0
var basket := 0
var fish := 0
var displayed_fish := 0
var stews := 0
## 오늘 크리처가 한 물고기 몰기 수 (내일 아침 물고기 +). 아침마다 0.
var fish_drive := 0
## 주민에게 입양 보낸 크리처 (2026-10-01 사용자 선택 D). {species, elements (리소스 경로), who (&"smith" 등)}
var adopted: Array = []
## 사냥꾼 레벨 · 스킬 (2026-10-02 디아2식). hunter_xp 는 지금 레벨 안에서 모은 경험치.
## skills = {스킬 id: 찍은 단계}, skill_left = {무기 종류: 왼클릭에 건 스킬 id}
var hunter_level := 1
var hunter_xp := 0
var skill_points := 0
var skills := {}
var skill_left := {}
## 직업 · 스탯 (2026-10-03 2단계). hunter_class = &"warrior" / &"archer" / &"mage" (&"" = 아직 안 고름),
## stats = {&"str" · &"dex" · &"wis" · &"bond": 찍은 점}, free_respec_used = 공짜 초기화를 썼는지
var hunter_class := &""
var stats := {}
var stat_points := 0
var free_respec_used := false


func _ready() -> void:
	_register_inputs()
	UiSkin.apply_font()


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
	potatoes = 0
	peppers = 0
	cabbages = 0
	potato_seeds = 0
	pepper_seeds = 0
	cabbage_seeds = 0
	displayed_harvest = {}
	crop_unlocked = []
	plot_crops = []
	open_plots = Config.START_FIELD_PLOTS
	farmer_eggs = []
	hunter_eggs = []
	village_eggs = []
	for i in Config.START_VILLAGE_EGGS:
		village_eggs.append(CreatureCatalog.STARTER_EGG)
	hunts_today = 0
	waypoints = [0]
	bosses_beaten = []
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
	yak_state = 0
	yak_boss_down = false
	material2 = 0
	roots = 0
	herb_bed = 0
	lamp_oil = 0
	strength = 0
	speed = 0
	tonics = 0
	tonic_day = -1
	barn_state = 0
	barn_boss_down = false
	material3 = 0
	hens = 0
	chicks = []
	nest = 0
	fed = 0
	hen_eggs = 0
	displayed_hen_eggs = 0
	lunches = 0
	naru_state = 0
	naru_boss_down = false
	material4 = 0
	final_boss_down = false
	hall_state = 0
	material5 = 0
	hall_request = {}
	site_work = {}
	build_today = 0
	errands = 0
	hall_rerolled = false
	requests_done = 0
	feast_state = 0
	feast_dishes = []
	feast_day = -1
	traps = 0
	basket = 0
	fish = 0
	displayed_fish = 0
	stews = 0
	fish_drive = 0
	adopted = []
	hunter_level = 1
	hunter_xp = 0
	skill_points = 0
	skills = {}
	hunter_class = &""
	stats = {}
	stat_points = 0
	free_respec_used = false
	skill_left = {}
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
		## 사냥꾼 스킬 창 (2026-10-02, 디아2처럼 T)
		"skills": [KEY_T],
		## 사냥터 구르기 (2026-10-02). Space 는 마을에선 도구질, 사냥터에선 구르기 (J 는 그대로 휘두르기)
		"dash": [KEY_SPACE, KEY_SHIFT],
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
	# 오른클릭 큰 스킬 (2026-10-02 사냥꾼 스킬)
	if not InputMap.has_action("skill_right"):
		InputMap.add_action("skill_right")
		var rclick := InputEventMouseButton.new()
		rclick.button_index = MOUSE_BUTTON_RIGHT
		InputMap.action_add_event("skill_right", rclick)
