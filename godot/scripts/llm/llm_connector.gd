class_name LLMConnector
extends Node

signal narrator_said(text: String)
signal turn_completed(text: String, actions_results: Array)
signal request_started()
signal request_failed(error_message: String)

@export var api_url: String = "http://127.0.0.1:8000/api/llm_step"
@export var auto_initial_call: bool = true

@export var action_controller: LLMActionController
@export var grid_manager: GridManager

var http_request: HTTPRequest
var is_requesting: bool = false

func _ready() -> void:
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_request_completed)
	
	ensure_references()
	
	if auto_initial_call:
		# Appel initial au démarrage après un léger délai pour que tout soit prêt
		get_tree().create_timer(0.3).timeout.connect(func():
			print("[LLMConnector] Lancement du premier appel d'initialisation LLM (sans message)...")
			send_player_message("")
		)

func ensure_references() -> void:
	if not action_controller:
		action_controller = get_node_or_null("../LLMActionController") as LLMActionController
	if not action_controller:
		action_controller = get_tree().root.find_child("LLMActionController", true, false) as LLMActionController
		
	if not grid_manager:
		grid_manager = get_node_or_null("../GridManager") as GridManager
	if not grid_manager:
		grid_manager = get_tree().root.find_child("GridManager", true, false) as GridManager

func send_player_message(message: String) -> void:
	if is_requesting:
		push_warning("[LLMConnector] Une requête est déjà en cours...")
		return
	
	ensure_references()
	if not grid_manager:
		request_failed.emit("GridManager introuvable pour envoyer le monde au LLM")
		return
	
	# Consommer l'état spatial complet et les événements récents
	var state_dict = grid_manager.get_spatial_state()
	# Vider les événements récents pour le tour suivant
	grid_manager.recent_events.clear()
	
	var payload = {
		"player_message": message,
		"world_state": state_dict
	}
	
	var json_payload = JSON.stringify(payload)
	var headers = ["Content-Type: application/json"]
	
	is_requesting = true
	request_started.emit()
	
	var err = http_request.request(api_url, headers, HTTPClient.METHOD_POST, json_payload)
	if err != OK:
		is_requesting = false
		request_failed.emit("Erreur lors de la requête HTTP: %d" % err)

func _on_request_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	is_requesting = false
	
	if response_code < 200 or response_code >= 300:
		var err_msg = "Réponse HTTP avec code: %d" % response_code
		print("[LLMConnector] ", err_msg)
		request_failed.emit(err_msg)
		return
	
	var body_text = body.get_string_from_utf8()
	var json = JSON.new()
	var parse_err = json.parse(body_text)
	if parse_err != OK:
		var parse_msg = "Erreur parsing JSON de l'API: " + json.get_error_message()
		print("[LLMConnector] ", parse_msg)
		request_failed.emit(parse_msg)
		return
	
	var data = json.get_data()
	if typeof(data) != TYPE_DICTIONARY:
		request_failed.emit("Format de réponse API invalide (dictionnaire attendu)")
		return
	
	# Traitement du texte du narrateur / LLM
	var narrator_text = data.get("text", "")
	if not narrator_text.is_empty():
		narrator_said.emit(narrator_text)
		print("[NARRATEUR IA] ", narrator_text)
	
	# Exécution de la liste ordonnée des actions
	var actions_list = data.get("actions", [])
	var results = []
	if typeof(actions_list) == TYPE_ARRAY and action_controller:
		for act in actions_list:
			if typeof(act) == TYPE_DICTIONARY:
				var res = action_controller.execute_action(act.get("action", ""), act.get("params", {}))
				results.append(res)
	
	turn_completed.emit(narrator_text, results)
