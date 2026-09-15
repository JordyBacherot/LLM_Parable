class_name GridManager
extends Node3D

signal world_state_changed()
signal player_moved_room(new_coords: Vector3i)
signal drop_zone_triggered(zone_id: String, object_id: String, satisfied: bool)

@export var room_size: Vector3 = Vector3(20.0, 6.0, 20.0)

var room_scene: PackedScene = preload("res://Scenes/modular/room_modular.tscn")
var stairs_scene: PackedScene = preload("res://Scenes/modular/stairs_modular.tscn")
var cube_scene: PackedScene = preload("res://Scenes/interactables/carryable_cube.tscn")
var drop_zone_scene: PackedScene = preload("res://Scenes/interactables/drop_zone.tscn")

# Dictionnaires de stockage
# rooms["x,y,z"] = ModularRoom ou ModularStairs
var rooms: Dictionary = {}
var spawned_objects: Dictionary = {}
var drop_zones: Dictionary = {}
var recent_events: Array[String] = []
const MAX_EVENTS: int = 25

var player: CharacterBody3D = null
var player_coords: Vector3i = Vector3i.ZERO

func _ready() -> void:
	find_player()

func find_player() -> void:
	if not player:
		player = get_tree().root.find_child("Player", true, false) as CharacterBody3D
	if not player and get_parent():
		player = get_parent().get_node_or_null("Player") as CharacterBody3D

func _process(_delta: float) -> void:
	if not player:
		find_player()
	
	if player:
		var current_calc_coords = world_to_grid(player.global_position)
		if current_calc_coords != player_coords:
			player_coords = current_calc_coords
			log_event("player_entered_room: [%d, %d, %d]" % [player_coords.x, player_coords.y, player_coords.z])
			player_moved_room.emit(player_coords)

# --- Conversions Spatiales Unifiées ---
func grid_to_world(coords: Vector3i) -> Vector3:
	return Vector3(coords.x * room_size.x, coords.y * room_size.y, coords.z * room_size.z)

func world_to_grid(pos: Vector3) -> Vector3i:
	return Vector3i(
		int(round(pos.x / room_size.x)),
		int(round(pos.y / room_size.y)),
		int(round(pos.z / room_size.z))
	)

func coords_to_key(coords: Vector3i) -> String:
	return "%d,%d,%d" % [coords.x, coords.y, coords.z]

func key_to_coords(key: String) -> Vector3i:
	var parts = key.split(",")
	if parts.size() == 3:
		return Vector3i(int(parts[0]), int(parts[1]), int(parts[2]))
	return Vector3i.ZERO

func log_event(text: String) -> void:
	recent_events.append(text)
	if recent_events.size() > MAX_EVENTS:
		recent_events.pop_front()
	world_state_changed.emit()

func consume_recent_events() -> Array[String]:
	var evs = recent_events.duplicate()
	recent_events.clear()
	return evs

# --- Création de Pièces & Escaliers ---
func create_room(coords: Vector3i, p_room_type: String = "normal", doors: Array = []) -> ModularRoom:
	var key = coords_to_key(coords)
	if rooms.has(key):
		push_warning("Une pièce existe déjà en " + key)
		return rooms[key] as ModularRoom
	
	var room_inst = room_scene.instantiate() as ModularRoom
	room_inst.coords = coords
	room_inst.room_type = p_room_type
	room_inst.room_size = room_size
	room_inst.name = "Room_" + key.replace(",", "_")
	add_child(room_inst)
	room_inst.global_position = grid_to_world(coords)
	
	room_inst.configure_doors(doors)
	
	room_inst.player_entered.connect(func(c):
		player_coords = c
		log_event("player_entered_room: [%d, %d, %d]" % [c.x, c.y, c.z])
	)
	
	rooms[key] = room_inst
	log_event("room_created: [%d, %d, %d]" % [coords.x, coords.y, coords.z])
	world_state_changed.emit()
	return room_inst

