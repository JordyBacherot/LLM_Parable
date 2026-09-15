class_name DebugLLMPanel
extends CanvasLayer

@export var action_controller: LLMActionController
@export var grid_manager: GridManager
@export var connector: LLMConnector

@onready var main_panel: Control = $MainPanel
@onready var state_text: TextEdit = $MainPanel/HSplit/Right/StateText
@onready var json_input: LineEdit = $MainPanel/HSplit/Left/CustomCommand/JsonInput
@onready var output_label: Label = $MainPanel/HSplit/Left/CustomCommand/OutputLabel
@onready var toggle_btn: Button = $ToggleBtn

var is_panel_open: bool = false
var debug_cube_count: int = 0

func _ready() -> void:
	if not action_controller:
		action_controller = get_parent().find_child("LLMActionController", true, false) as LLMActionController
	if not grid_manager:
		grid_manager = get_parent().find_child("GridManager", true, false) as GridManager
	if not connector:
		connector = get_parent().find_child("LLMConnector", true, false) as LLMConnector
	
	if grid_manager:
		grid_manager.world_state_changed.connect(refresh_state_view)
	
	toggle_btn.pressed.connect(toggle_panel)
	_setup_buttons()
	set_panel_visible(false)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_F1 or event.keycode == KEY_F1 or event.physical_keycode == KEY_SECTION:
			toggle_panel()

func toggle_panel() -> void:
	set_panel_visible(not is_panel_open)

func set_panel_visible(vis: bool) -> void:
	is_panel_open = vis
	main_panel.visible = is_panel_open
	toggle_btn.text = "Fermer Debug (F1)" if is_panel_open else "Ouvrir Debug (F1)"
	
	if is_panel_open:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		refresh_state_view()
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func refresh_state_view() -> void:
	if not is_panel_open or not grid_manager:
		return
	if state_text:
		state_text.text = grid_manager.get_spatial_state_json("  ")

func _setup_buttons() -> void:
	var btn_room_z1 = $MainPanel/HSplit/Left/ActionsScroll/VBox/BtnRoomZ1
	var btn_room_x1 = $MainPanel/HSplit/Left/ActionsScroll/VBox/BtnRoomX1
	var btn_stairs = $MainPanel/HSplit/Left/ActionsScroll/VBox/BtnStairs
	var btn_spawn_cube = $MainPanel/HSplit/Left/ActionsScroll/VBox/BtnSpawnCube
	var btn_despawn_cube = $MainPanel/HSplit/Left/ActionsScroll/VBox/BtnDespawnCube
	var btn_toggle_door = $MainPanel/HSplit/Left/ActionsScroll/VBox/BtnToggleDoor
	var btn_drop_zone = $MainPanel/HSplit/Left/ActionsScroll/VBox/BtnDropZone
	var btn_teleport_0 = $MainPanel/HSplit/Left/ActionsScroll/VBox/BtnTeleport0
	var btn_sim_api = $MainPanel/HSplit/Left/ActionsScroll/VBox/BtnSimulateAPI
	var btn_send_json = $MainPanel/HSplit/Left/CustomCommand/BtnSendJson
	
	if btn_room_z1:
		btn_room_z1.pressed.connect(func():
			_exec("generate_room", {"room_coords": [0, 0, 1], "doors": ["north", "south"]})
		)
	if btn_room_x1:
		btn_room_x1.pressed.connect(func():
			_exec("generate_room", {"room_coords": [1, 0, 0], "doors": ["west", "north"]})
		)
	if btn_stairs:
		btn_stairs.pressed.connect(func():
			_exec("generate_stairs", {"room_coords": [0, 1, 0], "direction": "north", "to_floor_offset": 1})
		)
	if btn_spawn_cube:
		btn_spawn_cube.pressed.connect(func():
			var c = grid_manager.player_coords if grid_manager else Vector3i.ZERO
			debug_cube_count += 1
			var obj_id = "cube_debug_%d" % debug_cube_count
			_exec("spawn_object", {
				"object_id": obj_id,
				"object_type": "cube",
				"room_coords": [c.x, c.y, c.z],
				"room_pos": [0.0, 1.5, 2.0]
			})
		)
	if btn_despawn_cube:
		btn_despawn_cube.pressed.connect(func():
			if grid_manager and grid_manager.spawned_objects.size() > 0:
				var first_id = grid_manager.spawned_objects.keys()[0]
				_exec("despawn_object", {"object_id": first_id})
		)
	if btn_toggle_door:
		btn_toggle_door.pressed.connect(func():
			var c = grid_manager.player_coords if grid_manager else Vector3i.ZERO
			var room = grid_manager.get_room(c) if grid_manager else null
			if room is ModularRoom:
				var current_state = room.doors_state["north"]
				var next_state = "none" if current_state != "none" else "open"
				_exec("set_door", {"room_coords": [c.x, c.y, c.z], "wall": "north", "state": next_state})
		)
	if btn_drop_zone:
		btn_drop_zone.pressed.connect(func():
			var c = grid_manager.player_coords if grid_manager else Vector3i.ZERO
			_exec("create_drop_zone", {
				"zone_id": "zone_debug_1",
				"room_coords": [c.x, c.y, c.z],
				"accepted_type": "cube",
				"room_pos": [0.0, 0.0, 3.0]
			})
		)
	if btn_teleport_0:
		btn_teleport_0.pressed.connect(func():
			_exec("teleport_player", {"room_coords": [0, 0, 0], "room_pos": [0.0, 1.0, 0.0]})
		)
	if btn_sim_api:
		btn_sim_api.pressed.connect(_on_simulate_llm_response)
	if btn_send_json:
		btn_send_json.pressed.connect(_on_send_custom_json)

func _on_simulate_llm_response() -> void:
	# Simuler exactement une réponse complète d'API LLM : texte narrateur + batch actions
	var mock_response = {
		"text": "Félicitations pour avoir trouvé le bouton de test. Observez la pièce se transformer...",
		"actions": [
			{
				"action": "set_door",
				"params": {"room_coords": [0, 0, 0], "wall": "north", "state": "open"}
			},
			{
				"action": "generate_room",
				"params": {"room_coords": [0, 0, -1], "doors": ["south", "north"]}
			},
			{
				"action": "spawn_object",
				"params": {
					"object_id": "companion_test",
					"object_type": "cube",
					"room_coords": [0, 0, -1],
					"room_pos": [0.0, 1.0, -2.0]
				}
			}
		]
	}
	if action_controller:
		var res = action_controller.execute_payload(mock_response)
		if connector and not mock_response.text.is_empty():
			connector.narrator_said.emit(mock_response.text)
		_display_result(res)
		refresh_state_view()

func _on_send_custom_json() -> void:
	if not json_input or not action_controller:
		return
	var text = json_input.text.strip_edges()
	if text.is_empty():
		return
	var res = action_controller.execute_json_string(text)
	_display_result(res)
	refresh_state_view()

func _exec(action: String, params: Dictionary) -> Dictionary:
	if not action_controller:
		return {}
	var res = action_controller.execute_action(action, params)
	_display_result(res)
	refresh_state_view()
	return res

func _display_result(res: Dictionary) -> void:
	if not output_label:
		return
	var status = res.get("status", "unknown")
	var msg = res.get("message", "")
	output_label.text = "[%s] %s" % [status.to_upper(), msg]
	if status == "success":
		output_label.modulate = Color(0.3, 1.0, 0.4)
	else:
		output_label.modulate = Color(1.0, 0.4, 0.3)
