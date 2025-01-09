extends Node

const object_snap_points : PackedVector2Array = [
	Vector2(-10, -4), Vector2(0, -4), Vector2(10, -4),
	Vector2(-10, 0), Vector2(0, 0), Vector2(10,0),
	Vector2(-10, 4), Vector2(0, 4), Vector2(10, 4)
]

var load_game = false
var objects_over_mouse: Array[WorldObject] = []
var building_mode_enabled := false
var snap_point_index := 4

func _process(_delta: float) -> void:
	if !objects_over_mouse.is_empty():
		if building_mode_enabled: last_oom().modulate = Color(2, 2, 1)
		else: last_oom().modulate = Color.WHITE
		if objects_over_mouse.size() >= 2:
			for i in range(objects_over_mouse.size()-1):
				objects_over_mouse[i].modulate = Color.WHITE
	if Input.is_action_just_pressed("toggle_building_mode"):
		building_mode_enabled = !building_mode_enabled
		if !building_mode_enabled && !objects_over_mouse.is_empty():
			last_oom().modulate = Color.WHITE
		
## Last object over mouse index
func last_oom_index() -> int:
	if objects_over_mouse.is_empty():
		return 0
	else:
		return objects_over_mouse.size()-1
## Last object over mouse
func last_oom() -> WorldObject:
	if objects_over_mouse.is_empty():
		return null
	else:
		return objects_over_mouse[last_oom_index()]
