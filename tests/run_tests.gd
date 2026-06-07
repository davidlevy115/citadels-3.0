# Port of packages/game-logic/src/__tests__/engine.test.ts (47 tests).
# Run headless:
#   godot --headless --path . --script tests/run_tests.gd
# Exits 0 when all tests pass, 1 otherwise.
extends SceneTree

var _passed := 0
var _failed := 0
var _current := ""


func _init() -> void:
	seed(Time.get_ticks_usec())

	test_game_creation()
	test_character_selection()
	test_player_turns()
	test_assassin()
	test_thief()
	test_magician()
	test_king()
	test_merchant()
	test_architect()
	test_warlord()
	test_graveyard()
	test_scoring()
	test_game_end()
	test_player_view()
	test_full_bot_simulation()

	print("")
	print("==========================================")
	print("  %d passed, %d failed" % [_passed, _failed])
	print("==========================================")
	quit(0 if _failed == 0 else 1)


# ── Assert helpers ──────────────────────────────────────────────

func t(name: String) -> void:
	_current = name


func check(cond: bool, detail := "") -> void:
	if cond:
		_passed += 1
		print("  ✓ %s" % _current)
	else:
		_failed += 1
		print("  ✗ FAIL: %s %s" % [_current, detail])


func check_eq(a, b) -> void:
	check(a == b, "(expected %s, got %s)" % [str(b), str(a)])


# Apply an action that must succeed; returns the new state.
func apply(state: Dictionary, action: Dictionary) -> Dictionary:
	var result := GameEngine.process_action(state, action)
	if not result["ok"]:
		_failed += 1
		print("  ✗ FAIL: %s — unexpected error: %s" % [_current, result["error"]])
		return state
	return result["state"]


# Apply an action that must fail; checks the error message contains substr.
func apply_err(state: Dictionary, action: Dictionary, substr := "") -> void:
	var result := GameEngine.process_action(state, action)
	if result["ok"]:
		check(false, "(expected error containing '%s' but action succeeded)" % substr)
	else:
		check(substr == "" or substr in result["error"], "(error was: %s)" % result["error"])


# ── Config helpers ──────────────────────────────────────────────

func make_config(num_players: int) -> Dictionary:
	var players: Array = []
	for i in range(num_players):
		players.push_back({"name": "Player %d" % (i + 1), "isBot": false})
	return {"players": players}


func make_bots_config(num_bots: int) -> Dictionary:
	var players: Array = [{"name": "Human", "isBot": false}]
	for i in range(num_bots):
		players.push_back({"name": "Bot %d" % (i + 1), "isBot": true})
	return {"players": players}


# Setup game in playerTurns phase with specified character ranks per player index.
func setup_with_characters(assignments: Dictionary) -> Dictionary:
	var state := GameEngine.create_game(make_config(4))

	state["phase"] = "playerTurns"
	state["availableCharacters"] = []

	for player_idx in assignments:
		var rank: int = assignments[player_idx]
		var character = Utils.find_item(Constants.CHARACTERS, func(c): return c["rank"] == rank)
		state["players"][player_idx]["characterCard"] = character.duplicate(true)

	var player0_rank: int = assignments[0]
	state["currentCharacterRank"] = player0_rank

	state["turnState"] = {
		"characterRank": player0_rank,
		"phase": "awaitingAction",
		"actionTaken": false,
		"powerUsed": false,
		"incomeCollected": false,
		"districtsBuilt": 0,
		"maxDistricts": 3 if player0_rank == 7 else 1,
		"drawnCards": [],
		"merchantBonusTaken": false,
		"specialBuildingsUsed": [],
	}

	return state


func setup_turn_phase() -> Dictionary:
	var state := GameEngine.create_game(make_config(4))
	for i in range(4):
		var player_idx: int = (state["crownPlayerIndex"] + i) % 4
		var char_rank: int = state["availableCharacters"][0]["rank"]
		state = apply(state, {"type": "CHOOSE_CHARACTER", "playerId": state["players"][player_idx]["id"], "characterRank": char_rank})
	return state


# ── Game creation ───────────────────────────────────────────────

