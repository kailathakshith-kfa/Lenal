extends CharacterBody3D

signal dialogue_finished

@onready var dialogue_layer: CanvasLayer = $DialogueUI
@onready var dialogue_panel: PanelContainer = $DialogueUI/DialoguePanel
@onready var speaker_label: Label = $DialogueUI/DialoguePanel/MarginContainer/VBoxContainer/SpeakerLabel
@onready var content_label: Label = $DialogueUI/DialoguePanel/MarginContainer/VBoxContainer/ContentLabel
@onready var prompt_label: Label = $DialogueUI/DialoguePanel/MarginContainer/VBoxContainer/PromptLabel
@onready var objective_panel: PanelContainer = $DialogueUI/ObjectivePanel
@onready var objective_label: Label = $DialogueUI/ObjectivePanel/MarginContainer/HBoxContainer/ObjectiveText
@onready var visual_root: Node3D = $VisualRoot

# Conversation 1: Chicken missing (Natural Hinglish)
var conv_initial: Array = [
	{"speaker": "OLD MAN", "text": "Arre beta, meri chicken missing hai!"},
	{"speaker": "PLAYER", "text": "Your chicken?"},
	{"speaker": "OLD MAN", "text": "Haan bhai, meri chicken. Subah se gayab hai."},
	{"speaker": "PLAYER", "text": "Okay... where did you last see her?"},
	{"speaker": "OLD MAN", "text": "Idhar hi thi. Ab pata nahi kidhar bhaag gayi."},
	{"speaker": "PLAYER", "text": "Okay. I'll find her."},
	{"speaker": "OLD MAN", "text": "Bas usko dhoondh ke mere paas le aana."},
	{"speaker": "PLAYER", "text": "That's it?"},
	{"speaker": "OLD MAN", "text": "Haan. Simple kaam hai."}
]

# Conversation 2: Follow up
var conv_lantern_returned: Array = [
	{"speaker": "OLD MAN", "text": "Arre wah! You found her trail?"},
	{"speaker": "PLAYER", "text": "She ran towards the forest... into a cave."},
	{"speaker": "OLD MAN", "text": "Cave? Accha... then go check the cave."},
	{"speaker": "PLAYER", "text": "Wait, seriously?"},
	{"speaker": "OLD MAN", "text": "Haan bhai, simple kaam hai. Go to the cave."}
]

var active_conversation: Array = []
var conversation: Array = [] # Kept for backward compatibility with tests
var current_line_idx: int = -1
var is_talking: bool = false
var has_completed_dialogue: bool = false
var has_completed_cave_dialogue: bool = false
var current_player: Node = null

var default_panel_y: float = 0.0

func _ready() -> void:
	add_to_group("interactable")
	conversation = conv_initial
	if dialogue_panel:
		dialogue_panel.visible = false
	if objective_panel:
		objective_panel.visible = false
		objective_panel.pivot_offset = Vector2(140, 24)

	# Connect to GameState signals
	var gs = get_node_or_null("/root/GameState")
	if gs:
		if gs.has_signal("objective_updated"):
			gs.objective_updated.connect(_on_objective_updated)
		if gs.has_signal("state_changed"):
			gs.state_changed.connect(_on_state_changed)

func _on_objective_updated(text: String) -> void:
	if objective_label:
		objective_label.text = text
	if objective_panel:
		objective_panel.visible = true
		SFX.play_objective()
		
		# Comic pop bounce animation
		objective_panel.scale = Vector2(1.2, 1.2)
		var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(objective_panel, "scale", Vector2.ONE, 0.35)

func _on_state_changed(new_state: int) -> void:
	if new_state == GameState.State.CAVE_NOTE_FOUND or new_state == GameState.State.GAME_OVER:
		hide_old_man()

func hide_old_man() -> void:
	if visual_root:
		visual_root.visible = false
	collision_layer = 0
	remove_from_group("interactable")

func _process(_delta: float) -> void:
	if visual_root and visual_root.visible:
		var time = Time.get_ticks_msec() * 0.002
		visual_root.position.y = sin(time) * 0.02

func get_interact_text() -> String:
	if not visual_root or not visual_root.visible:
		return ""
	if GameState.current_state == GameState.State.LANTERN_FOUND:
		return "Report to Old Man"
	return "Talk to Old Man"

