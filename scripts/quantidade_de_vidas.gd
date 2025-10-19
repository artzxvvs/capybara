extends Label


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if Dados.vidas == 3:
		$"../Life".show()
		$"../Life2".show()
		$"../Life3".show()
		$"../nolife".hide()
		$"../nolife2".hide()
		$"../nolife3".hide()
	if Dados.vidas == 2:
		$"../Life3".hide()
		$"../nolife3".show()
	if Dados.vidas == 1:
		$"../Life3".hide()
		$"../nolife3".show()
		$"../Life2".hide()
		$"../nolife2".show()
	if Dados.vidas == 0:
		$"../Life".hide()
		$"../Life2".hide()
		$"../Life3".hide()
		$"../nolife".show()
		$"../nolife2".show()
		$"../nolife3".show()
		
