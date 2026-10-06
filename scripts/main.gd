extends Node3D

@onready var pause_menu: CanvasLayer = $PauseMenu
@onready var player: CharacterBody3D = $Player

var is_in_cave: bool = false
var has_entered_forest: bool = false
var has_triggered_cave_meme: bool = false
var has_entered_cave_interior: bool = false
var has_seen_crystals: bool = false
var has_seen_light: bool = false

var cinematic_layer: CanvasLayer = null
var bar_top: ColorRect = null
var bar_bottom: ColorRect = null
var banner_panel: PanelContainer = null
var banner_title: Label = null
var banner_subtext: Label = null

func _ready() -> void:
	SFX.play_music("village", 1.2)
	_setup_cinematic_ui()

func _setup_cinematic_ui() -> void:
	cinematic_layer = CanvasLayer.new()
	cinematic_layer.name = "CinematicLayer"
	cinematic_layer.layer = 20
	add_child(cinematic_layer)
	
	bar_top = ColorRect.new()
	bar_top.color = Color(0, 0, 0, 1)
	bar_top.anchors_preset = Control.PRESET_TOP_WIDE
	bar_top.offset_bottom = 0.0
	cinematic_layer.add_child(bar_top)
	
	bar_bottom = ColorRect.new()
	bar_bottom.color = Color(0, 0, 0, 1)
	bar_bottom.anchors_preset = Control.PRESET_BOTTOM_WIDE
	bar_bottom.offset_top = 0.0
	cinematic_layer.add_child(bar_bottom)
	
	banner_panel = PanelContainer.new()
	banner_panel.anchors_preset = Control.PRESET_CENTER
	banner_panel.anchor_left = 0.5
	banner_panel.anchor_top = 0.5
	banner_panel.anchor_right = 0.5
	banner_panel.anchor_bottom = 0.5
	banner_panel.offset_left = -340.0
	banner_panel.offset_right = 340.0
	banner_panel.offset_top = -80.0
	banner_panel.offset_bottom = 80.0
	banner_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	banner_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.06, 0.04, 0.94)
	sb.border_width_left = 3
	sb.border_width_top = 3
	sb.border_width_right = 3
	sb.border_width_bottom = 3
	sb.border_color = Color(1.0, 0.82, 0.25, 1.0)
	sb.corner_radius_top_left = 12
	sb.corner_radius_top_right = 12
	sb.corner_radius_bottom_right = 12
	sb.corner_radius_bottom_left = 12
	sb.shadow_size = 14
	sb.shadow_color = Color(0, 0, 0, 0.8)
	sb.content_margin_left = 24.0
	sb.content_margin_right = 24.0
	sb.content_margin_top = 18.0
	sb.content_margin_bottom = 18.0
	banner_panel.add_theme_stylebox_override("panel", sb)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	banner_panel.add_child(vbox)
	
	banner_title = Label.new()
	banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25, 1.0))
	banner_title.add_theme_font_size_override("font_size", 22)
	banner_title.text = "THE CHOSEN ONE HAS ENTERED THE CAVE."
	vbox.add_child(banner_title)
	
	banner_subtext = Label.new()
	banner_subtext.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_subtext.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	banner_subtext.add_theme_font_size_override("font_size", 32)
	banner_subtext.text = ""
	vbox.add_child(banner_subtext)
	
	cinematic_layer.add_child(banner_panel)
	banner_panel.visible = false

