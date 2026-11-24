extends Node

const RUTA_GUARDADO := "user://luminar.json"

const ESCENA_ACCESO  := "res://Escenas/acceso.tscn"
const ESCENA_COMIC   := "res://Escenas/comic.tscn"
const ESCENA_PORTADA := "res://Escenas/portada.tscn"
const ESCENA_MUNDO   := "res://Escenas/mundo.tscn"
const ESCENA_RANKING := "res://Escenas/ranking.tscn"
const ESCENA_AJUSTES := "res://Escenas/ajustes.tscn"
const ESCENA_INSTRUCCIONES := "res://Escenas/instrucciones.tscn"
const ESCENA_CREDITOS := "res://Escenas/creditos.tscn"

const PUNTUACION_MAXIMA := 99999   # GDD 2.4: la puntuación se recorta a 0..99,999

# Acciones fijas (no se cambian en Ajustes). GDD 2.2: P/Esc pausa, M silencia.
const ACCIONES_FIJAS := {
	"pausar": [KEY_P, KEY_ESCAPE],
	"silenciar": [KEY_M],
}

# ---------- Ajustes: valores por defecto ----------
# Acciones de Chispa y el nombre que se muestra en la pantalla de Ajustes.
const ACCIONES := {
	"mover_izq": "Mover a la izquierda",
	"mover_der": "Mover a la derecha",
	"mover_arr": "Mover arriba",
	"mover_abj": "Mover abajo",
	"encender_farol": "Encender farol",
	"correr": "Correr (gasta energía)",
}

# [tecla principal, tecla alterna]  (0 = sin asignar). Son physical_keycode.
const TECLAS_DEFECTO := {
	"mover_izq": [KEY_A, KEY_LEFT],
	"mover_der": [KEY_D, KEY_RIGHT],
	"mover_arr": [KEY_W, KEY_UP],
	"mover_abj": [KEY_S, KEY_DOWN],
	"encender_farol": [KEY_E, KEY_SPACE],
	"correr": [KEY_SHIFT, KEY_K],
}

const AJUSTES_DEFECTO := {
	"vol_master": 1.0,
	"vol_musica": 0.7,
	"vol_efectos": 0.85,
	"silencio": false,
	"pantalla_completa": false,
	"vsync": true,
	"brillo": 1.0,          # 0.5 (oscuro) a 1.5 (claro)
	"enviar_online": true,  # enviar puntajes al ranking online
}

signal ranking_cargado(datos: Array, posicion: int, mejor: int)
signal ranking_error
signal puntaje_enviado(ok: bool, mensaje: String)   # resultado del guardado en la nube
signal silencio_cambiado(silencio: bool)
signal conexion_cambiada(en_linea: bool)               # RF-07: el menú y el juego muestran el estado

const MSG_SIN_CONEXION := "Sin conexión: partida guardada en este equipo. Se subirá a la nube cuando vuelva el internet."
var SEG_ENTRE_SUBIDAS := 16.0   # el servidor bloquea 2 partidas del mismo jugador en menos de 15 s

var alias := ""
var id_jugador := ""
var nivel_actual := 1
var _alias_registrado := ""

var ultimo_puntaje := 0
var ranking: Array = []   # ranking local (respaldo)
var pendientes: Array = []  # partidas jugadas sin conexión que faltan por subir a la nube
var en_linea := true        # último estado conocido de la conexión con Supabase
var token := ""             # sesión del dispositivo (la da el servidor al entrar con alias + PIN)
var records: Dictionary = {}   # récord personal por alias (en minúsculas)
var ultimo_es_record := false
var record_anterior := 0
var tutorial_visto := false
var historia_vista := false       # el cómic de inicio se muestra antes de la primera partida
var comic_pendiente: Dictionary = {}   # {historia, destino} para abrir el cómic como escena

