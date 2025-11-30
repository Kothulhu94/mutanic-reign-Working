import re
import os

file_path = "overworld.tscn"
backup_path = "overworld_backup.tscn"

# Create backup if it doesn't exist
if not os.path.exists(backup_path):
    with open(file_path, "r") as f:
        content = f.read()
    with open(backup_path, "w") as f:
        f.write(content)
    print(f"Created backup at {backup_path}")

with open(file_path, "r") as f:
    lines = f.readlines()

new_lines = []
replacements = 0

# Regex to match the chunk texture resource line
# [ext_resource type="Texture2D" uid="uid://..." path="res://chunks/chunk_X_Y.png" id="..."]
pattern = re.compile(r'\[ext_resource type="Texture2D" (uid="[^"]*" )?path="res://chunks/chunk_(\d+)_(\d+)\.png" id="([^"]*)"\]')

for line in lines:
    match = pattern.search(line)
    if match:
        # Extract groups
        uid_part = match.group(1) # might be None
        x = match.group(2)
        y = match.group(3)
        id_part = match.group(4)
        
        # Construct new line
        # We remove the UID so Godot regenerates it or uses the one in the .tres if it exists (but here we are referencing it)
        # Actually, when referencing a .tres, we usually just point to it.
        # [ext_resource type="AtlasTexture" path="res://resources/map_chunks/chunk_X_Y.tres" id="..."]
        
        new_line = f'[ext_resource type="AtlasTexture" path="res://resources/map_chunks/chunk_{x}_{y}.tres" id="{id_part}"]\n'
        new_lines.append(new_line)
        replacements += 1
    else:
        new_lines.append(line)

with open(file_path, "w") as f:
    f.writelines(new_lines)

print(f"Updated {replacements} chunk references in {file_path}")
