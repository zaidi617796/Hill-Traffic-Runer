extends Control
## Path Memory — grid par ek rasta roshan hota hai, phir wohi cells
## wohi order me dabao. Har round rasta ek step lamba; grid 3x3 se
## 5x5 tak barhta hai. Soft fail: Retry / ek "Watch it again" chance / End.

signal finished(game_id, score, stars)
signal exited

const UI := preload("res://scripts/ui_factory.gd")
const GameInfo := preload("res://scripts/game_info.gd")
const Tone := preload("res://scripts/tone.gd")

const GAME_ID := "path_memory"
const ACCENT := Color("E879F9")
const BOARD_W := 348.0
const GAP := 10.0

var grid_size: int = 3
var path_cells: Array = []
var path_len: int = 3
var input_index: int = 0
var score: int = 0
var best_len: int = 0
var state: String = "idle" # idle | showing | input | over
var chance_used: bool = false
var context: Dictionary = {}
var run_token: int = 0

var status_label: Label
var score_label: Label
var pb_label: Label
var pb_bar: ProgressBar
var grid: GridContainer
var cells: Array = []
var cell_normal: Array = []
var cell_lit: Array = []
var cell_done: Array = []
var start_overlay: Control
var fail_overlay: Control
var fail_score_label: Label
var watch_button: Button
var dots_box: HBoxContainer
var mode_label: Label

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
	back.pressed.connect(func() -> void: exited.emit())
	top.add_child(back)
	var title_v := VBoxContainer.new()
	title_v.add_theme_constant_override("separation", 0)
	top.add_child(title_v)
	title_v.add_child(UI.label("Path Memory", 21, UI.TEXT))
	mode_label = UI.label("", 13, UI.MUTED)
	title_v.add_child(mode_label)
	top.add_child(UI.hspacer())
	dots_box = HBoxContainer.new()
	dots_box.add_theme_constant_override("separation", 6)
	top.add_child(dots_box)

	# Personal best bar
	pb_label = UI.label("Best: —", 14, UI.MUTED)
	v.add_child(pb_label)
	pb_bar = ProgressBar.new()
	pb_bar.min_value = 0
	pb_bar.max_value = 100
	pb_bar.value = 0
	pb_bar.show_percentage = false
	pb_bar.custom_minimum_size = Vector2(0, 10)
	pb_bar.add_theme_stylebox_override("background", UI.style(UI.CARD_LIGHT, 5))
	pb_bar.add_theme_stylebox_override("fill", UI.style(ACCENT, 5))
	v.add_child(pb_bar)

	status_label = UI.label("Watch the path…", 20, UI.TEXT)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(status_label)
	score_label = UI.label("Score: 0", 16, UI.MUTED)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(score_label)

	# Grid
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(center)
	grid = GridContainer.new()
	grid.add_theme_constant_override("h_separation", int(GAP))
	grid.add_theme_constant_override("v_separation", int(GAP))
	center.add_child(grid)
	_build_grid(grid_size)

	start_overlay = _make_overlay("Watch the path light up,\nthen tap the same cells in order.\nThe path grows every round.", "Start", _on_start_pressed)
	fail_overlay = _make_fail_overlay()

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

func _make_fail_overlay() -> Control:
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
	var t := UI.label("Path missed", 22, UI.TEXT)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(t)
	fail_score_label = UI.label("", 15, UI.MUTED)
	fail_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(fail_score_label)
	var retry := UI.button("Retry", ACCENT, 17)
	retry.custom_minimum_size = Vector2(0, 50)
	retry.pressed.connect(_on_retry_pressed)
	cv.add_child(retry)
	watch_button = UI.ghost_button("Watch it again (1 extra chance)", 15)
	watch_button.custom_minimum_size = Vector2(0, 48)
	watch_button.pressed.connect(_on_watch_pressed)
	cv.add_child(watch_button)
	var end := UI.ghost_button("End & see score", 15)
	end.custom_minimum_size = Vector2(0, 48)
	end.pressed.connect(_on_end_pressed)
	cv.add_child(end)
	ov.visible = false
	add_child(ov)
	return ov

func _build_grid(size: int) -> void:
	for c in grid.get_children():
		grid.remove_child(c)
		c.queue_free()
	cells.clear()
	cell_normal.clear()
	cell_lit.clear()
	cell_done.clear()
	grid.columns = size
	var cell := (BOARD_W - float(size - 1) * GAP) / float(size)
	for i in size * size:
		var b := Button.new()
		b.custom_minimum_size = Vector2(cell, cell)
		var n := UI.style(UI.CARD_LIGHT, 14)
		var l := UI.style(ACCENT.lightened(0.25), 14)
		var d := UI.style(ACCENT.darkened(0.2), 14)
		cell_normal.append(n)
		cell_lit.append(l)
		cell_done.append(d)
		b.add_theme_stylebox_override("normal", n)
		b.add_theme_stylebox_override("hover", n)
		b.add_theme_stylebox_override("pressed", l)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.pressed.connect(_on_cell_pressed.bind(i))
		grid.add_child(b)
		cells.append(b)

func _reset_cells() -> void:
	for i in cells.size():
		(cells[i] as Button).add_theme_stylebox_override("normal", cell_normal[i])

# --- Run control ---

