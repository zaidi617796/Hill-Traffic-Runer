extends Control
## Circular progress ring — Today's Workout card ke liye.

var fraction: float = 0.0
var ring_color: Color = Color("FFB020")
var track_color: Color = Color("2C3247")

func _ready() -> void:
	custom_minimum_size = Vector2(84, 84)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_fraction(f: float) -> void:
	fraction = clampf(f, 0.0, 1.0)
	queue_redraw()

func _draw() -> void:
	var center := size / 2.0
	var radius := minf(size.x, size.y) / 2.0 - 6.0
	draw_arc(center, radius, 0, TAU, 64, track_color, 9.0, true)
	if fraction > 0.0:
		draw_arc(center, radius, -PI / 2.0, -PI / 2.0 + TAU * fraction, 64, ring_color, 9.0, true)
