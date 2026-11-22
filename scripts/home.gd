extends Control
## Home — Today's Workout card, Free Play list, My Progress link.
## Streak yahan NAHI dikhta (design law) — wo sirf My Progress me hai.
## Poora content ScrollContainer me hai: chhoti/ajeeeb screen par bhi
## cards kabhi phailte nahi, list scroll ho jati hai. Har game row ki
## height fix hai (76) — bare autowrap Label ko HBox me seedha rakhne
## se Godot us ki width ~1px kar deta tha aur "Coming soon" har card
## ko 400+ px uncha kheench deta tha; is liye ab chip (PanelContainer)
## istemal hota hai jis ki size pehle se tay hai.

signal play_requested(game_id)
signal workout_requested
signal progress_requested

const UI := preload("res://scripts/ui_factory.gd")
const GameInfo := preload("res://scripts/game_info.gd")
const ProgressRing := preload("res://scripts/progress_ring.gd")

const ROW_HEIGHT := 76.0

var ring = null # ProgressRing (script type, dynamic calls)
var ring_center_label: Label
var workout_status: Label
var workout_button: Button
var best_labels: Dictionary = {}
var game_rows: Dictionary = {} # game_id -> PanelContainer (layout QA ke liye)
var soon_chips: Dictionary = {} # game_id -> PanelContainer chip

func _ready() -> void:
	var mc := UI.margins(self, 20)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	mc.add_child(scroll)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(v)

	var title := UI.label("Daily Brain Workout", 32, UI.TEXT)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	v.add_child(title)
	var subtitle := UI.label("A daily puzzle break. Beat your own best.", 15, UI.MUTED)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_OFF
	v.add_child(subtitle)

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
	ring.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	wh.add_child(ring)
	ring_center_label = UI.label("0/2", 17, UI.TEXT)
	ring_center_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	ring_center_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ring_center_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ring_center_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	ring.add_child(ring_center_label)

	var wv := VBoxContainer.new()
	wv.add_theme_constant_override("separation", 6)
	wv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wh.add_child(wv)
	var wtitle := UI.label("Today's Workout", 22, UI.TEXT)
	wtitle.autowrap_mode = TextServer.AUTOWRAP_OFF
	wv.add_child(wtitle)
	workout_status = UI.label("Not started", 15, UI.MUTED)
	workout_status.autowrap_mode = TextServer.AUTOWRAP_OFF
	wv.add_child(workout_status)
	workout_button = UI.button("Start workout", Color("FFB020"), 17)
	workout_button.custom_minimum_size = Vector2(0, 50)
	workout_button.pressed.connect(func() -> void: workout_requested.emit())
	wv.add_child(workout_button)

	# --- Free Play ---
	v.add_child(UI.vspace(2))
	var fp := UI.label("Free Play", 20, UI.TEXT)
	fp.autowrap_mode = TextServer.AUTOWRAP_OFF
	v.add_child(fp)
	for gid in GameInfo.free_play_order():
		v.add_child(_game_row(str(gid)))

	v.add_child(UI.vspace(2))
	var prog_btn := UI.ghost_button("My Progress  →", 17)
	prog_btn.custom_minimum_size = Vector2(0, 52)
	prog_btn.pressed.connect(func() -> void: progress_requested.emit())
	v.add_child(prog_btn)
	var footer := UI.label("Fully offline · No sign-up · Your progress stays on this device", 13, UI.MUTED)
	footer.autowrap_mode = TextServer.AUTOWRAP_OFF
	v.add_child(footer)

func _game_row(game_id: String) -> PanelContainer:
	var info := GameInfo.get_game(game_id)
	var row := UI.card()
	row.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	row.size_flags_vertical = Control.SIZE_FILL
	game_rows[game_id] = row
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	row.add_child(h)
	var dot := UI.dot(info["accent"], 14)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(dot)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 2)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(tv)
	var name_label := UI.label(str(info["name"]), 18, UI.TEXT)
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	tv.add_child(name_label)
	var sub := UI.label("", 13, UI.MUTED)
	sub.autowrap_mode = TextServer.AUTOWRAP_OFF
	tv.add_child(sub)
	best_labels[game_id] = sub
	if bool(info["playable"]):
		var b := UI.button("Play", info["accent"], 16)
		b.custom_minimum_size = Vector2(84, 46)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.pressed.connect(func() -> void: play_requested.emit(game_id))
		h.add_child(b)
	else:
		h.add_child(_soon_chip(game_id))
	return row

func _soon_chip(game_id: String) -> PanelContainer:
	var chip := PanelContainer.new()
	var sb := UI.style(UI.CARD_LIGHT, 16)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 5
	sb.content_margin_bottom = 5
	chip.add_theme_stylebox_override("panel", sb)
	chip.custom_minimum_size = Vector2(116, 36)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.size_flags_horizontal = Control.SIZE_SHRINK_END
	var l := UI.label("Coming soon", 12, Color("FFB020"))
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chip.add_child(l)
	soon_chips[game_id] = chip
	return chip

func _fmt_time(sec: int) -> String:
	return "%d:%02d" % [sec / 60, sec % 60]

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
		if str(gid) == "tube_sort":
			var spb := Save.get_sort_pb("tube_sort")
			if spb.is_empty():
				sub.text = str(info["tag"]) + "   ·   No best yet"
			else:
				sub.text = str(info["tag"]) + "   ·   Best: %d moves · %s" % [int(spb["moves"]), _fmt_time(int(spb["seconds"]))]
		elif bool(info["playable"]):
			var pb := Save.get_pb(str(gid))
			sub.text = str(info["tag"]) + ("   ·   Best: %d" % pb if pb > 0 else "   ·   No best yet")
		else:
			sub.text = str(info["tag"]) + "   ·   Phase 2"
