extends Control
## Sequence Memory — Simon-style. Pattern dekho, phir dohrao.
## Soft fail: koi lives nahi. Fail par Retry / ek "Watch it again" chance / End.

signal finished(game_id, score, stars)
signal exited

const UI := preload("res://scripts/ui_factory.gd")
const GameInfo := preload("res://scripts/game_info.gd")
const Tone := preload("res://scripts/tone.gd")

const GAME_ID := "sequence_memory"

var pad_colors: Array = [Color("FB7185"), Color("2DD4BF"), Color("FFB020"), Color("A78BFA")]
var pad_freqs: Array = [329.63, 392.0, 440.0, 523.25]

var sequence: Array = []
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
var pads: Array = []
var pad_normal: Array = []
var pad_lit: Array = []
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
	title_v.add_child(UI.label("Sequence Memory", 21, UI.TEXT))
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
	pb_bar.add_theme_stylebox_override("fill", UI.style(Color("FFB020"), 5))
	v.add_child(pb_bar)

	status_label = UI.label("Watch the pattern…", 20, UI.TEXT)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(status_label)
	score_label = UI.label("Score: 0", 16, UI.MUTED)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(score_label)

	# Pads
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(center)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	center.add_child(grid)
	for i in 4:
		var b := Button.new()
		b.custom_minimum_size = Vector2(148, 148)
		var n := UI.style(pad_colors[i], 24)
		var l := UI.style(pad_colors[i].lightened(0.45), 24)
		pad_normal.append(n)
		pad_lit.append(l)
		b.add_theme_stylebox_override("normal", n)
		b.add_theme_stylebox_override("hover", n)
		b.add_theme_stylebox_override("pressed", l)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.pressed.connect(_on_pad_pressed.bind(i))
		grid.add_child(b)
		pads.append(b)

	start_overlay = _make_overlay("Watch the colours light up,\nthen repeat the pattern.\nEach round adds one more step.", "Start", _on_start_pressed)
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
	var b := UI.button(btn_text, Color("FFB020"), 18)
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
	var t := UI.label("Pattern missed", 22, UI.TEXT)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(t)
	fail_score_label = UI.label("", 15, UI.MUTED)
	fail_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(fail_score_label)
	var retry := UI.button("Retry", Color("FFB020"), 17)
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

# --- Run control ---

func start_run(ctx: Dictionary) -> void:
	context = ctx
	run_token += 1
	state = "idle"
	score = 0
	best_len = 0
	chance_used = false
	sequence = []
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
	chance_used = false
	sequence = []
	_update_score_ui()
	_update_pb_ui()
	_next_round()

func _next_round() -> void:
	if sequence.is_empty():
		for i in 3:
			sequence.append(randi() % 4)
	else:
		sequence.append(randi() % 4)
	_play_sequence()

func _play_sequence() -> void:
	state = "showing"
	status_label.text = "Watch the pattern…"
	var token := run_token
	await get_tree().create_timer(0.6).timeout
	if token != run_token:
		return
	var interval := clampf(0.62 - 0.02 * float(sequence.size()), 0.34, 0.62)
	for pad_idx in sequence:
		if token != run_token:
			return
		_flash_pad(int(pad_idx), interval * 0.72)
		await get_tree().create_timer(interval).timeout
	if token != run_token:
		return
	input_index = 0
	state = "input"
	status_label.text = "Your turn — %d steps" % sequence.size()

func _flash_pad(i: int, dur: float) -> void:
	var b: Button = pads[i]
	b.add_theme_stylebox_override("normal", pad_lit[i])
	Tone.play(self, float(pad_freqs[i]), dur, 0.4)
	await get_tree().create_timer(dur).timeout
	if is_instance_valid(b):
		b.add_theme_stylebox_override("normal", pad_normal[i])

func _on_pad_pressed(i: int) -> void:
	if state != "input":
		return
	_flash_pad(i, 0.16)
	if i == int(sequence[input_index]):
		input_index += 1
		score += 10
		_update_score_ui()
		_update_pb_ui()
		if input_index >= sequence.size():
			_round_complete()
	else:
		_fail()

func _round_complete() -> void:
	state = "showing"
	best_len = sequence.size()
	score += 25
	_update_score_ui()
	_update_pb_ui()
	status_label.text = "Nice! Get ready…"
	var token := run_token
	await get_tree().create_timer(0.9).timeout
	if token != run_token:
		return
	_next_round()

func _fail() -> void:
	state = "over"
	Tone.play(self, 160.0, 0.3, 0.35)
	fail_score_label.text = "Score: %d · Longest pattern: %d" % [score, best_len]
	watch_button.disabled = chance_used
	watch_button.text = "Watch it again (used)" if chance_used else "Watch it again (1 extra chance)"
	fail_overlay.visible = true

func _on_watch_pressed() -> void:
	if chance_used:
		return
	chance_used = true
	fail_overlay.visible = false
	_play_sequence()

func _on_retry_pressed() -> void:
	fail_overlay.visible = false
	_new_game()

func _on_end_pressed() -> void:
	fail_overlay.visible = false
	var stars := clampi(1 + (best_len - 3) / 2, 0, 3)
	finished.emit(GAME_ID, score, stars)
