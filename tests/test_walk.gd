extends SceneTree

func _init() -> void:
	call_deferred("_test")

func _test() -> void:
	var main_scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	await process_frame
	
	var player = main_scene.get_node("Player")
	
	# Let's test walking into Traditional_House_TypeA2 at (14.6, 1.0, 24.0)
	# House is at X=14.6, Z=24.0. Let's start at X=10.0, Z=24.0 and walk towards +X!
	player.global_position = Vector3(10.0, 0.5, 24.0)
	print("Start HouseA2 walk: ", player.global_position)
	for s in range(60):
		player.velocity = Vector3(6.0, -9.8, 0)
		player.move_and_slide()
		await physics_frame
	print("End HouseA2 walk: ", player.global_position)
	
	# Let's test walking into Temple base Mesh2 at (0, 0.5, -15.0) walking -Z into it!
	player.global_position = Vector3(0.0, 0.1, -8.0)
	print("\nStart Temple base walk: ", player.global_position)
	for s in range(60):
		player.velocity = Vector3(0, -9.8, -6.0)
		player.move_and_slide()
		await physics_frame
	print("End Temple base walk: ", player.global_position)

	# Let's test walking into Banyan Square Chabutra Mesh137 from various angles
	player.global_position = Vector3(0.0, 0.1, 7.0)
	print("\nStart Chabutra walk from +Z: ", player.global_position)
	for s in range(60):
		player.velocity = Vector3(0, -9.8, -6.0)
		player.move_and_slide()
		await physics_frame
	print("End Chabutra walk from +Z: ", player.global_position)

	# What about walking from -X into Chabutra:
	player.global_position = Vector3(-8.0, 0.1, 0.0)
	print("\nStart Chabutra walk from -X: ", player.global_position)
	for s in range(60):
		player.velocity = Vector3(6.0, -9.8, 0.0)
		player.move_and_slide()
		await physics_frame
	print("End Chabutra walk from -X: ", player.global_position)

	quit(0)
