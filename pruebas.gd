extends Control
## Pruebas automáticas de Luminar (sección 10.5 y 10.6).
## Cómo ejecutarlas: abre tests/pruebas.tscn en Godot y pulsa F6 (Ejecutar escena actual).
## Los resultados salen en la ventana y en el panel Salida (Output).
##   - Unitarias y funcionales: no necesitan internet.
##   - Integración con la nube: marca "probar_nube" en el Inspector (necesita internet;
##     crea un jugador "test_..." y 1 partida de prueba en Supabase).
## Desde la terminal:  godot --path . res://tests/pruebas.tscn -- --salir

@export var probar_nube := false

var _lbl: RichTextLabel
var _ok := 0
var _fallos := 0
var _respaldo := ""     # se respalda el guardado del jugador para no perder su progreso
var _url_original := ""


func _ready() -> void:
	_crear_pantalla()
	if "--nube" in OS.get_cmdline_user_args():
		probar_nube = true
	_correr.call_deferred()


func _crear_pantalla() -> void:
	var fondo := ColorRect.new()
	fondo.color = Color("#0A1128")
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)
	_lbl = RichTextLabel.new()
	_lbl.bbcode_enabled = true
	_lbl.scroll_following = true
	_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	_lbl.offset_left = 24
	_lbl.offset_top = 16
	_lbl.offset_right = -24
	_lbl.offset_bottom = -16
	_lbl.add_theme_font_size_override("normal_font_size", 16)
	_lbl.add_theme_font_size_override("bold_font_size", 18)
	add_child(_lbl)


func _linea(texto: String) -> void:
	_lbl.append_text(texto + "\n")
	print_rich(texto)


func comprobar(id: String, descripcion: String, condicion: bool, detalle: String = "") -> void:
	if condicion:
		_ok += 1
		_linea("[color=#69DB7C]✔ PASA[/color]  %s  %s" % [id, descripcion])
	else:
		_fallos += 1
		_linea("[color=#FF6B6B]✘ FALLA[/color] %s  %s  [color=#FFB37A]%s[/color]" % [id, descripcion, detalle])


func _titulo(t: String) -> void:
	_linea("\n[b][color=#FFD35A]%s[/color][/b]" % t)


func _esperar(seg: float) -> void:
	await get_tree().create_timer(seg, true, false, true).timeout


# ---------------------------------------------------------------
func _correr() -> void:
	_linea("[b]LUMINAR · Pruebas automáticas[/b]   %s" % Time.get_datetime_string_from_system(false, true))
	_respaldar()
	Global.ajustes["enviar_online"] = false
	await _pruebas_unitarias()
	await _pruebas_funcionales()
	if probar_nube:
		await _pruebas_integracion()
	else:
		_titulo("10.6 Integración con Supabase")
		_linea("(omitidas: marca 'probar_nube' en el Inspector para ejecutarlas)")
	_restaurar()
	var color := "#69DB7C" if _fallos == 0 else "#FF6B6B"
	_linea("\n[b][color=%s]RESULTADO: %d pasan, %d fallan[/color][/b]" % [color, _ok, _fallos])
	if "--salir" in OS.get_cmdline_user_args():
		get_tree().quit(_fallos)


func _respaldar() -> void:
	if FileAccess.file_exists(Global.RUTA_GUARDADO):
		_respaldo = FileAccess.get_file_as_string(Global.RUTA_GUARDADO)
	_url_original = Supabase.url


func _restaurar() -> void:
	Supabase.url = _url_original
	if _respaldo != "":
		var f := FileAccess.open(Global.RUTA_GUARDADO, FileAccess.WRITE)
		f.store_string(_respaldo)
		f.close()
	elif FileAccess.file_exists(Global.RUTA_GUARDADO):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Global.RUTA_GUARDADO))
	Global.alias = ""
	Global.id_jugador = ""
	Global.token = ""
	Global._alias_registrado = ""
	Global.records = {}
	Global.tutorial_visto = false
	Global.ranking = []
	Global.pendientes = []
	Global.ajustes = Global.AJUSTES_DEFECTO.duplicate(true)
	Global.cargar()


