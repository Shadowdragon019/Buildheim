class_name WorldObject extends StaticBody2D

const packed_point := preload("res://tests/test-building/point.tscn")
var snap_points : PackedVector2Array = []

func _on_mouse_entered() -> void:
	TestBuildingGlobal.objects_over_mouse.append(self)
func _on_mouse_exited() -> void:
	TestBuildingGlobal.objects_over_mouse.erase(self)
	modulate = Color.WHITE

func _ready() -> void:
	for point in TestBuildingGlobal.object_snap_points:
		snap_points.append(to_global(point))

	#for point in snap_points:
		#var point_graphic : Sprite2D = packed_point.instantiate()
		#add_child(point_graphic)
		#point_graphic.global_position = point
