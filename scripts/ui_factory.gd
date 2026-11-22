extends RefCounted
## UI banane ke shared helpers — "Dark Stage, Bright Pieces" palette.

const BG := Color("171A26")
const CARD := Color("232838")
const CARD_LIGHT := Color("2C3247")
const TEXT := Color("F2F3F7")
const MUTED := Color("9AA3B2")
const DARK_TEXT := Color("171A26")

static func style(bg: Color, radius: int = 16, border: Color = Color(0, 0, 0, 0), border_w: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_left = radius
	sb.corner_radius_bottom_right = radius
	if border_w > 0:
		sb.set_border_width_all(border_w)
		sb.border_color = border
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 2)
	return sb

static func label(text: String, size: int = 18, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

# Single-line label — jab label ki width us ke apne minimum size se
# tay hoti ho (HBox ke andar, CenterContainer me) to do cheezein lazmi:
# autowrap OFF aur clip_text OFF. Godot 4.3 me wrapping label ka
# minimum width ~1px report hota hai, aur clip_text bhi minimum width
# ko ~1px kar deta hai — container phir 1px de kar text ko ya to
# harf-harf stack kar deta hai ya kaat deta hai.
static func label1(text: String, size: int = 18, color: Color = TEXT) -> Label:
	var l := label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	return l

static func button(text: String, bg: Color, font_size: int = 18, font_color: Color = DARK_TEXT) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", font_color)
	b.add_theme_color_override("font_hover_color", font_color)
	b.add_theme_color_override("font_pressed_color", font_color)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.35))
	b.add_theme_stylebox_override("normal", style(bg, 14))
	b.add_theme_stylebox_override("hover", style(bg.lightened(0.08), 14))
	b.add_theme_stylebox_override("pressed", style(bg.darkened(0.12), 14))
	b.add_theme_stylebox_override("disabled", style(Color("3A405A"), 14))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return b

static func ghost_button(text: String, font_size: int = 17) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", TEXT)
	b.add_theme_color_override("font_pressed_color", TEXT)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.35))
	b.add_theme_stylebox_override("normal", style(CARD_LIGHT, 14))
	b.add_theme_stylebox_override("hover", style(CARD_LIGHT.lightened(0.08), 14))
	b.add_theme_stylebox_override("pressed", style(CARD_LIGHT.darkened(0.1), 14))
	b.add_theme_stylebox_override("disabled", style(Color("2A2F42"), 14))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return b

static func card() -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", style(CARD, 18))
	return p

static func vspace(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

static func hspacer() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

static func margins(vbox_parent: Control, m: int = 20) -> MarginContainer:
	var mc := MarginContainer.new()
	mc.set_anchors_preset(Control.PRESET_FULL_RECT)
	mc.add_theme_constant_override("margin_left", m)
	mc.add_theme_constant_override("margin_right", m)
	mc.add_theme_constant_override("margin_top", m)
	mc.add_theme_constant_override("margin_bottom", m)
	vbox_parent.add_child(mc)
	return mc

static func dot(color: Color, size: int = 14) -> Panel:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(size, size)
	p.add_theme_stylebox_override("panel", style(color, size / 2))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p
