extends CharacterBody2D

@onready var camera : Camera2D = $Camera
@export var inifnite_jumps := false
@export var jump_multiplier := 1.0
@export var movement_multiplier := 1.0

func _ready() -> void:
	add_to_group("blocks_object_placement")

func _physics_process(delta: float) -> void:
	var new_zoom: float = camera.zoom.x
	if Input.is_action_just_pressed("forwards") && !TestBuildingGlobal.building_enabled:
		new_zoom += 10.0 * delta
	if Input.is_action_just_pressed("back") && !TestBuildingGlobal.building_enabled:
		new_zoom += -10.0 * delta
	if new_zoom < 0.05:
		new_zoom = 0.05
	camera.zoom = Vector2(new_zoom, new_zoom)
	velocity.x *= 0.9
	
	if not is_on_floor():
		velocity += get_gravity() * delta
	var input := Input.get_axis("left", "right")
	if input != 0:
		velocity.x += input * delta * 2000 * movement_multiplier
	if (is_on_floor() || inifnite_jumps) && Input.is_action_just_pressed("space"):
		velocity.y = -250 * jump_multiplier
		
	move_and_slide()
