extends Control
## App shell — screens ki navigation, workout flow ka conductor.

const Home := preload("res://scripts/home.gd")
const ProgressScreen := preload("res://scripts/progress_screen.gd")
const ResultScreen := preload("res://scripts/result_screen.gd")
const SequenceMemory := preload("res://scripts/sequence_memory.gd")
const NumberSlide := preload("res://scripts/number_slide.gd")
const ColorWordClash := preload("res://scripts/color_word_clash.gd")
const OddOneOut := preload("res://scripts/odd_one_out.gd")
const PathMemory := preload("res://scripts/path_memory.gd")
const TubeSort := preload("res://scripts/tube_sort.gd")
const GameInfo := preload("res://scripts/game_info.gd")
const UI := preload("res://scripts/ui_factory.gd")

var screens: Dictionary = {}
var current: Control = null
var workout_mode: bool = false

func _ready() -> void:
	# Phone par portrait lock — project setting ke sath runtime par bhi,
	# taake auto-rotate wale phones par layout kabhi landscape na ho.
	DisplayServer.screen_set_orientation(DisplayServer.SCREEN_PORTRAIT)
	var bg := ColorRect.new()
	bg.color = UI.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	Save.ensure_today_workout()

	_add_screen("home", Home.new())
	_add_screen("progress", ProgressScreen.new())
	_add_screen("result", ResultScreen.new())
	_add_screen("sequence_memory", SequenceMemory.new())
	_add_screen("number_slide", NumberSlide.new())
	_add_screen("color_word_clash", ColorWordClash.new())
	_add_screen("odd_one_out", OddOneOut.new())
	_add_screen("path_memory", PathMemory.new())
	_add_screen("tube_sort", TubeSort.new())

	screens["home"].play_requested.connect(_on_play_requested)
	screens["home"].workout_requested.connect(_on_workout_requested)
	screens["home"].progress_requested.connect(func() -> void: show_screen("progress"))
	screens["progress"].back_requested.connect(func() -> void: show_screen("home"))
	screens["result"].home_requested.connect(func() -> void: show_screen("home"))
	for gid in ["sequence_memory", "number_slide", "color_word_clash", "odd_one_out", "path_memory", "tube_sort"]:
		screens[gid].finished.connect(_on_game_finished)
		screens[gid].exited.connect(_on_game_exited)

	show_screen("home")

func _add_screen(id: String, s: Control) -> void:
	s.set_anchors_preset(Control.PRESET_FULL_RECT)
	s.visible = false
	add_child(s)
	screens[id] = s

func show_screen(id: String) -> void:
	if current != null:
		current.visible = false
	current = screens[id]
	current.visible = true
	if current.has_method("refresh"):
		current.call("refresh")

# --- Game start ---

func _on_play_requested(game_id: String) -> void:
	workout_mode = false
	_start_game(game_id, {"mode": "free", "index": 0, "total": 1})

func _on_workout_requested() -> void:
	var w := Save.ensure_today_workout()
	var order: Array = w["order"]
	var results: Dictionary = w["results"]
	if results.size() >= order.size():
		# Aaj ka workout mukammal hai — dobara khelna hai to results reset
		# (streak 'counted' flag waisa hi rahega, dobara count nahi hoga).
		w["results"] = {}
		Save.persist()
		results = w["results"]
	for i in order.size():
		if not results.has(order[i]):
			_start_workout_game(i)
			return

func _start_workout_game(index: int) -> void:
	var w := Save.ensure_today_workout()
	var order: Array = w["order"]
	workout_mode = true
	_start_game(str(order[index]), {"mode": "workout", "index": index, "total": order.size()})

func _start_game(game_id: String, ctx: Dictionary) -> void:
	var s = screens[game_id]
	s.start_run(ctx)
	if current != null:
		current.visible = false
	current = s
	current.visible = true

# --- Game end ---

func _on_game_finished(game_id: String, score: int, stars: int) -> void:
	var new_best: bool
	if game_id == "tube_sort":
		# Tube Sort ka best points nahi — kam moves, barabar par tez waqt.
		var scr = screens[game_id]
		new_best = Save.submit_sort_pb(game_id, int(scr.moves), int(scr.elapsed_seconds))
	else:
		new_best = Save.submit_pb(game_id, score)
	if workout_mode:
		var w := Save.ensure_today_workout()
		(w["results"] as Dictionary)[game_id] = {"score": score, "stars": stars, "new_best": new_best}
		Save.persist()
		var order: Array = w["order"]
		var idx := order.find(game_id)
		if idx + 1 < order.size():
			_start_workout_game(idx + 1)
			return
		_finalize_workout()
		var entries: Array = []
		for gid in order:
			var r: Dictionary = (w["results"] as Dictionary)[gid]
			entries.append(_entry(gid, r))
		screens["result"].show_results("Workout complete!", entries)
		show_screen("result")
	else:
		var e := {"score": score, "stars": stars, "new_best": new_best}
		screens["result"].show_results("Result", [_entry(game_id, e)])
		show_screen("result")

func _entry(game_id: String, r: Dictionary) -> Dictionary:
	return {
		"game_id": game_id,
		"name": str(GameInfo.get_game(game_id)["name"]),
		"score": int(r["score"]),
		"stars": int(r["stars"]),
		"new_best": bool(r["new_best"]),
	}

func _finalize_workout() -> void:
	var w := Save.ensure_today_workout()
	if bool(w.get("counted", false)):
		return
	w["counted"] = true
	var st: Dictionary = Save.data["streak"]
	var today := Save.day_number()
	if int(st["last_day"]) == today - 1:
		st["count"] = int(st["count"]) + 1
	elif int(st["last_day"]) != today:
		st["count"] = 1
	st["last_day"] = today
	st["total"] = int(st["total"]) + 1
	var hist: Array = st["history"]
	if not hist.has(today):
		hist.append(today)
	while hist.size() > 60:
		hist.pop_front()
	Save.persist()

func _on_game_exited() -> void:
	workout_mode = false
	show_screen("home")
