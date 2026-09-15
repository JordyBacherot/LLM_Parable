class_name DropZone
extends Area3D

signal zone_satisfied(zone_id: String, object_id: String)
signal zone_unsatisfied(zone_id: String)

@export var zone_id: String = ""
@export var accepted_type: String = "cube"
@export var is_satisfied: bool = false

@onready var indicator_light: OmniLight3D = get_node_or_null("OmniLight3D")
@onready var pad_mesh: MeshInstance3D = get_node_or_null("PadMesh")

var current_object_id: String = ""

func _ready() -> void:
	add_to_group("drop_zones")
	if zone_id.is_empty():
		zone_id = "zone_" + str(get_instance_id())
	
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_update_visuals()

func _on_body_entered(body: Node3D) -> void:
	if body is Carryable and (accepted_type.is_empty() or body.object_type == accepted_type):
		is_satisfied = true
		current_object_id = body.object_id
		_update_visuals()
		zone_satisfied.emit(zone_id, current_object_id)
		print("[DropZone] Object deposited: ", current_object_id, " in zone: ", zone_id)

func _on_body_exited(body: Node3D) -> void:
	if body is Carryable and body.object_id == current_object_id:
		is_satisfied = false
		current_object_id = ""
		_update_visuals()
		zone_unsatisfied.emit(zone_id)
		print("[DropZone] Object removed from zone: ", zone_id)

func _update_visuals() -> void:
	var color = Color(0.2, 0.9, 0.3) if is_satisfied else Color(0.9, 0.3, 0.1)
	if indicator_light:
		indicator_light.light_color = color
	if pad_mesh:
		var mat = pad_mesh.get_active_material(0)
		if mat is StandardMaterial3D:
			mat = mat.duplicate()
			mat.albedo_color = color
			mat.emission_enabled = true
			mat.emission = color
			mat.emission_energy_multiplier = 1.5 if is_satisfied else 0.5
			pad_mesh.set_surface_override_material(0, mat)
