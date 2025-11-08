class_name NavMeshModifier
extends Object

## Static utility class for carving road segments into NavigationPolygon geometry
## Uses Geometry2D for boolean operations and NavigationServer2D for mesh updates


static func carve_segment_into_region(
	segment_polygon: PackedVector2Array,
	nav_region: NavigationRegion2D
) -> void:
	if nav_region == null or nav_region.navigation_polygon == null:
		push_error("NavMeshModifier: Invalid NavigationRegion2D or NavigationPolygon")
		return

	if segment_polygon.size() < 3:
		push_error("NavMeshModifier: Segment polygon must have at least 3 vertices")
		return

	var nav_poly: NavigationPolygon = nav_region.navigation_polygon
	var outline_count: int = nav_poly.get_outline_count()
	var new_outlines: Array[PackedVector2Array] = []

	for i in range(outline_count):
		var outline: PackedVector2Array = nav_poly.get_outline(i)
		var clipped_polygons: Array[PackedVector2Array] = Geometry2D.clip_polygons(
			outline,
			segment_polygon
		)

		for clipped_poly in clipped_polygons:
			if clipped_poly.size() >= 3 and _get_polygon_area(clipped_poly) > 1.0:
				new_outlines.append(clipped_poly)

	nav_poly.clear()

	for outline in new_outlines:
		nav_poly.add_outline(outline)

	nav_region.navigation_polygon = nav_poly
	nav_region.navigation_layers = 4

	_force_navmesh_update(nav_region)


static func deform_segment_to_boundary(
	segment_start: Vector2,
	segment_end: Vector2,
	boundary_polygon: PackedVector2Array
) -> PackedVector2Array:
	var segment_rect: PackedVector2Array = _create_segment_rect(segment_start, segment_end)

	if boundary_polygon.size() < 3:
		return segment_rect

	var intersected_polygons: Array[PackedVector2Array] = Geometry2D.intersect_polygons(
		segment_rect,
		boundary_polygon
	)

	if intersected_polygons.size() > 0:
		return intersected_polygons[0]

	return segment_rect


static func get_intersecting_polygon_index(
	segment_rect: Rect2,
	nav_region: NavigationRegion2D
) -> int:
	if nav_region == null or nav_region.navigation_polygon == null:
		return -1

	var nav_poly: NavigationPolygon = nav_region.navigation_polygon
	var segment_center: Vector2 = segment_rect.position + segment_rect.size * 0.5

	for i in range(nav_poly.get_outline_count()):
		var outline: PackedVector2Array = nav_poly.get_outline(i)
		if Geometry2D.is_point_in_polygon(segment_center, outline):
			return i

	return -1


static func is_segment_on_water_layer(
	segment_rect: Rect2,
	nav_region: NavigationRegion2D
) -> bool:
	if nav_region == null:
		return false

	return (nav_region.navigation_layers & 2) != 0


static func _create_segment_rect(start: Vector2, end: Vector2) -> PackedVector2Array:
	var direction: Vector2 = (end - start).normalized()
	var perpendicular: Vector2 = Vector2(-direction.y, direction.x) * 32.0

	return PackedVector2Array([
		start + perpendicular,
		end + perpendicular,
		end - perpendicular,
		start - perpendicular
	])


static func _get_polygon_area(polygon: PackedVector2Array) -> float:
	var area: float = 0.0
	var n: int = polygon.size()

	for i in range(n):
		var j: int = (i + 1) % n
		area += polygon[i].x * polygon[j].y
		area -= polygon[j].x * polygon[i].y

	return abs(area * 0.5)


static func _force_navmesh_update(nav_region: NavigationRegion2D) -> void:
	if not nav_region.enabled:
		return

	var map_rid: RID = nav_region.get_navigation_map()
	if map_rid.is_valid():
		NavigationServer2D.map_force_update(map_rid)
