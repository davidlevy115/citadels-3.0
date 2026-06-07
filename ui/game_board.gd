# The table: opponents up top, chronicle on the right, your court at the bottom,
# a fanned hand of living cards, and modal overlays for every decision.
class_name GameBoard
extends Control

var _opponents_row: HBoxContainer
var _opponent_panels: Dictionary = {}     # player_id -> OpponentPanel
var _log_panel: LogPanel
var _hand_fan: HandFan
var _hand_nodes: Dictionary = {}          # card_id -> CardNode
var _action_bar: HBoxContainer
var _my_city_row: HBoxContainer
var _my_name_label: Label
var _my_gold_label: Label
var _my_char_label: Label
var _round_label: Label
var _deck_label: Label
var _banner: Label
var _stage: TextureRect
var _stage_art: CardArt = null
var _thinking: Label
var _toast: Label
var _overlay_layer: Control
var _overlay_key := ""
var _manual_overlay: Control = null
var _mode := "normal"                     # normal | lab_discard | magician_discard | warlord_destroy
var _magician_picks: Dictionary = {}      # card_id -> index
var _last_banner_rank := -1
var _last_city_sig := ""
var _confirm_bar: HBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	add_child(TableBackground.new())

	# ── Top-left: round / deck info
	var info := PanelContainer.new()
	info.add_theme_stylebox_override("panel", Visual.panel_style())
	info.position = Vector2(16, 14)
	add_child(info)
	var info_box := VBoxContainer.new()
	info.add_child(info_box)
	_round_label = Visual.make_label("Round 1", 18, Visual.GOLD, Visual.display_font())
	info_box.add_child(_round_label)
	_deck_label = Visual.make_label("Deck: 0", 14, Color(0.75, 0.73, 0.68))
	info_box.add_child(_deck_label)

	# ── Top-center: opponents
	var opp_scroll := ScrollContainer.new()
	opp_scroll.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	opp_scroll.offset_left = 170
	opp_scroll.offset_right = -340
	opp_scroll.offset_top = 12
	opp_scroll.offset_bottom = 256
	opp_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(opp_scroll)
	var opp_center := CenterContainer.new()
	opp_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opp_scroll.add_child(opp_center)
	_opponents_row = HBoxContainer.new()
	_opponents_row.add_theme_constant_override("separation", 12)
	opp_center.add_child(_opponents_row)

	# ── Right: chronicle
	_log_panel = LogPanel.new()
	_log_panel.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	_log_panel.offset_left = -328
	_log_panel.offset_right = -12
	_log_panel.offset_top = 12
	_log_panel.offset_bottom = -12
	add_child(_log_panel)

	# ── Center stage: large rotating diorama of the character being called
	_stage = TextureRect.new()
	_stage.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_stage.position = Vector2(-150, -260)
	_stage.size = Vector2(300, 375)
	_stage.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_stage.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.modulate.a = 0.0
	add_child(_stage)

	# ── Center: turn banner + bot thinking
	_banner = Visual.make_label("", 44, Visual.GOLD, Visual.decor_font())
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.position = Vector2(-400, 300)
	_banner.size = Vector2(800, 60)
	_banner.modulate.a = 0.0
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.z_index = 20
	add_child(_banner)

	_thinking = Visual.make_label("", 16, Color(0.7, 0.7, 0.8))
	_thinking.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_thinking.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_thinking.position = Vector2(-200, 360)
	_thinking.size = Vector2(400, 30)
	_thinking.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_thinking)

	_toast = Visual.make_label("", 17, Color(1.0, 0.45, 0.4))
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.position = Vector2(-300, -390)
	_toast.size = Vector2(600, 30)
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toast)

	# ── Bottom: my court
	var my_panel := PanelContainer.new()
	my_panel.add_theme_stylebox_override("panel", Visual.panel_style(Color(0.07, 0.055, 0.11, 0.88), Color(0.5, 0.42, 0.22, 0.7), 14, 1))
	my_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	my_panel.offset_left = 16
	my_panel.offset_right = -340
	my_panel.offset_top = -352
	my_panel.offset_bottom = -188
	add_child(my_panel)
	var my_box := VBoxContainer.new()
	my_panel.add_child(my_box)

	var my_top := HBoxContainer.new()
	my_top.add_theme_constant_override("separation", 16)
	my_box.add_child(my_top)
	_my_name_label = Visual.make_label("You", 18, Color(0.96, 0.93, 0.85), Visual.display_font())
	my_top.add_child(_my_name_label)
	_my_gold_label = Visual.make_label("⬤ 0", 17, Visual.GOLD)
	my_top.add_child(_my_gold_label)
	_my_char_label = Visual.make_label("", 16, Color(0.8, 0.8, 0.9), Visual.display_font())
	my_top.add_child(_my_char_label)

	# Action buttons live inline on the right of the player strip,
	# so the raised hand fan never covers them.
	var my_spacer := Control.new()
	my_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	my_top.add_child(my_spacer)
	_confirm_bar = HBoxContainer.new()
	_confirm_bar.add_theme_constant_override("separation", 10)
	my_top.add_child(_confirm_bar)
	_action_bar = HBoxContainer.new()
	_action_bar.add_theme_constant_override("separation", 10)
	my_top.add_child(_action_bar)

	var city_scroll := ScrollContainer.new()
	city_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	city_scroll.custom_minimum_size = Vector2(0, CardNode.MINI_H + 10)
	city_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	my_box.add_child(city_scroll)
	_my_city_row = HBoxContainer.new()
	_my_city_row.add_theme_constant_override("separation", 4)
	city_scroll.add_child(_my_city_row)

	# ── Hand fan
	_hand_fan = HandFan.new()
	_hand_fan.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_hand_fan.offset_left = 60
	_hand_fan.offset_right = -380
	_hand_fan.offset_top = -126
	_hand_fan.offset_bottom = 0
	_hand_fan.clip_contents = false
	add_child(_hand_fan)

	# ── Overlay layer
	_overlay_layer = Control.new()
	_overlay_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay_layer)

	Game.view_updated.connect(_on_view_updated)
	Game.log_added.connect(func(msg): _log_panel.add_line(msg))
	Game.action_failed.connect(_on_action_failed)
	Game.bot_thinking.connect(func(bot_name): _thinking.text = "%s is plotting…" % bot_name)

	if Game.state != null:
		_on_view_updated(Game.view())