func _process(_delta: float) -> void:
	if not player:
		return
	
	var player_pos = player.global_position
	var player_z = player_pos.z
	
	# Music zone crossfade between tropical village/forest and deep mountain cave
	if player_z < -78.0 and not is_in_cave:
		is_in_cave = true
		SFX.play_music("cave", 1.5)
	elif player_z >= -75.0 and is_in_cave:
		is_in_cave = false
		SFX.play_music("village", 1.5)

	# 1. Forest Path Monologue Trigger (entering tropical forest trail)
	if player_z < -14.0 and not has_entered_forest and GameState.current_state >= GameState.State.CHICKEN_QUEST:
		has_entered_forest = true
		_trigger_forest_monologues()

	# 2. Cave Entrance Meme Cutscene Trigger (entering cave steps on CAVE_QUEST)
	if player_pos.x < 1.0 and player_z < -80.0 and not has_triggered_cave_meme and GameState.current_state == GameState.State.CAVE_QUEST:
		has_triggered_cave_meme = true
		_play_chosen_one_cutscene()

	# 3. Cave Interior Reactions (tunnel and final chamber)
	var dist_to_tunnel = player_pos.distance_to(Vector3(-6.0, 1.0, -84.0))
	if dist_to_tunnel < 8.0 and not has_entered_cave_interior and GameState.current_state >= GameState.State.CAVE_QUEST:
		has_entered_cave_interior = true
		_trigger_cave_interior_monologue()

	var dist_to_crystals = player_pos.distance_to(Vector3(-12.0, 1.0, -84.0))
	if dist_to_crystals < 6.0 and not has_seen_crystals and GameState.current_state >= GameState.State.CAVE_QUEST:
		has_seen_crystals = true
		_trigger_crystals_monologue()

	var dist_to_altar = player_pos.distance_to(Vector3(-18.0, 1.0, -84.0))
	if dist_to_altar < 5.0 and not has_seen_light and GameState.current_state >= GameState.State.CAVE_QUEST:
		has_seen_light = true
		_trigger_light_monologue()

func _trigger_forest_monologues() -> void:
	if not player or not player.has_method("show_monologue"):
		return
	player.show_monologue("PLAYER: \"Arey! The chicken is heading deep into the forest trail!\"", 2.8)

func _play_chosen_one_cutscene() -> void:
	if DisplayServer.get_name() == "headless":
		return
		
	if player:
		if "can_move" in player:
			player.can_move = false
		player.velocity = Vector3.ZERO

	# Black bars slide in
	var tween = create_tween().set_parallel(true)
	tween.tween_property(bar_top, "offset_bottom", 70.0, 0.35)
	tween.tween_property(bar_bottom, "offset_top", -70.0, 0.35)
	
	# Epic dramatic sting & banner
	SFX.play_dramatic()
	banner_title.text = "★ THE CHOSEN ONE HAS ENTERED THE CAVE ★"
	banner_subtext.text = ""
	banner_panel.visible = true
	banner_panel.modulate.a = 0.0
	var panel_tween = create_tween()
	panel_tween.tween_property(banner_panel, "modulate:a", 1.0, 0.35)

	# Dramatic reveal
	await get_tree().create_timer(1.8).timeout
	
	# Reveal chicken
	SFX.play_chicken()
	banner_subtext.text = "🐔\n(The Chicken.)"

	await get_tree().create_timer(1.6).timeout

	# Slide out bars and banner
	var out_tween = create_tween().set_parallel(true)
	out_tween.tween_property(bar_top, "offset_bottom", 0.0, 0.25)
	out_tween.tween_property(bar_bottom, "offset_top", 0.0, 0.25)
	out_tween.tween_property(banner_panel, "modulate:a", 0.0, 0.25)
	await out_tween.finished
	banner_panel.visible = false

	# Always restore player control immediately
	if player and "can_move" in player:
		player.can_move = true

	# Deadpan Hinglish reactions
	if player and player.has_method("show_monologue"):
		player.show_monologue("PLAYER: \"...\"", 1.2)
		await get_tree().create_timer(1.4).timeout
		player.show_monologue("PLAYER: \"Seriously?\"", 1.6)
		await get_tree().create_timer(1.8).timeout
		player.show_monologue("PLAYER: \"Main ek chicken ke peeche yahan tak aa gaya?\"", 2.8)

func _trigger_cave_interior_monologue() -> void:
	if not player or not player.has_method("show_monologue"):
		return
	player.show_monologue("PLAYER: \"Okay...\"", 1.2)
	await get_tree().create_timer(1.4).timeout
	player.show_monologue("PLAYER: \"Yeh jagah normal nahi hai.\"", 2.4)

func _trigger_crystals_monologue() -> void:
	if not player or not player.has_method("show_monologue"):
		return
	player.show_monologue("PLAYER: \"Bro...\"", 1.2)
	await get_tree().create_timer(1.4).timeout
	player.show_monologue("PLAYER: \"What IS this place?\"", 2.4)

func _trigger_light_monologue() -> void:
	if not player or not player.has_method("show_monologue"):
		return
	player.show_monologue("PLAYER: \"Okay... now this is getting weird.\"", 2.5)
