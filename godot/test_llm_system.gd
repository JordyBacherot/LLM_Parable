extends SceneTree

func _init() -> void:
	print("--- DEBUT DU TEST DU SYSTEME LLM UNIFIE ---")
	
	# Charger et instancier la scène principale
	var main_scene = load("res://levels/node_3d.tscn").instantiate()
	root.add_child(main_scene)
	
	var grid_manager = main_scene.get_node("GridManager") as GridManager
	var controller = main_scene.get_node("LLMActionController") as LLMActionController
	
	assert(grid_manager != null, "GridManager doit être présent")
	assert(controller != null, "LLMActionController doit être présent")
	
	controller.grid_manager = grid_manager
	
	print("[1/8] Test generate_room avec room_coords...")
	var res_room = controller.execute_action("generate_room", {
		"room_coords": [0, 0, 1],
		"room_type": "normal",
		"doors": ["north", "south"]
	})
	assert(res_room.status == "success", "generate_room a échoué: " + str(res_room))
	assert(grid_manager.has_room(Vector3i(0, 0, 1)), "La pièce [0,0,1] doit exister")
	print("  -> Succès: ", res_room.message)
	
	print("[2/8] Test generate_stairs...")
	var res_stairs = controller.execute_action("generate_stairs", {
		"room_coords": [0, 1, 0],
		"direction": "north",
		"to_floor_offset": 1
	})
	assert(res_stairs.status == "success", "generate_stairs a échoué: " + str(res_stairs))
	assert(grid_manager.has_room(Vector3i(0, 1, 0)), "L'escalier [0,1,0] doit exister")
	print("  -> Succès: ", res_stairs.message)
	
	print("[3/8] Test spawn_object avec object_id obligatoire et room_pos...")
	var res_spawn = controller.execute_action("spawn_object", {
		"object_id": "companion_unit_test",
		"object_type": "cube",
		"room_coords": [0, 0, 1],
		"room_pos": [1.5, 0.5, 2.0]
	})
	assert(res_spawn.status == "success", "spawn_object a échoué: " + str(res_spawn))
	assert(grid_manager.spawned_objects.has("companion_unit_test"), "L'objet doit être présent")
	print("  -> Succès: ", res_spawn.message)
	
	print("[4/8] Test despawn_object...")
	var res_despawn = controller.execute_action("despawn_object", {
		"object_id": "companion_unit_test"
	})
	assert(res_despawn.status == "success", "despawn_object a échoué: " + str(res_despawn))
	assert(not grid_manager.spawned_objects.has("companion_unit_test"), "L'objet doit être détruit")
	print("  -> Succès: ", res_despawn.message)
	
	print("[5/8] Test set_door (open, locked, none)...")
	var res_door_open = controller.execute_action("set_door", {
		"room_coords": [0, 0, 1],
		"wall": "east",
		"state": "open"
	})
	assert(res_door_open.status == "success", "set_door open a échoué: " + str(res_door_open))
	
	var res_door_none = controller.execute_action("set_door", {
		"room_coords": [0, 0, 1],
		"wall": "east",
		"state": "none"
	})
	assert(res_door_none.status == "success", "set_door none a échoué: " + str(res_door_none))
	print("  -> Succès: set_door fonctionne correctement")
	
	print("[6/8] Test create_drop_zone avec zone_id obligatoire...")
	var res_zone = controller.execute_action("create_drop_zone", {
		"zone_id": "pressure_plate_test",
		"room_coords": [0, 0, 1],
		"accepted_type": "cube",
		"room_pos": [0.0, 0.0, 3.0]
	})
	assert(res_zone.status == "success", "create_drop_zone a échoué: " + str(res_zone))
	assert(grid_manager.drop_zones.has("pressure_plate_test"), "La zone doit exister")
	print("  -> Succès: ", res_zone.message)
	
	print("[7/8] Test teleport_player...")
	var res_teleport = controller.execute_action("teleport_player", {
		"room_coords": [0, 0, 1],
		"room_pos": [0.0, 1.0, 0.0]
	})
	assert(res_teleport.status == "success", "teleport_player a échoué: " + str(res_teleport))
	print("  -> Succès: ", res_teleport.message)
	
	print("[8/8] Test exécution multi-actions batch (Format API LLM)...")
	var batch_payload = {
		"text": "Je suis l'IA. Voici une nouvelle épreuve.",
		"actions": [
			{
				"action": "generate_room",
				"params": {"room_coords": [1, 0, 0], "doors": ["west"]}
			},
			{
				"action": "spawn_object",
				"params": {
					"object_id": "batch_cube",
					"object_type": "cube",
					"room_coords": [1, 0, 0],
					"room_pos": [0.0, 1.0, 0.0]
				}
			}
		]
	}
	var res_batch = controller.execute_payload(batch_payload)
	assert(res_batch.status == "success", "Batch execution failed: " + str(res_batch))
	assert(grid_manager.has_room(Vector3i(1, 0, 0)), "Pièce [1,0,0] doit exister après le batch")
	assert(grid_manager.spawned_objects.has("batch_cube"), "Cube 'batch_cube' doit exister après le batch")
	print("  -> Succès batch: ", res_batch.message)
	
	print("\n--- ÉTAT SPATIAL FINAL DU MONDE (JSON EXPORTÉ POUR LE LLM) ---")
	var state_json = grid_manager.get_spatial_state_json()
	print(state_json)
	print("----------------------------------------------------------------\n")
	
	# Vérification des clés normalisées
	var state = grid_manager.get_spatial_state()
	assert(state.player.has("room_coords"), "player doit avoir room_coords")
	assert(state.player.has("room_pos"), "player doit avoir room_pos")
	assert(state.objects["batch_cube"].has("room_coords"), "objet doit avoir room_coords")
	assert(state.objects["batch_cube"].has("room_pos"), "objet doit avoir room_pos")
	assert(state.drop_zones["pressure_plate_test"].has("room_coords"), "zone doit avoir room_coords")
	assert(state.drop_zones["pressure_plate_test"].has("room_pos"), "zone doit avoir room_pos")
	
	print("=== TOUS LES TESTS DE VALIDATION DU SYSTEME LLM SONT VALIDES AVEC SUCCES ! ===")
	quit(0)
