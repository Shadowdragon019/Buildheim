extends Node2D

const packed_point := preload("res://tests/test-building/point.tscn")
const packed_object := preload("res://object/object.tscn")
const packed_ground_shader := preload("res://tests/test-building/ground.gdshader")
const world_bottom := 1000
const point_width := 5
const points_per_chunk := 400
const chunk_width := point_width * points_per_chunk
const ground_move_height := 40

@onready var player: CharacterBody2D = $Player
@onready var building_preview : Sprite2D = $BuildingPreview # Shader will break if there's more then one instance
@onready var snapping_area: Area2D = $SnappingArea
var terraforming_preview: Area2D = create_ground_piece(true)
var object_rotation := 0.0
var blocking_objects : Array[Node2D] = []
var snap_objects : Array[WorldObject] = []
#Dictionary[int, PackedFloat32Array]
var chunk_heights : Dictionary = {}
#Dictionary[int, Dictionary[int, float]]
var new_chunk_heights : Dictionary = {}
var ticks_game_existed := 0


func offset_point(point: Vector2i, offset: Vector2i) -> Vector2i:
	point += offset

	@warning_ignore("integer_division")
	point.x += point.y / points_per_chunk
	@warning_ignore("integer_division")
	point.y -= point.y / points_per_chunk * points_per_chunk
	if point.y < 0:
		point.x -= 1
		point.y += points_per_chunk
	
	return point


func chunk_index_at_x(x: float) -> int: 
	@warning_ignore("narrowing_conversion")
	var chunk_index : int = x / chunk_width
	if x < 0:
		chunk_index -= 1
	return chunk_index


func point_index_at_x(x: float) -> int:
	@warning_ignore("integer_division")
	var point_index := int(x) % chunk_width / point_width
	if chunk_index_at_x(x) < 0:
		point_index += points_per_chunk - 1
	return point_index


func get_height(chunk_index: int, point_index: int) -> float:
	if new_chunk_heights.has(chunk_index) && new_chunk_heights[chunk_index].values().has(point_index):
		return new_chunk_heights[chunk_index][point_index]
	return chunk_heights[chunk_index][point_index]


func get_height_vec(indexes: Vector2i) -> float:
	return get_height(indexes.x, indexes.y)


										   #Dictionary[int, float]
func set_heights(chunk_index: int, heights: Dictionary, smart_points: bool = true):
	# Set data in current chunk
	if new_chunk_heights.has(chunk_index):
		new_chunk_heights[chunk_index].merge(heights, true)
	else:
		new_chunk_heights[chunk_index] = heights
	
	# Set other chunk
	if smart_points:
		if heights.has(0):
			set_heights(chunk_index - 1, {points_per_chunk: heights[0]}, false)
		if heights.has(points_per_chunk):
			set_heights(chunk_index + 1, {0: heights[points_per_chunk]}, false)


func point_is_on_edge(point_index: int) -> bool:
	return point_index == 0 || point_index == points_per_chunk


func chunk_data_exists(chunk_index: int) -> bool:
	return chunk_heights.has(chunk_index)


func chunk_is_loaded(chunk_index: int) -> bool:
	var node := get_node_or_null("GroundCollision" + str(chunk_index))
	return node != null && !node.is_queued_for_deletion()


func generate_chunk_data(chunk_index: int):
	if chunk_data_exists(chunk_index):
		print("Chunk data already exists for chunk " + str(chunk_index))
	elif !chunk_heights.has(chunk_index):
		var chunk_heights_portion : PackedFloat32Array = []
		var start_x = chunk_width * chunk_index
		for i in range(points_per_chunk + 1):
			var x : float = start_x + i * point_width
			var y : float = sin(x/100.0) * 50.0
			#if sin(x/2500.0) < 0:
				#y += sin(x/2500.0) * 2500.0
			
			chunk_heights_portion.append(y)
		chunk_heights[chunk_index] = chunk_heights_portion


func create_ground_piece(is_preview: bool = false) -> Node2D:
	var shape := CollisionPolygon2D.new()
	var grass := Polygon2D.new()
	var ground := Polygon2D.new()
	var highlight := Polygon2D.new()
	shape.name = "Shape"
	grass.name = "Grass"
	ground.name = "Ground"
	highlight.name = "Highlight"
	grass.color = Color(0, 1, 0)
	ground.color = Color(1, 0.5, 0)
	highlight.color = Color(0, 0, 1, 0.5)
	
	if is_preview:
		var area := Area2D.new()
		area.visible = false
		area.add_child(shape)
		area.add_child(ground)
		area.add_child(grass)
		area.add_child(highlight)
		return area
	else:
		var collider := StaticBody2D.new()
		collider.visible = false
		collider.add_child(shape)
		collider.add_child(ground)
		collider.add_child(grass)
		return collider


