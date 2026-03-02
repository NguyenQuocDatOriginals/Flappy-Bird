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
var pause_panel: PanelContainer = null
var pause_label: Label = null

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
	# Cho phép Main script luôn chạy để nhận Input Unpause
	process_mode = Node.PROCESS_MODE_ALWAYS
	
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
	var is_mobile: bool = os_name == "Android" or os_name == "iOS" or OS.has_feature("web_android") or OS.has_feature("web_ios") or OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()
	
	if is_mobile:
		var screen_size = get_viewport().get_visible_rect().size
		if screen_size.y > screen_size.x: # Màn hình dọc (Portrait)
			is_mobile_portrait = true
			if rotate_panel:
				rotate_panel.visible = true
			
			# Hiden all UI and bird
			_set_game_visibility(false)
			if message_panel: message_panel.visible = false
			
			if state != GameState.READY: # Dừng game nếu đang chơi
				get_tree().paused = true
		else: # Màn hình ngang (Landscape)
			is_mobile_portrait = false
			if rotate_panel:
				rotate_panel.visible = false
			
			# Restore UI and bird visibility
			_set_game_visibility(true)
			# Nếu đang sẵn sàng và bị chặn, không tự động unpause game nếu đang chơi (để người dùng nhấn nút Pause lại)
	else:
		is_mobile_portrait = false
		if rotate_panel:
			rotate_panel.visible = false
		_set_game_visibility(true)


func _set_game_visibility(is_visible: bool) -> void:
	# UI Elements
	if btn_mute: btn_mute.visible = is_visible
	if btn_pause: 
		# Pause button only visible during PLAYING state in landscape
		btn_pause.visible = is_visible and state == GameState.PLAYING
	
	if is_visible:
		# Restore based on state
		match state:
			GameState.READY:
				if message_panel: message_panel.visible = true
				if score_panel: score_panel.visible = false
				if game_over_panel: game_over_panel.visible = false
				if pause_panel: pause_panel.visible = get_tree().paused
			GameState.PLAYING:
				if message_panel: message_panel.visible = false
				if score_panel: score_panel.visible = !get_tree().paused
				if game_over_panel: game_over_panel.visible = false
				if pause_panel: pause_panel.visible = get_tree().paused
			GameState.GAME_OVER:
				if message_panel: message_panel.visible = false
				if score_panel: score_panel.visible = false
				if game_over_panel: game_over_panel.visible = true
				if pause_panel: pause_panel.visible = false
	else:
		if message_panel: message_panel.visible = false
		if score_panel: score_panel.visible = false
		if game_over_panel: game_over_panel.visible = false
		if pause_panel: pause_panel.visible = false

	# Bird visibility
	if bird:
		bird.visible = is_visible


# ==============================================================
#  SCENE SETUP
# ==============================================================

func _setup_sound() -> void:
	sound = Node.new()
	sound.set_script(preload("res://sound_manager.gd"))
	sound.name = "SoundManager"
	sound.process_mode = Node.PROCESS_MODE_PAUSABLE
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
	world_env.process_mode = Node.PROCESS_MODE_PAUSABLE
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
	bird.position = Vector3(5, 7, 0)
	bird.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(bird)
	bird.died.connect(_on_bird_died)


func _setup_pipes() -> void:
	pipe_container = Node3D.new()
	pipe_container.name = "Pipes"
	pipe_container.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(pipe_container)

	spawn_timer = Timer.new()
	spawn_timer.wait_time = PIPE_SPACING / current_speed
	spawn_timer.one_shot = false
	spawn_timer.process_mode = Node.PROCESS_MODE_PAUSABLE
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
		group.process_mode = Node.PROCESS_MODE_PAUSABLE
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
		group.process_mode = Node.PROCESS_MODE_PAUSABLE
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
	grass_group.process_mode = Node.PROCESS_MODE_PAUSABLE
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
		road_group.process_mode = Node.PROCESS_MODE_PAUSABLE
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
		flag_group.process_mode = Node.PROCESS_MODE_PAUSABLE
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
	if state != GameState.PLAYING or get_tree().paused:
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
#  MODERN UI HELPERS
# ==============================================================

