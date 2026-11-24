extends Control
## Pantalla de inicio (GDD 5.3). Los nodos están en Escenas/portada.tscn (visibles en el editor):
## fondo con Chispa, menú (Jugar, Instrucciones, Ranking, Ajustes, Créditos, Salir), alias y pantalla de carga.

const Estilo = preload("res://scripts/estilo.gd")
const TIEMPO_MINIMO_CARGA := 0.8   # segundos que se ve la pantalla de carga como mínimo

@onready var btn_jugar: Button = %BtnJugar
@onready var lbl_jugador: Label = %LblJugador
@onready var aviso: Label = %Aviso
@onready var capa_carga: Control = %Carga
@onready var lbl_carga: Label = %TextoCarga
@onready var barra: ProgressBar = %BarraCarga

var _cargando := false
var _lbl_conexion: Label
var _t_carga := 0.0


func _ready() -> void:
	# Candado: sin un jugador válido no se entra al menú (se vuelve a la pantalla de acceso)
	if not Global.puede_jugar():
		Global.ir_a.call_deferred(Global.ESCENA_ACCESO)
		return
	capa_carga.visible = false

	btn_jugar.pressed.connect(_on_jugar)
	%BtnInstrucciones.pressed.connect(func(): Global.ir_a(Global.ESCENA_INSTRUCCIONES))
	%BtnRanking.pressed.connect(func(): Global.ir_a(Global.ESCENA_RANKING))
	%BtnAjustes.pressed.connect(func(): Global.ir_a(Global.ESCENA_AJUSTES))
	%BtnCreditos.pressed.connect(func(): Global.ir_a(Global.ESCENA_CREDITOS))
	%BtnSalir.pressed.connect(func(): get_tree().quit())
	%BtnCambiar.pressed.connect(_on_cambiar_jugador)
	_mostrar_estado_jugador()
	Audio.musica("menu")
	btn_jugar.grab_focus()
	_crear_indicador_conexion()


## RF-07: indicador "En línea / Sin conexión" en la esquina superior derecha.
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
	_lbl_conexion.offset_bottom = 70
	_lbl_conexion.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_lbl_conexion)
	_lbl_conexion.text = "● Comprobando conexión..."
	_lbl_conexion.add_theme_color_override("font_color", Color(Estilo.TEXTO, 0.7))
	Global.conexion_cambiada.connect(_pintar_conexion)
	_pintar_conexion(await Global.comprobar_conexion())


func _pintar_conexion(en_linea: bool) -> void:
	if not is_instance_valid(_lbl_conexion):
		return
	_mostrar_estado_jugador()
	var n := Global.pendientes.size()
	if en_linea:
		_lbl_conexion.text = "● En línea · ranking en la nube"
		if n > 0:
			_lbl_conexion.text += "\nSubiendo %d partida(s) guardada(s) sin conexión..." % n
		_lbl_conexion.add_theme_color_override("font_color", Estilo.VERDE)
	else:
		_lbl_conexion.text = ("● Sin conexión · modo local (puedes jugar igual)" if Supabase.configurada
			else "● Nube sin configurar (falta config.cfg) · modo local")
		if n > 0:
			_lbl_conexion.text += "\n%d partida(s) esperando para subir a la nube" % n
		_lbl_conexion.add_theme_color_override("font_color", Color("#FFB37A"))


func _mostrar_estado_jugador() -> void:
	var rec := Global.record_de(Global.alias)
	if Global.tiene_sesion():
		lbl_jugador.text = "👤 %s" % Global.alias
		lbl_jugador.add_theme_color_override("font_color", Estilo.ORO)
		_aviso_ok(("Tu récord: %s" % Estilo.miles(rec)) if rec > 0 else "¡Listo para jugar!")
	else:
		lbl_jugador.text = "👤 %s (modo local)" % Global.alias
		lbl_jugador.add_theme_color_override("font_color", Color("#FFB37A"))
		if Global.en_linea:
			_aviso_naranja("Volvió el internet: pulsa Jugar para entrar con tu PIN y subir tus puntuaciones.")
		else:
			_aviso_naranja("Sin conexión: tus puntuaciones se subirán cuando vuelvas a entrar con tu PIN.")


## "Cambiar jugador": cierra la sesión de este dispositivo y vuelve a la pantalla de acceso.
func _on_cambiar_jugador() -> void:
	if _cargando:
		return
	Audio.sfx_ui("confirmar")
	Global.cerrar_sesion()
	Global.ir_a(Global.ESCENA_ACCESO)


func _aviso_naranja(texto: String) -> void:
	aviso.text = texto
	aviso.add_theme_color_override("font_color", Color("#FFB37A"))


func _aviso_ok(texto: String) -> void:
	aviso.text = texto
	aviso.add_theme_color_override("font_color", Estilo.VERDE)


func _aviso_error(texto: String) -> void:
	aviso.text = texto
	aviso.add_theme_color_override("font_color", Estilo.ROJO)


func _on_jugar() -> void:
	if _cargando:
		return
	# Candado: sin jugador válido no se inicia el juego.
	# (Si entró sin internet y ya volvió la conexión, debe entrar con su PIN.)
	if not Global.puede_jugar():
		Audio.sfx_ui("error")
		Global.ir_a(Global.ESCENA_ACCESO)
		return
	# Historia: la primera vez se cuenta en cómic antes de jugar
	if not Global.historia_vista:
		Global.historia_vista = true
		Global.guardar()
		Global.ver_comic("inicio", Global.ESCENA_MUNDO)
		return
	# Mostrar "Cargando..." y cargar el mundo en segundo plano
	_cargando = true
	_t_carga = 0.0
	barra.value = 0.0
	capa_carga.visible = true
	if ResourceLoader.load_threaded_request(Global.ESCENA_MUNDO) != OK:
		_fallo_carga()


func _process(delta: float) -> void:
	if not _cargando:
		return
	_t_carga += delta
	lbl_carga.text = "Cargando" + ".".repeat(int(_t_carga * 2.5) % 4)
	var progreso: Array = []
	match ResourceLoader.load_threaded_get_status(Global.ESCENA_MUNDO, progreso):
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			var meta := float(progreso[0]) * 100.0 if progreso.size() > 0 else 0.0
			barra.value = lerpf(barra.value, meta, 0.2)
		ResourceLoader.THREAD_LOAD_LOADED:
			barra.value = lerpf(barra.value, 100.0, 0.25)
			if _t_carga >= TIEMPO_MINIMO_CARGA:
				_entrar_al_juego()
		_:
			_fallo_carga()


func _entrar_al_juego() -> void:
	_cargando = false
	var escena := ResourceLoader.load_threaded_get(Global.ESCENA_MUNDO) as PackedScene
	if escena == null:
		_fallo_carga()
		return
	get_tree().paused = false
	get_tree().change_scene_to_packed(escena)


func _fallo_carga() -> void:
	_cargando = false
	capa_carga.visible = false
	_aviso_error("No se pudo cargar el juego.")
	btn_jugar.grab_focus()