const LARGO_ALIAS_MIN := 3
const LARGO_ALIAS_MAX := 12
const PATRON_ALIAS := "^[A-Za-z0-9ÁÉÍÓÚÜÑáéíóúüñ_-]+( [A-Za-z0-9ÁÉÍÓÚÜÑáéíóúüñ_-]+)*$"
## Mensajes para cada error del servidor (RF-07 / RNF-01)
const MENSAJES_ACCESO := {
	"ALIAS_INVALIDO": "Alias no válido: usa de 3 a 12 letras, números, _ o - (un solo espacio entre palabras).",
	"PIN_INVALIDO": "El PIN debe tener exactamente 4 números.",
	"ALIAS_EN_USO": "Ese alias ya es de otro jugador. Si es tuyo, escribe tu PIN correcto.",
	"BLOQUEADO": "Demasiados intentos con ese alias. Espera unos minutos.",
	"SIN_CONEXION": "Sin conexión: no se pudo comprobar el alias.",
	"SIN_CONFIG": "La nube no está configurada: falta el archivo config.cfg junto al juego (ver README).",
	"BD_DESACTUALIZADA": "El servidor no está actualizado: ejecuta luminar_supabase_v2.sql en Supabase.",
	"ERROR_SERVIDOR": "El servidor tuvo un problema. Intenta de nuevo.",
}
var _subiendo := false
var _comprobando := false
var _timer_conexion: Timer

var ajustes: Dictionary = AJUSTES_DEFECTO.duplicate(true)
var teclas: Dictionary = {}   # accion -> [principal, alterna]; vacío = valores por defecto

var _brillo_rect: ColorRect
var _material_aditivo: CanvasItemMaterial

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	cargar()
	_crear_buses_audio()
	_crear_capa_brillo()
	aplicar_ajustes()
	aplicar_teclas()
	_registrar_acciones_fijas()
	RenderingServer.set_default_clear_color(Color("#0A1128"))
	# Cada 20 s, si no hay conexión o hay partidas pendientes, se vuelve a intentar
	_timer_conexion = Timer.new()
	_timer_conexion.wait_time = 20.0
	_timer_conexion.autostart = true
	_timer_conexion.process_mode = Node.PROCESS_MODE_ALWAYS
	_timer_conexion.timeout.connect(func():
		if not en_linea or not pendientes.is_empty():
			comprobar_conexion())
	add_child(_timer_conexion)
	comprobar_conexion.call_deferred()


func _registrar_acciones_fijas() -> void:
	for accion in ACCIONES_FIJAS:
		if not InputMap.has_action(accion):
			InputMap.add_action(accion)
		InputMap.action_erase_events(accion)
		for k in ACCIONES_FIJAS[accion]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(accion, ev)
		_agregar_control(accion)


# M silencia en cualquier pantalla (los campos de texto consumen la tecla antes).
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("silenciar") and not event.is_echo():
		alternar_silencio()
		get_viewport().set_input_as_handled()


func alternar_silencio() -> void:
	ajustes["silencio"] = not bool(ajustes["silencio"])
	_aplicar_audio()
	guardar()
	silencio_cambiado.emit(bool(ajustes["silencio"]))


func esta_silenciado() -> bool:
	return bool(ajustes["silencio"])

# ---------- Navegación ----------
## Abre el cómic ("inicio" o "final") y al terminar va a `destino`.
func ver_comic(historia: String, destino: String) -> void:
	comic_pendiente = {"historia": historia, "destino": destino}
	ir_a(ESCENA_COMIC)


func ir_a(ruta: String) -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(ruta)

# ---------- Guardado local ----------
## GDD 5.5: se valida la partida antes de guardarla (alias, rango de puntuación y tiempo).
func partida_valida(puntos: int, tiempo: int) -> bool:
	return alias.strip_edges().length() >= 3 and puntos >= 0 and puntos <= PUNTUACION_MAXIMA and tiempo >= 0 and tiempo <= 6 * 60 + 5


