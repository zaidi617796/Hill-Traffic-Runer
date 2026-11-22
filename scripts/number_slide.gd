extends Control
## Number Slide — classic 3×3 sliding puzzle (Klotski-style toy jaisa).
## Scramble hamesha solved state se valid moves se banti hai = har puzzle
## guaranteed solvable. Hint = BFS shortest path (session me 3 free).

signal finished(game_id, score, stars)
signal exited

const UI := preload("res://scripts/ui_factory.gd")
const GameInfo := preload("res://scripts/game_info.gd")
const Tone := preload("res://scripts/tone.gd")
const StarsRow := preload("res://scripts/stars_row.gd")

const GAME_ID := "number_slide"
const CELL := 104.0
const GAP := 8.0
const SOLVED: Array = [1, 2, 3, 4, 5, 6, 7, 8, 0]

var words: Array = ["one", "two", "three", "four", "five", "six", "seven", "eight"]
var pastels: Array = [Color("FFD6A5"), Color("FDFFB6"), Color("CAFFBF"), Color("9BF6FF"), Color("A0C4FF"), Color("BDB2FF"), Color("FFC6FF"), Color("FFE5EC")]

var board: Array = []
var tiles: Dictionary = {} # tile value -> Button
var tile_styles: Dictionary = {} # tile value -> normal StyleBox
var moves: int = 0
var seconds: int = 0
var timer_running: bool = false
var start_msec: int = 0
var busy: bool = false
var won: bool = false
var last_score: int = 0
var last_stars: int = 0
var context: Dictionary = {}

var dist_table: Dictionary = {}
var table_ready: bool = false

var moves_label: Label
var time_label: Label
var hint_button: Button
var pb_label: Label
var pb_bar: ProgressBar
var board_area: Control
var win_overlay: Control
var win_stats: Label
var win_stars = null # StarsRow (script type, dynamic calls)
var dots_box: HBoxContainer
var mode_label: Label
var timer_node: Timer

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
	title_v.add_child(UI.label1("Number Slide", 21, UI.TEXT))
	mode_label = UI.label1("", 13, UI.MUTED)
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
	pb_bar.add_theme_stylebox_override("fill", UI.style(Color("A0C4FF"), 5))
	v.add_child(pb_bar)

	# Info row
	var info := HBoxContainer.new()
	info.add_theme_constant_override("separation", 10)
	v.add_child(info)
	moves_label = UI.label1("Moves: 0", 17, UI.TEXT)
	info.add_child(moves_label)
	time_label = UI.label1("Time: 0:00", 17, UI.TEXT)
	info.add_child(time_label)
	info.add_child(UI.hspacer())
	hint_button = UI.ghost_button("Hint", 15)
	hint_button.custom_minimum_size = Vector2(104, 44)
	hint_button.pressed.connect(_on_hint_pressed)
	info.add_child(hint_button)
	var new_btn := UI.ghost_button("New", 15)
	new_btn.custom_minimum_size = Vector2(76, 44)
	new_btn.pressed.connect(func() -> void: _new_puzzle())
	info.add_child(new_btn)

	# Board
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(center)
	board_area = Control.new()
	board_area.custom_minimum_size = Vector2(CELL * 3 + GAP * 2, CELL * 3 + GAP * 2)
	center.add_child(board_area)
	var board_bg := Panel.new()
	board_bg.position = Vector2(-10, -10)
	board_bg.size = Vector2(CELL * 3 + GAP * 2 + 20, CELL * 3 + GAP * 2 + 20)
	board_bg.add_theme_stylebox_override("panel", UI.style(UI.CARD, 20))
	board_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board_area.add_child(board_bg)
	for val in range(1, 9):
		board_area.add_child(_make_tile(val))

	var note := UI.label("Every puzzle is solvable — no rigged boards.", 13, UI.MUTED)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(note)

	timer_node = Timer.new()
	timer_node.wait_time = 0.25
	timer_node.timeout.connect(_on_timer_tick)
	add_child(timer_node)

	win_overlay = _make_win_overlay()

