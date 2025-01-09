extends CollisionPolygon2D

func _ready():
	var copy := polygon
	var size = 1000.0
	var count := 10.0
	var top = 0.0
	var bottom = 100.0
	copy.append(Vector2(size/-2.0, bottom))
	for i in range(count):
		var x = (size/count*i)-size/2.0
		copy.append(Vector2(x, randf_range(top, (top-bottom)/2)))
	copy.append(Vector2(size/2.0, bottom))
	polygon = copy
