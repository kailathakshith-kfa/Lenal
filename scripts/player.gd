extends CharacterBody3D

signal interacted_with(target)

enum State {
	IDLE,
	WALK,
	RUN,
	JUMP,
	FALL,
	LAND
}

@export_group("Movement Settings")
@export var walk_speed: float = 3.5
@export var run_speed: float = 6.0
@export var acceleration: float = 20.0
@export var deceleration: float = 24.0
@export var jump_velocity: float = 7.5
@export var rotation_speed: float = 12.0
@export var can_move: bool = true
var move_speed: float = 3.5

@export_group("Camera Settings")
@export var camera_distance: float = 5.5
@export var camera_height: float = 2.4
@export var camera_fov: float = 65.0
@export var camera_look_pitch: float = -12.0
@export var mouse_sensitivity: float = 0.003
@export var min_pitch: float = -70.0
@export var max_pitch: float = 45.0

@export_group("Animation Mapping")
@export var anim_idle: String = "Idle"
@export var anim_walk: String = "Walk"
@export var anim_run: String = "Jog_Fwd"
@export var anim_jump: String = "Jump_Start"
@export var anim_fall: String = "Jump"
@export var anim_land: String = "Jump_Land"

@onready var cam_pivot: Node3D = $CamPivot
@onready var spring_arm: SpringArm3D = $CamPivot/SpringArm3D
@onready var camera: Camera3D = $CamPivot/SpringArm3D/Camera3D
@onready var mesh_root: Node3D = $MeshRoot
@onready var interact_ray: RayCast3D = $CamPivot/SpringArm3D/Camera3D/InteractRay
@onready var interact_prompt: Label = $HUD/InteractPrompt
@onready var status_label: Label = $HUD/StatusLabel
@onready var quest_tracker: PanelContainer = $HUD.get_node_or_null("QuestTracker")
@onready var quest_title: Label = $HUD.get_node_or_null("QuestTracker/VBox/QuestTitle")
@onready var quest_hint: Label = $HUD.get_node_or_null("QuestTracker/VBox/QuestHint")
@onready var waypoint_marker: PanelContainer = $HUD.get_node_or_null("WaypointMarker")
@onready var waypoint_icon: Label = $HUD.get_node_or_null("WaypointMarker/HBox/Icon")
@onready var waypoint_name: Label = $HUD.get_node_or_null("WaypointMarker/HBox/TargetName")
@onready var waypoint_dist: Label = $HUD.get_node_or_null("WaypointMarker/HBox/Distance")

# Animation player from imported UAL1_Standard.glb
@onready var anim_player: AnimationPlayer = $MeshRoot/CharacterModel/AnimationPlayer

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 18.0)
var current_interactable: Node = null
var status_timer: float = 0.0
var jump_buffer: float = 0.0
var footstep_timer: float = 0.0

var current_state: State = State.IDLE
var current_anim: String = ""
var land_timer: float = 0.0
var was_on_floor: bool = true
var prev_vertical_vel: float = 0.0
var last_safe_pos: Vector3 = Vector3(0, 0.5, 12)

const IndianBoyMesh = preload("res://scripts/indian_boy_mesh.gd")

func _ready() -> void:
	_ensure_input_mappings()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if interact_prompt:
		interact_prompt.visible = false
	if status_label:
		status_label.text = "LENAL — Stylized Indian Comic Adventure"
	var gs = get_node_or_null("/root/GameState")
	if gs:
		if gs.has_signal("objective_updated"):
			gs.objective_updated.connect(_on_objective_updated)
		if gs.has_signal("state_changed"):
			gs.state_changed.connect(_on_state_changed)
		_update_quest_info(gs.current_state)

	# Initialize Teenage Indian Boy character visuals
	var char_model: Node3D = $MeshRoot.get_node_or_null("CharacterModel")
	if char_model:
		IndianBoyMesh.setup_character(char_model)

	# Read global mouse sensitivity if configured
	if SFX and "mouse_sensitivity_setting" in SFX:
		mouse_sensitivity = SFX.mouse_sensitivity_setting

	# Apply exported camera tuning
	if cam_pivot:
		cam_pivot.position.y = camera_height
	if spring_arm:
		spring_arm.spring_length = camera_distance
		spring_arm.rotation.x = deg_to_rad(camera_look_pitch)
	if camera:
		camera.fov = camera_fov

	floor_snap_length = 0.4
	floor_max_angle = deg_to_rad(50.0)
	floor_constant_speed = true

	# Start initial animation
	_play_anim(anim_idle, 0.0)

