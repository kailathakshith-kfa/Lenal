extends CharacterBody3D

signal lantern_taken

enum ChickenState {
	IDLE,
	ALERT,
	RUNNING,
	CORNERED,
	CAUGHT
}

@export var run_speed: float = 5.8
@export var turn_speed: float = 12.0

@onready var visual_root: Node3D = $VisualRoot
@onready var body_mesh: MeshInstance3D = $VisualRoot/Body
@onready var head_root: Node3D = $VisualRoot/HeadRoot
@onready var lantern_node: Node3D = $VisualRoot/Lantern
@onready var lantern_light: OmniLight3D = $VisualRoot/Lantern/OmniLight3D
@onready var badge: Label3D = $VisualRoot.get_node_or_null("Badge")

var state: ChickenState = ChickenState.IDLE
var has_lantern: bool = true
var player_ref: Node3D = null

# Multi-stage village to forest cave chase route giving the player plenty of time and fun pursuit!
var chase_stages: Array = [
	# Leg 0: Scurrying past the bazaar stalls & market
	[
		Vector3(-6.5, 0.35, 1.0),
		Vector3(-6.5, 0.35, -4.0),
		Vector3(-6.5, 0.35, -8.0)
	],
	# Leg 1: Dashing across the plaza towards the temple grand gopuram gate
	[
		Vector3(0.0, 0.35, -8.0),
		Vector3(0.0, 1.85, -15.0),
		Vector3(0.0, 1.85, -18.0)
	],
	# Leg 2: Scurrying past the east temple colonnade to the rear forest exit
	[
		Vector3(6.0, 1.85, -20.0),
		Vector3(6.0, 1.85, -32.0),
		Vector3(6.0, 1.85, -36.0),
		Vector3(6.0, 0.35, -44.0)
	],
	# Leg 3: Scurrying deep into the tropical forest panorama trail
	[
		Vector3(5.0, 0.35, -55.0),
		Vector3(4.0, 0.35, -66.0),
		Vector3(3.0, 0.35, -76.0)
	],
	# Leg 4: Final panic dash right up to the dark mysterious Cave mouth
	[
		Vector3(3.0, 0.35, -82.0)
	]
]

# Waypoints list for backward compatibility with scripts and automated tests
var waypoints: Array[Vector3] = [
	Vector3(-6.5, 0.35, -8.0),
	Vector3(0.0, 1.85, -18.0),
	Vector3(6.0, 0.35, -44.0),
	Vector3(3.0, 0.35, -76.0),
	Vector3(3.0, 0.35, -82.0)
]
var current_waypoint_idx: int = 0

var current_stage: int = 0
var stage_waypoint_idx: int = 0
var is_taunting: bool = false
var taunt_bob: float = 0.0

var alert_timer: float = 0.0
var idle_bob_timer: float = 0.0
var cluck_timer: float = 3.0
var base_y: float = 0.35

func _ready() -> void:
	add_to_group("interactable")
	floor_snap_length = 0.4
	floor_max_angle = deg_to_rad(50.0)
	base_y = position.y
	_update_badge()

func _physics_process(delta: float) -> void:
	if not player_ref:
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player_ref = players[0]

	match state:
		ChickenState.IDLE:
			_process_idle(delta)
		ChickenState.ALERT:
			_process_alert(delta)
		ChickenState.RUNNING:
			_process_running(delta)
		ChickenState.CORNERED:
			_process_cornered(delta)
		ChickenState.CAUGHT:
			_process_caught(delta)

	move_and_slide()

func _process_idle(delta: float) -> void:
	idle_bob_timer += delta
	if idle_bob_timer > 0.6:
		idle_bob_timer = 0.0
		if randf() > 0.5 and head_root:
			head_root.rotation.y = randf_range(-0.8, 0.8)
			head_root.rotation.x = randf_range(-0.3, 0.3)
	
	cluck_timer -= delta
	if cluck_timer <= 0.0:
		cluck_timer = randf_range(4.0, 8.0)
		SFX.play_chicken()

	# Check distance to player
	if player_ref and GameState.current_state >= GameState.State.CHICKEN_QUEST:
		var dist = global_position.distance_to(player_ref.global_position)
		if dist < 5.0:
			trigger_alert()

