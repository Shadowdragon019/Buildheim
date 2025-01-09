extends Control

const packed_world = preload("res://tests/test-building/world.tscn")

func _on_new_game_pressed() -> void:
	TestBuildingGlobal.load_game = false
	get_tree().change_scene_to_packed(packed_world)

func _on_load_pressed() -> void:
	TestBuildingGlobal.load_game = true
	get_tree().change_scene_to_packed(packed_world)
