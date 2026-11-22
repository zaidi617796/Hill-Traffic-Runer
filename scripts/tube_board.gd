extends Control
## Tube Sort board — saari tubes ek hi Control me code-drawn hain
## (ProgressRing / StarsRow wali idiom, koi external asset nahi).
## Tap handling bhi yahin hoti hai: tube_tapped(index) signal.

signal tube_tapped(index)

const CAP := 4
const LIFT := 14.0
const GLASS := Color(1, 1, 1, 0.30)
const GLASS_SOFT := Color(1, 1, 1, 0.13)
const SELECTED_RING := Color("FFB020")

var tubes: Array = [] # Array of Array[int] — colour indices, bottom -> top
var colors: Array = [] # Array[Color]
var selected: int = -1
var tube_rects: Array = [] # Array[Rect2] — base positions (lift ke baghair)
var unit_styles: Array = [] # Array[StyleBoxFlat] per colour

func setup(p_tubes: Array, p_colors: Array) -> void:
	tubes = p_tubes
	colors = p_colors
	selected = -1
	unit_styles.clear()
	for c in colors:
		var sb := StyleBoxFlat.new()
		sb.bg_color = c
		sb.corner_radius_top_left = 7
		sb.corner_radius_top_right = 7
		sb.corner_radius_bottom_left = 7
		sb.corner_radius_bottom_right = 7
		unit_styles.append(sb)
	_layout()
	queue_redraw()

func refresh() -> void:
	_layout()
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()
		queue_redraw()

func _layout() -> void:
	tube_rects.clear()
	var n := tubes.size()
	if n == 0 or size.x <= 0.0 or size.y <= 0.0:
		return
	var cols := (n + 1) / 2
	var rows := 2
	var cell_w := size.x / float(cols)
	var cell_h := size.y / float(rows)
	var tube_w := minf(cell_w * 0.54, 100.0)
	var tube_h := minf(cell_h * 0.80, 250.0)
	for i in n:
		var col := i % cols
		var row := i / cols
		var x := col * cell_w + (cell_w - tube_w) / 2.0
		var y := row * cell_h + (cell_h - tube_h) / 2.0 + LIFT * 0.5
		tube_rects.append(Rect2(x, y, tube_w, tube_h))

func _unit_h(r: Rect2) -> float:
	return (r.size.y - 30.0) / float(CAP)

func _unit_rect(r: Rect2, j: int) -> Rect2:
	var uh := _unit_h(r)
	var inset := 5.0
	var gap := 2.0
	var bottom := r.position.y + r.size.y - 7.0
	var y := bottom - float(j + 1) * uh + gap * 0.5
	return Rect2(r.position.x + inset, y, r.size.x - inset * 2.0, uh - gap)

func _draw() -> void:
	if tube_rects.size() != tubes.size():
		_layout()
	for i in tubes.size():
		var r: Rect2 = tube_rects[i]
		var is_sel := i == selected
		if is_sel:
			r.position.y -= LIFT
		var stack: Array = tubes[i]
		# Rang wali units (neeche se upar)
		for j in stack.size():
			draw_style_box(unit_styles[int(stack[j])], _unit_rect(r, j))
		# Selected tube ki sab se upar wali unit munh se upar uthi hui
		if is_sel and not stack.is_empty():
			var top_rect := _unit_rect(r, stack.size() - 1)
			top_rect.position.y = r.position.y - top_rect.size.y - 5.0
			draw_style_box(unit_styles[int(stack.back())], top_rect)
		# Glass tube — transparent andar, sirf kinara; neeche gol
		var glass := StyleBoxFlat.new()
		glass.bg_color = Color(1, 1, 1, 0.04)
		glass.border_color = SELECTED_RING if is_sel else GLASS
		glass.set_border_width_all(3 if is_sel else 2)
		glass.corner_radius_top_left = 8
		glass.corner_radius_top_right = 8
		glass.corner_radius_bottom_left = int(r.size.x * 0.32)
		glass.corner_radius_bottom_right = int(r.size.x * 0.32)
		draw_style_box(glass, r)
		# Munh ki chamak wali patti
		var rim := Rect2(r.position.x - 3.0, r.position.y - 2.0, r.size.x + 6.0, 5.0)
		var rim_sb := StyleBoxFlat.new()
		rim_sb.bg_color = SELECTED_RING if is_sel else GLASS
		rim_sb.corner_radius_top_left = 3
		rim_sb.corner_radius_top_right = 3
		rim_sb.corner_radius_bottom_left = 3
		rim_sb.corner_radius_bottom_right = 3
		draw_style_box(rim_sb, rim)
		# Halki si side shine
		var shine := Rect2(r.position.x + 7.0, r.position.y + 12.0, 4.0, r.size.y - 34.0)
		var shine_sb := StyleBoxFlat.new()
		shine_sb.bg_color = GLASS_SOFT
		shine_sb.corner_radius_top_left = 2
		shine_sb.corner_radius_top_right = 2
		shine_sb.corner_radius_bottom_left = 2
		shine_sb.corner_radius_bottom_right = 2
		draw_style_box(shine_sb, shine)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			for i in tube_rects.size():
				var r: Rect2 = tube_rects[i]
				var hit := r.grow_individual(6.0, LIFT + _unit_h(r) + 8.0, 6.0, 6.0)
				if hit.has_point(mb.position):
					tube_tapped.emit(i)
					accept_event()
					return
