extends Control
## Tube Sort — test tubes me rang bhare hain, ulta-pulta. Ek tube se
## dusri me wohi rang undelo jo upar hai; jeet tab jab har tube ya
## khaali ho ya ek hi rang se poori bhari ho.
## Puzzle hamesha SOLVABLE: solved haalat se peeche ki taraf scramble
## kiya jata hai (har scramble step ek asli pour ka exact ulta hai),
## is liye ulta sequence hi hal ki guarantee hai.
## Personal best = kam se kam moves; barabar moves par tez waqt.

signal finished(game_id, score, stars)
signal exited

const UI := preload("res://scripts/ui_factory.gd")
const GameInfo := preload("res://scripts/game_info.gd")
const Tone := preload("res://scripts/tone.gd")
const StarsRow := preload("res://scripts/stars_row.gd")
const TubeBoard := preload("res://scripts/tube_board.gd")

const GAME_ID := "tube_sort"
const ACCENT := Color("38BDF8")
const TUBE_COUNT := 8
const FILLED_COUNT := 6
const CAP := 4
const SCRAMBLE_STEPS := 60

var color_defs: Array = [
	Color("EF4444"), Color("3B82F6"), Color("22C55E"),
	Color("FACC15"), Color("A855F7"), Color("F97316"),
]

var tubes: Array = [] # Array of Array[int], bottom -> top
var initial_tubes: Array = []
var scramble_steps: Array = [] # Array of [from, to, count]
var history: Array = [] # undo ke liye purani haalatein
var selected: int = -1
var moves: int = 0
var elapsed_seconds: int = 0
var score: int = 0
var state: String = "idle" # idle | playing | over
var context: Dictionary = {}

var status_label: Label
var moves_label: Label
var time_label: Label
var pb_label: Label
var board = null # TubeBoard (script type, dynamic calls)
var start_overlay: Control
var end_overlay: Control
var end_stats: Label
var end_stars = null # StarsRow (script type, dynamic calls)
var dots_box: HBoxContainer
var mode_label: Label
var clock: Timer

func _ready() -> void:
	var mc := UI.margins(self, 20)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	mc.add_child(v)

	# Top bar
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	v.add_child(top)
	var back := UI.ghost_button("←  Back", 15)
	back.custom_minimum_size = Vector2(92, 44)
	back.pressed.connect(_on_back_pressed)
	top.add_child(back)
	var title_v := VBoxContainer.new()
	title_v.add_theme_constant_override("separation", 0)
	top.add_child(title_v)
	title_v.add_child(UI.label1("Tube Sort", 21, UI.TEXT))
	mode_label = UI.label1("", 13, UI.MUTED)
	title_v.add_child(mode_label)
	top.add_child(UI.hspacer())
	dots_box = HBoxContainer.new()
	dots_box.add_theme_constant_override("separation", 6)
	top.add_child(dots_box)

	# Personal best (moves + waqt)
	pb_label = UI.label("Best: —", 14, UI.MUTED)
	v.add_child(pb_label)

	# HUD: moves + waqt
	var hud := HBoxContainer.new()
	hud.add_theme_constant_override("separation", 10)
	v.add_child(hud)
	moves_label = UI.label1("Moves: 0", 17, UI.TEXT)
	hud.add_child(moves_label)
	hud.add_child(UI.hspacer())
	time_label = UI.label1("Time: 0:00", 17, UI.TEXT)
	hud.add_child(time_label)

	status_label = UI.label("Sort every colour into its own tube!", 17, UI.TEXT)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(status_label)

	# Board — tubes code-drawn hain
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(center)
	board = TubeBoard.new()
	board.custom_minimum_size = Vector2(640, 470)
	board.tube_tapped.connect(_on_tube_tapped)
	center.add_child(board)

	# Undo / Restart
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 12)
	v.add_child(actions)
	var undo := UI.ghost_button("↩  Undo", 15)
	undo.custom_minimum_size = Vector2(132, 48)
	undo.pressed.connect(_on_undo_pressed)
	actions.add_child(undo)
	var restart := UI.ghost_button("Restart", 15)
	restart.custom_minimum_size = Vector2(132, 48)
	restart.pressed.connect(_on_restart_pressed)
	actions.add_child(restart)

	clock = Timer.new()
	clock.wait_time = 1.0
	clock.timeout.connect(_on_clock_tick)
	add_child(clock)

	start_overlay = _make_overlay("Tap a tube, then tap another\nto pour the top colour.\nFill each tube with one colour!", "Start", _on_start_pressed)
	end_overlay = _make_end_overlay()

func _make_overlay(how_text: String, btn_text: String, on_press: Callable) -> Control:
	var ov := Control.new()
	ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.add_child(cc)
	var cardp := UI.card()
	cardp.custom_minimum_size = Vector2(320, 0)
	cc.add_child(cardp)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 12)
	cardp.add_child(cv)
	var t := UI.label(how_text, 16, UI.TEXT)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(t)
	var b := UI.button(btn_text, ACCENT, 18)
	b.custom_minimum_size = Vector2(0, 52)
	b.pressed.connect(on_press)
	cv.add_child(b)
	add_child(ov)
	return ov

