extends Control
## My Progress — streak SIRF yahan rehta hai (design law).
## Personal bests, total workouts, pichle 7 din ki halat.

signal back_requested

const UI := preload("res://scripts/ui_factory.gd")
const GameInfo := preload("res://scripts/game_info.gd")

var streak_label: Label
var total_label: Label
var week_box: HBoxContainer
var best_box: VBoxContainer

func _ready() -> void:
	var mc := UI.margins(self, 20)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	mc.add_child(scroll)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(v)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	v.add_child(top)
	var back := UI.ghost_button("←  Back", 16)
	back.custom_minimum_size = Vector2(96, 46)
	back.pressed.connect(func() -> void: back_requested.emit())
	top.add_child(back)
	top.add_child(UI.label1("My Progress", 24, UI.TEXT))

	# --- Streak card ---
	var scard := UI.card()
	v.add_child(scard)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 6)
	scard.add_child(sv)
	streak_label = UI.label("0 day streak", 26, Color("FFB020"))
	streak_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	sv.add_child(streak_label)
	total_label = UI.label("Total workouts: 0", 15, UI.MUTED)
	total_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	sv.add_child(total_label)
	sv.add_child(UI.vspace(4))
	var last7 := UI.label("Last 7 days", 14, UI.MUTED)
	last7.autowrap_mode = TextServer.AUTOWRAP_OFF
	sv.add_child(last7)
	week_box = HBoxContainer.new()
	week_box.add_theme_constant_override("separation", 8)
	sv.add_child(week_box)

	# --- Personal bests ---
	var pb_title := UI.label("Personal bests", 20, UI.TEXT)
	pb_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	v.add_child(pb_title)
	best_box = VBoxContainer.new()
	best_box.add_theme_constant_override("separation", 10)
	v.add_child(best_box)
	for gid in GameInfo.free_play_order():
		best_box.add_child(_best_row(str(gid)))

	var pfooter := UI.label("Progress is saved on this device only.", 13, UI.MUTED)
	pfooter.autowrap_mode = TextServer.AUTOWRAP_OFF
	v.add_child(pfooter)

func _best_row(game_id: String) -> PanelContainer:
	var info := GameInfo.get_game(game_id)
	var row := UI.card()
	row.custom_minimum_size = Vector2(0, 56)
	row.size_flags_vertical = Control.SIZE_FILL
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	row.add_child(h)
	var dot := UI.dot(info["accent"], 14)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(dot)
	var name_label := UI.label(str(info["name"]), 17, UI.TEXT)
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(name_label)
	h.add_child(UI.hspacer())
	var val := UI.label("—", 17, UI.TEXT)
	val.autowrap_mode = TextServer.AUTOWRAP_OFF
	val.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	val.name = "best_" + game_id
	h.add_child(val)
	return row

func _fmt_time(sec: int) -> String:
	return "%d:%02d" % [sec / 60, sec % 60]

func refresh() -> void:
	var st: Dictionary = Save.data["streak"]
	var count := int(st["count"])
	streak_label.text = "%d day streak" % count if count != 1 else "1 day streak"
	total_label.text = "Total workouts: %d" % int(st["total"])
	# Last 7 days dots
	for c in week_box.get_children():
		c.queue_free()
	var today := Save.day_number()
	var hist: Array = st["history"]
	for i in range(6, -1, -1):
		var day := today - i
		var col := Color("FFB020") if hist.has(day) else UI.CARD_LIGHT
		week_box.add_child(UI.dot(col, 22))
	# Personal bests
	for gid in GameInfo.free_play_order():
		var info := GameInfo.get_game(str(gid))
		var val := best_box.find_child("best_" + str(gid), true, false) as Label
		if val == null:
			continue
		if str(gid) == "tube_sort":
			var spb := Save.get_sort_pb("tube_sort")
			if spb.is_empty():
				val.text = "—"
			else:
				val.text = "%d moves · %s" % [int(spb["moves"]), _fmt_time(int(spb["seconds"]))]
		elif bool(info["playable"]):
			var pb := Save.get_pb(str(gid))
			val.text = "%d" % pb if pb > 0 else "—"
		else:
			val.text = "Soon"
