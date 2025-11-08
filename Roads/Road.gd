class_name Road
extends Resource

## Data class for a single 64x64 road segment
## Stores position, deformed shape, and reference to parent NavigationRegion2D

@export var segment_position: Vector2 = Vector2.ZERO
@export var segment_shape: PackedVector2Array = []
@export var parent_nav_region_path: NodePath = NodePath()
@export var travel_cost: float = 0.7
@export var chunk_coords: Vector2i = Vector2i.ZERO

var parent_nav_region: NavigationRegion2D = null


func _init(
	position: Vector2 = Vector2.ZERO,
	shape: PackedVector2Array = [],
	nav_region_path: NodePath = NodePath(),
	chunk: Vector2i = Vector2i.ZERO
) -> void:
	segment_position = position
	segment_shape = shape
	parent_nav_region_path = nav_region_path
	chunk_coords = chunk


func set_parent_nav_region(region: NavigationRegion2D) -> void:
	parent_nav_region = region
	parent_nav_region_path = region.get_path()


func get_bounds() -> Rect2:
	if segment_shape.size() > 0:
		var min_x: float = segment_shape[0].x
		var max_x: float = segment_shape[0].x
		var min_y: float = segment_shape[0].y
		var max_y: float = segment_shape[0].y

		for vertex in segment_shape:
			min_x = min(min_x, vertex.x)
			max_x = max(max_x, vertex.x)
			min_y = min(min_y, vertex.y)
			max_y = max(max_y, vertex.y)

		return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))

	return Rect2(segment_position, Vector2(64, 64))
