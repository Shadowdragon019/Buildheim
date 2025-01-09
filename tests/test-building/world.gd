extends Node2D

# TODO
# Only update chunks at end of frame?
# Set point function to take into account updating a point on the edge of a chunk
# add option to toggle snapping
# save objects
# add more objects
# terrain editing
# unload/load objects in chunks
# add ability to copy object rotation

const packed_point := preload("res://tests/test-building/point.tscn")
const packed_object := preload("res://object/object.tscn")
const packed_ground_shader := preload("res://tests/test-building/ground.gdshader")
const chunk_bottom := 1000
const chunk_point_width := 5
const points_per_chunk := 400
const chunk_width := chunk_point_width * points_per_chunk

@onready var player: CharacterBody2D = $Player
@onready var preview : Sprite2D = $Preview # Shader will break if there's more then one instance
@onready var snapping_area: Area2D = $SnappingArea
var object_rotation := 0.0
var blocking_objects : Array[Node2D] = []
var snap_objects : Array[WorldObject] = []
#Dictionary[int, PackedFloat32Array]
var chunk_heights : Dictionary = {}


func chunk_at_x(x: float) -> int:
	return floori(x / chunk_width)


func get_height(chunk_index: int, point_index: int) -> float:
	return chunk_heights[chunk_index][point_index]


func update_chunk(chunk_index: int, points_to_update: PackedInt32Array):
	var collision_polygon : CollisionPolygon2D = get_node("GroundCollision" + str(chunk_index) + "/Shape")
	var ground_polygon : Polygon2D = get_node("GroundCollision" + str(chunk_index) + "/Ground")
	var grass_polygon : Polygon2D = get_node("GroundCollision" + str(chunk_index) + "/Grass")
	
	var collision_polygon_data := collision_polygon.polygon
	var ground_polygon_data := ground_polygon.polygon
	var grass_polygon_data := grass_polygon.polygon
	
	if points_to_update.is_empty():
		points_to_update = range(points_per_chunk)
	
	for point in points_to_update:
		var height = chunk_heights[chunk_index][point]
		collision_polygon_data[point + 1].y = height
		ground_polygon_data[point + 1].y = height
		grass_polygon_data[point].y = height
		grass_polygon_data[(points_per_chunk + 1) * 2 - point - 1].y = height - 10
	
	collision_polygon.polygon = collision_polygon_data
	ground_polygon.polygon = ground_polygon_data
	grass_polygon.polygon = grass_polygon_data

										   #Dictionary[int, float]
func set_heights(chunk_index: int, heights: Dictionary):
	for point_index in heights:
		chunk_heights[chunk_index][point_index] = heights[point_index]


func set_height(chunk_index: int, point_index: int, height: float):
	chunk_heights[chunk_index][point_index] = height


func point_is_on_edge(point_index: int) -> bool:
	return point_index == 0 || point_index == points_per_chunk


## Return chunks that need updating
										  #Dictionary[int, float]) -> Dictionary[int, PackedInt32Array]
func set_points(chunk_index: int, heights: Dictionary) -> Dictionary:
	# Dictionary[int, PackedInt32Array]
	var chunks_that_need_updating : Dictionary = {chunk_index: PackedInt32Array()}
	
	for point_index in heights:
		var _point_index : int = point_index
		var height : float = heights[_point_index]
		set_height(chunk_index, _point_index, height)
		chunks_that_need_updating[chunk_index].append(point_index)
		if point_is_on_edge(point_index):
			if _point_index == 0:
				set_heights(chunk_index - 1, {points_per_chunk: height})
				chunks_that_need_updating[chunk_index - 1] = PackedInt32Array([points_per_chunk])
			elif _point_index == points_per_chunk:
				set_heights(chunk_index + 1, {0: height})
				chunks_that_need_updating[chunk_index + 1] = PackedInt32Array([0])
	
	return chunks_that_need_updating


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
			var x : float = start_x + i * chunk_point_width
			var y : float = sin(x/100.0) * 250.0
			#if sin(x/2500.0) < 0:
				#y += sin(x/2500.0) * 2500.0
			
			chunk_heights_portion.append(y)
		chunk_heights[chunk_index] = chunk_heights_portion
		
		