func create_stairs(coords: Vector3i, direction: String = "north", to_floor_offset: int = 1) -> ModularStairs:
	var key = coords_to_key(coords)
	if rooms.has(key):
		push_warning("Un élément existe déjà en " + key)
		return null
	
	var stairs_inst = stairs_scene.instantiate() as ModularStairs
	stairs_inst.coords = coords
	stairs_inst.direction = direction
	stairs_inst.to_floor_offset = to_floor_offset
	stairs_inst.name = "Stairs_" + key.replace(",", "_")
	add_child(stairs_inst)
	stairs_inst.global_position = grid_to_world(coords)
	
	rooms[key] = stairs_inst
	log_event("stairs_created: [%d, %d, %d] (dir: %s)" % [coords.x, coords.y, coords.z, direction])
	world_state_changed.emit()
	return stairs_inst

func has_room(coords: Vector3i) -> bool:
	return rooms.has(coords_to_key(coords))

func get_room(coords: Vector3i) -> Node3D:
	var key = coords_to_key(coords)
	if rooms.has(key):
		return rooms[key]
	return null

# --- Outil Unifié de Porte : set_door ---
func set_door(room_coords: Vector3i, wall: String, state: String = "open") -> bool:
	var key = coords_to_key(room_coords)
	if not rooms.has(key):
		push_warning("Pièce introuvable en " + key + " pour set_door")
		return false
	var room = rooms[key]
	if room is ModularRoom:
		room.set_door(wall, state)
		log_event("door_set: [%d, %d, %d] wall '%s' -> '%s'" % [room_coords.x, room_coords.y, room_coords.z, wall, state])
		world_state_changed.emit()
		return true
	return false

# --- Gestion des Objets avec ID Obligatoire & room_pos ---
func spawn_object(object_id: String, object_type: String, room_coords: Vector3i, room_pos: Vector3 = Vector3(0, 1, 0)) -> Node3D:
	if object_id.is_empty():
		push_error("spawn_object requiert un object_id obligatoire.")
		return null
	
	if spawned_objects.has(object_id):
		push_warning("Un objet avec l'ID '%s' existe déjà. Remplacement." % object_id)
		despawn_object(object_id)
	
	var obj_inst: Node3D = null
	match object_type.to_lower():
		"cube", "companion_cube", _:
			obj_inst = cube_scene.instantiate()
	
	if not obj_inst:
		return null
	
	if obj_inst is Carryable:
		obj_inst.object_id = object_id
		obj_inst.object_type = object_type
	
	add_child(obj_inst)
	var base_room_pos = grid_to_world(room_coords)
	obj_inst.global_position = base_room_pos + room_pos
	
	spawned_objects[object_id] = obj_inst
	log_event("object_spawned: '%s' (type: %s) in room [%d, %d, %d]" % [object_id, object_type, room_coords.x, room_coords.y, room_coords.z])
	world_state_changed.emit()
	return obj_inst

func despawn_object(object_id: String) -> bool:
	if spawned_objects.has(object_id):
		var obj = spawned_objects[object_id]
		if is_instance_valid(obj):
			# Si le joueur tenait cet objet, le libérer
			if player and "held_object" in player and player.held_object == obj:
				player.held_object = null
			obj.queue_free()
		spawned_objects.erase(object_id)
		log_event("object_despawned: '%s'" % object_id)
		world_state_changed.emit()
		return true
	return false

# --- Gestion des Zones de Dépôt avec ID Obligatoire & room_pos ---
func create_drop_zone(zone_id: String, room_coords: Vector3i, accepted_type: String = "cube", room_pos: Vector3 = Vector3.ZERO) -> DropZone:
	if zone_id.is_empty():
		push_error("create_drop_zone requiert un zone_id obligatoire.")
		return null
	
	if drop_zones.has(zone_id):
		push_warning("Zone '%s' existe déjà. Suppression de l'ancienne." % zone_id)
		var old = drop_zones[zone_id]
		if is_instance_valid(old):
			old.queue_free()
		drop_zones.erase(zone_id)
	
	var zone_inst = drop_zone_scene.instantiate() as DropZone
	zone_inst.zone_id = zone_id
	zone_inst.accepted_type = accepted_type
	
	add_child(zone_inst)
	var base_room_pos = grid_to_world(room_coords)
	zone_inst.global_position = base_room_pos + room_pos
	
	zone_inst.zone_satisfied.connect(func(id, obj):
		log_event("drop_zone_satisfied: '%s' with '%s'" % [id, obj])
		drop_zone_triggered.emit(id, obj, true)
		world_state_changed.emit()
	)
	zone_inst.zone_unsatisfied.connect(func(id):
		log_event("drop_zone_unsatisfied: '%s'" % id)
		drop_zone_triggered.emit(id, "", false)
		world_state_changed.emit()
	)
	
	drop_zones[zone_id] = zone_inst
	log_event("drop_zone_created: '%s' in room [%d, %d, %d]" % [zone_id, room_coords.x, room_coords.y, room_coords.z])
	world_state_changed.emit()
	return zone_inst

