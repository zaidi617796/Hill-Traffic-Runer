extends SceneTree
## Headless checks — roster (Tube Sort in, Quick Math out), games,
## home layout (compact rows, chip) aur main shell integration.
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
	await _test_tube_sort()
	await _test_home_layout()
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
	check(not all.has("quick_math"), "registry: quick_math removed")
	check(all.has("tube_sort"), "registry: tube_sort present")
	var ts: Dictionary = all.get("tube_sort", {})
	check(str(ts.get("name", "")) == "Tube Sort", "registry: tube_sort name")
	check(bool(ts.get("playable", false)) == true, "registry: tube_sort playable")
	var playable_count := 0
	var soon_count := 0
	for gid in all.keys():
		if bool(all[gid].get("playable", false)):
			playable_count += 1
		else:
			soon_count += 1
	check(playable_count == 6 and soon_count == 2, "registry: 6 playable + 2 coming soon (got %d/%d)" % [playable_count, soon_count])
	var order: Array = GameInfo.free_play_order()
	var expected: Array = ["sequence_memory", "memory_tiles", "spot_difference", "tube_sort", "number_slide", "color_word_clash", "odd_one_out", "path_memory"]
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

# --- Tube Sort ---

func _colour_counts(tubes: Array) -> Dictionary:
	var counts := {}
	for t in tubes:
		for u in t:
			counts[int(u)] = int(counts.get(int(u), 0)) + 1
	return counts

func _test_tube_sort() -> void:
	var g = spawn("res://scripts/tube_sort.gd")
	await process_frame
	await process_frame
	g.start_run({"mode": "free", "index": 0, "total": 1})
	check(g.start_overlay.visible, "ts: start overlay shown")
	check(g.tubes.size() == 8, "ts: 8 tubes")
	var counts := _colour_counts(g.tubes)
	var counts_ok := counts.size() == 6
	for c in counts.keys():
		if int(counts[c]) != 4:
			counts_ok = false
	check(counts_ok, "ts: 6 colours x 4 units (got %s)" % str(counts))
	var empties := 0
	for t in g.tubes:
		if (t as Array).is_empty():
			empties += 1
	check(empties == 2, "ts: exactly 2 empty tubes")
	check(not g._is_solved(), "ts: puzzle not already solved")
	check(g.scramble_steps.size() >= 20, "ts: scramble applied (%d steps)" % g.scramble_steps.size())
	g._on_start_pressed()
	check(g.state == "playing", "ts: playing after start")
	# Ek legal pour dhoondo aur karo
	var src := -1
	var dst := -1
	for s in 8:
		for d in 8:
			if g._can_pour(s, d):
				src = s
				dst = d
				break
		if src != -1:
			break
	check(src != -1, "ts: a legal pour exists")
	var src_before: Array = (g.tubes[src] as Array).duplicate()
	var dst_before: Array = (g.tubes[dst] as Array).duplicate()
	g._on_tube_tapped(src)
	check(g.selected == src, "ts: tap selects source tube")
	g._on_tube_tapped(dst)
	check(g.moves == 1 and g.selected == -1, "ts: pour counts one move, selection cleared")
	var run_len := 0
	var top_col := int(src_before.back())
	for i in range(src_before.size() - 1, -1, -1):
		if int(src_before[i]) != top_col:
			break
		run_len += 1
	var expect_moved := mini(run_len, 4 - dst_before.size())
	check(g.tubes[src].size() == src_before.size() - expect_moved and g.tubes[dst].size() == dst_before.size() + expect_moved, "ts: pour moved top run (%d units)" % expect_moved)
	check(int(g.tubes[dst].back()) == top_col, "ts: poured colour on top of destination")
	# Undo purani haalat wapas lata hai
	g._on_undo_pressed()
	check(g.moves == 0 and g.tubes[src].size() == src_before.size() and g.tubes[dst].size() == dst_before.size(), "ts: undo restores state and move count")
	# Illegal pour: selection dusri tube par shift hoti hai, move nahi banta
	var bad_s := -1
	var bad_d := -1
	for s in 8:
		for d in 8:
			if s != d and not (g.tubes[s] as Array).is_empty() and not (g.tubes[d] as Array).is_empty() and not g._can_pour(s, d):
				bad_s = s
				bad_d = d
				break
		if bad_s != -1:
			break
	check(bad_s != -1, "ts: an illegal pair exists")
	g._on_tube_tapped(bad_s)
	g._on_tube_tapped(bad_d)
	check(g.moves == 0 and g.selected == bad_d, "ts: illegal pour reselects, no move counted")
	# Restart initial layout par wapas
	g.selected = -1
	if src != -1:
		g._do_pour(src, dst)
	g._on_restart_pressed()
	check(g.moves == 0 and str(g.tubes) == str(g.initial_tubes), "ts: restart restores initial layout")
	# Solvability: scramble ka ulta sequence hal tak le jata hai
	var solved_ok: bool = g.debug_solve()
	check(solved_ok and g._is_solved(), "ts: generated puzzle is solvable (reverse scramble solves it)")
	check(g.state == "over" and g.end_overlay.visible, "ts: solving shows end overlay")
	g._on_see_score_pressed()
	var f := last_finish("tube_sort")
	check(not f.is_empty(), "ts: finished signal fired")
	check(int(f.get("score", -1)) >= 100 and int(f.get("score", 9999)) <= 1200, "ts: sane score %s" % str(f))
	check(int(f.get("stars", -1)) >= 1 and int(f.get("stars", 99)) <= 3, "ts: sane stars %s" % str(f))
	# Sort PB: kam moves behtar, barabar par tez waqt
	var Save = root.get_node("Save")
	Save.data["pb_sort"] = {}
	check(Save.submit_sort_pb("tube_sort", 30, 120), "ts pb: first best accepted")
	check(not Save.submit_sort_pb("tube_sort", 31, 90), "ts pb: more moves rejected")
	check(not Save.submit_sort_pb("tube_sort", 30, 130), "ts pb: same moves slower rejected")
	check(Save.submit_sort_pb("tube_sort", 30, 110), "ts pb: same moves faster accepted")
	check(Save.submit_sort_pb("tube_sort", 25, 300), "ts pb: fewer moves accepted")
	var rec: Dictionary = Save.get_sort_pb("tube_sort")
	check(int(rec.get("moves", -1)) == 25 and int(rec.get("seconds", -1)) == 300, "ts pb: stored best is 25 moves / 300s")
	Save.data["pb_sort"] = {}
	Save.persist()
	g.queue_free()

