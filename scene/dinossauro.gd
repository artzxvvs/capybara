extends Area2D

@export var speed: float = 180.0
@onready var anim: AnimatedSprite2D = $dinossauro

var player: Node2D
var ativo: bool = false

func _ready():
	anim.play("idle")
	connect("body_entered", _on_body_entered)
	
	var timer = Timer.new()
	timer.wait_time = 3.0
	timer.one_shot = true
	add_child(timer)
	timer.connect("timeout", Callable(self, "_ativar_dino"))
	timer.start()

func _ativar_dino():
	ativo = true
	player = get_tree().get_root().get_node("Game/Player") # Ajuste o caminho se necessário!

func _process(delta):
	if ativo and player:
		var destino = Vector2(player.global_position.x, global_position.y)  # Y fixo!
		var direction = (destino - global_position)
		var distancia = direction.length()
		if distancia > 5:
			var dir_norm = direction.normalized()
			global_position += dir_norm * speed * delta
			if anim.animation != "walk":
				anim.play("walk")
			anim.flip_h = dir_norm.x < 0
		else:
			if anim.animation != "idle":
				anim.play("idle")

func _on_body_entered(body):
	if ativo and body.name == "Player":
		Dados.vidas = clamp(Dados.vidas - 1, 0, Dados.vida_max)
		anim.play("attack")
