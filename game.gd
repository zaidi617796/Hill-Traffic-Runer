extends Node3D
## Hill Traffic Runner — v0.1 test build.
## Endless 3-lane traffic dodging on a hill road. Everything is built
## procedurally (no imported assets) so the project stays tiny.

const LANE_X := [-3.2, 0.0, 3.2]
const SEG_LEN := 10.0
const SEG_COUNT := 26
const SPAWN_AHEAD := 235.0
const START_SPEED := 17.0
const MAX_SPEED := 46.0
const ACCEL := 0.32

var state := 0 # 0 = ready, 1 = playing, 2 = crashed
var distance := 0.0
var speed := 0.0
var bonus := 0
var best := 0
var player_lane := 1
var player_x := 0.0
var crash_timer := 0.0
var next_wave_at := 120.0
var floater_timer := 0.0
var touch_start_x := -1.0
var elapsed := 0.0

var segments: Array = []
var traffic: Array = []
var clouds: Array = []
var player: Node3D
var camera: Camera3D
var score_label: Label
var speed_label: Label
var center_label: Label
var floater_label: Label

var _mat_cache := {}
var _light_mat: StandardMaterial3D
var _tail_mat: StandardMaterial3D

func mat(color: Color) -> StandardMaterial3D:
	if _mat_cache.has(color):
		return _mat_cache[color]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.92
	_mat_cache[color] = m
	return m

func hill_h(z: float) -> float:
	return 6.0 * sin(z * 0.008) + 3.0 * sin(z * 0.021 + 1.7) + 1.5 * sin(z * 0.045 + 0.4)

func slope_angle(z: float) -> float:
	var d := 2.0
	return atan2(hill_h(z + d) - hill_h(z - d), 2.0 * d)