func test_game_creation() -> void:
	print("\nGame creation")

	t("creates a game with correct number of players")
	var state := GameEngine.create_game(make_config(4))
	check_eq(state["players"].size(), 4)

	t("gives each player 4 cards and 2 gold")
	state = GameEngine.create_game(make_config(4))
	var ok := true
	for p in state["players"]:
		ok = ok and p["hand"].size() == 4 and p["gold"] == 2
	check(ok)

	t("starts in chooseCharacters phase")
	state = GameEngine.create_game(make_config(4))
	check_eq(state["phase"], "chooseCharacters")

	t("rejects less than 2 players")
	check(Utils.is_err(GameEngine.create_game(make_config(1))))

	t("rejects more than 7 players")
	check(Utils.is_err(GameEngine.create_game(make_config(8))))

	t("removes correct faceup cards for 4 players (2 faceup)")
	state = GameEngine.create_game(make_config(4))
	check(state["removedCharactersFaceUp"].size() == 2
		and state["removedCharactersFaceDown"].size() == 1
		and state["availableCharacters"].size() == 5)

	t("removes correct faceup cards for 5 players (1 faceup)")
	state = GameEngine.create_game(make_config(5))
	check(state["removedCharactersFaceUp"].size() == 1 and state["availableCharacters"].size() == 6)

	t("removes 0 faceup cards for 6 players")
	state = GameEngine.create_game(make_config(6))
	check(state["removedCharactersFaceUp"].size() == 0 and state["availableCharacters"].size() == 7)

	t("first player gets the crown")
	state = GameEngine.create_game(make_config(4))
	check_eq(state["crownPlayerIndex"], 0)


# ── Character selection ─────────────────────────────────────────

func test_character_selection() -> void:
	print("\nCharacter selection")

	t("allows crown holder to choose first")
	var state := GameEngine.create_game(make_config(4))
	var actions := GameEngine.get_available_actions(state, state["players"][0]["id"])
	check(actions["canChooseCharacter"] and actions["availableCharacters"].size() > 0)

	t("prevents non-crown player from choosing first")
	state = GameEngine.create_game(make_config(4))
	actions = GameEngine.get_available_actions(state, state["players"][1]["id"])
	check_eq(actions["canChooseCharacter"], false)

	t("advances to next player after choosing")
	state = GameEngine.create_game(make_config(4))
	var first_char_rank: int = state["availableCharacters"][0]["rank"]
	state = apply(state, {"type": "CHOOSE_CHARACTER", "playerId": state["players"][0]["id"], "characterRank": first_char_rank})
	check(state["choosingPlayerIndex"] == 1 and state["players"][0]["characterCard"]["rank"] == first_char_rank)

	t("transitions to playerTurns after all choose")
	state = GameEngine.create_game(make_config(4))
	for i in range(4):
		var player_idx: int = (state["crownPlayerIndex"] + i) % 4
		var char_rank: int = state["availableCharacters"][0]["rank"]
		state = apply(state, {"type": "CHOOSE_CHARACTER", "playerId": state["players"][player_idx]["id"], "characterRank": char_rank})
	check_eq(state["phase"], "playerTurns")


# ── Player turns ────────────────────────────────────────────────

