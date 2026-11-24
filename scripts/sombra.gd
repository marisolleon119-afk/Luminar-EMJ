class_name Sombra
extends CharacterBody2D
## Enemigo "Sombra" de Luminar (GDD secciones 2.3, 3.2, 3.3 y 4.4).
##
## Estados: MERODEAR -> PERSEGUIR -> DISIPARSE -> REAPARECER -> MERODEAR
##
## Estructura de la escena (Sombra.tscn):
##   Sombra (CharacterBody2D, este script)   collision_layer = 4 (enemigos), collision_mask = 1 (muros/obstáculos)
##   ├── AnimatedSprite2D   animaciones opcionales: REPOSO, CAMINAR, DISIPAR
##   ├── CollisionShape2D   cuerpo físico (solo choca con muros)
##   └── AreaDano (Area2D)  collision_layer = 0, collision_mask = 2 (jugador)
##       └── CollisionShape2D
##
## Contrato con otros nodos:
##   - Chispa:  grupo "jugador", método recibir_dano(cantidad: int) y,
##              opcional, es_invulnerable() -> bool (los 2 s de invulnerabilidad).
##   - Faroles: grupo "faroles", variables `encendido: bool` y `radio_luz: float`.
##   - Puntos de aparición: nodos Marker2D en el grupo "puntos_aparicion" (borde oscuro del mapa).

signal disipada(sombra: Sombra, motivo: StringName)   # &"luz" o &"contacto"
signal reaparecida(sombra: Sombra)

enum Estado { MERODEAR, PERSEGUIR, DISIPARSE, REAPARECER }

# Tabla de dificultad (GDD 4.4). Índice 0 = Ronda 1.
const VELOCIDAD_MERODEO_POR_RONDA: Array[float] = [60.0, 75.0, 90.0]
const VELOCIDAD_PERSECUCION_POR_RONDA: Array[float] = [90.0, 110.0, 130.0]
const TIEMPO_REAPARICION: float = 8.0           # GDD 2.3: reaparece 8 s después

@export_group("Detección")
@export var radio_deteccion: float = 200.0       # Persigue si Chispa está a menos de esto y fuera de la luz
@export var histeresis: float = 20.0             # Evita que alterne de estado justo en el límite

@export_group("Luz")
@export_range(0.0, 1.0) var factor_velocidad_en_luz: float = 0.5
@export var tiempo_disipacion_luz: float = 2.0   # Segundos seguidos dentro de la luz para disiparse

@export_group("Merodeo")
@export var radio_merodeo: float = 120.0
@export var espera_min: float = 0.5
@export var espera_max: float = 1.5
@export var limites_mapa: Rect2 = Rect2(32, 32, 1216, 640)   # Mapa de 1280x704 menos el muro

@export_group("Disipación y reaparición")
@export var duracion_fundido: float = 0.4
@export var distancia_minima_aparicion: float = 300.0        # No aparece encima de Chispa
@export var dano_contacto: int = 1                           # -1 vida

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var colision: CollisionShape2D = $CollisionShape2D
@onready var area_dano: Area2D = $AreaDano

var estado: Estado = Estado.MERODEAR
var ronda: int = 1
var velocidad_ronda: float = 60.0          # merodeo
var velocidad_persecucion: float = 90.0
var tiempo_reaparicion: float = TIEMPO_REAPARICION

# Dificultad ampliada (los valores por ronda los envía mundo.gd con configurar())
var radio_alerta: float = 0.0            # avisa a las Sombras cercanas cuando ve a Chispa
var anticipacion: float = 0.0            # segundos que "adelanta" la posición de Chispa al perseguir
var multiplicador_furia: float = 1.0     # sube mientras más dura la ronda
var _t_alerta: float = 0.0

var jugador: Node2D = null
var en_luz: bool = false

var destino_merodeo: Vector2
var temporizador_espera: float = 0.0
var temporizador_luz: float = 0.0
var temporizador_reaparicion: float = 0.0


func _ready() -> void:
	add_to_group("sombras")
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING   # Vista cenital, sin gravedad
	configurar_ronda(ronda)
	destino_merodeo = global_position
	temporizador_espera = randf_range(espera_min, espera_max)


