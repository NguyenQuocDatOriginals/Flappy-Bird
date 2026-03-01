extends CharacterBody3D

signal died

const GRAVITY: float = 25.0
const FLAP_STRENGTH: float = 9.5
const MAX_FALL_SPEED: float = -18.0
const ROTATION_LERP_SPEED: float = 4.0

var is_alive: bool = true
var can_flap: bool = false

var wing_l: MeshInstance3D = null
var wing_r: MeshInstance3D = null
var flap_time: float = 0.0


func _ready() -> void:
	collision_layer = 1
	collision_mask = 6

	_create_body()
	_create_beak()
	_create_eye()
	_create_wings()
	_create_collision()


func _create_body() -> void:
	var mesh_inst: MeshInstance3D = MeshInstance3D.new()
	var capsule: CapsuleMesh = CapsuleMesh.new()
	capsule.radius = 0.30
	capsule.height = 0.70

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.84, 0.0)
	mat.metallic = 0.15
	mat.roughness = 0.45
	capsule.material = mat

	mesh_inst.mesh = capsule
	mesh_inst.rotation_degrees.z = 90
	add_child(mesh_inst)


func _create_beak() -> void:
	var beak: MeshInstance3D = MeshInstance3D.new()
	var beak_mesh: BoxMesh = BoxMesh.new()
	beak_mesh.size = Vector3(0.22, 0.12, 0.18)

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.4, 0.0)
	mat.roughness = 0.6
	beak_mesh.material = mat

	beak.mesh = beak_mesh
	beak.position = Vector3(0.38, -0.02, 0.0)
	add_child(beak)


func _create_eye() -> void:
	var eye: MeshInstance3D = MeshInstance3D.new()
	var eye_mesh: SphereMesh = SphereMesh.new()
	eye_mesh.radius = 0.10
	eye_mesh.height = 0.20

	var white_mat: StandardMaterial3D = StandardMaterial3D.new()
	white_mat.albedo_color = Color.WHITE
	eye_mesh.material = white_mat

	eye.mesh = eye_mesh
	eye.position = Vector3(0.18, 0.15, 0.20)
	add_child(eye)

	var pupil: MeshInstance3D = MeshInstance3D.new()
	var pupil_mesh: SphereMesh = SphereMesh.new()
	pupil_mesh.radius = 0.055
	pupil_mesh.height = 0.11

	var black_mat: StandardMaterial3D = StandardMaterial3D.new()
	black_mat.albedo_color = Color.BLACK
	pupil_mesh.material = black_mat

	pupil.mesh = pupil_mesh
	pupil.position = Vector3(0.24, 0.17, 0.23)
	add_child(pupil)


func _create_wings() -> void:
	var wing_mat: StandardMaterial3D = StandardMaterial3D.new()
	wing_mat.albedo_color = Color(1.0, 0.55, 0.0) # Orange
	wing_mat.roughness = 0.5

	var wing_mesh: BoxMesh = BoxMesh.new()
	wing_mesh.size = Vector3(0.35, 0.04, 0.45)
	wing_mesh.material = wing_mat

	wing_l = MeshInstance3D.new()
	wing_l.mesh = wing_mesh
	wing_l.position = Vector3(-0.05, 0.05, 0.35)
	add_child(wing_l)

	wing_r = MeshInstance3D.new()
	wing_r.mesh = wing_mesh
	wing_r.position = Vector3(-0.05, 0.05, -0.35)
	add_child(wing_r)


func _create_collision() -> void:
	var col: CollisionShape3D = CollisionShape3D.new()
	var shape: CapsuleShape3D = CapsuleShape3D.new()
	shape.radius = 0.30
	shape.height = 0.85
	col.shape = shape
	
	# Rotate and position to cover body + beak
	col.rotation_degrees.z = 90
	col.position.x = 0.1 # Shift slightly forward
	add_child(col)


func _physics_process(delta: float) -> void:
	if not is_alive:
		velocity.y -= GRAVITY * delta
		velocity.y = max(velocity.y, MAX_FALL_SPEED)
		move_and_slide()
		rotation.z = lerp(rotation.z, -PI / 2.0, delta * 2.5)
		return

	if not can_flap:
		return

	velocity.y -= GRAVITY * delta
	velocity.y = max(velocity.y, MAX_FALL_SPEED)

	var target_rot: float = clampf(velocity.y * 0.08, -1.2, 0.5)
	rotation.z = lerp(rotation.z, target_rot, delta * ROTATION_LERP_SPEED)

	# Wing flapping animation
	flap_time += delta * (25.0 if velocity.y > 0 else 12.0)
	var flap_angle: float = sin(flap_time) * 0.7
	wing_l.rotation.x = flap_angle
	wing_r.rotation.x = -flap_angle

	move_and_slide()

	if get_slide_collision_count() > 0:
		die()


func flap() -> void:
	if is_alive and can_flap:
		velocity.y = FLAP_STRENGTH


func die() -> void:
	if not is_alive:
		return
	is_alive = false
	died.emit()


func start() -> void:
	can_flap = true


func reset() -> void:
	position = Vector3(20, 7, 0)
	velocity = Vector3.ZERO
	rotation = Vector3.ZERO
	is_alive = true
	can_flap = false
	collision_layer = 1
	collision_mask = 6