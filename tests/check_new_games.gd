extends SceneTree
## Headless checks — Memory Tiles swap + 3 naye playable games.
## Run: godot --headless --path . -s res://tests/check_new_games.gd

var passes := 0
var failures := 0
var finishes: Array = []

func check(cond: bool, name: String) -> void:
	if cond:
		passes += 1
		print("PASS: ", name)
	else:
		failures += 1
		print("FAIL: ", name)

func wait_until(cond: Callable, timeout_sec: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout_sec * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if bool(cond.call()):
			return true
		await process_frame
	return bool(cond.call())

func spawn(script_path: String) -> Control:
	var g: Control = load(script_path).new()
	g.finished.connect(func(gid, sc, st) -> void: finishes.append({"id": gid, "score": sc, "stars": st}))
	root.add_child(g)
	return g

func last_finish(game_id: String) -> Dictionary:
	for i in range(finishes.size() - 1, -1, -1):
		if str(finishes[i]["id"]) == game_id:
			return finishes[i]
	return {}

func _initialize() -> void:
	_run()

func _run() -> void:
	await process_frame
	await process_frame
	_test_registry()
	await _test_color_word_clash()
	await _test_odd_one_out()
	await _test_path_memory()
	await _test_main_integration()
	print("CHECKS DONE: %d passed, %d failed" % [passes, failures])
	quit(0 if failures == 0 else 1)

# --- Registry ---

func _test_registry() -> void:
	var GameInfo = load("res://scripts/game_info.gd")
	var all: Dictionary = GameInfo.all()
	check(not all.has("number_pairs"), "registry: number_pairs removed")
	check(all.has("memory_tiles"), "registry: memory_tiles present")
	var mt: Dictionary = all.get("memory_tiles", {})
	check(str(mt.get("name", "")) == "Memory Tiles", "registry: memory_tiles name")
	check(str(mt.get("tag", "")) == "Flip the tiles and match the pairs", "registry: memory_tiles tag")
	check(bool(mt.get("playable", true)) == false, "registry: memory_tiles not playable yet")
	for gid in ["color_word_clash", "odd_one_out", "path_memory"]:
		check(all.has(gid), "registry: %s present" % gid)
		check(bool(all[gid].get("playable", false)) == true, "registry: %s playable" % gid)
	var order: Array = GameInfo.free_play_order()
	var expected: Array = ["sequence_memory", "memory_tiles", "spot_difference", "quick_math", "number_slide", "color_word_clash", "odd_one_out", "path_memory"]
	check(order == expected, "registry: free_play_order exact (got %s)" % str(order))

# --- Color Word Clash ---

func _test_color_word_clash() -> void:
	var g = spawn("res://scripts/color_word_clash.gd")
	await process_frame
	await process_frame
	g.start_run({"mode": "free", "index": 0, "total": 1})
	check(g.start_overlay.visible, "cwc: start overlay shown")
	g._on_start_pressed()
	check(g.state == "playing", "cwc: playing after start")
	check(g.active_count == 4, "cwc: starts with 4 colours")
	check(int(g.answer_buttons[3].visible) and not bool(g.answer_buttons[4].visible), "cwc: 4 answer buttons visible")
	check(g.word_idx >= 0 and g.word_idx < 4 and g.ink_idx >= 0 and g.ink_idx < 4, "cwc: question indices in range")
	# Sahi jawab
	(g.answer_buttons[g.ink_idx] as Button).pressed.emit()
	check(g.correct_count == 1 and g.score == 10, "cwc: correct tap scores 10")
	# Ghalat jawab + time penalty
	var tl: int = g.time_left
	var wrong: int = (g.ink_idx + 1) % g.active_count
	(g.answer_buttons[wrong] as Button).pressed.emit()
	check(g.wrong_count == 1, "cwc: wrong tap counted")
	check(g.time_left <= tl - 2 and g.time_left >= tl - 3, "cwc: wrong tap costs ~2s (was %d, now %d)" % [tl, g.time_left])
	# Rang unlock ramp
	g.correct_count = 9
	(g.answer_buttons[g.ink_idx] as Button).pressed.emit()
	check(g.active_count == 5, "cwc: 5th colour unlocks at 10 correct")
	g.correct_count = 19
	(g.answer_buttons[g.ink_idx] as Button).pressed.emit()
	check(g.active_count == 6 and bool(g.answer_buttons[5].visible), "cwc: 6th colour unlocks at 20 correct")
	# Time up -> end overlay -> finished
	g.time_left = 1
	var over := await wait_until(func() -> bool: return g.state == "over", 4.0)
	check(over and g.end_overlay.visible, "cwc: time up shows end overlay")
	g._on_see_score_pressed()
	var f := last_finish("color_word_clash")
	check(not f.is_empty(), "cwc: finished signal fired")
	check(int(f.get("score", -1)) > 0 and int(f.get("stars", -1)) >= 0 and int(f.get("stars", 99)) <= 3, "cwc: sane score/stars %s" % str(f))
	g.queue_free()

# --- Odd One Out ---

func _test_odd_one_out() -> void:
	var g = spawn("res://scripts/odd_one_out.gd")
	await process_frame
	await process_frame
	g.start_run({"mode": "free", "index": 0, "total": 1})
	g._on_start_pressed()
	check(g.state == "playing", "ooo: playing after start")
	check(g.cols == 3 and g.tiles.size() == 9, "ooo: round 1 is 3x3")
	check(g.odd_index >= 0 and g.odd_index < 9, "ooo: odd index in range")
	# Sahi tile
	(g.tiles[g.odd_index] as Button).pressed.emit()
	check(g.rounds_done == 1 and g.score >= 100, "ooo: correct tap clears round, score %d" % g.score)
	var back := await wait_until(func() -> bool: return g.state == "playing", 3.0)
	check(back, "ooo: next round starts")
	# Ghalat tile — waqt kat-ta hai, round waisa hi
	var tl: float = g.time_left
	var wrong: int = (g.odd_index + 1) % g.tiles.size()
	(g.tiles[wrong] as Button).pressed.emit()
	check(g.rounds_done == 1, "ooo: wrong tap keeps round")
	check(g.time_left <= tl - 0.99 and g.time_left >= tl - 1.3, "ooo: wrong tap costs ~1s (was %.2f, now %.2f)" % [tl, g.time_left])
	# Grid growth
	g.rounds_done = 4
	g._setup_round()
	check(g.cols == 5 and g.tiles.size() == 25, "ooo: round 5 grid is 5x5")
	# Time out -> fail overlay -> finished
	g.time_left = 0.04
	var over := await wait_until(func() -> bool: return g.state == "over", 3.0)
	check(over and g.fail_overlay.visible, "ooo: timeout shows fail overlay")
	g._on_end_pressed()
	var f := last_finish("odd_one_out")
	check(not f.is_empty(), "ooo: finished signal fired")
	check(int(f.get("stars", -1)) >= 0 and int(f.get("stars", 99)) <= 3, "ooo: sane stars %s" % str(f))
	g.queue_free()

# --- Path Memory ---

func _test_path_memory() -> void:
	var g = spawn("res://scripts/path_memory.gd")
	await process_frame
	await process_frame
	# Grid growth mapping + path generation sanity
	check(g._grid_size_for(3) == 3 and g._grid_size_for(5) == 3 and g._grid_size_for(6) == 4 and g._grid_size_for(8) == 4 and g._grid_size_for(9) == 5, "pm: grid size mapping 3/4/5")
	var p6: Array = g._gen_path(6, 4)
	var uniq := {}
	for c in p6:
		uniq[int(c)] = true
	check(p6.size() == 6 and uniq.size() == 6, "pm: generated path has 6 unique cells")
	var adjacent := true
	for i in range(1, p6.size()):
		var a := int(p6[i - 1])
		var b := int(p6[i])
		if abs(a % 4 - b % 4) + abs(a / 4 - b / 4) != 1:
			adjacent = false
	check(adjacent, "pm: generated path steps are neighbours")
	# Asli khel
	g.start_run({"mode": "free", "index": 0, "total": 1})
	g._on_start_pressed()
	var inp := await wait_until(func() -> bool: return g.state == "input", 10.0)
	check(inp, "pm: reaches input state")
	check(g.path_cells.size() == 3 and g.cells.size() == 9, "pm: first path is 3 steps on 3x3")
	for cell in g.path_cells:
		(g.cells[int(cell)] as Button).pressed.emit()
	check(g.best_len == 3, "pm: round 1 completed")
	inp = await wait_until(func() -> bool: return g.state == "input" and g.path_cells.size() == 4, 12.0)
	check(inp, "pm: round 2 path grows to 4")
	# Ghalat cell -> soft fail
	var wrong := -1
	for i in g.cells.size():
		if i != int(g.path_cells[0]):
			wrong = i
			break
	(g.cells[wrong] as Button).pressed.emit()
	check(g.state == "over" and g.fail_overlay.visible, "pm: wrong tap shows fail overlay")
	# Watch it again — ek extra chance
	g.watch_button.pressed.emit()
	check(g.chance_used, "pm: watch-again chance used")
	inp = await wait_until(func() -> bool: return g.state == "input", 12.0)
	check(inp, "pm: replay reaches input again")
	for cell in g.path_cells:
		(g.cells[int(cell)] as Button).pressed.emit()
	check(g.best_len == 4, "pm: replayed round completed")
	inp = await wait_until(func() -> bool: return g.state == "input" and g.path_cells.size() == 5, 12.0)
	check(inp, "pm: round 3 path grows to 5")
	var wrong2 := -1
	for i in g.cells.size():
		if i != int(g.path_cells[0]):
			wrong2 = i
			break
	(g.cells[wrong2] as Button).pressed.emit()
	check(g.state == "over" and g.watch_button.disabled, "pm: second fail, watch chance spent")
	g._on_end_pressed()
	var f := last_finish("path_memory")
	check(not f.is_empty(), "pm: finished signal fired")
	check(int(f.get("score", -1)) > 0 and int(f.get("stars", -1)) >= 0 and int(f.get("stars", 99)) <= 3, "pm: sane score/stars %s" % str(f))
	g.queue_free()

# --- Main shell integration ---

func _test_main_integration() -> void:
	var Save = root.get_node("Save")
	Save.data["workout"]["date"] = "2000-01-01" # aaj ka workout naye order se bane
	var w: Dictionary = Save.ensure_today_workout()
	check((w["order"] as Array).size() == 5, "main: workout has 5 games")
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	for gid in ["home", "progress", "result", "sequence_memory", "number_slide", "color_word_clash", "odd_one_out", "path_memory"]:
		check(main.screens.has(gid), "main: screen %s registered" % gid)
	# Free play: color_word_clash khel kar result screen tak
	main._on_play_requested("color_word_clash")
	var g = main.screens["color_word_clash"]
	check(main.current == g, "main: free play opens colour clash")
	g._on_start_pressed()
	(g.answer_buttons[g.ink_idx] as Button).pressed.emit()
	g.time_left = 1
	var over := await wait_until(func() -> bool: return g.state == "over", 4.0)
	check(over, "main: clash run ends")
	g._on_see_score_pressed()
	check(main.current == main.screens["result"], "main: result screen after finish")
	# Workout chaining: pehli game khulti hai, exit par home
	main._on_workout_requested()
	check(main.workout_mode, "main: workout mode on")
	check(main.current == main.screens[str(w["order"][0])], "main: workout starts first game")
	main.current.exited.emit()
	check(main.current == main.screens["home"], "main: exit returns home")
	main.queue_free()