# ---------------------------------------------------------------
# 10.5 PRUEBAS UNITARIAS (funciones aisladas)
# ---------------------------------------------------------------
func _pruebas_unitarias() -> void:
	_titulo("10.5 Pruebas unitarias")
	Global.alias = "Tester"
	comprobar("PU-01", "Partida válida se acepta", Global.partida_valida(500, 120))
	comprobar("PU-02", "Puntuación negativa se rechaza", not Global.partida_valida(-10, 120))
	comprobar("PU-03", "Puntuación mayor al máximo se rechaza", not Global.partida_valida(Global.PUNTUACION_MAXIMA + 1, 120))
	comprobar("PU-04", "Tiempo fuera de rango (> 6:05) se rechaza", not Global.partida_valida(500, 400))
	Global.alias = "ab"
	comprobar("PU-05", "Alias de menos de 3 caracteres se rechaza", not Global.partida_valida(500, 120))
	var r: Dictionary = await Global.iniciar_sesion("  x ", "1234")
	comprobar("PU-06", "iniciar_sesion valida el alias antes de enviar", not r.ok and r.error == "LOCAL")
	Global.alias = "Tester"
	comprobar("PU-07", "id_a_texto convierte 12.0 en \"12\"", Supabase.id_a_texto(12.0) == "12")
	comprobar("PU-08", "id_valor convierte \"12\" en entero", Supabase.id_valor("12") is int)
	Global.ranking = []
	Global.registrar_puntaje(150, 3, 2, 2, 20, 1)
	comprobar("PU-09", "registrar_puntaje guarda en el ranking local", Global.ranking.size() == 1 and int(Global.ranking[0]["puntos"]) == 150)
	Global.registrar_puntaje(-80, 0, 0, 1, 10, 1)
	comprobar("PU-10", "Puntuación negativa se recorta a 0 (no se guarda negativa)", Global.ultimo_puntaje == 0)
	comprobar("PU-11", "Alias válido con acentos y espacio se acepta", Global.validar_alias("Ñoño Pérez") == "")
	comprobar("PU-12", "Alias con símbolos se rechaza", Global.validar_alias("Ana<b>") != "")
	comprobar("PU-13", "Alias de más de 12 caracteres se rechaza", Global.validar_alias("NombreMuyLargo1") != "")
	comprobar("PU-14", "Espacios de más se normalizan", Global.normalizar_alias("  Ana   Luz ") == "Ana Luz")
	comprobar("PU-15", "PIN con letras se rechaza", Global.validar_pin("12a4") != "")
	comprobar("PU-16", "PIN de 4 números se acepta", Global.validar_pin("0427") == "")
	Global.records = {}
	Global.alias = "Tester"
	Global.registrar_puntaje(200, 3, 2, 2, 30, 1)
	var primero := Global.ultimo_es_record
	Global.registrar_puntaje(150, 3, 2, 2, 30, 1)
	comprobar("PU-17", "Récord personal: se detecta y no lo baja una partida peor",
		primero and not Global.ultimo_es_record and Global.record_de("tester") == 200)
	var cuenta := 0
	for ev in InputMap.action_get_events("encender_farol"):
		if ev is InputEventJoypadButton:
			cuenta += 1
	comprobar("PU-18", "Las acciones también funcionan con control (gamepad)", cuenta >= 1)
	Global.alias = "Tester"
	Global.token = "abc"
	Global._alias_registrado = "Tester"
	Global.cerrar_sesion()
	comprobar("PU-19", "Cambiar jugador borra la sesión del dispositivo", Global.alias == "" and Global.token == "" and not Global.tiene_sesion())
	var en_linea_antes := Global.en_linea
	Global.en_linea = true
	Global.alias = "Tester"
	comprobar("PU-20", "Con internet, sin PIN verificado no se puede jugar", not Global.puede_jugar())
	Global.en_linea = false
	comprobar("PU-21", "Sin internet se puede jugar con alias válido (modo local)", Global.puede_jugar())
	Global.alias = "a<b>"
	comprobar("PU-22", "Sin internet tampoco se acepta un alias inválido", not Global.puede_jugar())
	Global.en_linea = en_linea_antes
	Global.alias = "Tester"
	# Falta config.cfg: el juego lo dice claramente en vez de "Sin conexión"
	var url_antes: String = Supabase.url
	var conf_antes: bool = Supabase.configurada
	Supabase.url = ""
	Supabase.configurada = false
	var sin_conf: Dictionary = await Global.iniciar_sesion("Valido", "1234")
	comprobar("PU-23", "Sin config.cfg se avisa \"nube sin configurar\" (no un falso \"sin conexión\")",
		not sin_conf.ok and "config.cfg" in str(sin_conf.mensaje) and "config.cfg" in Global.texto_conexion())
	Supabase.url = url_antes
	Supabase.configurada = conf_antes
	Global.alias = "Tester"


