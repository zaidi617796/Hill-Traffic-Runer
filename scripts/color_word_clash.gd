extends Control
## Color Word Clash — Stroop game. Lafz kuch kehta hai, rang kuch aur.
## Ink (rang) wala button dabao, lafz wala nahi. 60 second ki race:
## score = sahi jawab; ghalat tap par waqt kat-ta hai. Sahi jawab badhne
## par naye rang unlock hote hain (pehle 4, phir 5, phir 6).

signal finished(game_id, score, stars)
signal exited

const UI := preload("res://scripts/ui_factory.gd")
const GameInfo := preload("res://scripts/game_info.gd")
const Tone := preload("res://scripts/tone.gd")
const StarsRow := preload("res://scripts/stars_row.gd")

const GAME_ID := "color_word_clash"
const ACCENT := Color("4ADE80")
const ROUND_SECONDS := 60
const WRONG_PENALTY := 2

# name, ink rang, button text dark ho ya white
var color_defs: Array = [
	{"name": "RED", "color": Color("EF4444"), "dark_text": false},
	{"name": "BLUE", "color": Color("3B82F6"), "dark_text": false},
	{"name": "GREEN", "color": Color("22C55E"), "dark_text": false},
	{"name": "YELLOW", "color": Color("FACC15"), "dark_text": true},
	{"name": "ORANGE", "color": Color("F97316"), "dark_text": false},
	{"name": "PURPLE", "color": Color("A855F7"), "dark_text": false},
]

var active_count: int = 4
var word_idx: int = 0
var ink_idx: int = 0
var correct_count: int = 0
var wrong_count: int = 0
var score: int = 0
var time_left: int = ROUND_SECONDS
var state: String = "idle" # idle | playing | over
var context: Dictionary = {}

var status_label: Label
var score_label: Label
var time_label: Label
var time_bar: ProgressBar
var word_label: Label
var pb_label: Label
var pb_bar: ProgressBar
var answer_buttons: Array = []
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
	title_v.add_child(UI.label1("Color Word Clash", 21, UI.TEXT))
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

	# HUD: score + time
	var hud := HBoxContainer.new()
	hud.add_theme_constant_override("separation", 10)
	v.add_child(hud)
	score_label = UI.label1("Score: 0", 17, UI.TEXT)
	hud.add_child(score_label)
	hud.add_child(UI.hspacer())
	time_label = UI.label1("Time: %d" % ROUND_SECONDS, 17, UI.TEXT)
	hud.add_child(time_label)
	time_bar = ProgressBar.new()
	time_bar.min_value = 0
	time_bar.max_value = ROUND_SECONDS
	time_bar.value = ROUND_SECONDS
	time_bar.show_percentage = false
	time_bar.custom_minimum_size = Vector2(0, 10)
	time_bar.add_theme_stylebox_override("background", UI.style(UI.CARD_LIGHT, 5))
	time_bar.add_theme_stylebox_override("fill", UI.style(ACCENT, 5))
	v.add_child(time_bar)

	status_label = UI.label("Tap the ink colour, not the word!", 17, UI.TEXT)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(status_label)

	# Bara lafz — ink rang me
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(center)
	word_label = UI.label1("?", 68, UI.MUTED)
	word_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(word_label)

	# Jawab wale buttons
	var grid_center := CenterContainer.new()
	v.add_child(grid_center)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	grid_center.add_child(grid)
	for i in color_defs.size():
		var d: Dictionary = color_defs[i]
		var font_col := UI.DARK_TEXT if bool(d["dark_text"]) else Color.WHITE
		var b := UI.button(str(d["name"]), d["color"], 19, font_col)
		b.custom_minimum_size = Vector2(156, 62)
		b.pressed.connect(_on_color_pressed.bind(i))
		grid.add_child(b)
		answer_buttons.append(b)

	clock = Timer.new()
	clock.wait_time = 1.0
	clock.timeout.connect(_on_clock_tick)
	add_child(clock)

	start_overlay = _make_overlay("The word says one colour,\nthe ink is another.\nTap the INK colour — fast!\nYou have 60 seconds.", "Start", _on_start_pressed)
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
	var t := UI.label("Time's up!", 26, UI.TEXT)
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