func test_player_turns() -> void:
	print("\nPlayer turns")

	t("calls characters in rank order")
	var state := setup_turn_phase()
	var min_rank := 99
	for p in state["players"]:
		min_rank = mini(min_rank, p["characterCard"]["rank"])
	check_eq(state["currentCharacterRank"], min_rank)

	t("allows taking gold")
	state = setup_turn_phase()
	var active_player = GameEngine.get_active_player(state)
	var gold_before: int = active_player["gold"]
	var new_state := apply(state, {"type": "TAKE_GOLD", "playerId": active_player["id"]})
	var updated = Utils.find_item(new_state["players"], func(p): return p["id"] == active_player["id"])
	check(updated["gold"] >= gold_before + 2)

	t("allows drawing cards")
	state = setup_turn_phase()
	active_player = GameEngine.get_active_player(state)
	new_state = apply(state, {"type": "DRAW_CARDS", "playerId": active_player["id"]})
	check(new_state["turnState"]["phase"] == "choosingCard" and new_state["turnState"]["drawnCards"].size() == 2)

	t("allows keeping a drawn card")
	state = setup_turn_phase()
	active_player = GameEngine.get_active_player(state)
	var hand_size_before: int = active_player["hand"].size()
	state = apply(state, {"type": "DRAW_CARDS", "playerId": active_player["id"]})
	state = apply(state, {"type": "KEEP_CARD", "playerId": active_player["id"], "cardIndex": 0})
	var updated2 = Utils.find_item(state["players"], func(p): return p["id"] == active_player["id"])
	check(updated2["hand"].size() == hand_size_before + 1 and state["turnState"]["actionTaken"] == true)

	t("prevents taking action twice")
	state = setup_turn_phase()
	active_player = GameEngine.get_active_player(state)
	state = apply(state, {"type": "TAKE_GOLD", "playerId": active_player["id"]})
	apply_err(state, {"type": "TAKE_GOLD", "playerId": active_player["id"]}, "Action already taken")

	t("prevents building before taking action")
	state = setup_turn_phase()
	active_player = GameEngine.get_active_player(state)
	apply_err(state, {"type": "BUILD_DISTRICT", "playerId": active_player["id"], "cardIndex": 0}, "Must take an action first")

	t("allows building after taking action")
	state = setup_turn_phase()
	active_player = GameEngine.get_active_player(state)
	var player_idx := Utils.find_index(state["players"], func(p): return p["id"] == active_player["id"])
	state["players"][player_idx]["gold"] = 20
	state = apply(state, {"type": "TAKE_GOLD", "playerId": active_player["id"]})
	var updated3 = Utils.find_item(state["players"], func(p): return p["id"] == active_player["id"])
	if updated3["hand"].size() > 0:
		var card: Dictionary = updated3["hand"][0]
		new_state = apply(state, {"type": "BUILD_DISTRICT", "playerId": active_player["id"], "cardIndex": 0})
		var final_player = Utils.find_item(new_state["players"], func(p): return p["id"] == active_player["id"])
		check(final_player["city"].size() == 1
			and final_player["city"][0]["name"] == card["name"]
			and final_player["gold"] == updated3["gold"] - card["cost"])
	else:
		check(true)

	t("prevents building duplicate districts")
	state = setup_turn_phase()
	active_player = GameEngine.get_active_player(state)
	player_idx = Utils.find_index(state["players"], func(p): return p["id"] == active_player["id"])
	var dup_card: Dictionary = state["players"][player_idx]["hand"][0]
	state["players"][player_idx]["gold"] = 20
	state["players"][player_idx]["city"] = [dup_card.duplicate(true)]
	state = apply(state, {"type": "TAKE_GOLD", "playerId": active_player["id"]})
	apply_err(state, {"type": "BUILD_DISTRICT", "playerId": active_player["id"], "cardIndex": 0}, "already have")

	t("ends turn and advances to next character")
	state = setup_turn_phase()
	active_player = GameEngine.get_active_player(state)
	var current_rank: int = state["currentCharacterRank"]
	state = apply(state, {"type": "TAKE_GOLD", "playerId": active_player["id"]})
	state = apply(state, {"type": "END_TURN", "playerId": active_player["id"]})
	check(state["currentCharacterRank"] > current_rank)


# ── Character powers ────────────────────────────────────────────

func test_assassin() -> void:
	print("\nCharacter powers — Assassin")

	t("murders a character")
	var state := setup_with_characters({0: 1, 1: 4, 2: 5, 3: 6})
	state = apply(state, {"type": "ASSASSIN_KILL", "playerId": state["players"][0]["id"], "targetRank": 4})
	check(state["murderedCharacter"] == 4 and state["turnState"]["powerUsed"] == true)

	t("cannot murder the Assassin (rank 1)")
	state = setup_with_characters({0: 1, 1: 4, 2: 5, 3: 6})
	apply_err(state, {"type": "ASSASSIN_KILL", "playerId": state["players"][0]["id"], "targetRank": 1})


func test_thief() -> void:
	print("\nCharacter powers — Thief")

	t("steals gold when target is called")
	var state := setup_with_characters({0: 2, 1: 4, 2: 5, 3: 6})
	state["players"][1]["gold"] = 10
	state = apply(state, {"type": "THIEF_STEAL", "playerId": state["players"][0]["id"], "targetRank": 4})
	check_eq(state["robbedCharacter"], 4)

	t("steal transfers gold when King is called")
	state = apply(state, {"type": "TAKE_GOLD", "playerId": state["players"][0]["id"]})
	state = apply(state, {"type": "END_TURN", "playerId": state["players"][0]["id"]})
	var king_player = Utils.find_item(state["players"], func(p): return p["characterCard"] != null and p["characterCard"]["rank"] == 4)
	var thief_player = Utils.find_item(state["players"], func(p): return p["characterCard"] != null and p["characterCard"]["rank"] == 2)
	check(king_player["gold"] == 0 and thief_player["gold"] >= 10)

	t("cannot steal from rank 1 or 2")
	state = setup_with_characters({0: 2, 1: 4, 2: 5, 3: 6})
	apply_err(state, {"type": "THIEF_STEAL", "playerId": state["players"][0]["id"], "targetRank": 1})
	t("cannot steal from rank 2")
	apply_err(state, {"type": "THIEF_STEAL", "playerId": state["players"][0]["id"], "targetRank": 2})

	t("cannot steal from murdered character")
	state = setup_with_characters({0: 2, 1: 4, 2: 5, 3: 6})
	state["murderedCharacter"] = 4
	apply_err(state, {"type": "THIEF_STEAL", "playerId": state["players"][0]["id"], "targetRank": 4})


