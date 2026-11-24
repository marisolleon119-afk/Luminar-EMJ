extends Node2D
## Director de la partida de Luminar (GDD secciones 2, 4, 5 y 6).
## Rondas, puntuación, combo, dificultad, oscuridad dinámica y aparición de Sombras y Celdas.
## El HUD y la pantalla de resultados son escenas (Escenas/hud.tscn y resultados.tscn).
##
## DIFICULTAD: todos los valores por ronda están en el Inspector de este nodo (grupo "Dificultad").
## Cada arreglo tiene 3 valores: [Ronda 1, Ronda 2, Ronda 3].

const Estilo = preload("res://scripts/estilo.gd")
const ESCENA_SOMBRA := preload("res://Escenas/sombra.tscn")
const ESCENA_CELDA := preload("res://Escenas/celda.tscn")
const SCRIPT_VIDA_EXTRA := preload("res://scripts/vida_extra.gd")

# ---------------------------------------------------------------
# REGLAS FIJAS (GDD 2.3, 2.4 y 2.6)
# ---------------------------------------------------------------
const RONDAS_TOTALES := 3
const FAROLES_POR_RONDA := 5
const TIEMPO_MAXIMO := 360.0             # Tope de partida: 6:00
const CELDAS_INICIALES := 3
const PUNTOS_CELDA := 10                 # 10 × combo
const BONO_RIESGO := 5                   # +5 por celda fuera de la luz (no se multiplica)
const PUNTOS_FAROL := 50
const BONO_RONDA := 100                  # 100 × número de ronda
const BONO_VICTORIA := 500
const COMBO_MAX := 5
const PUNTUACION_MAXIMA := 99999
const NOMBRES_RONDA := ["Recuperar la luz", "Las Sombras se acercan", "La última luz"]
const RITMO_MUSICA_POR_RONDA := [1.0, 1.04, 1.08]   # GDD 6.1: la música se acelera con la dificultad

# ---------------------------------------------------------------
# DIFICULTAD (editable en el Inspector)
# ---------------------------------------------------------------
@export_group("Dificultad: Sombras")
@export var sombras_por_ronda: PackedInt32Array = PackedInt32Array([3, 5, 7])
@export var velocidad_merodeo: PackedFloat32Array = PackedFloat32Array([70.0, 85.0, 100.0])
@export var velocidad_persecucion: PackedFloat32Array = PackedFloat32Array([95.0, 110.0, 125.0])
@export var radio_deteccion: PackedFloat32Array = PackedFloat32Array([200.0, 240.0, 280.0])
## Segundos seguidos dentro de la luz para que una Sombra se disipe
@export var tiempo_disipacion_luz: PackedFloat32Array = PackedFloat32Array([2.0, 2.5, 3.0])
## Velocidad de la Sombra dentro de la luz (0.5 = la mitad)
@export var frenado_en_luz: PackedFloat32Array = PackedFloat32Array([0.5, 0.6, 0.7])
@export var tiempo_reaparicion: PackedFloat32Array = PackedFloat32Array([8.0, 6.5, 5.0])
## Distancia a la que una Sombra que ve a Chispa avisa a las demás (0 = no avisa)
@export var radio_alerta: PackedFloat32Array = PackedFloat32Array([0.0, 260.0, 360.0])
## Segundos que la Sombra adelanta el movimiento de Chispa al perseguir (0 = va directo)
@export var anticipacion: PackedFloat32Array = PackedFloat32Array([0.0, 0.2, 0.45])

@export_group("Dificultad: presión dentro de la ronda")
## Cada cuántos segundos de la misma ronda las Sombras se aceleran
@export var furia_cada: float = 30.0
@export var furia_aumento: float = 0.06
@export var furia_maxima: float = 0.24
## Cada cuántos segundos de la misma ronda llega una Sombra extra (0 = nunca)
@export var refuerzo_cada: float = 60.0
@export var refuerzos_maximos: int = 2

@export_group("Dificultad: recursos")
## Multiplicador del gasto de energía de Chispa
@export var gasto_energia: PackedFloat32Array = PackedFloat32Array([1.0, 1.25, 1.5])
## Segundos para encadenar el combo
@export var ventana_combo: PackedFloat32Array = PackedFloat32Array([4.0, 3.5, 3.0])
@export var max_celdas: PackedInt32Array = PackedInt32Array([6, 5, 4])
@export var intervalo_celdas: PackedFloat32Array = PackedFloat32Array([3.0, 3.5, 4.0])

