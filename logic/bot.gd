# Port of packages/game-logic/src/bot.ts
# AI: get_bot_action(state, player_id) -> action Dictionary (or null).
class_name Bot


static func get_bot_action(state: Dictionary, bot_player_id: String):
	var actions := GameEngine.get_available_actions(state, bot_player_id)
	var player = Utils.find_item(state["players"], func(p): return p["id"] == bot_player_id)
	if player == null:
		return null

	# Graveyard decision (recover destroyed district for 1 gold?)
	if actions["canGraveyardDecide"] and state["pendingGraveyard"] != null:
		var card: Dictionary = state["pendingGraveyard"]["card"]
		var worth_it: bool = (
			player["gold"] >= 1
			and not player["city"].any(func(d): return d["name"] == card["name"])
			and (card["cost"] >= 2 or player["hand"].size() <= 1)
		)
		return {"type": "GRAVEYARD_RECOVER" if worth_it else "GRAVEYARD_PASS", "playerId": bot_player_id}

	# Character choosing phase
	if actions["canChooseCharacter"] and actions["availableCharacters"].size() > 0:
		var rank := choose_bot_character(state, player, actions["availableCharacters"])
		return {"type": "CHOOSE_CHARACTER", "playerId": bot_player_id, "characterRank": rank}

	# Card choosing phase (drew cards, must pick one)
	if actions["canKeepCard"] and actions["drawnCards"].size() > 0:
		var best_index := choose_best_card(player, actions["drawnCards"])
		return {"type": "KEEP_CARD", "playerId": bot_player_id, "cardIndex": best_index}

	# Player turn phase
	if state["phase"] == "playerTurns" and player["characterCard"] != null and player["characterCard"]["rank"] == state["currentCharacterRank"]:
		return get_bot_turn_action(state, player, actions)

	return null


static func get_bot_turn_action(state: Dictionary, player: Dictionary, actions: Dictionary):
	var player_id: String = player["id"]

	# Use power before action for Assassin/Thief
	if actions["canAssassinKill"]:
		var target := choose_assassin_target(state, player)
		return {"type": "ASSASSIN_KILL", "playerId": player_id, "targetRank": target}

	if actions["canThiefSteal"]:
		var target := choose_thief_target(state, player)
		return {"type": "THIEF_STEAL", "playerId": player_id, "targetRank": target}

	# Take action if not yet taken
	if actions["canTakeGold"] or actions["canDrawCards"]:
		if should_take_gold(player):
			return {"type": "TAKE_GOLD", "playerId": player_id}
		if actions["canDrawCards"]:
			return {"type": "DRAW_CARDS", "playerId": player_id}
		return {"type": "TAKE_GOLD", "playerId": player_id}

	# Use Magician power after action
	if actions["canMagicianSwap"]:
		var swap_action = choose_magician_action(state, player)
		if swap_action != null:
			return swap_action

	# Collect income
	if actions["canCollectIncome"]:
		return {"type": "USE_POWER", "playerId": player_id}

	# Build district
	if actions["canBuildDistrict"] and actions["buildableCards"].size() > 0:
		var best = choose_best_build(player, actions["buildableCards"])
		if best != null:
			return {"type": "BUILD_DISTRICT", "playerId": player_id, "cardIndex": best}

	# Use Warlord power
	if actions["canWarlordDestroy"]:
		var destroy_action = choose_warlord_target(state, player)
		if destroy_action != null:
			return destroy_action
		return {"type": "WARLORD_PASS", "playerId": player_id}

	# End turn
	if actions["canEndTurn"]:
		return {"type": "END_TURN", "playerId": player_id}

	return null


# ── Character selection strategy ────────────────────────────────