func box(parent: Node3D, size: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = material
	mi.position = pos
	parent.add_child(mi)
	return mi

func wheel(parent: Node3D, pos: Vector3, material: Material) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.42
	cm.bottom_radius = 0.42
	cm.height = 0.3
	cm.radial_segments = 12
	mi.mesh = cm
	mi.material_override = material
	mi.position = pos
	mi.rotation.z = PI / 2.0
	parent.add_child(mi)

func build_car(body_color: Color, is_truck: bool) -> Node3D:
	var car := Node3D.new()
	var dark := mat(Color(0.07, 0.07, 0.09))
	var glass := mat(Color(0.1, 0.17, 0.26))
	var body := mat(body_color)
	if is_truck:
		box(car, Vector3(2.05, 1.0, 1.8), Vector3(0, 0.98, -1.6), body)
		box(car, Vector3(1.7, 0.5, 0.7), Vector3(0, 1.3, -1.75), glass)
		var cargo_colors := [Color(0.0, 0.58, 0.58), Color(0.95, 0.45, 0.05), Color(0.85, 0.2, 0.45), Color(0.1, 0.55, 0.25)]
		box(car, Vector3(2.25, 1.9, 3.2), Vector3(0, 1.5, 0.7), mat(cargo_colors[randi() % cargo_colors.size()]))
		box(car, Vector3(2.3, 0.3, 3.25), Vector3(0, 0.6, 0.7), mat(Color(0.98, 0.8, 0.1)))
		wheel(car, Vector3(-1.0, 0.42, -1.55), dark)
		wheel(car, Vector3(1.0, 0.42, -1.55), dark)
		wheel(car, Vector3(-1.0, 0.42, 1.5), dark)
		wheel(car, Vector3(1.0, 0.42, 1.5), dark)
	else:
		box(car, Vector3(1.8, 0.52, 3.6), Vector3(0, 0.56, 0), body)
		box(car, Vector3(1.58, 0.5, 1.75), Vector3(0, 1.02, 0.3), glass)
		box(car, Vector3(0.34, 0.14, 0.06), Vector3(-0.6, 0.62, -1.82), _light_mat)
		box(car, Vector3(0.34, 0.14, 0.06), Vector3(0.6, 0.62, -1.82), _light_mat)
		wheel(car, Vector3(-0.88, 0.42, -1.25), dark)
		wheel(car, Vector3(0.88, 0.42, -1.25), dark)
		wheel(car, Vector3(-0.88, 0.42, 1.25), dark)
		wheel(car, Vector3(0.88, 0.42, 1.25), dark)
	box(car, Vector3(0.34, 0.12, 0.06), Vector3(-0.62, 0.66, 1.82), _tail_mat)
	box(car, Vector3(0.34, 0.12, 0.06), Vector3(0.62, 0.66, 1.82), _tail_mat)
	return car

func build_tree() -> Node3D:
	var tree := Node3D.new()
	var trunk := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.14
	cm.bottom_radius = 0.2
	cm.height = 1.4
	cm.radial_segments = 8
	trunk.mesh = cm
	trunk.material_override = mat(Color(0.35, 0.22, 0.1))
	trunk.position = Vector3(0, 0.7, 0)
	tree.add_child(trunk)
	var top := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.05
	sm.height = 2.1
	sm.radial_segments = 10
	sm.rings = 5
	top.mesh = sm
	top.material_override = mat(Color(0.1, 0.38, 0.13))
	top.position = Vector3(0, 2.3, 0)
	tree.add_child(top)
	return tree

func build_segment() -> Dictionary:
	var seg := Node3D.new()
	add_child(seg)
	box(seg, Vector3(180, 0.4, SEG_LEN + 1.4), Vector3(0, -0.46, 0), mat(Color(0.23, 0.47, 0.2)))
	box(seg, Vector3(11, 0.3, SEG_LEN + 0.1), Vector3(0, 0, 0), mat(Color(0.16, 0.16, 0.18)))
	box(seg, Vector3(0.25, 0.33, SEG_LEN), Vector3(-5.1, 0.02, 0), mat(Color(0.92, 0.92, 0.92)))
	box(seg, Vector3(0.25, 0.33, SEG_LEN), Vector3(5.1, 0.02, 0), mat(Color(0.92, 0.92, 0.92)))
	for bx in [-1.6, 1.6]:
		for dz in [-2.5, 2.5]:
			box(seg, Vector3(0.18, 0.33, 2.2), Vector3(bx, 0.02, dz), mat(Color(0.95, 0.8, 0.15)))
	var hills: Array = []
	for i in 5:
		var hill := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 1.0
		sm.height = 2.0
		sm.radial_segments = 12
		sm.rings = 6
		hill.mesh = sm
		hill.material_override = mat(Color(0.17, 0.43, 0.18))
		seg.add_child(hill)
		hills.append(hill)
	var trees: Array = []
	for i in 3:
		var t := build_tree()
		seg.add_child(t)
		trees.append(t)
	return {"node": seg, "world_z": 0.0, "hills": hills, "trees": trees}

func scatter_scenery(seg: Dictionary) -> void:
	for hill in seg.hills:
		var side := -1.0 if randf() < 0.5 else 1.0
		var x := side * randf_range(13.0, 60.0)
		hill.position = Vector3(x, -2.2 - absf(x) * 0.05, randf_range(-SEG_LEN / 2.0, SEG_LEN / 2.0))
		var s := randf_range(5.0, 12.0) * (1.0 + absf(x) / 28.0)
		hill.scale = Vector3(s, s * randf_range(0.45, 0.7), s)
	for tree in seg.trees:
		var side := -1.0 if randf() < 0.5 else 1.0
		tree.position = Vector3(side * randf_range(7.6, 12.5), 0.1, randf_range(-SEG_LEN / 2.0, SEG_LEN / 2.0))
		var ts := randf_range(0.85, 1.5)
		tree.scale = Vector3(ts, ts, ts)

func place_segment(seg: Dictionary) -> void:
	var node: Node3D = seg.node
	node.position = Vector3(0, hill_h(seg.world_z), -(seg.world_z - distance))
	node.rotation.x = slope_angle(seg.world_z)

func make_label(font_size: int, top: float, bottom: float) -> Label:
	var l := Label.new()
	l.anchor_left = 0.0
	l.anchor_right = 1.0
	l.anchor_top = top
	l.anchor_bottom = bottom
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	return l

func _ready() -> void:
	randomize()
	_light_mat = StandardMaterial3D.new()
	_light_mat.albedo_color = Color(1, 0.95, 0.7)
	_light_mat.emission_enabled = true
	_light_mat.emission = Color(1, 0.92, 0.6)
	_tail_mat = StandardMaterial3D.new()
	_tail_mat.albedo_color = Color(0.9, 0.1, 0.1)
	_tail_mat.emission_enabled = true
	_tail_mat.emission = Color(0.9, 0.08, 0.08)

	# Sky, fog, light
	var we := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.22, 0.42, 0.78)
	sky_mat.sky_horizon_color = Color(0.98, 0.78, 0.55)
	sky_mat.ground_bottom_color = Color(0.12, 0.25, 0.1)
	sky_mat.ground_horizon_color = Color(0.85, 0.68, 0.48)
	sky_mat.sun_angle_max = 25.0
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_BG
	env.fog_enabled = true
	env.fog_light_color = Color(0.85, 0.78, 0.68)
	env.fog_density = 0.011
	env.fog_depth_begin = 70.0
	env.fog_depth_end = 215.0
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1, 0.9, 0.74)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-42, -28, 0)
	add_child(sun)

	camera = Camera3D.new()
	camera.fov = 68.0
	camera.far = 420.0
	add_child(camera)
	camera.position = Vector3(0, 7, 11)

	# Distant mountains (follow the player loosely)
	for i in 6:
		var cone := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = 1.0
		cm.height = 2.0
		cm.radial_segments = 7
		cone.mesh = cm
		cone.material_override = mat(Color(0.3, 0.45, 0.5))
		var side := -1.0 if i % 2 == 0 else 1.0
		cone.position = Vector3(side * randf_range(60.0, 110.0), 0, -randf_range(140.0, 230.0))
		var s := randf_range(28.0, 52.0)
		cone.scale = Vector3(s, s * 0.62, s)
		cone.set_meta("follow", true)
		add_child(cone)
		clouds.append(cone) # reused list: backdrop items follow player height

	# Clouds
	for i in 9:
		var cloud := Node3D.new()
		for j in 3:
			var puff := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 1.0
			sm.height = 2.0
			sm.radial_segments = 10
			sm.rings = 5
			puff.mesh = sm
			var cm2 := StandardMaterial3D.new()
			cm2.albedo_color = Color(1, 1, 1, 0.92)
			cm2.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			puff.material_override = cm2
			puff.position = Vector3(j * 2.6 - 2.6, randf_range(-0.3, 0.3), randf_range(-0.5, 0.5))
			puff.scale = Vector3(randf_range(2.2, 3.6), randf_range(0.8, 1.1), randf_range(1.4, 2.0))
			cloud.add_child(puff)
		cloud.position = Vector3(randf_range(-90.0, 90.0), randf_range(26.0, 44.0), -randf_range(60.0, 220.0))
		cloud.set_meta("cloud", true)
		add_child(cloud)
		clouds.append(cloud)

	# Road segments
	for i in SEG_COUNT:
		var seg := build_segment()
		seg.world_z = i * SEG_LEN - 10.0
		scatter_scenery(seg)
		segments.append(seg)
		place_segment(seg)

	# Player car
	player = build_car(Color(0.85, 0.12, 0.12), false)
	add_child(player)
	player.position = Vector3(0, hill_h(0.0) + 0.15, 0)

	# HUD
	var layer := CanvasLayer.new()
	add_child(layer)
	score_label = make_label(46, 0.02, 0.1)
	layer.add_child(score_label)
	speed_label = make_label(30, 0.9, 0.98)
	speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	speed_label.offset_right = -24
	layer.add_child(speed_label)
	floater_label = make_label(34, 0.3, 0.38)
	floater_label.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
	layer.add_child(floater_label)
	center_label = make_label(52, 0.36, 0.62)
	layer.add_child(center_label)
	center_label.text = "HILL TRAFFIC RUNNER\n\nTap to start"

	var cfg := ConfigFile.new()
	if cfg.load("user://hilltraffic.cfg") == OK:
		best = int(cfg.get_value("scores", "best", 0))
	score_label.text = "0"