func update_ground_piece(ground_piece: Node2D, heights: PackedFloat32Array):
	var shape : CollisionPolygon2D = ground_piece.get_node("Shape")
	var grass : Polygon2D = ground_piece.get_node("Grass")
	var ground : Polygon2D = ground_piece.get_node("Ground")
	var highlight : Polygon2D = ground_piece.get_node_or_null("Highlight")
	
	var grass_points : PackedVector2Array = []
	grass_points.resize(heights.size() * 2)
	var ground_points : PackedVector2Array = [
		Vector2((heights.size() - 1) * point_width, world_bottom), Vector2(0, world_bottom)
	]
	
	var index := -1
	for height in heights:
		index += 1
		var x : float = index * point_width
		var y : float = height
		grass_points[index] = Vector2(x, y - 5)
		grass_points[(heights.size()) * 2 - index - 1] = Vector2(x, y + 5)
		ground_points.append(Vector2(x, height))
	
	shape.polygon = ground_points
	ground.polygon = ground_points
	grass.polygon = grass_points
	if highlight != null:
		highlight.polygon = ground_points
	ground_piece.visible = true
	
		
func load_chunk(chunk_index: int):
	if chunk_is_loaded(chunk_index):
		print("Chunk " + str(chunk_index) + " already exists")
	else:
		if !chunk_data_exists(chunk_index):
			generate_chunk_data(chunk_index)
		var piece := create_ground_piece()
		update_ground_piece(piece, chunk_heights[chunk_index])
		add_child(piece)
		piece.name = "GroundCollision" + str(chunk_index)
		piece.global_position.x = chunk_index * chunk_width

	
func unload_chunk(chunk_index: int):
	get_node("GroundCollision" + str(chunk_index)).queue_free()


func load_game():
	if not FileAccess.file_exists("user://save.json"):
		push_error("Save file does not exist")
	else:
		var save_file = FileAccess.open("user://save.json", FileAccess.READ)
		var data : Dictionary = JSON.parse_string(save_file.get_as_text())
		player.global_position = Vector2(data["player_position"]["x"], data["player_position"]["y"])
		
		var loaded_chunk_heights : Dictionary = data["chunk_heights"]
		for i in loaded_chunk_heights:
			chunk_heights[int(i)] = loaded_chunk_heights[i]
			load_chunk(int(i))
	print("Load success!")


func save_game():
	print("Saving!")
	var save := FileAccess.open("user://save.json", FileAccess.WRITE)
	var data := {
		"player_position": {
			"x": player.global_position.x,
			"y": player.global_position.y
		},
		"chunk_heights": chunk_heights
	}
	save.store_string(JSON.stringify(data))
	save.close()
	print("Save success!")
	
	
func _ready():
	if TestBuildingGlobal.load_game:
		load_game()
	add_child(terraforming_preview)
	terraforming_preview.modulate = Color(1, 1, 1, 0.5)
	terraforming_preview.top_level = true


