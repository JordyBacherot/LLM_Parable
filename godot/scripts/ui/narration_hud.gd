class_name NarrationHUD
extends CanvasLayer

@export var connector: LLMConnector

@onready var subtitle_panel: PanelContainer = $SubtitlePanel
@onready var subtitle_label: Label = $SubtitlePanel/Margin/SubtitleLabel
@onready var chat_container: PanelContainer = $ChatContainer
@onready var chat_input: LineEdit = $ChatContainer/Margin/HBox/ChatInput
@onready var send_btn: Button = $ChatContainer/Margin/HBox/SendBtn
@onready var hint_label: Label = $HintLabel

var hide_subtitle_timer: Timer

func _ready() -> void:
	if not connector:
		connector = get_parent().find_child("LLMConnector", true, false) as LLMConnector
	
	if connector:
		connector.narrator_said.connect(show_narrator_text)
		connector.request_started.connect(_on_request_started)
		connector.request_failed.connect(_on_request_failed)
	
	chat_container.visible = false
	subtitle_panel.visible = false
	
	hide_subtitle_timer = Timer.new()
	hide_subtitle_timer.one_shot = true
	hide_subtitle_timer.timeout.connect(func(): subtitle_panel.visible = false)
	add_child(hide_subtitle_timer)
	
	send_btn.pressed.connect(_on_send_pressed)
	chat_input.text_submitted.connect(func(_text): _on_send_pressed())

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_T or (event.physical_keycode == KEY_ENTER and not chat_container.visible):
			open_chat()
		elif event.physical_keycode == KEY_ESCAPE and chat_container.visible:
			close_chat()

func open_chat() -> void:
	chat_container.visible = true
	chat_input.text = ""
	chat_input.grab_focus()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func close_chat() -> void:
	chat_container.visible = false
	chat_input.release_focus()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_send_pressed() -> void:
	var msg = chat_input.text.strip_edges()
	close_chat()
	if not msg.is_empty() and connector:
		connector.send_player_message(msg)

func show_narrator_text(text: String) -> void:
	subtitle_label.text = text
	subtitle_panel.visible = true
	# Durée d'affichage proportionnelle à la longueur du texte (min 5s)
	var duration = maxf(5.0, text.length() * 0.07)
	hide_subtitle_timer.start(duration)

func _on_request_started() -> void:
	hint_label.text = "L'IA réfléchit..."
	hint_label.visible = true

func _on_request_failed(err: String) -> void:
	hint_label.text = "Erreur IA: " + err
	get_tree().create_timer(4.0).timeout.connect(func(): hint_label.text = "[T / Entrée] pour parler à l'IA")