func _on_objective_updated(text: String) -> void:
	show_status_message("Objective: " + text, 5.0)

func _ensure_input_mappings() -> void:
	var defaults = {
		"move_forward": [KEY_W, KEY_UP],
		"move_back": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"jump": [KEY_SPACE],
		"run": [KEY_SHIFT],
		"interact": [KEY_E],
	}
	for action in defaults:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for k in defaults[action]:
			var ev = InputEventKey.new()
			ev.physical_keycode = k
			ev.keycode = k
			if not InputMap.action_has_event(action, ev):
				InputMap.action_add_event(action, ev)

func _unhandled_input(event: InputEvent) -> void:
	# ESC toggles pause menu
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed):
		var pause_menus = get_tree().get_nodes_in_group("pause_menu")
		if pause_menus.size() > 0:
			pause_menus[0].toggle_pause()
			get_viewport().set_input_as_handled()
			return
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# Click to recapture mouse
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# Mouse camera rotation
	if event is InputEventMouseMotion and (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or DisplayServer.get_name() == "headless"):
		apply_look_rotation(event.relative.x, event.relative.y)

func apply_look_rotation(rel_x: float, rel_y: float) -> void:
	cam_pivot.rotate_y(-rel_x * mouse_sensitivity)
	spring_arm.rotate_x(-rel_y * mouse_sensitivity)
	spring_arm.rotation.x = clamp(spring_arm.rotation.x, deg_to_rad(min_pitch), deg_to_rad(max_pitch))

func _physics_process(delta: float) -> void:
	# Gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	# If locked by dialogue or sequence, decelerate to stop
	if not can_move:
		velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, deceleration * delta)
		var falling_speed := prev_vertical_vel
		prev_vertical_vel = velocity.y
		move_and_slide()
		if is_on_floor() and global_position.y >= -0.2:
			last_safe_pos = global_position
		elif global_position.y < -6.0:
			velocity = Vector3.ZERO
			global_position = last_safe_pos + Vector3(0, 0.6, 0)
			prev_vertical_vel = 0.0
		_update_animation_state(delta, false, false, falling_speed)
		_update_hud(delta)
		was_on_floor = is_on_floor()
		return

	# Jump buffer
	if Input.is_action_just_pressed("jump"):
		jump_buffer = 0.2
	elif jump_buffer > 0.0:
		jump_buffer -= delta

	if jump_buffer > 0.0 and is_on_floor():
		velocity.y = jump_velocity
		jump_buffer = 0.0
		current_state = State.JUMP
		_play_anim(anim_jump, 0.12)
		SFX.play_jump()

	# Calculate movement direction relative to camera yaw
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var cam_basis := cam_pivot.global_transform.basis
	var forward := -cam_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right := cam_basis.x
	right.y = 0.0
	right = right.normalized()

	var move_dir := (forward * (-input_dir.y) + right * input_dir.x).normalized()
	var has_input := input_dir.length_squared() > 0.01

	var is_running := (Input.is_action_pressed("run") or Input.is_key_pressed(KEY_SHIFT)) and has_input
	var target_speed := run_speed if is_running else walk_speed
	var target_vel := move_dir * target_speed

	var accel_rate := acceleration if has_input else deceleration
	velocity.x = move_toward(velocity.x, target_vel.x, accel_rate * delta)
	velocity.z = move_toward(velocity.z, target_vel.z, accel_rate * delta)

	var falling_speed := prev_vertical_vel
	prev_vertical_vel = velocity.y

	move_and_slide()

	# Safe ground tracking & Void fall rescue
	if is_on_floor() and global_position.y >= -0.2:
		last_safe_pos = global_position
	elif global_position.y < -6.0:
		velocity = Vector3.ZERO
		global_position = last_safe_pos + Vector3(0, 0.6, 0)
		prev_vertical_vel = 0.0
		show_status_message("Arre bhai! Sambhal ke! (Careful!)", 2.5)

	# Rotate character mesh smoothly toward movement direction
	if has_input and move_dir.length_squared() > 0.01:
		var target_angle := atan2(-move_dir.x, -move_dir.z)
		mesh_root.rotation.y = lerp_angle(mesh_root.rotation.y, target_angle, rotation_speed * delta)

	# Animation state machine
	_update_animation_state(delta, has_input, is_running, falling_speed)

	# Footsteps audio
	_update_footsteps(delta, is_running)

	_update_interaction()
	_update_hud(delta)

	was_on_floor = is_on_floor()

