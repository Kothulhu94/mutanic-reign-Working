class_name RoadNetwork
extends Resource

## Container for one complete road placement (multiple segments across chunks)
## Handles carving, saving, and tracking of modified NavigationRegion2D nodes

@export var network_id: StringName = StringName()
@export var segments: Array[Road] = []
@export var created_at: float = 0.0

var _nav_regions_modified: Dictionary = {}


func _init() -> void:
	network_id = StringName(str(Time.get_unix_time_from_system()))
	created_at = Time.get_unix_time_from_system()


func add_segment(segment: Road, nav_region: NavigationRegion2D) -> void:
	segments.append(segment)
	segment.set_parent_nav_region(nav_region)
	_nav_regions_modified[nav_region.get_path()] = nav_region


func carve_all_segments() -> void:
	for segment in segments:
		if segment.parent_nav_region == null:
			continue

		var deformed_shape: PackedVector2Array = _get_segment_shape(segment)
		NavMeshModifier.carve_segment_into_region(deformed_shape, segment.parent_nav_region)


func get_segment_count() -> int:
	return segments.size()


func save_network(filepath: String) -> void:
	var error: Error = ResourceSaver.save(self, filepath)
	if error != OK:
		push_error("Failed to save RoadNetwork to %s: Error %d" % [filepath, error])


func _get_segment_shape(segment: Road) -> PackedVector2Array:
	if segment.segment_shape.size() > 0:
		return segment.segment_shape

	return _make_rect(segment.segment_position)


func _make_rect(position: Vector2) -> PackedVector2Array:
	return PackedVector2Array([
		position,
		position + Vector2(64, 0),
		position + Vector2(64, 64),
		position + Vector2(0, 64)
	])
