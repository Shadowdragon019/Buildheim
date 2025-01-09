extends Node2D

const chunk_point_seperation := 5
const chunk_point_count := 1000
const chunk_width := chunk_point_count * chunk_point_seperation

@onready
var ground := $Ground

func generate_chunk(chunk_index: int):
	var starting_point := chunk_index * chunk_width
	var end_point := chunk_index * chunk_width + chunk_width
	var top_points := PackedVector2Array()
	
	for i in range(chunk_point_count + 1):
		var x := i * chunk_point_seperation + starting_point
		var y = sin(x/100.0)*5.0
		y += sin(x/500.0)*25.0
		
		top_points.append(Vector2(x, y))
	
	var all_points := PackedVector2Array()
	all_points.append(Vector2(starting_point, 2500))
	all_points.append_array(top_points)
	all_points.append(Vector2(end_point, 2500))
	if chunk_index == 0:
		$Ground/TestCollider.polygon = all_points
	else:
		var collision := CollisionPolygon2D.new()
		collision.polygon = all_points
		ground.add_child(collision)

func _ready():
	generate_chunk(-2)
	generate_chunk(-1)
	generate_chunk(0)
	generate_chunk(1)
	generate_chunk(2)
