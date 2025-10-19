extends CharacterBody2D

@export var speed: float = 100.0
@export var health: int = 3
@export var follow_distance: float = 700.0 # distância máxima para seguir
@onready var player = null

func _ready():
	player = get_parent().get_node("Player") # ajuste se necessário

func _physics_process(delta):
	if player:
		var distance = global_position.distance_to(player.global_position)
		
		if distance <= follow_distance:
			var direction_x = sign(player.global_position.x - global_position.x)
			velocity.x = direction_x * speed
			flip()
		else:
			velocity.x = 0 # para quando está longe
		
	# Gravidade
	velocity.y += ProjectSettings.get_setting("physics/2d/default_gravity") * delta
	
	move_and_slide()

func flip():
	if velocity.x > 0:
		$AnimatedSprite2D.flip_h = false
	elif velocity.x < 0:
		$AnimatedSprite2D.flip_h = true

func take_damage(amount: int):
	health -= amount
	if health <= 0:
		queue_free()