## Llamar desde SpawnManager al crear la Sombra o al cambiar de ronda.
func configurar_ronda(nueva_ronda: int) -> void:
	ronda = clampi(nueva_ronda, 1, VELOCIDAD_MERODEO_POR_RONDA.size())
	velocidad_ronda = VELOCIDAD_MERODEO_POR_RONDA[ronda - 1]
	velocidad_persecucion = VELOCIDAD_PERSECUCION_POR_RONDA[ronda - 1]
	tiempo_reaparicion = TIEMPO_REAPARICION


## Parámetros completos de dificultad de la ronda (los arma mundo.gd desde el Inspector).
func configurar(p: Dictionary) -> void:
	ronda = int(p.get("ronda", ronda))
	velocidad_ronda = float(p.get("merodeo", velocidad_ronda))
	velocidad_persecucion = float(p.get("persecucion", velocidad_persecucion))
	radio_deteccion = float(p.get("deteccion", radio_deteccion))
	tiempo_disipacion_luz = float(p.get("disipacion", tiempo_disipacion_luz))
	factor_velocidad_en_luz = float(p.get("frenado_luz", factor_velocidad_en_luz))
	tiempo_reaparicion = float(p.get("reaparicion", tiempo_reaparicion))
	radio_alerta = float(p.get("alerta", radio_alerta))
	anticipacion = float(p.get("anticipacion", anticipacion))


## Otra Sombra vio a Chispa: esta la busca aunque esté más lejos de su radio normal.
## MEJORA: un "!" sobre la Sombra avisa que te vio y empieza a perseguirte.
func _mostrar_alerta() -> void:
	var l := Label.new()
	l.text = "!"
	l.add_theme_font_size_override("font_size", 34)
	l.add_theme_color_override("font_color", Color("#FF5C8A"))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 6)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(40, 44)
	l.position = Vector2(-20, -92)
	l.pivot_offset = Vector2(20, 40)
	l.scale = Vector2(0.2, 0.2)
	l.z_index = 20
	add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.55)
	tw.tween_property(l, "modulate:a", 0.0, 0.3)
	tw.tween_callback(l.queue_free)


func recibir_alerta(duracion: float) -> void:
	if estado == Estado.MERODEAR or estado == Estado.PERSEGUIR:
		_t_alerta = maxf(_t_alerta, duracion)


func _alertar_vecinas() -> void:
	if radio_alerta <= 0.0:
		return
	for otra in get_tree().get_nodes_in_group("sombras"):
		if otra != self and global_position.distance_to(otra.global_position) <= radio_alerta:
			otra.recibir_alerta(3.0)


## Al reiniciar el mapa entre rondas: la Sombra vuelve a un punto oscuro del borde.
func reiniciar_en(pos: Vector2) -> void:
	global_position = pos
	velocity = Vector2.ZERO
	temporizador_luz = 0.0
	en_luz = false
	visible = true
	modulate.a = 0.0
	_set_activa(true)
	_t_alerta = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, duracion_fundido)
	estado = Estado.MERODEAR
	_elegir_destino_merodeo()


func _physics_process(delta: float) -> void:
	# La pausa (get_tree().paused) detiene este método, así que los
	# temporizadores también se congelan sin trabajo extra.
	match estado:
		Estado.DISIPARSE, Estado.REAPARECER:
			velocity = Vector2.ZERO
			_procesar_reaparicion(delta)
			return

	# Estados activos: MERODEAR y PERSEGUIR
	if _t_alerta > 0.0:
		_t_alerta -= delta
	if _vigilar_luz(delta):
		return                      # Se acaba de disipar
	if _revisar_contacto():
		return                      # Tocó a Chispa y se disipó

	_evaluar_transicion()

	if estado == Estado.PERSEGUIR:
		_procesar_persecucion()
	else:
		_procesar_merodeo(delta)

	move_and_slide()

	# Si chocó con un obstáculo mientras merodea, elige otro destino
	if estado == Estado.MERODEAR and get_slide_collision_count() > 0:
		_elegir_destino_merodeo()

	_actualizar_animacion()


