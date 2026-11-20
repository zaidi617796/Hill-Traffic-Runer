extends RefCounted
## Games ka central registry — naam, tagline, accent rang, playable ya nahi.

static func all() -> Dictionary:
	return {
		"sequence_memory": {
			"name": "Sequence Memory",
			"tag": "Watch the pattern, then repeat it",
			"accent": Color("FFB020"),
			"playable": true,
		},
		"memory_tiles": {
			"name": "Memory Tiles",
			"tag": "Flip the tiles and match the pairs",
			"accent": Color("2DD4BF"),
			"playable": false,
		},
		"spot_difference": {
			"name": "Spot the Difference",
			"tag": "Find what changed",
			"accent": Color("A78BFA"),
			"playable": false,
		},
		"quick_math": {
			"name": "Quick Math",
			"tag": "Fast answers against the clock",
			"accent": Color("FB7185"),
			"playable": false,
		},
		"number_slide": {
			"name": "Number Slide",
			"tag": "Slide the tiles into order",
			"accent": Color("A0C4FF"),
			"playable": true,
		},
		"color_word_clash": {
			"name": "Color Word Clash",
			"tag": "Tap the ink colour, not the word",
			"accent": Color("4ADE80"),
			"playable": true,
		},
		"odd_one_out": {
			"name": "Odd One Out",
			"tag": "Find the tile that is different",
			"accent": Color("FB923C"),
			"playable": true,
		},
		"path_memory": {
			"name": "Path Memory",
			"tag": "Watch the path, then retrace it",
			"accent": Color("E879F9"),
			"playable": true,
		},
	}

static func free_play_order() -> Array:
	return ["sequence_memory", "memory_tiles", "spot_difference", "quick_math", "number_slide", "color_word_clash", "odd_one_out", "path_memory"]

static func get_game(game_id: String) -> Dictionary:
	return all().get(game_id, {"name": game_id, "tag": "", "accent": Color.WHITE, "playable": false})
