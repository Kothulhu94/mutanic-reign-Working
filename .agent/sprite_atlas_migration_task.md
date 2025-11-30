# Sprite Atlas Migration - AtlasTexture Approach

## Discovery
- [x] Analyze current sprite organization
- [x] Identify map chunk usage (256 chunks in 16x16 grid)
- [x] Identify building sprite usage (14 individual sprites)
- [x] User decision: Keep chunked, use AtlasTexture references

## Planning
- [x] Create implementation plan
- [x] Get user approval on approach

## Map System Migration (AtlasTexture Approach)
- [ ] Configure `assets/themap.png` import for atlas usage
- [ ] Create AtlasTexture resources for each chunk (256 total)
- [ ] Update `overworld.tscn` to use AtlasTexture references
- [ ] Implement minimap rendering from atlas
- [ ] Test map rendering and memory usage
- [ ] Remove old individual chunk PNGs from `chunks/` directory

## Building Sprites Migration  
- [ ] Create building sprite atlas from individual PNGs in `art_src/`
- [ ] Configure AtlasTexture resources for buildings
- [ ] Update building scenes to use atlas references
- [ ] Test building rendering

## Cleanup & Verification
- [ ] Verify import settings for optimal memory
- [ ] Test game performance and draw calls
- [ ] Verify minimap functionality
- [ ] Document new sprite organization
