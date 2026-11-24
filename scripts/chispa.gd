class_name Chispa
extends CharacterBody2D
## Chispa, el robot farolero de Luminar (GDD secciones 2.2, 2.3, 2.6 y 3.1).
##
## Estructura de la escena:
##   Chispa (CharacterBody2D, este script)   collision_layer = 2 (jugador), collision_mask = 1 (muros)
##   ├── AnimatedSprite2D   animaciones: VT (espalda), FRS (frente), LD (lado)
##   ├── CollisionShape2D
##   └── PointLight2D       (opcional) luz propia pequeña
##
## Input Map necesario: mover_izq, mover_der, mover_arr, mover_abj, encender_farol
##
## Contrato con otros nodos:
##   - Faroles: grupo "faroles", variables `encendido: bool` y `radio_luz: float`,
##              método encender().
##   - Celdas:  al tocar a Chispa llaman a chispa.recoger_celda().
##   - GameState escucha las señales para puntos, combo y fin de partida.

signal vidas_cambiadas(vidas_actuales: int, vidas_maximas: int)
signal energia_cambiada(energia: float, energia_maxima: float)
signal energia_baja                                   # Cruzó por debajo de 20 (sonido E-09)
signal energia_insuficiente                           # Intentó encender un farol sin 10 de energía
signal vida_perdida                                   # GameState: combo vuelve a x1
signal celda_recogida(en_zona_iluminada: bool)        # ScoreCalculator: bono de riesgo si es false
signal farol_encendido(farol: Node)                   # GameState: +50 puntos
signal jugador_murio
signal vida_recuperada                                # Recogió un corazón
signal corriendo_cambiado(corriendo: bool)            # HUD: barra de energía en modo sprint

@export_group("Movimiento")
@export var speed: float = 120.0
@export_range(0.0, 1.0) var factor_velocidad_sin_energia: float = 0.5

@export_group("Correr (Shift)")
## Multiplicador de velocidad al mantener la tecla de correr
@export var factor_correr: float = 1.6
## Energía extra por segundo mientras corre (se suma al gasto normal y también se paga en la luz)
@export var gasto_correr: float = 6.0
## Energía mínima para empezar a correr
@export var energia_minima_correr: float = 5.0

@export_group("Vidas")
@export var vidas_maximas: int = 3
@export var tiempo_invulnerable: float = 2.0

@export_group("Energía")
@export var energia_maxima: float = 100.0
@export var gasto_moviendose: float = 2.0             # por segundo
@export var gasto_quieta: float = 0.5                 # por segundo
@export var energia_por_celda: float = 15.0
@export var costo_farol: float = 10.0
@export var umbral_energia_baja: float = 20.0
@export var tiempo_max_sin_energia: float = 5.0
@export var energia_tras_perder_vida: float = 30.0

@export_group("Interacción y luz")
@export var radio_interaccion: float = 48.0
@export_range(0.0, 1.0) var escala_luz_minima: float = 0.3   # Fracción de la luz normal con 0 de energía

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var luz: PointLight2D = $PointLight2D if has_node("PointLight2D") else null

var vidas: int
var energia: float
var invulnerable: bool = false
var muerto: bool = false

# GDD 4.4: la visibilidad baja con cada ronda (amplia, reducida, muy reducida)
const VISIBILIDAD_POR_RONDA: Array[float] = [1.0, 0.8, 0.62]

var factor_luz_ronda: float = 1.0
var multiplicador_gasto: float = 1.0   # el gasto de energía sube en cada ronda (lo ajusta mundo.gd)
var factor_vision: float = 1.0        # GDD 1.5: baja al alejarse de un farol encendido (lo ajusta mundo.gd)
var escala_luz_base: float = 1.0

var _temporizador_invulnerable: float = 0.0
var _temporizador_sin_energia: float = 0.0
var _energia_entera_previa: int = -1
var _energia_baja_avisada: bool = false
var _tween_parpadeo: Tween = null
var corriendo: bool = false
var _estela: CPUParticles2D


## Crea las acciones de teclado si no existen en el Input Map del proyecto.
## Si ya las definiste en Project Settings, no toca nada.
func _registrar_acciones() -> void:
	var acciones := {
		"mover_izq": [KEY_A, KEY_LEFT],
		"mover_der": [KEY_D, KEY_RIGHT],
		"mover_arr": [KEY_W, KEY_UP],
		"mover_abj": [KEY_S, KEY_DOWN],
		"encender_farol": [KEY_E, KEY_SPACE],
		"correr": [KEY_SHIFT, KEY_K],
	}
	for accion in acciones:
		if InputMap.has_action(accion):
			continue
		InputMap.add_action(accion)
		for tecla in acciones[accion]:
			var evento := InputEventKey.new()
			evento.physical_keycode = tecla
			InputMap.action_add_event(accion, evento)


func _ready() -> void:
	_registrar_acciones()

	# Chispa se añade sola al grupo "jugador" para que las Sombras la detecten
	if not is_in_group("jugador"):
		add_to_group("jugador")

	vidas = vidas_maximas
	energia = energia_maxima
	if luz:
		escala_luz_base = luz.texture_scale

	vidas_cambiadas.emit(vidas, vidas_maximas)
	_actualizar_luz()
	_emitir_energia()


