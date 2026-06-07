# Port of packages/game-logic/src/constants.ts
# Character definitions (rank 1-8) and the district card pool.
class_name Constants

const CHARACTERS := [
	{"rank": 1, "name": "Assassin", "description": "Announce a character to murder. That player skips their entire turn."},
	{"rank": 2, "name": "Thief", "description": "Announce a character to rob. When they are called, take all their gold."},
	{"rank": 3, "name": "Magician", "description": "Exchange your hand with another player, or discard cards and draw replacements."},
	{"rank": 4, "name": "King", "description": "Receive the Crown. Gain 1 gold per noble (yellow) district."},
	{"rank": 5, "name": "Bishop", "description": "Protected from the Warlord. Gain 1 gold per religious (blue) district."},
	{"rank": 6, "name": "Merchant", "description": "Gain 1 extra gold after your action. Gain 1 gold per trade (green) district."},
	{"rank": 7, "name": "Architect", "description": "Draw 2 extra cards. You may build up to 3 districts this turn."},
	{"rank": 8, "name": "Warlord", "description": "Destroy a district by paying 1 less than its cost. Gain 1 gold per military (red) district."},
]

const CHARACTER_INCOME_TYPE := {
	"Assassin": null,
	"Thief": null,
	"Magician": null,
	"King": "noble",
	"Bishop": "religious",
	"Merchant": "trade",
	"Architect": null,
	"Warlord": "military",
}

const DISTRICT_DEFS := [
	# Noble (Yellow)
	{"name": "Manor", "cost": 3, "type": "noble", "count": 5},
	{"name": "Castle", "cost": 4, "type": "noble", "count": 4},
	{"name": "Palace", "cost": 5, "type": "noble", "count": 3},

	# Religious (Blue)
	{"name": "Temple", "cost": 1, "type": "religious", "count": 3},
	{"name": "Church", "cost": 2, "type": "religious", "count": 3},
	{"name": "Monastery", "cost": 3, "type": "religious", "count": 3},
	{"name": "Cathedral", "cost": 5, "type": "religious", "count": 2},

	# Trade (Green)
	{"name": "Tavern", "cost": 1, "type": "trade", "count": 5},
	{"name": "Market", "cost": 2, "type": "trade", "count": 4},
	{"name": "Trading Post", "cost": 2, "type": "trade", "count": 3},
	{"name": "Docks", "cost": 3, "type": "trade", "count": 3},
	{"name": "Harbor", "cost": 4, "type": "trade", "count": 3},
	{"name": "Town Hall", "cost": 5, "type": "trade", "count": 2},

	# Military (Red)
	{"name": "Watchtower", "cost": 1, "type": "military", "count": 3},
	{"name": "Prison", "cost": 2, "type": "military", "count": 3},
	{"name": "Battlefield", "cost": 3, "type": "military", "count": 3},
	{"name": "Fortress", "cost": 5, "type": "military", "count": 2},

	# Special (Purple) — base game only
	{"name": "Haunted City", "cost": 2, "type": "special", "count": 1, "description": "For end-game scoring, the Haunted City counts as any district type of your choice."},
	{"name": "Keep", "cost": 3, "type": "special", "count": 2, "description": "The Keep cannot be destroyed by the Warlord."},
	{"name": "Laboratory", "cost": 5, "type": "special", "count": 1, "description": "Once per turn, discard a card from your hand and receive 2 gold."},
	{"name": "Smithy", "cost": 5, "type": "special", "count": 1, "description": "Once per turn, pay 2 gold and draw 3 cards."},
	{"name": "Graveyard", "cost": 5, "type": "special", "count": 1, "description": "When the Warlord destroys a district, you may pay 1 gold to take it into your hand."},
	{"name": "Observatory", "cost": 5, "type": "special", "count": 1, "description": "When you choose to draw cards, draw 3 and keep 1."},
	{"name": "Library", "cost": 6, "type": "special", "count": 1, "description": "When you choose to draw cards, keep both cards."},
	{"name": "School of Magic", "cost": 6, "type": "special", "count": 1, "description": "For income purposes, the School of Magic counts as the district type of your choice."},
	{"name": "Dragon Gate", "cost": 6, "type": "special", "count": 1, "description": "Worth 8 points at end of game (instead of 6)."},
	{"name": "University", "cost": 6, "type": "special", "count": 1, "description": "Worth 8 points at end of game (instead of 6)."},
	{"name": "Great Wall", "cost": 6, "type": "special", "count": 1, "description": "The Warlord must pay 1 extra gold to destroy any of your other districts."},
]


static func create_district_deck() -> Array:
	var deck: Array = []
	var id_counter := 0
	for def in DISTRICT_DEFS:
		for i in range(def["count"]):
			deck.push_back({
				"id": "district-%d" % id_counter,
				"name": def["name"],
				"cost": def["cost"],
				"type": def["type"],
				"description": def.get("description", null),
			})
			id_counter += 1
	return deck


const DISTRICTS_TO_WIN := 8
const DISTRICTS_TO_WIN_SHORT := 7
const STARTING_GOLD := 2
const STARTING_HAND_SIZE := 4
const GOLD_PER_ACTION := 2
const CARDS_DRAWN_PER_ACTION := 2
const CARDS_KEPT_PER_ACTION := 1

# Number of faceup removed characters by player count (4-7 players, 8 basic characters)
const FACEUP_REMOVED_BY_PLAYER_COUNT := {
	2: 0, # special rules
	3: 0, # special rules
	4: 2,
	5: 1,
	6: 0,
	7: 0,
}
