extends Node3D

enum GameState { READY, PLAYING, GAME_OVER }

const GAP_SIZE: float = 3.8
const GAP_MIN_Y: float = 3.5
const GAP_MAX_Y: float = 11.5
const PIPE_SPAWN_X: float = 45.0
const PIPE_SPACING: float = 6.5

var current_speed: float = 3.5
var base_gravity: float = 24.0

var state: int = GameState.READY
var score: int = 0
var best_score: int = 0

var bird: CharacterBody3D = null
var pipe_container: Node3D = null
var spawn_timer: Timer = null
var sound: Node = null

var score_label: Label = null
var message_label: Label = null
var game_over_container: VBoxContainer = null

var score_panel: PanelContainer = null
var message_panel: PanelContainer = null
var game_over_panel: PanelContainer = null

var btn_mute: Button = null
var btn_pause: Button = null
var is_muted: bool = false
var is_mobile_portrait: bool = false
var rotate_panel: PanelContainer = null

var _restart_cooldown: bool = false

# Parallax background tracking: [{node, speed, wrap_width}]
var _bg_elements: Array = []
const BG_BASE_SPEED: float = 5.5
const BG_LEFT_LIMIT: float = -120.0
const BG_WRAP_WIDTH: float = 240.0


func _ready() -> void:
	# Lắng nghe sự thay đổi kích thước màn hình
	get_tree().root.size_changed.connect(_on_size_changed)

	_setup_sound()
	_setup_environment()
	_setup_camera()
	_setup_lighting()
	_setup_ground()
	_setup_bird()
	_setup_pipes()
	_setup_background()
	_setup_ui()
	
	_check_mobile_orientation()
	_show_ready_screen()


func _on_size_changed() -> void:
	_check_mobile_orientation()


func _check_mobile_orientation() -> void:
	var os_name: String = OS.get_name()
	if os_name == "Android" or os_name == "iOS":
		var screen_size = get_viewport().get_visible_rect().size
		if screen_size.y > screen_size.x: # Màn hình dọc (Portrait)
			is_mobile_portrait = true
			if rotate_panel:
				rotate_panel.visible = true
			if state != GameState.READY: # Dừng game nếu đang chơi
				get_tree().paused = true
		else: # Màn hình ngang (Landscape)
			is_mobile_portrait = false
			if rotate_panel:
				rotate_panel.visible = false
			# Nếu đang sẵn sàng và bị chặn, không tự động unpause game nếu đang chơi (để người dùng nhấn nút Pause lại)
	else:
		is_mobile_portrait = false
		if rotate_panel:
			rotate_panel.visible = false


# ==============================================================
#  SCENE SETUP
# ==============================================================

func _setup_sound() -> void:
	sound = Node.new()
	sound.set_script(preload("res://sound_manager.gd"))
	sound.name = "SoundManager"
	add_child(sound)


func _setup_environment() -> void:
	# Sky with White horizon transitioning to Blue
	var sky_mat: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.15, 0.45, 0.85)    # Vibrant blue sky
	sky_mat.sky_horizon_color = Color(1.0, 1.0, 1.0)   # White at horizon
	sky_mat.ground_bottom_color = Color(0.65, 0.85, 0.15) # Keep banana green ground bottom
	sky_mat.ground_horizon_color = Color(1.0, 1.0, 1.0) # White horizon on ground side too

	var sky: Sky = Sky.new()
	sky.sky_material = sky_mat

	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_color = Color(0.85, 0.90, 1.0)
	env.ambient_light_energy = 0.8

	var world_env: WorldEnvironment = WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)


func _setup_camera() -> void:
	# Landscape 16:9 – camera further back, centered on wider play area
	var cam: Camera3D = Camera3D.new()
	cam.position = Vector3(5, 7, 20)
	cam.fov = 45
	cam.current = true
	add_child(cam)


func _setup_lighting() -> void:
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -20, 0)
	sun.shadow_enabled = true
	sun.light_energy = 1.15
	sun.light_color = Color(1.0, 0.97, 0.93)
	sun.directional_shadow_max_distance = 80.0
	sun.shadow_normal_bias = 2.0
	sun.shadow_bias = 0.1
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	add_child(sun)