func registrar_puntaje(puntos: int, celdas: int = 0, faroles: int = 0, combo: int = 1, tiempo: int = 0, nivel: int = 1) -> void:
	puntos = clampi(puntos, 0, PUNTUACION_MAXIMA)
	nivel_actual = nivel
	ultimo_puntaje = puntos
	if not partida_valida(puntos, tiempo):
		puntaje_enviado.emit(false, "Partida no válida: no se guardó")
		return
	record_anterior = record_de(alias)
	ultimo_es_record = puntos > record_anterior and puntos > 0
	if ultimo_es_record:
		records[alias.to_lower()] = puntos
	ranking.append({ "alias": alias, "puntos": puntos })
	ranking.sort_custom(func(a, b): return a["puntos"] > b["puntos"])
	ranking = ranking.slice(0, 10)
	guardar()
	if bool(ajustes["enviar_online"]):
		enviar_puntaje_online(puntos, celdas, faroles, combo, tiempo, nivel)
	else:
		puntaje_enviado.emit(false, "Guardado solo en este equipo (envío en línea desactivado)")

func guardar() -> void:
	var f := FileAccess.open(RUTA_GUARDADO, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({
		"alias": alias,
		"id_jugador": id_jugador,
		"alias_registrado": _alias_registrado,
		"token": token,
		"records": records,
		"tutorial_visto": tutorial_visto,
		"historia_vista": historia_vista,
		"ranking": ranking,
		"pendientes": pendientes,
		"ajustes": ajustes,
		"teclas": teclas,
	}))

func cargar() -> void:
	if not FileAccess.file_exists(RUTA_GUARDADO):
		return
	var f := FileAccess.open(RUTA_GUARDADO, FileAccess.READ)
	if f == null:
		return
	var datos = JSON.parse_string(f.get_as_text())
	if not (datos is Dictionary):
		return

	alias = datos.get("alias", "")
	ranking = datos.get("ranking", [])
	var p = datos.get("pendientes", [])
	pendientes = p if p is Array else []
	id_jugador = str(datos.get("id_jugador", "")).trim_suffix(".0")   # corrige ids guardados como "12.0"
	_alias_registrado = str(datos.get("alias_registrado", ""))
	token = str(datos.get("token", ""))
	var rec = datos.get("records", {})
	records = rec if rec is Dictionary else {}
	tutorial_visto = bool(datos.get("tutorial_visto", false))
	historia_vista = bool(datos.get("historia_vista", false))

	# Ajustes: se mezclan con los valores por defecto (por si se añaden nuevos)
	var guardados = datos.get("ajustes", {})
	if guardados is Dictionary:
		for clave in AJUSTES_DEFECTO:
			if guardados.has(clave):
				ajustes[clave] = guardados[clave]

	# Teclas: JSON devuelve números como float, se convierten a int
	var t = datos.get("teclas", {})
	if t is Dictionary:
		for accion in ACCIONES:
			if t.has(accion) and t[accion] is Array:
				var par: Array = [0, 0]
				for i in mini(t[accion].size(), 2):
					par[i] = int(t[accion][i])
				teclas[accion] = par

# ---------- Ajustes: aplicar ----------
func aplicar_ajustes() -> void:
	_aplicar_audio()
	_aplicar_pantalla()
	_aplicar_brillo()

func restablecer_ajustes(claves: Array) -> void:
	for clave in claves:
		if AJUSTES_DEFECTO.has(clave):
			ajustes[clave] = AJUSTES_DEFECTO[clave]
	aplicar_ajustes()
	guardar()

func borrar_progreso_local() -> void:
	ranking = []
	ultimo_puntaje = 0
	guardar()

# ---------- Teclas ----------
func get_teclas(accion: String) -> Array:
	var origen: Array = teclas.get(accion, TECLAS_DEFECTO.get(accion, []))
	var res: Array = [0, 0]
	for i in mini(origen.size(), 2):
		res[i] = int(origen[i])
	return res

func set_tecla(accion: String, slot: int, tecla: int) -> void:
	var par := get_teclas(accion)
	par[slot] = tecla
	teclas[accion] = par
	aplicar_teclas()
	guardar()