func save_best() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("scores", "best", best)
	cfg.save("user://hilltraffic.cfg")

func start_game() -> void:
	state = 1
	speed = START_SPEED
	center_label.text = ""

func reset_game() -> void:
	for t in traffic:
		t.node.queue_free()
	traffic.clear()
	distance = 0.0
	bonus = 0
	player_lane = 1
	player_x = 0.0
	next_wave_at = 120.0
	for i in SEG_COUNT:
		segments[i].world_z = i * SEG_LEN - 10.0
		scatter_scenery(segments[i])
	start_game()

func crash() -> void:
	state = 2
	crash_timer = 0.0
	var total := int(distance) + bonus
	if total > best:
		best = total
		save_best()
	center_label.text = "CRASHED!\nScore: %d\nBest: %d\n\nTap to restart" % [total, best]

func change_lane(dir: int) -> void:
	if state != 1:
		return
	player_lane = clampi(player_lane + dir, 0, 2)

func show_floater(text: String) -> void:
	floater_label.text = text
	floater_timer = 1.2

func handle_tap(x: float) -> void:
	var half := get_viewport().get_visible_rect().size.x / 2.0
	if state == 0:
		start_game()
	elif state == 2:
		if crash_timer > 0.8:
			reset_game()
	elif state == 1:
		change_lane(-1 if x < half else 1)

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			touch_start_x = event.position.x
		else:
			if touch_start_x >= 0.0:
				var dx: float = event.position.x - touch_start_x
				if dx > 45.0:
					change_lane(1)
				elif dx < -45.0:
					change_lane(-1)
				else:
					handle_tap(event.position.x)
				touch_start_x = -1.0
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		handle_tap(event.position.x)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_LEFT or event.keycode == KEY_A:
			change_lane(-1)
		elif event.keycode == KEY_RIGHT or event.keycode == KEY_D:
			change_lane(1)
		elif event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			handle_tap(get_viewport().get_visible_rect().size.x / 2.0)

