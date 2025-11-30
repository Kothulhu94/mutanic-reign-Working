@tool
extends EditorScript

func _run():
	# Load the scene file as text
	var file = FileAccess.open("res://overworld.tscn", FileAccess.READ)
	if not file:
		push_error("Could not open overworld.tscn")
		return
	
	var content = file.get_as_text()
	file.close()
	
	# Replace chunk PNG references with AtlasTexture references
	var modified_content = content
	var replacements = 0
	
	# Pattern to match chunk texture resources
	# Example: [ext_resource type="Texture2D" uid="uid://xyz" path="res://chunks/chunk_0_0.png" id="123"]
	# We'll replace these line by line
	
	var lines = modified_content.split("\n")
	var new_lines = []
	
	for line in lines:
		if "ext_resource" in line and "chunks/chunk_" in line and ".png" in line:
			# Extract chunk coordinates from path
			var regex = RegEx.new()
			regex.compile("chunks/chunk_(\\d+)_(\\d+)\\.png")
			var result = regex.search(line)
			
			if result:
				var x = result.get_string(1)
				var y = result.get_string(2)
				
				# Replace Texture2D with AtlasTexture and update path
				var new_line = line.replace("type=\"Texture2D\"", "type=\"AtlasTexture\"")
				new_line = new_line.replace("chunks/chunk_%s_%s.png" % [x, y],
											"resources/map_chunks/chunk_%s_%s.tres" % [x, y])
				# Remove uid as it will be regenerated
				var uid_regex = RegEx.new()
				uid_regex.compile("uid=\"[^\"]*\" ")
				new_line = uid_regex.sub(new_line, "")
				
				new_lines.append(new_line)
				replacements += 1
			else:
				new_lines.append(line)
		else:
			new_lines.append(line)
	
	modified_content = "\n".join(new_lines)
	
	# Save modified content
	file = FileAccess.open("res://overworld.tscn", FileAccess.WRITE)
	if not file:
		push_error("Could not write to overworld.tscn")
		return
	
	file.store_string(modified_content)
	file.close()
	
	print("Updated %d chunk references in overworld.tscn" % replacements)
	print("Scene file updated! Godot will need to reload the scene.")
