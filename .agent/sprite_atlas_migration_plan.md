# Sprite Atlas Migration Implementation Plan

## Overview

Migrate from individual PNG sprites to AtlasTexture-based system for optimal memory usage while maintaining chunked map architecture.

### Current State
- **Map Chunks**: 256 individual PNG files (16x16 grid, 512x512px each) in `chunks/` directory
- **Source Atlas**: `assets/themap.png` (8192x8192px) - currently using no VRAM compression
- **Building Sprites**: 14 individual PNG files in `art_src/` directory
- **Current Usage**: `overworld.tscn` references all 256 chunk files individually as Sprite2D textures

### Goals
1. **Memory Efficiency**: Single atlas texture loaded once, referenced 256 times via AtlasTexture
2. **Chunked Architecture**: Maintain chunk-based streaming capability
3. **Minimap Support**: Enable minimap rendering from the atlas
4. **Better Batching**: Reduce draw calls through atlas usage

## Proposed Changes

### Component 1: Map Atlas Configuration

#### [MODIFY] [themap.png.import](file:///d:/MutantReign-codex-initialize-godot-4-project-skeleton/MRCF/mutanic-reign-Working/assets/themap.png.import)

**Current Settings:**
```ini
compress/mode=0           # Lossless (no VRAM compression!)
mipmaps/generate=false
vram_texture=false
```

**Updated Settings for Memory Optimization:**
```ini
compress/mode=2           # VRAM Compressed (S3TC/BPTC)
mipmaps/generate=true     # Enable mipmaps for scaling
vram_texture=true         # Store in VRAM
```

**Why:** This reduces memory usage significantly. The atlas is 8192×8192, which at 32-bit RGBA is 256MB uncompressed. VRAM compression can reduce this to ~32-64MB.

---

### Component 2: AtlasTexture Resource Generation

#### [NEW] `scripts/generate_atlas_chunks.gd` (Editor Tool Script)

Create a GDScript tool to generate 256 AtlasTexture resources automatically:

```gdscript
@tool
extends EditorScript

func _run():
    var atlas_texture = load("res://assets/themap.png")
    var chunk_size = Vector2i(512, 512)
    var grid_size = Vector2i(16, 16)
    
    # Ensure output directory exists
    DirAccess.make_dir_recursive_absolute("res://resources/map_chunks/")
    
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
            print("Created: ", save_path)
    
    print("Generated 256 AtlasTexture resources")
```

**To Run:**
1. Save script to `scripts/generate_atlas_chunks.gd`
2. Open in Godot editor
3. Go to File → Run (or press Ctrl+Shift+X)
4. This creates `resources/map_chunks/chunk_X_Y.tres` files

**Result:** 256 `.tres` AtlasTexture resources, each ~200 bytes (vs ~150KB per PNG)

---

### Component 3: Overworld Scene Update

#### [MODIFY] [overworld.tscn](file:///d:/MutantReign-codex-initialize-godot-4-project-skeleton/MRCF/mutanic-reign-Working/overworld.tscn)

**Manual Update Required:**
Replace all 256 individual chunk texture references with AtlasTexture resources.

**Before:**
```gdscript
[ext_resource type="Texture2D" uid="uid://nwu1dekjdwcn" path="res://chunks/chunk_0_0.png" id="3_mb8ku"]
```

**After:**
```gdscript
[ext_resource type="AtlasTexture" path="res://resources/map_chunks/chunk_0_0.tres" id="3_mb8ku"]
```

**Automated Approach (GDScript tool):**

```gdscript
@tool
extends EditorScript

func _run():
    var scene = load("res://overworld.tscn")
    var root = scene.instantiate()
    
    # Find all Sprite2D nodes with chunk textures
    for node in get_all_children(root):
        if node is Sprite2D and node.texture:
            var tex_path = node.texture.resource_path
            if "chunks/chunk_" in tex_path:
                # Extract chunk coordinates
                var coords = tex_path.get_file().trim_suffix(".png").replace("chunk_", "")
                var atlas_path = "res://resources/map_chunks/chunk_%s.tres" % coords
                
                if ResourceLoader.exists(atlas_path):
                    node.texture = load(atlas_path)
                    print("Updated: ", node.name, " → ", atlas_path)
    
    # Save modified scene
    var packed = PackedScene.new()
    packed.pack(root)
    ResourceSaver.save(packed, "res://overworld.tscn")
    print("Overworld scene updated!")

func get_all_children(node):
    var nodes = [node]
    for child in node.get_children():
        nodes.append_array(get_all_children(child))
    return nodes
```