func spawn_wave() -> void:
	var lanes := [0, 1, 2]
	lanes.shuffle()
	var block_count := 1
	if speed > 24.0 and randf() < 0.6:
		block_count = 2
	if speed > 36.0 and randf() < 0.3:
		block_count = 2
	var palette := [Color(0.92, 0.92, 0.94), Color(0.75, 0.77, 0.8), Color(0.15, 0.35, 0.85), Color(0.98, 0.75, 0.1), Color(0.1, 0.6, 0.35)]
	for k in block_count:
		var is_truck := randf() < 0.3
		var car := build_car(palette[randi() % palette.size()], is_truck)
		add_child(car)
		traffic.append({
			"node": car,
			"world_z": distance + SPAWN_AHEAD + randf_range(-3.0, 3.0),
			"lane": lanes[k],
			"speed": randf_range(7.0, 10.0) if is_truck else randf_range(8.0, 13.5),
			"passed": false,
		})

func _process(delta: float) -> void:
	elapsed += delta
	if state == 1:
		speed = minf(speed + ACCEL * delta, MAX_SPEED)
		distance += speed * delta
		if distance >= next_wave_at:
			spawn_wave()
			next_wave_at = distance + clampf(randf_range(30.0, 48.0) * (30.0 / speed), 22.0, 50.0)
	elif state == 2:
		crash_timer += delta
		speed = move_toward(speed, 0.0, delta * 30.0)
		distance += speed * delta

	# Player placement
	player_x = move_toward(player_x, LANE_X[player_lane], delta * 13.0)
	player.position = Vector3(player_x, hill_h(distance) + 0.15, 0)
	player.rotation.x = slope_angle(distance)
	player.rotation.z = (LANE_X[player_lane] - player_x) * 0.045

	# Camera
	var cam_target := Vector3(player_x * 0.55, hill_h(distance) + 6.9, 10.8)
	camera.position = camera.position.lerp(cam_target, minf(delta * 6.0, 1.0))
	camera.look_at(Vector3(player_x * 0.7, hill_h(distance) + 1.1, -12.0), Vector3.UP)

	# Segments
	for seg in segments:
		if seg.world_z + SEG_LEN / 2.0 < distance - 25.0:
			seg.world_z += SEG_COUNT * SEG_LEN
			scatter_scenery(seg)
		place_segment(seg)

	# Traffic
	for i in range(traffic.size() - 1, -1, -1):
		var t: Dictionary = traffic[i]
		t.world_z += t.speed * delta
		if t.world_z < distance - 18.0:
			t.node.queue_free()
			traffic.remove_at(i)
			continue
		t.node.position = Vector3(LANE_X[t.lane], hill_h(t.world_z) + 0.15, -(t.world_z - distance))
		t.node.rotation.x = slope_angle(t.world_z)
		if state == 1:
			if not t.passed and t.world_z < distance + 0.5:
				t.passed = true
				if absf(player_x - LANE_X[t.lane]) > 1.35 and absf(player_x - LANE_X[t.lane]) < 3.6:
					bonus += 25
					show_floater("Near miss +25")
			if absf(t.world_z - distance) < 2.3 and absf(player_x - LANE_X[t.lane]) < 1.35:
				crash()

	# Backdrop + clouds follow
	for item in clouds:
		if item.has_meta("cloud"):
			item.position.y = hill_h(distance) + 30.0 + sin(elapsed * 0.05 + item.position.x) * 2.0
			item.position.x += delta * 0.7
			if item.position.x > 120.0:
				item.position.x = -120.0
		else:
			item.position.y = hill_h(distance) + 2.0

	# HUD
	if floater_timer > 0.0:
		floater_timer -= delta
		floater_label.modulate.a = clampf(floater_timer / 1.2, 0.0, 1.0)
		if floater_timer <= 0.0:
			floater_label.text = ""
	score_label.text = str(int(distance) + bonus)
	speed_label.text = "%d km/h" % int(speed * 3.6)
