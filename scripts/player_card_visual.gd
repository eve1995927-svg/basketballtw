extends Control
## Shared card artwork; coordinates are authored at 144 × 212 then scaled together.
## Keep the portrait and frame textures intact, with the fade beneath the frame.
const DESIGN_SIZE := Vector2(144, 212)
const INK := Color("f6f1e5")
static var footer_gradient: GradientTexture2D
var canvas: Control

class RaritySparkles extends Control:
	var diamond := false
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		queue_redraw()
	func _draw() -> void:
		var points := [Vector2(22, 28), Vector2(57, 42), Vector2(104, 25), Vector2(120, 72), Vector2(38, 88), Vector2(87, 96), Vector2(17, 116)]
		var glow := Color("d9f5ff99") if diamond else Color("f2d5ff88")
		var core := Color("ffffffdd") if diamond else Color("ffeaffcc")
		for p in points:
			var r := 5.0 if diamond else 3.5
			draw_circle(p, r * 2.2, Color(glow, 0.10))
			draw_line(p - Vector2(r, 0), p + Vector2(r, 0), glow, 1.2, true)
			draw_line(p - Vector2(0, r), p + Vector2(0, r), glow, 1.2, true)
			draw_circle(p, r * 0.42, core)

class TrainingGlow extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_process(true)
		queue_redraw()
	func _process(_delta: float) -> void:
		queue_redraw()
	func _draw() -> void:
		var pulse := 0.62 + 0.22 * sin(Time.get_ticks_msec() / 420.0)
		var color := Color(0.55, 0.95, 1.0, pulse)
		draw_rect(Rect2(2, 2, size.x - 4, size.y - 4), color, false, 1.6)


class StatBadge extends Control:
	func _draw() -> void:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("111923f5")
		style.border_color = Color("b6a077cc")
		style.set_border_width_all(1)
		style.set_corner_radius_all(4)
		style.shadow_color = Color(0, 0, 0, 0.32)
		style.shadow_size = 1
		style.shadow_offset = Vector2(0, 1)
		draw_style_box(style, Rect2(Vector2.ZERO, size))
		for y in range(3, int(size.y) - 3):
			draw_line(Vector2(3, y), Vector2(size.x - 3, y), Color(0.8, 0.9, 1, 0.055 * (1.0 - float(y) / size.y)), 1)
		draw_line(Vector2(6, 3), Vector2(size.x - 6, 3), Color("eadbc055"), 0.6, true)

func label(parent: Control, node_name: String, text_value: String, rect: Rect2, font: Font, font_px: int, color := INK) -> Label:
	var lab := Label.new()
	lab.name = node_name
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lab.clip_text = true
	lab.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	# Fit longer names without changing their center or pushing out adjacent elements.
	var fitted_px := font_px
	while fitted_px > maxi(9, int(font_px * 0.72)) and font.get_string_size(text_value, HORIZONTAL_ALIGNMENT_LEFT, -1, fitted_px).x > rect.size.x:
		fitted_px -= 1
	lab.add_theme_font_override("font", font)
	lab.add_theme_font_size_override("font_size", fitted_px)
	lab.add_theme_color_override("font_color", color)
	lab.add_theme_constant_override("outline_size", 2)
	lab.add_theme_color_override("font_outline_color", Color("07111f"))
	lab.text = text_value
	lab.position = rect.position
	lab.size = rect.size
	parent.add_child(lab)
	return lab

func add_art(parent: Control, node_name: String, texture: Texture2D, rect: Rect2, mode := TextureRect.STRETCH_SCALE) -> TextureRect:
	var art := TextureRect.new()
	art.name = node_name
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = mode
	art.texture = texture
	art.position = rect.position
	art.size = rect.size
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(art)
	return art

