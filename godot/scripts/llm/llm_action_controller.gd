class_name LLMActionController
extends Node

signal action_executed(action_name: String, params: Dictionary, result: Dictionary)
signal actions_batch_completed(results: Array)

@export var grid_manager: GridManager

func _ready() -> void:
	ensure_grid_manager()

func ensure_grid_manager() -> void:
	if not grid_manager:
		grid_manager = get_node_or_null("../GridManager") as GridManager
	if not grid_manager:
		grid_manager = get_tree().root.find_child("GridManager", true, false) as GridManager

func execute_json_string(json_string: String) -> Dictionary:
	var json = JSON.new()
	var err = json.parse(json_string)
	if err != OK:
		return {
			"status": "error",
			"message": "JSON invalide : " + json.get_error_message()
		}
	
	var data = json.get_data()
	if typeof(data) != TYPE_DICTIONARY:
		return {
			"status": "error",
			"message": "Le JSON doit être un objet."
		}
	
	return execute_payload(data)

func execute_payload(data: Dictionary) -> Dictionary:
	# Format multi-actions : { "text": "...", "actions": [ {...}, {...} ] }
	if data.has("actions") and typeof(data["actions"]) == TYPE_ARRAY:
		var results = []
		for act in data["actions"]:
			if typeof(act) == TYPE_DICTIONARY:
				var res = execute_action(act.get("action", ""), act.get("params", {}))
				results.append(res)
		actions_batch_completed.emit(results)
		return {
			"status": "success",
			"message": "%d action(s) exécutée(s)" % results.size(),
			"results": results,
			"narrator_text": data.get("text", "")
		}
	
	# Format action unique : { "action": "...", "params": {...} }
	var action = data.get("action", "")
	var params = data.get("params", {})
	return execute_action(action, params)