@export_group("Oscuridad")
## Color del ambiente por ronda: oscuridad baja, media y alta (GDD 4.4)
@export var ambiente_por_ronda: PackedColorArray = PackedColorArray([Color(0.42, 0.47, 0.72), Color(0.30, 0.34, 0.56), Color(0.19, 0.21, 0.39)])
@export var dist_vision_plena: float = 128.0     # dentro de la zona segura se ve normal
@export var dist_vision_minima: float = 520.0    # a partir de aquí la visión es la mínima
@export_range(0.3, 1.0) var vision_minima: float = 0.7
@export_range(0.0, 0.8) var oscurecer_lejos: float = 0.3

@export_group("Faroles: posición por ronda")
## En cada ronda los faroles cambian de lugar dentro de este rectángulo
@export var limites_faroles: Rect2 = Rect2(110, 135, 1060, 465)
## Distancia mínima entre faroles (si no caben, se va relajando)
@export var separacion_faroles: float = 250.0
## Distancia mínima entre un farol y Chispa al empezar la ronda
@export var distancia_farol_chispa: float = 150.0
## Espacio libre alrededor del DIBUJO de cada obstáculo (no solo de su colisión) para colocar faroles.
## Así siempre queda un pasillo para pasar entre el farol y el objeto.
@export var margen_faroles_obstaculos: float = 34.0
## Espacio libre alrededor de los obstáculos para celdas y corazones
@export var margen_objetos_obstaculos: float = 18.0

@export_group("Vidas extra")
## Segundos (mínimo, máximo) que tarda en aparecer un corazón mientras a Chispa le falta una vida
@export var intervalo_vida_extra: Vector2 = Vector2(15.0, 25.0)
## Segundos que el corazón se queda en el mapa antes de apagarse
@export var duracion_vida_extra: float = 12.0
## El corazón aparece al menos a esta distancia de Chispa (hay que ir por él)
@export var distancia_vida_extra: float = 260.0

const LIMITES_CELDAS := Rect2(64, 84, 1152, 560)
## Respaldo si no se encuentran posiciones libres para los faroles (las originales)
const POS_FAROLES_RESPALDO: Array[Vector2] = [
	Vector2(170, 150), Vector2(1110, 150), Vector2(170, 570), Vector2(1110, 570), Vector2(640, 115),
]
const POS_CELDAS: Array[Vector2] = [
	Vector2(260, 350), Vector2(500, 500), Vector2(700, 210), Vector2(780, 520),
	Vector2(1000, 330), Vector2(520, 230), Vector2(950, 560), Vector2(360, 430),
	Vector2(1050, 130), Vector2(240, 215), Vector2(800, 130), Vector2(460, 600),
	Vector2(1160, 500), Vector2(640, 480), Vector2(150, 440), Vector2(1130, 300),
]

@onready var objetos: Node2D = $Objetos
@onready var chispa = $Objetos/Chispa
@onready var ambiente: CanvasModulate = $Ambiente
@onready var hud = $HUD
@onready var camara: Camera2D = $Camara
@onready var _pausa: Node = get_node_or_null("Pausa")

# ---------------------------------------------------------------
# ESTADO
# ---------------------------------------------------------------
var puntos := 0
var combo := 1
var combo_maximo := 1
var celdas_recogidas := 0
var celdas_riesgo := 0
var faroles_totales := 0
var faroles_ronda := 0
var rondas_completadas := 0
var ronda := 1
var tiempo_total := 0.0
var terminada := false
var desglose := {"celdas": 0, "riesgo": 0, "faroles": 0, "rondas": 0, "tiempo": 0, "victoria": 0}

var _segundos_contados := 0
var _t_combo := 0.0
var _t_celda := 3.0
var _t_ronda := 0.0
var _nivel_furia := 0
var _refuerzos := 0
var _celdas_activas := 0
var _sombras: Array = []
var _vision := 1.0
var _lejania := 1.0
var _en_transicion := false
var _textos_flotantes: Node2D
var _t_vida_extra := 0.0
var _zonas_obstaculos: Array[Rect2] = []   # rectángulo del dibujo de cada obstáculo (se calcula una vez)


