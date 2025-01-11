extends Node2D

const packed_point := preload("res://tests/test-building/point.tscn")
const packed_object := preload("res://object/object.tscn")
const packed_ground_shader := preload("res://tests/test-building/ground.gdshader")
const chunk_bottom := 1000
const point_width := 5
const points_per_chunk := 400
const chunk_width := point_width * points_per_chunk

@onready var player: CharacterBody2D = $Player
@onready var building_preview : Sprite2D = $BuildingPreview # Shader will break if there's more then one instance
@onready var snapping_area: Area2D = $SnappingArea
@onready var terraforming_preview: Polygon2D = $TerraformingPreview
var object_rotation := 0.0
var blocking_objects : Array[Node2D] = []
var snap_objects : Array[WorldObject] = []
#Dictionary[int, PackedFloat32Array]
var chunk_heights : Dictionary = {}
#Dictionary[int, Dictionary[int, float]]
var new_chunk_heights : Dictionary = {}

func chunk_index_at_x(x: float) -> int: 
	@warning_ignore("narrowing_conversion")
	var chunk_index : int = x / chunk_width
	if x < 0:
		chunk_index -= 1
	return chunk_index


func point_index_at_x(x: float) -> int:
	@warning_ignore("integer_division")
	var point_index := (int(x + float(point_width) / 2.0) % chunk_width) / point_width
	if point_index < 0:
		point_index += points_per_chunk
	return point_index


func get_height(chunk_index: int, point_index: int) -> float:
	if new_chunk_heights.has(chunk_index) && new_chunk_heights[chunk_index].values().has(point_index):
		return new_chunk_heights[chunk_index][point_index]
	return chunk_heights[chunk_index][point_index]


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
			var x : float = start_x + i * point_width
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
	
	# Dictionary[int, float]
	set_heights(0, {
		400: 0,
		399: 0,
		398: 0,
		397: 0,
		396: 0,
	})

	


func _process(_delta: float):
	var global_mouse_position := get_global_mouse_position()
	
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
		terraforming_preview.global_position = Vector2(int(global_mouse_position.x / point_width) * point_width, global_mouse_position.y)
		
		if Input.is_action_just_pressed("left_click") && global_mouse_position.y < chunk_bottom:
			print("e")
			set_heights(chunk_index_at_x(terraforming_preview.global_position.x), {
				int(terraforming_preview.global_position.x / point_width): terraforming_preview.global_position.y
			})
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
		var points_to_update : Dictionary = new_chunk_heights[chunk_index]
		
		if !chunk_heights.has(chunk_index):
			push_warning("Attempting to modify chunk " + str(_chunk_index) + " when it does not exist. Ignoring.")
			continue
		
		var collision_polygon : CollisionPolygon2D = get_node("GroundCollision" + str(_chunk_index) + "/Shape")
		var ground_polygon : Polygon2D = get_node("GroundCollision" + str(_chunk_index) + "/Ground")
		var grass_polygon : Polygon2D = get_node("GroundCollision" + str(_chunk_index) + "/Grass")
		var collision_polygon_data := collision_polygon.polygon
		var ground_polygon_data := ground_polygon.polygon
		var grass_polygon_data := grass_polygon.polygon
		
		for point_index in points_to_update:
			var height : float = points_to_update[point_index]
			if point_index < 0:
				push_warning("Attempting to modify point (" + str(_chunk_index) + ", " + str(point_index) + ") with point index smaller then minimum, 0. Ignoring.")
				continue
			if point_index > points_per_chunk:
				push_warning("Attempting to modify point (" + str(_chunk_index) + ", " + str(point_index) + ") with point index bigger then maximum, " + str(points_per_chunk) + ". Ignoring.")
				continue
			if height > chunk_bottom:
				push_warning("Attempting to set height of point (" + str(_chunk_index) + ", " + str(point_index) + " which is below chunk bottom, " + str(chunk_bottom) + ". Ignoring.")
				continue
			
			chunk_heights[chunk_index][point_index] = height
			collision_polygon_data[point_index + 1].y = height
			ground_polygon_data[point_index + 1].y = height
			grass_polygon_data[point_index].y = height
			grass_polygon_data[(points_per_chunk + 1) * 2 - point_index - 1].y = height - 10
		
		collision_polygon.polygon = collision_polygon_data
		ground_polygon.polygon = ground_polygon_data
		grass_polygon.polygon = grass_polygon_data
				
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
