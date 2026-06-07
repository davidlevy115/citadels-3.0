# Port of packages/game-logic/src/engine.ts
# Core state machine: create_game(), process_action(state, action) -> result,
# get_player_view(state, player_id), get_available_actions().
#
# Error handling: TS throws — here every handler returns either the new state
# Dictionary or Utils.err("message"). process_action wraps the result as
# {"ok": bool, "state": Dictionary, "error": String}.
class_name GameEngine


static func get_districts_to_win(config: Dictionary) -> int:
	return Constants.DISTRICTS_TO_WIN_SHORT if config.get("shorterGame", false) else Constants.DISTRICTS_TO_WIN


static func get_active_player(state: Dictionary):
	return Utils.find_item(state["players"], func(p):
		return p["characterCard"] != null and p["characterCard"]["rank"] == state["currentCharacterRank"])


static func get_active_player_index(state: Dictionary) -> int:
	return Utils.find_index(state["players"], func(p):
		return p["characterCard"] != null and p["characterCard"]["rank"] == state["currentCharacterRank"])


# ── Create game ─────────────────────────────────────────────────

static func create_game(config: Dictionary) -> Dictionary:
	if config["players"].size() < 2 or config["players"].size() > 7:
		return Utils.err("Citadels requires 2-7 players.")

	var district_deck: Array = Utils.shuffle_array(Constants.create_district_deck())

	var players: Array = []
	for p in config["players"]:
		var hand: Array = []
		for i in range(Constants.STARTING_HAND_SIZE):
			hand.push_back(district_deck.pop_front())
		players.push_back({
			"id": Utils.generate_id(),
			"name": p["name"],
			"gold": Constants.STARTING_GOLD,
			"hand": hand,
			"city": [],
			"characterCard": null,
			"isBot": p["isBot"],
			"botDifficulty": p.get("botDifficulty", null),
		})

	var state := {
		"id": Utils.generate_id(),
		"players": players,
		"phase": "removeCharacters",
		"round": 1,

		"characterDeck": Constants.CHARACTERS.duplicate(true),
		"districtDeck": district_deck,
		"districtDiscard": [],

		"removedCharactersFaceDown": [],
		"removedCharactersFaceUp": [],
		"availableCharacters": [],
		"choosingPlayerIndex": 0,

		"currentCharacterRank": 0,
		"turnState": null,
		"murderedCharacter": null,
		"robbedCharacter": null,
		"pendingGraveyard": null,

		"crownPlayerIndex": 0, # first player gets crown
		"firstToEightDistricts": null,
		"gameEndTriggered": false,

		"scores": null,
		"log": [],
	}

	Utils.add_log(state, "Game started with %d players." % players.size())
	return start_remove_characters(state)


# ── Phase: Remove Characters ────────────────────────────────────

static func start_remove_characters(state: Dictionary) -> Dictionary:
	state["phase"] = "removeCharacters"
	state["murderedCharacter"] = null
	state["robbedCharacter"] = null

	# Return all character cards and reset
	for player in state["players"]:
		player["characterCard"] = null
	state["characterDeck"] = Constants.CHARACTERS.duplicate(true)

	# Shuffle character deck
	Utils.shuffle_array(state["characterDeck"])

	# 1. Remove one card facedown (nobody sees it)
	state["removedCharactersFaceDown"] = [state["characterDeck"].pop_front()]
	state["removedCharactersFaceUp"] = []

	# 2. Remove faceup cards based on player count
	var num_players: int = state["players"].size()

	if num_players >= 4 and num_players <= 7:
		var face_up_count: int = Constants.FACEUP_REMOVED_BY_PLAYER_COUNT.get(num_players, 0)
		for i in range(face_up_count):
			var card: Dictionary = state["characterDeck"].pop_front()
			# Special rule: if King is drawn faceup, replace with another and shuffle King back
			if card["name"] == "King":
				state["characterDeck"].push_back(card)
				Utils.shuffle_array(state["characterDeck"])
				var replacement: Dictionary = state["characterDeck"].pop_front()
				state["removedCharactersFaceUp"].push_back(replacement)
			else:
				state["removedCharactersFaceUp"].push_back(card)

	# Remaining cards are available for choosing
	state["availableCharacters"] = state["characterDeck"].duplicate()
	state["characterDeck"] = []

	# Move to choose characters phase
	state["choosingPlayerIndex"] = state["crownPlayerIndex"]
	state["phase"] = "chooseCharacters"

	Utils.add_log(state, "Round %d: Character selection begins." % state["round"])
	return state


# ── Phase: Choose Characters ────────────────────────────────────