func _process(_delta: float):
	ticks_game_existed += 1
	var global_mouse_position := get_global_mouse_position()
	@warning_ignore("unused_variable")
	var global_mouse_global_index := Vector2i(chunk_index_at_x(global_mouse_position.x), point_index_at_x(global_mouse_position.x))
	
	# Building
	#region
	if Input.is_action_just_pressed("forwards") && TestBuildingGlobal.building_enabled:
		object_rotation += PI/8.0
	if Input.is_action_just_pressed("back") && TestBuildingGlobal.building_enabled:
		object_rotation += -PI/8.0
	
	building_preview.global_position = global_mouse_position
	building_preview.rotation = object_rotation
	snapping_area.rotation = object_rotation
	building_preview.visible = TestBuildingGlobal.building_enabled
	snapping_area.visible = TestBuildingGlobal.building_enabled
	
	if Input.is_action_just_pressed("index_right") && TestBuildingGlobal.building_enabled:
		TestBuildingGlobal.snap_point_index -= 1
		if TestBuildingGlobal.snap_point_index < 0:
			TestBuildingGlobal.snap_point_index = TestBuildingGlobal.object_snap_points.size() - 1
	if Input.is_action_just_pressed("index_left") && TestBuildingGlobal.building_enabled:
		TestBuildingGlobal.snap_point_index += 1
		if TestBuildingGlobal.snap_point_index >= TestBuildingGlobal.object_snap_points.size():
			TestBuildingGlobal.snap_point_index = 0
	building_preview.global_position = building_preview.to_global(TestBuildingGlobal.object_snap_points[TestBuildingGlobal.snap_point_index])
	snapping_area.global_position = global_mouse_position
	
	for snap_object in snap_objects:
		for snap_point in snap_object.snap_points:
			var distance := snapping_area.global_position.distance_to(snap_point)
			if distance < 2:
				building_preview.global_position = snap_point
				building_preview.global_position = building_preview.to_global(TestBuildingGlobal.object_snap_points[TestBuildingGlobal.snap_point_index])
				break
	
	# Place object
	if Input.is_action_just_pressed("left_click") && TestBuildingGlobal.building_enabled:
		var object : StaticBody2D = packed_object.instantiate()
		object.global_position = building_preview.global_position
		object.global_rotation = building_preview.global_rotation
		add_child(object)
	# Remove object
	if Input.is_action_just_released("right_click") && !TestBuildingGlobal.objects_over_mouse.is_empty() && TestBuildingGlobal.building_enabled:
		TestBuildingGlobal.last_oom().queue_free()
		TestBuildingGlobal.objects_over_mouse.remove_at(TestBuildingGlobal.last_oom_index())
		
	#endregion
	
	# Terraforming
	#region
	terraforming_preview.visible = TestBuildingGlobal.terraforming_enabled
	if TestBuildingGlobal.terraforming_enabled:
		var chunk_index := chunk_index_at_x(global_mouse_position.x + point_width / 2.0)
		var point_index := point_index_at_x(global_mouse_position.x + point_width / 2.0)
		var global_index := Vector2i(chunk_index, point_index)
		
		#Dictionary[int, Dictionary[int, float]]
		var placements := {}
		var heights : PackedFloat32Array = []
		var width := 10
		
		for index in range(width * 2 + 1):
			var offset := index - width
			var offset_global_index := Vector2i(0, offset)
			var global_index_offset := offset_point(global_index, offset_global_index)
			var ground_height := get_height_vec(offset_point(global_index, offset_global_index))
			var weight := absf(width - index) / width
			weight *= weight
			weight = 1 - weight
			var height := minf(lerpf(ground_height, global_mouse_position.y, weight), world_bottom - width)
			heights.append(height)
			
			if !placements.has(global_index_offset.x):
				placements[global_index_offset.x] = {}
			placements[global_index_offset.x][global_index_offset.y] = height
			
		update_ground_piece(terraforming_preview, heights)
		terraforming_preview.global_position.x = point_index * point_width + chunk_index * chunk_width - point_width * width
	
		if Input.is_action_just_pressed("left_click"):
			for i in placements:
				set_heights(i, placements[i])
	#endregion
	
	# Load chunks around player
	for i in range(7):
		var chunk_index := i + chunk_index_at_x(player.global_position.x) - 3
		if !chunk_data_exists(chunk_index):
			load_chunk(chunk_index)
	
	# Updating chunks
	#region
	for chunk_index in new_chunk_heights:
		var _chunk_index : int = chunk_index
		# Dictionary[int, float]
		var chunk_piece : StaticBody2D = get_node("GroundCollision" + str(_chunk_index))
		# Dictionary[int, float]
		var new_points : Dictionary = new_chunk_heights[chunk_index]
		
		for point_index in new_points:
			chunk_heights[chunk_index][point_index] = new_points[point_index]
	
		update_ground_piece(chunk_piece, chunk_heights[chunk_index])
	
	new_chunk_heights = {}
	#endregion
	
	# Save
	if Input.is_action_just_pressed("save"):
		save_game()


func _on_preview_area_body_entered(body: Node2D):
	if body.is_in_group("blocks_object_placement"):
		blocking_objects.append(body)
		building_preview.material.set_shader_parameter("blocked", true)
		
		
func _preview_area_body_exited(body: Node2D):
	if body.is_in_group("blocks_object_placement"):
		blocking_objects.erase(body)
		if blocking_objects.is_empty():
			building_preview.material.set_shader_parameter("blocked", false)


func _on_snapping_area_body_entered(body: Node2D):
	if body is WorldObject && !snap_objects.has(body):
		snap_objects.append(body)
		
		
func _on_snapping_area_body_exited(body: Node2D):
	if body is WorldObject:
		snap_objects.erase(body)
