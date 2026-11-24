extends Control
## Pantalla de Instrucciones (GDD 5.3, punto 2). Los textos y tarjetas están en
## Escenas/instrucciones.tscn; aquí solo se escriben las teclas actuales y se conectan los botones.

const Estilo = preload("res://scripts/estilo.gd")

@onready var tabla_controles: GridContainer = %TablaControles


func _ready() -> void:
	Audio.musica("menu")
	_refrescar_controles()
	%BtnVolver.pressed.connect(func(): Global.ir_a(Global.ESCENA_PORTADA))
	%BtnJugar.pressed.connect(_jugar)
	%BtnHistoria.pressed.connect(func(): Global.ver_comic("inicio", Global.ESCENA_INSTRUCCIONES))
	%BtnVolver.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		Global.ir_a(Global.ESCENA_PORTADA)


func _jugar() -> void:
	# El alias es obligatorio (GDD 2.1): si no hay, se vuelve al inicio para registrarlo
	Global.ir_a(Global.ESCENA_MUNDO if Global.puede_jugar() else Global.ESCENA_ACCESO)


func _refrescar_controles() -> void:
	var filas: Array = []
	for accion in Global.ACCIONES:
		var nombres := PackedStringArray()
		for k in Global.get_teclas(accion):
			if int(k) != 0:
				nombres.append(Estilo.nombre_tecla(int(k)))
		filas.append([Global.ACCIONES[accion], " / ".join(nombres)])
	filas.append(["Pausar / reanudar", "P / Esc"])
	filas.append(["Silenciar audio", "M"])
	for i in filas.size():
		var a := tabla_controles.get_node_or_null("Accion%d" % i) as Label
		var t := tabla_controles.get_node_or_null("Tecla%d" % i) as Label
		if a and t:
			a.text = filas[i][0]
			t.text = filas[i][1]