func _setup_ground() -> void:
	# Rice-paddy earth
	var ground: StaticBody3D = StaticBody3D.new()
	ground.name = "Ground"
	ground.collision_layer = 4
	ground.collision_mask = 0
	ground.position = Vector3(0, -0.5, 0)

	var g_mesh: MeshInstance3D = MeshInstance3D.new()
	var g_box: BoxMesh = BoxMesh.new()
	g_box.size = Vector3(60, 1, 14)
	var g_mat: StandardMaterial3D = StandardMaterial3D.new()
	g_mat.albedo_color = Color(0.55, 0.42, 0.25)
	g_mat.roughness = 0.95
	g_box.material = g_mat
	g_mesh.mesh = g_box
	ground.add_child(g_mesh)

	var g_col: CollisionShape3D = CollisionShape3D.new()
	var g_shape: BoxShape3D = BoxShape3D.new()
	g_shape.size = Vector3(60, 1, 14)
	g_col.shape = g_shape
	ground.add_child(g_col)
	add_child(ground)

	# Green rice paddy top layer
	var paddy: MeshInstance3D = MeshInstance3D.new()
	var paddy_box: BoxMesh = BoxMesh.new()
	paddy_box.size = Vector3(60, 0.12, 14)
	var paddy_mat: StandardMaterial3D = StandardMaterial3D.new()
	paddy_mat.albedo_color = Color(0.35, 0.60, 0.15)
	paddy_mat.roughness = 0.85
	paddy_box.material = paddy_mat
	paddy.mesh = paddy_box
	paddy.position = Vector3(0, 0.06, 0)
	add_child(paddy)

	# Dirt path strip (đường làng)
	var path: MeshInstance3D = MeshInstance3D.new()
	var path_box: BoxMesh = BoxMesh.new()
	path_box.size = Vector3(60, 0.13, 1.2)
	var path_mat: StandardMaterial3D = StandardMaterial3D.new()
	path_mat.albedo_color = Color(0.70, 0.58, 0.38)
	path_mat.roughness = 0.9
	path_box.material = path_mat
	path.mesh = path_box
	path.position = Vector3(0, 0.065, 2.0)
	add_child(path)

	# Invisible ceiling
	var ceiling: StaticBody3D = StaticBody3D.new()
	ceiling.name = "Ceiling"
	ceiling.collision_layer = 4
	ceiling.collision_mask = 0
	ceiling.position = Vector3(0, 15.5, 0)

	var c_col: CollisionShape3D = CollisionShape3D.new()
	var c_shape: BoxShape3D = BoxShape3D.new()
	c_shape.size = Vector3(60, 1, 14)
	c_col.shape = c_shape
	ceiling.add_child(c_col)
	add_child(ceiling)


func _setup_bird() -> void:
	bird = CharacterBody3D.new()
	bird.set_script(preload("res://bird.gd"))
	bird.position = Vector3(0, 7, 0)
	add_child(bird)
	bird.died.connect(_on_bird_died)


func _setup_pipes() -> void:
	pipe_container = Node3D.new()
	pipe_container.name = "Pipes"
	add_child(pipe_container)

	spawn_timer = Timer.new()
	spawn_timer.wait_time = PIPE_SPACING / current_speed
	spawn_timer.one_shot = false
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	add_child(spawn_timer)


func _setup_background() -> void:
	# Sea removed as it conflicts with the Banana Green landscape
	_create_bg_terrain()
	_create_mountains()
	_create_urban_area()
	_create_flag()

func _create_sea() -> void:
	# No longer used to keep the background purely Banana Green
	pass

func _register_bg(node: Node3D, z_depth: float) -> void:
	# Deeper Z = slower parallax. Speed factor: 0.15 (far) to 0.6 (near)
	var factor: float = clampf(1.0 / (1.0 + absf(z_depth) * 0.25), 0.12, 0.65)
	_bg_elements.append({"node": node, "factor": factor})


