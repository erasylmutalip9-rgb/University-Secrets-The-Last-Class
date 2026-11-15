extends CharacterBody3D
class_name AlexPlayer

signal camera_mode_changed(first_person: bool)
signal flashlight_changed(enabled: bool)
signal recovered_from_fall()

const WALK_SPEED: float = 3.6
const RUN_SPEED: float = 5.8
const GRAVITY: float = 22.0
const ACCELERATION: float = 13.0
const BRAKE: float = 19.0
const JUMP_VELOCITY: float = 5.0
const MOUSE_SENS: float = 0.0019

var skate_mode: bool = false
var campaign_bounds: Vector2 = Vector2.ZERO
var can_move: bool = false
var first_person: bool = true
var flashlight_on: bool = true
var visual: CampusCharacterVisual
var last_safe_position: Vector3 = Vector3(-2.0,0.30,3.3)
var stable_ground_time: float = 0.0
var pitch: float = -0.14
var sway_time: float = 0.0

var camera_pivot: Node3D
var first_camera: Camera3D
var third_camera: Camera3D
var flashlight: SpotLight3D

func _ready() -> void:
	name = "Алекс"
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.35
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.34
	capsule.height = 1.78
	var collider := CollisionShape3D.new()
	collider.shape = capsule
	collider.position.y = 0.89
	add_child(collider)
	visual = CampusCharacterVisual.new()
	visual.name = "Модель Алекса"
	visual.archetype = "alex"
	visual.layer_mask = 2
	add_child(visual)
	camera_pivot = Node3D.new()
	camera_pivot.name = "Поворот камеры"
	camera_pivot.position.y = 1.64
	add_child(camera_pivot)
	first_camera = Camera3D.new()
	first_camera.name = "Первое лицо"
	first_camera.fov = 78.0
	first_camera.near = 0.05
	first_camera.cull_mask = 1
	camera_pivot.add_child(first_camera)
	var arm := SpringArm3D.new()
	arm.name = "Слежение без прохода сквозь стены"
	arm.spring_length = 3.2
	arm.margin = 0.22
	arm.collision_mask = 1
	arm.position.y = -0.12
	camera_pivot.add_child(arm)
	arm.add_excluded_object(get_rid())
	third_camera = Camera3D.new()
	third_camera.name = "Третье лицо"
	third_camera.fov = 73.0
	third_camera.near = 0.1
	third_camera.position.x = 0.30
	third_camera.cull_mask = 3
	arm.add_child(third_camera)
	flashlight = SpotLight3D.new()
	flashlight.name = "Фонарик"
	flashlight.light_color = Color("fff1d8")
	flashlight.light_energy = 1.45
	flashlight.spot_range = 17.0
	flashlight.spot_angle = 29.0
	flashlight.shadow_enabled = true
	camera_pivot.add_child(flashlight)
	flashlight.position = Vector3(0.16, -0.12, -0.08)
	flashlight_on = false
	flashlight.visible = false
	set_camera_mode(true)