# ── View updates ────────────────────────────────────────────────

func _on_view_updated(view: Dictionary) -> void:
	_round_label.text = "Round %d" % view["round"]
	_deck_label.text = "Deck: %d cards" % view["districtDeckCount"]
	if view["gameEndTriggered"] and view["phase"] != "gameOver":
		_round_label.text += "  — FINAL!"

	_update_opponents(view)
	_update_me(view)
	_update_hand(view)
	_update_action_bar(view)
	_update_banner(view)
	_update_overlay(view)

	if _whose_turn_is_human(view):
		_thinking.text = ""


func _whose_turn_is_human(view: Dictionary) -> bool:
	return view["isMyTurn"] or view["isMyTurnToChoose"]


func _update_opponents(view: Dictionary) -> void:
	var players: Array = view["players"]
	for i in range(players.size()):
		if i == view["myIndex"]:
			continue
		var p: Dictionary = players[i]
		var panel: OpponentPanel
		if _opponent_panels.has(p["id"]):
			panel = _opponent_panels[p["id"]]
		else:
			panel = OpponentPanel.new()
			panel.district_clicked.connect(_on_destroy_target)
			panel.panel_clicked.connect(_on_swap_target)
			_opponents_row.add_child(panel)
			_opponent_panels[p["id"]] = panel
		var is_active: bool = view["phase"] == "playerTurns" and p["revealedCharacter"] != null \
			and p["revealedCharacter"]["rank"] == view["currentCharacterRank"]
		panel.update_info(p, is_active, view["crownPlayerIndex"] == i)
		panel.set_destroy_mode(_mode == "warlord_destroy")
		panel.set_pick_mode(false)


func _update_me(view: Dictionary) -> void:
	var me: Dictionary = view["players"][view["myIndex"]]
	var crown := "♛ " if view["crownPlayerIndex"] == view["myIndex"] else ""
	_my_name_label.text = crown + me["name"]
	_my_gold_label.text = "⬤ %d gold" % me["gold"]
	if view["myCharacter"] != null:
		var ch: Dictionary = view["myCharacter"]
		_my_char_label.text = "%s (rank %d)" % [ch["name"], ch["rank"]]
		_my_char_label.add_theme_color_override("font_color", Visual.char_color(ch["name"]).lightened(0.3))
		if view["isMyTurn"]:
			_my_char_label.text += "  — YOUR TURN"
	else:
		_my_char_label.text = ""

	# my city
	var sig := ""
	for d in me["city"]:
		sig += str(d["name"]) + ","
	if sig != _last_city_sig:
		_last_city_sig = sig
		for child in _my_city_row.get_children():
			child.queue_free()
		for d in me["city"]:
			_my_city_row.add_child(CardNode.make(d, true))
		if me["city"].is_empty():
			_my_city_row.add_child(Visual.make_label("Your city awaits its first district…", 13, Color(0.55, 0.55, 0.6)))