func _create_mountains() -> void:
	var mount_mat: StandardMaterial3D = StandardMaterial3D.new()
	mount_mat.albedo_color = Color(0.05, 0.22, 0.05)
	mount_mat.roughness = 1.0

	var positions: Array = [
		Vector3(-105, 0, -35), Vector3(-75, 0, -35), Vector3(-45, 0, -35),
		Vector3(-15, 0, -38), Vector3(15, 0, -36), Vector3(45, 0, -37),
		Vector3(75, 0, -36), Vector3(105, 0, -35)
	]

	for pos: Vector3 in positions:
		var group: Node3D = Node3D.new()
		group.position = pos
		add_child(group)
		_register_bg(group, pos.z)

		var mount: MeshInstance3D = MeshInstance3D.new()
		var p_mesh: PrismMesh = PrismMesh.new()
		p_mesh.size = Vector3(randf_range(15, 25), randf_range(8, 15), 10)
		p_mesh.material = mount_mat
		mount.mesh = p_mesh
		mount.position.y = p_mesh.size.y / 2.0
		group.add_child(mount)

func _create_urban_area() -> void:
	var bldg_mat: StandardMaterial3D = StandardMaterial3D.new()
	bldg_mat.albedo_color = Color(0.4, 0.42, 0.45) # Concrete gray
	bldg_mat.roughness = 0.8

	var win_mat: StandardMaterial3D = StandardMaterial3D.new()
	win_mat.albedo_color = Color(0.9, 0.95, 1.0) # Window light
	win_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var clusters: Array = [
		Vector3(-105, 0, -25), Vector3(-75, 0, -26), Vector3(-45, 0, -25),
		Vector3(-15, 0, -28), Vector3(15, 0, -26), Vector3(45, 0, -25),
		Vector3(75, 0, -28), Vector3(105, 0, -26)
	]

	for cluster_pos: Vector3 in clusters:
		var group: Node3D = Node3D.new()
		group.position = cluster_pos
		add_child(group)
		_register_bg(group, cluster_pos.z)

		var b_count: int = randi_range(2, 4)
		for i: int in range(b_count):
			var b: MeshInstance3D = MeshInstance3D.new()
			var bm: BoxMesh = BoxMesh.new()
			var w: float = randf_range(2.0, 3.5)
			var h: float = randf_range(5.0, 12.0)
			var d: float = randf_range(2.0, 3.5)
			bm.size = Vector3(w, h, d)
			bm.material = bldg_mat
			b.mesh = bm
			b.position = Vector3(i * 4.0 - (b_count * 2.0), h / 2.0, randf_range(-1, 1))
			group.add_child(b)

			# Optimized windows: instead of many small meshes, use a few "stripes"
			# or just a couple of window blocks per side
			var win_count: int = int(h / 3.0)
			for j in range(win_count):
				var win: MeshInstance3D = MeshInstance3D.new()
				var wm: BoxMesh = BoxMesh.new()
				wm.size = Vector3(w + 0.05, 0.6, d + 0.05)
				wm.material = win_mat
				win.mesh = wm
				win.position.y = (j * 3.0) - (h / 2.0) + 2.0
				b.add_child(win)

func _create_bg_terrain() -> void:
	# Banana green background ground – spans Z from -10 to -45
	var grass_group: Node3D = Node3D.new()
	grass_group.position = Vector3(0, -0.6, -25) # Centered
	add_child(grass_group)
	_register_bg(grass_group, -25)
	
	var g_mesh: MeshInstance3D = MeshInstance3D.new()
	var g_box: BoxMesh = BoxMesh.new()
	g_box.size = Vector3(600, 0.1, 40) # Larger ground area to cover expanded parallax
	var g_mat: StandardMaterial3D = StandardMaterial3D.new()
	g_mat.albedo_color = Color(0.65, 0.85, 0.15) # Banana Green (Vibrant yellowish green)
	g_box.material = g_mat
	g_mesh.mesh = g_box
	grass_group.add_child(g_mesh)

	# Multiple parallel asphalt roads
	var road_depths: Array = [-12, -18, -22, -30]
	for z_pos in road_depths:
		var road_group: Node3D = Node3D.new()
		road_group.position = Vector3(0, -0.55, z_pos)
		add_child(road_group)
		_register_bg(road_group, z_pos)
		
		var r_mesh: MeshInstance3D = MeshInstance3D.new()
		var r_box: BoxMesh = BoxMesh.new()
		r_box.size = Vector3(600, 0.05, randf_range(1.5, 3.0))
		var r_mat: StandardMaterial3D = StandardMaterial3D.new()
		r_mat.albedo_color = Color(0.12, 0.12, 0.15) # Dark asphalt
		r_box.material = r_mat
		r_mesh.mesh = r_box
		road_group.add_child(r_mesh)