func test_magician() -> void:
	print("\nCharacter powers — Magician")

	t("swaps hands with another player")
	var state := setup_with_characters({0: 3, 1: 4, 2: 5, 3: 6})
	var my_hand_ids: Array = state["players"][0]["hand"].map(func(c): return c["id"])
	var their_hand_ids: Array = state["players"][1]["hand"].map(func(c): return c["id"])
	state = apply(state, {"type": "MAGICIAN_SWAP_PLAYER", "playerId": state["players"][0]["id"], "targetPlayerId": state["players"][1]["id"]})
	check(state["players"][0]["hand"].map(func(c): return c["id"]) == their_hand_ids
		and state["players"][1]["hand"].map(func(c): return c["id"]) == my_hand_ids)

	t("discards and draws from deck")
	state = setup_with_characters({0: 3, 1: 4, 2: 5, 3: 6})
	var hand_size_before: int = state["players"][0]["hand"].size()
	state = apply(state, {"type": "MAGICIAN_SWAP_DECK", "playerId": state["players"][0]["id"], "cardIndices": [0, 1]})
	check(state["players"][0]["hand"].size() == hand_size_before and state["turnState"]["powerUsed"] == true)


func test_king() -> void:
	print("\nCharacter powers — King")

	t("gives crown when called")
	var state := setup_with_characters({0: 1, 1: 4, 2: 5, 3: 6})
	state["crownPlayerIndex"] = 2 # someone else has crown
	state = apply(state, {"type": "TAKE_GOLD", "playerId": state["players"][0]["id"]})
	state = apply(state, {"type": "END_TURN", "playerId": state["players"][0]["id"]})
	check_eq(state["crownPlayerIndex"], 1) # Player 1 (King)

	t("collects income from noble districts")
	state = setup_with_characters({0: 4, 1: 5, 2: 6, 3: 8})
	state["players"][0]["city"] = [
		{"id": "test1", "name": "Manor", "cost": 3, "type": "noble"},
		{"id": "test2", "name": "Castle", "cost": 4, "type": "noble"},
	]
	state = apply(state, {"type": "TAKE_GOLD", "playerId": state["players"][0]["id"]})
	var gold_after_action: int = state["players"][0]["gold"]
	state = apply(state, {"type": "USE_POWER", "playerId": state["players"][0]["id"]})
	check_eq(state["players"][0]["gold"], gold_after_action + 2) # 2 noble districts


func test_merchant() -> void:
	print("\nCharacter powers — Merchant")

	t("gets +1 gold after taking action")
	var state := setup_with_characters({0: 6, 1: 7, 2: 8, 3: 1})
	var gold_before: int = state["players"][0]["gold"]
	state = apply(state, {"type": "TAKE_GOLD", "playerId": state["players"][0]["id"]})
	check_eq(state["players"][0]["gold"], gold_before + 3) # +2 action, +1 Merchant


func test_architect() -> void:
	print("\nCharacter powers — Architect")

	t("draws 2 extra cards after action")
	var state := setup_with_characters({0: 7, 1: 8, 2: 1, 3: 2})
	var hand_size_before: int = state["players"][0]["hand"].size()
	state = apply(state, {"type": "TAKE_GOLD", "playerId": state["players"][0]["id"]})
	check_eq(state["players"][0]["hand"].size(), hand_size_before + 2)

	t("can build up to 3 districts")
	state = setup_with_characters({0: 7, 1: 8, 2: 1, 3: 2})
	check_eq(state["turnState"]["maxDistricts"], 3)