func _make_end_overlay() -> Control:
	var ov := Control.new()
	ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.add_child(cc)
	var cardp := UI.card()
	cardp.custom_minimum_size = Vector2(320, 0)
	cc.add_child(cardp)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 10)
	cardp.add_child(cv)
	var t := UI.label("Solved!", 26, UI.TEXT)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(t)
	end_stars = StarsRow.new()
	end_stars.star_size = 36.0
	var sc := CenterContainer.new()
	sc.add_child(end_stars)
	cv.add_child(sc)
	end_stats = UI.label("", 15, UI.MUTED)
	end_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(end_stats)
	var see := UI.button("See score", ACCENT, 17)
	see.custom_minimum_size = Vector2(0, 50)
	see.pressed.connect(_on_see_score_pressed)
	cv.add_child(see)
	var again := UI.ghost_button("Play again", 15)
	again.custom_minimum_size = Vector2(0, 48)
	again.pressed.connect(_on_play_again_pressed)
	cv.add_child(again)
	ov.visible = false
	add_child(ov)
	return ov

# --- Puzzle banana (hamesha solvable) ---

func _deep_copy(src: Array) -> Array:
	var out: Array = []
	for t in src:
		out.append((t as Array).duplicate())
	return out

func _top_run(t: Array) -> int:
	if t.is_empty():
		return 0
	var col := int(t.back())
	var n := 0
	for i in range(t.size() - 1, -1, -1):
		if int(t[i]) != col:
			break
		n += 1
	return n

func _generate() -> void:
	var solved: Array = []
	for c in FILLED_COUNT:
		solved.append([c, c, c, c])
	for e in TUBE_COUNT - FILLED_COUNT:
		solved.append([])
	tubes = _deep_copy(solved)
	scramble_steps.clear()
	var guard := 0
	# Do marhale: pehle 45 steps azadi se ghul-mil, phir khaali tubes ki
	# tadaad wapas 2 par lana lazmi — deal hamesha classic 6 bhari + 2
	# khaali hi dikhegi, aur har step invertible rehta hai.
	while (scramble_steps.size() < SCRAMBLE_STEPS or _empty_count() != 2) and guard < 30000:
		guard += 1
		var a := randi() % TUBE_COUNT
		if tubes[a].is_empty():
			continue
		var col := int(tubes[a].back())
		var run := _top_run(tubes[a])
		var k := 1 + randi() % run
		# Invertible tabhi hai jab source par wohi rang upar bacha rahe
		# (k < run) ya tube bilkul khaali ho jaye (k == poori tube).
		if k == run and tubes[a].size() != run:
			continue
		var b := randi() % TUBE_COUNT
		if b == a:
			continue
		if tubes[b].size() + k > CAP:
			continue
		# Destination ke upar wohi rang NA ho — warna wapas undelte waqt
		# zyada units uth jayengi aur ulta step exact nahi rahega.
		if not tubes[b].is_empty() and int(tubes[b].back()) == col:
			continue
		if not scramble_steps.is_empty():
			var last: Array = scramble_steps.back()
			if int(last[0]) == b and int(last[1]) == a:
				continue # pichla step foran ulta na karo, warna ghul-mil khatam
		if scramble_steps.size() >= 45:
			var e := _empty_count()
			var e_delta := (1 if tubes[a].size() == k else 0) - (1 if tubes[b].is_empty() else 0)
			if e == 2 and e_delta != 0:
				continue
			if e < 2 and e_delta <= 0:
				continue
			if e > 2 and e_delta >= 0:
				continue
		for i in k:
			tubes[b].append(tubes[a].pop_back())
		scramble_steps.append([a, b, k])
	if _is_solved() or scramble_steps.size() < 20 or _empty_count() != 2:
		_generate()
		return
	initial_tubes = _deep_copy(tubes)

func _empty_count() -> int:
	var n := 0
	for t in tubes:
		if t.is_empty():
			n += 1
	return n

func _is_solved() -> bool:
	for t in tubes:
		if t.is_empty():
			continue
		if t.size() != CAP:
			return false
		for u in t:
			if int(u) != int(t[0]):
				return false
	return true

func _can_pour(s: int, d: int) -> bool:
	if s == d or tubes[s].is_empty() or tubes[d].size() >= CAP:
		return false
	return tubes[d].is_empty() or int(tubes[d].back()) == int(tubes[s].back())

func _do_pour(s: int, d: int) -> bool:
	if not _can_pour(s, d):
		return false
	history.append(_deep_copy(tubes))
	var amt := mini(_top_run(tubes[s]), CAP - tubes[d].size())
	for i in amt:
		tubes[d].append(tubes[s].pop_back())
	moves += 1
	selected = -1
	board.selected = -1
	board.tubes = tubes
	board.refresh()
	_update_hud()
	if _is_solved():
		_on_win()
	return true