# --- Run control ---

func start_run(ctx: Dictionary) -> void:
	context = ctx
	clock.stop()
	state = "idle"
	score = 0
	correct_count = 0
	wrong_count = 0
	active_count = 4
	time_left = ROUND_SECONDS
	end_overlay.visible = false
	start_overlay.visible = true
	word_label.text = "?"
	word_label.add_theme_color_override("font_color", UI.MUTED)
	status_label.text = "Tap the ink colour, not the word!"
	status_label.add_theme_color_override("font_color", UI.TEXT)
	_update_score_ui()
	_update_time_ui()
	_update_mode_ui()
	_update_pb_ui()
	_refresh_buttons()

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

func _update_time_ui() -> void:
	time_label.text = "Time: %d" % maxi(time_left, 0)
	time_bar.value = maxi(time_left, 0)

func _update_pb_ui() -> void:
	var pb := Save.get_pb(GAME_ID)
	pb_label.text = "Best: %d" % pb if pb > 0 else "No best yet — set one!"
	pb_bar.max_value = maxi(maxi(pb, score), 100)
	pb_bar.value = score

func _refresh_buttons() -> void:
	for i in answer_buttons.size():
		(answer_buttons[i] as Button).visible = i < active_count

func _on_back_pressed() -> void:
	clock.stop()
	state = "idle"
	exited.emit()

func _on_start_pressed() -> void:
	start_overlay.visible = false
	_new_game()

func _on_play_again_pressed() -> void:
	end_overlay.visible = false
	_new_game()

func _new_game() -> void:
	score = 0
	correct_count = 0
	wrong_count = 0
	active_count = 4
	time_left = ROUND_SECONDS
	state = "playing"
	_update_score_ui()
	_update_time_ui()
	_update_pb_ui()
	_refresh_buttons()
	_next_question()
	clock.start()

func _next_question() -> void:
	word_idx = randi() % active_count
	if randi() % 10 < 3:
		ink_idx = word_idx # kabhi kabhi match bhi ho
	else:
		ink_idx = randi() % active_count
		while ink_idx == word_idx:
			ink_idx = randi() % active_count
	word_label.text = str(color_defs[word_idx]["name"])
	word_label.add_theme_color_override("font_color", color_defs[ink_idx]["color"])
	status_label.text = "Tap the ink colour, not the word!"
	status_label.add_theme_color_override("font_color", UI.TEXT)
	_refresh_buttons()

func _on_color_pressed(i: int) -> void:
	if state != "playing":
		return
	if i == ink_idx:
		correct_count += 1
		score += 10
		Tone.play(self, 660.0, 0.08, 0.3)
		_update_score_ui()
		_update_pb_ui()
		var unlocked := ""
		if correct_count == 10 and active_count == 4:
			active_count = 5
			unlocked = "New colour unlocked: ORANGE!"
		elif correct_count == 20 and active_count == 5:
			active_count = 6
			unlocked = "New colour unlocked: PURPLE!"
		_next_question()
		if unlocked != "":
			status_label.text = unlocked
			status_label.add_theme_color_override("font_color", ACCENT)
	else:
		wrong_count += 1
		time_left = maxi(0, time_left - WRONG_PENALTY)
		Tone.play(self, 160.0, 0.2, 0.3)
		status_label.text = "That's the word — tap the ink colour!"
		status_label.add_theme_color_override("font_color", Color("FB7185"))
		_update_time_ui()
		if time_left <= 0:
			_time_up()

func _on_clock_tick() -> void:
	if state != "playing":
		return
	time_left -= 1
	_update_time_ui()
	if time_left <= 0:
		_time_up()

func _stars() -> int:
	return clampi(1 + (correct_count - 8) / 8, 0, 3)

func _time_up() -> void:
	if state != "playing":
		return
	state = "over"
	clock.stop()
	time_left = 0
	_update_time_ui()
	end_stats.text = "Correct: %d · Wrong: %d · Score: %d" % [correct_count, wrong_count, score]
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
