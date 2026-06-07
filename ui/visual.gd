# Shared visual language: palette, fonts, stylebox factories.
class_name Visual

const TYPE_COLORS := {
	"noble": Color(0.95, 0.76, 0.22),
	"religious": Color(0.32, 0.62, 0.95),
	"trade": Color(0.34, 0.78, 0.42),
	"military": Color(0.88, 0.30, 0.26),
	"special": Color(0.66, 0.42, 0.95),
}

const TYPE_DARK := {
	"noble": Color(0.28, 0.21, 0.05),
	"religious": Color(0.07, 0.13, 0.26),
	"trade": Color(0.06, 0.20, 0.10),
	"military": Color(0.24, 0.07, 0.06),
	"special": Color(0.17, 0.09, 0.27),
}

const CHARACTER_COLORS := {
	"Assassin": Color(0.45, 0.16, 0.40),
	"Thief": Color(0.16, 0.48, 0.49),
	"Magician": Color(0.42, 0.27, 0.81),
	"King": Color(0.91, 0.72, 0.18),
	"Bishop": Color(0.25, 0.51, 0.88),
	"Merchant": Color(0.27, 0.69, 0.36),
	"Architect": Color(0.78, 0.55, 0.31),
	"Warlord": Color(0.80, 0.24, 0.20),
}

const GOLD := Color(1.0, 0.84, 0.35)
const PARCHMENT := Color(0.93, 0.88, 0.76)
const INK := Color(0.10, 0.08, 0.06)
const PANEL_BG := Color(0.075, 0.06, 0.12, 0.92)

static var _display_font: FontFile
static var _decor_font: FontFile
static var _body_font: FontFile
static var _symbol_fonts: Array


static func _symbols() -> Array:
	if _symbol_fonts.is_empty():
		_symbol_fonts = [
			load("res://assets/fonts/NotoSansSymbols.ttf"),
			load("res://assets/fonts/NotoSansSymbols2.ttf"),
		]
	return _symbol_fonts


static func display_font() -> FontFile:
	if _display_font == null:
		_display_font = load("res://assets/fonts/Cinzel.ttf")
		_display_font.fallbacks = _symbols()
	return _display_font


static func decor_font() -> FontFile:
	if _decor_font == null:
		_decor_font = load("res://assets/fonts/CinzelDecorative.ttf")
		_decor_font.fallbacks = _symbols()
	return _decor_font


static func body_font() -> FontFile:
	if _body_font == null:
		_body_font = load("res://assets/fonts/EBGaramond.ttf")
		_body_font.fallbacks = _symbols()
	return _body_font


static func panel_style(bg := PANEL_BG, border := Color(0.55, 0.45, 0.22, 0.8), radius := 12, border_w := 1) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


static func card_style(type_color: Color, hovered := false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.075, 0.13, 0.97)
	sb.border_color = type_color.lightened(0.25) if hovered else type_color.darkened(0.1)
	sb.set_border_width_all(3 if hovered else 2)
	sb.set_corner_radius_all(14)
	# every card sits in soft drop shadow; hover turns it into a colored glow
	sb.shadow_color = (type_color * Color(1, 1, 1, 0.55)) if hovered else Color(0, 0, 0, 0.45)
	sb.shadow_size = 18 if hovered else 8
	sb.shadow_offset = Vector2.ZERO if hovered else Vector2(0, 4)
	return sb


# Thin gold inner frame drawn inside a card, above the art.
static func gold_inner_frame() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.draw_center = false
	sb.border_color = Color(0.78, 0.62, 0.28, 0.55)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(11)
	return sb


static func button_style(base: Color, pressed := false, hovered := false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	var c := base
	if pressed:
		c = base.darkened(0.25)
	elif hovered:
		c = base.lightened(0.18)
	sb.bg_color = c
	sb.border_color = base.lightened(0.45)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


static func style_button(btn: Button, base: Color, font_size := 17) -> void:
	btn.add_theme_stylebox_override("normal", button_style(base))
	btn.add_theme_stylebox_override("hover", button_style(base, false, true))
	btn.add_theme_stylebox_override("pressed", button_style(base, true))
	var disabled_sb := button_style(base.darkened(0.5))
	disabled_sb.bg_color.a = 0.4
	btn.add_theme_stylebox_override("disabled", disabled_sb)
	btn.add_theme_font_override("font", display_font())
	btn.add_theme_font_size_override("font_size", font_size)
	btn.add_theme_color_override("font_color", Color(0.97, 0.95, 0.88))
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 0.95))
	btn.add_theme_color_override("font_pressed_color", Color(0.9, 0.88, 0.8))
	btn.add_theme_color_override("font_disabled_color", Color(0.7, 0.68, 0.62, 0.5))


static func make_label(text: String, size: int, color := Color(0.95, 0.93, 0.86), font: FontFile = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font if font != null else body_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func type_color(district_type: String) -> Color:
	return TYPE_COLORS.get(district_type, Color.GRAY)


static func char_color(char_name: String) -> Color:
	return CHARACTER_COLORS.get(char_name, Color.GRAY)
