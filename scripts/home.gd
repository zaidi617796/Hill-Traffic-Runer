extends Control
## Home — Today's Workout card, Free Play list, My Progress link.
## Streak yahan NAHI dikhta (design law) — wo sirf My Progress me hai.

signal play_requested(game_id)
signal workout_requested
signal progress_requested

const UI := preload("res://scripts/ui_factory.gd")
const GameInfo := preload("res://scripts/game_info.gd")
const ProgressRing := preload("res://scripts/progress_ring.gd")

var ring = null # ProgressRing (script type, dynamic calls)
var ring_center_label: Label
var workout_status: Label
var workout_button: Button
var best_labels: Dictionary = {}

func _ready() -> void:
	var mc := UI.margins(self, 20)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	mc.add_child(v)

	var title := UI.label("Daily Brain Workout", 32, UI.TEXT)
	v.add_child(title)
	v.add_child(UI.label("A daily puzzle break. Beat your own best.", 15, UI.MUTED))

	# --- Today's Workout card ---
	var wcard := UI.card()
	v.add_child(wcard)
	var wmargin := MarginContainer.new()
	wmargin.add_theme_constant_override("margin_left", 6)
	wmargin.add_theme_constant_override("margin_right", 6)
	wmargin.add_theme_constant_override("margin_top", 6)
	wmargin.add_theme_constant_override("margin_bottom", 6)
	wcard.add_child(wmargin)
	var wh := HBoxContainer.new()
	wh.add_theme_constant_override("separation", 16)
	wmargin.add_child(wh)

	ring = ProgressRing.new()
	wh.add_child(ring)
	ring_center_label = UI.label("0/2", 17, UI.TEXT)
	ring_center_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ring_center_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ring_center_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	ring.add_child(ring_center_label)

	var wv := VBoxContainer.new()
	wv.add_theme_constant_override("separation", 6)
	wv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wh.add_child(wv)
	wv.add_child(UI.label("Today's Workout", 22, UI.TEXT))
	workout_status = UI.label("Not started", 15, UI.MUTED)
	wv.add_child(workout_status)
	workout_button = UI.button("Start workout", Color("FFB020"), 17)
	workout_button.custom_minimum_size = Vector2(0, 50)
	workout_button.pressed.connect(func() -> void: workout_requested.emit())
	wv.add_child(workout_button)

	# --- Free Play ---
	v.add_child(UI.vspace(2))
	v.add_child(UI.label("Free Play", 20, UI.TEXT))
	for gid in GameInfo.free_play_order():
		v.add_child(_game_row(str(gid)))

	v.add_child(UI.vspace(2))
	var prog_btn := UI.ghost_button("My Progress  →", 17)
	prog_btn.custom_minimum_size = Vector2(0, 52)
	prog_btn.pressed.connect(func() -> void: progress_requested.emit())
	v.add_child(prog_btn)
	v.add_child(UI.label("Fully offline · No sign-up · Your progress stays on this device", 13, UI.MUTED))

func _game_row(game_id: String) -> PanelContainer:
	var info := GameInfo.get_game(game_id)
	var row := UI.card()
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	row.add_child(h)
	h.add_child(UI.dot(info["accent"], 14))
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 2)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(tv)
	tv.add_child(UI.label(str(info["name"]), 18, UI.TEXT))
	var sub := UI.label("", 13, UI.MUTED)
	tv.add_child(sub)
	best_labels[game_id] = sub
	if bool(info["playable"]):
		var b := UI.button("Play", info["accent"], 16)
		b.custom_minimum_size = Vector2(84, 46)
		b.pressed.connect(func() -> void: play_requested.emit(game_id))
		h.add_child(b)
	else:
		var soon := UI.label("Coming soon", 13, Color("FFB020"))
		h.add_child(soon)
	return row

func refresh() -> void:
	var w := Save.ensure_today_workout()
	var total := (w["order"] as Array).size()
	var done := (w["results"] as Dictionary).size()
	ring.set_fraction(float(done) / float(maxi(total, 1)))
	ring_center_label.text = "%d/%d" % [done, total]
	if done == 0:
		workout_status.text = "Not started · %d quick games" % total
		workout_button.text = "Start workout"
	elif done < total:
		workout_status.text = "%d of %d done — keep going" % [done, total]
		workout_button.text = "Continue"
	else:
		workout_status.text = "Done for today. Nice work!"
		workout_button.text = "Play again"
	for gid in best_labels.keys():
		var info := GameInfo.get_game(str(gid))
		var sub: Label = best_labels[gid]
		if bool(info["playable"]):
			var pb := Save.get_pb(str(gid))
			sub.text = str(info["tag"]) + ("   ·   Best: %d" % pb if pb > 0 else "   ·   No best yet")
		else:
			sub.text = str(info["tag"]) + "   ·   Phase 2"