func test_warlord() -> void:
	print("\nCharacter powers — Warlord")

	t("destroys a district")
	var state := setup_with_characters({0: 8, 1: 4, 2: 5, 3: 6})
	state["players"][0]["gold"] = 20
	state["players"][1]["city"] = [{"id": "test1", "name": "Tavern", "cost": 1, "type": "trade"}]
	state = apply(state, {"type": "TAKE_GOLD", "playerId": state["players"][0]["id"]})
	state = apply(state, {"type": "WARLORD_DESTROY", "playerId": state["players"][0]["id"], "targetPlayerId": state["players"][1]["id"], "districtIndex": 0})
	check(state["players"][1]["city"].size() == 0 and state["players"][0]["gold"] == 22)

	t("cannot destroy the Keep")
	state = setup_with_characters({0: 8, 1: 4, 2: 5, 3: 6})
	state["players"][0]["gold"] = 20
	state["players"][1]["city"] = [{"id": "test1", "name": "Keep", "cost": 3, "type": "special"}]
	state = apply(state, {"type": "TAKE_GOLD", "playerId": state["players"][0]["id"]})
	apply_err(state, {"type": "WARLORD_DESTROY", "playerId": state["players"][0]["id"], "targetPlayerId": state["players"][1]["id"], "districtIndex": 0}, "Keep")

	t("cannot destroy Bishop districts")
	state = setup_with_characters({0: 8, 1: 5, 2: 4, 3: 6})
	state["players"][0]["gold"] = 20
	state["players"][1]["city"] = [{"id": "test1", "name": "Tavern", "cost": 1, "type": "trade"}]
	state = apply(state, {"type": "TAKE_GOLD", "playerId": state["players"][0]["id"]})
	apply_err(state, {"type": "WARLORD_DESTROY", "playerId": state["players"][0]["id"], "targetPlayerId": state["players"][1]["id"], "districtIndex": 0}, "Bishop")

	t("cannot destroy districts in completed city (8 districts)")
	state = setup_with_characters({0: 8, 1: 4, 2: 5, 3: 6})
	state["players"][0]["gold"] = 20
	var full_city: Array = []
	for i in range(8):
		full_city.push_back({"id": "test%d" % i, "name": "District%d" % i, "cost": 1, "type": "trade"})
	state["players"][1]["city"] = full_city
	state = apply(state, {"type": "TAKE_GOLD", "playerId": state["players"][0]["id"]})
	apply_err(state, {"type": "WARLORD_DESTROY", "playerId": state["players"][0]["id"], "targetPlayerId": state["players"][1]["id"], "districtIndex": 0}, "completed city")

	t("can destroy after building and collecting income")
	state = setup_with_characters({0: 8, 1: 4, 2: 5, 3: 6})
	state["players"][0]["gold"] = 20
	state["players"][0]["hand"] = [{"id": "h1", "name": "Watchtower", "cost": 1, "type": "military"}]
	state["players"][0]["city"] = [{"id": "c1", "name": "Battlefield", "cost": 3, "type": "military"}]
	state["players"][1]["city"] = [{"id": "t1", "name": "Tavern", "cost": 1, "type": "trade"}]
	state = apply(state, {"type": "TAKE_GOLD", "playerId": state["players"][0]["id"]})
	state = apply(state, {"type": "USE_POWER", "playerId": state["players"][0]["id"]})
	check(state["turnState"]["incomeCollected"] == true and state["turnState"]["powerUsed"] == false)
	t("can still build then destroy after income")
	state = apply(state, {"type": "BUILD_DISTRICT", "playerId": state["players"][0]["id"], "cardIndex": 0})
	state = apply(state, {"type": "WARLORD_DESTROY", "playerId": state["players"][0]["id"], "targetPlayerId": state["players"][1]["id"], "districtIndex": 0})
	check(state["turnState"]["powerUsed"] == true and state["players"][1]["city"].size() == 0)


func setup_graveyard_destroy(graveyard_owner_idx: int) -> Dictionary:
	var state := setup_with_characters({0: 8, 1: 4, 2: 5, 3: 6})
	state["players"][0]["gold"] = 20
	state["players"][1]["city"] = [{"id": "test1", "name": "Tavern", "cost": 1, "type": "trade"}]
	state["players"][graveyard_owner_idx]["gold"] = maxi(state["players"][graveyard_owner_idx]["gold"], 3)
	state["players"][graveyard_owner_idx]["city"] = state["players"][graveyard_owner_idx]["city"] + [{"id": "gy1", "name": "Graveyard", "cost": 5, "type": "special"}]
	state = apply(state, {"type": "TAKE_GOLD", "playerId": state["players"][0]["id"]})
	return apply(state, {"type": "WARLORD_DESTROY", "playerId": state["players"][0]["id"], "targetPlayerId": state["players"][1]["id"], "districtIndex": 0})


