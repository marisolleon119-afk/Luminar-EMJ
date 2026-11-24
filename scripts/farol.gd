class_name Farol
extends StaticBody2D
## Farol de Luminar. Contrato con Chispa y las Sombras:
##   - grupo "faroles", variables `encendido: bool` y `radio_luz: float`, método encender().

signal encendido_cambiado(farol: Farol, encendido: bool)

@export var radio_luz: float = 128.0      # GDD 2.3: zona segura de 128 px
@export var encendido_inicial: bool = false

@onready var sprite: Sprite2D = $Sprite
@onready var luz: PointLight2D = $Luz
@onready var aro: Node2D = $Aro

const TEX_ON := preload("res://Recursos/Mundo/farol_on.png")
const TEX_OFF := preload("res://Recursos/Mundo/farol_off.png")
const ENERGIA_LUZ := 1.9

var encendido: bool = false
var _tween: Tween = null
var _t: float = 0.0


func _ready() -> void:
	add_to_group("faroles")
	aro.set("radio", radio_luz)
	if encendido_inicial:
		_aplicar(true, false)
	else:
		_aplicar(false, false)


func encender() -> void:
	if encendido:
		return
	_aplicar(true, true)


## Al empezar una ronda nueva (GDD 3.2: apagado al inicio de cada ronda). Sin animación.
func reiniciar() -> void:
	_aplicar(false, false)


## GDD: en cada ronda los faroles cambian de lugar (lo llama mundo.gd).
## La animación corre aunque el juego esté en pausa (transición entre rondas).
func mover_a(pos: Vector2, animar: bool = false) -> void:
	global_position = pos
	if not animar:
		return
	sprite.scale = Vector2(0.15, 0.15)
	sprite.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(sprite, "scale", Vector2(0.7, 0.7), 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(randf() * 0.25)
	tw.tween_property(sprite, "modulate:a", 1.0, 0.3)


func apagar() -> void:
	if not encendido:
		return
	_aplicar(false, true)


func _aplicar(valor: bool, animar: bool) -> void:
	encendido = valor
	sprite.texture = TEX_ON if valor else TEX_OFF
	aro.visible = valor
	if _tween:
		_tween.kill()
	if animar:
		_tween = create_tween()
		if valor:
			luz.energy = 0.0
			_tween.tween_property(luz, "energy", ENERGIA_LUZ, 0.6)
			sprite.scale = Vector2(0.82, 0.82)
			_tween.parallel().tween_property(sprite, "scale", Vector2(0.7, 0.7), 0.4)
		else:
			_tween.tween_property(luz, "energy", 0.0, 0.4)
	else:
		luz.energy = ENERGIA_LUZ if valor else 0.0
	encendido_cambiado.emit(self, valor)


## Parpadeo suave de la llama mientras está encendido.
func _process(delta: float) -> void:
	if not encendido or (_tween and _tween.is_running()):
		return
	_t += delta
	luz.energy = ENERGIA_LUZ + sin(_t * 7.0) * 0.07 + sin(_t * 13.0) * 0.04