# ---------------------------------------------------------------
# LUZ
# ---------------------------------------------------------------
## ¿La posición está dentro de la zona de algún farol encendido?
func esta_en_luz(pos: Vector2) -> bool:
	for farol in get_tree().get_nodes_in_group("faroles"):
		if farol.get("encendido") == true and pos.distance_to(farol.global_position) <= float(farol.get("radio_luz")):
			return true
	return false


## Actualiza `en_luz` y cuenta los 2 s. Devuelve true si la Sombra se disipó.
func _vigilar_luz(delta: float) -> bool:
	en_luz = esta_en_luz(global_position)
	if en_luz:
		temporizador_luz += delta
		if temporizador_luz >= tiempo_disipacion_luz:
			_disiparse(&"luz")
			return true
	else:
		temporizador_luz = 0.0      # Los 2 s deben ser seguidos
	return false


func _velocidad_actual(base: float) -> float:
	return base * multiplicador_furia * (factor_velocidad_en_luz if en_luz else 1.0)


# ---------------------------------------------------------------
# TRANSICIONES MERODEAR <-> PERSEGUIR
# ---------------------------------------------------------------
func _buscar_jugador() -> void:
	if jugador == null or not is_instance_valid(jugador):
		jugador = get_tree().get_first_node_in_group("jugador") as Node2D


func _evaluar_transicion() -> void:
	_buscar_jugador()
	if jugador == null:
		_pasar_a_merodear()
		return

	var distancia := global_position.distance_to(jugador.global_position)
	var limite := radio_deteccion + (histeresis if estado == Estado.PERSEGUIR else 0.0)
	if _t_alerta > 0.0:
		limite = maxf(limite, radio_deteccion * 2.0)   # alertada por otra Sombra
	var jugador_expuesto := not esta_en_luz(jugador.global_position)

	if distancia <= limite and jugador_expuesto:
		if estado != Estado.PERSEGUIR:
			estado = Estado.PERSEGUIR
			_mostrar_alerta()
			if _t_alerta <= 0.0:
				_alertar_vecinas()       # la que vio primero avisa a las demás
		sprite.modulate = Color(1.25, 0.8, 1.25)   # tono magenta: está cazando
	elif estado == Estado.PERSEGUIR:
		_pasar_a_merodear()
		sprite.modulate = Color.WHITE


func _pasar_a_merodear() -> void:
	if estado == Estado.MERODEAR:
		return
	estado = Estado.MERODEAR
	_elegir_destino_merodeo()


# ---------------------------------------------------------------
# COMPORTAMIENTOS
# ---------------------------------------------------------------
func _procesar_merodeo(delta: float) -> void:
	if global_position.distance_to(destino_merodeo) > 4.0:
		velocity = global_position.direction_to(destino_merodeo) * _velocidad_actual(velocidad_ronda)
	else:
		velocity = Vector2.ZERO
		temporizador_espera -= delta
		if temporizador_espera <= 0.0:
			_elegir_destino_merodeo()


## Elige un punto aleatorio cercano que esté en zona oscura y dentro del mapa.
func _elegir_destino_merodeo() -> void:
	temporizador_espera = randf_range(espera_min, espera_max)
	destino_merodeo = global_position   # Si no hay punto válido, se queda quieta

	for i in 12:
		var candidato := global_position + Vector2.from_angle(randf() * TAU) * randf_range(32.0, radio_merodeo)
		if limites_mapa.has_point(candidato) and not esta_en_luz(candidato):
			destino_merodeo = candidato
			return


func _procesar_persecucion() -> void:
	# Va hacia Chispa; en rondas altas apunta a donde Chispa VA a estar (anticipación)
	var objetivo := jugador.global_position
	if anticipacion > 0.0 and jugador is CharacterBody2D:
		var futuro := objetivo + (jugador as CharacterBody2D).velocity * anticipacion
		if global_position.distance_to(objetivo) > 48.0:
			objetivo = futuro
	velocity = global_position.direction_to(objetivo) * _velocidad_actual(velocidad_persecucion)