# ---------------------------------------------------------------
# 10.5 PRUEBAS FUNCIONALES (el juego real en ejecución)
# ---------------------------------------------------------------
func _pruebas_funcionales() -> void:
	_titulo("10.5 Pruebas funcionales")
	var acceso: Node = load("res://Escenas/acceso.tscn").instantiate()
	Global.cerrar_sesion()
	add_child(acceso)
	await _esperar(0.2)
	acceso.campo_alias.text = "x"
	acceso.campo_pin.text = "1234"
	await acceso._on_entrar()
	comprobar("PF-00", "La pantalla de acceso no deja pasar con alias inválido", is_instance_valid(acceso) and acceso.aviso.text != "" and not Global.tiene_sesion())
	acceso.campo_alias.text = "Valido"
	acceso.campo_pin.text = "12"
	await acceso._on_entrar()
	comprobar("PF-00b", "La pantalla de acceso no deja pasar con PIN incompleto", "PIN" in acceso.aviso.text and not Global.tiene_sesion())
	acceso.queue_free()
	Global.alias = "Tester"
	var mundo: Node = load("res://Escenas/mundo.tscn").instantiate()
	add_child(mundo)
	await _esperar(0.6)
	var ch = mundo.chispa

	# Faroles repartidos
	var p1: Array = []
	for f in get_tree().get_nodes_in_group("faroles"):
		p1.append(f.global_position)
	var min_d := INF
	for i in p1.size():
		for j in range(i + 1, p1.size()):
			min_d = minf(min_d, p1[i].distance_to(p1[j]))
	comprobar("PF-01", "Hay 5 faroles separados al menos 120 px", p1.size() == 5 and min_d >= 120.0, "min=%.0f" % min_d)

	# Correr
	Input.action_press("mover_der")
	await _esperar(0.4)
	var v_normal: float = ch.velocity.length()
	var e0: float = ch.energia
	Input.action_press("correr")
	await _esperar(0.8)
	var v_correr: float = ch.velocity.length()
	var e1: float = ch.energia
	Input.action_release("correr")
	Input.action_release("mover_der")
	await _esperar(0.1)
	comprobar("PF-02", "Correr aumenta la velocidad (x1.6)", v_correr > v_normal * 1.4, "%.0f -> %.0f" % [v_normal, v_correr])
	comprobar("PF-03", "Correr gasta energía extra", e0 - e1 > 4.0, "%.1f -> %.1f" % [e0, e1])

	# Vida extra
	ch.invulnerable = false
	ch.recibir_dano(1)
	comprobar("PF-04", "Chispa pierde una vida al ser tocada", ch.vidas == ch.vidas_maximas - 1)
	mundo._t_vida_extra = 0.05
	await _esperar(0.3)
	var corazones := get_tree().get_nodes_in_group("vidas_extra")
	comprobar("PF-05", "Aparece un corazón cuando falta una vida", corazones.size() == 1)
	if corazones.size() == 1:
		ch.global_position = corazones[0].global_position
		await _esperar(0.4)
	comprobar("PF-06", "Recoger el corazón recupera la vida", ch.vidas == ch.vidas_maximas)

	# Cambio de ronda
	for f in get_tree().get_nodes_in_group("faroles"):
		f.encender()
		ch.farol_encendido.emit(f)
	await _esperar(4.5)
	comprobar("PF-07", "Encender 5 faroles completa la ronda", mundo.ronda == 2, "ronda=%d" % mundo.ronda)
	var movidos := 0
	for f in get_tree().get_nodes_in_group("faroles"):
		var cerca := false
		for q in p1:
			if f.global_position.distance_to(q) < 60.0:
				cerca = true
		if not cerca:
			movidos += 1
	comprobar("PF-08", "En la ronda nueva los faroles cambian de lugar", movidos >= 4, "%d/5 movidos" % movidos)
	comprobar("PF-09", "La puntuación incluye el bono de ronda", mundo.puntos >= 100, "puntos=%d" % mundo.puntos)

	# Historia: cómic de inicio
	var comic: Control = load(Global.ESCENA_COMIC).instantiate()
	comic.historia = "inicio"
	var fin_comic := [false]
	comic.terminado.connect(func(): fin_comic[0] = true)
	add_child(comic)
	await _esperar(0.2)
	var paginas: int = comic._paginas.size()
	for i in 6:
		if fin_comic[0] or not is_instance_valid(comic):
			break
		comic._siguiente()
		await _esperar(0.05)
	comprobar("PF-13", "El cómic de inicio tiene 2 páginas y se puede avanzar hasta el final", paginas == 2 and fin_comic[0])

	# Sin conexión: el juego sigue y guarda local
	Supabase.url = "https://sin-conexion.invalid"
	Global.ajustes["enviar_online"] = true
	Global.token = "token-de-prueba"          # simula que ya entró con su PIN
	Global._alias_registrado = Global.alias
	Global.pendientes = []
	var msgs: Array = []
	var cb := func(ok, m): msgs.append([ok, m])
	Global.puntaje_enviado.connect(cb)
	for i in 3:
		ch.invulnerable = false
		ch.recibir_dano(1)
	await _esperar(1.5)
	Global.puntaje_enviado.disconnect(cb)
	comprobar("PF-10", "Sin conexión la partida termina sin cerrarse el juego", mundo.terminada and is_instance_valid(mundo))
	comprobar("PF-11", "Sin conexión se muestra un mensaje claro", msgs.size() > 0 and not msgs[0][0] and "Sin conexión" in str(msgs[0][1]))
	comprobar("PF-12", "Sin conexión la partida queda pendiente en el equipo", Global.pendientes.size() == 1)
	get_tree().paused = false
	mundo.queue_free()
	await _esperar(0.2)

	# Historia: al ganar aparece el cómic final ANTES de los resultados
	Supabase.url = "https://sin-conexion.invalid"
	mundo = load("res://Escenas/mundo.tscn").instantiate()
	add_child(mundo)
	await _esperar(0.5)
	mundo._finalizar(true, "victoria")
	await _esperar(0.3)
	var comic_final: Node = mundo.find_child("Comic", true, false)
	var res: Control = mundo.find_child("Resultados", true, false)
	comprobar("PF-14", "Al ganar se muestra el cómic final antes de los resultados",
		comic_final != null and comic_final.historia == "final" and (res == null or not res.visible))
	if comic_final:
		comic_final._terminar()
	await _esperar(0.3)
	comprobar("PF-15", "Al cerrar el cómic final aparecen los resultados", res != null and res.visible)
	Supabase.url = _url_original
	Global.pendientes = []
	Global.ajustes["enviar_online"] = false
	get_tree().paused = false
	mundo.queue_free()
	await _esperar(0.2)