func restablecer_teclas() -> void:
	teclas.clear()
	aplicar_teclas()
	guardar()

# Crea/actualiza las acciones del Input Map. Como Global es un autoload se ejecuta
# antes que Chispa, y Chispa solo crea las acciones que no existen.
func aplicar_teclas() -> void:
	for accion in ACCIONES:
		if not InputMap.has_action(accion):
			InputMap.add_action(accion)
		InputMap.action_erase_events(accion)
		for k in get_teclas(accion):
			if int(k) == 0:
				continue
			var ev := InputEventKey.new()
			ev.physical_keycode = int(k) as Key
			InputMap.action_add_event(accion, ev)
		_agregar_control(accion)


## Mejora: se puede jugar con control (Xbox / PlayStation / genérico).
## Stick izquierdo o cruceta para moverse, A/Cruz para encender, RB/R1 o X/Cuadrado para correr.
const CONTROL := {
	"mover_izq": [[JOY_AXIS_LEFT_X, -1.0], JOY_BUTTON_DPAD_LEFT],
	"mover_der": [[JOY_AXIS_LEFT_X, 1.0], JOY_BUTTON_DPAD_RIGHT],
	"mover_arr": [[JOY_AXIS_LEFT_Y, -1.0], JOY_BUTTON_DPAD_UP],
	"mover_abj": [[JOY_AXIS_LEFT_Y, 1.0], JOY_BUTTON_DPAD_DOWN],
	"encender_farol": [JOY_BUTTON_A],
	"correr": [JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_X],
	"pausar": [JOY_BUTTON_START],
}

func _agregar_control(accion: String) -> void:
	if not CONTROL.has(accion):
		return
	for c in CONTROL[accion]:
		if c is Array:
			var m := InputEventJoypadMotion.new()
			m.axis = c[0]
			m.axis_value = c[1]
			InputMap.action_add_event(accion, m)
		else:
			var b := InputEventJoypadButton.new()
			b.button_index = c
			InputMap.action_add_event(accion, b)
	if accion.begins_with("mover_"):
		InputMap.action_set_deadzone(accion, 0.3)

# ---------- Audio ----------
func _crear_buses_audio() -> void:
	for nombre in ["Musica", "Efectos"]:
		if AudioServer.get_bus_index(nombre) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, nombre)
			AudioServer.set_bus_send(i, "Master")

func _aplicar_audio() -> void:
	var todo_mudo := bool(ajustes["silencio"])
	_volumen_bus("Master",  float(ajustes["vol_master"]),  todo_mudo)
	_volumen_bus("Musica",  float(ajustes["vol_musica"]))
	_volumen_bus("Efectos", float(ajustes["vol_efectos"]))

func _volumen_bus(nombre: String, lineal: float, forzar_mute: bool = false) -> void:
	var i := AudioServer.get_bus_index(nombre)
	if i == -1:
		return
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(lineal, 0.0001)))
	AudioServer.set_bus_mute(i, forzar_mute or lineal <= 0.001)

# ---------- Pantalla ----------
func _aplicar_pantalla() -> void:
	var modo := DisplayServer.WINDOW_MODE_WINDOWED
	if bool(ajustes["pantalla_completa"]):
		modo = DisplayServer.WINDOW_MODE_FULLSCREEN
	if DisplayServer.window_get_mode() != modo:
		DisplayServer.window_set_mode(modo)

	var vsync := DisplayServer.VSYNC_DISABLED
	if bool(ajustes["vsync"]):
		vsync = DisplayServer.VSYNC_ENABLED
	DisplayServer.window_set_vsync_mode(vsync)

# ---------- Brillo ----------
# Capa por encima de todo: negro translúcido para oscurecer, blanco aditivo para aclarar.
func _crear_capa_brillo() -> void:
	var capa := CanvasLayer.new()
	capa.layer = 128
	add_child(capa)

	_material_aditivo = CanvasItemMaterial.new()
	_material_aditivo.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	_brillo_rect = ColorRect.new()
	_brillo_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_brillo_rect.color = Color(0, 0, 0, 0)
	capa.add_child(_brillo_rect)
	_brillo_rect.set_anchors_preset(Control.PRESET_FULL_RECT)

