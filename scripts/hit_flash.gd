class_name HitFlash
## 맞은 번쩍임 (2026-10-03 타격감, 화면 흔들림 대신). 그림 하나마다 재질을 따로 둔다 (세기가 저마다 다름).

const SHADER := preload("res://scripts/hit_flash.gdshader")
## 사냥꾼이 다쳤을 때 색
const HURT_COLOR := Color(1.0, 0.25, 0.2)


static func material(color := Color.WHITE) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter(&"flash_color", color)
	return m


## amount 0 ~ 1. 재질이 없는 그림은 그냥 둔다.
static func set_amount(item: CanvasItem, amount: float) -> void:
	var m := item.material as ShaderMaterial
	if m == null or is_equal_approx(float(item.get_meta(&"flash", 0.0)), amount):
		return
	item.set_meta(&"flash", amount)
	m.set_shader_parameter(&"flash", amount)
