extends Control
## Pantalla de Créditos (GDD 5.6 y 6.4). Todo el contenido está en Escenas/creditos.tscn.


func _ready() -> void:
	Audio.musica("menu")
	%BtnVolver.pressed.connect(func(): Global.ir_a(Global.ESCENA_PORTADA))
	%BtnVolver.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		Global.ir_a(Global.ESCENA_PORTADA)
