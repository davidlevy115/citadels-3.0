# Title screen: animated arcane background, showcase of 3D character art,
# opponent count selection, and the gateway into the city.
class_name MainMenu
extends Control

signal start_requested(num_bots: int)

var _num_bots := 3
var _count_label: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(TableBackground.new())

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 26)
	add_child(vbox)

	var title := Visual.make_label("CITADELS", 92, Visual.GOLD, Visual.decor_font())
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var subtitle := Visual.make_label("—  3.0 · Rise of the City  —", 22, Color(0.8, 0.75, 0.62), Visual.display_font())
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(subtitle)

	# Showcase: three rotating character dioramas
	var showcase_center := CenterContainer.new()
	vbox.add_child(showcase_center)
	var showcase := HBoxContainer.new()
	showcase.add_theme_constant_override("separation", 30)
	showcase_center.add_child(showcase)
	for char_name in ["King", "Magician", "Warlord"]:
		var frame := PanelContainer.new()
		frame.add_theme_stylebox_override("panel", Visual.panel_style(Color(0.05, 0.04, 0.09, 0.9), Visual.char_color(char_name).darkened(0.1), 14, 2))
		var art: Control
		if LivingArt.has_any(char_name):
			art = LivingArt.make(char_name, true)
			art.custom_minimum_size = Vector2(200, 250)
		else:
			var vp := CardArt.create(char_name, 240, true, Visual.char_color(char_name))
			vp.spin_speed = 0.4
			add_child(vp)
			var tr := TextureRect.new()
			tr.texture = vp.get_texture()
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.custom_minimum_size = Vector2(200, 250)
			art = tr
		frame.add_child(art)
		showcase.add_child(frame)

	# Opponent count selector
	var sel_center := CenterContainer.new()
	vbox.add_child(sel_center)
	var sel := HBoxContainer.new()
	sel.add_theme_constant_override("separation", 16)
	sel_center.add_child(sel)

	var minus := Button.new()
	minus.text = "−"
	Visual.style_button(minus, Color(0.30, 0.26, 0.38), 24)
	minus.pressed.connect(func():
		_num_bots = maxi(1, _num_bots - 1)
		_refresh_count())
	sel.add_child(minus)

	_count_label = Visual.make_label("", 22, Color(0.92, 0.90, 0.82), Visual.display_font())
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count_label.custom_minimum_size = Vector2(330, 0)
	sel.add_child(_count_label)

	var plus := Button.new()
	plus.text = "+"
	Visual.style_button(plus, Color(0.30, 0.26, 0.38), 24)
	plus.pressed.connect(func():
		_num_bots = mini(6, _num_bots + 1)
		_refresh_count())
	sel.add_child(plus)

	# Start button
	var start_center := CenterContainer.new()
	vbox.add_child(start_center)
	var start := Button.new()
	start.text = "  Enter the City  "
	Visual.style_button(start, Color(0.55, 0.38, 0.10), 26)
	start.pressed.connect(func(): start_requested.emit(_num_bots))
	start_center.add_child(start)

	var credit := Visual.make_label("A free fan-made digital adaptation of Bruno Faidutti's Citadels — built with Godot", 13, Color(0.5, 0.48, 0.45))
	credit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(credit)

	_refresh_count()


func _refresh_count() -> void:
	_count_label.text = "You vs %d rival%s  (%d players)" % [_num_bots, "" if _num_bots == 1 else "s", _num_bots + 1]
