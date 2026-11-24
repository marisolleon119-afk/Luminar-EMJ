extends Control
## Pantalla de acceso (RF-01). Es la primera pantalla del juego: sin un alias válido
## y su PIN no se puede pasar al menú ni jugar.
##   - Alias nuevo  -> se registra y queda protegido con el PIN.
##   - Alias de otro -> solo entra con el PIN correcto (en cualquier dispositivo).
##   - Sin internet -> se puede jugar en modo local con un alias válido; las partidas
##                     se suben cuando vuelva a entrar con su PIN.
## Siempre se pregunta quién juega. Si este equipo tiene una sesión guardada se ofrece
## "Continuar como X" o "Entrar con otro jugador" (útil al compartir la computadora o el juego).

const Estilo = preload("res://scripts/estilo.gd")
const NARANJA := Color("#FFB37A")

@onready var campo_alias: LineEdit = %CampoAlias
@onready var campo_pin: LineEdit = %CampoPin
@onready var aviso: Label = %Aviso
@onready var btn_entrar: Button = %BtnEntrar
@onready var btn_local: Button = %BtnLocal

var _lbl_conexion: Label
var _ocupado := false


func _ready() -> void:
	btn_entrar.pressed.connect(_on_entrar)
	%BtnContinuar.pressed.connect(_on_continuar_sesion)
	%BtnOtro.pressed.connect(_on_otro_jugador)
	btn_local.pressed.connect(_on_jugar_local)
	%BtnSalir.pressed.connect(func(): get_tree().quit())
	campo_alias.text_submitted.connect(func(_t): campo_pin.grab_focus())
	campo_pin.text_submitted.connect(func(_t): _on_entrar())
	campo_pin.text_changed.connect(_solo_numeros)
	campo_alias.text_changed.connect(func(_t): btn_local.visible = false)

	# Si antes jugó alguien en este equipo, se sugiere su alias (igual debe poner el PIN)
	campo_alias.text = Global.alias
	if Global.alias != "":
		_aviso("Escribe tu PIN para entrar como %s, o cambia el alias." % Global.alias, Color(Estilo.TEXTO, 0.85))
		campo_pin.grab_focus()
	else:
		campo_alias.grab_focus()

	Audio.musica("menu")
	_crear_indicador_conexion()
	_crear_version()
	if Global.tiene_sesion():
		_mostrar_recordado()


## Hay un jugador recordado: se pregunta si es él antes de entrar (nunca entra solo).
func _mostrar_recordado() -> void:
	%Formulario.visible = false
	$Centro/Panel/Col/Explicacion.visible = false
	%Recordado.visible = true
	%LblRecordado.text = "Último jugador en este equipo:"
	%BtnContinuar.text = "▶  Continuar como %s" % Global.alias
	%BtnContinuar.grab_focus()


func _on_continuar_sesion() -> void:
	Audio.sfx_ui("confirmar")
	Global.ir_a(Global.ESCENA_PORTADA)


func _on_otro_jugador() -> void:
	Audio.sfx_ui("confirmar")
	Global.cerrar_sesion()
	%Recordado.visible = false
	%Formulario.visible = true
	$Centro/Panel/Col/Explicacion.visible = true
	campo_alias.text = ""
	campo_pin.text = ""
	_aviso("", Estilo.TEXTO)
	campo_alias.grab_focus()


func _crear_indicador_conexion() -> void:
	_lbl_conexion = Label.new()
	_lbl_conexion.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_lbl_conexion.add_theme_font_size_override("font_size", 18)
	_lbl_conexion.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_lbl_conexion.add_theme_constant_override("outline_size", 4)
	_lbl_conexion.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_lbl_conexion.offset_left = -620
	_lbl_conexion.offset_right = -24
	_lbl_conexion.offset_top = 16
	_lbl_conexion.offset_bottom = 50
	_lbl_conexion.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_lbl_conexion)
	_lbl_conexion.text = "● Comprobando conexión..."
	_lbl_conexion.add_theme_color_override("font_color", Color(Estilo.TEXTO, 0.7))
	Global.conexion_cambiada.connect(_pintar_conexion)
	_pintar_conexion(await Global.comprobar_conexion())


