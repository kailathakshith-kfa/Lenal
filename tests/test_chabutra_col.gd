extends SceneTree

const GameStateScript = preload("res://scripts/game_state.gd")

func _init() -> void:
	call_deferred("_test")

func _test() -> void:
	var gs = GameStateScript.new()
	gs.name = "GameState"
	root.add_child(gs)

	var sfx_script = load("res://scripts/sfx.gd")
	var sfx_node = sfx_script.new()
	sfx_node.name = "SFX"
	root.add_child(sfx_node)

	var main_scene = load("res://scenes/main.tscn")
	var main_instance = main_scene.instantiate()
	root.add_child(main_instance)

	await process_frame
	await process_frame

	var player = main_instance.get_node("Player")
	
	# Test walking into Mesh137 from various angles around the chabutra:
	# Chabutra radius is 5.8m at (0, 0, 0).
	var angles = [0.0, 45.0, 90.0, 135.0, 180.0, 225.0, 270.0, 315.0]
	for a in angles:
		var rad = deg_to_rad(a)
		var start = Vector3(sin(rad) * 7.0, 0.1, cos(rad) * 7.0)
		player.global_position = start
		player.velocity = Vector3.ZERO
		var target = Vector3.ZERO
		print("\n--- Test angle ", a, " from ", start, " to ", target)
		
		var penetrated = false
		for step in range(120):
			var dir = (target - player.global_position)
			dir.y = 0.0
			dir = dir.normalized()
			player.velocity.x = dir.x * player.walk_speed
			player.velocity.z = dir.z * player.walk_speed
			player.move_and_slide()
			
			var dist = player.global_position.distance_to(Vector3.ZERO)
			# If player is inside 5.8m radius while at Y < 0.8:
			if dist < 5.6 and player.global_position.y < 0.8:
				print("PENETRATED INSIDE CHABUTRA at dist: ", dist, " pos: ", player.global_position)
				penetrated = true
				break
		if not penetrated:
			print("Blocked properly at dist: ", player.global_position.distance_to(Vector3.ZERO), " pos: ", player.global_position)
	
	quit(0)
