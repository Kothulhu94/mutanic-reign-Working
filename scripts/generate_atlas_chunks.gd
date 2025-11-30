@tool
extends EditorScript

func _run():
	var atlas_texture = load("res://assets/themap.png")
	var chunk_size = Vector2i(512, 512)
	var grid_size = Vector2i(16, 16)
	
	# Ensure output directory exists
	DirAccess.make_dir_recursive_absolute("res://resources/map_chunks/")
	
	var count = 0
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			var atlas = AtlasTexture.new()
			atlas.atlas = atlas_texture
			atlas.region = Rect2(
				x * chunk_size.x,
				y * chunk_size.y,
				chunk_size.x,
				chunk_size.y
			)
			
			var save_path = "res://resources/map_chunks/chunk_%d_%d.tres" % [x, y]
			ResourceSaver.save(atlas, save_path)
			count += 1
	
	print("Generated %d AtlasTexture resources in resources/map_chunks/" % count)
	print("Atlas configuration complete! Next: Reload Godot project to import changes.")
