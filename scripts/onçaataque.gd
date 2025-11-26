extends CharacterBody2D

@export var speed: float = 100.0
@export var spawn_delay: float = 4.0
@export var gravity: float = 800.0
@export var damage: int = 1
@export var damage_interval: float = 1.0  # tempo entre danos

var player: Node2D = null
var is_active: bool = false
var last_damage_time: float = -999.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hitbox: Area2D = $HitBox

func _ready():
	visible = false
	set_physics_process(false)

	# Acha o player
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]
	else:
		push_warning("Nenhum player no grupo 'player'.")

	# Conecta HitBox
	if hitbox:
		hitbox.body_entered.connect(_on_hitbox_body_entered)
	else:
		push_warning("Crie um Area2D chamado HitBox como filho da onça.")

	await get_tree().create_timer(spawn_delay).timeout
	_activate()

func _activate():
	visible = true
	is_active = true
	set_physics_process(true)

func _physics_process(delta):
	if not is_active or player == null:
		return

	velocity.y += gravity * delta

	var direction = player.global_position - global_position
	if direction.length() > 0:
		direction = direction.normalized()
		velocity.x = direction.x * speed
	else:
		velocity.x = 0

	move_and_slide()

	if abs(velocity.x) > 0.1:
		sprite.play("walk")
		sprite.flip_h = velocity.x < 0
	else:
		sprite.play("idle")

func _on_hitbox_body_entered(body):
	if not is_active:
		return
	if body == null:
		return
	if not body.is_in_group("player"):
		return
	if not body.has_method("take_damage"):
		return

	var now := Time.get_ticks_msec() / 1000.0
	if now - last_damage_time < damage_interval:
		return

	body.take_damage(damage)
	last_damage_time = now