func _update_animation_state(delta: float, has_input: bool, is_running: bool, falling_speed: float) -> void:
	var horiz_speed := Vector2(velocity.x, velocity.z).length()

	if is_on_floor():
		# Landing detection
		if not was_on_floor and falling_speed < -1.5:
			current_state = State.LAND
			land_timer = 0.35
			_play_anim(anim_land, 0.1)
			SFX.play_land()

		if current_state == State.LAND:
			if has_input:
				# Break out of landing into locomotion if player is actively moving
				if is_running:
					current_state = State.RUN
					_play_anim(anim_run, 0.2)
				else:
					current_state = State.WALK
					_play_anim(anim_walk, 0.2)
			else:
				land_timer -= delta
				if land_timer <= 0.0:
					current_state = State.IDLE
					_play_anim(anim_idle, 0.25)
		else:
			if horiz_speed < 0.2:
				current_state = State.IDLE
				_play_anim(anim_idle, 0.25)
			elif is_running:
				current_state = State.RUN
				_play_anim(anim_run, 0.2)
			else:
				current_state = State.WALK
				_play_anim(anim_walk, 0.2)
	else:
		# Airborne states
		if velocity.y > 0.5:
			current_state = State.JUMP
			_play_anim(anim_jump, 0.15)
		else:
			current_state = State.FALL
			_play_anim(anim_fall, 0.25)

func _play_anim(anim_name: String, blend_time: float = 0.2) -> void:
	if current_anim == anim_name:
		return
	current_anim = anim_name
	if anim_player and anim_player.has_animation(anim_name):
		anim_player.play(anim_name, blend_time)

func _update_footsteps(delta: float, is_running: bool) -> void:
	var horiz_speed := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and horiz_speed > 0.5:
		footstep_timer += delta
		var step_interval := 0.30 if is_running else 0.42
		if footstep_timer >= step_interval:
			footstep_timer = 0.0
			SFX.play_footstep()
	else:
		footstep_timer = 0.25

func _update_interaction() -> void:
	current_interactable = null
	
	if interact_ray and interact_ray.is_colliding():
		var collider = interact_ray.get_collider()
		if collider and collider.is_in_group("interactable"):
			current_interactable = collider
	
	# Proximity fallback area detection
	if not current_interactable and has_node("InteractArea"):
		var areas = $InteractArea.get_overlapping_bodies()
		for b in areas:
			if b.is_in_group("interactable"):
				current_interactable = b
				break
		if not current_interactable:
			var area_nodes = $InteractArea.get_overlapping_areas()
			for a in area_nodes:
				if a.is_in_group("interactable"):
					current_interactable = a
					break

	if interact_prompt:
		if current_interactable:
			var obj_name = current_interactable.name
			if current_interactable.has_method("get_interact_text"):
				obj_name = current_interactable.get_interact_text()
			interact_prompt.text = "[E] " + obj_name
			interact_prompt.visible = true
		else:
			interact_prompt.visible = false

	# Handle interact action
	if Input.is_action_just_pressed("interact") and current_interactable:
		_perform_interaction(current_interactable)

