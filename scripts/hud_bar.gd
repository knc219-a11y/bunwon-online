class_name HudBar
extends Control
## 위 줄 (2026-09-30 그래픽 시범): 반투명 나무 줄 위에 아이콘 + 글씨 알약을 늘어놓는다.
## 같은 내용의 글줄은 main._status 에도 그대로 남아 있다 (테스트 · 예전 표시용, 화면엔 숨김).

## [아이콘, 글씨] 목록
var chips: Array = []


func set_chips(list: Array) -> void:
	chips = list
	queue_redraw()


func _draw() -> void:
	var x := 4.0
	for c: Array in chips:
		x = UiSkin.draw_chip(self, Vector2(x, 5), c[0], c[1])