static func handle_choose_character(state: Dictionary, player_id: String, character_rank: int) -> Dictionary:
	var player_index := Utils.find_index(state["players"], func(p): return p["id"] == player_id)
	if player_index == -1:
		return Utils.err("Player not found.")

	# Determine choosing order based on crown
	var num_players: int = state["players"].size()
	var expected_chooser_index: int = state["choosingPlayerIndex"]

	if player_index != expected_chooser_index:
		return Utils.err("Not your turn to choose a character.")

	# Find the character in available pool
	var char_index := Utils.find_index(state["availableCharacters"], func(c): return c["rank"] == character_rank)
	if char_index == -1:
		return Utils.err("Character not available.")

	var character: Dictionary = state["availableCharacters"].pop_at(char_index)
	state["players"][player_index]["characterCard"] = character

	Utils.add_log(state, "%s chose a character." % state["players"][player_index]["name"])

	# Special handling for 2-player and 3-player games
	if num_players == 2:
		return handle_two_player_draft(state)
	if num_players == 3:
		return handle_three_player_draft(state)

	# Advance to next player
	state["choosingPlayerIndex"] = (state["choosingPlayerIndex"] + 1) % num_players

	# Check if all players have chosen
	var all_chosen: bool = state["players"].all(func(p): return p["characterCard"] != null)
	if all_chosen:
		# Last remaining card goes facedown
		if state["availableCharacters"].size() > 0:
			state["removedCharactersFaceDown"].append_array(state["availableCharacters"])
			state["availableCharacters"] = []
		return start_player_turns(state)

	# 7-player special: last player picks between remaining card and facedown card
	if num_players == 7:
		var players_with_cards: int = state["players"].filter(func(p): return p["characterCard"] != null).size()
		if players_with_cards == 6 and state["availableCharacters"].size() == 1:
			# Last player sees the facedown card too
			state["availableCharacters"].push_back(state["removedCharactersFaceDown"][0])
			state["removedCharactersFaceDown"] = []

	return state


static func handle_two_player_draft(state: Dictionary) -> Dictionary:
	# 2-player draft is complex: each player picks 2 characters
	# But our state only supports 1 characterCard per player.
	# For simplicity, 2-player uses standard draft (each player gets 1 character).
	# The full 2-player variant is a future enhancement. For now, advance normally.
	state["choosingPlayerIndex"] = (state["choosingPlayerIndex"] + 1) % state["players"].size()
	var all_chosen: bool = state["players"].all(func(p): return p["characterCard"] != null)
	if all_chosen:
		if state["availableCharacters"].size() > 0:
			state["removedCharactersFaceDown"].append_array(state["availableCharacters"])
			state["availableCharacters"] = []
		return start_player_turns(state)
	return state


static func handle_three_player_draft(state: Dictionary) -> Dictionary:
	# Same simplification as 2-player for now
	state["choosingPlayerIndex"] = (state["choosingPlayerIndex"] + 1) % state["players"].size()
	var all_chosen: bool = state["players"].all(func(p): return p["characterCard"] != null)
	if all_chosen:
		if state["availableCharacters"].size() > 0:
			state["removedCharactersFaceDown"].append_array(state["availableCharacters"])
			state["availableCharacters"] = []
		return start_player_turns(state)
	return state


# ── Phase: Player Turns ─────────────────────────────────────────

static func start_player_turns(state: Dictionary) -> Dictionary:
	state["phase"] = "playerTurns"
	state["currentCharacterRank"] = 0
	Utils.add_log(state, "Character selection complete. Calling characters...")
	return advance_to_next_character(state)


static func advance_to_next_character(state: Dictionary) -> Dictionary:
	state["currentCharacterRank"] += 1

	# Find if any player has this character
	while state["currentCharacterRank"] <= 8:
		var player_index := get_active_player_index(state)

		if player_index != -1:
			var player: Dictionary = state["players"][player_index]

			# Check if this character was murdered
			if state["murderedCharacter"] == state["currentCharacterRank"]:
				Utils.add_log(state, "%s was murdered! %s skips their turn." % [player["characterCard"]["name"], player["name"]])
				state["currentCharacterRank"] += 1
				continue

			# Start this player's turn
			Utils.add_log(state, "%s (#%d) is called. %s reveals." % [player["characterCard"]["name"], state["currentCharacterRank"], player["name"]])

			# King gets crown immediately
			if player["characterCard"]["name"] == "King":
				state["crownPlayerIndex"] = player_index
				Utils.add_log(state, "%s takes the Crown." % player["name"])

			# Check if robbed
			if state["robbedCharacter"] == state["currentCharacterRank"]:
				var thief = Utils.find_item(state["players"], func(p):
					return p["characterCard"] != null and p["characterCard"]["name"] == "Thief")
				if thief != null:
					var stolen: int = player["gold"]
					var updated_victim := player.duplicate()
					updated_victim["gold"] = 0
					state["players"][player_index] = updated_victim
					var thief_index := Utils.find_index(state["players"], func(p): return p["id"] == thief["id"])
					var updated_thief: Dictionary = thief.duplicate()
					updated_thief["gold"] = thief["gold"] + stolen
					state["players"][thief_index] = updated_thief
					Utils.add_log(state, "%s (Thief) steals %d gold from %s!" % [thief["name"], stolen, player["name"]])

			state["turnState"] = {
				"characterRank": state["currentCharacterRank"],
				"phase": "awaitingAction",
				"actionTaken": false,
				"powerUsed": false,
				"incomeCollected": false,
				"districtsBuilt": 0,
				"maxDistricts": 3 if state["players"][player_index]["characterCard"]["name"] == "Architect" else 1,
				"drawnCards": [],
				"merchantBonusTaken": false,
				"specialBuildingsUsed": [],
			}

			return state

		state["currentCharacterRank"] += 1

	# All characters called — end of round
	return end_round(state)


# ── Turn actions ────────────────────────────────────────────────

static func handle_take_gold(state: Dictionary, player_id: String) -> Dictionary:
	var validation := validate_turn_action(state, player_id)
	if Utils.is_err(validation):
		return validation
	var player_index: int = validation["index"]
	var player: Dictionary = state["players"][player_index]

	var updated := player.duplicate()
	updated["gold"] = player["gold"] + 2
	state["players"][player_index] = updated
	state["turnState"]["actionTaken"] = true
	state["turnState"]["phase"] = "actionTaken"
	Utils.add_log(state, "%s takes 2 gold. (Total: %d)" % [player["name"], player["gold"] + 2])

	# Merchant bonus: +1 gold after action
	state = CharactersLogic.apply_merchant_bonus(state, player_index)

	# Architect: draw 2 extra cards after action
	state = CharactersLogic.apply_architect_draw(state, player_index)

	return state