func trigger_alert() -> void:
	state = ChickenState.ALERT
	alert_timer = 0.45
	SFX.play_chicken()
	velocity.y = 3.5 # Panic hop
	if head_root:
		head_root.rotation.y = PI # Look back at player
	_update_badge()
	if player_ref and player_ref.has_method("show_monologue"):
		player_ref.show_monologue("PLAYER: \"Arey! That's the missing chicken holding a lantern?! Ruk!\"", 2.6)

func _process_alert(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 18.0 * delta
	else:
		velocity.y = 0.0

	alert_timer -= delta
	if alert_timer <= 0.0:
		state = ChickenState.RUNNING
		current_stage = 0
		stage_waypoint_idx = 0
		is_taunting = false
		_update_badge()

func _process_running(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 18.0 * delta
	else:
		velocity.y = 0.0

	if is_taunting:
		_process_taunting(delta)
		return

	if current_stage >= chase_stages.size():
		state = ChickenState.CORNERED
		velocity.x = 0.0
		velocity.z = 0.0
		SFX.play_chicken()
		_update_badge()
		return

	var current_leg: Array = chase_stages[current_stage]
	if stage_waypoint_idx >= current_leg.size():
		# Reached checkpoint for this stage!
		if current_stage == chase_stages.size() - 1:
			state = ChickenState.CORNERED
			velocity.x = 0.0
			velocity.z = 0.0
			SFX.play_chicken()
			_update_badge()
			return
		else:
			is_taunting = true
			velocity.x = 0.0
			velocity.z = 0.0
			SFX.play_chicken()
			_update_badge()
			return

	var target_pos: Vector3 = current_leg[stage_waypoint_idx]
	var dir = (target_pos - global_position)
	dir.y = 0.0
	
	if dir.length() < 0.8:
		stage_waypoint_idx += 1
		return

	dir = dir.normalized()
	velocity.x = dir.x * run_speed
	velocity.z = dir.z * run_speed

	# Face movement direction
	var target_angle = atan2(-dir.x, -dir.z)
	visual_root.rotation.y = lerp_angle(visual_root.rotation.y, target_angle, turn_speed * delta)

	# Funny rapid waddle
	var run_time = Time.get_ticks_msec() * 0.025
	visual_root.position.y = abs(sin(run_time)) * 0.12
	visual_root.rotation.z = sin(run_time * 0.5) * 0.22

func _process_taunting(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0

	# Face player while teasing
	if player_ref:
		var dir_to_player = (player_ref.global_position - global_position).normalized()
		var target_angle = atan2(-dir_to_player.x, -dir_to_player.z)
		visual_root.rotation.y = lerp_angle(visual_root.rotation.y, target_angle, 6.0 * delta)

	# Comedic bobbing and wing flapping
	taunt_bob += delta * 7.5
	visual_root.position.y = abs(sin(taunt_bob)) * 0.12
	if head_root:
		head_root.rotation.x = sin(taunt_bob * 1.5) * 0.3

	cluck_timer -= delta
	if cluck_timer <= 0.0:
		cluck_timer = randf_range(1.5, 3.0)
		SFX.play_chicken()

	# If player catches up close, bolt to the next stage!
	if player_ref:
		var dist = global_position.distance_to(player_ref.global_position)
		if dist < 3.2:
			_advance_to_next_stage()

func _advance_to_next_stage() -> void:
	is_taunting = false
	current_stage += 1
	stage_waypoint_idx = 0
	SFX.play_chicken()
	velocity.y = 3.2 # Panic hop
	
	if player_ref and player_ref.has_method("show_monologue"):
		match current_stage:
			1:
				player_ref.show_monologue("PLAYER: \"Abey yeh mandir ke andar kyun bhaag gayi?!\"", 2.4)
			2:
				player_ref.show_monologue("PLAYER: \"Wait! Mandir se bahar nikal rahi hai!\"", 2.4)
			3:
				player_ref.show_monologue("PLAYER: \"Yeh chicken jungle mein kyun jaa rahi hai?!\"", 2.6)
			4:
				player_ref.show_monologue("PLAYER: \"Seriously?! In the jungle?! How is she this fast?!\"", 2.6)
				get_tree().create_timer(3.2).timeout.connect(func():
					if player_ref and player_ref.has_method("show_monologue"):
						player_ref.show_monologue("PLAYER: \"Finally cornered you outside the cave! What is that in her beak?!\"", 3.2)
				)

	if current_stage >= chase_stages.size():
		state = ChickenState.CORNERED
		velocity.x = 0.0
		velocity.z = 0.0
		_update_badge()
	else:
		_update_badge()

func _process_cornered(delta: float) -> void:
	# Heavy breathing / panting
	var pant_time = Time.get_ticks_msec() * 0.012
	visual_root.position.y = abs(sin(pant_time)) * 0.05
	visual_root.rotation.z = move_toward(visual_root.rotation.z, 0.0, delta * 2.0)
	
	# Lantern flickering
	if lantern_light:
		lantern_light.light_energy = 1.6 + sin(Time.get_ticks_msec() * 0.015) * 0.4
	
	_update_badge()

func _process_caught(_delta: float) -> void:
	var calm_time = Time.get_ticks_msec() * 0.003
	visual_root.position.y = sin(calm_time) * 0.02
	visual_root.rotation.z = 0.0
	_update_badge()

func _update_badge() -> void:
	if not badge:
		return
	match state:
		ChickenState.IDLE:
			if GameState.current_state >= GameState.State.CHICKEN_QUEST and has_lantern:
				badge.text = "🐔 MISSING CHICKEN"
				badge.visible = true
			else:
				badge.text = "🐔"
				badge.visible = true
		ChickenState.ALERT:
			badge.text = "🐔 !!"
			badge.visible = true
		ChickenState.RUNNING:
			if is_taunting:
				badge.text = "🐔 [Catch me!]"
			else:
				badge.text = "🐔 [Running!]"
			badge.visible = true
		ChickenState.CORNERED:
			badge.text = "🐔 [E] CATCH & TAKE LANTERN"
			badge.visible = true
		ChickenState.CAUGHT:
			badge.visible = false

func get_interact_text() -> String:
	if has_lantern:
		if state == ChickenState.CORNERED:
			return "Catch Chicken & Take Lantern"
		elif state == ChickenState.RUNNING and is_taunting:
			return "Grab at Chicken!"
		elif GameState.current_state == GameState.State.START:
			return "Inspect Chicken"
		else:
			return "Catch Chicken"
	return "Exhausted Chicken"

func interact(player: Node) -> String:
	if GameState.current_state == GameState.State.START:
		SFX.play_chicken()
		return "Chicken: *clucks suspiciously and clings to a stolen lantern*"

	if is_taunting and state == ChickenState.RUNNING:
		_advance_to_next_stage()
		return "Chicken: *Bawk-bawk! The chicken flutters just out of reach and sprints away!*"

	if has_lantern:
		has_lantern = false
		state = ChickenState.CAUGHT
		if lantern_node:
			lantern_node.visible = false
		
		SFX.play_lantern()
		SFX.play_chicken()
		
		GameState.set_state(GameState.State.LANTERN_FOUND)
		lantern_taken.emit()
		_update_badge()
		
		if player and player.has_method("show_status_message"):
			player.show_status_message("YOU GOT THE LANTERN! Return to the Old Man.", 4.0)
		
		if player and player.has_method("show_monologue"):
			player.show_monologue("PLAYER: \"Got the lantern! Now I should take it back to the Old Man in the village.\"", 3.2)
		
		return "YOU GOT THE LANTERN."
	else:
		SFX.play_chicken()
		return "Chicken: *soft defeated cluck*"