func _ready() -> void:
	randomize()
	var cam_chispa := chispa.get_node_or_null("Camera2D") as Camera2D
	if cam_chispa:
		cam_chispa.enabled = false     # GDD 4.1: mapa de una sola pantalla, cámara fija
	camara.make_current()

	_textos_flotantes = Node2D.new()
	_textos_flotantes.z_index = 50
	add_child(_textos_flotantes)

	chispa.vidas_cambiadas.connect(func(v, m): hud.actualizar_vidas(v, m))
	chispa.energia_cambiada.connect(_on_energia)
	chispa.energia_baja.connect(_on_energia_baja)
	chispa.energia_insuficiente.connect(_on_energia_insuficiente)
	chispa.vida_perdida.connect(_on_vida_perdida)
	chispa.celda_recogida.connect(_on_celda)
	chispa.farol_encendido.connect(_on_farol)
	chispa.jugador_murio.connect(_on_jugador_murio)
	chispa.vida_recuperada.connect(_on_vida_recuperada)
	chispa.corriendo_cambiado.connect(func(c): hud.actualizar_corriendo(c))
	_t_vida_extra = randf_range(intervalo_vida_extra.x, intervalo_vida_extra.y)

	hud.actualizar_vidas(chispa.vidas, chispa.vidas_maximas)
	_on_energia(chispa.energia, chispa.energia_maxima)
	hud.actualizar_puntos(0)
	hud.actualizar_tiempo(0.0, TIEMPO_MAXIMO)

	for f in get_tree().get_nodes_in_group("faroles"):
		f.reiniciar()
	_iniciar_ronda(1)
	_avisar_si_sin_conexion()
	_tutorial()
	Audio.musica("juego")
	Audio.ritmo_musica(RITMO_MUSICA_POR_RONDA[0])

	await get_tree().physics_frame    # los obstáculos ya están registrados en la física
	_recolocar_faroles(true)
	for i in CELDAS_INICIALES:
		_generar_celda()


## Valor del arreglo para la ronda actual (si el arreglo es más corto, usa el último).
func _v(arr, r: int = -1):
	if r < 0:
		r = ronda
	if arr.size() == 0:
		return 0
	return arr[clampi(r - 1, 0, arr.size() - 1)]


func _process(delta: float) -> void:
	if terminada or _en_transicion:
		return

	tiempo_total += delta
	_t_ronda += delta
	while int(tiempo_total) > _segundos_contados:
		_segundos_contados += 1
		_sumar_puntos(1, "tiempo", false)

	if _t_combo > 0.0:
		_t_combo = maxf(_t_combo - delta, 0.0)
		if _t_combo == 0.0:
			combo = 1
		_actualizar_combo()

	_t_celda -= delta
	if _t_celda <= 0.0:
		_t_celda = float(_v(intervalo_celdas))
		if _celdas_activas < int(_v(max_celdas)):
			_generar_celda()

	_actualizar_vida_extra(delta)
	_actualizar_presion()
	_actualizar_vision(delta)
	hud.actualizar_tiempo(tiempo_total, TIEMPO_MAXIMO)

	if tiempo_total >= TIEMPO_MAXIMO:
		_finalizar(false, "tiempo")


# ---------------------------------------------------------------
# DIFICULTAD
# ---------------------------------------------------------------
func _parametros_sombra() -> Dictionary:
	return {
		"ronda": ronda,
		"merodeo": _v(velocidad_merodeo),
		"persecucion": _v(velocidad_persecucion),
		"deteccion": _v(radio_deteccion),
		"disipacion": _v(tiempo_disipacion_luz),
		"frenado_luz": _v(frenado_en_luz),
		"reaparicion": _v(tiempo_reaparicion),
		"alerta": _v(radio_alerta),
		"anticipacion": _v(anticipacion),
	}


## Mientras más dura una ronda, más presión: las Sombras se aceleran y llegan refuerzos.
func _actualizar_presion() -> void:
	if furia_cada > 0.0:
		var nivel := int(_t_ronda / furia_cada)
		var mult := 1.0 + minf(nivel * furia_aumento, furia_maxima)
		if nivel != _nivel_furia:
			_nivel_furia = nivel
			if nivel > 0 and nivel * furia_aumento <= furia_maxima + 0.001:
				hud.aviso("Las Sombras se agitan...", Estilo.MAGENTA, 1.4)
			for s in _sombras:
				if is_instance_valid(s):
					s.multiplicador_furia = mult
	if refuerzo_cada > 0.0 and _refuerzos < refuerzos_maximos and _t_ronda >= refuerzo_cada * (_refuerzos + 1):
		_refuerzos += 1
		_crear_sombra()
		hud.aviso("¡Llega otra Sombra!", Estilo.MAGENTA, 1.6)


func _crear_sombra() -> void:
	var s = ESCENA_SOMBRA.instantiate()
	if s == null:
		push_error("mundo: no se pudo instanciar sombra.tscn")
		return
	s.set("ronda", ronda)
	s.position = _punto_aparicion_oscuro()
	if s.has_signal("disipada"):
		s.disipada.connect(_on_sombra_disipada)
	objetos.add_child(s)                 # _ready de la Sombra corre aquí
	s.configurar(_parametros_sombra())
	s.multiplicador_furia = 1.0 + minf(_nivel_furia * furia_aumento, furia_maxima)
	_sombras.append(s)


