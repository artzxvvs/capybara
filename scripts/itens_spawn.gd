extends Node2D
## Spawner de Plataformas e Pedras – com:
## 1) Vão mínimo para a capivara (min_vertical_clearance_px/capy_height_px)
## 2) Altura mínima da plataforma em relação ao chão (min_platform_ground_gap_px)
## 3) Pedras sempre no chão
## Godot 4.5 (2D - plataforma)

@export_node_path("Node2D") var player_path: NodePath
@export var platform_scenes: Array[PackedScene] = []
@export var rock_scenes: Array[PackedScene] = []

@export_group("Colisão")
@export_flags_2d_physics var ground_collision_mask: int = 0      # chão/TileMap (somente ele para as pedras)
@export_flags_2d_physics var platform_collision_mask: int = 0    # camadas das plataformas (para clearance)
@export_flags_2d_physics var obstacle_collision_mask: int = 0    # camadas a evitar no spawn (opcional)

@export_group("Métricas do Personagem")
@export var JUMP_VELOCITY: float = -400.0
@export var SPEED: float = 300.0
@export var gravity_override: float = -1.0

@export_group("Vão / Altura Mínima")
@export var min_vertical_clearance_px: float = 120.0    # vão mínimo chão→plataforma p/ capi
@export var capy_height_px: float = 0.0                 # altura real da capivara (0 = ignora)
@export var min_platform_ground_gap_px: float = 0.0     # altura mínima da plataforma acima do chão (0 = desliga)

@export_group("Parâmetros de Spawn")
@export var spawn_ahead_px: float = 1200.0
@export var despawn_behind_px: float = 1200.0
@export var start_padding_px: float = 200.0
@export var max_new_chunks_per_tick: int = 1            # limite de “trechos” por frame

@export_group("Plataformas")
@export var platform_nominal_width_px: float = 160.0
@export var platform_y_min_px: float = 100.0  # limite superior (topo da tela)
@export var platform_y_max_px: float = 470.0  # limite inferior (perto do chão)
@export var gap_min_px: float = 80.0
@export var gap_safety_factor: float = 0.85

@export_group("Pedras (sempre no chão)")
@export var rock_runup_px: float = 60.0
@export var rock_cooldown_px: float = 60.0
@export var rock_nominal_width_px: float = 64.0

@export_group("Debug")
@export var print_stats: bool = false
@export var debug_draw: bool = false

var _player: Node2D
var _gravity: float
var _jump_speed: float
var _jump_height_px: float
var _jump_air_time_s: float
var _flat_jump_range_px: float

var _safe_gap_max_px: float
var _max_step_up_px: float
var _max_rock_height_px: float
var _required_clearance_px: float

var _next_spawn_x: float
var _last_platform_y: float
var _active_nodes: Array[Node2D] = []

func _ready() -> void:
	_player = get_node_or_null(player_path) as Node2D
	if _player == null:
		push_error("Defina player_path no Inspetor.")
		set_physics_process(false)
		return

	_gravity = gravity_override if gravity_override >= 0.0 else float(ProjectSettings.get_setting("physics/2d/default_gravity", 980.0))
	_jump_speed = abs(JUMP_VELOCITY)
	_jump_height_px = (_jump_speed * _jump_speed) / (2.0 * _gravity)
	_jump_air_time_s = (2.0 * _jump_speed) / _gravity
	_flat_jump_range_px = SPEED * _jump_air_time_s

	_safe_gap_max_px = clamp(gap_safety_factor, 0.2, 1.0) * _flat_jump_range_px
	_max_step_up_px = 0.75 * _jump_height_px
	_max_rock_height_px = 0.70 * _jump_height_px

	_required_clearance_px = max(min_vertical_clearance_px, capy_height_px)

	_last_platform_y = clamp(_player.global_position.y, platform_y_min_px, platform_y_max_px)
	_next_spawn_x = _player.global_position.x + start_padding_px

	# Sanitiza listas de cenas (evita subrecursos/itens inválidos)
	platform_scenes = _filter_valid_scenes(platform_scenes, "plataforma")
	rock_scenes = _filter_valid_scenes(rock_scenes, "pedra")

	if print_stats:
		print("[Spawner] g=%.1f, h=%.1fpx, T=%.3fs, d=%.1fpx, gap<=%.1f, step<=%.1f, rockH<=%.1f, reqClear=%.1f, minPlatGap=%.1f" % [
			_gravity, _jump_height_px, _jump_air_time_s, _flat_jump_range_px,
			_safe_gap_max_px, _max_step_up_px, _max_rock_height_px, _required_clearance_px, min_platform_ground_gap_px
		])