# ---------------------------------------------------------------
# CONTACTO CON CHISPA
# ---------------------------------------------------------------
## Se revisa cada frame (no con body_entered) para que, si Chispa estaba
## invulnerable al tocarla, el contacto se vuelva a evaluar después.
func _revisar_contacto() -> bool:
	for cuerpo in area_dano.get_overlapping_bodies():
		if not cuerpo.is_in_group("jugador"):
			continue
		if cuerpo.has_method("es_invulnerable") and cuerpo.es_invulnerable():
			continue
		if cuerpo.has_method("recibir_dano"):
			cuerpo.recibir_dano(dano_contacto)   # -1 vida, 2 s de invulnerabilidad, combo x1 (lo hace Chispa)
		_disiparse(&"contacto")
		return true
	return false


# ---------------------------------------------------------------
# DISIPARSE y REAPARECER
# ---------------------------------------------------------------
func _disiparse(motivo: StringName) -> void:
	if estado == Estado.DISIPARSE or estado == Estado.REAPARECER:
		return
	sprite.modulate = Color.WHITE
	_t_alerta = 0.0

	estado = Estado.DISIPARSE
	velocity = Vector2.ZERO
	temporizador_luz = 0.0
	temporizador_reaparicion = tiempo_reaparicion   # Cuenta desde que se disipa
	_set_activa(false)

	if sprite.sprite_frames and sprite.sprite_frames.has_animation("DISIPAR"):
		sprite.play("DISIPAR")

	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, duracion_fundido)
	tween.tween_callback(_terminar_fundido)

	disipada.emit(self, motivo)


func _terminar_fundido() -> void:
	visible = false
	estado = Estado.REAPARECER


func _procesar_reaparicion(delta: float) -> void:
	temporizador_reaparicion -= delta
	if estado == Estado.REAPARECER and temporizador_reaparicion <= 0.0:
		_reaparecer()


func _reaparecer() -> void:
	global_position = _elegir_punto_aparicion()
	velocity = Vector2.ZERO
	temporizador_luz = 0.0
	en_luz = false
	visible = true
	modulate.a = 0.0
	_set_activa(true)

	create_tween().tween_property(self, "modulate:a", 1.0, duracion_fundido)

	estado = Estado.MERODEAR
	_elegir_destino_merodeo()
	reaparecida.emit(self)


## Punto de aparición oscuro del borde, preferiblemente lejos de Chispa.
func _elegir_punto_aparicion() -> Vector2:
	var puntos := get_tree().get_nodes_in_group("puntos_aparicion")
	if puntos.is_empty():
		push_warning("Sombra: no hay nodos en el grupo 'puntos_aparicion'; reaparece donde se disipó.")
		return global_position

	_buscar_jugador()
	var oscuros: Array[Vector2] = []
	var oscuros_lejanos: Array[Vector2] = []
	for p in puntos:
		var pos: Vector2 = p.global_position
		if esta_en_luz(pos):
			continue
		oscuros.append(pos)
		if jugador == null or pos.distance_to(jugador.global_position) >= distancia_minima_aparicion:
			oscuros_lejanos.append(pos)

	if not oscuros_lejanos.is_empty():
		return oscuros_lejanos.pick_random()
	if not oscuros.is_empty():
		return oscuros.pick_random()
	return (puntos.pick_random() as Node2D).global_position


## Activa/desactiva colisión y daño sin tocar la física dentro del mismo frame.
func _set_activa(activa: bool) -> void:
	colision.set_deferred("disabled", not activa)
	area_dano.set_deferred("monitoring", activa)


# ---------------------------------------------------------------
# ANIMACIÓN
# ---------------------------------------------------------------
func _actualizar_animacion() -> void:
	if sprite == null or sprite.sprite_frames == null:
		return

	if velocity.length() > 1.0:
		if sprite.sprite_frames.has_animation("CAMINAR") and sprite.animation != "CAMINAR":
			sprite.play("CAMINAR")
		if abs(velocity.x) > 1.0:
			sprite.flip_h = velocity.x < 0.0
	elif sprite.sprite_frames.has_animation("REPOSO") and sprite.animation != "REPOSO":
		sprite.play("REPOSO")