## Llamar al empezar cada ronda (1 a 3). La luz propia se reduce según la tabla del GDD 4.4.
func configurar_ronda(ronda: int) -> void:
	var i := clampi(ronda, 1, VISIBILIDAD_POR_RONDA.size()) - 1
	factor_luz_ronda = VISIBILIDAD_POR_RONDA[i]
	_actualizar_luz()


## Oscuridad dinámica: 1.0 junto a un farol encendido, menos al alejarse.
func set_factor_vision(valor: float) -> void:
	valor = clampf(valor, 0.0, 1.0)
	if is_equal_approx(valor, factor_vision):
		return
	factor_vision = valor
	_actualizar_luz()


func _physics_process(delta: float) -> void:
	if muerto:
		return

	# get_vector normaliza: en diagonal también se mueve a 120 px/s
	var input_vector := Input.get_vector("mover_izq", "mover_der", "mover_arr", "mover_abj")
	var factor := factor_velocidad_sin_energia if energia <= 0.0 else 1.0
	_actualizar_correr(input_vector != Vector2.ZERO)
	if corriendo:
		factor *= factor_correr
	velocity = input_vector * speed * factor
	move_and_slide()
	actualizar_animacion(input_vector)

	_actualizar_energia(delta, input_vector != Vector2.ZERO)
	if corriendo:
		_cambiar_energia(-gasto_correr * multiplicador_gasto * delta)
	_actualizar_invulnerabilidad(delta)

	if Input.is_action_just_pressed("encender_farol"):
		_intentar_encender_farol()


# ---------------------------------------------------------------
# CORRER: más velocidad a cambio de energía
# ---------------------------------------------------------------
func _actualizar_correr(moviendose: bool) -> void:
	var quiere := moviendose and InputMap.has_action("correr") and Input.is_action_pressed("correr")
	# Para empezar a correr hace falta un mínimo; si ya corre, sigue hasta quedarse en 0
	var puede := energia > (0.0 if corriendo else energia_minima_correr)
	var nuevo := quiere and puede
	if nuevo == corriendo:
		return
	corriendo = nuevo
	sprite.speed_scale = factor_correr if corriendo else 1.0
	_activar_estela(corriendo)
	corriendo_cambiado.emit(corriendo)


## MEJORA: chispitas doradas detrás de Chispa mientras corre.
func _activar_estela(activa: bool) -> void:
	if _estela == null:
		_estela = CPUParticles2D.new()
		_estela.amount = 28
		_estela.lifetime = 0.45
		_estela.local_coords = false
		_estela.position = Vector2(0, 6)
		_estela.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
		_estela.emission_sphere_radius = 6.0
		_estela.direction = Vector2(0, -1)
		_estela.spread = 180.0
		_estela.gravity = Vector2.ZERO
		_estela.initial_velocity_min = 8.0
		_estela.initial_velocity_max = 22.0
		_estela.scale_amount_min = 2.0
		_estela.scale_amount_max = 4.0
		var g := Gradient.new()
		g.set_color(0, Color(1.0, 0.85, 0.35, 0.9))
		g.set_color(1, Color(1.0, 0.6, 0.2, 0.0))
		_estela.color_ramp = g
		_estela.z_index = -1
		_estela.emitting = false
		add_child(_estela)
	_estela.emitting = activa


# ---------------------------------------------------------------
# ANIMACIÓN
# ---------------------------------------------------------------
func actualizar_animacion(input_vector: Vector2) -> void:
	if input_vector == Vector2.ZERO:
		# Se detiene en el primer frame
		sprite.stop()
		sprite.frame = 0
		return

	# El volteo se actualiza siempre que haya movimiento horizontal
	if input_vector.x != 0:
		sprite.flip_h = input_vector.x < 0

	# Prioridad vertical
	if input_vector.y < 0:
		sprite.play("VT")    # Vista trasera
	elif input_vector.y > 0:
		sprite.play("FRS")   # Frente
	else:
		sprite.play("LD")    # Lado


# ---------------------------------------------------------------
# ZONA SEGURA (luz de faroles encendidos)
# ---------------------------------------------------------------
func esta_en_zona_segura() -> bool:
	for farol in get_tree().get_nodes_in_group("faroles"):
		if farol.get("encendido") == true and global_position.distance_to(farol.global_position) <= float(farol.get("radio_luz")):
			return true
	return false


# ---------------------------------------------------------------
# ENERGÍA
# ---------------------------------------------------------------
func _actualizar_energia(delta: float, moviendose: bool) -> void:
	var en_zona := esta_en_zona_segura()

	# El gasto solo ocurre fuera de una zona segura
	if not en_zona:
		var gasto := (gasto_moviendose if moviendose else gasto_quieta) * multiplicador_gasto
		_cambiar_energia(-gasto * delta)

	# Con 0 de energía fuera de la zona segura corre el reloj de 5 s
	if energia <= 0.0 and not en_zona:
		_temporizador_sin_energia += delta
		if _temporizador_sin_energia >= tiempo_max_sin_energia:
			_temporizador_sin_energia = 0.0
			_perder_vidas(1, false)
			if not muerto:
				_cambiar_energia(energia_tras_perder_vida)
	else:
		_temporizador_sin_energia = 0.0