func _perform_interaction(obj: Node) -> void:
	interacted_with.emit(obj)
	var response_msg := ""
	if obj.has_method("interact"):
		response_msg = str(obj.interact(self))
	else:
		response_msg = "Interacted with " + obj.name
	
	show_status_message(response_msg)

var monologue_panel: PanelContainer = null
var monologue_label: Label = null
var monologue_timer: float = 0.0

func _setup_monologue_ui() -> void:
	if monologue_panel != null:
		return
	var hud_node = get_node_or_null("HUD")
	if not hud_node:
		return
	
	monologue_panel = PanelContainer.new()
	monologue_panel.name = "MonologueBox"
	monologue_panel.anchors_preset = Control.PRESET_CENTER_BOTTOM
	monologue_panel.anchor_left = 0.5
	monologue_panel.anchor_right = 0.5
	monologue_panel.anchor_top = 1.0
	monologue_panel.anchor_bottom = 1.0
	monologue_panel.offset_left = -300.0
	monologue_panel.offset_right = 300.0
	monologue_panel.offset_top = -140.0
	monologue_panel.offset_bottom = -88.0
	monologue_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	monologue_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	monologue_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.08, 0.06, 0.92)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(0.95, 0.75, 0.22, 1.0)
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_right = 8
	sb.corner_radius_bottom_left = 8
	sb.content_margin_left = 18.0
	sb.content_margin_right = 18.0
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 8.0
	sb.shadow_size = 8
	sb.shadow_color = Color(0, 0, 0, 0.5)
	monologue_panel.add_theme_stylebox_override("panel", sb)
	
	monologue_label = Label.new()
	monologue_label.name = "Text"
	monologue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	monologue_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	monologue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	monologue_label.add_theme_color_override("font_color", Color(1, 0.96, 0.88, 1))
	monologue_label.add_theme_font_size_override("font_size", 16)
	monologue_panel.add_child(monologue_label)
	
	hud_node.add_child(monologue_panel)
	monologue_panel.visible = false

func show_monologue(text: String, duration: float = 3.5) -> void:
	if not monologue_panel:
		_setup_monologue_ui()
	if monologue_label:
		monologue_label.text = text
	if monologue_panel:
		monologue_panel.visible = true
		monologue_panel.modulate.a = 1.0
	monologue_timer = duration

func show_status_message(msg: String, duration: float = 3.5) -> void:
	if status_label:
		status_label.text = msg
		status_timer = duration

func _update_hud(delta: float) -> void:
	if status_timer > 0.0:
		status_timer -= delta
		if status_timer <= 0.0 and status_label:
			status_label.text = "LENAL — Stylized Indian Village Adventure"
	if monologue_timer > 0.0:
		monologue_timer -= delta
		if monologue_timer <= 0.0 and monologue_panel:
			var tween = create_tween()
			tween.tween_property(monologue_panel, "modulate:a", 0.0, 0.3)
			tween.tween_callback(func(): if monologue_panel: monologue_panel.visible = false)
	_update_waypoint()

func _on_state_changed(new_state: int) -> void:
	_update_quest_info(new_state)

func _update_quest_info(state_val: int) -> void:
	if not quest_title or not quest_hint:
		return
	match state_val:
		0: # START
			quest_title.text = "Talk to the Old Man"
			quest_hint.text = "Find the old man sitting on the charpai near the village plaza"
		1: # CHICKEN_QUEST
			quest_title.text = "🐔 FIND THE CHICKEN"
			quest_hint.text = "Follow the clucking sounds across the village to catch the runaway chicken!"
		2: # LANTERN_FOUND
			quest_title.text = "🔙 Return to the Old Man"
			quest_hint.text = "You caught the chicken and retrieved the lantern! Return to the village plaza and talk to the Old Man."
		3: # CAVE_QUEST
			quest_title.text = "ENTER THE CAVE"
			quest_hint.text = "Follow the forest trail into the mysterious mountain cave and investigate!"
		4: # CAVE_NOTE_FOUND
			quest_title.text = "🔙 GO BACK TO THE OLD MAN"
			quest_hint.text = "Head back through the forest to the village plaza where the old man was sitting."
		5: # GAME_OVER
			quest_title.text = "Quest Complete!"
			quest_hint.text = "You discovered the secrets of the village and collected your reward!"

