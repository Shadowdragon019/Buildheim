extends CharacterBody2D

@export
var gravity := true

@onready
var camera := $Camera

func _process(delta: float):
	if Input.is_action_just_pressed("forwards"):
		camera.zoom += Vector2(10, 10) * Vector2(delta, delta)
	if Input.is_action_just_pressed("back"):
		camera.zoom -= Vector2(10, 10) * Vector2(delta, delta)
	if camera.zoom.x < 0.05:
		camera.zoom = Vector2(0.05, 0.05)
		 
func _physics_process(delta: float):
	# I already coded this trying to get other ideas working but whatever, it works & I don't feel like recoding it
	var floor_normal := absf(absf(rad_to_deg(get_floor_normal().angle())) - 90)
	if gravity:
		if is_on_floor() && floor_normal > 44:
			velocity += get_gravity() * delta * 8
		else:
			velocity += get_gravity() * delta
		
	var input := Input.get_axis("left", "right")
	var speed := input * 1000
	if Input.is_action_pressed("run"):
		speed *= 2
	if is_on_floor() && floor_normal > 44 && not Input.is_action_pressed("run"):
		speed /= 2
	
	if is_on_floor():
		velocity.x *= 0.9
		velocity.x += speed * delta
			
		if Input.is_action_just_pressed("space"):
			velocity += get_floor_normal() * 300
			velocity += Vector2(input * 50, -50)
	
	move_and_slide()
