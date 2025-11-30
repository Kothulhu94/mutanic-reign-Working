@tool
extends EditorScript

## Updates all Sprite_X_Y nodes in overworld.tscn to use AtlasTexture resources
## Run via: File → Run in Godot Editor

func _run():
	print("Starting sprite texture update...")
	
	# Load overworld scene
	var scene_path = "res://overworld.tscn"
	var packed_scene = load(scene_path) as PackedScene
	if not packed_scene:
		push_error("Could not load overworld.tscn")
		return
	
	var root = packed_scene.instantiate()
	if not root:
		push_error("Could not instantiate overworld scene")
		return
	
	# Find Chunker node
	var chunker = _find_node_by_name(root, "Chunker")
	if not chunker:
		push_error("Could not find Chunker node in scene")
		root.queue_free()
		return
	
	print("Found Chunker node, updating sprites...")
	
	var updated_count = 0
	var failed_count = 0
	
	# Update all Sprite_X_Y children
	for child in chunker.get_children():
		if child is Sprite2D and child.name.begins_with("Sprite_"):
			var parts = child.name.split("_")
			if parts.size() >= 3:
				var x = parts[1].to_int()
				var y = parts[2].to_int()
				
				# Load AtlasTexture
				var atlas_path = "res://resources/map_chunks/chunk_%d_%d.tres" % [x, y]
				if ResourceLoader.exists(atlas_path):
					child.texture = load(atlas_path)
					updated_count += 1
				else:
					push_warning("AtlasTexture not found: %s" % atlas_path)
					failed_count += 1
	
	# Save the modified scene
	var new_packed = PackedScene.new()
	var result = new_packed.pack(root)
	if result == OK:
		ResourceSaver.save(new_packed, scene_path)
		print("✓ Updated %d sprites to use AtlasTextures" % updated_count)
		if failed_count > 0:
			print("⚠ Failed to find AtlasTexture for %d sprites" % failed_count)
		print("✓ Saved changes to overworld.tscn")
	else:
		push_error("Failed to save scene")
	
	root.queue_free()

func _find_node_by_name(node: Node, node_name: String) -> Node:
	if node.name == node_name:
		return node
	
	for child in node.get_children():
		var result = _find_node_by_name(child, node_name)
		if result:
			return result
	
	return null