func _physics_process(_delta: float) -> void:
	var px: float = _player.global_position.x

	var spawned_this_tick: int = 0
	while _next_spawn_x < px + spawn_ahead_px and spawned_this_tick < max_new_chunks_per_tick:
		_spawn_next_chunk()
		spawned_this_tick += 1

	# Despawn atrás do player
	for i in range(_active_nodes.size() - 1, -1, -1):
		var n: Node2D = _active_nodes[i]
		if not is_instance_valid(n):
			_active_nodes.remove_at(i)
			continue
		if n.global_position.x < px - despawn_behind_px:
			n.queue_free()
			_active_nodes.remove_at(i)

func _spawn_next_chunk() -> void:
	# 1) Gap alcançável
	var gap_max_effective: float = max(gap_min_px, _safe_gap_max_px - platform_nominal_width_px)
	var gap: float = randf_range(gap_min_px, gap_max_effective)
	var this_platform_width: float = platform_nominal_width_px
	var next_x: float = _next_spawn_x + gap + this_platform_width * 0.5

	# 2) Altura da plataforma alvo (respeitando step up/down)
	var max_up: float = _max_step_up_px
	var max_down: float = _jump_height_px * 1.25
	var dy: float = randf_range(-max_down, max_up) # negativo = mais baixo (y maior), positivo = mais alto (y menor)
	var target_y: float = clamp(_last_platform_y - dy, platform_y_min_px, platform_y_max_px)

	# --- Ajuste com base no chão encontrado (para clearance e altura mínima) ---
	var ground_y: float = _raycast_to_y(Vector2(next_x, -1000.0), Vector2(next_x, 2000.0), ground_collision_mask)
	if not is_nan(ground_y):
		# min_gap_needed = maior entre "vão p/ capi" e "altura mínima da plataforma"
		var min_gap_needed: float = max(_required_clearance_px, min_platform_ground_gap_px)
		# y máximo permitido para a plataforma (quanto menor o y, mais alto está)
		var max_platform_y_allowed: float = ground_y - min_gap_needed
		if target_y > max_platform_y_allowed:
			target_y = max(platform_y_min_px, max_platform_y_allowed)
		# Se mesmo após ajuste, não há espaço suficiente (por limites), cancela este trecho
		if ground_y - target_y < min_gap_needed - 0.5:
			_next_spawn_x += max(64.0, gap_min_px)
			return

	# 3) Plataforma
	var plat: Node2D = _spawn_platform(Vector2(next_x, target_y))
	if plat == null:
		_next_spawn_x += max(64.0, gap_min_px)
		return

	_last_platform_y = target_y

	# 4) Pedra ENTRE plataformas (sempre no chão)
	_try_spawn_rock_between(_next_spawn_x, next_x)

	# 5) Avança cursor
	_next_spawn_x = next_x + this_platform_width * 0.5

func _spawn_platform(pos: Vector2) -> Node2D:
	if platform_scenes.is_empty():
		return null
	var scene: PackedScene = platform_scenes[randi() % platform_scenes.size()]

	if obstacle_collision_mask != 0 and not _is_area_free_rect(pos, Vector2(platform_nominal_width_px*0.5, 16.0), obstacle_collision_mask):
		return null

	var node: Node2D = _instantiate_node2d(scene, "Plataforma")
	if node == null:
		return null

	add_child(node)
	node.global_position = pos

	if _has_property(node, "platform_width_px"):
		node.set("platform_width_px", platform_nominal_width_px)
		if node.has_method("apply_size"):
			node.call("apply_size")
	else:
		node.scale.x = node.scale.x * randf_range(0.9, 1.1)

	_active_nodes.append(node)
	return node

