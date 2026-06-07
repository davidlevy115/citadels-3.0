# Scrolling chronicle of game events.
class_name LogPanel
extends PanelContainer

var _rich: RichTextLabel


func _ready() -> void:
	add_theme_stylebox_override("panel", Visual.panel_style())
	custom_minimum_size = Vector2(312, 0)

	var vbox := VBoxContainer.new()
	add_child(vbox)

	var title := Visual.make_label("Chronicle", 18, Visual.GOLD, Visual.display_font())
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	_rich = RichTextLabel.new()
	_rich.bbcode_enabled = true
	_rich.scroll_following = true
	_rich.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_rich.add_theme_font_override("normal_font", Visual.body_font())
	_rich.add_theme_font_size_override("normal_font_size", 14)
	_rich.add_theme_color_override("default_color", Color(0.85, 0.83, 0.78))
	vbox.add_child(_rich)


func add_line(message: String) -> void:
	if _rich == null:
		return
	var color := "d9d4c5"
	if "murders" in message or "murdered" in message:
		color = "ff6a5e"
	elif "steals" in message or "robbery" in message:
		color = "ffd166"
	elif "builds" in message:
		color = "8ecf78"
	elif "destroys" in message:
		color = "ff8c5a"
	elif "is called" in message:
		color = "9db8ff"
	elif "Round" in message:
		color = "e8c66a"
	elif "Game over" in message:
		color = "ffe28a"
	_rich.append_text("[color=#%s]%s[/color]\n" % [color, message])


func clear_log() -> void:
	if _rich != null:
		_rich.clear()
