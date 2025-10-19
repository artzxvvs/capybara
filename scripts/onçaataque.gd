extends CharacterBody2D

@export var speed: float = 150.0
@export var player_path: NodePath
@onready var animo: AnimatedSprite2D = $AnimatedSprite2D

var player: CharacterBody2D

func _ready():
	player = get_node(player_path)

func _physics_process(_delta):
	if player == null:
		return

	var direction = (player.global_position - global_position).normalized()
	velocity = direction * speed
	move_and_slide()

	# Animação de perseguição
	if abs(direction.x) > 0.1:
		animo.flip_h = direction.x < 0
		if not animo.is_playing() or animo.animation != "walk":
			animo.play("walk")
	else:
		if not animo.is_playing() or animo.animation != "idle":
			animo.play("idle")