func _get_current_target_info() -> Dictionary:
	var gs = get_node_or_null("/root/GameState")
	var s: int = gs.current_state if gs else 0
	match s:
		0: # START
			return {"pos": Vector3(3.8, 1.5, 1.2), "icon": "👴", "name": "Old Man"}
		1: # CHICKEN_QUEST
			var interactables = get_tree().get_nodes_in_group("interactable")
			for obj in interactables:
				if obj.name == "Chicken" or obj.has_method("trigger_alert"):
					var is_cornered = obj.get("state") == 3 # ChickenState.CORNERED
					var name_str = "Catch Chicken!" if is_cornered else "Runaway Chicken"
					return {"pos": obj.global_position + Vector3(0, 0.8, 0), "icon": "🐔", "name": name_str}
			return {"pos": Vector3(-3.2, 0.5, -1.8), "icon": "🐔", "name": "Runaway Chicken"}
		2: # LANTERN_FOUND
			return {"pos": Vector3(3.8, 1.5, 1.2), "icon": "👴", "name": "Old Man (Village)"}
		3: # CAVE_QUEST
			# Outside cave: guide to cave entrance; inside cave: guide directly to glowing relic
			if global_position.x > 0.0 or global_position.z > -80.0:
				return {"pos": Vector3(1.0, 1.5, -84.0), "icon": "⛰️", "name": "Cave Entrance"}
			else:
				return {"pos": Vector3(-18.0, 1.4, -84.0), "icon": "✨", "name": "Glowing Relic"}
		4: # CAVE_NOTE_FOUND
			return {"pos": Vector3(3.8, 1.0, 1.2), "icon": "💰", "name": "Old Man's Spot"}
		_:
			return {}

func _update_waypoint() -> void:
	if not waypoint_marker or not is_instance_valid(camera):
		return
	if DisplayServer.get_name() == "headless":
		return

	var info = _get_current_target_info()
	if info.is_empty():
		waypoint_marker.visible = false
		return

	var target_pos: Vector3 = info["pos"]
	var dist = global_position.distance_to(target_pos)

	if waypoint_icon:
		waypoint_icon.text = info["icon"]
	if waypoint_name:
		waypoint_name.text = info["name"]
	if waypoint_dist:
		waypoint_dist.text = "%dm" % int(dist)

	var gs = get_node_or_null("/root/GameState")
	if (gs and gs.current_state == gs.State.GAME_OVER) or dist < 2.2:
		waypoint_marker.visible = false
		return

	var vp = get_viewport()
	if not vp:
		return
	var vp_size = vp.get_visible_rect().size
	if vp_size.x <= 0 or vp_size.y <= 0:
		return

	var screen_pos = camera.unproject_position(target_pos)
	var is_behind = camera.is_position_behind(target_pos)

	if is_behind:
		var center = vp_size * 0.5
		var dir = (screen_pos - center).normalized()
		if dir.length_squared() < 0.01:
			dir = Vector2(0, 1)
		screen_pos = center - dir * min(center.x, center.y) * 0.85

	var margin = 60.0
	screen_pos.x = clamp(screen_pos.x, margin, vp_size.x - margin)
	screen_pos.y = clamp(screen_pos.y, margin, vp_size.y - margin)

	waypoint_marker.global_position = screen_pos - waypoint_marker.size * 0.5
	waypoint_marker.visible = true