func _setup_modern_button(btn: Button) -> void:
	btn.resized.connect(func(): btn.pivot_offset = btn.size / 2.0)
	
	btn.mouse_entered.connect(func():
		var tw = get_tree().create_tween()
		tw.tween_property(btn, "scale", Vector2(1.1, 1.1), 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	)
	btn.mouse_exited.connect(func():
		var tw = get_tree().create_tween()
		tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	)
	btn.button_down.connect(func():
		var tw = get_tree().create_tween()
		tw.tween_property(btn, "scale", Vector2(0.95, 0.95), 0.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	)
	btn.button_up.connect(func():
		var tw = get_tree().create_tween()
		var target_scale = Vector2(1.1, 1.1) if btn.is_hovered() else Vector2(1.0, 1.0)
		tw.tween_property(btn, "scale", target_scale, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	)
	
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color("#2563EB") # primary-600
	normal_style.set_corner_radius_all(100)
	normal_style.shadow_color = Color(0.145, 0.388, 0.922, 0.4) # shadow-primary-600/40
	normal_style.shadow_size = 15
	normal_style.shadow_offset = Vector2(0, 4)
	
	var hover_style = normal_style.duplicate()
	hover_style.bg_color = Color("#3B82F6") # primary-500
	hover_style.shadow_size = 20
	hover_style.shadow_offset = Vector2(0, 8)
	
	var pressed_style = normal_style.duplicate()
	pressed_style.bg_color = Color("#1D4ED8") # primary-700
	pressed_style.shadow_size = 5
	pressed_style.shadow_offset = Vector2(0, 2)
	
	btn.add_theme_stylebox_override("normal", normal_style)
	btn.add_theme_stylebox_override("hover", hover_style)
	btn.add_theme_stylebox_override("pressed", pressed_style)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	
	var font = SystemFont.new()
	font.font_names = ["Segoe UI", "Roboto", "Helvetica Neue", "Arial", "sans-serif"]
	font.font_weight = 600
	btn.add_theme_font_override("font", font)


func _setup_modern_panel(panel: PanelContainer, is_circle: bool = false, is_urgent: bool = false) -> void:
	panel.resized.connect(func(): panel.pivot_offset = panel.size / 2.0)
	
	var style = StyleBoxFlat.new()
	if is_urgent:
		style.bg_color = Color("#EF4444") # red-500
		style.shadow_color = Color(0.937, 0.266, 0.266, 0.4)
	else:
		style.bg_color = Color("#2563EB") # primary-600
		style.shadow_color = Color(0.145, 0.388, 0.922, 0.4)
		
	style.set_corner_radius_all(100 if is_circle else 32)
	style.shadow_size = 20
	style.shadow_offset = Vector2(0, 8)
	
	if not is_circle:
		style.content_margin_left = 40
		style.content_margin_right = 40
		style.content_margin_top = 20
		style.content_margin_bottom = 20
		
	panel.visibility_changed.connect(func():
		if panel.visible:
			panel.scale = Vector2(0.5, 0.5)
			var tw = get_tree().create_tween()
			tw.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	)
		
	panel.add_theme_stylebox_override("panel", style)


func _setup_modern_label(label: Label, is_bold: bool = false) -> void:
	var font = SystemFont.new()
	font.font_names = ["Segoe UI", "Roboto", "Helvetica Neue", "Arial", "sans-serif"]
	font.font_weight = 700 if is_bold else 600
	label.add_theme_font_override("font", font)


# ==============================================================
#  UI  (1280 × 720 landscape, Vietnamese)
# ==============================================================

func _setup_ui() -> void:
	var canvas: CanvasLayer = CanvasLayer.new()
	canvas.name = "UI"
	add_child(canvas)

	# --- Score Panel ---
	score_panel = PanelContainer.new()
	_setup_modern_panel(score_panel, true)
	
	var custom_score_style = score_panel.get_theme_stylebox("panel").duplicate()
	custom_score_style.content_margin_left = 0
	custom_score_style.content_margin_right = 0
	custom_score_style.content_margin_top = 0
	custom_score_style.content_margin_bottom = 0
	score_panel.add_theme_stylebox_override("panel", custom_score_style)
	
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
	_setup_modern_label(score_label, true)
	score_panel.add_child(score_label)

	# --- Message Panel ---
	message_panel = PanelContainer.new()
	_setup_modern_panel(message_panel, true)
	var custom_style = message_panel.get_theme_stylebox("panel").duplicate()
	custom_style.content_margin_left = 60
	custom_style.content_margin_right = 60
	custom_style.content_margin_top = 30
	custom_style.content_margin_bottom = 30
	message_panel.add_theme_stylebox_override("panel", custom_style)
	
	message_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	message_panel.offset_top = 20
	message_panel.custom_minimum_size = Vector2(150, 0)
	message_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	message_panel.grow_vertical = Control.GROW_DIRECTION_END
	canvas.add_child(message_panel)

	message_label = Label.new()
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	message_label.add_theme_font_size_override("font_size", 32)
	message_label.add_theme_color_override("font_color", Color.WHITE)
	_setup_modern_label(message_label, false)
	message_panel.add_child(message_label)

	# --- Capsule Pause Panel ---
	pause_panel = PanelContainer.new()
	_setup_modern_panel(pause_panel, true)
	var custom_pause_style = pause_panel.get_theme_stylebox("panel").duplicate()
	custom_pause_style.content_margin_left = 120
	custom_pause_style.content_margin_right = 120
	custom_pause_style.content_margin_top = 60
	custom_pause_style.content_margin_bottom = 60
	pause_panel.add_theme_stylebox_override("panel", custom_pause_style)
	
	# Matching score_panel position exactly
	pause_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	pause_panel.offset_top = -30
	pause_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	pause_panel.grow_vertical = Control.GROW_DIRECTION_END
	pause_panel.custom_minimum_size = Vector2(150, 0)
	pause_panel.visible = false
	canvas.add_child(pause_panel)

	pause_label = Label.new()
	pause_label.text = "Đã tạm dừng trò chơi rồi nè bạn yêu dấu ơi!"
	pause_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pause_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	pause_label.add_theme_font_size_override("font_size", 64)
	pause_label.add_theme_color_override("font_color", Color.WHITE)
	_setup_modern_label(pause_label, false)
	pause_panel.add_child(pause_label)


	# --- Game Over Panel ---
	game_over_panel = PanelContainer.new()
	_setup_modern_panel(game_over_panel, false)
	
	var custom_go_style = game_over_panel.get_theme_stylebox("panel").duplicate()
	custom_go_style.content_margin_left = 60
	custom_go_style.content_margin_right = 60
	custom_go_style.content_margin_top = 30
	custom_go_style.content_margin_bottom = 30
	game_over_panel.add_theme_stylebox_override("panel", custom_go_style)
	
	game_over_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	game_over_panel.offset_top = 20
	game_over_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	game_over_panel.grow_vertical = Control.GROW_DIRECTION_END
	game_over_panel.visible = false
	canvas.add_child(game_over_panel)

	# --- Rotate Device Mobile Panel ---
	rotate_panel = PanelContainer.new()
	_setup_modern_panel(rotate_panel, true, true)
	
	# Match pause_panel exactly for mobile
	var os_name: String = OS.get_name()
	var is_mobile: bool = os_name == "Android" or os_name == "iOS" or OS.has_feature("web_android") or OS.has_feature("web_ios") or OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()
	if is_mobile:
		rotate_panel.custom_minimum_size = Vector2(150, 0)
		var match_style = rotate_panel.get_theme_stylebox("panel").duplicate()
		match_style.content_margin_left = 60
		match_style.content_margin_right = 60
		match_style.content_margin_top = 40
		match_style.content_margin_bottom = 40
		rotate_panel.add_theme_stylebox_override("panel", match_style)
	
	rotate_panel.set_anchors_preset(Control.PRESET_CENTER)
	rotate_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	rotate_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	rotate_panel.visible = false
	rotate_panel.process_mode = Node.PROCESS_MODE_ALWAYS # Hiện kể cả khi pause
	rotate_panel.z_index = 100 # Đảm bảo nằm trên cùng
	canvas.add_child(rotate_panel)

	var rotate_label = Label.new()
	rotate_label.text = "Hãy xoay ngang điện thoại để chơi nha bạn yêu dấu ơi!"
	rotate_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rotate_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rotate_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	rotate_label.add_theme_font_size_override("font_size", 48) # Reduced to fit mobile portrait
	rotate_label.add_theme_color_override("font_color", Color.WHITE)
	_setup_modern_label(rotate_label, true)
	rotate_panel.add_child(rotate_label)

	game_over_container = VBoxContainer.new()
	game_over_container.alignment = BoxContainer.ALIGNMENT_CENTER
	game_over_panel.add_child(game_over_container)

	var go_label: Label = Label.new()
	go_label.text = "TOANG RỒI BẠN YÊU DẤU ƠI!"
	go_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	go_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	go_label.add_theme_font_size_override("font_size", 52)
	go_label.add_theme_color_override("font_color", Color.WHITE)
	_setup_modern_label(go_label, true)
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
	_setup_modern_label(score_disp, true)
	game_over_container.add_child(score_disp)

	var best_disp: Label = Label.new()
	best_disp.name = "BestDisplay"
	best_disp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	best_disp.autowrap_mode = TextServer.AUTOWRAP_OFF
	best_disp.add_theme_font_size_override("font_size", 36)
	best_disp.add_theme_color_override("font_color", Color(1, 0.84, 0)) # Gold text for Best
	_setup_modern_label(best_disp, true)
	game_over_container.add_child(best_disp)

	var spacer2: Control = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 30)
	game_over_container.add_child(spacer2)

	var restart_lbl: Label = Label.new()
	restart_lbl.name = "RestartInstruction"
	restart_lbl.text = "Hãy nhấn chuột hoặc phím Space để chơi lại nha bạn yêu dấu ơi!"
	restart_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	restart_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	restart_lbl.add_theme_font_size_override("font_size", 24)
	restart_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 0.85))
	_setup_modern_label(restart_lbl, false)
	game_over_container.add_child(restart_lbl)

	# --- Mute and Pause Buttons ---

	btn_mute = Button.new()
	btn_mute.focus_mode = Control.FOCUS_NONE
	btn_mute.icon = preload("res://assets/volume-x.svg") if is_muted else preload("res://assets/volume-2.svg")
	btn_mute.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn_mute.expand_icon = true
	btn_mute.add_theme_constant_override("icon_max_width", 42)
	btn_mute.custom_minimum_size = Vector2(100, 100)
	btn_mute.position = Vector2(25, 25)
	
	btn_mute.pressed.connect(_on_mute_pressed)
	btn_mute.process_mode = Node.PROCESS_MODE_ALWAYS
	canvas.add_child(btn_mute)
	_setup_modern_button(btn_mute)

	btn_pause = Button.new()
	btn_pause.focus_mode = Control.FOCUS_NONE
	btn_pause.icon = preload("res://assets/pause.svg")
	btn_pause.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn_pause.expand_icon = true
	btn_pause.add_theme_constant_override("icon_max_width", 42)
	btn_pause.custom_minimum_size = Vector2(100, 100)
	btn_pause.position = Vector2(145, 25)
	
	btn_pause.pressed.connect(_on_pause_pressed)
	btn_pause.process_mode = Node.PROCESS_MODE_ALWAYS
	canvas.add_child(btn_pause)
	_setup_modern_button(btn_pause)