---

### Component 4: Minimap Implementation

#### [NEW] `scripts/Minimap.gd`

```gdscript
extends Control

@export var map_atlas: Texture2D
@export var player_marker: Node2D
@export var zoom_level: float = 0.1  # 10% of original size

var minimap_texture: ImageTexture

func _ready():
    create_minimap()

func create_minimap():
    # Load the full map atlas
    var atlas_image = map_atlas.get_image()
    
    # Scale down for minimap (8192×8192 → 819×819 at 0.1 zoom)
    var minimap_size = Vector2i(
        int(atlas_image.get_width() * zoom_level),
        int(atlas_image.get_height() * zoom_level)
    )
    atlas_image.resize(minimap_size.x, minimap_size.y)
    
    # Create texture for minimap
    minimap_texture = ImageTexture.create_from_image(atlas_image)
    
    # Display in UI (assuming TextureRect child)
    var minimap_display = $MinimapDisplay as TextureRect
    if minimap_display:
        minimap_display.texture = minimap_texture

func _process(_delta):
    # Update player position marker
    if player_marker:
        var world_pos = player_marker.global_position
        var minimap_pos = world_pos * zoom_level
        $PlayerMarker.position = minimap_pos
```

#### [NEW] `scenes/Minimap.tscn`

Scene structure:
```
Control (Minimap)
├── TextureRect (MinimapDisplay)
│   └── texture: (set at runtime)
└── Sprite2D (PlayerMarker)
    └── texture: player_icon.png
```

---

### Component 5: Building Sprite Atlas

#### [NEW] `scripts/generate_building_atlas.py`

Python script to pack building sprites:

```python
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

# Load all sprites
sprites = {}
for filename in building_sprites:
    path = os.path.join(src_dir, filename)
    sprites[filename] = Image.open(path).convert("RGBA")

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

# Save atlas and config
atlas.save(output_atlas)
with open(output_config, "w") as f:
    json.dump(atlas_config, f, indent=2)

print(f"Created atlas: {output_atlas} ({total_width}×{max_height})")
print(f"Config saved: {output_config}")
```

**To Run:**
```bash
cd d:/MutantReign-codex-initialize-godot-4-project-skeleton/MRCF/mutanic-reign-Working
python scripts/generate_building_atlas.py
```

#### [NEW] `scripts/apply_building_atlas.gd` (Editor Tool)

Automatically create AtlasTexture resources from config:

```gdscript
@tool
extends EditorScript

func _run():
    var config_file = FileAccess.open("res://resources/buildings_atlas_config.json", FileAccess.READ)
    var config = JSON.parse_string(config_file.get_as_text())
    config_file.close()
    
    var atlas_texture = load("res://art_src/buildings_atlas.png")
    
    DirAccess.make_dir_recursive_absolute("res://resources/building_sprites/")
    
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
        print("Created: ", save_path)
    
    print("Generated building AtlasTextures")
```

#### [MODIFY] Building Scenes