# --- Home layout (compact rows regression) ---

func _test_home_layout() -> void:
	for sz in [Vector2(720, 1280), Vector2(720, 1600), Vector2(1280, 720)]:
		var host := Control.new()
		host.size = sz
		root.add_child(host)
		var main = load("res://main.tscn").instantiate()
		host.add_child(main)
		await process_frame
		await process_frame
		await process_frame
		var home = main.screens["home"]
		check(home.game_rows.size() == 8, "layout %s: 8 game rows built" % str(sz))
		# Font-metrics se azad checks: saari rows ek jitni unchi (koi
		# phaila hua giant card nahi), naam/sub ek line, chip ek line.
		var first_h := -1.0
		var uniform_ok := true
		var lines_ok := true
		var prev_bottom := -1.0
		var ordered_ok := true
		for gid in ["sequence_memory", "memory_tiles", "spot_difference", "tube_sort", "number_slide", "color_word_clash", "odd_one_out", "path_memory"]:
			var row: PanelContainer = home.game_rows[gid]
			if first_h < 0.0:
				first_h = row.size.y
			elif absf(row.size.y - first_h) > 2.0:
				uniform_ok = false
			var tv := row.get_child(0).get_child(1) as VBoxContainer
			if (tv.get_child(0) as Label).get_line_count() != 1 or (tv.get_child(1) as Label).get_line_count() != 1:
				lines_ok = false
			if row.global_position.y < prev_bottom - 1.0:
				ordered_ok = false
			prev_bottom = row.global_position.y + row.size.y
		check(uniform_ok, "layout %s: all rows one uniform compact height (no giant cards)" % str(sz))
		check(lines_ok, "layout %s: name + tagline stay on one line each" % str(sz))
		check(ordered_ok, "layout %s: rows stacked in order, no overlap" % str(sz))
		var chips_ok := true
		for gid in home.soon_chips.keys():
			var chip: PanelContainer = home.soon_chips[gid]
			var chip_label := chip.get_child(0) as Label
			if chip.size.x < 90.0 or chip_label.get_line_count() != 1:
				chips_ok = false
		check(home.soon_chips.size() == 2 and chips_ok, "layout %s: coming-soon chips wide, text on one line (no letter stack)" % str(sz))
		main.queue_free()
		host.queue_free()
		await process_frame

# --- Main shell integration ---

func _test_main_integration() -> void:
	var Save = root.get_node("Save")
	Save.data["workout"]["date"] = "2000-01-01" # aaj ka workout naye order se bane
	var w: Dictionary = Save.ensure_today_workout()
	check((w["order"] as Array).size() == 6, "main: workout has 6 games")
	check((w["order"] as Array).has("tube_sort"), "main: workout includes tube_sort")
	check(not (w["order"] as Array).has("quick_math"), "main: workout has no quick_math")
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	for gid in ["home", "progress", "result", "sequence_memory", "number_slide", "color_word_clash", "odd_one_out", "path_memory", "tube_sort"]:
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
	# Free play: tube sort khol kar hal karo — result + sort PB main flow se
	Save.data["pb_sort"] = {}
	main._on_play_requested("tube_sort")
	var tg = main.screens["tube_sort"]
	check(main.current == tg, "main: free play opens tube sort")
	tg._on_start_pressed()
	check(tg.debug_solve(), "main: tube sort solved in main flow")
	tg._on_see_score_pressed()
	check(main.current == main.screens["result"], "main: result screen after tube sort")
	var spb: Dictionary = Save.get_sort_pb("tube_sort")
	check(not spb.is_empty() and int(spb["moves"]) == tg.moves, "main: tube sort PB saved as moves/time")
	Save.data["pb_sort"] = {}
	Save.persist()
	main.queue_free()