func load_chunk(chunk_index: int):
	if chunk_is_loaded(chunk_index):
		print("Chunk " + str(chunk_index) + " already exists")
	else:
		var polygon := Polygon2D.new()
		polygon.color = Color(1, 0.5, 0 ,1)
		polygon.name = "Ground"
		var grass_polygon := Polygon2D.new()
		grass_polygon.color = Color(0, 1, 0 ,1)
		grass_polygon.name = "Grass"
		var collision := StaticBody2D.new()
		collision.name = "GroundCollision" + str(chunk_index)
		var shape := CollisionPolygon2D.new()
		shape.name = "Shape"
		collision.add_child(shape)
		collision.add_child(polygon)
		collision.add_child(grass_polygon)
		
		var ground_points : PackedVector2Array = []
		var ground_uv : PackedVector2Array = [Vector2(0, 1)]
		var grass_points : PackedVector2Array = []
		grass_points.resize((points_per_chunk + 1) * 2)
		
		if !chunk_data_exists(chunk_index):
			generate_chunk_data(chunk_index)
		
		var start_x = chunk_width * chunk_index
		for i in range(points_per_chunk + 1):
			var x : float = start_x + i * chunk_point_width
			var y : float = chunk_heights[chunk_index][i]
			grass_points[i] = Vector2(x, y)
			grass_points[(points_per_chunk + 1) * 2 - i - 1] = Vector2(x, y - 10)
			if i == 0:
				ground_points.append(Vector2(x, chunk_bottom))
			ground_points.append(Vector2(x, y))
			if i == points_per_chunk:
				ground_points.append(Vector2(x, chunk_bottom))
			ground_uv.append(Vector2(0, 0))
		ground_uv.append(Vector2(0, 1))
		
		shape.polygon = ground_points
		polygon.polygon = ground_points
		polygon.uv = ground_uv
		grass_polygon.polygon = grass_points
		
		add_child(collision)

	
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
	set_heights(0, {points_per_chunk: 0})
	set_heights(1, {0: 0})
	update_chunk(0, [points_per_chunk])
	update_chunk(1, [0])


func _process(_delta: float):
	if Input.is_action_just_pressed("forwards") && TestBuildingGlobal.building_mode_enabled:
		object_rotation += PI/8.0
	if Input.is_action_just_pressed("back") && TestBuildingGlobal.building_mode_enabled:
		object_rotation += -PI/8.0
	
	preview.global_position = get_global_mouse_position()
	preview.rotation = object_rotation
	snapping_area.rotation = object_rotation
	preview.visible = TestBuildingGlobal.building_mode_enabled
	snapping_area.visible = TestBuildingGlobal.building_mode_enabled
	
	if Input.is_action_just_pressed("index_right") && TestBuildingGlobal.building_mode_enabled:
		TestBuildingGlobal.snap_point_index -= 1
		if TestBuildingGlobal.snap_point_index < 0:
			TestBuildingGlobal.snap_point_index = TestBuildingGlobal.object_snap_points.size() - 1
	if Input.is_action_just_pressed("index_left") && TestBuildingGlobal.building_mode_enabled:
		TestBuildingGlobal.snap_point_index += 1
		if TestBuildingGlobal.snap_point_index >= TestBuildingGlobal.object_snap_points.size():
			TestBuildingGlobal.snap_point_index = 0
	preview.global_position = preview.to_global(TestBuildingGlobal.object_snap_points[TestBuildingGlobal.snap_point_index])
	snapping_area.global_position = get_global_mouse_position()
	
	for snap_object in snap_objects:
		for snap_point in snap_object.snap_points:
			var distance := snapping_area.global_position.distance_to(snap_point)
			if distance < 2:
				preview.global_position = snap_point
				preview.global_position = preview.to_global(TestBuildingGlobal.object_snap_points[TestBuildingGlobal.snap_point_index])
				break
	
	# Place object
	if Input.is_action_just_pressed("left_click") && TestBuildingGlobal.building_mode_enabled:
		var object : StaticBody2D = packed_object.instantiate()
		object.global_position = preview.global_position
		object.global_rotation = preview.global_rotation
		add_child(object)
	# Remove object
	if Input.is_action_just_released("right_click") && !TestBuildingGlobal.objects_over_mouse.is_empty() && TestBuildingGlobal.building_mode_enabled:
		TestBuildingGlobal.last_oom().queue_free()
		TestBuildingGlobal.objects_over_mouse.remove_at(TestBuildingGlobal.last_oom_index())
	
	# Load chunks around player
	for i in range(7):
		var chunk_i := i + chunk_at_x(player.global_position.x) - 3
		if !chunk_data_exists(chunk_i):
			load_chunk(chunk_i)
	
	# Save
	if Input.is_action_just_pressed("save"):
		save_game()
		
		
func _on_preview_area_body_entered(body: Node2D):
	if body.is_in_group("blocks_object_placement"):
		blocking_objects.append(body)
		preview.material.set_shader_parameter("blocked", true)
		
		
func _preview_area_body_exited(body: Node2D):
	if body.is_in_group("blocks_object_placement"):
		blocking_objects.erase(body)
		if blocking_objects.is_empty():
			preview.material.set_shader_parameter("blocked", false)


func _on_snapping_area_body_entered(body: Node2D):
	if body is WorldObject && !snap_objects.has(body):
		snap_objects.append(body)
		
		
func _on_snapping_area_body_exited(body: Node2D):
	if body is WorldObject:
		snap_objects.erase(body)
