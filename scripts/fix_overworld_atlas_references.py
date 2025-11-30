#!/usr/bin/env python3
"""
Fix overworld.tscn to use AtlasTexture .tres files instead of individual chunk PNGs
"""
import re
import os
import shutil

# Paths
scene_file = "overworld.tscn"
backup_file = "overworld_backup_original.tscn"

# Create a backup of the original if it doesn't exist
if not os.path.exists(backup_file):
    shutil.copy2(scene_file, backup_file)
    print(f"✓ Created backup: {backup_file}")
else:
    print(f"ℹ Backup already exists: {backup_file}")

# Read the scene file
with open(scene_file, 'r', encoding='utf-8') as f:
    content = f.read()

# Pattern to match chunk PNG ext_resource lines
# Example: [ext_resource type="Texture2D" uid="uid://..." path="res://chunks/chunk_12_7.png" id="127_x2dlj"]
pattern = re.compile(
    r'\[ext_resource type="Texture2D" uid="([^"]*)" path="res://chunks/chunk_(\d+)_(\d+)\.png" id="([^"]*)"\]'
)

replacements = 0
lines = content.split('\n')
new_lines = []

for line in lines:
    match = pattern.search(line)
    if match:
        old_uid = match.group(1)
        x = match.group(2)
        y = match.group(3)
        id_value = match.group(4)
        
        # Create new line referencing the AtlasTexture .tres file
        # We reference it as type AtlasTexture, pointing to the .tres file
        # Note: We DON'T include the uid here - Godot will load it from the .tres file itself
        new_line = f'[ext_resource type="AtlasTexture" path="res://resources/map_chunks/chunk_{x}_{y}.tres" id="{id_value}"]'
        new_lines.append(new_line)
        replacements += 1
        
        if replacements <= 5:  # Show first few replacements
            print(f"  Chunk {x},{y}: {old_uid} -> .tres")
    else:
        new_lines.append(line)

# Join lines back together
new_content = '\n'.join(new_lines)

# Write the updated scene file
with open(scene_file, 'w', encoding='utf-8') as f:
    f.write(new_content)

print(f"\n✓ Updated {replacements} chunk references in {scene_file}")
print(f"✓ Changed from individual PNGs to AtlasTexture .tres files")
print(f"\nNext steps:")
print(f"1. Open Godot and reload the project")
print(f"2. Open overworld.tscn and verify chunks render correctly")
print(f"3. If everything works, you can delete the chunks/ directory")
