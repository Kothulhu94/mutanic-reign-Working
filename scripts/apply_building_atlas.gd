@tool
extends EditorScript

func _run():
	var config_path = "res://resources/buildings_atlas_config.json"
	
	if not FileAccess.file_exists(config_path):
		push_error("Config file not found: %s" % config_path)
		push_error("Run generate_building_atlas.py first!")
		return
	
	var config_file = FileAccess.open(config_path, FileAccess.READ)
	if not config_file:
		push_error("Could not open config file")
		return
	
	var json = JSON.new()
	var parse_result = json.parse(config_file.get_as_text())
	config_file.close()
	
	if parse_result != OK:
		push_error("Failed to parse JSON config")
		return
	
	var config = json.data
	var atlas_texture = load("res://art_src/buildings_atlas.png")
	
	if not atlas_texture:
		push_error("Buildings atlas not found at res://art_src/buildings_atlas.png")
		return
	
	DirAccess.make_dir_recursive_absolute("res://resources/building_sprites/")
	
	var count = 0
	for building_name in config:
		var data = config[building_name]
		
		var atlas = AtlasTexture.new()
		atlas.atlas = atlas_texture
		atlas.region = Rect2(
			data["x"], data["y"],
			data["width"], data["height"]
		)
		
		var save_path = "res://resources/building_sprites/%s.tres" % building_name
		ResourceSaver.save(atlas, save_path)
		count += 1
	
	print("Generated %d building AtlasTextures in resources/building_sprites/" % count)