func _update_hand(view: Dictionary) -> void:
	var hand: Array = view["myHand"]
	var actions := Game.available_actions()
	var buildable_ids: Dictionary = {}
	for entry in actions["buildableCards"]:
		buildable_ids[entry["card"]["id"]] = entry["index"]

	# remove stale nodes
	var current_ids: Dictionary = {}
	for card in hand:
		current_ids[card["id"]] = true
	for cid in _hand_nodes.keys():
		if not current_ids.has(cid):
			_hand_nodes[cid].queue_free()
			_hand_nodes.erase(cid)

	# add new nodes
	var changed := false
	for card in hand:
		if not _hand_nodes.has(card["id"]):
			var node := CardNode.make(card)
			node.card_clicked.connect(_on_hand_card_clicked)
			_hand_fan.add_child(node)
			_hand_nodes[card["id"]] = node
			changed = true

	# interactivity + highlights per mode
	for card in hand:
		var node: CardNode = _hand_nodes[card["id"]]
		match _mode:
			"lab_discard":
				node.interactive = true
				node.set_highlighted(true)
			"magician_discard":
				node.interactive = true
				node.set_highlighted(false)
				node.set_selected(_magician_picks.has(card["id"]))
			_:
				node.interactive = view["isMyTurn"] and buildable_ids.has(card["id"])
				node.set_highlighted(node.interactive)
				node.set_selected(false)

	_hand_fan.relayout(changed)


func _update_action_bar(view: Dictionary) -> void:
	for child in _action_bar.get_children():
		child.queue_free()
	for child in _confirm_bar.get_children():
		child.queue_free()

	if _mode == "lab_discard":
		_hint("Click a card in your hand to discard for 2 gold")
		_cancel_button()
		return
	if _mode == "magician_discard":
		_hint("Select cards to return to the deck, then confirm")
		var confirm := Button.new()
		confirm.text = "Redraw %d" % _magician_picks.size()
		confirm.disabled = _magician_picks.is_empty()
		Visual.style_button(confirm, Color(0.35, 0.25, 0.6))
		confirm.pressed.connect(_confirm_magician_discard)
		_confirm_bar.add_child(confirm)
		_cancel_button()
		return
	if _mode == "warlord_destroy":
		_hint("Click an enemy district to raze it")
		_cancel_button()
		return

	if not view["isMyTurn"]:
		if not view["isMyTurnToChoose"] and view["phase"] != "gameOver":
			_hint("Waiting for the other characters…")
		return

	var actions := Game.available_actions()
	var me := Game.human_player()

	if actions["canTakeGold"]:
		_action_button("Take 2 Gold", Color(0.55, 0.42, 0.10), func():
			Game.submit({"type": "TAKE_GOLD", "playerId": Game.human_id}))
	if actions["canDrawCards"]:
		_action_button("Draw Cards", Color(0.22, 0.38, 0.60), func():
			Game.submit({"type": "DRAW_CARDS", "playerId": Game.human_id}))
	if actions["canAssassinKill"]:
		_action_button("Murder…", Color(0.45, 0.12, 0.35), _open_murder_picker)
	if actions["canThiefSteal"]:
		_action_button("Rob…", Color(0.13, 0.40, 0.41), _open_rob_picker)
	if actions["canMagicianSwap"]:
		_action_button("Swap Hands…", Color(0.33, 0.22, 0.62), _open_swap_picker)
		if me["hand"].size() > 0:
			_action_button("Redraw Cards…", Color(0.28, 0.20, 0.50), func():
				_mode = "magician_discard"
				_magician_picks.clear()
				_on_view_updated(Game.view()))
	if actions["canCollectIncome"]:
		var income := CharactersLogic.get_character_income_gold(Game.state, me)
		_action_button("Collect Income (+%d)" % income, Color(0.50, 0.38, 0.10), func():
			Game.submit({"type": "USE_POWER", "playerId": Game.human_id}))
	if actions["canWarlordDestroy"]:
		_action_button("Destroy…", Color(0.55, 0.16, 0.12), func():
			_mode = "warlord_destroy"
			_on_view_updated(Game.view()))

	# Special buildings
	var turn = Game.state["turnState"]
	if turn != null:
		var used: Array = turn["specialBuildingsUsed"]
		if me["city"].any(func(d): return d["name"] == "Laboratory") and not used.has("Laboratory") and me["hand"].size() > 0:
			_action_button("Laboratory", Color(0.20, 0.45, 0.30), func():
				_mode = "lab_discard"
				_on_view_updated(Game.view()))
		if me["city"].any(func(d): return d["name"] == "Smithy") and not used.has("Smithy") and me["gold"] >= 2:
			_action_button("Smithy (−2g, +3 cards)", Color(0.45, 0.28, 0.15), func():
				Game.submit({"type": "SMITHY_DRAW", "playerId": Game.human_id}))

	if actions["canEndTurn"]:
		_action_button("End Turn", Color(0.30, 0.30, 0.38), func():
			Game.submit({"type": "END_TURN", "playerId": Game.human_id}))


