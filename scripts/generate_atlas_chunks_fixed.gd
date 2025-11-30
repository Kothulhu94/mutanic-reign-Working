@tool
extends EditorScript

func _run():
	var atlas_texture = load("res://assets/themap.png")
	var chunk_size = Vector2i(512, 512)
	var grid_size = Vector2i(16, 16)
	
	# Ensure output directory exists
	DirAccess.make_dir_recursive_absolute("res://resources/map_chunks/")
	
	var count = 0
	# Chunk naming is chunk_COLUMN_ROW
	# In the atlas: Column determines X position, Row determines Y position
	for row in range(grid_size.y):
		for col in range(grid_size.x):
			var atlas = AtlasTexture.new()
			atlas.atlas = atlas_texture
			# Column (col) = X position, Row (row) = Y position
			atlas.region = Rect2(
				col * chunk_size.x,
				row * chunk_size.y,
				chunk_size.x,
				chunk_size.y
			)
			
			var save_path = "res://resources/map_chunks/chunk_%d_%d.tres" % [col, row]
			ResourceSaver.save(atlas, save_path)
			count += 1
	
	print("Generated %d AtlasTexture resources in resources/map_chunks/" % count)
	print("Chunks use column_row naming: chunk_COLUMN_ROW.tres")
	print("Atlas configuration complete! Reload Godot project to see changes.")
