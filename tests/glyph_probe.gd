extends SceneTree

func _init() -> void:
	var fonts := {
		"EBGaramond": load("res://assets/fonts/EBGaramond.ttf"),
		"Cinzel": load("res://assets/fonts/Cinzel.ttf"),
		"NotoSymbols": load("res://assets/fonts/NotoSansSymbols.ttf"),
		"NotoSymbols2": load("res://assets/fonts/NotoSansSymbols2.ttf"),
	}
	var chars := {
		"⬤ (2B24)": 0x2B24, "● (25CF)": 0x25CF, "• (2022)": 0x2022,
		"♛ (265B)": 0x265B, "👑 (1F451)": 0x1F451, "🂠 (1F0A0)": 0x1F0A0,
		"♦ (2666)": 0x2666, "▮ (25AE)": 0x25AE, "✖ (2716)": 0x2716,
		"⚜ (269C)": 0x269C, "★ (2605)": 0x2605, "✦ (2726)": 0x2726,
	}
	for fname in fonts:
		var f: Font = fonts[fname]
		var have: Array = []
		var missing: Array = []
		for label in chars:
			if f.has_char(chars[label]):
				have.push_back(label)
			else:
				missing.push_back(label)
		print("%s HAS: %s" % [fname, ", ".join(have)])
		print("%s MISSING: %s" % [fname, ", ".join(missing)])
	quit(0)