func _aplicar_brillo() -> void:
	if _brillo_rect == null:
		return
	var b := clampf(float(ajustes["brillo"]), 0.5, 1.5)
	if b < 1.0:
		_brillo_rect.material = null
		_brillo_rect.color = Color(0, 0, 0, 1.0 - b)
	elif b > 1.0:
		_brillo_rect.material = _material_aditivo
		_brillo_rect.color = Color(1, 1, 1, (b - 1.0) * 0.5)
	else:
		_brillo_rect.material = null
		_brillo_rect.color = Color(0, 0, 0, 0)

# ---------- Ranking online (Supabase) ----------

# Registra el alias en la nube la primera vez (o si el alias cambió).
## true si este dispositivo tiene una sesión válida para el alias actual.
func tiene_sesion() -> bool:
	return token != "" and alias != "" and _alias_registrado.to_lower() == alias.to_lower()


func record_de(nombre: String) -> int:
	return int(records.get(nombre.to_lower(), 0))


# ---------- Alias (RF-01 y RF-08) ----------
## Quita espacios de más: "  Ana   Luz " -> "Ana Luz"
func normalizar_alias(texto: String) -> String:
	var limpio := ""
	for palabra in texto.strip_edges().split(" ", false):
		limpio += ("" if limpio == "" else " ") + palabra
	return limpio


## Devuelve "" si el alias es válido, o el mensaje de error.
func validar_alias(texto: String) -> String:
	var a := normalizar_alias(texto)
	if a.length() < LARGO_ALIAS_MIN or a.length() > LARGO_ALIAS_MAX:
		return "El alias debe tener de %d a %d caracteres." % [LARGO_ALIAS_MIN, LARGO_ALIAS_MAX]
	var re := RegEx.new()
	re.compile(PATRON_ALIAS)
	if re.search(a) == null:
		return "Usa solo letras, números, _ o - (un espacio entre palabras)."
	return ""


func validar_pin(pin: String) -> String:
	if pin.length() != 4 or not pin.is_valid_int() or "-" in pin or "+" in pin:
		return "El PIN debe tener exactamente 4 números."
	return ""


## Entra con alias + PIN (o lo registra si está libre). Devuelve {ok, error, mensaje, nuevo}.
func iniciar_sesion(texto_alias: String, pin: String) -> Dictionary:
	var a := normalizar_alias(texto_alias)
	var err := validar_alias(a)
	if err == "":
		err = validar_pin(pin)
	if err != "":
		return {"ok": false, "error": "LOCAL", "mensaje": err}
	var r = await Supabase.acceder_jugador(a, pin)
	if r.get("ok", false):
		_marcar_conexion(true)
		alias = str(r.get("alias", a))
		id_jugador = str(r.get("id_jugador", ""))
		token = str(r.get("token", ""))
		_alias_registrado = alias
		guardar()
		if not pendientes.is_empty():
			subir_pendientes()
		return {"ok": true, "nuevo": bool(r.get("nuevo", false)), "mensaje": ""}
	var codigo := str(r.get("error", "ERROR_SERVIDOR"))
	if codigo == "SIN_CONEXION":
		_marcar_conexion(false)
		if not Supabase.configurada:
			# Se trata igual que sin conexión (se puede jugar en modo local), pero con el motivo real
			return {"ok": false, "error": "SIN_CONEXION", "mensaje": MENSAJES_ACCESO["SIN_CONFIG"]}
	var msg: String = MENSAJES_ACCESO.get(codigo, MENSAJES_ACCESO["ERROR_SERVIDOR"])
	if codigo == "ALIAS_EN_USO" and r.has("intentos_restantes"):
		msg += " (Te quedan %d intentos.)" % int(r["intentos_restantes"])
	elif codigo == "BLOQUEADO" and r.has("minutos"):
		msg = "Demasiados intentos con ese alias. Espera %d minutos." % int(r["minutos"])
	return {"ok": false, "error": codigo, "mensaje": msg}


