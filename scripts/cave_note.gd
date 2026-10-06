extends StaticBody3D

@onready var note_mesh: MeshInstance3D = $NoteMesh
@onready var aura_light: OmniLight3D = $AuraLight
@onready var canvas_layer: CanvasLayer = $CanvasLayer
@onready var note_panel: PanelContainer = $CanvasLayer/NotePanel
@onready var message_label: Label = $CanvasLayer/NotePanel/MarginContainer/VBoxContainer/MessageLabel
@onready var close_label: Label = $CanvasLayer/NotePanel/MarginContainer/VBoxContainer/CloseLabel

var is_showing: bool = false
var has_been_read: bool = false
var current_player: Node = null
var flash_rect: ColorRect = null

func _ready() -> void:
	add_to_group("interactable")
	if note_panel:
		note_panel.visible = false

func _process(_delta: float) -> void:
	# Subtle floating / pulsing glow on note
	if aura_light:
		aura_light.light_energy = 1.2 + sin(Time.get_ticks_msec() * 0.005) * 0.4
	if note_mesh:
		note_mesh.position.y = 0.55 + sin(Time.get_ticks_msec() * 0.003) * 0.02

func get_interact_text() -> String:
	if not has_been_read:
		if GameState.current_state < GameState.State.CAVE_QUEST:
			return "Dormant Relic (Report to Old Man first)"
		return "Inspect Glowing Relic"
	return "Read Cave Note"

func interact(player: Node) -> String:
	current_player = player
	if not has_been_read:
		if GameState.current_state < GameState.State.CAVE_QUEST:
			if current_player and current_player.has_method("show_monologue"):
				current_player.show_monologue("PLAYER: \"The relic is dormant... I should take the lantern back to the Old Man first!\"", 3.2)
			if current_player and current_player.has_method("show_status_message"):
				current_player.show_status_message("Objective: Report back to the Old Man in the village plaza!", 3.5)
			return "The relic is dormant. Report back to the Old Man first."
		_play_chamber_flash_sequence()
		return ""
	else:
		if not is_showing:
			show_note()
		else:
			hide_note()
		return ""

func _unhandled_input(event: InputEvent) -> void:
	if not is_showing:
		return
	
	if event.is_action_pressed("interact") or event.is_action_pressed("jump") or (event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed):
		hide_note()
		get_viewport().set_input_as_handled()

func _play_chamber_flash_sequence() -> void:
	if DisplayServer.get_name() == "headless":
		has_been_read = true
		GameState.set_state(GameState.State.CAVE_NOTE_FOUND)
		show_note()
		return

	if current_player and "can_move" in current_player:
		current_player.can_move = false

	# PLAYER: "Okay... this has to be important."
	if current_player and current_player.has_method("show_monologue"):
		current_player.show_monologue("PLAYER: \"Okay... this has to be important.\"", 2.0)

	await get_tree().create_timer(2.2).timeout

	# Chicken walks toward it, player warns
	SFX.play_chicken()
	if current_player and current_player.has_method("show_monologue"):
		current_player.show_monologue("PLAYER: \"Wait. Don't touch that.\"", 2.0)

	await get_tree().create_timer(2.2).timeout

	# 💥 FLASH! Full-screen whiteout
	_trigger_flash_effect()
	SFX.play_dramatic()

	await get_tree().create_timer(1.8).timeout

	# Hide crystal relic after flash
	if has_node("CrystalMesh"):
		get_node("CrystalMesh").visible = false

	# Show note and update state
	show_note()
	has_been_read = true
	GameState.set_state(GameState.State.CAVE_NOTE_FOUND)

	await get_tree().create_timer(1.2).timeout

	# Player monologue reactions: "..." -> "That's it?" -> "Seriously?"
	if current_player and current_player.has_method("show_monologue"):
		current_player.show_monologue("PLAYER: \"...\"", 1.4)
		await get_tree().create_timer(1.6).timeout
		current_player.show_monologue("PLAYER: \"That's it?\"", 1.6)
		await get_tree().create_timer(1.8).timeout
		current_player.show_monologue("PLAYER: \"Seriously?\"", 2.0)

	if current_player and "can_move" in current_player:
		current_player.can_move = true

func _trigger_flash_effect() -> void:
	if not canvas_layer:
		return
	if not flash_rect:
		flash_rect = ColorRect.new()
		flash_rect.anchors_preset = Control.PRESET_FULL_RECT
		flash_rect.anchor_right = 1.0
		flash_rect.anchor_bottom = 1.0
		flash_rect.color = Color(1, 1, 1, 1)
		flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		canvas_layer.add_child(flash_rect)
	
	flash_rect.visible = true
	flash_rect.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(flash_rect, "modulate:a", 1.0, 0.12)
	tween.tween_interval(0.6)
	tween.tween_property(flash_rect, "modulate:a", 0.0, 1.2)
	tween.tween_callback(func(): flash_rect.visible = false)

func show_note() -> void:
	is_showing = true
	SFX.play_note()
	if note_panel:
		note_panel.visible = true
	
	if not has_been_read:
		has_been_read = true
		GameState.set_state(GameState.State.CAVE_NOTE_FOUND)
		if current_player and current_player.has_method("show_status_message"):
			current_player.show_status_message("New Objective: 🔙 GO BACK TO THE OLD MAN", 4.0)

func hide_note() -> void:
	is_showing = false
	if note_panel:
		note_panel.visible = false