static func handle_draw_cards(state: Dictionary, player_id: String) -> Dictionary:
	var validation := validate_turn_action(state, player_id)
	if Utils.is_err(validation):
		return validation
	var player_index: int = validation["index"]
	var player: Dictionary = state["players"][player_index]

	var draw_count := CharactersLogic.get_cards_to_draw_count(player)
	var keep_count := CharactersLogic.get_cards_to_keep_count(player)

	var drawn: Array = []
	for i in range(draw_count):
		if state["districtDeck"].size() > 0:
			drawn.push_back(state["districtDeck"].pop_front())

	if keep_count == -1 or drawn.size() <= 1:
		# Library: keep all drawn cards, or only 1 drawn
		var updated := player.duplicate()
		updated["hand"] = player["hand"] + drawn
		state["players"][player_index] = updated
		state["turnState"]["actionTaken"] = true
		state["turnState"]["phase"] = "actionTaken"
		Utils.add_log(state, "%s draws %d cards and keeps %s." % [player["name"], drawn.size(), "it" if drawn.size() == 1 else "all"])

		state = CharactersLogic.apply_merchant_bonus(state, player_index)
		state = CharactersLogic.apply_architect_draw(state, player_index)
	else:
		# Must choose which card to keep
		state["turnState"]["drawnCards"] = drawn
		state["turnState"]["phase"] = "choosingCard"
		Utils.add_log(state, "%s draws %d cards and must choose one to keep." % [player["name"], drawn.size()])

	return state


static func handle_keep_card(state: Dictionary, player_id: String, card_index: int) -> Dictionary:
	var player_index := Utils.find_index(state["players"], func(p): return p["id"] == player_id)
	if player_index == -1:
		return Utils.err("Player not found.")
	if state["turnState"] == null or state["turnState"]["phase"] != "choosingCard":
		return Utils.err("Not in card choosing phase.")

	var drawn: Array = state["turnState"]["drawnCards"]
	if card_index < 0 or card_index >= drawn.size():
		return Utils.err("Invalid card index.")

	var kept: Dictionary = drawn[card_index]
	var returned: Array = []
	for i in range(drawn.size()):
		if i != card_index:
			returned.push_back(drawn[i])

	var updated: Dictionary = state["players"][player_index].duplicate()
	updated["hand"] = state["players"][player_index]["hand"] + [kept]
	state["players"][player_index] = updated

	# Return unchosen cards to bottom of deck
	state["districtDeck"].append_array(returned)

	state["turnState"]["drawnCards"] = []
	state["turnState"]["actionTaken"] = true
	state["turnState"]["phase"] = "actionTaken"

	state = CharactersLogic.apply_merchant_bonus(state, player_index)
	state = CharactersLogic.apply_architect_draw(state, player_index)

	return state


static func handle_build_district(state: Dictionary, player_id: String, card_index: int) -> Dictionary:
	var player_index := Utils.find_index(state["players"], func(p): return p["id"] == player_id)
	if player_index == -1:
		return Utils.err("Player not found.")
	if state["turnState"] == null:
		return Utils.err("No active turn.")
	if not state["turnState"]["actionTaken"]:
		return Utils.err("Must take an action first.")
	if state["turnState"]["districtsBuilt"] >= state["turnState"]["maxDistricts"]:
		return Utils.err("Cannot build more than %d districts this turn." % state["turnState"]["maxDistricts"])

	var player: Dictionary = state["players"][player_index]
	if card_index < 0 or card_index >= player["hand"].size():
		return Utils.err("Invalid card index.")
	var card: Dictionary = player["hand"][card_index]
	if player["gold"] < card["cost"]:
		return Utils.err("Not enough gold. Need %d, have %d." % [card["cost"], player["gold"]])

	# Cannot build duplicate district
	if player["city"].any(func(d): return d["name"] == card["name"]):
		return Utils.err("You already have %s in your city." % card["name"])

	# Build it
	var new_hand: Array = player["hand"].duplicate()
	new_hand.pop_at(card_index)

	var updated := player.duplicate()
	updated["gold"] = player["gold"] - card["cost"]
	updated["hand"] = new_hand
	updated["city"] = player["city"] + [card.duplicate()]
	state["players"][player_index] = updated

	state["turnState"]["districtsBuilt"] += 1
	Utils.add_log(state, "%s builds %s (cost %d)." % [player["name"], card["name"], card["cost"]])

	# Check game end trigger
	var limit := Constants.DISTRICTS_TO_WIN # TODO: support shorter game
	if state["players"][player_index]["city"].size() >= limit and not state["gameEndTriggered"]:
		state["gameEndTriggered"] = true
		state["firstToEightDistricts"] = player["id"]
		Utils.add_log(state, "%s has built %d districts! This is the final round." % [player["name"], limit])

	return state


# ── Character powers ────────────────────────────────────────────