## Versión del juego abajo a la derecha (Proyecto > Configuración > Aplicación > Versión)
func _crear_version() -> void:
	var v := Label.new()
	v.text = "Luminar v%s" % str(ProjectSettings.get_setting("application/config/version", "1.0.0"))
	v.add_theme_font_size_override("font_size", 14)
	v.add_theme_color_override("font_color", Color(Estilo.TEXTO, 0.55))
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	v.offset_left = -300
	v.offset_top = -34
	v.offset_right = -18
	v.offset_bottom = -10
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(v)


func _pintar_conexion(en_linea: bool) -> void:
	if not is_instance_valid(_lbl_conexion):
		return
	_lbl_conexion.text = Global.texto_conexion()
	_lbl_conexion.add_theme_color_override("font_color", Estilo.VERDE if en_linea else NARANJA)


func _solo_numeros(texto: String) -> void:
	var limpio := ""
	for c in texto:
		if c >= "0" and c <= "9":
			limpio += c
	if limpio != texto:
		campo_pin.text = limpio
		campo_pin.caret_column = limpio.length()


func _aviso(texto: String, color: Color) -> void:
	aviso.text = texto
	aviso.add_theme_color_override("font_color", color)


func _on_entrar() -> void:
	if _ocupado:
		return
	btn_local.visible = false
	var texto := Global.normalizar_alias(campo_alias.text)
	var pin := campo_pin.text.strip_edges()

	# 1) Validación en el juego (RF-08): no se envía nada si el formato no es válido
	var err := Global.validar_alias(texto)
	if err != "":
		_rechazar(err, campo_alias)
		return
	err = Global.validar_pin(pin)
	if err != "":
		_rechazar(err, campo_pin)
		return

	# 2) Validación en el servidor: alias libre, o alias propio con su PIN
	_ocupado = true
	btn_entrar.disabled = true
	_aviso("Comprobando alias...", Color(Estilo.TEXTO, 0.7))
	var r: Dictionary = await Global.iniciar_sesion(texto, pin)
	_ocupado = false
	if not is_inside_tree():
		return
	btn_entrar.disabled = false

	if r.ok:
		Audio.sfx_ui("confirmar")
		if r.get("nuevo", false):
			_aviso("¡Bienvenido, %s! Tu alias quedó protegido con tu PIN." % Global.alias, Estilo.VERDE)
		else:
			_aviso("¡Hola de nuevo, %s!" % Global.alias, Estilo.VERDE)
		btn_entrar.disabled = true
		await get_tree().create_timer(0.9).timeout
		Global.ir_a(Global.ESCENA_PORTADA)
	elif r.error == "SIN_CONEXION":
		Audio.sfx_ui("error")
		if Supabase.configurada:
			_aviso("Sin conexión: no se pudo comprobar el alias. Puedes jugar en modo local; tus puntuaciones se subirán cuando vuelvas a entrar con tu PIN.", NARANJA)
		else:
			_aviso(str(r.mensaje) + " Mientras tanto puedes jugar en modo local.", NARANJA)
		btn_local.visible = true
		btn_local.grab_focus()
	else:
		_rechazar(r.mensaje, campo_pin if r.error in ["ALIAS_EN_USO", "PIN_INVALIDO"] else campo_alias)


func _rechazar(mensaje: String, foco: LineEdit) -> void:
	Audio.sfx_ui("error")
	_aviso(mensaje, Color("#FF7A7A"))
	campo_pin.clear()
	foco.grab_focus()
	# Pequeña sacudida del panel para que se note el error
	var panel: Control = $Centro/Panel
	var tw := panel.create_tween()
	for dx in [10.0, -8.0, 6.0, -3.0, 0.0]:
		tw.tween_property(panel, "position:x", panel.position.x + dx, 0.04)


## Solo aparece si no hay internet. El alias ya pasó la validación de formato.
func _on_jugar_local() -> void:
	var texto := Global.normalizar_alias(campo_alias.text)
	if Global.validar_alias(texto) != "":
		_rechazar(Global.validar_alias(texto), campo_alias)
		btn_local.visible = false
		return
	Global.usar_alias_sin_conexion(texto)
	Audio.sfx_ui("confirmar")
	Global.ir_a(Global.ESCENA_PORTADA)
