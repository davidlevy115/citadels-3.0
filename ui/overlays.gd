# Full-screen modal overlays: character draft, keep-a-card chooser,
# murder/rob target pickers, player picker, graveyard prompt, score screen.
class_name Overlays


# Base dim overlay that blocks the table behind it.
static func _base(title_text: String) -> Dictionary:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.z_index = 100

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.05, 0.82)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 22)
	root.add_child(vbox)

	var title := Visual.make_label(title_text, 34, Visual.GOLD, Visual.decor_font())
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# fade in
	root.modulate.a = 0.0
	root.ready.connect(func():
		var tw := root.create_tween()
		tw.tween_property(root, "modulate:a", 1.0, 0.25))

	return {"root": root, "vbox": vbox, "title": title}


static func _card_row(vbox: VBoxContainer) -> HBoxContainer:
	var center := CenterContainer.new()
	vbox.add_child(center)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	center.add_child(row)
	return row


static func _subtitle(vbox: VBoxContainer, text: String) -> void:
	var sub := Visual.make_label(text, 17, Color(0.82, 0.80, 0.74))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(sub)


static func _button_row(vbox: VBoxContainer) -> HBoxContainer:
	var center := CenterContainer.new()
	vbox.add_child(center)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	center.add_child(row)
	return row


# ── Character draft ─────────────────────────────────────────────

static func character_select(view: Dictionary, on_choose: Callable) -> Control:
	var parts := _base("Choose Your Character")
	_subtitle(parts["vbox"], "Round %d — pick wisely; rank order decides who acts first." % view["round"])

	var row := _card_row(parts["vbox"])
	for character in view["availableCharacters"]:
		var cc := CharacterCard.make(character, true)
		cc.chosen.connect(func(rank): on_choose.call(rank))
		row.add_child(cc)

	if view["removedCharactersFaceUp"].size() > 0 or view["removedCharactersFaceDownCount"] > 0:
		var info := "Removed face-up: "
		var names: Array = []
		for c in view["removedCharactersFaceUp"]:
			names.push_back(c["name"])
		info += ", ".join(names) if names.size() > 0 else "none"
		info += "   ·   Face-down: %d" % view["removedCharactersFaceDownCount"]
		_subtitle(parts["vbox"], info)

	return parts["root"]


# ── Keep-one-card chooser ───────────────────────────────────────

static func card_chooser(drawn: Array, keep_label: String, on_pick: Callable) -> Control:
	var parts := _base("Choose a Card")
	_subtitle(parts["vbox"], keep_label)
	var row := _card_row(parts["vbox"])
	var idx := 0
	for card in drawn:
		var node := CardNode.make(card)
		node.interactive = true
		node.highlighted = true
		var card_index := idx
		node.card_clicked.connect(func(_n): on_pick.call(card_index))
		row.add_child(node)
		idx += 1
	return parts["root"]


# ── Murder / rob target picker ──────────────────────────────────

static func rank_picker(title: String, subtitle: String, valid_ranks: Array, on_pick: Callable, on_cancel: Callable) -> Control:
	var parts := _base(title)
	_subtitle(parts["vbox"], subtitle)
	var row := _card_row(parts["vbox"])
	for character in Constants.CHARACTERS:
		var rank: int = character["rank"]
		var cc := CharacterCard.make(character, valid_ranks.has(rank))
		if not valid_ranks.has(rank):
			cc.dimmed = true
		cc.chosen.connect(func(r): on_pick.call(r))
		row.add_child(cc)
	var buttons := _button_row(parts["vbox"])
	var cancel := Button.new()
	cancel.text = "Cancel"
	Visual.style_button(cancel, Color(0.35, 0.30, 0.35))
	cancel.pressed.connect(func(): on_cancel.call())
	buttons.add_child(cancel)
	return parts["root"]


# ── Player picker (Magician hand swap) ──────────────────────────