static func handle_assassin_kill(state: Dictionary, player_id: String, target_rank: int) -> Dictionary:
	var validation := validate_power_use(state, player_id, "Assassin")
	if Utils.is_err(validation):
		return validation
	var player_index: int = validation["index"]

	if target_rank < 2 or target_rank > 8:
		return Utils.err("Invalid target. Must be rank 2-8.")
	if target_rank == 1:
		return Utils.err("Cannot murder the Assassin.")

	state["murderedCharacter"] = target_rank
	state["turnState"]["powerUsed"] = true

	var target_char = Utils.find_item(Constants.CHARACTERS, func(c): return c["rank"] == target_rank)
	Utils.add_log(state, "%s (Assassin) murders the %s!" % [state["players"][player_index]["name"], target_char["name"] if target_char != null else "unknown"])

	return state


static func handle_thief_steal(state: Dictionary, player_id: String, target_rank: int) -> Dictionary:
	var validation := validate_power_use(state, player_id, "Thief")
	if Utils.is_err(validation):
		return validation
	var player_index: int = validation["index"]

	if target_rank < 3 or target_rank > 8:
		return Utils.err("Invalid target. Must be rank 3-8.")
	if target_rank == 1:
		return Utils.err("Cannot steal from the Assassin.")
	if target_rank == 2:
		return Utils.err("Cannot steal from the Thief.")
	if state["murderedCharacter"] == target_rank:
		return Utils.err("Cannot steal from the murdered character.")

	state["robbedCharacter"] = target_rank
	state["turnState"]["powerUsed"] = true

	var target_char = Utils.find_item(Constants.CHARACTERS, func(c): return c["rank"] == target_rank)
	Utils.add_log(state, "%s (Thief) targets the %s for robbery." % [state["players"][player_index]["name"], target_char["name"] if target_char != null else "unknown"])

	return state


static func handle_magician_swap_player(state: Dictionary, player_id: String, target_player_id: String) -> Dictionary:
	var validation := validate_power_use(state, player_id, "Magician")
	if Utils.is_err(validation):
		return validation
	var player_index: int = validation["index"]
	var target_index := Utils.find_index(state["players"], func(p): return p["id"] == target_player_id)
	if target_index == -1:
		return Utils.err("Target player not found.")
	if target_index == player_index:
		return Utils.err("Cannot swap with yourself.")

	var my_hand: Array = state["players"][player_index]["hand"]
	var their_hand: Array = state["players"][target_index]["hand"]

	var updated_me: Dictionary = state["players"][player_index].duplicate()
	updated_me["hand"] = their_hand
	state["players"][player_index] = updated_me

	var updated_them: Dictionary = state["players"][target_index].duplicate()
	updated_them["hand"] = my_hand
	state["players"][target_index] = updated_them

	state["turnState"]["powerUsed"] = true
	Utils.add_log(state, "%s (Magician) swaps hands with %s." % [state["players"][player_index]["name"], state["players"][target_index]["name"]])

	return state


static func handle_magician_swap_deck(state: Dictionary, player_id: String, card_indices: Array) -> Dictionary:
	var validation := validate_power_use(state, player_id, "Magician")
	if Utils.is_err(validation):
		return validation
	var player_index: int = validation["index"]
	var player: Dictionary = state["players"][player_index]

	# Validate indices (unique, sorted descending)
	var unique := {}
	for idx in card_indices:
		unique[int(idx)] = true
	var sorted_indices: Array = unique.keys()
	sorted_indices.sort()
	sorted_indices.reverse()
	for idx in sorted_indices:
		if idx < 0 or idx >= player["hand"].size():
			return Utils.err("Invalid card index.")

	# Remove cards from hand (in reverse order to maintain indices)
	var new_hand: Array = player["hand"].duplicate()
	var discarded: Array = []
	for idx in sorted_indices:
		discarded.push_back(new_hand.pop_at(idx))

	# Put discarded at bottom of deck
	state["districtDeck"].append_array(discarded)

	# Draw same number from top
	var drawn: Array = []
	for i in range(discarded.size()):
		if state["districtDeck"].size() > 0:
			drawn.push_back(state["districtDeck"].pop_front())

	var updated := player.duplicate()
	updated["hand"] = new_hand + drawn
	state["players"][player_index] = updated
	state["turnState"]["powerUsed"] = true
	Utils.add_log(state, "%s (Magician) discards %d cards and draws %d new ones." % [player["name"], discarded.size(), drawn.size()])

	return state


static func handle_warlord_destroy(state: Dictionary, player_id: String, target_player_id: String, district_index: int) -> Dictionary:
	var validation := validate_power_use(state, player_id, "Warlord")
	if Utils.is_err(validation):
		return validation
	var player_index: int = validation["index"]

	var error = CharactersLogic.can_warlord_destroy(state, target_player_id, district_index, false)
	if error != null:
		return Utils.err(error)

	var target_player_index := Utils.find_index(state["players"], func(p): return p["id"] == target_player_id)
	var target_player: Dictionary = state["players"][target_player_index]
	var cost := CharactersLogic.get_warlord_destroy_cost(state, target_player_id, district_index)

	# Pay cost
	var updated_warlord: Dictionary = state["players"][player_index].duplicate()
	updated_warlord["gold"] = state["players"][player_index]["gold"] - cost
	state["players"][player_index] = updated_warlord

	# Remove district
	var new_city: Array = target_player["city"].duplicate()
	var removed: Dictionary = new_city.pop_at(district_index)
	var updated_target := target_player.duplicate()
	updated_target["city"] = new_city
	state["players"][target_player_index] = updated_target

	state["turnState"]["powerUsed"] = true
	Utils.add_log(state, "%s (Warlord) destroys %s in %s's city (paid %d gold)." % [state["players"][player_index]["name"], removed["name"], target_player["name"], cost])

	# Graveyard: owner may pay 1 gold to recover the destroyed district
	# (not allowed if the owner is the Warlord, or if the Graveyard itself was destroyed)
	var graveyard_owner = Utils.find_item(state["players"], func(p):
		return p["city"].any(func(d): return d["name"] == "Graveyard") and p["id"] != player_id)
	if graveyard_owner != null and removed["name"] != "Graveyard" and graveyard_owner["gold"] >= 1:
		state["pendingGraveyard"] = {"playerId": graveyard_owner["id"], "card": removed}
		Utils.add_log(state, "%s may use Graveyard to recover %s for 1 gold." % [graveyard_owner["name"], removed["name"]])
	else:
		state["districtDiscard"].push_back(removed)

	return state


