class_name ModularStairs
extends Node3D

signal player_entered(coords: Vector3i)

@export var coords: Vector3i = Vector3i.ZERO
@export var direction: String = "north" # "north", "south", "east", "west"
@export var to_floor_offset: int = 1

@onready var detection_area: Area3D = get_node_or_null("DetectionArea")

func _ready() -> void:
	add_to_group("modular_stairs")
	if detection_area:
		detection_area.body_entered.connect(_on_detection_body_entered)
	apply_direction()

func apply_direction() -> void:
	match direction.to_lower():
		"north":
			rotation_degrees.y = 0.0
		"south":
			rotation_degrees.y = 180.0
		"east":
			rotation_degrees.y = -90.0
		"west":
			rotation_degrees.y = 90.0

func _on_detection_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		player_entered.emit(coords)
