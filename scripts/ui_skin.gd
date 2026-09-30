class_name UiSkin
extends RefCounted
## 그래픽 시범 (2026-09-30): 글씨 · 창 · 아이콘. 그림은 tools/make_ui_skin.py, 글씨는 갈무리9 (SIL OFL 1.1, assets/fonts).

const FONT_FILE := preload("res://assets/fonts/Galmuri9.ttf")
const ICONS := preload("res://assets/ui/icons.png")
const WINDOW := preload("res://assets/ui/window.png")
const BAR := preload("res://assets/ui/bar.png")
const CHIP := preload("res://assets/ui/chip.png")

enum Icon { SUN, MOON, COIN, SEED, RADISH, HERB, EGG, CREATURE, TOOL, HEART, HEART_EMPTY, POTION, FLAG, MONSTER, JUNK, PERSON }

## 글씨 색 (한지 위 먹색) · 이름표 테두리
const INK := Color(0.29, 0.2, 0.16)
const TAG_EDGE := Color(0.2, 0.12, 0.18, 0.85)

static var _chip_box: StyleBoxTexture
static var _frame_box: StyleBoxTexture


## 게임 전체 글씨를 갈무리9로 (픽셀 글꼴이라 번짐 없이)
static func apply_font() -> void:
	var f: FontFile = FONT_FILE
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	f.hinting = TextServer.HINTING_NONE
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	ThemeDB.fallback_font = f
	ThemeDB.fallback_font_size = 10


## 9칸 나눔 창 (부모 크기를 따라감)
static func nine(tex: Texture2D, margin: int) -> NinePatchRect:
	var n := NinePatchRect.new()
	n.texture = tex
	n.patch_margin_left = margin
	n.patch_margin_right = margin
	n.patch_margin_top = margin
	n.patch_margin_bottom = margin
	n.set_anchors_preset(Control.PRESET_FULL_RECT)
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return n


static func chip_box() -> StyleBoxTexture:
	if _chip_box == null:
		_chip_box = StyleBoxTexture.new()
		_chip_box.texture = CHIP
		for s in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
			_chip_box.set_texture_margin(s, 5)
	return _chip_box


## 작은 지도 같은 그림 둘레 나무 테두리 (가운데는 비움)
static func frame_box() -> StyleBoxTexture:
	if _frame_box == null:
		_frame_box = StyleBoxTexture.new()
		_frame_box.texture = WINDOW
		_frame_box.draw_center = false
		for s in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
			_frame_box.set_texture_margin(s, 6)
	return _frame_box


static func draw_icon(ci: CanvasItem, icon: int, at: Vector2) -> void:
	ci.draw_texture_rect_region(ICONS, Rect2(at, Vector2(12, 12)), Rect2(icon * 12, 0, 12, 12))


## 아이콘 + 글씨 알약 하나. 다음 알약이 올 x 를 돌려준다.
static func draw_chip(ci: CanvasItem, at: Vector2, icon: int, text: String, h := 16.0) -> float:
	var font := ThemeDB.fallback_font
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	var w := (16.0 if icon >= 0 else 4.0) + tw + 6
	ci.draw_style_box(chip_box(), Rect2(at, Vector2(w, h)))
	var x := at.x + 3
	if icon >= 0:
		draw_icon(ci, icon, Vector2(x, at.y + (h - 12) / 2 - 1))
		x += 14
	ci.draw_string(font, Vector2(x, at.y + h / 2 + 3), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, INK)
	return at.x + w + 3


## 머리 위 이름표: 테두리 두른 흰 글씨 (가운데 정렬, 폭 width)
static func draw_tag(ci: CanvasItem, pos: Vector2, text: String, width: float, col := Color(1, 0.98, 0.92)) -> void:
	var font := ThemeDB.fallback_font
	ci.draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, width, 10, 3, TAG_EDGE)
	ci.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, width, 10, col)