func interact(player: Node) -> String:
	current_player = player
	
	if not is_talking:
		if GameState.current_state == GameState.State.START:
			start_conversation(conv_initial)
			return ""
		elif GameState.current_state == GameState.State.CHICKEN_QUEST:
			return "Old Man: 'Bas usko dhoondh ke mere paas le aana. Simple kaam hai.'"
		elif GameState.current_state == GameState.State.LANTERN_FOUND:
			start_conversation(conv_lantern_returned)
			return ""
		elif GameState.current_state == GameState.State.CAVE_QUEST:
			return "Old Man: 'Gufa mein jao beta, chicken wahi gayi hai. Simple kaam hai!'"
		else:
			return "Old Man: 'Bas usko dhoondh ke mere paas le aana. Simple kaam hai.'"
	else:
		advance_dialogue()
		return ""

func _unhandled_input(event: InputEvent) -> void:
	if not is_talking:
		return
	
	var is_advancing = false
	if event.is_action_pressed("interact") or event.is_action_pressed("jump"):
		is_advancing = true
	elif event is InputEventKey and (event.keycode == KEY_E or event.keycode == KEY_SPACE or event.keycode == KEY_ENTER) and event.pressed:
		is_advancing = true
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		is_advancing = true

	if is_advancing:
		advance_dialogue()
		get_viewport().set_input_as_handled()

func start_dialogue() -> void:
	start_conversation(conv_initial)

func start_conversation(conv: Array) -> void:
	SFX.play_interact()
	active_conversation = conv
	conversation = conv
	is_talking = true
	current_line_idx = 0
	
	# Prevent player from running around during conversation
	if current_player and "can_move" in current_player:
		current_player.can_move = false
		
	if dialogue_panel:
		dialogue_panel.visible = true
		dialogue_panel.modulate.a = 0.0
		dialogue_panel.pivot_offset = Vector2(240, 50)
		dialogue_panel.scale = Vector2(0.96, 0.96)
		var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(dialogue_panel, "modulate:a", 1.0, 0.18)
		tween.tween_property(dialogue_panel, "scale", Vector2.ONE, 0.18)
		
	_display_current_line()

func advance_dialogue() -> void:
	SFX.play_ui_click()
	current_line_idx += 1
	if current_line_idx < active_conversation.size():
		_display_current_line()
	else:
		end_dialogue()

func _display_current_line() -> void:
	if current_line_idx < 0 or current_line_idx >= active_conversation.size():
		return
		
	var item = active_conversation[current_line_idx]
	if speaker_label:
		speaker_label.text = item["speaker"]
		var sb = speaker_label.get_theme_stylebox("normal")
		if sb is StyleBoxFlat:
			sb = sb.duplicate()
			if item["speaker"] == "OLD MAN":
				speaker_label.add_theme_color_override("font_color", Color(0.12, 0.08, 0.04, 1))
				sb.bg_color = Color(0.95, 0.72, 0.18, 1) # Warm Gold
			else:
				speaker_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
				sb.bg_color = Color(0.18, 0.52, 0.82, 1) # Hero Blue
			speaker_label.add_theme_stylebox_override("normal", sb)
	
	if content_label:
		content_label.text = item["text"]
		content_label.modulate.a = 0.35
		var text_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		text_tween.tween_property(content_label, "modulate:a", 1.0, 0.12)
	
	if prompt_label:
		prompt_label.text = "[ E / Space / Click ] Continue ▸"

func end_dialogue() -> void:
	is_talking = false
	if dialogue_panel:
		dialogue_panel.visible = false
		
	# Release player movement lock
	if current_player and "can_move" in current_player:
		current_player.can_move = true
	
	if active_conversation == conv_initial:
		has_completed_dialogue = true
		GameState.set_state(GameState.State.CHICKEN_QUEST)
		if objective_panel and objective_label:
			objective_label.text = "🐔 FIND THE CHICKEN"
			objective_panel.visible = true
	elif active_conversation == conv_lantern_returned:
		has_completed_cave_dialogue = true
		GameState.set_state(GameState.State.CAVE_QUEST)
		if objective_panel and objective_label:
			objective_label.text = "ENTER THE CAVE"
			objective_panel.visible = true
	
	dialogue_finished.emit()
