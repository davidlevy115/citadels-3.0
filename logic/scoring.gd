# Port of packages/game-logic/src/scoring.ts
# End-game point calculation.
class_name Scoring

const ALL_TYPES := ["noble", "religious", "trade", "military", "special"]


static func calculate_scores(state: Dictionary, shorter_game: bool) -> Array:
	var limit := 7 if shorter_game else 8

	var scores: Array = []
	for player in state["players"]:
		# 1. Total cost of districts
		var district_points := 0
		for d in player["city"]:
			# Dragon Gate and University are worth 8 instead of their cost
			if d["name"] == "Dragon Gate" or d["name"] == "University":
				district_points += 8
			else:
				district_points += d["cost"]

		# 2. Color bonus: 3 points for having all 5 types
		var types := {}
		for d in player["city"]:
			if d["name"] == "Haunted City":
				# Haunted City: counts as any type — handled below
				pass
			else:
				types[d["type"]] = true

		# Haunted City: if player has it and is missing exactly 1 type, it fills that gap
		var has_haunted_city: bool = player["city"].any(func(d): return d["name"] == "Haunted City")
		var color_bonus_points := 0
		if has_haunted_city:
			var missing := ALL_TYPES.filter(func(t): return not types.has(t))
			if missing.size() <= 1:
				color_bonus_points = 3
		elif ALL_TYPES.all(func(t): return types.has(t)):
			color_bonus_points = 3

		# 3. First to reach limit: 4 points
		var first_to_eight_points := 4 if state["firstToEightDistricts"] == player["id"] else 0

		# 4. Others who also reached limit: 2 points
		var other_eight_points := 2 if (state["firstToEightDistricts"] != player["id"] and player["city"].size() >= limit) else 0

		var total_points: int = district_points + color_bonus_points + first_to_eight_points + other_eight_points

		scores.push_back({
			"playerId": player["id"],
			"playerName": player["name"],
			"districtPoints": district_points,
			"colorBonusPoints": color_bonus_points,
			"firstToEightPoints": first_to_eight_points,
			"otherEightPoints": other_eight_points,
			"totalPoints": total_points,
		})
	return scores


static func determine_winner(scores: Array, players: Array) -> Dictionary:
	var sorted := scores.duplicate()
	sorted.sort_custom(func(a, b):
		# Highest total points
		if b["totalPoints"] != a["totalPoints"]:
			return a["totalPoints"] > b["totalPoints"]
		# Tiebreaker 1: highest district points
		if b["districtPoints"] != a["districtPoints"]:
			return a["districtPoints"] > b["districtPoints"]
		# Tiebreaker 2: most gold
		var pa = Utils.find_item(players, func(p): return p["id"] == a["playerId"])
		var pb = Utils.find_item(players, func(p): return p["id"] == b["playerId"])
		var gold_a: int = pa["gold"] if pa != null else 0
		var gold_b: int = pb["gold"] if pb != null else 0
		return gold_a > gold_b
	)
	return sorted[0]