static func handle_graveyard_recover(state: Dictionary, player_id: String) -> Dictionary:
	if state["pendingGraveyard"] == null:
		return Utils.err("No Graveyard decision pending.")
	if state["pendingGraveyard"]["playerId"] != player_id:
		return Utils.err("Not your Graveyard decision.")

	var player_index := Utils.find_index(state["players"], func(p): return p["id"] == player_id)
	var player: Dictionary = state["players"][player_index]
	if player["gold"] < 1:
		return Utils.err("Need 1 gold to use Graveyard.")

	var updated := player.duplicate()
	updated["gold"] = player["gold"] - 1
	updated["hand"] = player["hand"] + [state["pendingGraveyard"]["card"]]
	state["players"][player_index] = updated
	Utils.add_log(state, "%s uses Graveyard to recover %s for 1 gold." % [player["name"], state["pendingGraveyard"]["card"]["name"]])
	state["pendingGraveyard"] = null

	return state


static func handle_graveyard_pass(state: Dictionary, player_id: String) -> Dictionary:
	if state["pendingGraveyard"] == null:
		return Utils.err("No Graveyard decision pending.")
	if state["pendingGraveyard"]["playerId"] != player_id:
		return Utils.err("Not your Graveyard decision.")

	state["districtDiscard"].push_back(state["pendingGraveyard"]["card"])
	state["pendingGraveyard"] = null

	return state


static func handle_laboratory_discard(state: Dictionary, player_id: String, card_index: int) -> Dictionary:
	var player_index := Utils.find_index(state["players"], func(p): return p["id"] == player_id)
	if player_index == -1:
		return Utils.err("Player not found.")
	if state["turnState"] == null:
		return Utils.err("No active turn.")
	var character = state["players"][player_index]["characterCard"]
	if character == null or character["rank"] != state["currentCharacterRank"]:
		return Utils.err("Not your turn.")
	if state["turnState"]["specialBuildingsUsed"].has("Laboratory"):
		return Utils.err("Laboratory already used this turn.")

	var player: Dictionary = state["players"][player_index]
	if not player["city"].any(func(d): return d["name"] == "Laboratory"):
		return Utils.err("You do not have Laboratory built.")
	if player["hand"].size() == 0:
		return Utils.err("No cards to discard.")
	if card_index < 0 or card_index >= player["hand"].size():
		return Utils.err("Invalid card index.")

	var discarded: Dictionary = player["hand"][card_index]
	var new_hand: Array = player["hand"].duplicate()
	new_hand.pop_at(card_index)
	state["districtDiscard"].push_back(discarded)

	var updated := player.duplicate()
	updated["gold"] = player["gold"] + 2
	updated["hand"] = new_hand
	state["players"][player_index] = updated
	state["turnState"]["specialBuildingsUsed"].push_back("Laboratory")
	Utils.add_log(state, "%s uses Laboratory: discards %s for 2 gold." % [player["name"], discarded["name"]])

	return state


static func handle_smithy_draw(state: Dictionary, player_id: String) -> Dictionary:
	var player_index := Utils.find_index(state["players"], func(p): return p["id"] == player_id)
	if player_index == -1:
		return Utils.err("Player not found.")
	if state["turnState"] == null:
		return Utils.err("No active turn.")
	var character = state["players"][player_index]["characterCard"]
	if character == null or character["rank"] != state["currentCharacterRank"]:
		return Utils.err("Not your turn.")
	if state["turnState"]["specialBuildingsUsed"].has("Smithy"):
		return Utils.err("Smithy already used this turn.")

	var player: Dictionary = state["players"][player_index]
	if not player["city"].any(func(d): return d["name"] == "Smithy"):
		return Utils.err("You do not have Smithy built.")
	if player["gold"] < 2:
		return Utils.err("Need at least 2 gold to use Smithy.")

	var drawn: Array = []
	for i in range(3):
		if state["districtDeck"].size() > 0:
			drawn.push_back(state["districtDeck"].pop_front())

	var updated := player.duplicate()
	updated["gold"] = player["gold"] - 2
	updated["hand"] = player["hand"] + drawn
	state["players"][player_index] = updated
	state["turnState"]["specialBuildingsUsed"].push_back("Smithy")
	Utils.add_log(state, "%s uses Smithy: pays 2 gold, draws %d cards." % [player["name"], drawn.size()])

	return state


static func handle_collect_income(state: Dictionary, player_id: String) -> Dictionary:
	var player_index := Utils.find_index(state["players"], func(p): return p["id"] == player_id)
	if player_index == -1:
		return Utils.err("Player not found.")
	if state["turnState"] == null:
		return Utils.err("No active turn.")
	if state["turnState"]["incomeCollected"]:
		return Utils.err("Income already collected this turn.")
	state = CharactersLogic.collect_income(state, player_index)
	state["turnState"]["incomeCollected"] = true
	return state


# ── End turn ────────────────────────────────────────────────────

