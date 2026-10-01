extends Node
## 소리 (autoload: Sound). 2026-10-01 사운드 첫 단계.
## - 버스 셋: Master ← Music(배경음) · SFX(효과음). default_bus_layout.tres 에 있고, 없으면 여기서 만든다.
## - 소리 파일은 tools/make_sounds.py 가 코드로 합성한다 (외부 소리 없음 → 저작권 걱정 없음).
## - 배경음 · 효과음 크기는 저장 슬롯과 따로 user://settings.cfg 에 남는다.

const SFX_DIR := "res://audio/sfx/"
const BGM_DIR := "res://audio/bgm/"
const SETTINGS_PATH := "user://settings.cfg"
## 배경음이 바뀔 때 겹쳐 넘어가는 시간 (초)
const BGM_FADE := 1.5
## 효과음 동시 재생 수
const SFX_VOICES := 8
## 크기 단계 (멈춤 메뉴에서 F 누를 때마다 다음 단계, 끝에서 0 다음 100)
const VOLUME_STEPS: Array[float] = [1.0, 0.8, 0.6, 0.4, 0.2, 0.0]

var music_volume := 0.8
var sfx_volume := 0.8
## 지금 트는 배경음 이름 (&"" = 없음)
var bgm_name := &""

var _voices: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _bgm: Array[AudioStreamPlayer] = []
var _bgm_front := 0
var _streams := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus(&"Music")
	_ensure_bus(&"SFX")
	for i in SFX_VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		add_child(p)
		_voices.append(p)
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = &"Music"
		p.volume_db = -80.0
		add_child(p)
		_bgm.append(p)
	_load_settings()
	_apply_volumes()


## 효과음 하나. 같은 소리가 기계처럼 들리지 않게 높낮이를 조금씩 흔든다.
func sfx(id: StringName, volume_db := 0.0, pitch := 1.0, jitter := 0.06) -> void:
	var stream := _stream(SFX_DIR, id)
	if stream == null:
		return
	var p := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch * randf_range(1.0 - jitter, 1.0 + jitter)
	p.play()


## 배경음을 바꾼다. 같은 곡이면 그대로 두고, 다른 곡이면 겹쳐 넘어간다. &"" 은 끈다.
func bgm(id: StringName) -> void:
	if id == bgm_name:
		return
	bgm_name = id
	var old := _bgm[_bgm_front]
	_fade(old, -80.0, true)
	if id == &"":
		return
	var stream := _stream(BGM_DIR, id)
	if stream == null:
		return
	_bgm_front = 1 - _bgm_front
	var p := _bgm[_bgm_front]
	p.stream = stream
	p.volume_db = -40.0
	p.play()
	_fade(p, 0.0, false)


func set_music_volume(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	_apply_volumes()
	_save_settings()


func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	_apply_volumes()
	_save_settings()


## 멈춤 메뉴용: 지금 크기의 다음 단계
static func next_step(v: float) -> float:
	for i in VOLUME_STEPS.size():
		if is_equal_approx(VOLUME_STEPS[i], v):
			return VOLUME_STEPS[(i + 1) % VOLUME_STEPS.size()]
	return VOLUME_STEPS[0]


static func percent(v: float) -> String:
	return "끔" if v <= 0.0 else "%d%%" % roundi(v * 100.0)


func _stream(dir: String, id: StringName) -> AudioStream:
	if _streams.has(id):
		return _streams[id]
	var path := dir + String(id) + ".ogg"
	var s: AudioStream = load(path) if ResourceLoader.exists(path) else null
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = dir == BGM_DIR
	_streams[id] = s
	return s


func _fade(p: AudioStreamPlayer, to_db: float, stop_after: bool) -> void:
	var tw := create_tween()
	tw.tween_property(p, "volume_db", to_db, BGM_FADE).set_trans(Tween.TRANS_SINE)
	if stop_after:
		tw.tween_callback(p.stop)


func _ensure_bus(bus: StringName) -> void:
	if AudioServer.get_bus_index(bus) >= 0:
		return
	AudioServer.add_bus()
	var i := AudioServer.bus_count - 1
	AudioServer.set_bus_name(i, bus)
	AudioServer.set_bus_send(i, &"Master")


func _apply_volumes() -> void:
	for pair in [[&"Music", music_volume], [&"SFX", sfx_volume]]:
		var i := AudioServer.get_bus_index(pair[0])
		AudioServer.set_bus_mute(i, pair[1] <= 0.0)
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(pair[1], 0.001)))


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	music_volume = clampf(cfg.get_value("sound", "music", music_volume), 0.0, 1.0)
	sfx_volume = clampf(cfg.get_value("sound", "sfx", sfx_volume), 0.0, 1.0)


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("sound", "music", music_volume)
	cfg.set_value("sound", "sfx", sfx_volume)
	cfg.save(SETTINGS_PATH)