func test_graveyard() -> void:
	print("\nCharacter powers — Graveyard")

	t("offers the destroyed district to the Graveyard owner")
	var state := setup_graveyard_destroy(2)
	check(state["pendingGraveyard"] != null
		and state["pendingGraveyard"]["playerId"] == state["players"][2]["id"]
		and state["pendingGraveyard"]["card"]["name"] == "Tavern")

	t("blocks other actions while decision is pending")
	state = setup_graveyard_destroy(2)
	apply_err(state, {"type": "END_TURN", "playerId": state["players"][0]["id"]}, "Graveyard")

	t("owner pays 1 gold to recover the district")
	state = setup_graveyard_destroy(2)
	var gold_before: int = state["players"][2]["gold"]
	var hand_before: int = state["players"][2]["hand"].size()
	state = apply(state, {"type": "GRAVEYARD_RECOVER", "playerId": state["players"][2]["id"]})
	check(state["pendingGraveyard"] == null
		and state["players"][2]["gold"] == gold_before - 1
		and state["players"][2]["hand"].size() == hand_before + 1
		and state["players"][2]["hand"].any(func(c): return c["name"] == "Tavern"))

	t("owner may decline — card goes to the discard")
	state = setup_graveyard_destroy(2)
	gold_before = state["players"][2]["gold"]
	state = apply(state, {"type": "GRAVEYARD_PASS", "playerId": state["players"][2]["id"]})
	check(state["pendingGraveyard"] == null
		and state["players"][2]["gold"] == gold_before
		and state["districtDiscard"].any(func(c): return c["name"] == "Tavern"))

	t("another player cannot answer the decision")
	state = setup_graveyard_destroy(2)
	apply_err(state, {"type": "GRAVEYARD_RECOVER", "playerId": state["players"][3]["id"]}, "Not your Graveyard decision")

	t("the targeted player CAN use their own Graveyard")
	state = setup_graveyard_destroy(1)
	check(state["pendingGraveyard"] != null and state["pendingGraveyard"]["playerId"] == state["players"][1]["id"])

	t("the Warlord cannot use their own Graveyard")
	state = setup_with_characters({0: 8, 1: 4, 2: 5, 3: 6})
	state["players"][0]["gold"] = 20
	state["players"][0]["city"] = [{"id": "gy1", "name": "Graveyard", "cost": 5, "type": "special"}]
	state["players"][1]["city"] = [{"id": "test1", "name": "Tavern", "cost": 1, "type": "trade"}]
	state = apply(state, {"type": "TAKE_GOLD", "playerId": state["players"][0]["id"]})
	state = apply(state, {"type": "WARLORD_DESTROY", "playerId": state["players"][0]["id"], "targetPlayerId": state["players"][1]["id"], "districtIndex": 0})
	check(state["pendingGraveyard"] == null and state["districtDiscard"].any(func(c): return c["name"] == "Tavern"))

	t("destroying the Graveyard itself offers no recovery")
	state = setup_with_characters({0: 8, 1: 4, 2: 5, 3: 6})
	state["players"][0]["gold"] = 20
	state["players"][1]["gold"] = 5
	state["players"][1]["city"] = [{"id": "gy1", "name": "Graveyard", "cost": 5, "type": "special"}]
	state = apply(state, {"type": "TAKE_GOLD", "playerId": state["players"][0]["id"]})
	state = apply(state, {"type": "WARLORD_DESTROY", "playerId": state["players"][0]["id"], "targetPlayerId": state["players"][1]["id"], "districtIndex": 0})
	check(state["pendingGraveyard"] == null)

	t("no offer when owner has no gold")
	state = setup_with_characters({0: 8, 1: 4, 2: 5, 3: 6})
	state["players"][0]["gold"] = 20
	state["players"][1]["city"] = [{"id": "test1", "name": "Tavern", "cost": 1, "type": "trade"}]
	state["players"][2]["gold"] = 0
	state["players"][2]["city"] = [{"id": "gy1", "name": "Graveyard", "cost": 5, "type": "special"}]
	state = apply(state, {"type": "TAKE_GOLD", "playerId": state["players"][0]["id"]})
	state = apply(state, {"type": "WARLORD_DESTROY", "playerId": state["players"][0]["id"], "targetPlayerId": state["players"][1]["id"], "districtIndex": 0})
	check(state["pendingGraveyard"] == null)

	t("get_available_actions exposes the decision only to the owner")
	state = setup_graveyard_destroy(2)
	check(GameEngine.get_available_actions(state, state["players"][2]["id"])["canGraveyardDecide"] == true
		and GameEngine.get_available_actions(state, state["players"][0]["id"])["canGraveyardDecide"] == false
		and GameEngine.get_available_actions(state, state["players"][0]["id"])["canEndTurn"] == false)

	t("bot resolves the pending decision")
	state = setup_graveyard_destroy(2)
	var action = Bot.get_bot_action(state, state["players"][2]["id"])
	check(action != null and action["type"] in ["GRAVEYARD_RECOVER", "GRAVEYARD_PASS"])


# ── Scoring ─────────────────────────────────────────────────────

