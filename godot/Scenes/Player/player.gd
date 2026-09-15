extends CharacterBody3D

@onready var gunRay = $Head/Camera3d/RayCast3d as RayCast3D
@onready var Cam = $Head/Camera3d as Camera3D
@export var _bullet_scene : PackedScene
var mouseSensibility = 1200
var mouse_relative_x = 0
var mouse_relative_y = 0
const SPEED = 5.0
const JUMP_VELOCITY = 4.5

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

var held_object: Carryable = null
const INTERACT_DISTANCE: float = 3.5

func _ready():
	add_to_group("player")
	#Captures mouse and stops rgun from hitting yourself
	gunRay.add_exception(self)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
func _physics_process(delta):
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Handle Jump.
	if Input.is_action_just_pressed("Jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	# Handle Shooting
	if Input.is_action_just_pressed("Shoot"):
		shoot()
	# Get the input direction and handle the movement/deceleration.
	var input_dir = Input.get_vector("moveLeft", "moveRight", "moveUp", "moveDown")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()

	# Maintien de l'objet porté
	if held_object and is_instance_valid(held_object):
		var target_hold_pos = Cam.global_position - Cam.global_transform.basis.z * 2.2
		held_object.global_position = held_object.global_position.lerp(target_hold_pos, 0.3)
		held_object.rotation = Cam.global_rotation

func _input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_E or event.keycode == KEY_E:
			toggle_interact()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		toggle_interact()

	if event is InputEventMouseMotion:
		rotation.y -= event.relative.x / mouseSensibility
		$Head/Camera3d.rotation.x -= event.relative.y / mouseSensibility
		$Head/Camera3d.rotation.x = clamp($Head/Camera3d.rotation.x, deg_to_rad(-90), deg_to_rad(90) )
		mouse_relative_x = clamp(event.relative.x, -50, 50)
		mouse_relative_y = clamp(event.relative.y, -50, 10)

func toggle_interact() -> void:
	if held_object:
		drop_held_object()
	else:
		try_pickup_object()

func try_pickup_object() -> void:
	var space_state = get_world_3d().direct_space_state
	var origin = Cam.global_position
	var end = origin - Cam.global_transform.basis.z * INTERACT_DISTANCE
	var query = PhysicsRayQueryParameters3D.create(origin, end)
	query.exclude = [self.get_rid()]
	var result = space_state.intersect_ray(query)
	if result:
		var collider = result.collider
		if collider is Carryable:
			held_object = collider
			held_object.pick_up(self)
		elif collider.is_in_group("carryable") and collider is RigidBody3D:
			held_object = collider as Carryable
			if held_object:
				held_object.pick_up(self)

func drop_held_object() -> void:
	if held_object and is_instance_valid(held_object):
		var forward = -Cam.global_transform.basis.z
		held_object.drop(forward * 3.0)
		held_object = null

func teleport_to(target_pos: Vector3) -> void:
	velocity = Vector3.ZERO
	global_position = target_pos

func shoot():
	if not gunRay.is_colliding():
		return
	var bulletInst = _bullet_scene.instantiate() as Node3D
	bulletInst.set_as_top_level(true)
	get_parent().add_child(bulletInst)
	bulletInst.global_transform.origin = gunRay.get_collision_point() as Vector3
	bulletInst.look_at((gunRay.get_collision_point()+gunRay.get_collision_normal()),Vector3.BACK)
	print(gunRay.get_collision_point())
	print(gunRay.get_collision_point()+gunRay.get_collision_normal())