func configure(data: Dictionary, fonts: Dictionary) -> void:
	name = "CardVisual"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	canvas = Control.new()
	canvas.name = "DesignCanvas"
	canvas.size = DESIGN_SIZE
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(canvas)
	# The frame PNG already defines the card silhouette. A full rectangular plate
	# showed through its transparent corners as black, so the canvas stays clear.
	add_art(canvas, "Portrait", data.portrait, Rect2(144 * 0.11, 212 * 0.06, 144 * 0.78, 212 * 0.72), TextureRect.STRETCH_KEEP_ASPECT_COVERED)
	var rarity := str(data.get("tier", ""))
	if rarity in ["purple", "diamond"]:
		var sparkles := RaritySparkles.new()
		sparkles.name = "RaritySparkles"
		sparkles.diamond = rarity == "diamond"
		sparkles.position = Vector2.ZERO
		sparkles.size = DESIGN_SIZE
		canvas.add_child(sparkles)
	if int(data.get("training_sessions", 0)) > 0:
		var training := StatBadge.new()
		training.name = "TrainingBadge"
		training.position = Vector2(7, 9)
		training.size = Vector2(42, 18)
		training.mouse_filter = Control.MOUSE_FILTER_IGNORE
		canvas.add_child(training)
		label(training, "Value", "+%d" % int(data.get("training_sessions", 0)), Rect2(2, 0, 38, 18), fonts.kicker, 13, Color("9de7ff"))
	if footer_gradient == null:
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.30, 0.63, 1.0])
		gradient.colors = PackedColorArray([Color(0.025, 0.04, 0.07, 0), Color(0.025, 0.04, 0.07, 0.18), Color(0.025, 0.04, 0.07, 0.78), Color(0.025, 0.04, 0.07, 0.98)])
		footer_gradient = GradientTexture2D.new()
		footer_gradient.gradient = gradient
		footer_gradient.width = 32
		footer_gradient.height = 256
		footer_gradient.fill_from = Vector2.ZERO
		footer_gradient.fill_to = Vector2(0, 1)
	add_art(canvas, "FooterGradient", footer_gradient, Rect2(16, 111, 112, 95))
	add_art(canvas, "OriginalFrame", data.frame, Rect2(Vector2.ZERO, DESIGN_SIZE)).modulate = data.frame_tint
	# Move the large emblem above the centered text; all lower badges stay below the face.
	if data.logo != null:
		add_art(canvas, "OriginLogo", data.logo, Rect2(13, 103, 36, 36), TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
	elif not str(data.logo_mark).is_empty():
		var fallback := StatBadge.new()
		fallback.name = "OriginLogo"
		fallback.position = Vector2(13, 103)
		fallback.size = Vector2(36, 36)
		fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
		canvas.add_child(fallback)
		label(fallback, "FallbackMark", data.logo_mark, Rect2(2, 2, 32, 32), fonts.bold, 18)
	var position_text: String = data.position
	var pos_width := minf(76, ceilf(fonts.kicker.get_string_size(position_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x) + 18)
	var position_badge := StatBadge.new()
	position_badge.name = "PositionBadge"
	position_badge.position = Vector2(132 - pos_width, 116)
	position_badge.size = Vector2(pos_width, 23)
	position_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(position_badge)
	label(position_badge, "Position", position_text, Rect2(6, 0, pos_width - 12, 23), fonts.kicker, 17, Color("e6d9bd"))
	var ovr := StatBadge.new()
	ovr.name = "OvrBadge"
	ovr.position = Vector2(100, 9)
	ovr.size = Vector2(33, 40)
	ovr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(ovr)
	label(ovr, "Caption", "OVR", Rect2(3, 3, 27, 9), fonts.kicker, 8, Color("b8a98c"))
	label(ovr, "Number", str(data.ovr), Rect2(3, 12, 27, 26), fonts.number, 25)
	if not str(data.identity).is_empty():
		label(canvas, "Identity", data.identity, Rect2(87, 94, 44, 18), fonts.bold, 12, Color("ead9fa"))
	if not str(data.origin).is_empty():
		label(canvas, "OriginName", data.origin, Rect2(14, 141, 116, 23), fonts.bold, 13, Color("e0e6ed"))
	label(canvas, "PlayerName", data.player_name, Rect2(14, 161, 116, 28), fonts.bold, 21)
	label(canvas, "Salary", data.salary, Rect2(14, 188, 116, 20), fonts.bold, 14, Color("e5c885"))
	if int(data.get("training_sessions", 0)) >= 5:
		# Draw after the frame so the completed-training glow remains visible.
		var glow := TrainingGlow.new()
		glow.name = "TrainingGlow"
		glow.size = DESIGN_SIZE
		canvas.add_child(glow)
	resized.connect(_fit_canvas)
	_fit_canvas()

func _fit_canvas() -> void:
	if canvas != null:
		canvas.scale = size / DESIGN_SIZE
