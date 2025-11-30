from PIL import Image
import os
import json

# Configuration
building_sprites = [
    "AloeFarm.png", "Bakery.png", "CoffeeFarm.png", "CottonFarm.png",
    "FoodTrader.png", "HempFarm.png", "Hub.png", "LuxuryTrader.png",
    "MaterialTrader.png", "MedicalTrader.png", "RabbitHutch.png",
    "Scrapyard.png", "StoneQuarry.png", "Wheat_Farm.png"
]

padding = 2  # Prevent texture bleeding
src_dir = "art_src"
output_atlas = "art_src/buildings_atlas.png"
output_config = "resources/buildings_atlas_config.json"

print("Building sprite atlas from art_src/...")

# Load all sprites
sprites = {}
for filename in building_sprites:
    path = os.path.join(src_dir, filename)
    if os.path.exists(path):
        sprites[filename] = Image.open(path).convert("RGBA")
        print(f"  Loaded: {filename}")
    else:
        print(f"  WARNING: {filename} not found, skipping")

if not sprites:
    print("ERROR: No sprites found!")
    exit(1)

# Calculate atlas size (simple horizontal packing)
total_width = sum(img.width + padding for img in sprites.values())
max_height = max(img.height for img in sprites.values()) + padding * 2

# Create atlas
atlas = Image.new("RGBA", (total_width, max_height), (0, 0, 0, 0))

# Pack sprites and record positions
atlas_config = {}
x_offset = padding

for name, img in sprites.items():
    atlas.paste(img, (x_offset, padding))
    
    atlas_config[name.replace(".png", "")] = {
        "x": x_offset,
        "y": padding,
        "width": img.width,
        "height": img.height
    }
    
    x_offset += img.width + padding

# Ensure output directory exists
os.makedirs("resources", exist_ok=True)

# Save atlas and config
atlas.save(output_atlas)
with open(output_config, "w") as f:
    json.dump(atlas_config, f, indent=2)

print(f"\n✓ Created atlas: {output_atlas} ({total_width}×{max_height})")
print(f"✓ Config saved: {output_config}")
print(f"✓ Packed {len(sprites)} building sprites")
