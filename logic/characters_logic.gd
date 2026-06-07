# Port of packages/game-logic/src/characters.ts
# Character power helpers: income collection, Architect draw, Warlord destroy
# cost, Observatory/Library draw logic.
class_name CharactersLogic


static func get_character_income_gold(_state: Dictionary, player: Dictionary) -> int:
	var character = player["characterCard"]
	if character == null:
		return 0
	var income_type = Constants.CHARACTER_INCOME_TYPE[character["name"]]
	if income_type == null:
		return 0

	var count := 0
	for district in player["city"]:
		if district["type"] == income_type:
			count += 1
		# School of Magic counts as any type for income
		if district["name"] == "School of Magic":
			count += 1
	return count


static func collect_income(state: Dictionary, player_index: int) -> Dictionary:
	var player: Dictionary = state["players"][player_index]
	var income := get_character_income_gold(state, player)
	if income > 0:
		var updated := player.duplicate()
		updated["gold"] = player["gold"] + income
		state["players"][player_index] = updated
		Utils.add_log(state, "%s collects %d gold income from districts." % [player["name"], income])
	return state


static func apply_merchant_bonus(state: Dictionary, player_index: int) -> Dictionary:
	var player: Dictionary = state["players"][player_index]
	var character = player["characterCard"]
	if character != null and character["name"] == "Merchant" and state["turnState"] != null and not state["turnState"]["merchantBonusTaken"]:
		var updated := player.duplicate()
		updated["gold"] = player["gold"] + 1
		state["players"][player_index] = updated
		state["turnState"]["merchantBonusTaken"] = true
		Utils.add_log(state, "%s receives 1 bonus gold as Merchant." % player["name"])
	return state


static func apply_architect_draw(state: Dictionary, player_index: int) -> Dictionary:
	var player: Dictionary = state["players"][player_index]
	var character = player["characterCard"]
	if character != null and character["name"] == "Architect":
		var drawn: Array = []
		for i in range(2):
			if state["districtDeck"].size() > 0:
				var card = state["districtDeck"].pop_front()
				state["players"][player_index]["hand"].push_back(card)
				drawn.push_back(card["name"])
		if drawn.size() > 0:
			Utils.add_log(state, "%s draws %d extra cards as Architect." % [player["name"], drawn.size()])
	return state


# Returns null when the Warlord may destroy, otherwise an error message string.
static func can_warlord_destroy(state: Dictionary, target_player_id: String, district_index: int, shorter_game: bool):
	var target_player = Utils.find_item(state["players"], func(p): return p["id"] == target_player_id)
	if target_player == null:
		return "Target player not found."

	# Cannot destroy in completed city
	var limit := 7 if shorter_game else 8
	if target_player["city"].size() >= limit:
		return "Cannot destroy districts in a completed city."

	# Cannot destroy Bishop's districts
	if target_player["characterCard"] != null and target_player["characterCard"]["name"] == "Bishop":
		return "Cannot destroy the Bishop's districts."

	if district_index < 0 or district_index >= target_player["city"].size():
		return "District not found."
	var district: Dictionary = target_player["city"][district_index]

	# Cannot destroy Keep
	if district["name"] == "Keep":
		return "The Keep cannot be destroyed."

	# Check cost
	var warlord = Utils.find_item(state["players"], func(p): return p["characterCard"] != null and p["characterCard"]["name"] == "Warlord")
	if warlord == null:
		return "No Warlord found."

	var destroy_cost: int = district["cost"] - 1
	# Great Wall makes it cost +1 for other districts
	if target_player["city"].any(func(d): return d["name"] == "Great Wall") and district["name"] != "Great Wall":
		destroy_cost += 1

	if warlord["gold"] < destroy_cost:
		return "Not enough gold. Need %d, have %d." % [destroy_cost, warlord["gold"]]

	return null # can destroy


static func get_warlord_destroy_cost(state: Dictionary, target_player_id: String, district_index: int) -> int:
	var target_player = Utils.find_item(state["players"], func(p): return p["id"] == target_player_id)
	var district: Dictionary = target_player["city"][district_index]
	var cost: int = district["cost"] - 1
	if target_player["city"].any(func(d): return d["name"] == "Great Wall") and district["name"] != "Great Wall":
		cost += 1
	return maxi(0, cost)


static func get_cards_to_draw_count(player: Dictionary) -> int:
	if player["city"].any(func(d): return d["name"] == "Observatory"):
		return 3
	return 2


static func get_cards_to_keep_count(player: Dictionary) -> int:
	if player["city"].any(func(d): return d["name"] == "Library"):
		return -1 # keep all
	return 1