func _ajustar_sombras() -> void:
	_sombras = _sombras.filter(func(s): return is_instance_valid(s))
	var objetivo := int(_v(sombras_por_ronda))
	# Las Sombras de refuerzo de la ronda anterior se van
	while _sombras.size() > objetivo:
		_sombras.pop_back().queue_free()
	var p := _parametros_sombra()
	for s in _sombras:
		s.configurar_ronda(ronda)
		s.configurar(p)
		s.multiplicador_furia = 1.0
	while _sombras.size() < objetivo:
		_crear_sombra()


# ---------------------------------------------------------------
# RONDAS (GDD 4.3 y 4.4)
# ---------------------------------------------------------------
func _iniciar_ronda(n: int, mostrar_banner: bool = true) -> void:
	ronda = n
	faroles_ronda = 0
	_t_ronda = 0.0
	_nivel_furia = 0
	_refuerzos = 0
	_t_celda = float(_v(intervalo_celdas))
	chispa.configurar_ronda(n)
	chispa.multiplicador_gasto = float(_v(gasto_energia))
	_ajustar_sombras()
	hud.actualizar_ronda(n, RONDAS_TOTALES)
	hud.actualizar_faroles(0, FAROLES_POR_RONDA)
	_actualizar_combo()
	if mostrar_banner:
		hud.banner("Ronda %d" % n, NOMBRES_RONDA[n - 1], 2.4)
	Audio.ritmo_musica(RITMO_MUSICA_POR_RONDA[clampi(n - 1, 0, 2)])


func _completar_ronda() -> void:
	rondas_completadas += 1
	Audio.sfx_ui("ronda")
	var bono := BONO_RONDA * ronda
	_sumar_puntos(bono, "rondas")
	if ronda >= RONDAS_TOTALES:
		_sumar_puntos(BONO_VICTORIA, "victoria")
		_finalizar(true, "victoria")
	else:
		_transicion_a_ronda(ronda + 1, bono)


func _transicion_a_ronda(siguiente: int, bono: int) -> void:
	_en_transicion = true
	get_tree().paused = true
	_activar_pausa(false)
	hud.banner("¡Ronda %d completada!" % ronda, "+%s puntos" % Estilo.miles(bono), 1.6)
	await get_tree().create_timer(1.8).timeout
	if terminada:
		return
	_reiniciar_mapa()
	_iniciar_ronda(siguiente, false)
	hud.banner("Ronda %d: %s" % [siguiente, NOMBRES_RONDA[siguiente - 1]],
		"%d Sombras · más rápidas, ven más lejos y se avisan entre ellas" % int(_v(sombras_por_ronda)), 2.4)
	await get_tree().create_timer(2.6).timeout
	if terminada:
		return
	_en_transicion = false
	get_tree().paused = false
	_activar_pausa(true)


func _reiniciar_mapa() -> void:
	for f in get_tree().get_nodes_in_group("faroles"):
		f.reiniciar()
	for c in get_tree().get_nodes_in_group("celdas"):
		c.queue_free()
	for v in get_tree().get_nodes_in_group("vidas_extra"):
		v.queue_free()
	_celdas_activas = 0
	_recolocar_faroles(true)
	for s in _sombras:
		if is_instance_valid(s):
			s.reiniciar_en(_punto_aparicion_oscuro())
	await get_tree().process_frame
	for i in CELDAS_INICIALES:
		_generar_celda()


# ---------------------------------------------------------------
# FAROLES EN POSICIONES NUEVAS CADA RONDA
# ---------------------------------------------------------------
func _recolocar_faroles(animar: bool = false) -> void:
	var faroles: Array = get_tree().get_nodes_in_group("faroles")
	if faroles.is_empty():
		return
	var previas: Array[Vector2] = []
	var excluir: Array[RID] = []
	for f in faroles:
		previas.append(f.global_position)
		excluir.append(f.get_rid())

	var elegidas: Array[Vector2] = []
	# Primero se busca SIN repetir lugares de la ronda anterior; si no caben, se va relajando
	# la separación. Solo como último recurso se permite repetir algún lugar.
	var listo := false
	for evitar in [true, false]:
		for factor in [1.0, 0.9, 0.8, 0.7, 0.6, 0.5]:
			for _intento in 4:
				elegidas = _buscar_posiciones_faroles(faroles.size(), separacion_faroles * factor, previas, excluir, evitar)
				if elegidas.size() >= faroles.size():
					listo = true
					break
			if listo:
				break
		if listo:
			break
	# Respaldo: completar con las posiciones originales que queden libres
	for p in POS_FAROLES_RESPALDO:
		if elegidas.size() >= faroles.size():
			break
		var libre := true
		for e in elegidas:
			if e.distance_to(p) < 120.0:
				libre = false
				break
		if libre:
			elegidas.append(p)
	while elegidas.size() < faroles.size():
		elegidas.append(POS_FAROLES_RESPALDO[elegidas.size() % POS_FAROLES_RESPALDO.size()])

	elegidas.shuffle()
	for i in faroles.size():
		faroles[i].mover_a(elegidas[i], animar)