func execute_action(action_name: String, params: Dictionary) -> Dictionary:
	ensure_grid_manager()
	if not grid_manager:
		return {"status": "error", "message": "GridManager non assigné ou introuvable"}
	
	var result = {"status": "error", "action": action_name, "message": "Action inconnue"}
	
	match action_name:
		"generate_room", "create_room":
			var room_coords = _extract_coords(params, "room_coords", "coords")
			var room_type = params.get("room_type", "normal")
			var doors = params.get("doors", [])
			var room = grid_manager.create_room(room_coords, room_type, doors)
			if room:
				result = {
					"status": "success",
					"action": action_name,
					"message": "Pièce créée en [%d, %d, %d]" % [room_coords.x, room_coords.y, room_coords.z],
					"room_coords": [room_coords.x, room_coords.y, room_coords.z]
				}
			else:
				result = {"status": "error", "message": "Impossible de créer la pièce (existe déjà ?)"}

		"generate_stairs", "create_stairs":
			var room_coords = _extract_coords(params, "room_coords", "coords")
			var direction = params.get("direction", "north")
			var to_floor = int(params.get("to_floor_offset", 1))
			var stairs = grid_manager.create_stairs(room_coords, direction, to_floor)
			if stairs:
				result = {
					"status": "success",
					"action": action_name,
					"message": "Escalier créé en [%d, %d, %d] vers le %s" % [room_coords.x, room_coords.y, room_coords.z, direction],
					"room_coords": [room_coords.x, room_coords.y, room_coords.z]
				}
			else:
				result = {"status": "error", "message": "Impossible de créer l'escalier"}

		"set_door":
			var room_coords = _extract_coords(params, "room_coords", "coords")
			var wall = params.get("wall", "north")
			var state = params.get("state", "open")
			if grid_manager.set_door(room_coords, wall, state):
				result = {
					"status": "success",
					"action": action_name,
					"message": "Porte mur '%s' configurée sur '%s' en [%d, %d, %d]" % [wall, state, room_coords.x, room_coords.y, room_coords.z]
				}
			else:
				result = {"status": "error", "message": "Pièce introuvable en [%d, %d, %d]" % [room_coords.x, room_coords.y, room_coords.z]}

		# Rétrocompatibilité : add_door / remove_door redirigent vers set_door
		"add_door", "spawn_door":
			var room_coords = _extract_coords(params, "room_coords", "coords")
			var wall = params.get("wall", "north")
			if grid_manager.set_door(room_coords, wall, "open"):
				result = {"status": "success", "action": action_name, "message": "Porte ouverte en [%d, %d, %d] (%s)" % [room_coords.x, room_coords.y, room_coords.z, wall]}
			else:
				result = {"status": "error", "message": "Échec de l'ouverture de porte"}

		"remove_door":
			var room_coords = _extract_coords(params, "room_coords", "coords")
			var wall = params.get("wall", "north")
			if grid_manager.set_door(room_coords, wall, "none"):
				result = {"status": "success", "action": action_name, "message": "Porte supprimée (muré) en [%d, %d, %d] (%s)" % [room_coords.x, room_coords.y, room_coords.z, wall]}
			else:
				result = {"status": "error", "message": "Échec de la fermeture de porte"}

		"spawn_object":
			var object_id = params.get("object_id", "")
			if object_id.is_empty():
				return {"status": "error", "message": "Paramètre 'object_id' obligatoire manquant dans spawn_object"}
			var obj_type = params.get("object_type", "cube")
			var room_coords = _extract_coords(params, "room_coords", "coords")
			var room_pos = _extract_vector3(params, "room_pos", "relative_pos", Vector3(0, 1, 0))
			var obj = grid_manager.spawn_object(object_id, obj_type, room_coords, room_pos)
			if obj:
				result = {
					"status": "success",
					"action": action_name,
					"object_id": object_id,
					"message": "Objet '%s' (%s) créé en room [%d, %d, %d]" % [object_id, obj_type, room_coords.x, room_coords.y, room_coords.z]
				}
			else:
				result = {"status": "error", "message": "Échec de l'apparition de l'objet"}

		"despawn_object":
			var object_id = params.get("object_id", "")
			if object_id.is_empty():
				return {"status": "error", "message": "Paramètre 'object_id' obligatoire manquant dans despawn_object"}
			if grid_manager.despawn_object(object_id):
				result = {
					"status": "success",
					"action": action_name,
					"message": "Objet '%s' supprimé" % object_id
				}
			else:
				result = {"status": "error", "message": "Objet introuvable : " + object_id}

		"create_drop_zone":
			var zone_id = params.get("zone_id", "")
			if zone_id.is_empty():
				return {"status": "error", "message": "Paramètre 'zone_id' obligatoire manquant dans create_drop_zone"}
			var room_coords = _extract_coords(params, "room_coords", "coords")
			var accepted_type = params.get("accepted_type", "cube")
			var room_pos = _extract_vector3(params, "room_pos", "relative_pos", Vector3.ZERO)
			var zone = grid_manager.create_drop_zone(zone_id, room_coords, accepted_type, room_pos)
			if zone:
				result = {
					"status": "success",
					"action": action_name,
					"zone_id": zone_id,
					"message": "Zone de dépôt '%s' créée en [%d, %d, %d]" % [zone_id, room_coords.x, room_coords.y, room_coords.z]
				}
			else:
				result = {"status": "error", "message": "Échec de la création de zone de dépôt"}

		"teleport_player":
			var room_coords = _extract_coords(params, "room_coords", "coords")
			var room_pos = _extract_vector3(params, "room_pos", "relative_pos", Vector3(0, 1.0, 0))
			if grid_manager.teleport_player(room_coords, room_pos):
				result = {
					"status": "success",
					"action": action_name,
					"message": "Joueur téléporté en pièce [%d, %d, %d]" % [room_coords.x, room_coords.y, room_coords.z]
				}
			else:
				result = {"status": "error", "message": "Échec de la téléportation"}

		"get_world_state", "get_state":
			result = {
				"status": "success",
				"action": action_name,
				"data": grid_manager.get_spatial_state()
			}
	
	action_executed.emit(action_name, params, result)
	return result

func _extract_coords(params: Dictionary, primary_key: String, fallback_key: String) -> Vector3i:
	var val = params.get(primary_key, null)
	if val == null:
		val = params.get(fallback_key, [0, 0, 0])
	return _parse_coords(val)

func _extract_vector3(params: Dictionary, primary_key: String, fallback_key: String, default_vec: Vector3) -> Vector3:
	var val = params.get(primary_key, null)
	if val == null:
		val = params.get(fallback_key, null)
	if val == null:
		return default_vec
	return _parse_vector3(val)

func _parse_coords(val: Variant) -> Vector3i:
	if val is Vector3i:
		return val
	if val is Vector3:
		return Vector3i(int(val.x), int(val.y), int(val.z))
	if val is Array and val.size() >= 3:
		return Vector3i(int(val[0]), int(val[1]), int(val[2]))
	if val is String:
		var parts = val.split(",")
		if parts.size() >= 3:
			return Vector3i(int(parts[0]), int(parts[1]), int(parts[2]))
	return Vector3i.ZERO

func _parse_vector3(val: Variant) -> Vector3:
	if val is Vector3:
		return val
	if val is Array and val.size() >= 3:
		return Vector3(float(val[0]), float(val[1]), float(val[2]))
	return Vector3.ZERO
