# A character card — large portrait frame with live 3D figure art.
class_name CharacterCard
extends Control

signal chosen(rank: int)

const W := 218.0
const H := 386.0

var character: Dictionary = {}
var selectable := false
var dimmed := false          # removed face-up / unavailable
var marker := ""             # "murdered" / "robbed" / ""
var _panel: Panel
var _hover := false


static func make(p_character: Dictionary, p_selectable := false) -> CharacterCard:
	var n := CharacterCard.new()
	n.character = p_character
	n.selectable = p_selectable
	return n


func _ready() -> void:
	custom_minimum_size = Vector2(W, H)
	size = Vector2(W, H)
	pivot_offset = Vector2(W / 2.0, H)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var cc := Visual.char_color(character["name"])

	_panel = Panel.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)

	# Gradient wash
	var grad := Gradient.new()
	grad.colors = PackedColorArray([cc.darkened(0.72), Color(0.04, 0.03, 0.08)])
	var gtex := GradientTexture2D.new()
	gtex.gradient = grad
	gtex.fill_from = Vector2(0.5, 0)
	gtex.fill_to = Vector2(0.5, 1)
	var bg := TextureRect.new()
	bg.texture = gtex
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.offset_left = 4
	bg.offset_top = 4
	bg.offset_right = -4
	bg.offset_bottom = -4
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# Art: painted portrait when available, procedural 3D figure otherwise
	var art: Control
	if LivingArt.has_any(character["name"]):
		art = LivingArt.make(character["name"], true)
	else:
		var vp := CardArt.create(character["name"], 256, true, cc)
		vp.spin_speed = 0.35
		add_child(vp)
		var tr := TextureRect.new()
		tr.texture = vp.get_texture()
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art = tr
	# aspect-matched window (0.8 portrait) — full faces, no cropping
	art.position = Vector2(8, 34)
	art.size = Vector2(W - 16, (W - 16) * 1.22)
	add_child(art)

	# Gold inner frame
	var inner := Panel.new()
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.offset_left = 5
	inner.offset_top = 5
	inner.offset_right = -5
	inner.offset_bottom = -5
	inner.add_theme_stylebox_override("panel", Visual.gold_inner_frame())
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(inner)

	# Rank medallion
	var rank_gem := RankGem.new()
	rank_gem.rank = int(character["rank"])
	rank_gem.gem_color = cc
	rank_gem.position = Vector2(-6, -6)
	rank_gem.size = Vector2(44, 44)
	rank_gem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rank_gem)

	# Name
	var name_label := Visual.make_label(character["name"], 20, Color(0.98, 0.95, 0.87), Visual.decor_font())
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.position = Vector2(10, 286)
	name_label.size = Vector2(W - 20, 26)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(name_label)

	# Divider
	var div := ColorRect.new()
	div.color = cc.lightened(0.1)
	div.position = Vector2(30, 316)
	div.size = Vector2(W - 60, 2)
	div.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(div)

	# Description
	var desc := Visual.make_label(character["description"], 12, Color(0.86, 0.83, 0.76))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.position = Vector2(12, 322)
	desc.size = Vector2(W - 24, H - 328)
	desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(desc)

	if dimmed:
		modulate = Color(0.45, 0.45, 0.5, 0.85)

	if marker != "":
		var tag := Visual.make_label("✖ MURDERED" if marker == "murdered" else "ROBBED", 14, Color(1, 0.3, 0.3) if marker == "murdered" else Visual.GOLD, Visual.display_font())
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag.position = Vector2(10, 8)
		tag.size = Vector2(W - 20, 20)
		add_child(tag)

	mouse_entered.connect(func():
		_hover = true
		_refresh()
		if selectable:
			z_index = 50
			var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(self, "scale", Vector2(1.12, 1.12), 0.16))
	mouse_exited.connect(func():
		_hover = false
		_refresh()
		if selectable:
			z_index = 0
			var tw := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(self, "scale", Vector2.ONE, 0.18))
	gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and selectable:
			chosen.emit(int(character["rank"])))

	_refresh()


func _refresh() -> void:
	var cc := Visual.char_color(character["name"])
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.06, 0.11, 0.97)
	sb.set_corner_radius_all(16)
	sb.border_color = cc.lightened(0.35) if (_hover and selectable) else cc.darkened(0.05)
	sb.set_border_width_all(4 if (_hover and selectable) else 2)
	if _hover and selectable:
		sb.shadow_color = cc * Color(1, 1, 1, 0.6)
		sb.shadow_size = 22
	_panel.add_theme_stylebox_override("panel", sb)


class RankGem extends Control:
	var rank := 1
	var gem_color := Color.GRAY

	func _draw() -> void:
		var r := size.x / 2.0
		var c := Vector2(r, r)
		# diamond shape
		var pts := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])
		draw_colored_polygon(pts, Color(0.08, 0.06, 0.04))
		var inner := PackedVector2Array([c + Vector2(0, -r + 3), c + Vector2(r - 3, 0), c + Vector2(0, r - 3), c + Vector2(-r + 3, 0)])
		draw_colored_polygon(inner, gem_color)
		var f := Visual.display_font()
		var fs := int(r * 1.1)
		var s := str(rank)
		var sw := f.get_string_size(s, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
		draw_string(f, Vector2(r - sw / 2.0, r + fs * 0.36), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.05, 0.04, 0.02))