func _make_tile(val: int) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(CELL, CELL)
	b.size = Vector2(CELL, CELL)
	b.text = str(val)
	b.add_theme_font_size_override("font_size", 38)
	var dark := Color("2B2B3A")
	b.add_theme_color_override("font_color", dark)
	b.add_theme_color_override("font_hover_color", dark)
	b.add_theme_color_override("font_pressed_color", dark)
	var n := UI.style(pastels[val - 1], 18)
	tile_styles[val] = n
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", UI.style(pastels[val - 1].lightened(0.06), 18))
	b.add_theme_stylebox_override("pressed", UI.style(pastels[val - 1].darkened(0.08), 18))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var wl := Label.new()
	wl.text = words[val - 1]
	wl.add_theme_font_size_override("font_size", 13)
	wl.add_theme_color_override("font_color", Color(0.17, 0.17, 0.23, 0.6))
	wl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wl.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	wl.offset_top = -30
	wl.offset_bottom = -8
	wl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(wl)
	b.pressed.connect(_on_tile_pressed.bind(val))
	tiles[val] = b
	return b

func _make_win_overlay() -> Control:
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
	win_stars = StarsRow.new()
	win_stars.star_size = 36.0
	var sc := CenterContainer.new()
	sc.add_child(win_stars)
	cv.add_child(sc)
	win_stats = UI.label("", 15, UI.MUTED)
	win_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(win_stats)
	var see := UI.button("See score", Color("FFB020"), 17)
	see.custom_minimum_size = Vector2(0, 50)
	see.pressed.connect(_on_see_score_pressed)
	cv.add_child(see)
	var again := UI.ghost_button("Play again", 15)
	again.custom_minimum_size = Vector2(0, 48)
	again.pressed.connect(func() -> void: _new_puzzle())
	cv.add_child(again)
	ov.visible = false
	add_child(ov)
	return ov

# --- Run control ---

func start_run(ctx: Dictionary) -> void:
	context = ctx
	win_overlay.visible = false
	_update_mode_ui()
	_update_hint_button()
	_new_puzzle()

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

func _cell_pos(idx: int) -> Vector2:
	return Vector2((idx % 3) * (CELL + GAP), (idx / 3) * (CELL + GAP))

func _neighbor_indices(idx: int) -> Array:
	var out: Array = []
	var col := idx % 3
	var row := idx / 3
	if row > 0:
		out.append(idx - 3)
	if row < 2:
		out.append(idx + 3)
	if col > 0:
		out.append(idx - 1)
	if col < 2:
		out.append(idx + 1)
	return out

func _new_puzzle() -> void:
	win_overlay.visible = false
	board = SOLVED.duplicate()
	var prev_empty := -1
	var empty := 8
	for i in 40:
		var opts: Array = []
		for n in _neighbor_indices(empty):
			if int(n) != prev_empty:
				opts.append(int(n))
		var pick := int(opts[randi() % opts.size()])
		board[empty] = board[pick]
		board[pick] = 0
		prev_empty = empty
		empty = pick
	if board == SOLVED:
		_new_puzzle()
		return
	moves = 0
	seconds = 0
	won = false
	busy = false
	timer_running = false
	timer_node.stop()
	_layout_tiles(false)
	_update_info()
	_update_pb_ui(0)

