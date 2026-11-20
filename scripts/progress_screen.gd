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
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	mc.add_child(v)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	v.add_child(top)
	var back := UI.ghost_button("←  Back", 16)
	back.custom_minimum_size = Vector2(96, 46)
	back.pressed.connect(func() -> void: back_requested.emit())
	top.add_child(back)
	top.add_child(UI.label("My Progress", 24, UI.TEXT))

	# --- Streak card ---
	var scard := UI.card()
	v.add_child(scard)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 6)
	scard.add_child(sv)
	streak_label = UI.label("0 day streak", 26, Color("FFB020"))
	sv.add_child(streak_label)
	total_label = UI.label("Total workouts: 0", 15, UI.MUTED)
	sv.add_child(total_label)
	sv.add_child(UI.vspace(4))
	sv.add_child(UI.label("Last 7 days", 14, UI.MUTED))
	week_box = HBoxContainer.new()
	week_box.add_theme_constant_override("separation", 8)
	sv.add_child(week_box)

	# --- Personal bests ---
	v.add_child(UI.label("Personal bests", 20, UI.TEXT))
	best_box = VBoxContainer.new()
	best_box.add_theme_constant_override("separation", 10)
	v.add_child(best_box)
	for gid in GameInfo.free_play_order():
		best_box.add_child(_best_row(str(gid)))

	v.add_child(UI.label("Progress is saved on this device only.", 13, UI.MUTED))

func _best_row(game_id: String) -> PanelContainer:
	var info := GameInfo.get_game(game_id)
	var row := UI.card()
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	row.add_child(h)
	h.add_child(UI.dot(info["accent"], 14))
	h.add_child(UI.label(str(info["name"]), 17, UI.TEXT))
	h.add_child(UI.hspacer())
	var val := UI.label("—", 17, UI.TEXT)
	val.name = "best_" + game_id
	h.add_child(val)
	return row

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
		if bool(info["playable"]):
			var pb := Save.get_pb(str(gid))
			val.text = "%d" % pb if pb > 0 else "—"
		else:
			val.text = "Soon"
