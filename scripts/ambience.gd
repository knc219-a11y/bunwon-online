class_name Ambience
extends Node2D
## 조명 · 날씨 느낌 (2026-09-30 그래픽 시범 C). 게임 규칙은 바꾸지 않는 겉모습만.
## - 하루 시계 따라 화면 색 (아침 복숭앗빛 → 한낮 → 노을 → 푸른 밤). 예전 _dusk 어둡기는 수치로만 남는다.
## - 저녁부터 불빛 (집 창 · 부화기 보온등 등, add_light 로 등록)
## - 느리게 지나가는 구름 그림자, 바람에 날리는 감잎 · 꽃잎, 밤 반딧불

## 시각(분) → 화면 색
const DAY_COLORS: Array = [
	[6 * 60, Color(1.0, 0.9, 0.84)],
	[8 * 60, Color(1, 1, 1)],
	[16 * 60, Color(1, 1, 1)],
	[18 * 60, Color(1.0, 0.84, 0.7)],
	[20 * 60, Color(0.66, 0.62, 0.86)],
	[22 * 60, Color(0.46, 0.47, 0.72)],
	[26 * 60, Color(0.42, 0.44, 0.7)],
]
const LIGHT_ON_START := 17 * 60 + 30
const LIGHT_ON_FULL := 20 * 60
const CLOUD_SPEED := Vector2(7, 2.5)

## 구름 그림자가 도는 넓이 (px)
var area := Vector2(640, 360)
var _modulate: CanvasModulate
var _lights: Array[PointLight2D] = []
var _clouds: Array[Dictionary] = []
var _fireflies: CPUParticles2D
var _soft: GradientTexture2D


func _ready() -> void:
	_soft = _radial(64, Color(1, 1, 1, 1))
	_modulate = CanvasModulate.new()
	add_child(_modulate)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in maxi(3, int(area.x * area.y / 90000.0)):
		_clouds.append({at = Vector2(rng.randf_range(0, area.x), rng.randf_range(0, area.y)), size = Vector2(rng.randf_range(150, 240), rng.randf_range(70, 110))})
	var clouds := Node2D.new()
	clouds.z_index = 3000
	clouds.draw.connect(_draw_clouds.bind(clouds))
	add_child(clouds)
	set_meta(&"clouds", clouds)
	add_child(_leaves())
	_fireflies = _firefly_particles()
	add_child(_fireflies)
	update_time()


## 불빛 하나 (at: 월드 px). 저녁이 되면 켜진다.
func add_light(at: Vector2, radius: float, col: Color) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = _soft
	l.texture_scale = radius / 32.0
	l.color = col
	l.position = at
	l.energy = 0.0
	add_child(l)
	_lights.append(l)
	return l


func _process(delta: float) -> void:
	for c in _clouds:
		c.at += CLOUD_SPEED * delta
		if c.at.x - c.size.x > area.x:
			c.at.x = -c.size.x
		if c.at.y - c.size.y > area.y:
			c.at.y = -c.size.y
	(get_meta(&"clouds") as Node2D).queue_redraw()
	update_time()


func update_time() -> void:
	var m := GameState.minutes
	_modulate.color = color_at(m)
	var on := clampf(inverse_lerp(LIGHT_ON_START, LIGHT_ON_FULL, m), 0.0, 1.0)
	for l in _lights:
		l.energy = on * 1.1
	_fireflies.emitting = on > 0.5


static func color_at(m: float) -> Color:
	if m <= DAY_COLORS[0][0]:
		return DAY_COLORS[0][1]
	for i in range(1, DAY_COLORS.size()):
		if m <= DAY_COLORS[i][0]:
			var t := inverse_lerp(float(DAY_COLORS[i - 1][0]), float(DAY_COLORS[i][0]), m)
			return (DAY_COLORS[i - 1][1] as Color).lerp(DAY_COLORS[i][1], t)
	return DAY_COLORS[-1][1]


func _draw_clouds(n: Node2D) -> void:
	# 낮에만 또렷하고 밤엔 옅게
	var a := 0.32 * clampf(inverse_lerp(21 * 60, 17 * 60, GameState.minutes), 0.0, 1.0)
	if a <= 0.0:
		return
	for c in _clouds:
		n.draw_texture_rect(_soft, Rect2(c.at - c.size / 2, c.size), false, Color(0.22, 0.2, 0.4, a))
		n.draw_texture_rect(_soft, Rect2(c.at - c.size * Vector2(0.1, 0.45), c.size * 0.7), false, Color(0.22, 0.2, 0.4, a * 0.8))


func _radial(size: int, col: Color) -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, col)
	g.set_color(1, Color(col, 0.0))
	g.add_point(0.55, Color(col, 0.75))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = size
	t.height = size
	return t


func _dot(w: int, h: int, cols: Array[Color]) -> ImageTexture:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			img.set_pixel(x, y, cols[(x + y) % cols.size()])
	return ImageTexture.create_from_image(img)


## 바람에 날리는 감잎 · 꽃잎
func _leaves() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = _dot(4, 3, [Color(0.95, 0.6, 0.35), Color(0.98, 0.78, 0.45), Color(0.9, 0.5, 0.3)])
	p.amount = maxi(16, int(area.x * area.y / 11000.0))
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = area / 2
	p.position = area / 2
	p.direction = Vector2(1, 0.35)
	p.spread = 20
	p.gravity = Vector2(0, 4)
	p.initial_velocity_min = 8
	p.initial_velocity_max = 16
	p.angular_velocity_min = -90
	p.angular_velocity_max = 90
	p.angle_min = 0
	p.angle_max = 360
	p.color_ramp = _fade_ramp(Color(1, 1, 1))
	p.z_index = 2900
	return p


## 밤 반딧불 (저녁 불빛이 반쯤 켜지면)
func _firefly_particles() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = _dot(2, 2, [Color(0.9, 1.0, 0.55)])
	p.amount = maxi(12, int(area.x * area.y / 14000.0))
	p.lifetime = 5.0
	p.preprocess = 5.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = area / 2
	p.position = area / 2
	p.gravity = Vector2.ZERO
	p.direction = Vector2(0, -1)
	p.spread = 180
	p.initial_velocity_min = 2
	p.initial_velocity_max = 6
	p.color_ramp = _fade_ramp(Color(0.9, 1.0, 0.55))
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	p.material = mat
	p.z_index = 2950
	p.emitting = false
	return p


func _fade_ramp(col: Color) -> Gradient:
	var g := Gradient.new()
	g.set_color(0, Color(col, 0.0))
	g.set_color(1, Color(col, 0.0))
	g.add_point(0.15, col)
	g.add_point(0.85, col)
	return g