static func handle_end_turn(state: Dictionary, player_id: String) -> Dictionary:
	var player_index := Utils.find_index(state["players"], func(p): return p["id"] == player_id)
	if player_index == -1:
		return Utils.err("Player not found.")
	if state["turnState"] == null:
		return Utils.err("No active turn.")
	if not state["turnState"]["actionTaken"]:
		return Utils.err("Must take an action before ending turn.")

	state["turnState"]["phase"] = "turnOver"
	return advance_to_next_character(state)


# ── End round ───────────────────────────────────────────────────

static func end_round(state: Dictionary) -> Dictionary:
	# Check if murdered King — heir gets crown
	if state["murderedCharacter"] == 4:
		var king_player = Utils.find_item(state["players"], func(p):
			return p["characterCard"] != null and p["characterCard"]["name"] == "King")
		if king_player != null:
			var king_idx := Utils.find_index(state["players"], func(p): return p["id"] == king_player["id"])
			state["crownPlayerIndex"] = king_idx
			Utils.add_log(state, "%s (murdered King's heir) takes the Crown." % king_player["name"])

	# Check game end
	if state["gameEndTriggered"]:
		return end_game(state)

	# New round
	state["round"] += 1
	state["turnState"] = null
	return start_remove_characters(state)


# ── Game end ────────────────────────────────────────────────────

static func end_game(state: Dictionary) -> Dictionary:
	state["phase"] = "gameOver"
	state["turnState"] = null

	state["scores"] = Scoring.calculate_scores(state, false)
	var winner := Scoring.determine_winner(state["scores"], state["players"])

	Utils.add_log(state, "Game over! %s wins with %d points!" % [winner["playerName"], winner["totalPoints"]])

	return state


# ── Validation helpers ──────────────────────────────────────────

static func validate_turn_action(state: Dictionary, player_id: String) -> Dictionary:
	var player_index := Utils.find_index(state["players"], func(p): return p["id"] == player_id)
	if player_index == -1:
		return Utils.err("Player not found.")
	if state["turnState"] == null:
		return Utils.err("No active turn.")
	var character = state["players"][player_index]["characterCard"]
	if character == null or character["rank"] != state["currentCharacterRank"]:
		return Utils.err("Not your turn.")
	if state["turnState"]["actionTaken"]:
		return Utils.err("Action already taken.")
	return {"index": player_index}


static func validate_power_use(state: Dictionary, player_id: String, expected_character: String) -> Dictionary:
	var player_index := Utils.find_index(state["players"], func(p): return p["id"] == player_id)
	if player_index == -1:
		return Utils.err("Player not found.")
	if state["turnState"] == null:
		return Utils.err("No active turn.")
	var character = state["players"][player_index]["characterCard"]
	if character == null or character["name"] != expected_character:
		return Utils.err("You are not the %s." % expected_character)
	if state["turnState"]["powerUsed"]:
		return Utils.err("Power already used this turn.")
	return {"index": player_index}


# ── Process action (main entry point) ───────────────────────────
# Returns {"ok": true, "state": Dictionary} or {"ok": false, "error": String}.

static func process_action(state: Dictionary, action: Dictionary) -> Dictionary:
	state = Utils.clone_state(state)

	# A pending Graveyard decision blocks everything else
	if state["pendingGraveyard"] != null and action["type"] != "GRAVEYARD_RECOVER" and action["type"] != "GRAVEYARD_PASS":
		return _result(Utils.err("Waiting for the Graveyard owner to decide."))

	match action["type"]:
		"START_GAME":
			return _result(state) # game starts in create_game

		"CHOOSE_CHARACTER":
			if state["phase"] != "chooseCharacters":
				return _result(Utils.err("Not in character choosing phase."))
			return _result(handle_choose_character(state, action["playerId"], action["characterRank"]))

		"TAKE_GOLD":
			if state["phase"] != "playerTurns":
				return _result(Utils.err("Not in player turns phase."))
			return _result(handle_take_gold(state, action["playerId"]))

		"DRAW_CARDS":
			if state["phase"] != "playerTurns":
				return _result(Utils.err("Not in player turns phase."))
			return _result(handle_draw_cards(state, action["playerId"]))

		"KEEP_CARD":
			if state["phase"] != "playerTurns":
				return _result(Utils.err("Not in player turns phase."))
			return _result(handle_keep_card(state, action["playerId"], action["cardIndex"]))

		"BUILD_DISTRICT":
			if state["phase"] != "playerTurns":
				return _result(Utils.err("Not in player turns phase."))
			return _result(handle_build_district(state, action["playerId"], action["cardIndex"]))

		"USE_POWER":
			if state["phase"] != "playerTurns":
				return _result(Utils.err("Not in player turns phase."))
			return _result(handle_collect_income(state, action["playerId"]))

		"END_TURN":
			if state["phase"] != "playerTurns":
				return _result(Utils.err("Not in player turns phase."))
			return _result(handle_end_turn(state, action["playerId"]))

		"ASSASSIN_KILL":
			if state["phase"] != "playerTurns":
				return _result(Utils.err("Not in player turns phase."))
			return _result(handle_assassin_kill(state, action["playerId"], action["targetRank"]))

		"THIEF_STEAL":
			if state["phase"] != "playerTurns":
				return _result(Utils.err("Not in player turns phase."))
			return _result(handle_thief_steal(state, action["playerId"], action["targetRank"]))

		"MAGICIAN_SWAP_PLAYER":
			if state["phase"] != "playerTurns":
				return _result(Utils.err("Not in player turns phase."))
			return _result(handle_magician_swap_player(state, action["playerId"], action["targetPlayerId"]))

		"MAGICIAN_SWAP_DECK":
			if state["phase"] != "playerTurns":
				return _result(Utils.err("Not in player turns phase."))
			return _result(handle_magician_swap_deck(state, action["playerId"], action["cardIndices"]))

		"WARLORD_DESTROY":
			if state["phase"] != "playerTurns":
				return _result(Utils.err("Not in player turns phase."))
			return _result(handle_warlord_destroy(state, action["playerId"], action["targetPlayerId"], action["districtIndex"]))

		"WARLORD_PASS":
			if state["phase"] != "playerTurns":
				return _result(Utils.err("Not in player turns phase."))
			# Warlord chooses not to destroy — just mark power as used
			if state["turnState"] == null:
				return _result(Utils.err("No active turn."))
			state["turnState"]["powerUsed"] = true
			return _result(state)

		"LABORATORY_DISCARD":
			if state["phase"] != "playerTurns":
				return _result(Utils.err("Not in player turns phase."))
			return _result(handle_laboratory_discard(state, action["playerId"], action["cardIndex"]))

		"SMITHY_DRAW":
			if state["phase"] != "playerTurns":
				return _result(Utils.err("Not in player turns phase."))
			return _result(handle_smithy_draw(state, action["playerId"]))

		"GRAVEYARD_RECOVER":
			if state["phase"] != "playerTurns":
				return _result(Utils.err("Not in player turns phase."))
			return _result(handle_graveyard_recover(state, action["playerId"]))

		"GRAVEYARD_PASS":
			if state["phase"] != "playerTurns":
				return _result(Utils.err("Not in player turns phase."))
			return _result(handle_graveyard_pass(state, action["playerId"]))

		_:
			return _result(Utils.err("Unknown action type: %s" % str(action["type"])))