static func choose_bot_character(state: Dictionary, player: Dictionary, available: Array) -> int:
	# Score each available character
	var best_rank: int = available[0]["rank"]
	var best_score := -INF

	for character in available:
		var score := 0.0

		match character["name"]:
			"Assassin":
				# Good when others are close to winning
				score = 8.0 if get_max_opponent_city_size(state, player) >= 6 else 3.0
			"Thief":
				# Good when we need gold
				score = 6.0 if player["gold"] < 3 else 3.0
			"Magician":
				# Good when hand is bad or empty
				score = 6.0 if player["hand"].size() <= 1 else 2.0
			"King":
				# Good for yellow districts and crown control
				score = 4.0 + count_district_type(player, "noble") * 2.0
			"Bishop":
				# Good for blue districts and protection
				score = 3.0 + count_district_type(player, "religious") * 2.0
				if get_max_opponent_city_size(state, player) >= 6:
					score += 3.0 # protection is valuable late
			"Merchant":
				# Good for green districts and gold
				score = 5.0 + count_district_type(player, "trade") * 2.0
			"Architect":
				# Good when we have gold and cards to build
				score = 8.0 if (player["gold"] >= 4 and player["hand"].size() >= 2) else 2.0
			"Warlord":
				# Good for red districts and disrupting leaders
				score = 3.0 + count_district_type(player, "military") * 2.0
				if get_max_opponent_city_size(state, player) >= 6:
					score += 4.0

		# Add some randomness
		score += randf() * 2.0

		if score > best_score:
			best_score = score
			best_rank = character["rank"]

	return best_rank


# ── Action strategies ───────────────────────────────────────────

static func should_take_gold(player: Dictionary) -> bool:
	# Take gold if we have buildable cards but not enough money
	var buildable: Array = player["hand"].filter(func(c):
		return not player["city"].any(func(d): return d["name"] == c["name"]))
	buildable.sort_custom(func(a, b): return a["cost"] < b["cost"])
	var cheapest_buildable = buildable[0] if buildable.size() > 0 else null

	if cheapest_buildable != null and player["gold"] < cheapest_buildable["cost"]:
		return true
	if player["hand"].size() >= 5:
		return true # plenty of cards
	if player["gold"] < 2:
		return true
	return false


static func choose_best_card(player: Dictionary, drawn_cards: Array) -> int:
	var best_index := 0
	var best_score := -INF

	for i in range(drawn_cards.size()):
		var card: Dictionary = drawn_cards[i]
		var score: float = card["cost"] # higher cost = more points

		# Prefer types we don't have
		if not player["city"].any(func(d): return d["type"] == card["type"]):
			score += 3
		# Avoid duplicates in hand
		if player["hand"].any(func(c): return c["name"] == card["name"]):
			score -= 5
		# Avoid duplicates in city
		if player["city"].any(func(d): return d["name"] == card["name"]):
			score -= 10
		# Prefer affordable
		if card["cost"] <= player["gold"] + 2:
			score += 2
		# Prefer special districts
		if card["type"] == "special":
			score += 2

		if score > best_score:
			best_score = score
			best_index = i

	return best_index


static func choose_best_build(player: Dictionary, buildable: Array):
	if buildable.size() == 0:
		return null

	var best: Dictionary = buildable[0]
	var best_score := -INF

	for entry in buildable:
		var score: float = entry["card"]["cost"] # more expensive = more points

		# Strong preference for types we don't have in city
		if not player["city"].any(func(d): return d["type"] == entry["card"]["type"]):
			score += 5
		# Special districts are valuable
		if entry["card"]["type"] == "special":
			score += 3
		# Don't overspend if low on gold
		if player["gold"] - entry["card"]["cost"] < 1:
			score -= 2

		if score > best_score:
			best_score = score
			best = entry

	return best["index"]


static func choose_assassin_target(state: Dictionary, player: Dictionary) -> int:
	# Murder the player closest to winning
	var leader = get_leading_opponent(state, player)
	# Try to guess what character the leader would pick
	# Simple heuristic: target Architect (7) if leader has gold, Bishop (5) for protection
	if leader != null and leader["city"].size() >= 6 and leader["gold"] >= 4:
		return 7 # Architect
	if leader != null and leader["city"].size() >= 6:
		return 5 # Bishop (protection)
	# Random between King/Bishop/Merchant/Architect/Warlord
	var targets := [4, 5, 6, 7, 8]
	return targets[randi() % targets.size()]