# ==============================================================
#  INPUT
# ==============================================================

func _unhandled_input(event: InputEvent) -> void:
	if is_mobile_portrait:
		return
		
	if not _is_action_event(event):
		return

	# Nếu game đang bị tạm dừng, cho phép dùng Input để unpause
	if get_tree().paused and (state == GameState.PLAYING or state == GameState.READY):
		_on_pause_pressed()
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
		
		if !is_paused: # Tức là hiện tại đang chuyển sang Pause
			btn_pause.icon = preload("res://assets/play.svg")
			score_panel.visible = false
			message_panel.visible = false
			pause_panel.visible = true
		else:
			btn_pause.icon = preload("res://assets/pause.svg")
			pause_panel.visible = false
			if state == GameState.READY:
				message_panel.visible = true
			else:
				message_panel.visible = false
				score_panel.visible = true


func _on_mute_pressed() -> void:
	is_muted = !is_muted
	var bus_idx = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(bus_idx, is_muted)
	btn_mute.icon = preload("res://assets/volume-x.svg") if is_muted else preload("res://assets/volume-2.svg")


# ==============================================================
#  GAME FLOW
# ==============================================================

func _show_ready_screen() -> void:
	var os_name: String = OS.get_name()
	var is_mobile: bool = os_name == "Android" or os_name == "iOS" or OS.has_feature("web_android") or OS.has_feature("web_ios") or OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()
	var action_text = "chạm vào màn hình" if is_mobile else "nhấn chuột hoặc phím Space"
	
	message_label.text = "Hãy " + action_text + " để bắt đầu nha bạn yêu dấu ơi!"
	message_panel.visible = !is_mobile_portrait
	pause_panel.visible = false
	score_panel.visible = false
	game_over_panel.visible = false
	
	if btn_pause:
		btn_pause.visible = false