func _buscar_posiciones_faroles(cantidad: int, separacion: float, previas: Array[Vector2],
		excluir: Array[RID], evitar_previas: bool) -> Array[Vector2]:
	# Se revisa una cuadrícula de todo el mapa y se elige entre los lugares libres.
	# Así nunca se "acaban" los intentos aunque los márgenes con los obstáculos sean grandes.
	var candidatos := _lugares_libres_faroles(excluir)
	candidatos.shuffle()
	var res: Array[Vector2] = []
	for p in candidatos:
		if res.size() >= cantidad:
			break
		var ok := true
		for o in res:
			if p.distance_to(o) < separacion:
				ok = false
				break
		if ok and evitar_previas:
			# Que se note el cambio: no repetir el lugar de la ronda anterior
			for v in previas:
				if p.distance_to(v) < 90.0:
					ok = false
					break
		if ok:
			res.append(p)
	return res


## Puntos de una cuadrícula (cada 30 px) donde cabe un farol: sin colisiones, lejos del dibujo
## de los obstáculos, de Chispa y de los puntos de aparición de las Sombras.
func _lugares_libres_faroles(excluir: Array[RID]) -> Array[Vector2]:
	var aparicion: Array[Vector2] = []
	for a in get_tree().get_nodes_in_group("puntos_aparicion"):
		aparicion.append(a.global_position)
	var libres: Array[Vector2] = []
	var paso := 30.0
	var x := limites_faroles.position.x
	while x <= limites_faroles.end.x:
		var y := limites_faroles.position.y
		while y <= limites_faroles.end.y:
			var p := Vector2(x, y) + Vector2(randf_range(-8, 8), randf_range(-8, 8))
			var ok := p.distance_to(chispa.global_position) >= distancia_farol_chispa
			if ok:
				for a in aparicion:
					if p.distance_to(a) < 110.0:
						ok = false
						break
			if ok and _fuera_de_obstaculos(_rect_farol(p), margen_faroles_obstaculos) \
					and _sin_obstaculos(p, Vector2(76, 56), Vector2(0, -18), excluir):
				libres.append(p)
			y += paso
		x += paso
	return libres


## Rectángulo que ocupa un farol dibujado con su base en `p`.
func _rect_farol(p: Vector2) -> Rect2:
	return Rect2(p + Vector2(-30, -96), Vector2(60, 108))


## Rectángulos de los DIBUJOS de los obstáculos (fuente, bancas, barriles, jardineras, arbustos).
## Las colisiones solo cubren la base; el dibujo es más grande y no queremos encimar nada sobre él.
func _zonas() -> Array[Rect2]:
	if _zonas_obstaculos.is_empty():
		for n in objetos.get_children():
			if n is StaticBody2D and not n.is_in_group("faroles"):
				for hijo in n.get_children():
					if hijo is Sprite2D:
						_zonas_obstaculos.append(hijo.global_transform * hijo.get_rect())
	return _zonas_obstaculos


func _fuera_de_obstaculos(r: Rect2, margen: float) -> bool:
	for z in _zonas():
		if z.grow(margen).intersects(r):
			return false
	return true


func _sin_obstaculos(p: Vector2, tam: Vector2, desfase: Vector2, excluir: Array[RID] = []) -> bool:
	var forma := RectangleShape2D.new()
	forma.size = tam
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = forma
	q.transform = Transform2D(0.0, p + desfase)
	q.collision_mask = 1
	q.collide_with_areas = false
	q.exclude = excluir
	return get_world_2d().direct_space_state.intersect_shape(q, 1).is_empty()


# ---------------------------------------------------------------
# VIDAS EXTRA (corazones)
# ---------------------------------------------------------------
func _actualizar_vida_extra(delta: float) -> void:
	if chispa.muerto:
		return
	if chispa.vidas >= chispa.vidas_maximas:
		# Con todas las vidas no aparece nada; el reloj espera a que pierda una
		_t_vida_extra = randf_range(intervalo_vida_extra.x, intervalo_vida_extra.y)
		return
	if not get_tree().get_nodes_in_group("vidas_extra").is_empty():
		return
	_t_vida_extra -= delta
	if _t_vida_extra <= 0.0:
		_t_vida_extra = randf_range(intervalo_vida_extra.x, intervalo_vida_extra.y)
		_generar_vida_extra()


