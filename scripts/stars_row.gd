extends Control
## Code-drawn stars — font glyphs par depend nahi karta.

var stars: int = 0
var max_stars: int = 3
var star_size: float = 30.0
var filled_color: Color = Color("FFB020")
var empty_color: Color = Color("3A405A")

func _ready() -> void:
	custom_minimum_size = Vector2(star_size * max_stars + 8.0 * (max_stars - 1), star_size)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_stars(n: int) -> void:
	stars = clampi(n, 0, max_stars)
	queue_redraw()

func _draw() -> void:
	for i in max_stars:
		var cx := i * (star_size + 8.0) + star_size / 2.0
		var cy := star_size / 2.0
		var pts := PackedVector2Array()
		for k in 10:
			var ang := -PI / 2.0 + k * PI / 5.0
			var r := star_size / 2.0 if k % 2 == 0 else star_size / 5.0
			pts.append(Vector2(cx + cos(ang) * r, cy + sin(ang) * r))
		draw_colored_polygon(pts, filled_color if i < stars else empty_color)
