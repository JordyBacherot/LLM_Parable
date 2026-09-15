class_name ModularRoom
extends Node3D

signal player_entered(coords: Vector3i)
signal player_exited(coords: Vector3i)

@export var coords: Vector3i = Vector3i.ZERO
@export var room_type: String = "normal"
@export var room_size: Vector3 = Vector3(20.0, 6.0, 20.0)

# États possibles pour chaque mur : "open", "closed", "locked", "none"
var doors_state: Dictionary = {
	"north": "none",
	"south": "none",
	"east": "none",
	"west": "none"
}

@onready var walls_node: Node3D = $Walls
@onready var detection_area: Area3D = $DetectionArea

func _ready() -> void:
	add_to_group("modular_rooms")
	if detection_area:
		detection_area.body_entered.connect(_on_detection_body_entered)
		detection_area.body_exited.connect(_on_detection_body_exited)

func configure_doors(doors_list: Array) -> void:
	for dir in ["north", "south", "east", "west"]:
		if dir in doors_list:
			set_door(dir, "open")
		else:
			set_door(dir, "none")

func set_door(direction: String, state: String = "open") -> void:
	direction = direction.to_lower()
	state = state.to_lower()
	if not doors_state.has(direction):
		push_warning("Direction inconnue pour la porte: " + direction)
		return
	
	if not state in ["open", "closed", "locked", "none"]:
		push_warning("État de porte invalide '%s'. Utilisation de 'open'." % state)
		state = "open"
	
	doors_state[direction] = state
	
	var wall_node = walls_node.get_node_or_null(direction.capitalize())
	if wall_node:
		var blocker = wall_node.get_node_or_null("DoorBlocker")
		var door_leaf = wall_node.get_node_or_null("DoorLeaf")
		
		var has_doorway = (state != "none")
		
		# Bloqueur solide si aucun passage
		if blocker:
			blocker.visible = not has_doorway
			var blocker_col = blocker.get_node_or_null("CollisionShape3D")
			if blocker_col:
				blocker_col.disabled = has_doorway
		
		# Battant de porte
		if door_leaf:
			door_leaf.visible = has_doorway
			var door_col = door_leaf.get_node_or_null("CollisionShape3D")
			if door_col:
				# Si open -> collision désactivée pour passer librement
				door_col.disabled = (state == "open") or (not has_doorway)
			
			if state == "open":
				door_leaf.rotation_degrees.y = -90.0
			else:
				door_leaf.rotation_degrees.y = 0.0

func get_doors_dict() -> Dictionary:
	var res = {}
	for dir in doors_state.keys():
		var s = doors_state[dir]
		if s != "none":
			var offset = Vector3i.ZERO
			match dir:
				"north": offset = Vector3i(0, 0, -1)
				"south": offset = Vector3i(0, 0, 1)
				"east":  offset = Vector3i(1, 0, 0)
				"west":  offset = Vector3i(-1, 0, 0)
			var target_coords = coords + offset
			res[dir] = {
				"state": s,
				"leads_to": [target_coords.x, target_coords.y, target_coords.z]
			}
		else:
			res[dir] = null
	return res

func _on_detection_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		player_entered.emit(coords)

func _on_detection_body_exited(body: Node3D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		player_exited.emit(coords)
