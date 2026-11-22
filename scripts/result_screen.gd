extends Control
## Result — total score count-up, har game ke stars, New Best chip.

signal home_requested

const UI := preload("res://scripts/ui_factory.gd")
const StarsRow := preload("res://scripts/stars_row.gd")

var title_label: Label
var total_label: Label
var entries_box: VBoxContainer
var count_tween: Tween = null

func _ready() -> void:
	var mc := UI.margins(self, 20)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	mc.add_child(v)

	title_label = UI.label("Result", 28, UI.TEXT)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title_label)

	total_label = UI.label("0", 56, Color("FFB020"))
	total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(total_label)
	var pts := UI.label("points", 14, UI.MUTED)
	pts.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(pts)

	entries_box = VBoxContainer.new()
	entries_box.add_theme_constant_override("separation", 10)
	v.add_child(entries_box)

	v.add_child(UI.vspace(6))
	var home_btn := UI.button("Back to Home", Color("FFB020"), 18)
	home_btn.custom_minimum_size = Vector2(0, 54)
	home_btn.pressed.connect(func() -> void: home_requested.emit())
	v.add_child(home_btn)
	v.add_child(UI.label("Beat your own best — that's the only race here.", 13, UI.MUTED))

func show_results(title_text: String, entries: Array) -> void:
	title_label.text = title_text
	for c in entries_box.get_children():
		c.queue_free()
	var total := 0
	for e in entries:
		total += int(e["score"])
		entries_box.add_child(_entry_row(e))
	if count_tween != null and count_tween.is_valid():
		count_tween.kill()
	total_label.text = "0"
	count_tween = create_tween()
	count_tween.tween_method(_set_total_text, 0, total, 0.9)

func _set_total_text(v: int) -> void:
	total_label.text = "%d" % v

func _entry_row(e: Dictionary) -> PanelContainer:
	var row := UI.card()
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	row.add_child(h)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 2)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(tv)
	var ename := UI.label(str(e["name"]), 18, UI.TEXT)
	ename.autowrap_mode = TextServer.AUTOWRAP_OFF
	tv.add_child(ename)
	var epts := UI.label("%d points" % int(e["score"]), 13, UI.MUTED)
	epts.autowrap_mode = TextServer.AUTOWRAP_OFF
	tv.add_child(epts)
	var stars := StarsRow.new()
	stars.set_stars(int(e["stars"]))
	h.add_child(stars)
	if bool(e["new_best"]):
		var chip := UI.label("New best!", 13, Color("2DD4BF"))
		chip.autowrap_mode = TextServer.AUTOWRAP_OFF
		chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(chip)
	return row