func _create_flag() -> void:
	var intervals: Array = [-100, -70, -40, -10, 20, 50, 80, 110]
	for x_pos: float in intervals:
		var flag_group: Node3D = Node3D.new()
		flag_group.position = Vector3(x_pos, 0, -8)
		add_child(flag_group)
		_register_bg(flag_group, -8)

		# Flagpole
		var pole: MeshInstance3D = MeshInstance3D.new()
		var pole_mesh: CylinderMesh = CylinderMesh.new()
		pole_mesh.top_radius = 0.1
		pole_mesh.bottom_radius = 0.15
		pole_mesh.height = 10.0
		var pole_mat: StandardMaterial3D = StandardMaterial3D.new()
		pole_mat.albedo_color = Color(0.8, 0.8, 0.8)
		pole_mesh.material = pole_mat
		pole.mesh = pole_mesh
		pole.position.y = 5.0
		flag_group.add_child(pole)

		# The Flag itself
		var flag: MeshInstance3D = MeshInstance3D.new()
		var flag_mesh: QuadMesh = QuadMesh.new()
		flag_mesh.size = Vector2(3.0, 2.0)
		
		var flag_mat: StandardMaterial3D = StandardMaterial3D.new()
		var tex: Texture2D = load("res://assets/Quốc kỳ Việt Nam.png")
		flag_mat.albedo_texture = tex
		flag_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		flag_mesh.material = flag_mat
		
		flag.mesh = flag_mesh
		flag.position = Vector3(1.6, 8.5, 0)
		flag_group.add_child(flag)


# ==============================================================
#  PARALLAX SCROLLING
# ==============================================================

func _process(delta: float) -> void:
	if state != GameState.PLAYING:
		return
	
	for entry: Dictionary in _bg_elements:
		var node: Node3D = entry["node"]
		if not is_instance_valid(node):
			continue
		node.position.x -= (current_speed * entry["factor"]) * delta
		
		# Wrap background elements far off-screen to prevent flickering/popping
		if node.position.x < BG_LEFT_LIMIT:
			node.position.x += BG_WRAP_WIDTH


# ==============================================================
#  UI  (1280 × 720 landscape, Vietnamese)
# ==============================================================

