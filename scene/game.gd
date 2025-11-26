extends Node2D

@export var item_scene: PackedScene           # Arraste sua cena de item, ex: laranja.tscn
@export var intervalo: float = 2.0            # Tempo entre cada geração automática
@export var limite_maximo: int = 8000         # Limite final do chão (ajuste pra largura da sua tela/fase)
@export var distancia_frente: int = 50        # Mínimo de distância à frente do player para spawnar


	

func _spawn_dino():
	var dinossauro_scene = load("res://dinossauro.tscn")
	var dino = dinossauro_scene.instantiate()
	# Pegue a posição Y do player para alinhar no chão
	var pos_y = $Player.global_position.y              # ajuste o caminho do seu player se necessário
	dino.global_position = Vector2(900, pos_y)         # escolha X e Y conforme seu mapa
	add_child(dino)
var timer := Timer.new()

func _ready():
	add_child(timer)
	timer.wait_time = intervalo
	timer.timeout.connect(gerar_itens)
	timer.start()
	


func gerar_itens():
	var player = $Player
	if player == null:
		push_warning("Não encontrei o Player na cena!")
		return

	var player_x = player.position.x
	var pos_y = $parallex/ParallaxBackground/StaticBody2D/CollisionShape2D.global_position.y

	var min_x = int(player_x) + distancia_frente
	var max_x = limite_maximo

	# Dá spawnar até 3 itens de cada vez, sempre em pontos diferentes à frente do Player
	for i in range(3):
		if min_x >= max_x:
			break  # Garante que não bugue se o player estiver muito à frente

		var x = randi() % (max_x - min_x) + min_x

		# Se quiser garantir espaçamento mínimo entre frutas:
		# x += i * 40   # cada fruta fica pelo menos 40 pixels à frente da anterior

		var item = item_scene.instantiate()
		item.position = Vector2(x, pos_y)
		add_child(item)