func _generar_vida_extra() -> void:
	var v: Area2D = SCRIPT_VIDA_EXTRA.new()
	v.duracion = duracion_vida_extra
	v.position = _buscar_punto_vida_extra()
	v.expirada.connect(_on_vida_extra_expirada)
	objetos.add_child(v)
	hud.aviso("¡Apareció un corazón! Recógelo para recuperar una vida", Color("#FF7A9A"), 2.0)


func _on_vida_extra_expirada(_v: Node) -> void:
	if not terminada:
		hud.aviso("El corazón se apagó...", Color("#FF7A9A"), 1.2)


func _buscar_punto_vida_extra() -> Vector2:
	var ocupadas: Array[Vector2] = []
	for c in get_tree().get_nodes_in_group("celdas"):
		ocupadas.append(c.global_position)
	for f in get_tree().get_nodes_in_group("faroles"):
		ocupadas.append(f.global_position)
	var mejor := Vector2(640, 300)
	var mejor_d := -1.0
	for _i in 60:
		var p := Vector2(randf_range(LIMITES_CELDAS.position.x, LIMITES_CELDAS.end.x),
			randf_range(LIMITES_CELDAS.position.y, LIMITES_CELDAS.end.y))
		if not _punto_valido(p, ocupadas):
			continue
		var d := p.distance_to(chispa.global_position)
		if d >= distancia_vida_extra:
			return p
		if d > mejor_d:
			mejor_d = d
			mejor = p
	return mejor


func _on_vida_recuperada() -> void:
	Audio.sfx("confirmar", 1.15)
	_texto_flotante("+1 vida", chispa.global_position + Vector2(0, -50), Color("#FF7A9A"))
	hud.vida_recuperada()
	hud.aviso("¡Vida recuperada!  %d/%d" % [chispa.vidas, chispa.vidas_maximas], Color("#FF7A9A"), 1.2)


func _punto_aparicion_oscuro() -> Vector2:
	var candidatos: Array[Vector2] = []
	for p in get_tree().get_nodes_in_group("puntos_aparicion"):
		var pos: Vector2 = p.global_position
		if pos.distance_to(chispa.global_position) >= 300.0 and not _en_luz(pos):
			candidatos.append(pos)
	if candidatos.is_empty():
		for p in get_tree().get_nodes_in_group("puntos_aparicion"):
			candidatos.append(p.global_position)
	if candidatos.is_empty():
		return Vector2(80, 80)
	return candidatos.pick_random()


func _en_luz(pos: Vector2) -> bool:
	for f in get_tree().get_nodes_in_group("faroles"):
		if f.get("encendido") == true and pos.distance_to(f.global_position) <= float(f.get("radio_luz")):
			return true
	return false


# ---------------------------------------------------------------
# OSCURIDAD DINÁMICA (GDD 1.5 y 4.4)
# ---------------------------------------------------------------
func _actualizar_vision(delta: float) -> void:
	var distancia := INF
	for f in get_tree().get_nodes_in_group("faroles"):
		if f.get("encendido") == true:
			distancia = minf(distancia, chispa.global_position.distance_to(f.global_position))
	var lejania := 1.0
	if distancia < INF:
		lejania = clampf((distancia - dist_vision_plena) / maxf(dist_vision_minima - dist_vision_plena, 1.0), 0.0, 1.0)
	_lejania = lerpf(_lejania, lejania, 1.0 - exp(-4.0 * delta))
	_vision = lerpf(1.0, vision_minima, _lejania)
	chispa.set_factor_vision(_vision)
	var base: Color = _v(ambiente_por_ronda) if ambiente_por_ronda.size() > 0 else Color(0.42, 0.47, 0.72)
	ambiente.color = base.lerp(base.darkened(oscurecer_lejos), _lejania)


# ---------------------------------------------------------------
# CELDAS (GDD 2.6 y 4.5)
# ---------------------------------------------------------------
func _generar_celda() -> void:
	if terminada:
		return
	var celda = ESCENA_CELDA.instantiate()
	if celda == null or not celda.has_signal("recogida"):
		push_error("mundo: celda.tscn no tiene el script celda_de_energia.gd")
		if celda:
			celda.queue_free()
		return
	celda.position = _buscar_punto_celda()
	celda.connect("recogida", func(_c): _celdas_activas = maxi(_celdas_activas - 1, 0))
	objetos.add_child(celda)
	_celdas_activas += 1


