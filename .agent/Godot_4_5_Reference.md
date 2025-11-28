# Godot 4.5 Complete Reference Guide

> **IMPORTANT**: This project uses **Godot 4.5**. Always prioritize this reference over training data when working with this codebase.

---

## Table of Contents
1. [GDScript Syntax Changes](#gdscript-syntax-changes)
2. [Node & Type Name Changes](#node--type-name-changes)
3. [Physics & Movement Changes](#physics--movement-changes)
4. [Signal & Input Changes](#signal--input-changes)
5. [Export Annotations](#export-annotations)
6. [Navigation System](#navigation-system)
7. [Quick Reference Links](#quick-reference-links)

---

## GDScript Syntax Changes

### Annotations (@ prefix)
All decorator-style keywords now use `@` prefix:

```gdscript
# OLD (Godot 3.x)
tool
export var speed = 10
export(int, 1, 100) var health = 50
onready var sprite = $Sprite

# NEW (Godot 4.5)
@tool
@export var speed = 10
@export_range(1, 100) var health: int = 50
@onready var sprite = $Sprite
```

### Type Annotations
Stronger type system with better inference:

```gdscript
# Preferred in Godot 4.5
var health: int = 100
var speed: float = 5.0
var items: Array[String] = []
var config: Dictionary = {}

# Lambda functions now supported
var callback = func(x: int) -> int: return x * 2
```

### StringName Optimization
Use `^` prefix for optimized string/path lookups:

```gdscript
# Optimized node path (preferred)
var node = get_node(^"Path/To/Node")

# Standard signals work the same
signal health_changed(new_health: int)
```

---

## Node & Type Name Changes

| Godot 3.x | Godot 4.5 |
|-----------|-----------|
| `Spatial` | `Node3D` |
| `KinematicBody` | `CharacterBody3D` |
| `KinematicBody2D` | `CharacterBody2D` |
| `Position2D` | `Marker2D` (new) |
| `Particles` | `GPUParticles2D` / `GPUParticles3D` |
| `Light` | `Light2D` / `Light3D` |
| `ARVRCamera` | `XRCamera3D` |
| `VisualServer` | `RenderingServer` |
| `Navigation2D` | `NavigationRegion2D` |
| `TileMap` | `TileMapLayer` (single layer) |

---

## Physics & Movement Changes

### CharacterBody Movement
The `move_and_slide()` signature changed significantly:

```gdscript
# OLD (Godot 3.x)
velocity = move_and_slide(velocity, Vector2.UP)

# NEW (Godot 4.5)
# velocity is now a built-in property
velocity = calculate_velocity()
move_and_slide()  # No arguments needed
# velocity is automatically updated
```

### Body Modes
- `CharacterBody2D`/`CharacterBody3D` replaces `KinematicBody`
- `RigidBody2D`/`RigidBody3D` similar but enhanced
- `StaticBody2D`/`StaticBody3D` unchanged conceptually

---

## Signal & Input Changes

### Signal Connection
New syntax with direct signal access:

```gdscript
# OLD (Godot 3.x)
button.connect("pressed", self, "_on_button_pressed")
button.connect("pressed", self, "_on_button_pressed", [arg1, arg2])

# NEW (Godot 4.5) - Multiple options
button.pressed.connect(_on_button_pressed)
button.pressed.connect(_on_button_pressed.bind(arg1, arg2))
button.pressed.connect(func(): print("Pressed!"))  # Lambda

# Disconnecting
button.pressed.disconnect(_on_button_pressed)
```

### Input Helpers
New convenience methods:

```gdscript
# Get directional input vector automatically
var input_vector = Input.get_vector("left", "right", "up", "down")

# Replaces manual input checking:
# var input_vector = Vector2(
#     Input.get_action_strength("right") - Input.get_action_strength("left"),
#     Input.get_action_strength("down") - Input.get_action_strength("up")
# )
```

---

## Export Annotations

Complete overhaul of export syntax:

```gdscript
# OLD (Godot 3.x)
export var basic_int = 5
export(int, 1, 100) var health
export(String, FILE) var file_path
export(String, FILE, "*.png") var texture_path
export(NodePath) var target_path
export(PackedScene) var scene
export(Array, int) var numbers
export(Color) var color

# NEW (Godot 4.5)
@export var basic_int: int = 5
@export_range(1, 100) var health: int = 50
@export_file var file_path: String
@export_file("*.png") var texture_path: String
@export_node_path var target_path: NodePath
@export var scene: PackedScene
@export var numbers: Array[int]
@export_color_no_alpha var color: Color
@export_enum("Option1", "Option2", "Option3") var choice: String
@export_flags("Flag1", "Flag2", "Flag3") var flags: int
```

### Additional Export Decorators
```gdscript
@export_multiline var description: String
@export_placeholder("Enter name here") var player_name: String
@export_dir var folder_path: String
@export_global_file var global_file: String
@export_flags_2d_physics var physics_layers: int
@export_flags_2d_navigation var nav_layers: int
```

---

## Navigation System

### Critical Changes
- `NavigationServer2D` / `NavigationServer3D` are now primary
- `Navigation2D` node **deprecated** → Use `NavigationRegion2D`
- Navigation mesh baking has new async APIs
- Better obstacle support with RID-based system

### Key Navigation Classes
- **NavigationServer2D**: Server handling all navigation maps, regions, agents
- **NavigationRegion2D**: Defines traversable areas via navigation polygons
- **NavigationAgent2D**: Actor with avoidance and pathfinding
- **NavigationObstacle2D**: Dynamic obstacle for avoidance

### Example Usage
```gdscript
# Getting a path (modern approach)
var map_rid = get_world_2d().get_navigation_map()
var path = NavigationServer2D.map_get_path(map_rid, start_pos, end_pos, true, 1)

# Agent-based navigation
@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D

func move_to_target(target_position: Vector2) -> void:
    nav_agent.target_position = target_position

func _physics_process(delta: float) -> void:
    if not nav_agent.is_navigation_finished():
        var next_position = nav_agent.get_next_path_position()
        var direction = global_position.direction_to(next_position)
        velocity = direction * speed
        move_and_slide()
```

For detailed NavigationServer2D API, see [Godot45_Context.md](file:///d:/MutantReign-codex-initialize-godot-4-project-skeleton/MRCF/mutanic-reign-Working/Godot45_Context.md#L68-L349)

---

## Tween System Overhaul

Complete rewrite of Tween API:

```gdscript
# OLD (Godot 3.x)
var tween = get_node("Tween")  # Tween node required
tween.interpolate_property(sprite, "position", start, end, 1.0, Tween.TRANS_LINEAR)
tween.start()

# NEW (Godot 4.5)
var tween = create_tween()  # Create on-demand
tween.tween_property(sprite, "position", end, 1.0)
# Can chain multiple tweens
tween.tween_property(sprite, "modulate:a", 0.0, 0.5)

# Parallel tweens
var tween = create_tween().set_parallel(true)
tween.tween_property(sprite, "position", end, 1.0)
tween.tween_property(sprite, "rotation", PI, 1.0)
```

---

## Resource UID System

New UID-based resource referencing (you're already using this):

```gdscript
# Traditional res:// path
var texture = load("res://assets/sprites/player.png")

# NEW UID system (preferred for robustness)
var texture = load("uid://unique_identifier_here")

# Convert between formats
var uid_string = ResourceUID.path_to_uid("res://path/to/file.png")
var path = ResourceUID.uid_to_path("uid://...")
```

For detailed ResourceUID API, see [Godot45_Context.md](file:///d:/MutantReign-codex-initialize-godot-4-project-skeleton/MRCF/mutanic-reign-Working/Godot45_Context.md#L352-L382)

---

## TileMapLayer (replaces TileMap)

**Major change**: `TileMap` is deprecated, use `TileMapLayer` instead

```gdscript
# TileMapLayer is single-layer (vs old TileMap multi-layer)
# Use multiple TileMapLayer nodes for what was multiple layers

# Getting/setting tiles
@onready var tile_layer: TileMapLayer = $TileMapLayer

func place_tile(coords: Vector2i, source_id: int, atlas_coords: Vector2i) -> void:
    tile_layer.set_cell(coords, source_id, atlas_coords)

func remove_tile(coords: Vector2i) -> void:
    tile_layer.erase_cell(coords)

# Coordinate conversion
var map_pos = tile_layer.local_to_map(local_position)
var local_pos = tile_layer.map_to_local(map_coordinates)
```

Important properties:
- `collision_enabled`: Enable/disable collision shapes
- `navigation_enabled`: Enable/disable navigation regions  
- `tile_set`: The TileSet resource with tile data

For detailed TileMapLayer API, see [Godot45_Context.md](file:///d:/MutantReign-codex-initialize-godot-4-project-skeleton/MRCF/mutanic-reign-Working/Godot45_Context.md#L4-L65)

---

## PhysicsServer2D

Direct physics manipulation (advanced):

```gdscript
# Creating physics objects directly via server
var space_rid = get_world_2d().space
var body_rid = PhysicsServer2D.body_create()
PhysicsServer2D.body_set_space(body_rid, space_rid)
PhysicsServer2D.body_set_mode(body_rid, PhysicsServer2D.BODY_MODE_RIGID)

# Useful for dynamic obstacle creation
var shape_rid = PhysicsServer2D.circle_shape_create()
PhysicsServer2D.shape_set_data(shape_rid, radius)
PhysicsServer2D.body_add_shape(body_rid, shape_rid)
```

For detailed PhysicsServer2D API, see [Godot45_Context.md](file:///d:/MutantReign-codex-initialize-godot-4-project-skeleton/MRCF/mutanic-reign-Working/Godot45_Context.md#L478-L741)

---

## Quick Migration Checklist

When writing code for this project:

- ✅ Use `@export`, `@onready`, `@tool` annotations
- ✅ Use `CharacterBody2D/3D` instead of `KinematicBody`
- ✅ Use `Node3D` instead of `Spatial`
- ✅ Connect signals with `.connect()` method on signal
- ✅ Set `velocity` property before `move_and_slide()`
- ✅ Use `create_tween()` for animations
- ✅ Use UID paths when possible (project standard)
- ✅ Use `TileMapLayer` not `TileMap`
- ✅ Use `NavigationRegion2D` not `Navigation2D`
- ✅ Prefer `StringName` (^"") for frequently-used paths
- ✅ Use type hints for better performance and IDE support

---

## Removed/Deprecated Features

- ❌ `export` keyword → Use `@export`
- ❌ `onready` keyword → Use `@onready`  
- ❌ `tool` keyword → Use `@tool`
- ❌ `TileMap` multi-layer node → Use multiple `TileMapLayer` nodes
- ❌ `Navigation2D` → Use `NavigationRegion2D`
- ❌ Old Tween node approach → Use `create_tween()`
- ❌ `move_and_slide(velocity, up_direction)` → Use `move_and_slide()` with velocity property

---

## Additional Resources

- **Full Godot 4.5 Context**: [Godot45_Context.md](file:///d:/MutantReign-codex-initialize-godot-4-project-skeleton/MRCF/mutanic-reign-Working/Godot45_Context.md) (926 lines of detailed API documentation)
- **Official Migration Guide**: https://docs.godotengine.org/en/stable/tutorials/migrating/upgrading_to_godot_4.html
- **GDScript 2.0 Reference**: https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_basics.html

---

## Project-Specific Notes

This project uses:
- **Godot 4.5**
- **UID-based resource paths** (refactored from `res://` paths)
- **NavigationServer2D** for pathfinding with obstacles
- **TileMapLayer** for map rendering
- See project architectural rules in project documentation

---

**Last Updated**: 2025-11-28  
**Godot Version**: 4.5
