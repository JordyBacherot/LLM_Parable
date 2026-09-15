class_name Carryable
extends RigidBody3D

@export var object_id: String = ""
@export var object_type: String = "cube"

var is_held: bool = false
var carrier_node: Node3D = null

func _ready() -> void:
	add_to_group("carryable")
	if object_id.is_empty():
		object_id = "obj_" + str(get_instance_id())

func pick_up(carrier: Node3D) -> void:
	is_held = true
	carrier_node = carrier
	freeze = true
	collision_layer = 2
	collision_mask = 1

func drop(impulse: Vector3 = Vector3.ZERO) -> void:
	is_held = false
	carrier_node = null
	freeze = false
	collision_layer = 1
	collision_mask = 1
	if impulse != Vector3.ZERO:
		apply_central_impulse(impulse)

func _physics_process(_delta: float) -> void:
	if is_held and carrier_node:
		global_transform.origin = carrier_node.global_transform.origin
		rotation = carrier_node.rotation