Update all building `.tscn` files to use new AtlasTexture resources:
- [AloeGarden.tscn](file:///d:/MutantReign-codex-initialize-godot-4-project-skeleton/MRCF/mutanic-reign-Working/Buildings/AloeGarden.tscn) → `res://resources/building_sprites/AloeFarm.tres`
- [Bakery.tscn](file:///d:/MutantReign-codex-initialize-godot-4-project-skeleton/MRCF/mutanic-reign-Working/Buildings/Bakery.tscn) → `res://resources/building_sprites/Bakery.tres`
- [CoffeeFarm.tscn](file:///d:/MutantReign-codex-initialize-godot-4-project-skeleton/MRCF/mutanic-reign-Working/Buildings/CoffeeFarm.tscn) → `res://resources/building_sprites/CoffeeFarm.tres`
- [CottonFarm.tscn](file:///d:/MutantReign-codex-initialize-godot-4-project-skeleton/MRCF/mutanic-reign-Working/Buildings/CottonFarm.tscn) → `res://resources/building_sprites/CottonFarm.tres`
- [HempFarm.tscn](file:///d:/MutantReign-codex-initialize-godot-4-project-skeleton/MRCF/mutanic-reign-Working/Buildings/HempFarm.tscn) → `res://resources/building_sprites/HempFarm.tres`
- [RabbitHutch.tscn](file:///d:/MutantReign-codex-initialize-godot-4-project-skeleton/MRCF/mutanic-reign-Working/Buildings/RabbitHutch.tscn) → `res://resources/building_sprites/RabbitHutch.tres`
- [ScrapYard.tscn](file:///d:/MutantReign-codex-initialize-godot-4-project-skeleton/MRCF/mutanic-reign-Working/Buildings/ScrapYard.tscn) → `res://resources/building_sprites/Scrapyard.tres`
- [StoneQuarry.tscn](file:///d:/MutantReign-codex-initialize-godot-4-project-skeleton/MRCF/mutanic-reign-Working/Buildings/StoneQuarry.tscn) → `res://resources/building_sprites/StoneQuarry.tres`

---

## Implementation Order

### Phase 1: Map Atlas Setup
1. Update `assets/themap.png.import` settings
2. Reimport texture in Godot (Project → Reload Current Project)
3. Run `generate_atlas_chunks.gd` editor script
4. Verify 256 `.tres` files created in `resources/map_chunks/`

### Phase 2: Overworld Update
5. Backup `overworld.tscn` 
6. Run overworld update script or manually replace references
7. Test map rendering in editor

### Phase 3: Minimap
8. Create `Minimap.gd` and `Minimap.tscn`
9. Integrate into game UI
10. Test minimap functionality

### Phase 4: Building Atlas
11. Run `generate_building_atlas.py`
12. Run `apply_building_atlas.gd`
13. Update building scene files
14. Test building rendering

### Phase 5: Cleanup
15. Delete `chunks/` directory (backup first!)
16. Remove unused individual building PNGs from `art_src/`
17. Final testing and performance profiling

---

## Verification Plan

### Memory Usage Test
**Before:**
```
Map: 256 × ~180KB = ~46MB (individual PNGs)
Buildings: 14 × ~150KB = ~2MB
Total: ~48MB
```

**After (Expected):**
```
Map Atlas: ~32-64MB (VRAM compressed)
Building Atlas: ~2MB (single texture)
.tres files: 256 × 200 bytes = ~50KB
Total: ~34-66MB (30-40% reduction + better VRAM usage)
```

**How to Verify:**
1. Open Godot Debugger → Monitors
2. Check "Video Mem" before and after
3. Expected: Lower VRAM usage, same visual quality

### Draw Call Test
**Expected Improvement:**
- Buildings: 14 draw calls → 1 draw call (if using same material)
- Map: Chunks still render individually but with better batching

**How to Verify:**
1. Run game with profiler (Debug → Profiler)
2. Check "Raster" section for draw calls
3. Buildings should batch if using same atlas

### Visual Quality Test
1. Open `overworld.tscn` in editor - verify no missing chunks
2. Run game and pan across entire map - check for seams or artifacts
3. Verify buildings look identical to original
4. Test minimap rendering

### Minimap Test
1. Open minimap in game
2. Move player around
3. Verify minimap updates correctly
4. Check performance (minimap should not cause lag)

---

## Troubleshooting

### Issue: Chunks appear black or corrupted
**Solution:** Check `themap.png.import` - ensure `vram_texture=true` and reimport

### Issue: Seams visible between chunks
**Solution:** Enable `process/fix_alpha_border=true` in import settings

### Issue: Minimap is blurry
**Solution:** Adjust `zoom_level` in `Minimap.gd` or enable mipmaps

### Issue: High memory usage persists
**Solution:** Verify VRAM compression is active (`compress/mode=2`)

---

## Expected Benefits

✅ **30-40% memory reduction** through VRAM compression  
✅ **99% reduction in individual file count** (256 PNGs → 1 atlas + 256 tiny .tres)  
✅ **Better batching** for building sprites  
✅ **Minimap support** from single atlas texture  
✅ **Maintained chunk architecture** for streaming/culling  
✅ **Faster project load times** (fewer files to import)
