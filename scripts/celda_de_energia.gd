class_name CeldaEnergia
extends Area2D
## Celda de energía: al tocar a Chispa le da energía (chispa.recoger_celda()) y desaparece.

signal recogida(celda: CeldaEnergia)

@onready var deslumbre: AnimatedSprite2D = $Deslumbre
@onready var luz: PointLight2D = $Luz

var _t: float = randf() * TAU
var _base_y: float = 0.0
var _tomada: bool = false


func _ready() -> void:
	add_to_group("celdas")
	collision_layer = 0
	collision_mask = 2          # solo detecta a Chispa (capa 2)
	_base_y = deslumbre.position.y
	body_entered.connect(_on_body_entered)
	# Aparición suave
	scale = Vector2(0.2, 0.2)
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	_t += delta * 3.0
	deslumbre.position.y = _base_y + sin(_t) * 3.0
	luz.energy = 0.85 + sin(_t * 1.7) * 0.15


func _on_body_entered(cuerpo: Node) -> void:
	if _tomada or not cuerpo.is_in_group("jugador"):
		return
	if cuerpo.has_method("recoger_celda"):
		_tomada = true
		cuerpo.recoger_celda()
		recogida.emit(self)
		set_deferred("monitoring", false)
		var tw := create_tween().set_parallel(true)
		tw.tween_property(self, "scale", Vector2(1.8, 1.8), 0.2)
		tw.tween_property(self, "modulate:a", 0.0, 0.2)
		tw.chain().tween_callback(queue_free)


func activar_deslumbramiento() -> void:
	deslumbre.visible = true
	deslumbre.frame = 0
	deslumbre.play()


func detener_deslumbramiento() -> void:
	deslumbre.stop()
	deslumbre.visible = true