func _physics_process(delta: float) -> void:
	# Rescue when crossing a physics gap or loading an outdated save location.
	if global_position.y < -0.60 or not _inside_campus_bounds(global_position):
		_rescue_player()
		return
	if is_on_floor() and _inside_safe_room(global_position):
		stable_ground_time += delta
		if stable_ground_time > 0.22:
			last_safe_position = global_position
	else:
		stable_ground_time = 0.0
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = -0.6
	if can_move and Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		stable_ground_time = 0.0
	if can_move:
		var move_input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		var move_dir: Vector3 = (global_transform.basis * Vector3(move_input.x, 0.0, move_input.y)).normalized()
		var speed: float = RUN_SPEED if Input.is_action_pressed("sprint") else WALK_SPEED
		if skate_mode: speed *= 1.35
		var accel: float = ACCELERATION if move_input.length() > 0.03 else BRAKE
		velocity.x = move_toward(velocity.x, move_dir.x * speed, accel * delta)
		velocity.z = move_toward(velocity.z, move_dir.z * speed, accel * delta)
		visual.move_amount = clampf(Vector2(velocity.x,velocity.z).length()/WALK_SPEED,0.0,1.0)
		visual.sprinting = speed > WALK_SPEED
		if move_input.length() > 0.05:
			sway_time += delta * (9.0 if speed > WALK_SPEED else 6.0)
			if first_person:
				first_camera.position.y = lerpf(first_camera.position.y, sin(sway_time) * 0.012,delta*8.0)
		else:
			first_camera.position.y = lerpf(first_camera.position.y,0.0,delta*7.0)
	else:
		visual.move_amount = clampf(Vector2(velocity.x,velocity.z).length()/WALK_SPEED,0.0,1.0)
		velocity.x = move_toward(velocity.x, 0.0, BRAKE * delta)
		velocity.z = move_toward(velocity.z, 0.0, BRAKE * delta)
	move_and_slide()

func _unhandled_input(event: InputEvent) -> void:
	if not can_move:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENS)
		var lower_limit: float = -0.95 if first_person else -0.40
		var upper_limit: float = 0.95 if first_person else 0.38
		pitch = clampf(pitch - event.relative.y * MOUSE_SENS, lower_limit, upper_limit)
		camera_pivot.rotation.x = pitch

func toggle_camera() -> void:
	set_camera_mode(not first_person)

func reset_camera() -> void:
	pitch = -0.14
	camera_pivot.rotation.x = pitch
	if is_instance_valid(third_camera):
		third_camera.h_offset = 0.0
		third_camera.v_offset = 0.0

func set_camera_mode(is_first: bool) -> void:
	first_person = is_first
	if not first_person:
		pitch = clampf(pitch, -0.30, 0.25)
		camera_pivot.rotation.x = pitch
	first_camera.current = first_person
	third_camera.current = not first_person
	if is_instance_valid(visual):
		visual.visible = not first_person
	camera_mode_changed.emit(first_person)

func toggle_flashlight() -> void:
	flashlight_on = not flashlight_on
	flashlight.visible = flashlight_on
	flashlight_changed.emit(flashlight_on)

func look_direction() -> Vector3:
	return (-camera_pivot.global_transform.basis.z).normalized()


# A checkpoint is valid only over a real playable room or connector.
func _inside_safe_room(p: Vector3) -> bool:
	if campaign_bounds != Vector2.ZERO:
		return absf(p.x) < campaign_bounds.x - 0.4 and absf(p.z) < campaign_bounds.y - 0.4
	return (absf(p.x) < 8.55 and absf(p.z) < 7.50) \
		or (absf(p.x + 19.0) < 8.55 and absf(p.z) < 7.5) \
		or (absf(p.x - 19.0) < 8.55 and absf(p.z) < 7.5) \
		or (absf(p.x - 19.0) < 8.55 and absf(p.z + 16.0) < 7.5) \
		or (p.x > -10.6 and p.x < -8.4 and absf(p.z) < 1.65) \
		or (p.x > 8.4 and p.x < 10.6 and absf(p.z) < 1.65)

func _inside_campus_bounds(p: Vector3) -> bool:
	if campaign_bounds != Vector2.ZERO:
		return absf(p.x) < campaign_bounds.x + 1.0 and absf(p.z) < campaign_bounds.y + 1.0
	return p.x >= -29.0 and p.x <= 29.0 and p.z >= -25.0 and p.z <= 9.0

func _rescue_player() -> void:
	velocity = Vector3.ZERO
	global_position = last_safe_position + Vector3(0,0.18,0)
	stable_ground_time = 0.0
	recovered_from_fall.emit()

func set_safe_spawn(pos: Vector3) -> void:
	last_safe_position = pos
	global_position = pos
	velocity = Vector3.ZERO
	stable_ground_time = 0.0
