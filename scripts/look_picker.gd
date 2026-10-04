class_name LookPicker
extends Node2D
## 새 게임 주인공 고르기 (2026-10-04 사용자: "둘다 캐릭터 선택창에서 고르는걸로할까").
## Config.LOOKS 의 몸 시트를 정면 · 옆 · 뒷모습으로 크게 나란히 그리고, 고른 쪽에 금빛 테두리를 두른다.
## main 의 메뉴 (menu_kind &"look") 가 pick 을 넣고 다시 그리게 한다.

const SCALE := 2.0
const CELL := 48
const PANEL := Vector2(300, 124)
const TOP := 34.0
const GOLD := Color(1.0, 0.85, 0.35)

var pick := 0
var _sheets: Array[Texture2D] = []


func _ready() -> void:
	for k: StringName in Config.LOOKS:
		_sheets.append(load(Config.LOOKS[k].sheet))


func _draw() -> void:
	var keys := Config.LOOKS.keys()
	var font := ThemeDB.fallback_font
	for i in keys.size():
		var l: Dictionary = Config.LOOKS[keys[i]]
		var at := Vector2(320 - PANEL.x - 4 + i * (PANEL.x + 8), TOP)
		var box := Rect2(at, PANEL)
		draw_rect(box, Color(0.12, 0.09, 0.08, 0.94))
		draw_rect(box, GOLD if i == pick else Color(0.45, 0.38, 0.3), false, 2.0 if i == pick else 1.0)
		var tex: Texture2D = _sheets[i]
		# 정면 · 옆 · 뒷모습 (시트 줄 0 아래 · 2 옆 · 1 위), 대기 첫 칸
		for j in 3:
			var row: int = [0, 2, 1][j]
			var src := Rect2(0, row * CELL, CELL, CELL)
			var dst := Rect2(at + Vector2(6 + j * 96, 22), Vector2(CELL, CELL) * SCALE)
			draw_texture_rect_region(tex, dst, src, Color.WHITE if i == pick else Color(0.7, 0.7, 0.7))
		draw_string_outline(font, at + Vector2(8, 16), "%s %s" % ["AB"[i], l.name], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 3, Color(0, 0, 0))
		draw_string(font, at + Vector2(8, 16), "%s %s" % ["AB"[i], l.name], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, GOLD if i == pick else Color(0.9, 0.86, 0.78))