# Test/debug ke liye: scramble ka ulta sequence chala kar hal tak jao.
# Har pour asli rules se hota hai — fail ho to puzzle solvable nahi tha.
func debug_solve() -> bool:
	for i in range(scramble_steps.size() - 1, -1, -1):
		var step: Array = scramble_steps[i]
		if not _do_pour(int(step[1]), int(step[0])):
			return false
	return _is_solved()

# --- Run control ---

func start_run(ctx: Dictionary) -> void:
	context = ctx
	clock.stop()
	state = "idle"
	end_overlay.visible = false
	start_overlay.visible = true
	_generate()
	_reset_run_state()
	board.setup(tubes, color_defs)
	status_label.text = "Sort every colour into its own tube!"
	status_label.add_theme_color_override("font_color", UI.TEXT)
	_update_mode_ui()
	_update_pb_ui()
	_update_hud()

func _reset_run_state() -> void:
	moves = 0
	elapsed_seconds = 0
	score = 0
	selected = -1
	history.clear()

func _new_game() -> void:
	clock.stop()
	_generate()
	_reset_run_state()
	board.setup(tubes, color_defs)
	state = "playing"
	status_label.text = "Sort every colour into its own tube!"
	status_label.add_theme_color_override("font_color", UI.TEXT)
	_update_pb_ui()
	_update_hud()
	clock.start()

func _update_mode_ui() -> void:
	for c in dots_box.get_children():
		c.queue_free()
	if str(context.get("mode", "free")) == "workout":
		var idx := int(context.get("index", 0))
		var total := int(context.get("total", 1))
		mode_label.text = "Workout · %d of %d" % [idx + 1, total]
		for i in total:
			var col := UI.CARD_LIGHT
			if i < idx:
				col = Color("FFB020")
			elif i == idx:
				col = UI.TEXT
			dots_box.add_child(UI.dot(col, 11))
	else:
		mode_label.text = "Free Play"

func _fmt_time(sec: int) -> String:
	return "%d:%02d" % [sec / 60, sec % 60]

func _update_hud() -> void:
	moves_label.text = "Moves: %d" % moves
	time_label.text = "Time: %s" % _fmt_time(elapsed_seconds)

func _update_pb_ui() -> void:
	var pb := Save.get_sort_pb(GAME_ID)
	if pb.is_empty():
		pb_label.text = "No best yet — set one!"
	else:
		pb_label.text = "Best: %d moves · %s" % [int(pb["moves"]), _fmt_time(int(pb["seconds"]))]

func _on_back_pressed() -> void:
	clock.stop()
	state = "idle"
	exited.emit()

func _on_start_pressed() -> void:
	start_overlay.visible = false
	state = "playing"
	clock.start()

func _on_play_again_pressed() -> void:
	end_overlay.visible = false
	_new_game()

func _on_clock_tick() -> void:
	if state != "playing":
		return
	elapsed_seconds += 1
	_update_hud()

func _on_tube_tapped(i: int) -> void:
	if state != "playing":
		return
	if selected == -1:
		if not tubes[i].is_empty():
			selected = i
			board.selected = i
			board.queue_redraw()
			Tone.play(self, 440.0, 0.06, 0.25)
	elif selected == i:
		selected = -1
		board.selected = -1
		board.queue_redraw()
	else:
		if _can_pour(selected, i):
			_do_pour(selected, i)
			Tone.play(self, 560.0, 0.09, 0.3)
		elif not tubes[i].is_empty():
			selected = i
			board.selected = i
			board.queue_redraw()
			Tone.play(self, 440.0, 0.06, 0.25)
		else:
			Tone.play(self, 160.0, 0.15, 0.3)

func _on_undo_pressed() -> void:
	if state != "playing" or history.is_empty():
		return
	tubes = history.pop_back()
	moves = maxi(0, moves - 1)
	selected = -1
	board.selected = -1
	board.tubes = tubes
	board.refresh()
	_update_hud()
	Tone.play(self, 330.0, 0.07, 0.25)

func _on_restart_pressed() -> void:
	if state != "playing":
		return
	tubes = _deep_copy(initial_tubes)
	history.clear()
	moves = 0
	elapsed_seconds = 0
	selected = -1
	board.selected = -1
	board.tubes = tubes
	board.refresh()
	_update_hud()

func _stars() -> int:
	if moves <= 28:
		return 3
	if moves <= 42:
		return 2
	return 1

func _on_win() -> void:
	if state != "playing":
		return
	state = "over"
	clock.stop()
	score = clampi(1200 - 12 * moves - 3 * elapsed_seconds, 100, 1200)
	end_stats.text = "Moves: %d · Time: %s · Score: %d" % [moves, _fmt_time(elapsed_seconds), score]
	end_stars.set_stars(_stars())
	end_overlay.visible = true
	Tone.play(self, 523.25, 0.16, 0.35)
	await get_tree().create_timer(0.14).timeout
	Tone.play(self, 659.25, 0.16, 0.35)
	await get_tree().create_timer(0.14).timeout
	Tone.play(self, 783.99, 0.24, 0.35)

func _on_see_score_pressed() -> void:
	end_overlay.visible = false
	finished.emit(GAME_ID, score, _stars())