func test_scoring() -> void:
	print("\nScoring")

	t("scores district costs correctly")
	var state := {
		"players": [
			{"id": "p1", "name": "Player 1", "gold": 0, "hand": [], "city": [
				{"id": "d1", "name": "Manor", "cost": 3, "type": "noble"},
				{"id": "d2", "name": "Temple", "cost": 1, "type": "religious"},
			]},
		],
		"firstToEightDistricts": null,
	}
	var scores := Scoring.calculate_scores(state, false)
	check_eq(scores[0]["districtPoints"], 4)

	t("awards 3 points for all 5 colors")
	state = {
		"players": [
			{"id": "p1", "name": "Player 1", "gold": 0, "hand": [], "city": [
				{"id": "d1", "name": "Manor", "cost": 3, "type": "noble"},
				{"id": "d2", "name": "Temple", "cost": 1, "type": "religious"},
				{"id": "d3", "name": "Tavern", "cost": 1, "type": "trade"},
				{"id": "d4", "name": "Watchtower", "cost": 1, "type": "military"},
				{"id": "d5", "name": "Keep", "cost": 3, "type": "special"},
			]},
		],
		"firstToEightDistricts": null,
	}
	scores = Scoring.calculate_scores(state, false)
	check_eq(scores[0]["colorBonusPoints"], 3)

	t("awards 4 points for first to 8 districts")
	var city8: Array = []
	for i in range(8):
		city8.push_back({"id": "d%d" % i, "name": "D%d" % i, "cost": 1, "type": "trade"})
	state = {
		"players": [{"id": "p1", "name": "Player 1", "gold": 0, "hand": [], "city": city8}],
		"firstToEightDistricts": "p1",
	}
	scores = Scoring.calculate_scores(state, false)
	check_eq(scores[0]["firstToEightPoints"], 4)

	t("awards 2 points for others who reach 8")
	var city_a: Array = []
	var city_b: Array = []
	for i in range(8):
		city_a.push_back({"id": "d1%d" % i, "name": "A%d" % i, "cost": 1, "type": "trade"})
		city_b.push_back({"id": "d2%d" % i, "name": "B%d" % i, "cost": 2, "type": "noble"})
	state = {
		"players": [
			{"id": "p1", "name": "Player 1", "gold": 0, "hand": [], "city": city_a},
			{"id": "p2", "name": "Player 2", "gold": 0, "hand": [], "city": city_b},
		],
		"firstToEightDistricts": "p1",
	}
	scores = Scoring.calculate_scores(state, false)
	check(scores[0]["firstToEightPoints"] == 4 and scores[1]["otherEightPoints"] == 2)

	t("Dragon Gate and University score 8 points")
	state = {
		"players": [
			{"id": "p1", "name": "Player 1", "gold": 0, "hand": [], "city": [
				{"id": "d1", "name": "Dragon Gate", "cost": 6, "type": "special"},
				{"id": "d2", "name": "University", "cost": 6, "type": "special"},
			]},
		],
		"firstToEightDistricts": null,
	}
	scores = Scoring.calculate_scores(state, false)
	check_eq(scores[0]["districtPoints"], 16)

	t("Haunted City fills missing color for bonus")
	state = {
		"players": [
			{"id": "p1", "name": "Player 1", "gold": 0, "hand": [], "city": [
				{"id": "d1", "name": "Manor", "cost": 3, "type": "noble"},
				{"id": "d2", "name": "Temple", "cost": 1, "type": "religious"},
				{"id": "d3", "name": "Tavern", "cost": 1, "type": "trade"},
				{"id": "d4", "name": "Watchtower", "cost": 1, "type": "military"},
				{"id": "d5", "name": "Haunted City", "cost": 2, "type": "special"},
			]},
		],
		"firstToEightDistricts": null,
	}
	scores = Scoring.calculate_scores(state, false)
	check_eq(scores[0]["colorBonusPoints"], 3)


# ── Game end ────────────────────────────────────────────────────