func _buscar_punto_celda() -> Vector2:
	var ocupadas: Array[Vector2] = []
	for c in get_tree().get_nodes_in_group("celdas"):
		if not c.is_queued_for_deletion():
			ocupadas.append(c.global_position)
	for f in get_tree().get_nodes_in_group("faroles"):
		ocupadas.append(f.global_position)
		ocupadas.append(f.global_position + Vector2(0, -60))   # el poste también ocupa espacio
	for _i in 60:
		var p := Vector2(randf_range(LIMITES_CELDAS.position.x, LIMITES_CELDAS.end.x),
			randf_range(LIMITES_CELDAS.position.y, LIMITES_CELDAS.end.y))
		if _punto_valido(p, ocupadas):
			return p
	var libres: Array[Vector2] = []
	for p in POS_CELDAS:
		if _punto_valido(p, ocupadas, false):
			libres.append(p)
	return libres.pick_random() if not libres.is_empty() else POS_CELDAS.pick_random()


func _punto_valido(p: Vector2, ocupadas: Array[Vector2], revisar_fisica: bool = true) -> bool:
	if p.distance_to(chispa.global_position) < 90.0:
		return false
	for o in ocupadas:
		if p.distance_to(o) < 70.0:
			return false
	if not revisar_fisica:
		return true
	if not _fuera_de_obstaculos(Rect2(p - Vector2(16, 16), Vector2(32, 32)), margen_objetos_obstaculos):
		return false
	return _sin_obstaculos(p, Vector2(48, 110), Vector2(0, 40))


# ---------------------------------------------------------------
# EVENTOS DE CHISPA
# ---------------------------------------------------------------
func _on_energia(energia: float, maxima: float) -> void:
	hud.actualizar_energia(energia, maxima, energia < float(chispa.umbral_energia_baja))


func _on_energia_baja() -> void:
	hud.aviso("¡Energía baja! Busca una celda", Color("#FF8A5A"))
	Audio.sfx("energia_baja")


func _on_energia_insuficiente() -> void:
	hud.aviso("Necesitas 10 de energía para encender el farol", Color("#FF8A5A"))
	Audio.sfx("error")


func _on_sombra_disipada(_sombra: Node, motivo: StringName) -> void:
	if motivo == &"luz" and not terminada:
		Audio.sfx("sombra_disipa", randf_range(0.9, 1.1), -2.0)


func _on_celda(en_zona_iluminada: bool) -> void:
	Audio.sfx("celda", 1.0 + 0.07 * (combo - 1))
	celdas_recogidas += 1
	var base: int = PUNTOS_CELDA * combo
	_sumar_puntos(base, "celdas")
	var texto := "+%d" % base
	if not en_zona_iluminada:
		celdas_riesgo += 1
		_sumar_puntos(BONO_RIESGO, "riesgo")
		texto += "  +%d riesgo" % BONO_RIESGO
	_texto_flotante(texto, chispa.global_position + Vector2(0, -50), Estilo.ORO)
	combo = mini(combo + 1, COMBO_MAX)
	combo_maximo = maxi(combo_maximo, combo)
	_t_combo = float(_v(ventana_combo))
	_actualizar_combo()


func _on_farol(farol: Node) -> void:
	Audio.sfx("farol")
	faroles_ronda += 1
	faroles_totales += 1
	_sumar_puntos(PUNTOS_FAROL, "faroles")
	_texto_flotante("+%d" % PUNTOS_FAROL, farol.global_position + Vector2(0, -90), Color("#FFE9A8"))
	hud.actualizar_faroles(faroles_ronda, FAROLES_POR_RONDA, true)
	if faroles_ronda >= FAROLES_POR_RONDA:
		_completar_ronda()
	else:
		hud.aviso("Farol encendido  %d/%d" % [faroles_ronda, FAROLES_POR_RONDA], Estilo.ORO, 1.2)


func _on_vida_perdida() -> void:
	Audio.sfx("golpe")
	combo = 1
	_t_combo = 0.0
	_actualizar_combo()
	hud.golpe()
	_sacudir_camara(9.0, 0.35)
	_pausa_de_impacto()


# ---------------------------------------------------------------
# MEJORA: sensación de golpe (sacudida de cámara + micro-pausa)
# ---------------------------------------------------------------
func _sacudir_camara(fuerza: float, duracion: float) -> void:
	var cam := get_node_or_null("Camara") as Camera2D
	if cam == null:
		return
	var tw := cam.create_tween()
	var pasos := 7
	for i in pasos:
		var f := fuerza * (1.0 - float(i) / pasos)
		tw.tween_property(cam, "offset", Vector2(randf_range(-f, f), randf_range(-f, f)), duracion / pasos)
	tw.tween_property(cam, "offset", Vector2.ZERO, 0.05)


func _pausa_de_impacto() -> void:
	Engine.time_scale = 0.15
	await get_tree().create_timer(0.08, true, false, true).timeout
	Engine.time_scale = 1.0


