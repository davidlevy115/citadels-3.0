# Autoload "Game" — owns the GameState, processes actions, runs bot turns.
# The UI is a thin layer: it submits actions and reacts to signals.
extends Node

signal view_updated(view: Dictionary)
signal action_failed(error: String)
signal bot_thinking(player_name: String)
signal log_added(message: String)
signal game_over_reached
signal turn_changed

var state: Variant = null   # full GameState (server-side view)
var human_id := ""          # the human player's id
var bot_delay := 0.85       # seconds between bot moves (0 in tests)
var _bots_running := false
var _log_seen := 0


func new_game(num_bots: int, player_name := "You") -> void:
	var players: Array = [{"name": player_name, "isBot": false}]
	var bot_names := ["Aria", "Borin", "Cedric", "Dahlia", "Edmund", "Fiora"]
	for i in range(num_bots):
		players.push_back({"name": bot_names[i % bot_names.size()], "isBot": true})

	var result := GameEngine.create_game({"players": players})
	if Utils.is_err(result):
		action_failed.emit(result["__error"])
		return
	state = result
	human_id = state["players"][0]["id"]
	_log_seen = 0
	_emit_view()
	_run_bots()


# Human submits an action.
func submit(action: Dictionary) -> void:
	if state == null:
		return
	var result := GameEngine.process_action(state, action)
	if not result["ok"]:
		action_failed.emit(result["error"])
		return
	state = result["state"]
	_emit_view()
	_run_bots()


func view() -> Dictionary:
	return GameEngine.get_player_view(state, human_id)


func available_actions() -> Dictionary:
	return GameEngine.get_available_actions(state, human_id)


func human_player() -> Dictionary:
	return Utils.find_item(state["players"], func(p): return p["id"] == human_id)


# Who must act right now? Returns a player Dictionary or null.
func _whose_turn() -> Variant:
	if state == null or state["phase"] == "gameOver":
		return null
	if state["pendingGraveyard"] != null:
		return Utils.find_item(state["players"], func(p): return p["id"] == state["pendingGraveyard"]["playerId"])
	if state["phase"] == "chooseCharacters":
		return state["players"][state["choosingPlayerIndex"]]
	if state["phase"] == "playerTurns":
		return GameEngine.get_active_player(state)
	return null


func _run_bots() -> void:
	if _bots_running:
		return
	_bots_running = true
	var safety := 0
	while safety < 500:
		safety += 1
		var actor = _whose_turn()
		if actor == null or not actor["isBot"]:
			break
		bot_thinking.emit(actor["name"])
		if bot_delay > 0.0:
			await get_tree().create_timer(bot_delay).timeout
		# Re-check after await: game may have been reset
		if state == null:
			break
		var action = Bot.get_bot_action(state, actor["id"])
		if action == null:
			push_warning("Bot %s has no action — breaking." % actor["name"])
			break
		var result := GameEngine.process_action(state, action)
		if not result["ok"]:
			push_warning("Bot action failed: %s — %s" % [str(action), result["error"]])
			break
		state = result["state"]
		_emit_view()
	_bots_running = false
	if state != null and state["phase"] == "gameOver":
		game_over_reached.emit()


func _emit_view() -> void:
	# Emit new log lines individually (for the animated log panel)
	var entries: Array = state["log"]
	# Log is capped at 200 — track by total appended instead of size
	while _log_seen < entries.size():
		log_added.emit(entries[_log_seen]["message"])
		_log_seen += 1
	if _log_seen > entries.size():
		_log_seen = entries.size()
	view_updated.emit(view())
	turn_changed.emit()
	if state["phase"] == "gameOver":
		game_over_reached.emit()
