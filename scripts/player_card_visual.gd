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

class CourtSparkles extends Control:
	var diamond := false
	var elapsed := 0.0
	var redraw_elapsed := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_process(true)
		queue_redraw()

	func _process(delta: float) -> void:
		elapsed += delta
		redraw_elapsed += delta
		# Card grids can contain many premium cards. Eight redraws per second keeps
		# the subtle twinkle while avoiding hundreds of canvas redraws each second.
		if redraw_elapsed >= 0.125:
			redraw_elapsed = 0.0
			queue_redraw()

	func _draw() -> void:
		var points := [
			Vector2(0.14, 0.16), Vector2(0.31, 0.31), Vector2(0.76, 0.17),
			Vector2(0.88, 0.39), Vector2(0.20, 0.57), Vector2(0.69, 0.51),
		]
		var glow := Color("ccefff") if diamond else Color("ffe49a")
		for i in points.size():
			var speed := 0.72 + float(i % 3) * 0.17
			var phase := elapsed * speed + float(i) * 1.37
			var alpha := 0.20 + 0.42 * (0.5 + 0.5 * sin(phase * TAU))
			var drift := Vector2(sin(phase) * 1.4, cos(phase * 0.73) * 0.9)
			var p: Vector2 = points[i] * size + drift
			var radius := 2.1 if i % 2 == 0 else 1.4
			draw_circle(p, radius * 2.8, Color(glow, alpha * 0.10))
			draw_line(p - Vector2(radius, 0), p + Vector2(radius, 0), Color(glow, alpha), 0.8, true)
			draw_line(p - Vector2(0, radius), p + Vector2(0, radius), Color(glow, alpha), 0.8, true)

class TrainingGlow extends Control:
	var glow_layers: Array[StyleBoxFlat] = []

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		# A fixed stack of rounded inset borders creates a gold-to-ivory gradient.
		# It lives on the authored 144x212 canvas, so the frame and glow always
		# receive the exact same scale and cannot drift at different UI sizes.
		glow_layers = [
			glow_style(Color("b978241f"), 2, 22),
			glow_style(Color("e4a63e42"), 2, 21),
			glow_style(Color("ffd76a70"), 2, 19),
			glow_style(Color("ffe79fa8"), 2, 18),
			glow_style(Color("fff4cce8"), 1, 17),
		]
		queue_redraw()
		modulate.a = 0.58
		var pulse := create_tween().set_loops()
		pulse.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		pulse.tween_property(self, "modulate:a", 1.0, 0.72)
		pulse.tween_property(self, "modulate:a", 0.58, 0.72)

	func glow_style(color: Color, width: int, radius: int) -> StyleBoxFlat:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0, 0, 0, 0)
		style.border_color = color
		style.set_border_width_all(width)
		style.set_corner_radius_all(radius)
		style.anti_aliasing = true
		return style

	func _draw() -> void:
		var insets := [1.0, 2.5, 4.0, 5.5, 7.0]
		for i in glow_layers.size():
			var inset: float = insets[i]
			draw_style_box(glow_layers[i], Rect2(inset, inset, size.x - inset * 2.0, size.y - inset * 2.0))


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
		# Four soft highlights replace the old line-per-pixel fill. The visual is
		# effectively identical at card size and much cheaper in a 12-card grid.
		for y in [3.0, 5.0, 8.0, 12.0]:
			if y < size.y - 3.0:
				draw_line(Vector2(3, y), Vector2(size.x - 3, y), Color(0.8, 0.9, 1, 0.045), 1)
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
	var portrait_rect := Rect2(144 * 0.11, 212 * 0.06, 144 * 0.78, 212 * 0.72)
	var rarity := str(data.get("tier", ""))
	var court: Texture2D = data.get("court")
	if court != null:
		var court_art := add_art(canvas, "CourtBackground", court, portrait_rect, TextureRect.STRETCH_KEEP_ASPECT_COVERED)
		court_art.modulate = data.get("court_tint", Color.WHITE)
		var court_shade := ColorRect.new()
		court_shade.name = "CourtShade"
		court_shade.position = portrait_rect.position
		court_shade.size = portrait_rect.size
		court_shade.color = Color(0.015, 0.025, 0.055, 0.20)
		court_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		canvas.add_child(court_shade)
		if rarity in ["gold", "diamond"]:
			var court_sparkles := CourtSparkles.new()
			court_sparkles.name = "PremiumCourtSparkles"
			court_sparkles.diamond = rarity == "diamond"
			court_sparkles.position = portrait_rect.position
			court_sparkles.size = portrait_rect.size
			canvas.add_child(court_sparkles)
	add_art(canvas, "Portrait", data.portrait, portrait_rect, TextureRect.STRETCH_KEEP_ASPECT_COVERED)
	if rarity == "purple":
		var sparkles := RaritySparkles.new()
		sparkles.name = "RaritySparkles"
		sparkles.diamond = false
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
	# Keep the original large team logo on the left as a separate card element.
	var logo_badge := PanelContainer.new()
	logo_badge.name = "OriginLogoBadge"
	logo_badge.position = Vector2(11, 101)
	logo_badge.size = Vector2(40, 40)
	logo_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var logo_style := StyleBoxFlat.new()
	logo_style.bg_color = Color("09121ee8")
	logo_style.border_color = Color("d9c17dcc")
	logo_style.set_border_width_all(1)
	logo_style.set_corner_radius_all(20)
	logo_style.anti_aliasing = true
	logo_badge.add_theme_stylebox_override("panel", logo_style)
	logo_badge.visible = data.logo != null or not str(data.logo_mark).is_empty()
	canvas.add_child(logo_badge)
	if data.logo != null:
		add_art(canvas, "OriginLogo", data.logo, Rect2(14, 104, 34, 34), TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
	elif not str(data.logo_mark).is_empty():
		var fallback := Control.new()
		fallback.name = "OriginLogo"
		fallback.position = Vector2(14, 104)
		fallback.size = Vector2(34, 34)
		fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
		canvas.add_child(fallback)
		label(fallback, "FallbackMark", data.logo_mark, Rect2(2, 2, 30, 30), fonts.bold, 18)
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
	# Lift the complete OVR plate slightly; the original top gap was visually
	# larger than the position and training badges.
	ovr.position = Vector2(100, 6)
	ovr.size = Vector2(33, 40)
	ovr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(ovr)
	label(ovr, "Caption", "OVR", Rect2(3, 1, 27, 9), fonts.kicker, 8, Color("b8a98c"))
	label(ovr, "Number", str(data.ovr), Rect2(3, 9, 27, 28), fonts.number, 25)
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