func _setup_ui() -> void:
	var canvas: CanvasLayer = CanvasLayer.new()
	canvas.name = "UI"
	add_child(canvas)

	# Pill StyleBox for text
	var pill_style: StyleBoxFlat = StyleBoxFlat.new()
	pill_style.bg_color = Color(0, 0, 0, 0.45) # Semi-transparent black
	pill_style.set_corner_radius_all(100)
	pill_style.content_margin_left = 40
	pill_style.content_margin_right = 40
	pill_style.content_margin_top = 15
	pill_style.content_margin_bottom = 15
	
	# Circle StyleBox for score
	var circle_style: StyleBoxFlat = StyleBoxFlat.new()
	circle_style.bg_color = Color(0, 0, 0, 0.45)
	circle_style.set_corner_radius_all(100)

	# --- Score Panel ---
	score_panel = PanelContainer.new()
	score_panel.add_theme_stylebox_override("panel", circle_style)
	score_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	score_panel.offset_top = 20
	score_panel.custom_minimum_size = Vector2(100, 100)
	score_panel.visible = false
	canvas.add_child(score_panel)

	score_label = Label.new()
	score_label.text = "0"
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	score_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	score_label.add_theme_font_size_override("font_size", 64)
	score_label.add_theme_color_override("font_color", Color.WHITE)
	score_panel.add_child(score_label)

	# --- Message Panel ---
	message_panel = PanelContainer.new()
	message_panel.add_theme_stylebox_override("panel", pill_style)
	message_panel.set_anchors_preset(Control.PRESET_CENTER)
	message_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	message_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	canvas.add_child(message_panel)

	message_label = Label.new()
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	message_label.add_theme_font_size_override("font_size", 32)
	message_label.add_theme_color_override("font_color", Color.WHITE)
	message_panel.add_child(message_label)

	# --- Game Over Panel ---
	game_over_panel = PanelContainer.new()
	game_over_panel.add_theme_stylebox_override("panel", pill_style)
	game_over_panel.set_anchors_preset(Control.PRESET_CENTER)
	game_over_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	game_over_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	game_over_panel.visible = false
	canvas.add_child(game_over_panel)

	# --- Rotate Device Mobile Panel ---
	var urgent_style: StyleBoxFlat = pill_style.duplicate()
	urgent_style.bg_color = Color(0.8, 0.1, 0.1, 0.9)
	
	rotate_panel = PanelContainer.new()
	rotate_panel.add_theme_stylebox_override("panel", urgent_style)
	rotate_panel.set_anchors_preset(Control.PRESET_CENTER)
	rotate_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	rotate_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	rotate_panel.visible = false
	rotate_panel.process_mode = Node.PROCESS_MODE_ALWAYS # Hiện kể cả khi pause
	rotate_panel.z_index = 100 # Đảm bảo nằm trên cùng
	canvas.add_child(rotate_panel)

	var rotate_label = Label.new()
	rotate_label.text = "Vui lòng xoay ngang\nđiện thoại để chơi!"
	rotate_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rotate_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rotate_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	rotate_label.add_theme_font_size_override("font_size", 42)
	rotate_label.add_theme_color_override("font_color", Color.WHITE)
	rotate_panel.add_child(rotate_label)

	game_over_container = VBoxContainer.new()
	game_over_container.alignment = BoxContainer.ALIGNMENT_CENTER
	game_over_panel.add_child(game_over_container)

	var go_label: Label = Label.new()
	go_label.text = "KẾT THÚC"
	go_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	go_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	go_label.add_theme_font_size_override("font_size", 52)
	go_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	game_over_container.add_child(go_label)

	var spacer1: Control = Control.new()
	spacer1.custom_minimum_size = Vector2(0, 15)
	game_over_container.add_child(spacer1)

	var score_disp: Label = Label.new()
	score_disp.name = "ScoreDisplay"
	score_disp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_disp.autowrap_mode = TextServer.AUTOWRAP_OFF
	score_disp.add_theme_font_size_override("font_size", 36)
	score_disp.add_theme_color_override("font_color", Color.WHITE)
	game_over_container.add_child(score_disp)

	var best_disp: Label = Label.new()
	best_disp.name = "BestDisplay"
	best_disp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	best_disp.autowrap_mode = TextServer.AUTOWRAP_OFF
	best_disp.add_theme_font_size_override("font_size", 30)
	best_disp.add_theme_color_override("font_color", Color(1, 0.84, 0))
	game_over_container.add_child(best_disp)

	var spacer2: Control = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 30)
	game_over_container.add_child(spacer2)

	var restart_lbl: Label = Label.new()
	restart_lbl.text = "Nhấn chuột hoặc phím Space để chơi lại"
	restart_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	restart_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	restart_lbl.add_theme_font_size_override("font_size", 28)
	restart_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 0.85))
	game_over_container.add_child(restart_lbl)

	# --- Mute and Pause Buttons ---
	var btn_style: StyleBoxFlat = StyleBoxFlat.new()
	btn_style.bg_color = Color(0, 0, 0, 0.45)
	btn_style.set_corner_radius_all(100)

	btn_mute = Button.new()
	btn_mute.text = "🔇" if is_muted else "🔊"
	btn_mute.add_theme_font_size_override("font_size", 32)
	btn_mute.add_theme_stylebox_override("normal", btn_style)
	btn_mute.add_theme_stylebox_override("hover", btn_style)
	btn_mute.add_theme_stylebox_override("pressed", btn_style)
	btn_mute.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn_mute.custom_minimum_size = Vector2(80, 80)
	btn_mute.position = Vector2(20, 20)
	btn_mute.pressed.connect(_on_mute_pressed)
	btn_mute.process_mode = Node.PROCESS_MODE_ALWAYS
	canvas.add_child(btn_mute)

	btn_pause = Button.new()
	btn_pause.text = "⏸"
	btn_pause.add_theme_font_size_override("font_size", 32)
	btn_pause.add_theme_stylebox_override("normal", btn_style)
	btn_pause.add_theme_stylebox_override("hover", btn_style)
	btn_pause.add_theme_stylebox_override("pressed", btn_style)
	btn_pause.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn_pause.custom_minimum_size = Vector2(80, 80)
	btn_pause.position = Vector2(120, 20)
	btn_pause.pressed.connect(_on_pause_pressed)
	btn_pause.process_mode = Node.PROCESS_MODE_ALWAYS
	canvas.add_child(btn_pause)