static func _result(state_or_err: Dictionary) -> Dictionary:
	if Utils.is_err(state_or_err):
		return {"ok": false, "error": state_or_err["__error"]}
	return {"ok": true, "state": state_or_err}


# ── Round events builder ────────────────────────────────────────

static var _re_murder: RegEx
static var _re_steal_target: RegEx
static var _re_stolen: RegEx
static var _re_swap: RegEx
static var _re_destroy: RegEx


static func _compile_regexes() -> void:
	if _re_murder != null:
		return
	_re_murder = RegEx.create_from_string("^(.+?) \\(Assassin\\) murders the (.+?)!")
	_re_steal_target = RegEx.create_from_string("^(.+?) \\(Thief\\) targets the (.+?) for robbery")
	_re_stolen = RegEx.create_from_string("^(.+?) \\(Thief\\) steals (\\d+) gold from (.+?)!")
	_re_swap = RegEx.create_from_string("^(.+?) \\(Magician\\) swaps hands with (.+?)\\.")
	_re_destroy = RegEx.create_from_string("^(.+?) \\(Warlord\\) destroys (.+?) in (.+?)'s city")


static func build_round_events(state: Dictionary) -> Array:
	_compile_regexes()
	var events: Array = []

	# Scan log entries from this round for targeting events
	for entry in state["log"]:
		var msg: String = entry["message"]

		# Assassin murder
		var murder_match := _re_murder.search(msg)
		if murder_match != null:
			events.push_back({
				"type": "murder",
				"actorName": murder_match.get_string(1),
				"actorCharacter": "Assassin",
				"targetCharacter": murder_match.get_string(2),
			})

		# Thief steal target
		var steal_match := _re_steal_target.search(msg)
		if steal_match != null:
			events.push_back({
				"type": "steal",
				"actorName": steal_match.get_string(1),
				"actorCharacter": "Thief",
				"targetCharacter": steal_match.get_string(2),
			})

		# Thief actual steal
		var stolen_match := _re_stolen.search(msg)
		if stolen_match != null:
			# Update existing steal event with victim name
			var existing = Utils.find_item(events, func(e):
				return e["type"] == "steal" and e["actorName"] == stolen_match.get_string(1))
			if existing != null:
				existing["targetPlayerName"] = stolen_match.get_string(3)
				existing["detail"] = "%s gold stolen" % stolen_match.get_string(2)

		# Magician swap
		var swap_match := _re_swap.search(msg)
		if swap_match != null:
			events.push_back({
				"type": "swap",
				"actorName": swap_match.get_string(1),
				"actorCharacter": "Magician",
				"targetPlayerName": swap_match.get_string(2),
			})

		# Warlord destroy
		var destroy_match := _re_destroy.search(msg)
		if destroy_match != null:
			events.push_back({
				"type": "destroy",
				"actorName": destroy_match.get_string(1),
				"actorCharacter": "Warlord",
				"targetPlayerName": destroy_match.get_string(3),
				"detail": destroy_match.get_string(2),
			})

	return events


# ── Player view ─────────────────────────────────────────────────