func _action_button(text: String, color: Color, on_press: Callable) -> void:
	var btn := Button.new()
	btn.text = text
	Visual.style_button(btn, color)
	btn.pressed.connect(on_press)
	_action_bar.add_child(btn)


func _hint(text: String) -> void:
	var l := Visual.make_label(text, 16, Color(0.8, 0.78, 0.7))
	_action_bar.add_child(l)


func _cancel_button() -> void:
	var btn := Button.new()
	btn.text = "Cancel"
	Visual.style_button(btn, Color(0.35, 0.30, 0.35))
	btn.pressed.connect(func():
		_mode = "normal"
		_magician_picks.clear()
		_on_view_updated(Game.view()))
	_confirm_bar.add_child(btn)


# ── Hand interactions ───────────────────────────────────────────

func _on_hand_card_clicked(node: CardNode) -> void:
	var card: Dictionary = node.card
	match _mode:
		"lab_discard":
			var idx := _hand_index(card["id"])
			_mode = "normal"
			if idx != -1:
				Game.submit({"type": "LABORATORY_DISCARD", "playerId": Game.human_id, "cardIndex": idx})
		"magician_discard":
			if _magician_picks.has(card["id"]):
				_magician_picks.erase(card["id"])
			else:
				_magician_picks[card["id"]] = true
			_on_view_updated(Game.view())
		_:
			var idx := _hand_index(card["id"])
			if idx != -1:
				_animate_build(node)
				Game.submit({"type": "BUILD_DISTRICT", "playerId": Game.human_id, "cardIndex": idx})


func _hand_index(card_id: String) -> int:
	var me := Game.human_player()
	return Utils.find_index(me["hand"], func(c): return c["id"] == card_id)


func _animate_build(node: CardNode) -> void:
	var tw := node.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(node, "modulate:a", 0.0, 0.22)
	tw.parallel().tween_property(node, "scale", Vector2(0.4, 0.4), 0.22)


func _confirm_magician_discard() -> void:
	var me := Game.human_player()
	var indices: Array = []
	for i in range(me["hand"].size()):
		if _magician_picks.has(me["hand"][i]["id"]):
			indices.push_back(i)
	_mode = "normal"
	_magician_picks.clear()
	if indices.size() > 0:
		Game.submit({"type": "MAGICIAN_SWAP_DECK", "playerId": Game.human_id, "cardIndices": indices})


# ── Target pickers ──────────────────────────────────────────────

func _open_murder_picker() -> void:
	var valid: Array = [2, 3, 4, 5, 6, 7, 8]
	_show_manual(Overlays.rank_picker("Mark for Death", "The murdered character loses their entire turn.", valid,
		func(rank):
			_close_manual()
			Game.submit({"type": "ASSASSIN_KILL", "playerId": Game.human_id, "targetRank": rank}),
		_close_manual))


func _open_rob_picker() -> void:
	var valid: Array = [3, 4, 5, 6, 7, 8].filter(func(r): return r != Game.state["murderedCharacter"])
	_show_manual(Overlays.rank_picker("Choose Your Mark", "When that character is called, you take all their gold.", valid,
		func(rank):
			_close_manual()
			Game.submit({"type": "THIEF_STEAL", "playerId": Game.human_id, "targetRank": rank}),
		_close_manual))


func _open_swap_picker() -> void:
	var view := Game.view()
	_show_manual(Overlays.player_picker(view["players"], view["myIndex"],
		func(pid):
			_close_manual()
			Game.submit({"type": "MAGICIAN_SWAP_PLAYER", "playerId": Game.human_id, "targetPlayerId": pid}),
		_close_manual))