# ---------------------------------------------------------------
# 10.6 PRUEBAS DE INTEGRACIÓN (Supabase real)
# ---------------------------------------------------------------
func _pruebas_integracion() -> void:
	_titulo("10.6 Integración con Supabase (%s)" % Supabase.url)
	var alias_prueba := "test%d" % (int(Time.get_unix_time_from_system()) % 100000000)
	var pin := "%04d" % (randi() % 10000)
	var reg: Dictionary = await Supabase.acceder_jugador(alias_prueba, pin)
	comprobar("PI-01", "Registrar jugador nuevo con PIN (rpc acceder_jugador)", reg.get("ok", false) and reg.get("nuevo", false), str(reg.get("error", "")))
	if not reg.get("ok", false):
		_linea("[color=#FFB37A]No se pudo usar Supabase (%s): se omiten las demás pruebas de integración.[/color]" % str(reg.get("error", "")))
		return
	var id: String = str(reg.id_jugador)
	var tok: String = str(reg.token)
	var reg2: Dictionary = await Supabase.acceder_jugador(alias_prueba.to_upper(), pin)
	comprobar("PI-02", "Mismo alias (en mayúsculas) + PIN correcto = mismo jugador", reg2.get("ok", false) and str(reg2.get("id_jugador", "")) == id)
	var otro_pin := "%04d" % ((int(pin) + 1) % 10000)
	var intruso: Dictionary = await Supabase.acceder_jugador(alias_prueba, otro_pin)
	comprobar("PI-03", "Otro dispositivo con PIN incorrecto NO puede usar el alias", not intruso.get("ok", true) and intruso.get("error", "") == "ALIAS_EN_USO", str(intruso.get("error", "")))
	var invalido: Dictionary = await Supabase.acceder_jugador("a<b>", "1234")
	comprobar("PI-04", "El servidor rechaza alias inválidos", invalido.get("error", "") == "ALIAS_INVALIDO", str(invalido.get("error", "")))

	var partida := {"puntos": 321, "nivel": 1, "celdas": 4, "faroles": 3, "combo": 2, "tiempo": 45}
	var r: Dictionary = await Supabase.guardar_partida(tok, partida)
	comprobar("PI-05", "Guardar partida válida con sesión (rpc guardar_partida)", r.get("ok", false), str(r.get("error", "")))
	var g = await Supabase._request(HTTPClient.METHOD_GET,
		"partidas?select=id_partida,puntuacion,fecha_partida&id_jugador=eq." + id)
	var encontrada: bool = g.ok and g.data is Array and g.data.size() == 1 and int(g.data[0].get("puntuacion", -1)) == 321
	comprobar("PI-06", "Consultar la partida guardada (GET -> 200, mismos datos)", encontrada, "HTTP %d" % g.code)
	var t = await Supabase.obtener_top10()
	var ordenado: bool = t.ok and t.data is Array and t.data.size() <= 10
	if ordenado:
		for i in range(1, t.data.size()):
			if int(t.data[i].get("puntuacion", 0)) > int(t.data[i - 1].get("puntuacion", 0)):
				ordenado = false
	comprobar("PI-07", "Top 10: máximo 10 filas ordenadas de mayor a menor", ordenado)

	var dup: Dictionary = await Supabase.guardar_partida(tok, partida)
	comprobar("PI-08", "El servidor rechaza partida duplicada (< 15 s)", dup.get("error", "") == "DUPLICADA", str(dup.get("error", "")))
	var falsa: Dictionary = await Supabase.guardar_partida("token-falso", partida)
	comprobar("PI-09", "Sin sesión válida no se puede guardar", falsa.get("error", "") == "SESION_INVALIDA", str(falsa.get("error", "")))
	var directo = await Supabase._request(HTTPClient.METHOD_POST, "partidas",
		{"id_jugador": Supabase.id_valor(id), "puntuacion": 50, "nivel_alcanzado": 1})
	comprobar("PI-10", "No se puede insertar directo en la tabla (solo con la función)", directo.code >= 400 and directo.code < 500, "HTTP %d" % directo.code)
	var pin_hash = await Supabase._request(HTTPClient.METHOD_GET, "jugadores?select=pin_hash&limit=1")
	comprobar("PI-11", "Nadie puede leer los PIN por la API", pin_hash.code >= 400 and pin_hash.code < 500, "HTTP %d" % pin_hash.code)
	await _esperar(16.0)   # pasa la ventana anti-duplicados
	var neg: Dictionary = await Supabase.guardar_partida(tok, {"puntos": -50, "nivel": 1})
	comprobar("PI-12", "El servidor rechaza puntuación negativa", neg.get("error", "") == "DATOS_INVALIDOS", str(neg.get("error", "")))
	var imposible: Dictionary = await Supabase.guardar_partida(tok, {"puntos": 99999, "nivel": 1, "tiempo": 10})
	comprobar("PI-13", "El servidor rechaza puntuación imposible", imposible.get("error", "") == "DATOS_INVALIDOS", str(imposible.get("error", "")))
	var upd = await Supabase._request(HTTPClient.METHOD_PATCH, "partidas?id_jugador=eq." + id, {"puntuacion": 99999})
	var g2 = await Supabase._request(HTTPClient.METHOD_GET, "partidas?select=puntuacion&id_jugador=eq." + id)
	var intacta: bool = g2.ok and g2.data is Array and g2.data.size() == 1 and int(g2.data[0].get("puntuacion", -1)) == 321
	comprobar("PI-14", "El juego no puede modificar puntuaciones", intacta, "HTTP %d" % upd.code)
	_linea("(Jugador de prueba creado: %s. Puedes borrarlo en Supabase si quieres.)" % alias_prueba)
