# Root node: routes between the main menu and the game board.
extends Control

var _menu: MainMenu
var _board: GameBoard


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_show_menu()
	if "--smoke" in OS.get_cmdline_user_args():
		_run_smoke()
	elif "--shot" in OS.get_cmdline_user_args():
		_run_shots()


# Visual verification: capture screenshots of the menu, the draft and the table.
func _run_shots() -> void:
	await get_tree().create_timer(2.0).timeout
	_save_shot("/tmp/citadels_menu.png")
	_start_game(3)
	Game.bot_delay = 0.4
	await get_tree().create_timer(2.5).timeout
	_save_shot("/tmp/citadels_draft.png")
	# pick first available character if drafting
	for i in range(40):
		var actor = Game._whose_turn()
		if Game.state["phase"] == "playerTurns":
			break
		if actor != null and not actor["isBot"]:
			var action = Bot.get_bot_action(Game.state, Game.human_id)
			if action != null:
				Game.submit(action)
		await get_tree().create_timer(0.3).timeout
	await get_tree().create_timer(3.0).timeout
	_save_shot("/tmp/citadels_table.png")
	# play a few human moves to reach mid-game state
	for i in range(60):
		var actor = Game._whose_turn()
		if actor != null and not actor["isBot"]:
			var action = Bot.get_bot_action(Game.state, Game.human_id)
			if action != null:
				Game.submit(action)
		if Game.state["round"] >= 3:
			break
		await get_tree().create_timer(0.3).timeout
	await get_tree().create_timer(1.5).timeout
	_save_shot("/tmp/citadels_midgame.png")
	get_tree().quit(0)


func _save_shot(path: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("[shot] saved %s" % path)


# Headless smoke test: boots the real UI, starts a game, and auto-plays the
# human seat with the bot brain until the game ends. Exits 0 on success.
func _run_smoke() -> void:
	print("[smoke] starting")
	Game.bot_delay = 0.01
	_start_game(3)
	var iterations := 0
	while iterations < 3000:
		iterations += 1
		await get_tree().create_timer(0.02).timeout
		if Game.state == null:
			continue
		if Game.state["phase"] == "gameOver":
			break
		# If it's the human's move, let the bot brain play the human seat
		# through the same submit() path the UI buttons use.
		var actor = Game._whose_turn()
		if actor != null and not actor["isBot"]:
			var action = Bot.get_bot_action(Game.state, Game.human_id)
			if action == null:
				print("[smoke] FAIL: no action for human seat")
				get_tree().quit(1)
				return
			Game.submit(action)
	# Let the score overlay build
	await get_tree().create_timer(0.2).timeout
	if Game.state != null and Game.state["phase"] == "gameOver":
		print("[smoke] game completed in %d ticks — OK" % iterations)
		get_tree().quit(0)
	else:
		print("[smoke] FAIL: game did not finish (phase=%s)" % (Game.state["phase"] if Game.state != null else "null"))
		get_tree().quit(1)


func _show_menu() -> void:
	if _board != null:
		_board.queue_free()
		_board = null
	_menu = MainMenu.new()
	_menu.start_requested.connect(_start_game)
	add_child(_menu)


func _start_game(num_bots: int) -> void:
	if _menu != null:
		_menu.queue_free()
		_menu = null
	_board = GameBoard.new()
	add_child(_board)
	Game.new_game(num_bots)
