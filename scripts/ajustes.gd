extends Control
## Pantalla de Ajustes de Luminar. Los nodos están en Escenas/ajustes.tscn (visibles en el editor).
## Pestañas: Sonido, Pantalla, Controles y Perfil.
## Todo se aplica en vivo a través de Global y se guarda en user://luminar.json.

## Se emite al cerrar los ajustes cuando se abrieron desde el menú de pausa.
signal cerrado

## Poner en true ANTES de add_child() para usar Ajustes como superposición dentro del juego.
var modo_pausa := false

const Estilo = preload("res://scripts/estilo.gd")

# clave de Global.ajustes -> nombre del nodo en la escena
const SLIDERS := {"vol_master": "Master", "vol_musica": "Musica", "vol_efectos": "Efectos", "brillo": "Brillo"}
const CHECKS := {"silencio": "CheckSilencio", "pantalla_completa": "CheckPantallaCompleta",
	"vsync": "CheckVsync", "enviar_online": "CheckEnviarOnline"}

@onready var paginas := {
	"sonido": %PaginaSonido, "pantalla": %PaginaPantalla, "controles": %PaginaControles, "perfil": %PaginaPerfil,
}
@onready var tabs := {
	"sonido": %TabSonido, "pantalla": %TabPantalla, "controles": %TabControles, "perfil": %TabPerfil,
}
@onready var aviso: Label = %Aviso
@onready var btn_restablecer: Button = %BtnRestablecer
@onready var grid_teclas: GridContainer = %GridTeclas
@onready var campo_alias: LineEdit = %CampoAlias

var _actual := "sonido"
var _captura: Dictionary = {}          # {accion, slot} mientras se espera una tecla


func _ready() -> void:
	# En pausa: velo negro para ver el juego detrás y sin la pestaña Perfil
	if modo_pausa:
		%Fondo.visible = false
		%Velo.color = Color(0, 0, 0, 0.8)
		tabs["perfil"].visible = false
	else:
		Audio.musica("menu")

	for id in tabs:
		tabs[id].pressed.connect(_mostrar_pagina.bind(id))

	for clave in SLIDERS:
		var s := _slider(clave)
		s.value_changed.connect(_on_slider.bind(clave))
		s.drag_ended.connect(_on_slider_soltado.bind(clave))
	for clave in CHECKS:
		(get_node("%" + CHECKS[clave]) as CheckButton).toggled.connect(_on_check.bind(clave))

	for accion in Global.ACCIONES:
		for slot in 2:
			_boton_tecla(accion, slot).pressed.connect(_iniciar_captura.bind(accion, slot))

	campo_alias.text_submitted.connect(func(_t): _guardar_alias())
	%BtnGuardarAlias.pressed.connect(_guardar_alias)
	%BtnBorrar.pressed.connect(_confirmar_borrado)
	btn_restablecer.pressed.connect(_restablecer_pagina)
	%BtnVolver.pressed.connect(_volver)
	tree_exiting.connect(Global.guardar)

	_refrescar_valores()
	_mostrar_pagina("sonido")
	tabs["sonido"].button_pressed = true
	tabs["sonido"].grab_focus()


# ======================================================
#  ENTRADA
# ======================================================
func _input(event: InputEvent) -> void:
	if _captura.is_empty():
		return
	var ev := event as InputEventKey
	if ev == null or not ev.pressed or ev.echo:
		return
	get_viewport().set_input_as_handled()

	var k: int = ev.physical_keycode
	var accion: String = _captura["accion"]
	var slot: int = _captura["slot"]

	if k == KEY_ESCAPE:
		_cancelar_captura()
		aviso.text = ""
		return
	# Supr / Retroceso quitan la tecla alterna (la principal siempre existe)
	if slot == 1 and (k == KEY_DELETE or k == KEY_BACKSPACE):
		_asignar_tecla(accion, slot, 0)
		return
	# Evitar la misma tecla en dos acciones
	for otra in Global.ACCIONES:
		var asignadas := Global.get_teclas(otra)
		for s in 2:
			if asignadas[s] == k and not (otra == accion and s == slot):
				_cancelar_captura()
				_aviso_error("Esa tecla ya se usa en «%s»." % Global.ACCIONES[otra])
				return
	_asignar_tecla(accion, slot, k)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _captura.is_empty():
		get_viewport().set_input_as_handled()
		_volver()


# ======================================================
#  PÁGINAS Y VALORES
# ======================================================
func _mostrar_pagina(id: String) -> void:
	_actual = id
	_cancelar_captura()
	aviso.text = ""
	for clave in paginas:
		paginas[clave].visible = (clave == id)
	btn_restablecer.visible = (id != "perfil")


