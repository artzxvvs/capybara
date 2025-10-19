extends CharacterBody2D

@export var speed: float = 10.0
@export var left_limit: float = -100.0
@export var right_limit: float = 100.0

var direction: int = 1
var start_position: Vector2

func _ready():
	start_position = global_position

func _physics_process(delta):
	
	velocity.x = direction * speed
	move_and_slide()

	
	if direction == 1 and global_position.x >= start_position.x + right_limit:
		global_position.x = start_position.x + right_limit  
		direction = -1
		scale.x = -1
	elif direction == -1 and global_position.x <= start_position.x + left_limit:
		global_position.x = start_position.x + left_limit  
		direction = 1
		scale.x = 1