static func choose_thief_target(state: Dictionary, _player: Dictionary) -> int:
	# Steal from characters likely to have gold
	var murdered = state["murderedCharacter"]
	var options: Array = [3, 4, 5, 6, 7, 8].filter(func(r): return r != murdered)
	# Prefer Merchant (6) or Architect (7) — likely to have gold
	if options.has(6):
		return 6
	if options.has(7):
		return 7
	return options[randi() % options.size()]


static func choose_magician_action(state: Dictionary, player: Dictionary):
	# If hand is mostly bad (expensive cards we can't afford, or duplicates), swap with richest player
	var bad_cards: Array = player["hand"].filter(func(c):
		return c["cost"] > player["gold"] + 4 or player["city"].any(func(d): return d["name"] == c["name"]))

	if bad_cards.size() >= player["hand"].size() / 2.0:
		# Swap with player who has the most cards
		var others: Array = state["players"].filter(func(p): return p["id"] != player["id"])
		others.sort_custom(func(a, b): return a["hand"].size() > b["hand"].size())
		var target = others[0] if others.size() > 0 else null
		if target != null and target["hand"].size() > player["hand"].size():
			return {"type": "MAGICIAN_SWAP_PLAYER", "playerId": player["id"], "targetPlayerId": target["id"]}

	# Otherwise, discard bad cards
	if bad_cards.size() > 0:
		var indices: Array = []
		for c in bad_cards:
			var idx: int = player["hand"].find(c)
			if idx != -1:
				indices.push_back(idx)
		if indices.size() > 0:
			return {"type": "MAGICIAN_SWAP_DECK", "playerId": player["id"], "cardIndices": indices}

	return null


static func choose_warlord_target(state: Dictionary, player: Dictionary):
	# Destroy cheapest district of the leader (if not Bishop)
	var opponents: Array = state["players"].filter(func(p):
		return p["id"] != player["id"] \
			and not (p["characterCard"] != null and p["characterCard"]["name"] == "Bishop") \
			and p["city"].size() < 8)

	var best_target = null # {playerId, districtIndex, cost}

	for opp in opponents:
		for i in range(opp["city"].size()):
			var d: Dictionary = opp["city"][i]
			if d["name"] == "Keep":
				continue
			var destroy_cost: int = maxi(0, d["cost"] - 1)
			var adjusted_cost := destroy_cost
			if opp["city"].any(func(x): return x["name"] == "Great Wall") and d["name"] != "Great Wall":
				adjusted_cost += 1
			if adjusted_cost <= player["gold"]:
				# Prefer destroying leaders' districts, especially cheap ones
				var priority: int = opp["city"].size() * 10 - adjusted_cost
				var best_priority := -1
				if best_target != null:
					var bt_player = Utils.find_item(state["players"], func(p): return p["id"] == best_target["playerId"])
					var bt_city_size: int = bt_player["city"].size() if bt_player != null else 0
					best_priority = bt_city_size * 10 - best_target["cost"]
				if best_target == null or priority > best_priority:
					best_target = {"playerId": opp["id"], "districtIndex": i, "cost": adjusted_cost}

	if best_target != null:
		return {
			"type": "WARLORD_DESTROY",
			"playerId": player["id"],
			"targetPlayerId": best_target["playerId"],
			"districtIndex": best_target["districtIndex"],
		}

	return null


# ── Helpers ──────────────────────────────────────────────────────

static func count_district_type(player: Dictionary, type: String) -> int:
	return player["city"].filter(func(d): return d["type"] == type).size()


static func get_max_opponent_city_size(state: Dictionary, player: Dictionary) -> int:
	var sizes: Array = state["players"].filter(func(p): return p["id"] != player["id"]).map(func(p): return p["city"].size())
	var max_size := 0
	for s in sizes:
		max_size = maxi(max_size, s)
	return max_size


static func get_leading_opponent(state: Dictionary, player: Dictionary):
	var opponents: Array = state["players"].filter(func(p): return p["id"] != player["id"])
	if opponents.size() == 0:
		return null
	opponents.sort_custom(func(a, b): return a["city"].size() > b["city"].size())
	return opponents[0]