## Copia los valores guardados en Global a los controles de la escena.
func _refrescar_valores() -> void:
	for clave in SLIDERS:
		var v := float(Global.ajustes[clave])
		_slider(clave).set_value_no_signal(v)
		_valor(clave).text = _porcentaje(v)
	for clave in CHECKS:
		(get_node("%" + CHECKS[clave]) as CheckButton).set_pressed_no_signal(bool(Global.ajustes[clave]))
	campo_alias.text = Global.alias
	_refrescar_teclas()


func _slider(clave: String) -> HSlider:
	return get_node("%Slider" + SLIDERS[clave]) as HSlider


func _valor(clave: String) -> Label:
	return get_node("%Valor" + SLIDERS[clave]) as Label


func _boton_tecla(accion: String, slot: int) -> Button:
	return grid_teclas.get_node("%s_%d" % [accion, slot]) as Button


func _on_slider(v: float, clave: String) -> void:
	Global.ajustes[clave] = v
	_valor(clave).text = _porcentaje(v)
	Global.aplicar_ajustes()


## GDD 6.3: al soltar el control de volumen suena una muestra.
func _on_slider_soltado(_cambio: bool, clave: String) -> void:
	Global.guardar()
	if clave == "vol_efectos" or clave == "vol_master":
		Audio.sfx_ui("celda")


func _on_check(activo: bool, clave: String) -> void:
	Global.ajustes[clave] = activo
	Global.aplicar_ajustes()
	Global.guardar()


func _porcentaje(v: float) -> String:
	return "%d%%" % int(round(v * 100.0))


# ======================================================
#  CONTROLES: captura de teclas
# ======================================================
func _iniciar_captura(accion: String, slot: int) -> void:
	_cancelar_captura()
	_captura = {"accion": accion, "slot": slot}
	_boton_tecla(accion, slot).text = "Pulsa una tecla…"
	_aviso_ok("Pulsa la nueva tecla (Esc para cancelar).")


func _cancelar_captura() -> void:
	if _captura.is_empty():
		return
	_captura.clear()
	_refrescar_teclas()


func _asignar_tecla(accion: String, slot: int, tecla: int) -> void:
	_captura.clear()
	Global.set_tecla(accion, slot, tecla)
	_refrescar_teclas()
	_aviso_ok("Tecla asignada.")


func _refrescar_teclas() -> void:
	for accion in Global.ACCIONES:
		var asignadas := Global.get_teclas(accion)
		for slot in 2:
			var b := _boton_tecla(accion, slot)
			if b:
				var k := int(asignadas[slot])
				b.text = "—" if k == 0 else Estilo.nombre_tecla(k)


# ======================================================
#  PERFIL y PIE
# ======================================================
func _guardar_alias() -> void:
	var texto := campo_alias.text.strip_edges()
	if texto.length() < 3:
		_aviso_error("El alias debe tener al menos 3 caracteres.")
		Audio.sfx_ui("error")
		return
	Global.alias = texto
	Global.guardar()
	_aviso_ok("Alias guardado: %s" % texto)
	Audio.sfx_ui("confirmar")


func _confirmar_borrado() -> void:
	var d := ConfirmationDialog.new()
	d.title = "Borrar progreso"
	d.dialog_text = "Se borrará el ranking local de este dispositivo.\nTu alias se conserva. ¿Continuar?"
	d.ok_button_text = "Borrar"
	d.cancel_button_text = "Cancelar"
	d.confirmed.connect(_on_borrado_confirmado)
	d.visibility_changed.connect(_on_dialogo_visible.bind(d))
	add_child(d)
	d.popup_centered()


func _on_dialogo_visible(d: ConfirmationDialog) -> void:
	if not d.visible:
		d.queue_free()


func _on_borrado_confirmado() -> void:
	Global.borrar_progreso_local()
	_aviso_ok("Progreso local borrado.")


func _restablecer_pagina() -> void:
	match _actual:
		"sonido":
			Global.restablecer_ajustes(["vol_master", "vol_musica", "vol_efectos", "silencio"])
		"pantalla":
			Global.restablecer_ajustes(["pantalla_completa", "vsync", "brillo"])
		"controles":
			Global.restablecer_teclas()
	_refrescar_valores()
	_aviso_ok("Valores restablecidos.")


func _volver() -> void:
	Global.guardar()
	if modo_pausa:
		cerrado.emit()
		queue_free()
		return
	Global.ir_a(Global.ESCENA_PORTADA)


func _aviso_ok(texto: String) -> void:
	aviso.add_theme_color_override("font_color", Estilo.ORO)
	aviso.text = texto


func _aviso_error(texto: String) -> void:
	aviso.add_theme_color_override("font_color", Estilo.ROJO)
	aviso.text = texto
