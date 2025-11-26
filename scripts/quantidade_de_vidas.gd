extends Label

func _process(_delta: float) -> void:
	if Dados.vidas == 3:
		$"../Life".show()
		$"../Life2".show()
		$"../Life3".show()
		$"../nolife".hide()
		$"../nolife2".hide()
		$"../nolife3".hide()
	elif Dados.vidas == 2:
		$"../Life3".hide()
		$"../nolife3".show()
		$"../Life2".show()
		$"../nolife2".hide()
		$"../Life".show()
		$"../nolife".hide()
	elif Dados.vidas == 1:
		$"../Life3".hide()
		$"../nolife3".show()
		$"../Life2".hide()
		$"../nolife2".show()
		$"../Life".show()
		$"../nolife".hide()
	elif Dados.vidas == 0:
		$"../Life".hide()
		$"../Life2".hide()
		$"../Life3".hide()
		$"../nolife".show()
		$"../nolife2".show()
		$"../nolife3".show()
