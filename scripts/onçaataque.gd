extends CharacterBody2D

@export var speed: float = 100.0           # Velocidade de movimento
@export var spawn_delay: float = 4.0       # Tempo para aparecer
@export var gravity: float = 800.0         # Gravidade aplicada ao inimigo

var player: Node2D = null
var is_active: bool = false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready():
	visible = false
	set_physics_process(false)

	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]
	else:
		push_warning("Nenhum player encontrado no grupo 'player'.")

	await get_tree().create_timer(spawn_delay).timeout
	activate()

func activate():
	visible = true
	is_active = true
	set_physics_process(true)

func _physics_process(delta):
	if not is_active or player == null:
		return

	# Aplica gravidade
	velocity.y += gravity * delta

	# Verifica se o player ainda existe e calcula direção
	var direction = player.global_position - global_position
	if direction.length() != 0:
		direction = direction.normalized()
		velocity.x = direction.x * speed
	else:
		velocity.x = 0

	# Move o inimigo
	move_and_slide()

	# Alterna animações
	if abs(velocity.x) > 0.1:
		sprite.play("walk")
		sprite.flip_h = velocity.x < 0
	else:
		sprite.play("idle")

	move_and_slide()

	
