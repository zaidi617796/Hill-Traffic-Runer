extends Control
## Odd One Out — saari tiles ek jaisi, sirf ek mukhtalif.
## Bar khatam hone se pehle mukhtalif tile dabao. Har round: grid bara,
## farq zyada bareek. Ghalat tap par waqt kat-ta hai; waqt khatam = soft fail.

signal finished(game_id, score, stars)
signal exited

const UI := preload("res://scripts/ui_factory.gd")
const GameInfo := preload("res://scripts/game_info.gd")
const Tone := preload("res://scripts/tone.gd")

const GAME_ID := "odd_one_out"
const ACCENT := Color("FB923C")
const BOARD_W := 348.0
const GAP := 8.0
const WRONG_PENALTY := 1.0

var palette: Array = [Color("FB7185"), Color("2DD4BF"), Color("FFB020"), Color("A78BFA"), Color("A0C4FF"), Color("4ADE80"), Color("FB923C"), Color("F472B6")]

var rounds_done: int = 0
var score: int = 0
var cols: int = 3
var odd_index: int = 0
var round_time: float = 6.0
var time_left: float = 6.0
var state: String = "idle" # idle | playing | over
var context: Dictionary = {}
var run_token: int = 0

var status_label: Label
var score_label: Label
var pb_label: Label
var pb_bar: ProgressBar
var time_bar: ProgressBar
var grid: GridContainer
var tiles: Array = []
var tile_style: StyleBoxFlat
var start_overlay: Control
var fail_overlay: Control
var fail_stats: Label
var dots_box: HBoxContainer
var mode_label: Label
var tick_timer: Timer

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
	title_v.add_child(UI.label1("Odd One Out", 21, UI.TEXT))
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
	pb_bar.add_theme_stylebox_override("fill", UI.style(ACCENT, 5))
	v.add_child(pb_bar)

	status_label = UI.label("Find the tile that is different", 19, UI.TEXT)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(status_label)
	score_label = UI.label1("Score: 0 · Round 1", 16, UI.MUTED)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(score_label)

	# Round time bar
	time_bar = ProgressBar.new()
	time_bar.min_value = 0
	time_bar.max_value = 100
	time_bar.value = 100
	time_bar.show_percentage = false
	time_bar.custom_minimum_size = Vector2(0, 10)
	time_bar.add_theme_stylebox_override("background", UI.style(UI.CARD_LIGHT, 5))
	time_bar.add_theme_stylebox_override("fill", UI.style(ACCENT, 5))
	v.add_child(time_bar)

	# Tiles grid
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(center)
	grid = GridContainer.new()
	grid.add_theme_constant_override("h_separation", int(GAP))
	grid.add_theme_constant_override("v_separation", int(GAP))
	center.add_child(grid)

	tick_timer = Timer.new()
	tick_timer.wait_time = 0.05
	tick_timer.timeout.connect(_on_tick)
	add_child(tick_timer)

	start_overlay = _make_overlay("Every tile looks the same —\nexcept one. Tap the different tile\nbefore the bar runs out.", "Start", _on_start_pressed)
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
	var t := UI.label("Out of time", 22, UI.TEXT)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(t)
	fail_stats = UI.label("", 15, UI.MUTED)
	fail_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(fail_stats)
	var retry := UI.button("Retry", ACCENT, 17)
	retry.custom_minimum_size = Vector2(0, 50)
	retry.pressed.connect(_on_retry_pressed)
	cv.add_child(retry)
	var end := UI.ghost_button("End & see score", 15)
	end.custom_minimum_size = Vector2(0, 48)
	end.pressed.connect(_on_end_pressed)
	cv.add_child(end)
	ov.visible = false
	add_child(ov)
	return ov

# --- Run control ---

func start_run(ctx: Dictionary) -> void:
	context = ctx
	run_token += 1
	tick_timer.stop()
	state = "idle"
	score = 0
	rounds_done = 0
	fail_overlay.visible = false
	start_overlay.visible = true
	status_label.text = "Find the tile that is different"
	_update_score_ui()
	_update_time_ui()
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
	score_label.text = "Score: %d · Round %d" % [score, rounds_done + 1]

func _update_time_ui() -> void:
	time_bar.value = 100.0 * clampf(time_left / maxf(round_time, 0.01), 0.0, 1.0)

func _update_pb_ui() -> void:
	var pb := Save.get_pb(GAME_ID)
	pb_label.text = "Best: %d" % pb if pb > 0 else "No best yet — set one!"
	pb_bar.max_value = maxi(maxi(pb, score), 100)
	pb_bar.value = score

