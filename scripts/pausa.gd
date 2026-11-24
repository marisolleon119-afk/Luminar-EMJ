extends CanvasLayer
## Botones de pausa y sonido + menú de pausa (GDD 2.7 y 5.3). Los nodos están en Escenas/pausa.tscn.
##   - P o Esc pausan / reanudan. M silencia (lo maneja Global).
##   - Menú: Continuar (cuenta regresiva de 3 s), Reiniciar, Cómo jugar, Ajustes y Salir al menú.
##   - Reiniciar o salir a mitad de partida no guarda puntuación.

const Estilo = preload("res://scripts/estilo.gd")
const TEX_SONIDO_ON := preload("res://Recursos/UI/sonido_on.png")
const TEX_SONIDO_OFF := preload("res://Recursos/UI/sonido_off.png")
const SEGUNDOS_CUENTA := 3

@onready var btn_pausa: Button = %BtnPausa
@onready var btn_sonido: Button = %BtnSonido
@onready var menu: Control = %Menu
@onready var ayuda: Control = %Ayuda
@onready var lbl_cuenta: Label = %Cuenta
@onready var btn_continuar: Button = %BtnContinuar
@onready var tabla_controles: GridContainer = %TablaControles

var _ajustes: Control = null
var _contando := false


func _ready() -> void:
	menu.visible = false
	ayuda.visible = false
	lbl_cuenta.visible = false
	btn_pausa.pressed.connect(pausar_juego)
	btn_sonido.pressed.connect(func(): Global.alternar_silencio())
	btn_continuar.pressed.connect(reanudar)
	%BtnReiniciar.pressed.connect(func(): Global.ir_a(Global.ESCENA_MUNDO))
	%BtnAyuda.pressed.connect(_abrir_ayuda)
	%BtnAjustes.pressed.connect(_abrir_ajustes)
	%BtnSalir.pressed.connect(func(): Global.ir_a(Global.ESCENA_PORTADA))
	%BtnVolverAyuda.pressed.connect(_cerrar_ayuda)
	Global.silencio_cambiado.connect(func(_s): _refrescar_sonido())
	_refrescar_sonido()


func _unhandled_input(event: InputEvent) -> void:
	if _contando:
		return
	var tecla_pausa := event.is_action_pressed("pausar") and not event.is_echo()
	var cancelar := event.is_action_pressed("ui_cancel")
	if not (tecla_pausa or cancelar):
		return
	if ayuda.visible:
		get_viewport().set_input_as_handled()
		_cerrar_ayuda()
		return
	if _ajustes != null:
		return   # los Ajustes manejan su propio Esc
	get_viewport().set_input_as_handled()
	if get_tree().paused:
		reanudar()
	elif tecla_pausa:
		pausar_juego()


## MEJORA: si la ventana pierde el foco (Alt+Tab, notificación...), el juego se pausa solo.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if process_mode != Node.PROCESS_MODE_DISABLED and not get_tree().paused and not _contando:
			pausar_juego()


func pausar_juego() -> void:
	if _contando:
		return
	get_tree().paused = true
	btn_pausa.visible = false
	menu.visible = true
	btn_continuar.grab_focus()
	Audio.sfx_ui("pausa")
	Audio.atenuar_musica(true)


## Cuenta regresiva de 3 s y luego se reanuda (GDD 2.7).
func reanudar() -> void:
	if _contando:
		return
	_contando = true
	menu.visible = false
	lbl_cuenta.visible = true
	for n in range(SEGUNDOS_CUENTA, 0, -1):
		lbl_cuenta.text = str(n)
		Audio.sfx_ui("cuenta")
		lbl_cuenta.pivot_offset = lbl_cuenta.size * 0.5
		lbl_cuenta.scale = Vector2(1.6, 1.6)
		lbl_cuenta.modulate.a = 1.0
		var tw := lbl_cuenta.create_tween().set_parallel(true)
		tw.tween_property(lbl_cuenta, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(lbl_cuenta, "modulate:a", 0.35, 0.9).set_delay(0.1)
		await get_tree().create_timer(1.0).timeout
		if not is_inside_tree():
			return
	lbl_cuenta.visible = false
	Audio.sfx_ui("cuenta_ya")
	Audio.atenuar_musica(false)
	_contando = false
	get_tree().paused = false
	btn_pausa.visible = true


func _abrir_ajustes() -> void:
	var escena := load(Global.ESCENA_AJUSTES) as PackedScene
	_ajustes = escena.instantiate()
	_ajustes.set("modo_pausa", true)            # antes de add_child
	_ajustes.connect("cerrado", _on_ajustes_cerrado)
	add_child(_ajustes)
	menu.visible = false


func _on_ajustes_cerrado() -> void:
	_ajustes = null
	menu.visible = true
	_refrescar_sonido()
	btn_continuar.grab_focus()


func _abrir_ayuda() -> void:
	_refrescar_controles()
	menu.visible = false
	ayuda.visible = true
	%BtnVolverAyuda.grab_focus()


func _cerrar_ayuda() -> void:
	ayuda.visible = false
	menu.visible = true
	btn_continuar.grab_focus()


## Escribe las teclas ACTUALES en la tabla de la escena (si se cambiaron en Ajustes, se reflejan).
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


func _refrescar_sonido() -> void:
	var mudo := Global.esta_silenciado()
	btn_sonido.icon = TEX_SONIDO_OFF if mudo else TEX_SONIDO_ON
	btn_sonido.tooltip_text = "Activar sonido (M)" if mudo else "Silenciar (M)"