func test_game_end() -> void:
	print("\nGame end")

	t("triggers game end when player builds 8th district")
	var state := GameEngine.create_game(make_config(4))
	state["phase"] = "playerTurns"

	state["players"][0]["characterCard"] = Constants.CHARACTERS[3].duplicate(true) # King (rank 4)
	state["players"][1]["characterCard"] = Constants.CHARACTERS[4].duplicate(true) # Bishop
	state["players"][2]["characterCard"] = Constants.CHARACTERS[5].duplicate(true) # Merchant
	state["players"][3]["characterCard"] = Constants.CHARACTERS[6].duplicate(true) # Architect

	state["currentCharacterRank"] = 4
	var city7: Array = []
	for i in range(7):
		city7.push_back({"id": "city%d" % i, "name": "District%d" % i, "cost": 1, "type": "trade"})
	state["players"][0]["gold"] = 20
	state["players"][0]["city"] = city7
	state["players"][0]["hand"] = [{"id": "new", "name": "UniqueDistrict", "cost": 1, "type": "noble"}]

	state["turnState"] = {
		"characterRank": 4,
		"phase": "awaitingAction",
		"actionTaken": false,
		"powerUsed": false,
		"incomeCollected": false,
		"districtsBuilt": 0,
		"maxDistricts": 1,
		"drawnCards": [],
		"merchantBonusTaken": false,
		"specialBuildingsUsed": [],
	}

	state = apply(state, {"type": "TAKE_GOLD", "playerId": state["players"][0]["id"]})
	state = apply(state, {"type": "BUILD_DISTRICT", "playerId": state["players"][0]["id"], "cardIndex": 0})

	check(state["gameEndTriggered"] == true and state["firstToEightDistricts"] == state["players"][0]["id"])


# ── Player view ─────────────────────────────────────────────────

func test_player_view() -> void:
	print("\nPlayer view")

	t("hides other players hands and characters")
	var state := GameEngine.create_game(make_config(4))
	for i in range(4):
		var player_idx: int = (state["crownPlayerIndex"] + i) % 4
		var char_rank: int = state["availableCharacters"][0]["rank"]
		state = apply(state, {"type": "CHOOSE_CHARACTER", "playerId": state["players"][player_idx]["id"], "characterRank": char_rank})

	var view := GameEngine.get_player_view(state, state["players"][0]["id"])

	var ok: bool = view["myCharacter"] != null

	# Other players' unrevealed characters should be null
	for i in range(1, view["players"].size()):
		var p: Dictionary = view["players"][i]
		if p["revealedCharacter"] != null and p["revealedCharacter"]["rank"] > state["currentCharacterRank"]:
			ok = false

	# I should see my hand
	ok = ok and view["myHand"].size() > 0

	# Other players should only show hand size
	for p in view["players"]:
		ok = ok and (p["handSize"] is int)

	check(ok)


# ── Full game simulation with bots ──────────────────────────────

func test_full_bot_simulation() -> void:
	print("\nFull game simulation with bots")

	t("plays a complete game without errors")
	var state := GameEngine.create_game({
		"players": [
			{"name": "Bot A", "isBot": true},
			{"name": "Bot B", "isBot": true},
			{"name": "Bot C", "isBot": true},
			{"name": "Bot D", "isBot": true},
		],
	})

	var safety := 0
	var max_iterations := 5000
	var last_phase := ""
	var stuck_count := 0

	while state["phase"] != "gameOver" and safety < max_iterations:
		safety += 1
		# Find which bot needs to act
		var bot_id = null

		if state["phase"] == "chooseCharacters":
			bot_id = state["players"][state["choosingPlayerIndex"]]["id"]
		elif state["phase"] == "playerTurns":
			var active = GameEngine.get_active_player(state)
			if active != null:
				bot_id = active["id"]
			# A pending Graveyard decision may belong to a non-active player
			if state["pendingGraveyard"] != null:
				bot_id = state["pendingGraveyard"]["playerId"]

		if bot_id == null:
			break

		var action = Bot.get_bot_action(state, bot_id)
		if action == null:
			break

		var result := GameEngine.process_action(state, action)
		if not result["ok"]:
			print("    bot action failed: %s — %s" % [str(action), result["error"]])
			break
		state = result["state"]

		# Detect stuck loops
		var turn_phase = state["turnState"]["phase"] if state["turnState"] != null else "none"
		var state_key := "%s-%s-%s-%s" % [state["phase"], state["round"], state["currentCharacterRank"], turn_phase]
		if state_key == last_phase:
			stuck_count += 1
			if stuck_count > 50:
				break
		else:
			stuck_count = 0
			last_phase = state_key

	var sim_ok: bool = state["phase"] == "gameOver" and state["scores"] != null and state["scores"].size() == 4
	t("game reaches gameOver with 4 scores")
	check(sim_ok, "(phase=%s after %d iterations)" % [state["phase"], safety])

	t("winner has the highest score and positive points")
	if state["scores"] != null:
		var sorted: Array = state["scores"].duplicate()
		sorted.sort_custom(func(a, b): return a["totalPoints"] > b["totalPoints"])
		check(sorted[0]["totalPoints"] > 0)
	else:
		check(false, "(no scores)")