func _show_manual(overlay: Control) -> void:
	_close_manual()
	_manual_overlay = overlay
	_overlay_layer.add_child(overlay)


func _close_manual() -> void:
	if _manual_overlay != null and is_instance_valid(_manual_overlay):
		_manual_overlay.queue_free()
	_manual_overlay = null


func _on_destroy_target(player_id: String, district_index: int) -> void:
	_mode = "normal"
	Game.submit({"type": "WARLORD_DESTROY", "playerId": Game.human_id, "targetPlayerId": player_id, "districtIndex": district_index})


func _on_swap_target(player_id: String) -> void:
	Game.submit({"type": "MAGICIAN_SWAP_PLAYER", "playerId": Game.human_id, "targetPlayerId": player_id})


# ── State-driven overlays ───────────────────────────────────────

func _update_overlay(view: Dictionary) -> void:
	var key := ""
	if view["phase"] == "gameOver":
		key = "score"
	elif view["pendingGraveyard"] != null and view["pendingGraveyard"]["playerId"] == Game.human_id:
		key = "graveyard"
	elif view["isMyTurnToChoose"]:
		key = "draft-%d" % view["round"]
	elif view["isMyTurn"] and view["turnState"] != null and view["turnState"]["phase"] == "choosingCard":
		key = "keep"

	if key == _overlay_key:
		return
	_overlay_key = key

	# clear state-driven overlays
	for child in _overlay_layer.get_children():
		if child != _manual_overlay:
			child.queue_free()

	match key:
		"":
			pass
		"score":
			_close_manual()
			_mode = "normal"
			_overlay_layer.add_child(Overlays.score_screen(view, func(): get_tree().reload_current_scene()))
		"graveyard":
			_overlay_layer.add_child(Overlays.graveyard_prompt(view["pendingGraveyard"]["card"],
				func(): Game.submit({"type": "GRAVEYARD_RECOVER", "playerId": Game.human_id}),
				func(): Game.submit({"type": "GRAVEYARD_PASS", "playerId": Game.human_id})))
		"keep":
			var me := Game.human_player()
			var keeps := CharactersLogic.get_cards_to_keep_count(me)
			var label := "Keep one — the rest return to the deck." if keeps != -1 else "You keep all drawn cards."
			_overlay_layer.add_child(Overlays.card_chooser(view["turnState"]["drawnCards"], label,
				func(idx): Game.submit({"type": "KEEP_CARD", "playerId": Game.human_id, "cardIndex": idx})))
		_:
			if key.begins_with("draft"):
				_overlay_layer.add_child(Overlays.character_select(view,
					func(rank): Game.submit({"type": "CHOOSE_CHARACTER", "playerId": Game.human_id, "characterRank": rank})))


# ── Banner / toast ──────────────────────────────────────────────

func _update_banner(view: Dictionary) -> void:
	if view["phase"] != "playerTurns":
		_last_banner_rank = -1
		return
	var rank: int = view["currentCharacterRank"]
	if rank == _last_banner_rank or rank < 1 or rank > 8:
		return
	_last_banner_rank = rank
	var character = Utils.find_item(Constants.CHARACTERS, func(c): return c["rank"] == rank)
	if character == null:
		return
	_banner.text = "The %s is called" % character["name"]
	_banner.add_theme_color_override("font_color", Visual.char_color(character["name"]).lightened(0.35))
	_banner.modulate.a = 0.0
	var tw := _banner.create_tween()
	tw.tween_property(_banner, "modulate:a", 1.0, 0.3)
	tw.tween_interval(1.3)
	tw.tween_property(_banner, "modulate:a", 0.0, 0.6)

	# swap the center-stage art to the called character
	if _stage_art != null and is_instance_valid(_stage_art):
		_stage_art.queue_free()
		_stage_art = null
	if LivingArt.has_any(character["name"]):
		var la := LivingArt.make(character["name"], true)
		_stage.texture = la.texture
		_stage.material = la.material
		la.free()
	else:
		_stage_art = CardArt.create(character["name"], 330, true, Visual.char_color(character["name"]))
		_stage_art.spin_speed = 0.3
		add_child(_stage_art)
		_stage.texture = _stage_art.get_texture()
		_stage.material = null
	_stage.modulate.a = 0.0
	var stw := _stage.create_tween()
	stw.tween_property(_stage, "modulate:a", 0.72, 0.5)


func _on_action_failed(error: String) -> void:
	_toast.text = error
	_toast.modulate.a = 1.0
	var tw := _toast.create_tween()
	tw.tween_interval(2.2)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.5)