## Sin internet se puede jugar con un alias válido: las partidas quedan pendientes
## y se suben cuando el jugador entre con su PIN.
func usar_alias_sin_conexion(texto_alias: String) -> void:
	alias = normalizar_alias(texto_alias)
	if _alias_registrado.to_lower() != alias.to_lower():
		token = ""
		id_jugador = ""
		_alias_registrado = ""
	guardar()


## ¿Hay un jugador válido para entrar al menú y jugar?
## Con internet hace falta sesión (alias + PIN). Sin internet basta un alias con formato válido.
func puede_jugar() -> bool:
	if tiene_sesion():
		return true
	return alias != "" and validar_alias(alias) == "" and not en_linea


## "Cambiar jugador": se olvida la sesión de este dispositivo. Las partidas pendientes
## se conservan y se subirán cuando su dueño vuelva a entrar con su PIN.
func cerrar_sesion() -> void:
	token = ""
	id_jugador = ""
	_alias_registrado = ""
	alias = ""
	guardar()


func _asegurar_jugador() -> bool:
	return tiene_sesion()

# ---------- Conexión y partidas pendientes (RF-07) ----------
func _marcar_conexion(valor: bool) -> void:
	if valor != en_linea:
		en_linea = valor
		conexion_cambiada.emit(en_linea)


## Texto del indicador de conexión (lo usan la pantalla de acceso y el menú).
func texto_conexion() -> String:
	if not Supabase.configurada:
		return "● Nube sin configurar (falta config.cfg)"
	return "● En línea" if en_linea else "● Sin conexión"


## Pregunta al servidor si responde. Si vuelve la conexión, sube lo pendiente.
func comprobar_conexion() -> bool:
	if _comprobando:
		return en_linea
	_comprobando = true
	var r = await Supabase._request(HTTPClient.METHOD_GET, "jugadores?select=id_jugador&limit=1")
	_comprobando = false
	_marcar_conexion(r.code != 0)      # código 0 = no hubo respuesta (sin internet / servidor caído)
	if en_linea and not pendientes.is_empty():
		subir_pendientes()
	return en_linea


func _guardar_pendiente(datos: Dictionary) -> void:
	pendientes.append(datos)
	guardar()


## Sube una por una las partidas jugadas sin conexión.
## Solo se suben las del alias con sesión en este dispositivo; las demás esperan
## a que su dueño entre con su PIN.
func subir_pendientes() -> void:
	if _subiendo or pendientes.is_empty() or not tiene_sesion():
		return
	_subiendo = true
	var i := 0
	while i < pendientes.size():
		var p: Dictionary = pendientes[i]
		if str(p.get("alias", "")).to_lower() != alias.to_lower():
			i += 1
			continue
		var r = await Supabase.guardar_partida(token, p)
		if r.get("error", "") == "SIN_CONEXION":
			_marcar_conexion(false)
			break
		if r.get("error", "") == "SESION_INVALIDA":
			_sesion_vencida()
			break
		if r.get("error", "") in ["DUPLICADA", "BD_DESACTUALIZADA", "ERROR_SERVIDOR"]:
			break   # se reintenta en la siguiente revisión (cada 20 s)
		# Subida o rechazada por el servidor (datos no válidos / duplicada): sale de la cola
		pendientes.remove_at(i)
		guardar()
		if r.get("ok", false):
			print("Partida pendiente subida a la nube (%d puntos)" % int(p.get("puntos", 0)))
		else:
			push_warning("El servidor rechazó una partida pendiente (%s)" % str(r.get("error", "")))
		if i < pendientes.size():
			await get_tree().create_timer(SEG_ENTRE_SUBIDAS, true).timeout
	_subiendo = false
	conexion_cambiada.emit(en_linea)   # refresca los indicadores (cuántas faltan)