func _start_game() -> void:
	state = GameState.PLAYING
	score = 0
	current_speed = 3.0
	score_label.text = "0"
	score_panel.visible = true
	message_panel.visible = false
	pause_panel.visible = false
	
	if btn_pause:
		btn_pause.visible = true
		
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
		
		# Bump animation cho điểm số
		var tw = get_tree().create_tween()
		score_panel.pivot_offset = score_panel.size / 2.0
		tw.tween_property(score_panel, "scale", Vector2(1.2, 1.2), 0.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(score_panel, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _on_bird_died() -> void:
	state = GameState.GAME_OVER
	
	if btn_pause:
		btn_pause.visible = false
		
	spawn_timer.stop()
	_restart_cooldown = false # Instant restart allowed
	sound.stop_bgm()
	sound.play_hit()

	for pipe: Node3D in pipe_container.get_children():
		pipe.set("current_speed", 0)

	if score > best_score:
		best_score = score

	await get_tree().create_timer(0.4).timeout
	if state != GameState.GAME_OVER: return # Guard: check if game was restarted
	sound.play_die()

	await get_tree().create_timer(0.6).timeout
	if state != GameState.GAME_OVER: return # Guard: check if game was restarted

	score_panel.visible = false
	game_over_panel.visible = true
	game_over_container.get_node("ScoreDisplay").text = "Điểm: " + str(score)
	game_over_container.get_node("BestDisplay").text = "Kỷ lục: " + str(best_score)
	
	var os_name: String = OS.get_name()
	var is_mobile: bool = os_name == "Android" or os_name == "iOS" or OS.has_feature("web_android") or OS.has_feature("web_ios") or OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()
	var action_text = "chạm vào màn hình" if is_mobile else "nhấn chuột hoặc phím Space"
	game_over_container.get_node("RestartInstruction").text = "Hãy " + action_text + " để chơi lại nha bạn yêu dấu ơi!"

	_restart_cooldown = false


func _restart_game() -> void:
	if get_tree().paused:
		get_tree().paused = false
		btn_pause.icon = preload("res://assets/pause.svg")
		
	state = GameState.READY

	for pipe: Node3D in pipe_container.get_children():
		pipe.queue_free()

	bird.reset()
	_show_ready_screen()