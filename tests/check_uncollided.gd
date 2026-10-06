extends SceneTree

func _init() -> void:
	call_deferred("_inspect")

func _inspect() -> void:
	var main_scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	
	print("=== GROUP 2_ ENTRANCE & BOUNDARY ===")
	var node2 = main_scene.get_node("VillageEnvironment/Model/Indian_Village_Assembled/2_ 🚪 Entrance & Boundary")
	_inspect_node(node2)
	quit(0)

func _inspect_node(node: Node) -> void:
	if node is MeshInstance3D and node.mesh:
		var has_col = false
		for c in node.get_children():
			if c is StaticBody3D: has_col = true
		var mat = node.mesh.surface_get_material(0)
		print(node.name, " parent: ", node.get_parent().name, " col: ", has_col, " pos: ", node.global_position, " aabb: ", node.mesh.get_aabb(), " col: ", mat.albedo_color if mat is BaseMaterial3D else "")
	for c in node.get_children():
		_inspect_node(c)