func _try_spawn_rock_between(x_a: float, x_b: float) -> void:
	if rock_scenes.is_empty():
		return
	if x_b - x_a < rock_runup_px + rock_nominal_width_px + rock_cooldown_px:
		return

	var x: float = randf_range(x_a + rock_runup_px, x_b - (rock_nominal_width_px + rock_cooldown_px))

	# Pedra sempre no CHÃO → ray apenas no ground
	var ground_y: float = _raycast_to_y(Vector2(x, -1000.0), Vector2(x, 2000.0), ground_collision_mask)
	if is_nan(ground_y):
		return

	# Verifica se existe plataforma acima e se sobra vão suficiente para capivara + pedra
	var plat_y: float = _raycast_to_y(Vector2(x, ground_y - 2000.0), Vector2(x, ground_y - 1.0), platform_collision_mask)
	if not is_nan(plat_y):
		var ground_to_platform: float = ground_y - plat_y  # y cresce pra baixo → diferença positiva
		var assumed_rock_h: float = _max_rock_height_px    # pior caso
		var min_gap_needed: float = max(_required_clearance_px, min_platform_ground_gap_px)
		if ground_to_platform < min_gap_needed + assumed_rock_h - 0.5:
			return  # não cabe pedra mantendo os vãos mínimos

	var pos: Vector2 = Vector2(x, ground_y)

	if obstacle_collision_mask != 0 and not _is_area_free_rect(pos, Vector2(rock_nominal_width_px*0.5, _max_rock_height_px*0.5), obstacle_collision_mask):
		return

	_spawn_rock_at(pos)

func _spawn_rock_at(pos: Vector2) -> void:
	if rock_scenes.is_empty():
		return
	var scene: PackedScene = rock_scenes[randi() % rock_scenes.size()]
	var rock: Node2D = _instantiate_node2d(scene, "Pedra")
	if rock == null:
		return

	add_child(rock)
	rock.global_position = pos

	if rock.has_node("CollisionShape2D"):
		var cs: CollisionShape2D = rock.get_node("CollisionShape2D") as CollisionShape2D
		if cs and cs.shape is RectangleShape2D:
			var rect: RectangleShape2D = cs.shape as RectangleShape2D
			rect.size = Vector2(rect.size.x, clamp(rect.size.y, 16.0, _max_rock_height_px))

	_active_nodes.append(rock)

# ---------- Utilitários ----------

func _raycast_to_y(from: Vector2, to: Vector2, mask: int) -> float:
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var p: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(from, to)
	p.collision_mask = mask
	p.collide_with_areas = true
	p.collide_with_bodies = true
	var hit: Dictionary = space.intersect_ray(p)
	if hit.is_empty():
		return NAN
	return float(hit.position.y)

func _is_area_free_rect(center: Vector2, half_extents: Vector2, mask: int) -> bool:
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = half_extents * 2.0
	var params: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	params.shape = shape
	params.transform = Transform2D(0.0, center)
	params.collision_mask = mask
	params.collide_with_areas = true
	params.collide_with_bodies = true
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var hits: Array = space.intersect_shape(params, 1)
	return hits.is_empty()

func _has_property(obj: Object, prop_name: String) -> bool:
	var props: Array = obj.get_property_list()
	for i in props.size():
		var p: Dictionary = props[i]
		if p.has("name") and p["name"] == prop_name:
			return true
	return false

func _filter_valid_scenes(list_in: Array[PackedScene], label: String) -> Array[PackedScene]:
	var out: Array[PackedScene] = []
	for i in range(list_in.size()):
		var s: PackedScene = list_in[i]
		if s == null:
			push_warning("[Spawner] %s[%d] é nulo." % [label, i])
			continue
		var path := s.resource_path
		if path == "":
			push_warning("[Spawner] %s[%d] sem resource_path (possível subrecurso). Aponte para um .tscn." % [label, i])
			continue
		if not s.can_instantiate():
			push_warning("[Spawner] %s[%d] (%s) não pode instanciar (cena vazia?)." % [label, i, path])
			continue
		out.append(s)
	return out

func _instantiate_node2d(scene: PackedScene, label: String) -> Node2D:
	if scene == null or not scene.can_instantiate():
		push_warning("[Spawner] %s inválida: %s" % [label, scene])
		return null
	var inst := scene.instantiate()
	if inst == null:
		push_warning("[Spawner] instantiate() retornou null para %s (%s)" % [label, scene.resource_path])
		return null
	var n2d := inst as Node2D
	if n2d == null:
		push_warning("[Spawner] %s raiz não é Node2D (%s)." % [label, scene.resource_path])
		add_child(inst)
		return null
	return n2d

func _draw() -> void:
	if not debug_draw:
		return
	var px: float = _player.global_position.x
	draw_line(Vector2(px - despawn_behind_px, 5), Vector2(px + spawn_ahead_px, 5), Color.SKY_BLUE, 2.0)

func _process(_delta: float) -> void:
	if debug_draw:
		queue_redraw()
