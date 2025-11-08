class_name RoadBuilder
extends Node

## Handles player interaction for road building
## Drag-click placement, ghost preview, validation, and confirmation

@export var segment_size: float = 64.0
@export var segment_preview_color_valid: Color = Color(0.0, 1.0, 0.0, 0.5)
@export var segment_preview_color_invalid: Color = Color(1.0, 0.0, 0.0, 0.5)

signal building_started()
signal building_cancelled()
signal building_confirmed(network: RoadNetwork)

var _is_building: bool = false
var _is_dragging: bool = false
var _current_segments: Array[Road] = []
var _preview_polygons: Array[Polygon2D] = []
var _path_points: Array[Vector2] = []
var _overworld: Node2D = null
var _camera: Camera2D = null
var _click_count: int = 0
var _last_click_time: float = 0.0
var _double_click_threshold: float = 0.3


func initialize(overworld: Node2D, camera: Camera2D) -> void:
	_overworld = overworld
	_camera = camera


func _input(event: InputEvent) -> void:
	if not _is_building:
		if Input.is_action_just_pressed("build_road"):
			_start_build_mode()
		return

	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton

		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			_handle_left_click()

		elif mouse_event.button_index == MOUSE_BUTTON_RIGHT and mouse_event.pressed:
			_cancel_build_mode()

	if event is InputEventMouseMotion and _is_building:
		_update_preview()


func _handle_left_click() -> void:
	var current_time: float = Time.get_ticks_msec() / 1000.0
	var is_double_click: bool = (current_time - _last_click_time) < _double_click_threshold

	_last_click_time = current_time

	if is_double_click:
		_confirm_build_mode()
		return

	var mouse_pos: Vector2 = _get_world_mouse_position()

	if _path_points.size() == 0:
		_path_points.append(mouse_pos)
		_is_dragging = true
	else:
		_path_points.append(mouse_pos)


func _start_build_mode() -> void:
	_is_building = true
	_is_dragging = false
	_current_segments.clear()
	_path_points.clear()
	_clear_preview_polygons()
	get_tree().paused = true
	building_started.emit()


func _update_preview() -> void:
	if not _is_building or _overworld == null:
		return

	var mouse_pos: Vector2 = _get_world_mouse_position()
	_clear_preview_polygons()

	if _path_points.size() == 0:
		_create_single_segment_preview(mouse_pos)
	else:
		var preview_points: Array[Vector2] = _path_points.duplicate()
		preview_points.append(mouse_pos)
		_create_path_preview(preview_points)


func _create_single_segment_preview(position: Vector2) -> void:
	var segment_rect: Rect2 = Rect2(position - Vector2(32, 32), Vector2(64, 64))
	var is_valid: bool = _is_position_valid(position)
	_create_preview_polygon(segment_rect, is_valid)


func _create_path_preview(points: Array[Vector2]) -> void:
	for i in range(points.size() - 1):
		var start: Vector2 = points[i]
		var end: Vector2 = points[i + 1]
		var distance: float = start.distance_to(end)
		var segment_count: int = max(1, int(distance / segment_size))

		for j in range(segment_count):
			var t: float = float(j) / float(segment_count)
			var segment_pos: Vector2 = start.lerp(end, t)
			var is_valid: bool = _is_position_valid(segment_pos)
			var segment_rect: Rect2 = Rect2(segment_pos - Vector2(32, 32), Vector2(64, 64))
			_create_preview_polygon(segment_rect, is_valid)


func _create_preview_polygon(rect: Rect2, is_valid: bool) -> void:
	var polygon: Polygon2D = Polygon2D.new()
	polygon.polygon = PackedVector2Array([
		rect.position,
		rect.position + Vector2(rect.size.x, 0),
		rect.position + rect.size,
		rect.position + Vector2(0, rect.size.y)
	])
	polygon.color = segment_preview_color_valid if is_valid else segment_preview_color_invalid
	_overworld.add_child(polygon)
	_preview_polygons.append(polygon)


func _is_position_valid(position: Vector2) -> bool:
	var nav_region: NavigationRegion2D = _get_nav_region_at_position(position)

	if nav_region == null:
		return false

	if NavMeshModifier.is_segment_on_water_layer(Rect2(position - Vector2(32, 32), Vector2(64, 64)), nav_region):
		return false

	return true


func _confirm_build_mode() -> void:
	if _path_points.size() < 1:
		_cancel_build_mode()
		return

	var mouse_pos: Vector2 = _get_world_mouse_position()
	_path_points.append(mouse_pos)

	_current_segments.clear()

	for i in range(_path_points.size() - 1):
		var start: Vector2 = _path_points[i]
		var end: Vector2 = _path_points[i + 1]
		var distance: float = start.distance_to(end)
		var segment_count: int = max(1, int(distance / segment_size))

		for j in range(segment_count):
			var t: float = float(j) / float(segment_count)
			var segment_pos: Vector2 = start.lerp(end, t)

			if not _is_position_valid(segment_pos):
				continue

			var nav_region: NavigationRegion2D = _get_nav_region_at_position(segment_pos)
			if nav_region == null:
				continue

			var chunk_coords: Vector2i = _get_chunk_coords_from_nav_region(nav_region)
			var road_segment: Road = Road.new(segment_pos, PackedVector2Array(), nav_region.get_path(), chunk_coords)
			_current_segments.append(road_segment)

	if _current_segments.size() > 0:
		var network: RoadNetwork = RoadNetwork.new()

		for segment in _current_segments:
			var nav_region: NavigationRegion2D = _get_nav_region_at_position(segment.segment_position)
			if nav_region != null:
				network.add_segment(segment, nav_region)

		building_confirmed.emit(network)

	_cleanup_build_mode()


func _cancel_build_mode() -> void:
	_current_segments.clear()
	_cleanup_build_mode()
	building_cancelled.emit()


func _cleanup_build_mode() -> void:
	_is_building = false
	_is_dragging = false
	_path_points.clear()
	_clear_preview_polygons()
	get_tree().paused = false


func _clear_preview_polygons() -> void:
	for polygon in _preview_polygons:
		if is_instance_valid(polygon):
			polygon.queue_free()
	_preview_polygons.clear()


func _get_world_mouse_position() -> Vector2:
	if _camera == null:
		return get_viewport().get_mouse_position()
	return _camera.get_global_mouse_position()


func _get_nav_region_at_position(world_pos: Vector2) -> NavigationRegion2D:
	if _overworld == null:
		return null

	var chunker: Node = _overworld.get_node_or_null("Chunker")
	if chunker == null:
		return null

	var chunk_x: int = int(world_pos.x / 512)
	var chunk_y: int = int(world_pos.y / 512)

	var sprite_node: Node = chunker.get_node_or_null("Sprite_%d_%d" % [chunk_x, chunk_y])
	if sprite_node == null:
		return null

	var nav_region: NavigationRegion2D = sprite_node.get_node_or_null("Nav_%d_%d" % [chunk_x, chunk_y])
	return nav_region


func _get_chunk_coords_from_nav_region(nav_region: NavigationRegion2D) -> Vector2i:
	var node_name: String = nav_region.name
	var parts: PackedStringArray = node_name.split("_")

	if parts.size() >= 3:
		return Vector2i(int(parts[1]), int(parts[2]))

	return Vector2i.ZERO