# --- Téléportation du Joueur avec room_coords & room_pos ---
func teleport_player(room_coords: Vector3i, room_pos: Vector3 = Vector3(0, 1.0, 0)) -> bool:
	find_player()
	if not player:
		return false
	
	var target_world_pos = grid_to_world(room_coords) + room_pos
	if player.has_method("teleport_to"):
		player.teleport_to(target_world_pos)
	else:
		player.global_position = target_world_pos
		player.velocity = Vector3.ZERO
	
	player_coords = room_coords
	log_event("player_teleported_to: room [%d, %d, %d]" % [room_coords.x, room_coords.y, room_coords.z])
	world_state_changed.emit()
	return true

# --- Sérialisation Complète & Unifiée de l'État Spatial ---
func get_spatial_state() -> Dictionary:
	find_player()
	
	var p_room_coords = [player_coords.x, player_coords.y, player_coords.z]
	var p_room_pos = [0.0, 0.0, 0.0]
	var p_held = null
	
	if player:
		var room_origin = grid_to_world(player_coords)
		var rel_p = player.global_position - room_origin
		p_room_pos = [
			snappedf(rel_p.x, 0.1),
			snappedf(rel_p.y, 0.1),
			snappedf(rel_p.z, 0.1)
		]
		if "held_object" in player and player.held_object:
			p_held = player.held_object.object_id
	
	var rooms_dict = {}
	for key in rooms.keys():
		var r = rooms[key]
		if not is_instance_valid(r):
			continue
		var coords_arr = [r.coords.x, r.coords.y, r.coords.z]
		if r is ModularRoom:
			rooms_dict[key] = {
				"type": r.room_type,
				"room_coords": coords_arr,
				"doors": r.get_doors_dict()
			}
		elif r is ModularStairs:
			rooms_dict[key] = {
				"type": "stairs",
				"room_coords": coords_arr,
				"direction": r.direction,
				"to_floor_offset": r.to_floor_offset
			}
	
	var objects_dict = {}
	for obj_id in spawned_objects.keys():
		var obj = spawned_objects[obj_id]
		if is_instance_valid(obj):
			var obj_grid = world_to_grid(obj.global_position)
			var origin = grid_to_world(obj_grid)
			var rel = obj.global_position - origin
			objects_dict[obj_id] = {
				"object_type": obj.object_type if "object_type" in obj else "cube",
				"room_coords": [obj_grid.x, obj_grid.y, obj_grid.z],
				"room_pos": [snappedf(rel.x, 0.1), snappedf(rel.y, 0.1), snappedf(rel.z, 0.1)],
				"is_held": obj.is_held if "is_held" in obj else false
			}
	
	var zones_dict = {}
	for z_id in drop_zones.keys():
		var z = drop_zones[z_id]
		if is_instance_valid(z):
			var z_grid = world_to_grid(z.global_position)
			var origin = grid_to_world(z_grid)
			var rel = z.global_position - origin
			zones_dict[z_id] = {
				"accepted_type": z.accepted_type,
				"is_satisfied": z.is_satisfied,
				"current_object": z.current_object_id if not z.current_object_id.is_empty() else null,
				"room_coords": [z_grid.x, z_grid.y, z_grid.z],
				"room_pos": [snappedf(rel.x, 0.1), snappedf(rel.y, 0.1), snappedf(rel.z, 0.1)]
			}
	
	return {
		"player": {
			"room_coords": p_room_coords,
			"room_pos": p_room_pos,
			"carrying_object": p_held
		},
		"rooms": rooms_dict,
		"objects": objects_dict,
		"drop_zones": zones_dict,
		"recent_events": recent_events
	}

func get_spatial_state_json(indent: String = "  ") -> String:
	return JSON.stringify(get_spatial_state(), indent)