static func get_player_view(state: Dictionary, player_id: String) -> Dictionary:
	var my_index := Utils.find_index(state["players"], func(p): return p["id"] == player_id)
	var me = state["players"][my_index] if my_index != -1 else null
	var active_player_index := get_active_player_index(state)

	var players: Array = []
	for p in state["players"]:
		var revealed = null
		# Only show revealed character during playerTurns phase for characters already called
		if state["phase"] == "playerTurns" and p["characterCard"] != null and p["characterCard"]["rank"] <= state["currentCharacterRank"]:
			revealed = p["characterCard"]
		elif state["phase"] == "gameOver":
			revealed = p["characterCard"]
		players.push_back({
			"id": p["id"],
			"name": p["name"],
			"gold": p["gold"],
			"city": p["city"],
			"handSize": p["hand"].size(),
			"isBot": p["isBot"],
			"revealedCharacter": revealed,
		})

	var turn_state = null
	if active_player_index == my_index:
		turn_state = state["turnState"]
	elif state["turnState"] != null:
		turn_state = state["turnState"].duplicate(true)
		turn_state["drawnCards"] = [] # hide drawn cards from other players

	return {
		"id": state["id"],
		"phase": state["phase"],
		"round": state["round"],
		"myIndex": my_index,
		"players": players,
		"myHand": me["hand"] if me != null else [],
		"myCharacter": me["characterCard"] if me != null else null,

		"availableCharacters": state["availableCharacters"] if (state["phase"] == "chooseCharacters" and state["choosingPlayerIndex"] == my_index) else [],
		"isMyTurnToChoose": state["phase"] == "chooseCharacters" and state["choosingPlayerIndex"] == my_index,
		"removedCharactersFaceUp": state["removedCharactersFaceUp"],
		"removedCharactersFaceDownCount": state["removedCharactersFaceDown"].size(),

		"currentCharacterRank": state["currentCharacterRank"],
		"turnState": turn_state,
		"isMyTurn": state["phase"] == "playerTurns" and active_player_index == my_index,
		"pendingGraveyard": state["pendingGraveyard"],

		"crownPlayerIndex": state["crownPlayerIndex"],
		"gameEndTriggered": state["gameEndTriggered"],
		"firstToEightDistricts": state["firstToEightDistricts"],
		"scores": state["scores"],
		"log": state["log"],
		"districtDeckCount": state["districtDeck"].size(),

		"murderedCharacter": state["murderedCharacter"],
		"robbedCharacter": state["robbedCharacter"],
		"roundEvents": build_round_events(state),
	}


# ── Available actions ───────────────────────────────────────────

static func get_available_actions(state: Dictionary, player_id: String) -> Dictionary:
	var player_index := Utils.find_index(state["players"], func(p): return p["id"] == player_id)
	var player = state["players"][player_index] if player_index != -1 else null
	var turn = state["turnState"]

	var empty := {
		"canChooseCharacter": false,
		"availableCharacters": [],
		"canTakeGold": false,
		"canDrawCards": false,
		"canKeepCard": false,
		"drawnCards": [],
		"canBuildDistrict": false,
		"buildableCards": [],
		"canUsePower": false,
		"powerType": null,
		"canCollectIncome": false,
		"canEndTurn": false,
		"canAssassinKill": false,
		"canThiefSteal": false,
		"canMagicianSwap": false,
		"canWarlordDestroy": false,
		"canGraveyardDecide": false,
	}

	if player == null:
		return empty

	# A pending Graveyard decision blocks everything else
	if state["pendingGraveyard"] != null:
		var with_graveyard := empty.duplicate()
		with_graveyard["canGraveyardDecide"] = state["pendingGraveyard"]["playerId"] == player_id
		return with_graveyard

	# Character choosing phase
	if state["phase"] == "chooseCharacters" and state["choosingPlayerIndex"] == player_index:
		var choosing := empty.duplicate()
		choosing["canChooseCharacter"] = true
		choosing["availableCharacters"] = state["availableCharacters"]
		return choosing

	# Not in player turns or not this player's turn
	if state["phase"] != "playerTurns" or turn == null:
		return empty
	if player["characterCard"] == null or player["characterCard"]["rank"] != state["currentCharacterRank"]:
		return empty

	var is_awaiting_action: bool = not turn["actionTaken"]
	var is_choosing_card: bool = turn["phase"] == "choosingCard"
	var has_acted: bool = turn["actionTaken"]
	var can_build: bool = has_acted and turn["districtsBuilt"] < turn["maxDistricts"]

	# Find buildable cards
	var buildable_cards: Array = []
	if can_build:
		for i in range(player["hand"].size()):
			var card: Dictionary = player["hand"][i]
			if card["cost"] <= player["gold"] and not player["city"].any(func(d): return d["name"] == card["name"]):
				buildable_cards.push_back({"index": i, "card": card})

	# Character power availability
	var char_name = player["characterCard"]["name"] if player["characterCard"] != null else null
	var can_use_power: bool = not turn["powerUsed"]

	var actions := empty.duplicate()
	actions["canTakeGold"] = is_awaiting_action
	actions["canDrawCards"] = is_awaiting_action and state["districtDeck"].size() > 0
	actions["canKeepCard"] = is_choosing_card
	actions["drawnCards"] = turn["drawnCards"] if is_choosing_card else []
	actions["canBuildDistrict"] = buildable_cards.size() > 0
	actions["buildableCards"] = buildable_cards
	actions["canUsePower"] = can_use_power and not (char_name in ["Assassin", "Thief"])
	actions["powerType"] = char_name
	actions["canCollectIncome"] = has_acted and not turn["incomeCollected"] and (char_name in ["King", "Bishop", "Merchant", "Warlord"])
	actions["canEndTurn"] = has_acted and not is_choosing_card
	actions["canAssassinKill"] = can_use_power and char_name == "Assassin"
	actions["canThiefSteal"] = can_use_power and char_name == "Thief"
	actions["canMagicianSwap"] = can_use_power and char_name == "Magician"
	actions["canWarlordDestroy"] = can_use_power and char_name == "Warlord" and has_acted
	return actions
