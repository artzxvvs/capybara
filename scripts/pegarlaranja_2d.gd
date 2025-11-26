extends Area2D

var pode_interagir: bool = false
var jogador

@onready var interagir_png: Sprite2D = $interagirpng          # Ícone "E" ("interagirlabel" se for Label)
@onready var coleta_particula: CPUParticles2D = $ColetaParticle
@onready var coleta_som: AudioStreamPlayer2D = $ColetaSom
@onready var sprite: Sprite2D = $Sprite2D                     # Laranja

func _ready():
	interagir_png.visible = false
	coleta_particula.emitting = false
	connect("body_entered", _on_body_entered)
	connect("body_exited", _on_body_exited)

func _on_body_entered(body):
	if body.name == "Player":
		pode_interagir = true
		jogador = body
		interagir_png.visible = true

func _on_body_exited(body):
	if body.name == "Player":
		pode_interagir = false
		jogador = null
		interagir_png.visible = false

func _process(_delta):
	if pode_interagir and Input.is_action_just_pressed("ui_accept"):
		if jogador:
			jogador.recuperar_vida()
		coleta_som.play()
		coleta_particula.emitting = true
		interagir_png.visible = false
		animar_pulo()

func animar_pulo():
	var tween = create_tween()
	# Efeito shake lateral rápido
	for i in range(6):
		var dx = randf_range(-8.0, 8.0)
		tween.tween_property(sprite, "position:x", sprite.position.x + dx, 0.025)
		tween.tween_property(sprite, "position:x", sprite.position.x, 0.025)
	# Pulo (escala)
	tween.tween_property(sprite, "scale", Vector2(1.3, 0.7), 0.18)
	tween.tween_property(sprite, "scale", Vector2(0.0, 0.0), 0.18).set_delay(0.12)
	tween.tween_callback(func():
		queue_free()
	)