func _cambiar_energia(cantidad: float) -> void:
	var anterior := energia
	energia = clampf(energia + cantidad, 0.0, energia_maxima)

	# Aviso de energía baja, una sola vez por caída
	if energia < umbral_energia_baja and not _energia_baja_avisada:
		_energia_baja_avisada = true
		energia_baja.emit()
	elif energia >= umbral_energia_baja:
		_energia_baja_avisada = false

	# La luz solo cambia al cruzar el 0
	if (anterior <= 0.0) != (energia <= 0.0):
		_actualizar_luz()

	_emitir_energia()


func _emitir_energia() -> void:
	# Se emite solo cuando cambia el valor entero, para no saturar al HUD
	var entera := int(ceil(energia))
	if entera != _energia_entera_previa:
		_energia_entera_previa = entera
		energia_cambiada.emit(energia, energia_maxima)


func _actualizar_luz() -> void:
	if luz == null:
		return
	var escala := escala_luz_base * factor_luz_ronda * factor_vision
	if energia <= 0.0:
		escala *= escala_luz_minima
	luz.texture_scale = escala


# ---------------------------------------------------------------
# INTERACCIÓN: CELDAS Y FAROLES
# ---------------------------------------------------------------
## Lo llama la celda al tocar a Chispa.
func recoger_celda() -> void:
	if muerto:
		return
	celda_recogida.emit(esta_en_zona_segura())
	_cambiar_energia(energia_por_celda)


func _intentar_encender_farol() -> void:
	var cercano: Node2D = null
	var menor_distancia := radio_interaccion

	for farol in get_tree().get_nodes_in_group("faroles"):
		if farol.get("encendido") == true:
			continue
		var d := global_position.distance_to(farol.global_position)
		if d <= menor_distancia:
			menor_distancia = d
			cercano = farol

	if cercano == null:
		return
	if energia < costo_farol:
		energia_insuficiente.emit()
		return

	if cercano.has_method("encender"):
		cercano.encender()
		_cambiar_energia(-costo_farol)
		farol_encendido.emit(cercano)


# ---------------------------------------------------------------
# VIDAS Y DAÑO
# ---------------------------------------------------------------
## Lo llama el corazón al tocar a Chispa. Devuelve false si ya tiene todas las vidas.
func recuperar_vida(cantidad: int = 1) -> bool:
	if muerto or vidas >= vidas_maximas:
		return false
	vidas = mini(vidas + cantidad, vidas_maximas)
	vidas_cambiadas.emit(vidas, vidas_maximas)
	vida_recuperada.emit()
	# Destello verde breve
	var tw := create_tween()
	tw.tween_property(sprite, "modulate", Color(0.6, 1.4, 0.7), 0.12)
	tw.tween_property(sprite, "modulate", Color.WHITE, 0.35)
	return true


## Lo llama la Sombra. `cantidad` son vidas (el GDD usa -1).
func recibir_dano(cantidad: int = 1) -> void:
	_perder_vidas(cantidad, true)


## La Sombra lo consulta para no disiparse si Chispa no puede ser golpeada.
func es_invulnerable() -> bool:
	return invulnerable or muerto


func _perder_vidas(cantidad: int, con_invulnerabilidad: bool) -> void:
	if muerto:
		return
	if con_invulnerabilidad and invulnerable:
		return

	vidas = maxi(vidas - cantidad, 0)
	vidas_cambiadas.emit(vidas, vidas_maximas)
	vida_perdida.emit()

	if vidas <= 0:
		morir()
	elif con_invulnerabilidad:
		_activar_invulnerabilidad()


func _activar_invulnerabilidad() -> void:
	invulnerable = true
	_temporizador_invulnerable = tiempo_invulnerable

	# Parpadeo para que se note el golpe
	if _tween_parpadeo:
		_tween_parpadeo.kill()
	_tween_parpadeo = create_tween().set_loops(int(tiempo_invulnerable / 0.2))
	_tween_parpadeo.tween_property(sprite, "modulate:a", 0.3, 0.1)
	_tween_parpadeo.tween_property(sprite, "modulate:a", 1.0, 0.1)


## El temporizador vive en _physics_process: se congela con la pausa del juego.
func _actualizar_invulnerabilidad(delta: float) -> void:
	if not invulnerable:
		return
	_temporizador_invulnerable -= delta
	if _temporizador_invulnerable <= 0.0:
		invulnerable = false
		if _tween_parpadeo:
			_tween_parpadeo.kill()
		sprite.modulate.a = 1.0


func morir() -> void:
	muerto = true
	if corriendo:
		corriendo = false
		corriendo_cambiado.emit(false)
	velocity = Vector2.ZERO
	sprite.stop()
	sprite.modulate = Color(1, 0.3, 0.3)   # Tinte rojo al morir
	# GameState decide qué sigue: calcular puntuación, guardar en la nube y mostrar Resultados
	jugador_murio.emit()
