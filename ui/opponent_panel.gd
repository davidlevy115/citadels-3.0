# One opponent's seat at the table: name, gold, hand size, revealed character,
# crown, and their city as a row of mini cards.
class_name OpponentPanel
extends PanelContainer

signal district_clicked(player_id: String, district_index: int)
signal panel_clicked(player_id: String)

var player_info: Dictionary = {}
var is_active := false
var has_crown := false
var destroy_mode := false      # Warlord: city tiles clickable
var pick_mode := false         # Magician: whole panel clickable

var _name_label: Label
var _gold_label: Label
var _hand_label: Label
var _char_label: Label
var _city_row: HBoxContainer


func _ready() -> void:
	custom_minimum_size = Vector2(286, 200)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	add_child(vbox)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	vbox.add_child(top)

	_name_label = Visual.make_label("", 17, Color(0.96, 0.93, 0.85), Visual.display_font())
	top.add_child(_name_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)

	_gold_label = Visual.make_label("", 15, Visual.GOLD)
	top.add_child(_gold_label)

	_hand_label = Visual.make_label("", 15, Color(0.75, 0.78, 0.92))
	top.add_child(_hand_label)

	_char_label = Visual.make_label("", 14, Color(0.8, 0.8, 0.85), Visual.display_font())
	vbox.add_child(_char_label)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, CardNode.MINI_H + 8)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	_city_row = HBoxContainer.new()
	_city_row.add_theme_constant_override("separation", 4)
	scroll.add_child(_city_row)

	gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and pick_mode:
			panel_clicked.emit(player_info["id"]))

	_refresh()


func update_info(info: Dictionary, p_active: bool, p_crown: bool) -> void:
	var city_changed := _city_signature(info) != _city_signature(player_info)
	player_info = info
	is_active = p_active
	has_crown = p_crown
	_refresh(city_changed)


func set_destroy_mode(v: bool) -> void:
	destroy_mode = v
	_refresh(true)


func set_pick_mode(v: bool) -> void:
	pick_mode = v
	_refresh()


func _city_signature(info: Dictionary) -> String:
	if info.is_empty():
		return ""
	var names: Array = []
	for d in info["city"]:
		names.push_back(d["name"])
	return ",".join(names)


func _refresh(rebuild_city := true) -> void:
	if _name_label == null or player_info.is_empty():
		return

	var crown_prefix := "♛ " if has_crown else ""
	_name_label.text = crown_prefix + player_info["name"]
	_gold_label.text = "⬤ %d" % player_info["gold"]
	_gold_label.tooltip_text = "Gold"
	_hand_label.text = "🂠 %d" % player_info["handSize"]
	_hand_label.tooltip_text = "Cards in hand"

	var rc = player_info.get("revealedCharacter")
	if rc != null:
		_char_label.text = "%s (%d)" % [rc["name"], rc["rank"]]
		_char_label.add_theme_color_override("font_color", Visual.char_color(rc["name"]).lightened(0.25))
	else:
		_char_label.text = "— hidden character —"
		_char_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.62))

	# Border: gold when active turn, red pulse when destroy-targetable
	var border := Color(0.35, 0.30, 0.25, 0.7)
	var bg := Visual.PANEL_BG
	if is_active:
		border = Visual.GOLD
		bg = Color(0.11, 0.09, 0.15, 0.95)
	if destroy_mode:
		border = Color(1.0, 0.3, 0.25)
	if pick_mode:
		border = Color(0.4, 0.75, 1.0)
	var sb := Visual.panel_style(bg, border, 12, 2 if (is_active or destroy_mode or pick_mode) else 1)
	add_theme_stylebox_override("panel", sb)

	if rebuild_city:
		for child in _city_row.get_children():
			child.queue_free()
		var idx := 0
		for d in player_info["city"]:
			var tile := CardNode.make(d, true)
			var district_index := idx
			if destroy_mode and d["name"] != "Keep":
				tile.interactive = true
				tile.highlighted = true
				tile.card_clicked.connect(func(_n): district_clicked.emit(player_info["id"], district_index))
			_city_row.add_child(tile)
			idx += 1
		if player_info["city"].is_empty():
			var empty := Visual.make_label("No districts built", 12, Color(0.5, 0.5, 0.55))
			_city_row.add_child(empty)