func start_run(ctx: Dictionary) -> void:
	context = ctx
	run_token += 1
	state = "idle"
	score = 0
	best_len = 0
	path_len = 3
	chance_used = false
	path_cells = []
	if grid_size != 3:
		grid_size = 3
		_build_grid(grid_size)
	_reset_cells()
	fail_overlay.visible = false
	start_overlay.visible = true
	status_label.text = "Ready when you are"
	_update_score_ui()
	_update_mode_ui()
	_update_pb_ui()

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

func _update_score_ui() -> void:
	score_label.text = "Score: %d" % score

func _update_pb_ui() -> void:
	var pb := Save.get_pb(GAME_ID)
	pb_label.text = "Best: %d" % pb if pb > 0 else "No best yet — set one!"
	pb_bar.max_value = maxi(maxi(pb, score), 100)
	pb_bar.value = score

func _on_start_pressed() -> void:
	start_overlay.visible = false
	_new_game()

func _new_game() -> void:
	run_token += 1
	score = 0
	best_len = 0
	path_len = 3
	chance_used = false
	if grid_size != 3:
		grid_size = 3
		_build_grid(grid_size)
	_update_score_ui()
	_update_pb_ui()
	_next_round()

func _grid_size_for(length: int) -> int:
	if length <= 5:
		return 3
	if length <= 8:
		return 4
	return 5

func _neighbors(idx: int, size: int) -> Array:
	var out: Array = []
	var col := idx % size
	var row := idx / size
	if row > 0:
		out.append(idx - size)
	if row < size - 1:
		out.append(idx + size)
	if col > 0:
		out.append(idx - 1)
	if col < size - 1:
		out.append(idx + 1)
	return out

# Self-avoiding random walk — rasta kabhi ek cell do dafa nahi chhoota.
func _gen_path(length: int, size: int) -> Array:
	var best: Array = []
	for attempt in 80:
		var path: Array = []
		var visited := {}
		var cur := randi() % (size * size)
		path.append(cur)
		visited[cur] = true
		while path.size() < length:
			var opts: Array = []
			for n in _neighbors(cur, size):
				if not visited.has(int(n)):
					opts.append(int(n))
			if opts.is_empty():
				break
			cur = int(opts[randi() % opts.size()])
			path.append(cur)
			visited[cur] = true
		if path.size() >= length:
			return path
		if path.size() > best.size():
			best = path
	return best

func _next_round() -> void:
	var size := _grid_size_for(path_len)
	if size != grid_size:
		grid_size = size
		_build_grid(grid_size)
	path_cells = _gen_path(path_len, grid_size)
	_play_path()

func _play_path() -> void:
	state = "showing"
	status_label.text = "Watch the path…"
	_reset_cells()
	var token := run_token
	await get_tree().create_timer(0.6).timeout
	if token != run_token:
		return
	var interval := clampf(0.62 - 0.02 * float(path_cells.size()), 0.34, 0.62)
	for step in path_cells.size():
		if token != run_token:
			return
		_flash_cell(int(path_cells[step]), interval * 0.72, 330.0 + 40.0 * float(step))
		await get_tree().create_timer(interval).timeout
	if token != run_token:
		return
	input_index = 0
	state = "input"
	status_label.text = "Your turn — %d steps" % path_cells.size()

func _flash_cell(i: int, dur: float, freq: float) -> void:
	var b: Button = cells[i]
	b.add_theme_stylebox_override("normal", cell_lit[i])
	Tone.play(self, freq, dur, 0.4)
	await get_tree().create_timer(dur).timeout
	if is_instance_valid(b):
		b.add_theme_stylebox_override("normal", cell_normal[i])

func _on_cell_pressed(i: int) -> void:
	if state != "input":
		return
	if i == int(path_cells[input_index]):
		var b: Button = cells[i]
		b.add_theme_stylebox_override("normal", cell_done[i])
		Tone.play(self, 330.0 + 40.0 * float(input_index), 0.12, 0.35)
		input_index += 1
		score += 10
		_update_score_ui()
		_update_pb_ui()
		if input_index >= path_cells.size():
			_round_complete()
	else:
		_fail()

func _round_complete() -> void:
	state = "showing"
	best_len = path_cells.size()
	score += 25
	_update_score_ui()
	_update_pb_ui()
	status_label.text = "Nice! Get ready…"
	var token := run_token
	await get_tree().create_timer(0.9).timeout
	if token != run_token:
		return
	path_len += 1
	_next_round()

func _fail() -> void:
	state = "over"
	Tone.play(self, 160.0, 0.3, 0.35)
	fail_score_label.text = "Score: %d · Longest path: %d" % [score, best_len]
	watch_button.disabled = chance_used
	watch_button.text = "Watch it again (used)" if chance_used else "Watch it again (1 extra chance)"
	fail_overlay.visible = true

func _on_watch_pressed() -> void:
	if chance_used:
		return
	chance_used = true
	fail_overlay.visible = false
	_play_path()

func _on_retry_pressed() -> void:
	fail_overlay.visible = false
	_new_game()

func _on_end_pressed() -> void:
	fail_overlay.visible = false
	var stars := clampi(1 + (best_len - 3) / 2, 0, 3)
	finished.emit(GAME_ID, score, stars)