# ==============================================================
#  INPUT
# ==============================================================

func _unhandled_input(event: InputEvent) -> void:
	if is_mobile_portrait:
		return
		
	if not _is_action_event(event):
		return

	match state:
		GameState.READY:
			_start_game()
			bird.flap()
			sound.play_flap()
		GameState.PLAYING:
			bird.flap()
			sound.play_flap()
		GameState.GAME_OVER:
			if not _restart_cooldown:
				_restart_game()


func _is_action_event(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		return event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if event is InputEventKey:
		return event.pressed and not event.echo and event.keycode == KEY_SPACE
	if event is InputEventScreenTouch:
		return event.pressed
	return false


func _on_pause_pressed() -> void:
	if state == GameState.PLAYING or state == GameState.READY:
		var is_paused: bool = get_tree().paused
		get_tree().paused = !is_paused
		btn_pause.text = "▶" if !is_paused else "⏸"


func _on_mute_pressed() -> void:
	is_muted = !is_muted
	var bus_idx = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(bus_idx, is_muted)
	btn_mute.text = "🔇" if is_muted else "🔊"


# ==============================================================
#  GAME FLOW
# ==============================================================

func _show_ready_screen() -> void:
	message_label.text = "Nhấn chuột hoặc phím Space để bắt đầu"
	message_panel.visible = true
	score_panel.visible = false
	game_over_panel.visible = false


func _start_game() -> void:
	state = GameState.PLAYING
	score = 0
	current_speed = 3.0
	score_label.text = "0"
	score_panel.visible = true
	message_panel.visible = false
	bird.start()
	
	# Spawn initial "pipe train" to ensure uniform spacing from the start
	var spawn_x: float = 32.0
	while spawn_x <= PIPE_SPAWN_X:
		_spawn_pipe(spawn_x)
		spawn_x += PIPE_SPACING
		
	spawn_timer.wait_time = PIPE_SPACING / current_speed
	spawn_timer.start()
	sound.play_bgm()


func _on_spawn_timer_timeout() -> void:
	_spawn_pipe()


func _spawn_pipe(forced_x: float = -1.0) -> void:
	var pipe: Node3D = Node3D.new()
	pipe.set_script(preload("res://pipe.gd"))
	pipe.position.x = forced_x if forced_x > 0 else PIPE_SPAWN_X
	pipe.set("current_speed", current_speed)
	pipe_container.add_child(pipe)

	var gap_center: float = randf_range(GAP_MIN_Y, GAP_MAX_Y)
	pipe.setup(gap_center, GAP_SIZE)
	pipe.is_moving = true
	pipe.score_triggered.connect(_on_pipe_scored)


func _on_pipe_scored() -> void:
	if state == GameState.PLAYING:
		score += 1
		score_label.text = str(score)
		sound.play_score()


func _on_bird_died() -> void:
	state = GameState.GAME_OVER
	spawn_timer.stop()
	_restart_cooldown = true
	sound.stop_bgm()
	sound.play_hit()

	for pipe: Node3D in pipe_container.get_children():
		pipe.set("current_speed", 0)

	if score > best_score:
		best_score = score

	await get_tree().create_timer(0.4).timeout
	sound.play_die()

	await get_tree().create_timer(0.6).timeout

	score_panel.visible = false
	game_over_panel.visible = true
	game_over_container.get_node("ScoreDisplay").text = "Điểm: " + str(score)
	game_over_container.get_node("BestDisplay").text = "Kỷ lục: " + str(best_score)

	await get_tree().create_timer(0.3).timeout
	_restart_cooldown = false


func _restart_game() -> void:
	if get_tree().paused:
		get_tree().paused = false
		btn_pause.text = "⏸"
		
	state = GameState.READY

	for pipe: Node3D in pipe_container.get_children():
		pipe.queue_free()

	bird.reset()
	_show_ready_screen()