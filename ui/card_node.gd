# A district card — Magic-style frame with live 3D art, cost gem, name banner.
class_name CardNode
extends Control

signal card_clicked(node: CardNode)

const FULL_W := 190.0
const FULL_H := 308.0
const MINI_W := 96.0
const MINI_H := 148.0

var card: Dictionary = {}
var mini := false
var interactive := false
var highlighted := false      # buildable / selectable glow
var selected := false         # multi-select (Magician discard)
var _panel: Panel
var _hover := false
var _base_scale := Vector2.ONE


static func make(p_card: Dictionary, p_mini := false) -> CardNode:
	var n := CardNode.new()
	n.card = p_card
	n.mini = p_mini
	return n


func _ready() -> void:
	var w := MINI_W if mini else FULL_W
	var h := MINI_H if mini else FULL_H
	custom_minimum_size = Vector2(w, h)
	size = Vector2(w, h)
	pivot_offset = Vector2(w / 2.0, h)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var tc := Visual.type_color(card.get("type", "special"))

	_panel = Panel.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.add_theme_stylebox_override("panel", Visual.card_style(tc))
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)

	# Inner gradient wash
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Visual.TYPE_DARK.get(card.get("type", "special"), Color(0.1, 0.1, 0.15)), Color(0.05, 0.04, 0.09)])
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

	# Art: painted living art when available, procedural 3D diorama otherwise
	var art: Control
	if LivingArt.has_any(card["name"]):
		art = LivingArt.make(card["name"], not mini)
	else:
		var art_px := 96 if mini else 230
		var vp := CardArt.create(card["name"], art_px, not mini, tc)
		add_child(vp)
		var tr := TextureRect.new()
		tr.texture = vp.get_texture()
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art = tr
	# art window matches the painted art aspect (0.8) so nothing gets cropped
	if mini:
		art.position = Vector2(4, 14)
		art.size = Vector2(w - 8, (w - 8) * 1.18)
	else:
		art.position = Vector2(7, 30)
		art.size = Vector2(w - 14, (w - 14) * 1.18)
	add_child(art)

	# Name banner
	var name_label := Visual.make_label(card["name"], 10 if mini else 16, Color(0.97, 0.94, 0.85), Visual.display_font())
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.clip_text = true
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if mini:
		name_label.position = Vector2(2, h - 29)
		name_label.size = Vector2(w - 4, 18)
	else:
		name_label.position = Vector2(10, h - 66)
		name_label.size = Vector2(w - 20, 24)
	add_child(name_label)

	# Type ribbon
	var ribbon := ColorRect.new()
	ribbon.color = tc.darkened(0.15)
	ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if mini:
		ribbon.position = Vector2(4, h - 10)
		ribbon.size = Vector2(w - 8, 6)
	else:
		ribbon.position = Vector2(10, h - 40)
		ribbon.size = Vector2(w - 20, 4)
	add_child(ribbon)

	# Description (full cards with special text only)
	if not mini and card.get("description") != null:
		var desc := Visual.make_label(str(card["description"]), 11, Color(0.85, 0.82, 0.74))
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		desc.position = Vector2(10, h - 34)
		desc.size = Vector2(w - 20, 30)
		desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(desc)
	elif not mini:
		var flavor := Visual.make_label(card.get("type", "").capitalize() + " district", 12, Color(0.62, 0.58, 0.52))
		flavor.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		flavor.position = Vector2(10, h - 32)
		flavor.size = Vector2(w - 20, 20)
		flavor.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(flavor)

	# Gold inner frame
	var inner := Panel.new()
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.offset_left = 4
	inner.offset_top = 4
	inner.offset_right = -4
	inner.offset_bottom = -4
	inner.add_theme_stylebox_override("panel", Visual.gold_inner_frame())
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(inner)

	# Cost gem
	var gem := CostGem.new()
	gem.cost = int(card.get("cost", 0))
	gem.gem_color = tc
	var gem_r := 13.0 if mini else 20.0
	gem.position = Vector2(-4, -4)
	gem.size = Vector2(gem_r * 2, gem_r * 2)
	gem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(gem)

	if card.get("description") != null:
		tooltip_text = "%s — %s" % [card["name"], card["description"]]

	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)
	_refresh_style()


func set_highlighted(v: bool) -> void:
	highlighted = v
	_refresh_style()


func set_selected(v: bool) -> void:
	selected = v
	_refresh_style()


func _refresh_style() -> void:
	if _panel == null:
		return
	var tc := Visual.type_color(card.get("type", "special"))
	var sb := Visual.card_style(tc, _hover and interactive)
	if selected:
		sb.border_color = Visual.GOLD
		sb.set_border_width_all(4)
		sb.shadow_color = Visual.GOLD * Color(1, 1, 1, 0.6)
		sb.shadow_size = 16
	elif highlighted:
		sb.border_color = Visual.GOLD.lerp(tc, 0.3)
		sb.set_border_width_all(3)
		sb.shadow_color = Visual.GOLD * Color(1, 1, 1, 0.35)
		sb.shadow_size = 10
	_panel.add_theme_stylebox_override("panel", sb)


func _on_mouse_entered() -> void:
	_hover = true
	_refresh_style()
	if interactive and not mini:
		z_index = 50
		var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(self, "scale", _base_scale * 1.16, 0.16)


func _on_mouse_exited() -> void:
	_hover = false
	_refresh_style()
	if interactive and not mini:
		z_index = 0
		var tw := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(self, "scale", _base_scale, 0.18)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if interactive:
			card_clicked.emit(self)


# Gold cost gem with the number inside.
class CostGem extends Control:
	var cost := 0
	var gem_color := Color.GRAY

	func _draw() -> void:
		var r := size.x / 2.0
		var c := Vector2(r, r)
		draw_circle(c, r, Color(0.08, 0.06, 0.04))
		draw_circle(c, r - 1.5, Visual.GOLD.darkened(0.25))
		draw_circle(c, r - 3.5, Visual.GOLD)
		draw_arc(c, r - 3.0, PI * 0.8, PI * 1.9, 16, Color(1, 0.97, 0.8, 0.8), 1.5, true)
		var f := Visual.display_font()
		var fs := int(r * 1.15)
		var s := str(cost)
		var sw := f.get_string_size(s, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
		draw_string(f, Vector2(r - sw / 2.0, r + fs * 0.36), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.15, 0.10, 0.02))
