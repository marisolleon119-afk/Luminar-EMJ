extends Control
## Ranking global conectado a la nube (GDD 5.5). Los nodos están en Escenas/ranking.tscn.
## Las filas se crean duplicando "FilaPlantilla" (la fila de ejemplo que se ve en el editor).
## Si no hay conexión, se muestra el ranking guardado en este equipo sin bloquear el juego.

const Estilo = preload("res://scripts/estilo.gd")
const COLORES_PODIO := [Color("#FFD35A"), Color("#D9DEE8"), Color("#E0A060")]

@onready var lista: VBoxContainer = %Lista
@onready var plantilla: PanelContainer = %FilaPlantilla
@onready var estado: Label = %Estado
@onready var mi_posicion: Label = %MiPosicion

var _token := 0   # evita mezclar respuestas si el jugador cambia de pestaña rápido


func _ready() -> void:
	Audio.musica("menu")
	plantilla.visible = false
	%BtnVolver.pressed.connect(func(): Global.ir_a(Global.ESCENA_PORTADA))
	%BtnJugar.pressed.connect(_jugar)
	%BtnTop.pressed.connect(_cargar.bind("top"))
	%BtnSemana.pressed.connect(_cargar.bind("semana"))
	%BtnNivel.pressed.connect(_cargar.bind("nivel"))
	%BtnVolver.grab_focus()
	_cargar("top")


func _jugar() -> void:
	Global.ir_a(Global.ESCENA_MUNDO if Global.alias != "" else Global.ESCENA_PORTADA)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		Global.ir_a(Global.ESCENA_PORTADA)


# ---------------- Datos (Supabase) ----------------
func _filtro_query(filtro: String) -> String:
	match filtro:
		"semana":
			var hace_7_dias := Time.get_unix_time_from_system() - 7 * 86400
			return "&fecha_partida=gte." + Time.get_datetime_string_from_unix_time(int(hace_7_dias)) + "Z"
		"nivel":
			return "&nivel_alcanzado=eq." + str(Global.nivel_actual)
	return ""


func _cargar(filtro: String) -> void:
	_token += 1
	var mi_token := _token
	_limpiar()
	estado.text = "Cargando..."
	estado.add_theme_color_override("font_color", Estilo.TEXTO)
	mi_posicion.text = ""
	var extra := _filtro_query(filtro)

	# 1) Las 10 mejores, de mayor a menor
	var r = await Supabase._request(HTTPClient.METHOD_GET,
		"partidas?select=puntuacion,jugadores(alias)&order=puntuacion.desc&limit=10" + extra)
	if mi_token != _token:
		return
	if not r.ok or not (r.data is Array):
		_mostrar_local()
		return

	var datos: Array = []
	for f in r.data:
		var alias_fila := "???"
		if f.get("jugadores") is Dictionary:
			alias_fila = str(f["jugadores"].get("alias", "???"))
		datos.append({"alias": alias_fila, "puntos": int(f["puntuacion"])})

	# 2) Mi mejor puntuación y mi posición
	var posicion := 0
	var mejor := 0
	if str(Global.id_jugador) != "":
		var m = await Supabase._request(HTTPClient.METHOD_GET,
			"partidas?select=puntuacion&id_jugador=eq." + str(Global.id_jugador)
			+ "&order=puntuacion.desc&limit=1" + extra)
		if mi_token != _token:
			return
		if m.ok and m.data is Array and m.data.size() > 0:
			mejor = int(m.data[0]["puntuacion"])
			var c = await Supabase._request(HTTPClient.METHOD_GET,
				"partidas?select=id_partida&puntuacion=gt." + str(mejor) + extra)
			if mi_token != _token:
				return
			if c.ok and c.data is Array:
				posicion = c.data.size() + 1

	_limpiar()
	estado.text = "Aún no hay partidas" if datos.is_empty() else ""
	for i in datos.size():
		_agregar_fila(i + 1, str(datos[i]["alias"]), int(datos[i]["puntos"]))
	if posicion > 0:
		mi_posicion.text = "Tu posición: #%d   ·   Tu mejor puntuación: %s" % [posicion, Estilo.miles(mejor)]
	elif Global.alias != "":
		mi_posicion.text = "Aún no tienes partidas registradas"


## Sin conexión: ranking local para no bloquear al jugador (GDD 5.5).
func _mostrar_local() -> void:
	_limpiar()
	var local: Array = Global.ranking.duplicate()
	local.sort_custom(func(a, b): return int(a["puntos"]) > int(b["puntos"]))
	local = local.slice(0, 10)
	for i in local.size():
		_agregar_fila(i + 1, str(local[i].get("alias", "???")), int(local[i].get("puntos", 0)))
	if local.is_empty():
		estado.text = "No se pudo conectar con el servidor y aún no hay puntuaciones en este equipo."
	else:
		estado.text = "Sin conexión con el servidor. Mostrando las puntuaciones guardadas en este equipo."
		if not Global.pendientes.is_empty():
			estado.text += "\n%d partida(s) se subirán a la nube cuando vuelva el internet." % Global.pendientes.size()
	estado.add_theme_color_override("font_color", Color("#FFB37A"))


func _limpiar() -> void:
	for hijo in lista.get_children():
		if hijo != plantilla:
			hijo.queue_free()


## Copia la fila de ejemplo y la pinta: oro, plata y bronce para el podio; tu alias resaltado.
func _agregar_fila(puesto: int, nombre: String, puntos: int) -> void:
	var fila := plantilla.duplicate() as PanelContainer
	fila.unique_name_in_owner = false
	fila.visible = true
	lista.add_child(fila)    # dentro del árbol ya toma los estilos del tema
	var es_mio := Global.alias != "" and nombre == Global.alias
	var podio := puesto <= 3
	var color: Color = COLORES_PODIO[puesto - 1] if podio else Estilo.TEXTO

	var caja := (fila.get_theme_stylebox("panel") as StyleBoxFlat)
	if caja:
		caja = caja.duplicate()
		caja.bg_color = Color("#16285A") if podio else Color("#0F1B3D")
		caja.border_color = Estilo.ORO if es_mio else (Color(color, 0.6) if podio else Color(Estilo.BORDE, 0.5))
		caja.set_border_width_all(2 if (es_mio or podio) else 1)
		fila.add_theme_stylebox_override("panel", caja)

	var tam := 20 if podio else 17
	var l_puesto := fila.get_node("Fila/Puesto") as Label
	var l_alias := fila.get_node("Fila/Alias") as Label
	var l_puntos := fila.get_node("Fila/Puntos") as Label
	l_puesto.text = str(puesto)
	l_alias.text = nombre + ("  (tú)" if es_mio else "")
	l_puntos.text = Estilo.miles(puntos)
	l_puesto.add_theme_color_override("font_color", color)
	l_alias.add_theme_color_override("font_color", Estilo.ORO if es_mio else Estilo.TEXTO)
	l_puntos.add_theme_color_override("font_color", color)
	for l in [l_puesto, l_alias, l_puntos]:
		l.add_theme_font_size_override("font_size", tam)