func _on_back_pressed() -> void:
	run_token += 1
	tick_timer.stop()
	state = "idle"
	exited.emit()

func _on_start_pressed() -> void:
	start_overlay.visible = false
	_new_game()

func _on_retry_pressed() -> void:
	fail_overlay.visible = false
	_new_game()

func _new_game() -> void:
	run_token += 1
	score = 0
	rounds_done = 0
	_update_score_ui()
	_update_pb_ui()
	_setup_round()

func _setup_round() -> void:
	run_token += 1
	state = "playing"
	cols = mini(6, 3 + rounds_done / 2)
	round_time = maxf(3.0, 6.0 - 0.3 * float(rounds_done))
	time_left = round_time
	_build_tiles()
	status_label.text = "Find the tile that is different"
	status_label.add_theme_color_override("font_color", UI.TEXT)
	_update_score_ui()
	_update_time_ui()
	tick_timer.start()

func _build_tiles() -> void:
	for c in grid.get_children():
		grid.remove_child(c)
		c.queue_free()
	tiles.clear()
	grid.columns = cols
	var count := cols * cols
	var tile := (BOARD_W - float(cols - 1) * GAP) / float(cols)
	var base: Color = palette[randi() % palette.size()]
	var mode := randi() % 3 # 0 = shade, 1 = shape, 2 = size
	odd_index = randi() % count
	tile_style = UI.style(UI.CARD_LIGHT, 12)
	var shape_size := tile * 0.52
	for i in count:
		var b := Button.new()
		b.custom_minimum_size = Vector2(tile, tile)
		b.add_theme_stylebox_override("normal", tile_style)
		b.add_theme_stylebox_override("hover", tile_style)
		b.add_theme_stylebox_override("pressed", tile_style)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		var col := base
		var s := shape_size
		var radius := int(s * 0.28)
		if i == odd_index:
			if mode == 0:
				var delta := maxf(0.07, 0.30 - 0.025 * float(rounds_done))
				col = base.lightened(delta) if randi() % 2 == 0 else base.darkened(delta * 0.8)
			elif mode == 1:
				radius = int(s / 2.0)
			else:
				s = shape_size * minf(0.85, 0.70 + 0.015 * float(rounds_done))
		var shape := Panel.new()
		shape.custom_minimum_size = Vector2(s, s)
		shape.size = Vector2(s, s)
		shape.position = Vector2((tile - s) / 2.0, (tile - s) / 2.0)
		shape.add_theme_stylebox_override("panel", UI.style(col, radius))
		shape.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(shape)
		b.pressed.connect(_on_tile_pressed.bind(i))
		grid.add_child(b)
		tiles.append(b)

func _on_tile_pressed(i: int) -> void:
	if state != "playing":
		return
	if i == odd_index:
		tick_timer.stop()
		state = "showing"
		rounds_done += 1
		score += 100 + int(time_left * 10.0)
		Tone.play(self, 740.0, 0.09, 0.3)
		_update_score_ui()
		_update_pb_ui()
		var b: Button = tiles[i]
		b.add_theme_stylebox_override("normal", UI.style(Color("22C55E"), 12))
		var token := run_token
		await get_tree().create_timer(0.25).timeout
		if token != run_token:
			return
		_setup_round()
	else:
		time_left = maxf(0.0, time_left - WRONG_PENALTY)
		Tone.play(self, 160.0, 0.18, 0.3)
		status_label.text = "Not that one — keep looking!"
		status_label.add_theme_color_override("font_color", Color("FB7185"))
		var b2: Button = tiles[i]
		b2.add_theme_stylebox_override("normal", UI.style(Color("7F1D2D"), 12))
		_update_time_ui()
		var token2 := run_token
		await get_tree().create_timer(0.25).timeout
		if token2 == run_token and is_instance_valid(b2):
			b2.add_theme_stylebox_override("normal", tile_style)
		if time_left <= 0.0 and state == "playing":
			_fail()

func _on_tick() -> void:
	if state != "playing":
		return
	time_left -= 0.05
	_update_time_ui()
	if time_left <= 0.0:
		time_left = 0.0
		_fail()

func _fail() -> void:
	if state == "over":
		return
	state = "over"
	tick_timer.stop()
	Tone.play(self, 160.0, 0.3, 0.35)
	fail_stats.text = "Rounds cleared: %d · Score: %d" % [rounds_done, score]
	fail_overlay.visible = true

func _on_end_pressed() -> void:
	fail_overlay.visible = false
	var stars := clampi(1 + (rounds_done - 3) / 3, 0, 3)
	finished.emit(GAME_ID, score, stars)