func _layout_tiles(animate: bool) -> void:
	for val in range(1, 9):
		var b: Button = tiles[val]
		var target := _cell_pos(board.find(val))
		if animate:
			var tw := create_tween()
			tw.tween_property(b, "position", target, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		else:
			b.position = target

func _on_tile_pressed(val: int) -> void:
	if busy or won:
		return
	var idx := board.find(val)
	var empty := board.find(0)
	if not _neighbor_indices(empty).has(idx):
		return
	if not timer_running:
		timer_running = true
		start_msec = Time.get_ticks_msec()
		timer_node.start()
	busy = true
	board[empty] = val
	board[idx] = 0
	moves += 1
	var b: Button = tiles[val]
	board_area.move_child(b, board_area.get_child_count() - 1)
	var tw := create_tween()
	tw.tween_property(b, "position", _cell_pos(empty), 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	Tone.play(self, 240.0, 0.06, 0.2)
	await tw.finished
	busy = false
	_update_info()
	if board == SOLVED:
		_win()

func _on_timer_tick() -> void:
	if timer_running:
		seconds = int((Time.get_ticks_msec() - start_msec) / 1000)
		_update_info()

func _time_str() -> String:
	return "%d:%02d" % [seconds / 60, seconds % 60]

func _update_info() -> void:
	moves_label.text = "Moves: %d" % moves
	time_label.text = "Time: %s" % _time_str()

func _update_pb_ui(current_score: int) -> void:
	var pb := Save.get_pb(GAME_ID)
	pb_label.text = "Best: %d" % pb if pb > 0 else "No best yet — set one!"
	pb_bar.max_value = maxi(maxi(pb, current_score), 100)
	pb_bar.value = current_score

func _win() -> void:
	won = true
	timer_running = false
	timer_node.stop()
	last_score = maxi(50, 600 - 8 * moves - 3 * seconds)
	if moves <= 22:
		last_stars = 3
	elif moves <= 34:
		last_stars = 2
	else:
		last_stars = 1
	_update_pb_ui(last_score)
	win_stats.text = "Moves: %d · Time: %s · Score: %d" % [moves, _time_str(), last_score]
	win_stars.set_stars(last_stars)
	win_overlay.visible = true
	Tone.play(self, 523.25, 0.16, 0.35)
	await get_tree().create_timer(0.14).timeout
	Tone.play(self, 659.25, 0.16, 0.35)
	await get_tree().create_timer(0.14).timeout
	Tone.play(self, 783.99, 0.24, 0.35)

func _on_see_score_pressed() -> void:
	win_overlay.visible = false
	finished.emit(GAME_ID, last_score, last_stars)

# --- Hint (BFS shortest path) ---

func _update_hint_button() -> void:
	var left := Save.slide_hints_left
	hint_button.text = "Hint · %d" % left
	hint_button.disabled = left <= 0

func _key_of(b: Array) -> String:
	var bytes := PackedByteArray()
	bytes.resize(9)
	for i in 9:
		bytes[i] = int(b[i]) + 48
	return bytes.get_string_from_ascii()

func _build_table() -> void:
	dist_table.clear()
	var start_key := "123456780"
	dist_table[start_key] = 0
	var queue: Array = [start_key]
	var head := 0
	while head < queue.size():
		var cur: String = queue[head]
		head += 1
		var d := int(dist_table[cur])
		var bytes := cur.to_ascii_buffer()
		var zi := bytes.find(48)
		for nzi in _neighbor_indices(zi):
			var nb := bytes.duplicate()
			nb[zi] = nb[nzi]
			nb[nzi] = 48
			var nk := nb.get_string_from_ascii()
			if not dist_table.has(nk):
				dist_table[nk] = d + 1
				queue.append(nk)
	table_ready = true

func _on_hint_pressed() -> void:
	if won or busy or Save.slide_hints_left <= 0:
		return
	if not table_ready:
		hint_button.text = "Hint · …"
		await get_tree().process_frame
		_build_table()
	var key := _key_of(board)
	if not dist_table.has(key):
		_update_hint_button()
		return
	var d := int(dist_table[key])
	if d == 0:
		_update_hint_button()
		return
	var empty := board.find(0)
	for nzi in _neighbor_indices(empty):
		var nb := board.duplicate()
		nb[empty] = nb[nzi]
		nb[nzi] = 0
		if int(dist_table.get(_key_of(nb), 999)) == d - 1:
			Save.slide_hints_left -= 1
			_update_hint_button()
			_highlight_tile(int(board[nzi]))
			return
	_update_hint_button()

func _highlight_tile(val: int) -> void:
	var b: Button = tiles[val]
	var lit := UI.style(pastels[val - 1].lightened(0.35), 18, Color.WHITE, 4)
	b.add_theme_stylebox_override("normal", lit)
	await get_tree().create_timer(1.2).timeout
	if is_instance_valid(b):
		b.add_theme_stylebox_override("normal", tile_styles[val])
