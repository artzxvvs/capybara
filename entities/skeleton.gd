extends CharacterBody2D

# Esqueleto que patrulha e persegue o Player quando ele estiver próximo.
# Usa o grupo "Player" (o Player.tscn já tem groups=["Player"]).

enum SkeletonState {
	idle,
	walk,
	follow,
	attack,
	hurt
}

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var hitbox: Area2D = $Hitbox
@onready var wall_detector: RayCast2D = $WallDetector
@onready var ground_detector: RayCast2D = $GroundDetector
@onready var player_detector: RayCast2D = get_node_or_null("PlayerDetector")
@onready var bone_start_position: Node2D = $BoneStartPosition

const SPEED = 60.0
const PATROL_SPEED = 20.0
const FOLLOW_RANGE = 220.0
const ATTACK_RANGE = 28.0
const GRAVITY = 1200.0

var status: SkeletonState = SkeletonState.walk
var direction = 1
var can_throw = true

func _ready() -> void:
	if wall_detector:
		wall_detector.enabled = true
	if ground_detector:
		ground_detector.enabled = true
	if player_detector:
		player_detector.enabled = true
		player_detector.collide_with_areas = true
		player_detector.collide_with_bodies = true

	go_to_walk_state()

func _physics_process(delta: float) -> void:
	# física vertical
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0

	# localizar player mais próximo
	var player = _find_closest_player()
	var dist_to_player = INF
	if player:
		dist_to_player = global_position.distance_to(player.global_position)

	# transições de estado
	if status == SkeletonState.hurt:
		# mantém hurt até a animação terminar
		pass
	elif player and dist_to_player <= ATTACK_RANGE:
		go_to_attack_state()
	elif player and dist_to_player <= FOLLOW_RANGE:
		go_to_follow_state()
	else:
		if status != SkeletonState.walk:
			go_to_walk_state()

	# execução do estado
	match status:
		SkeletonState.walk:
			_walk_state(delta)
		SkeletonState.follow:
			_follow_state(delta, player)
		SkeletonState.attack:
			_attack_state(delta)
		SkeletonState.hurt:
			_hurt_state(delta)

	# aplicar movimento
	move_and_slide()

func _find_closest_player() -> Node:
	var players = get_tree().get_nodes_in_group("Player")
	var best: Node = null
	var best_dist = INF
	for p in players:
		var candidate: Node2D = null
		if p is Node2D:
			candidate = p
		elif p.get_parent() and p.get_parent() is Node2D:
			candidate = p.get_parent()
		if candidate:
			var d = global_position.distance_to(candidate.global_position)
			if d < best_dist:
				best = candidate
				best_dist = d
	return best

func go_to_walk_state():
	status = SkeletonState.walk
	anim.play("walk")
	velocity.x = PATROL_SPEED * direction

func go_to_follow_state():
	status = SkeletonState.follow
	anim.play("walk")

func go_to_attack_state():
	status = SkeletonState.attack
	anim.play("attack")
	velocity.x = 0
	can_throw = true

func go_to_hurt_state():
	status = SkeletonState.hurt
	anim.play("hurt")
	hitbox.process_mode = Node.PROCESS_MODE_DISABLED
	velocity = Vector2.ZERO

# --- Estados ---
func _walk_state(_delta):
	# patrulha: move apenas em alguns frames (mantive a ideia antiga)
	if anim.frame == 3 or anim.frame == 4:
		velocity.x = PATROL_SPEED * direction
	else:
		velocity.x = 0

	# troca direção se detectar parede ou beira de plataforma
	if wall_detector and wall_detector.is_colliding():
		_flip_direction()
	if ground_detector and not ground_detector.is_colliding():
		_flip_direction()

func _follow_state(_delta, player):
	# Persegue o player: cuidado com null
	if not player:
		go_to_walk_state()
		return

	var target_x = player.global_position.x
	var dx = target_x - global_position.x

	# se o player estiver longe o suficiente, move em sua direção
	if abs(dx) > 4:
		# usa a sintaxe "a if cond else b" do GDScript
		direction = 1 if dx > 0 else -1
		velocity.x = SPEED * direction
	else:
		velocity.x = 0

	# evita atravessar paredes: se colidir com parede, inverte
	if wall_detector and wall_detector.is_colliding():
		_flip_direction()

	# atualizar flip do sprite após ajustar direction
	_update_sprite_flip()

func _attack_state(_delta):
	velocity.x = 0
	if anim.frame == 2 and can_throw:
		can_throw = false
		# implementar projéteis aqui, se desejado

func _hurt_state(_delta):
	velocity.x = 0

# utilitários
func _flip_direction():
	direction *= -1
	_update_sprite_flip()

func _update_sprite_flip():
	# define scale.x para virar sprite visualmente (mantendo magnitude)
	if direction < 0:
		scale.x = -abs(scale.x)
	else:
		scale.x = abs(scale.x)

func take_damage():
	go_to_hurt_state()

func _on_animated_sprite_2d_animation_finished() -> void:
	if anim.animation == "attack":
		var player = _find_closest_player()
		if player and global_position.distance_to(player.global_position) <= FOLLOW_RANGE:
			go_to_follow_state()
		else:
			go_to_walk_state()
		return
	if anim.animation == "hurt":
		go_to_walk_state()
		return
