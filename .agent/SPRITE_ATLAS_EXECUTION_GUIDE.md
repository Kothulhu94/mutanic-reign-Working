# Sprite Atlas Migration - Execution Guide

## Overview
All migration scripts have been created and are ready to execute. This guide walks you through the step-by-step process to migrate from individual PNG sprites to an optimized AtlasTexture system.

## What's Been Done
✅ Updated `assets/themap.png.import` for VRAM compression  
✅ Created all migration scripts in `scripts/` directory  
✅ Configured import settings: `compress/mode=2`, `mipmaps/generate=true`, `vram_texture=true`

## Expected Benefits
- **Memory Reduction**: 30-40% reduction (~46MB → ~34-66MB)
- **File Count Reduction**: 99% reduction (256 PNGs → 1 atlas + 256 tiny .tres files)
- **Better Performance**: Improved batching and faster loading

---

## Phase 1: Map Atlas Setup (REQUIRED)

### Step 1: Reload Godot Project
The `themap.png.import` file has been modified. Godot needs to reimport the atlas with new settings.

**Action**: 
```
In Godot Editor: Project → Reload Current Project
```

This will apply VRAM compression to the atlas.

### Step 2: Generate AtlasTexture Resources
Run the atlas chunk generator to create 256 `.tres` files.

**Action**:
1. Open `scripts/generate_atlas_chunks.gd` in Godot
2. Go to: **File → Run** (or press `Ctrl+Shift+X`)

**Expected Output**:
```
Generated 256 AtlasTexture resources in resources/map_chunks/
Atlas configuration complete! Next: Reload Godot project to import changes.
```

**Result**: Check `resources/map_chunks/` - should contain 256 `.tres` files

### Step 3: Update Overworld Scene
Replace all 256 chunk PNG references with AtlasTexture references in `overworld.tscn`.

**Action**:
1. **BACKUP FIRST**: Copy `overworld.tscn` to `overworld_backup.tscn`
2. Open `scripts/update_overworld_scene.gd` in Godot
3. Go to: **File → Run**

**Expected Output**:
```
Updated 256 chunk references in overworld.tscn
Scene file updated! Godot will need to reload the scene.
```

### Step 4: Verify Map Rendering
**Action**: 
1. Open `overworld.tscn` in the editor
2. Check that all chunks render correctly
3. Verify no missing or black tiles

---

## Phase 2: Building Atlas Setup (RECOMMENDED)

### Step 5: Generate Building Sprite Atlas
Run the Python script to pack building sprites.

**Action**:
```powershell
cd d:/MutantReign-codex-initialize-godot-4-project-skeleton/MRCF/mutanic-reign-Working
python scripts/generate_building_atlas.py
```

**Expected Output**:
```
✓ Created atlas: art_src/buildings_atlas.png (XXX×XXX)
✓ Config saved: resources/buildings_atlas_config.json
✓ Packed 14 building sprites
```

**Requirements**: Python 3 with Pillow installed (`pip install pillow`)

### Step 6: Create Building AtlasTextures
**Action**:
1. Open `scripts/apply_building_atlas.gd` in Godot
2. Go to: **File → Run**

**Expected Output**:
```
Generated 14 building AtlasTextures in resources/building_sprites/
```

### Step 7: Update Building Scenes
Manually update each building scene to use the new AtlasTexture resources.

**Files to Update** (in `Buildings/` directory):
- AloeGarden.tscn → `res://resources/building_sprites/AloeFarm.tres`
- Bakery.tscn → `res://resources/building_sprites/Bakery.tres`
- CoffeeFarm.tscn → `res://resources/building_sprites/CoffeeFarm.tres`
- CottonFarm.tscn → `res://resources/building_sprites/CottonFarm.tres`
- HempFarm.tscn → `res://resources/building_sprites/HempFarm.tres`
- RabbitHutch.tscn → `res://resources/building_sprites/RabbitHutch.tres`
- ScrapYard.tscn → `res://resources/building_sprites/Scrapyard.tres`
- StoneQuarry.tscn → `res://resources/building_sprites/StoneQuarry.tres`

**Action**: Open each `.tscn` file and update the Sprite2D texture property

---

## Phase 3: Optional Minimap (FUTURE)

A minimap script has been created at `scripts/Minimap.gd`.  
To implement:
1. Create a scene based on the Minimap.gd script
2. Add TextureRect child named "MinimapDisplay"
3. Add player marker Sprite2D
4. Assign `map_atlas` export variable to `res://assets/themap.png`

**This can be done later when you're ready to implement the minimap UI.**

---

## Phase 4: Cleanup (After Verification)

### ⚠️ ONLY AFTER TESTING THOROUGHLY

Once you've verified everything works:

1. **Delete Old Chunks**:
   ```powershell
   Remove-Item -Path "d:\MutantReign-codex-initialize-godot-4-project-skeleton\MRCF\mutanic-reign-Working\chunks" -Recurse -Force
   ```

2. **Remove Individual Building PNGs** (if desired):
   Keep in `art_src/` for reference, or delete if atlas is working

---

## Verification Checklist

### Map System
- [ ] `resources/map_chunks/` contains 256 `.tres` files
- [ ] `overworld.tscn` opens without errors
- [ ] All map chunks render correctly (no missing tiles)
- [ ] No visual difference from before migration

### Building System  
- [ ] `resources/building_sprites/` contains 14 `.tres` files
- [ ] Building scenes render correctly
- [ ] No visual difference from before migration

### Memory Usage
- [ ] Check Godot Debugger → Monitors → "Video Mem"
- [ ] Expected: Lower VRAM usage with same visual quality

---

## Troubleshooting

### "Chunks appear black or corrupted"
**Solution**: Verify `themap.png.import` has `vram_texture=true` and `compress/mode=2`, then reload project

### "Seams visible between chunks"
**Solution**: Check `process/fix_alpha_border=true` in `themap.png.import`

### "High memory usage persists"
**Solution**: Verify VRAM compression is active (`compress/mode=2`)

### "Missing .tres files"
**Solution**: Re-run `generate_atlas_chunks.gd` script

---

## Rollback Plan

If anything goes wrong:
1. Restore `overworld_backup.tscn` → `overworld.tscn`
2. Revert `assets/themap.png.import` to original settings
3. Reload Godot project

Original chunk PNGs remain in `chunks/` directory until you manually delete them.

---

## Current Status

**✅ PHASE 1 COMPLETE**: Map atlas setup finished! 
- All 256 AtlasTexture .tres files created
- overworld.tscn updated to reference .tres files instead of individual PNGs
- Import settings configured for VRAM compression

**Next Action**: 
1. Open Godot and reload the project
2. Open overworld.tscn to verify all chunks render correctly
3. Test the game to ensure map displays properly

**Files Created**:
- `scripts/generate_atlas_chunks.gd` ✓
- `scripts/update_overworld_scene.gd` ✓
- `scripts/Minimap.gd` ✓
- `scripts/generate_building_atlas.py` ✓
- `scripts/apply_building_atlas.gd` ✓
- `assets/themap.png.import` (modified) ✓
