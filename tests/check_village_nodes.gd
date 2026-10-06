extends SceneTree

func _init() -> void:
	call_deferred("_inspect")

func _inspect() -> void:
	var main_scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	await process_frame
	
	print("=== VILLAGE ENVIRONMENT INSPECTION ===")
	var env = main_scene.get_node("VillageEnvironment/Model/Indian_Village_Assembled")
	for group in env.get_children():
		print("\n--- GROUP: ", group.name, " ---")
		_inspect_group(group)
	quit(0)

func _inspect_group(node: Node, depth: int = 1) -> void:
	if node is MeshInstance3D and node.mesh:
		var has_col = false
		for c in node.get_children():
			if c is StaticBody3D:
				has_col = true
				break
		var aabb = node.mesh.get_aabb()
		var g_pos = node.global_position
		print("  ".repeat(depth), "- Mesh: ", node.name, " has_col: ", has_col, " pos: ", g_pos, " aabb: ", aabb)
	for child in node.get_children():
		if not (child is StaticBody3D):
			_inspect_group(child, depth + 1)