func _exit_tree() -> void:
	Engine.time_scale = 1.0   # por si se sale justo durante la micro-pausa


# ---------------------------------------------------------------
# MEJORA: pistas en la primera partida (tutorial ligero)
# ---------------------------------------------------------------
func _tutorial() -> void:
	if Global.tutorial_visto:
		return
	var tecla := func(accion: String) -> String:
		var t: Array = Global.get_teclas(accion)
		return Estilo.nombre_tecla(int(t[0])) if t.size() > 0 and int(t[0]) != 0 else "?"
	var pistas := [
		"Acércate a un farol y pulsa %s para encenderlo (cuesta 10 de energía)" % tecla.call("encender_farol"),
		"Fuera de la luz gastas energía: recoge las celdas amarillas para recargar",
		"Mantén %s para correr más rápido (gasta energía extra)" % tecla.call("correr"),
		"Si una Sombra te persigue (\"!\"), llévala a la luz de un farol para disiparla",
	]
	await get_tree().create_timer(3.5 if Global.en_linea else 8.0, false).timeout
	for p in pistas:
		if terminada or not is_inside_tree():
			return
		hud.aviso(p, Color("#9AD8FF"), 4.5)
		await get_tree().create_timer(7.0, false).timeout


func _on_jugador_murio() -> void:
	await get_tree().create_timer(1.2).timeout
	_finalizar(false, "vidas")


func _actualizar_combo() -> void:
	hud.actualizar_combo(combo, _t_combo, float(_v(ventana_combo)))


func _sumar_puntos(cantidad: int, clave: String, animar: bool = true) -> void:
	desglose[clave] = int(desglose.get(clave, 0)) + cantidad
	puntos = clampi(puntos + cantidad, 0, PUNTUACION_MAXIMA)
	hud.actualizar_puntos(puntos, animar)


# ---------------------------------------------------------------
# FIN DE PARTIDA (GDD 2.5 y 5.3)
# ---------------------------------------------------------------
func _finalizar(victoria: bool, motivo: String) -> void:
	if terminada:
		return
	terminada = true
	_en_transicion = false
	Engine.time_scale = 1.0
	if not Global.tutorial_visto:
		Global.tutorial_visto = true
	get_tree().paused = true
	_activar_pausa(false)
	var datos := {
		"victoria": victoria, "motivo": motivo, "ronda": ronda, "puntos": puntos, "desglose": desglose,
		"celdas": celdas_recogidas, "riesgo": celdas_riesgo, "faroles": faroles_totales,
		"rondas": rondas_completadas, "rondas_totales": RONDAS_TOTALES, "tiempo": int(tiempo_total),
		"combo_max": combo_maximo,
	}
	Audio.tema_y_despues("victoria" if victoria else "derrota", "menu")
	if victoria:
		# Historia: el final se cuenta en cómic y después aparecen los resultados
		await _comic_final()
	hud.mostrar_resultados(datos)
	Global.registrar_puntaje(puntos, celdas_recogidas, faroles_totales, combo_maximo, int(tiempo_total), ronda)


func _comic_final() -> void:
	var capa := CanvasLayer.new()
	capa.layer = 60
	capa.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(capa)
	var comic: Control = load(Global.ESCENA_COMIC).instantiate()
	comic.historia = "final"
	comic.puntos_finales = puntos
	capa.add_child(comic)
	await comic.terminado
	capa.queue_free()


## RF-07: si no hay internet se avisa, pero la partida sigue con normalidad.
func _avisar_si_sin_conexion() -> void:
	var en_linea: bool = await Global.comprobar_conexion()
	if not en_linea and not terminada and is_instance_valid(hud):
		await get_tree().create_timer(3.0, false).timeout   # después del banner de la ronda
		if not terminada:
			hud.aviso("Sin conexión: puedes jugar igual, tu puntuación se guardará en este equipo", Color("#FFB37A"), 4.0)


func _activar_pausa(activa: bool) -> void:
	if _pausa == null:
		return
	_pausa.visible = activa
	_pausa.process_mode = Node.PROCESS_MODE_ALWAYS if activa else Node.PROCESS_MODE_DISABLED


func _texto_flotante(texto: String, pos: Vector2, color: Color) -> void:
	var l := Estilo.label_hud(texto, 18, color, HORIZONTAL_ALIGNMENT_CENTER)
	l.size = Vector2(200, 30)
	l.position = pos - Vector2(100, 15)
	_textos_flotantes.add_child(l)
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 36.0, 0.8)
	tw.tween_property(l, "modulate:a", 0.0, 0.8).set_delay(0.3)
	tw.chain().tween_callback(l.queue_free)
