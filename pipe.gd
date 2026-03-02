extends Node3D

signal score_triggered

var current_speed: float = 4.5
const PIPE_WIDTH: float = 1.5
const PIPE_DEPTH: float = 1.5

var is_moving: bool = false
var scored: bool = false

var _pipe_material: StandardMaterial3D = null
var _cap_material: StandardMaterial3D = null


func _ready() -> void:
	_pipe_material = StandardMaterial3D.new()
	_pipe_material.albedo_color = Color(0.30, 0.69, 0.31)
	_pipe_material.metallic = 0.15
	_pipe_material.roughness = 0.55

	_cap_material = StandardMaterial3D.new()
	_cap_material.albedo_color = Color(0.26, 0.63, 0.28)
	_cap_material.metallic = 0.20
	_cap_material.roughness = 0.50


func setup(gap_center: float, gap_size: float) -> void:
	var top_of_gap: float = gap_center + gap_size / 2.0
	var bottom_of_gap: float = gap_center - gap_size / 2.0

	var top_height: float = 16.0 - top_of_gap
	if top_height > 0.1:
		_create_pipe_body("TopPipe", top_of_gap + top_height / 2.0, top_height)
		_create_cap(top_of_gap + 0.2)

	var bottom_height: float = bottom_of_gap
	if bottom_height > 0.1:
		_create_pipe_body("BottomPipe", bottom_height / 2.0, bottom_height)
		_create_cap(bottom_of_gap - 0.2)

	var score_area: Area3D = Area3D.new()
	score_area.name = "ScoreArea"
	score_area.collision_layer = 0
	score_area.collision_mask = 1

	var score_col: CollisionShape3D = CollisionShape3D.new()
	var score_shape: BoxShape3D = BoxShape3D.new()
	score_shape.size = Vector3(0.3, gap_size, PIPE_DEPTH + 1.0)
	score_col.shape = score_shape
	score_area.add_child(score_col)

	score_area.position.y = gap_center
	score_area.body_entered.connect(_on_score_body_entered)
	add_child(score_area)


func _create_pipe_body(pipe_name: String, center_y: float, height: float) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = pipe_name
	
	# Đặt Bottom Pipe về Layer 4 (Giống Ground) để hứng chim nhảy hoặc chết rơi xuống
	# Đặt Top Pipe về Layer 2 để chim chết có thể rơi xuyên ngang
	if pipe_name == "BottomPipe":
		body.collision_layer = 4
	else:
		body.collision_layer = 2
		
	body.collision_mask = 0

	var mesh_inst: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(PIPE_WIDTH, height, PIPE_DEPTH)
	box.material = _pipe_material
	mesh_inst.mesh = box
	body.add_child(mesh_inst)

	var col: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(PIPE_WIDTH, height, PIPE_DEPTH)
	col.shape = shape
	body.add_child(col)

	body.position.y = center_y
	add_child(body)


func _create_cap(y_pos: float) -> void:
	var cap: MeshInstance3D = MeshInstance3D.new()
	var cap_mesh: BoxMesh = BoxMesh.new()
	cap_mesh.size = Vector3(PIPE_WIDTH + 0.30, 0.40, PIPE_DEPTH + 0.30)
	cap_mesh.material = _cap_material
	cap.mesh = cap_mesh
	cap.position.y = y_pos
	add_child(cap)


func _process(delta: float) -> void:
	if is_moving and current_speed > 0:
		var actual_speed = current_speed
		# If we wanted to access main.gd directly, we could use:
		# var main = get_tree().root.get_child(0)
		# if main and "current_speed" in main: actual_speed = main.current_speed
		
		# However, main.gd will update all pipes' current_speed instead.
		position.x -= actual_speed * delta
		if position.x < -80.0:
			queue_free()


func _on_score_body_entered(body: Node3D) -> void:
	if not scored and body is CharacterBody3D:
		scored = true
		score_triggered.emit()