static func player_picker(players: Array, my_index: int, on_pick: Callable, on_cancel: Callable) -> Control:
	var parts := _base("Swap Hands With…")
	var buttons := _button_row(parts["vbox"])
	for i in range(players.size()):
		if i == my_index:
			continue
		var p: Dictionary = players[i]
		var btn := Button.new()
		btn.text = "%s  (%d cards)" % [p["name"], p["handSize"]]
		Visual.style_button(btn, Color(0.25, 0.35, 0.55), 19)
		var pid: String = p["id"]
		btn.pressed.connect(func(): on_pick.call(pid))
		buttons.add_child(btn)
	var row2 := _button_row(parts["vbox"])
	var cancel := Button.new()
	cancel.text = "Cancel"
	Visual.style_button(cancel, Color(0.35, 0.30, 0.35))
	cancel.pressed.connect(func(): on_cancel.call())
	row2.add_child(cancel)
	return parts["root"]


# ── Graveyard prompt ────────────────────────────────────────────

static func graveyard_prompt(card: Dictionary, on_recover: Callable, on_pass: Callable) -> Control:
	var parts := _base("The Graveyard Stirs…")
	_subtitle(parts["vbox"], "The Warlord destroyed %s. Pay 1 gold to take it into your hand?" % card["name"])
	var row := _card_row(parts["vbox"])
	var node := CardNode.make(card)
	row.add_child(node)
	var buttons := _button_row(parts["vbox"])
	var recover := Button.new()
	recover.text = "Recover (1 gold)"
	Visual.style_button(recover, Color(0.20, 0.45, 0.25), 19)
	recover.pressed.connect(func(): on_recover.call())
	buttons.add_child(recover)
	var pass_btn := Button.new()
	pass_btn.text = "Let it go"
	Visual.style_button(pass_btn, Color(0.35, 0.30, 0.35), 19)
	pass_btn.pressed.connect(func(): on_pass.call())
	buttons.add_child(pass_btn)
	return parts["root"]


# ── Score screen ────────────────────────────────────────────────

static func score_screen(view: Dictionary, on_again: Callable) -> Control:
	var parts := _base("Game Over")
	var scores: Array = view["scores"].duplicate()
	scores.sort_custom(func(a, b): return a["totalPoints"] > b["totalPoints"])

	_subtitle(parts["vbox"], "♛  %s claims the city with %d points!" % [scores[0]["playerName"], scores[0]["totalPoints"]])

	var center := CenterContainer.new()
	parts["vbox"].add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Visual.panel_style(Color(0.08, 0.06, 0.13, 0.96), Visual.GOLD, 14, 2))
	center.add_child(panel)

	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 26)
	grid.add_theme_constant_override("v_separation", 8)
	panel.add_child(grid)

	for header in ["Player", "Districts", "Colors", "First to 8", "Reached 8", "Total"]:
		var h := Visual.make_label(header, 15, Visual.GOLD, Visual.display_font())
		grid.add_child(h)

	var rank := 0
	for s in scores:
		rank += 1
		var name_text: String = ("♛ " if rank == 1 else "%d. " % rank) + str(s["playerName"])
		grid.add_child(Visual.make_label(name_text, 16, Color(0.95, 0.92, 0.85) if rank == 1 else Color(0.8, 0.78, 0.72)))
		grid.add_child(_score_cell(s["districtPoints"]))
		grid.add_child(_score_cell(s["colorBonusPoints"]))
		grid.add_child(_score_cell(s["firstToEightPoints"]))
		grid.add_child(_score_cell(s["otherEightPoints"]))
		var total := Visual.make_label(str(s["totalPoints"]), 17, Visual.GOLD, Visual.display_font())
		total.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		grid.add_child(total)

	var buttons := _button_row(parts["vbox"])
	var again := Button.new()
	again.text = "Return to Menu"
	Visual.style_button(again, Color(0.45, 0.32, 0.12), 20)
	again.pressed.connect(func(): on_again.call())
	buttons.add_child(again)

	return parts["root"]


static func _score_cell(value: int) -> Label:
	var l := Visual.make_label(str(value), 16, Color(0.82, 0.80, 0.74))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l