func _sesion_vencida() -> void:
	token = ""
	_alias_registrado = ""
	guardar()


func _filtro_query(filtro: String) -> String:
	match filtro:
		"semana":
			var hace_7 := int(Time.get_unix_time_from_system()) - 7 * 86400
			return "&fecha_partida=gte." + Time.get_datetime_string_from_unix_time(hace_7) + "Z"
		"nivel":
			return "&nivel_alcanzado=eq." + str(nivel_actual)
	return ""

func cargar_ranking_online(filtro: String = "top") -> void:
	var extra := _filtro_query(filtro)

	# Las 10 mejores
	var r = await Supabase._request(HTTPClient.METHOD_GET,
		"partidas?select=puntuacion,jugadores(alias)&order=puntuacion.desc&limit=10" + extra)
	if not r.ok or not (r.data is Array):
		ranking_error.emit()
		return

	var top: Array = []
	for f in r.data:
		var nombre := "???"
		if f.get("jugadores") is Dictionary:
			nombre = str(f["jugadores"].get("alias", "???"))
		top.append({"alias": nombre, "puntos": int(f["puntuacion"])})

	# Mi mejor puntuación y mi posición
	var posicion := 0
	var mejor := 0
	if id_jugador != "":
		var m = await Supabase._request(HTTPClient.METHOD_GET,
			"partidas?select=puntuacion&id_jugador=eq." + id_jugador
			+ "&order=puntuacion.desc&limit=1" + extra)
		if m.ok and m.data is Array and m.data.size() > 0:
			mejor = int(m.data[0]["puntuacion"])
			var c = await Supabase._request(HTTPClient.METHOD_GET,
				"partidas?select=id_partida&puntuacion=gt." + str(mejor) + extra)
			if c.ok and c.data is Array:
				posicion = c.data.size() + 1

	ranking_cargado.emit(top, posicion, mejor)

func enviar_puntaje_online(puntos: int, celdas: int = 0, faroles: int = 0, combo: int = 1, tiempo: int = 0, nivel: int = 1) -> void:
	var pendiente := {"alias": alias, "puntos": puntos, "nivel": nivel, "celdas": celdas,
		"faroles": faroles, "combo": combo, "tiempo": tiempo}
	if not tiene_sesion():
		# Jugó sin haber entrado con su PIN (por ejemplo, sin internet)
		_guardar_pendiente(pendiente)
		puntaje_enviado.emit(false, "Guardado en este equipo. Entra con tu alias y PIN para subirla a la nube.")
		return
	var r = await Supabase.guardar_partida(token, pendiente)
	match str(r.get("error", "")):
		"":
			_marcar_conexion(true)
			puntaje_enviado.emit(true, "Puntuación guardada en el ranking global")
		"SIN_CONEXION":
			push_warning("Sin conexión: la partida queda pendiente de subir")
			_marcar_conexion(false)
			_guardar_pendiente(pendiente)
			puntaje_enviado.emit(false, MSG_SIN_CONEXION)
		"SESION_INVALIDA":
			_sesion_vencida()
			_guardar_pendiente(pendiente)
			puntaje_enviado.emit(false, "Tu sesión venció: vuelve a entrar con tu alias y PIN para subir la partida.")
		"BD_DESACTUALIZADA":
			_guardar_pendiente(pendiente)
			puntaje_enviado.emit(false, MENSAJES_ACCESO["BD_DESACTUALIZADA"])
		"DUPLICADA":
			# Otra partida de este jugador se guardó hace menos de 15 s: se reintenta en un momento
			_marcar_conexion(true)
			_guardar_pendiente(pendiente)
			puntaje_enviado.emit(false, "Partida guardada en este equipo; se subirá a la nube en unos segundos.")
		_:
			push_warning("El servidor rechazó la partida (%s)" % str(r.get("error", "")))
			_marcar_conexion(true)
			puntaje_enviado.emit(false, "El servidor rechazó la partida (datos no válidos o duplicada). Se guardó en este equipo.")
