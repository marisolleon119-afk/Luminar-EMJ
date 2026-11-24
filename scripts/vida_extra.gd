class_name VidaExtra
extends Area2D
## Corazón que aparece en el mapa cuando a Chispa le falta alguna vida.
## Al tocarlo, Chispa recupera 1 vida (chispa.recuperar_vida()). Si nadie lo recoge,
## parpadea y se apaga después de `duracion` segundos.
## Se construye por código (no necesita escena): mundo.gd hace VidaExtra.new().

signal recogida(vida: VidaExtra)
signal expirada(vida: VidaExtra)

const TEX_CORAZON := preload("res://Recursos/UI/corazon.png")

@export var duracion: float = 12.0
@export var aviso_final: float = 3.5     # segundos finales en los que parpadea

var _t := 0.0
var _vida := 0.0
var _tomada := false
var _sprite: Sprite2D
var _luz: PointLight2D


func _ready() -> void:
	add_to_group("vidas_extra")
	collision_layer = 0
	collision_mask = 2          # solo detecta a Chispa (capa 2)
	z_index = 5

	var forma := CollisionShape2D.new()
	var circulo := CircleShape2D.new()
	circulo.radius = 16.0
	forma.shape = circulo
	add_child(forma)

	_sprite = Sprite2D.new()
	_sprite.texture = TEX_CORAZON
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var lado := float(maxi(TEX_CORAZON.get_width(), TEX_CORAZON.get_height()))
	var s := 30.0 / maxf(lado, 1.0)
	_sprite.scale = Vector2(s, s)
	add_child(_sprite)

	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	grad.colors = PackedColorArray([Color(1, 1, 1, 1), Color(0.35, 0.35, 0.35, 1), Color(0, 0, 0, 1)])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = 256
	tex.height = 256
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	_luz = PointLight2D.new()
	_luz.texture = tex
	_luz.color = Color(1.0, 0.35, 0.45)
	_luz.energy = 0.9
	_luz.texture_scale = 0.35
	add_child(_luz)

	body_entered.connect(_on_body_entered)

	# Aparición suave
	scale = Vector2(0.2, 0.2)
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	if _tomada:
		return
	_t += delta * 3.0
	_vida += delta
	# Latido
	var latido := 1.0 + sin(_t * 2.0) * 0.08
	_sprite.scale = Vector2.ONE * (30.0 / maxf(float(maxi(TEX_CORAZON.get_width(), TEX_CORAZON.get_height())), 1.0)) * latido
	_sprite.position.y = sin(_t) * 3.0
	_luz.energy = 0.8 + sin(_t * 1.7) * 0.2

	var restante := duracion - _vida
	if restante <= aviso_final:
		# Parpadeo cada vez más rápido antes de apagarse
		var ritmo := lerpf(4.0, 14.0, 1.0 - restante / aviso_final)
		_sprite.modulate.a = 0.35 + 0.65 * absf(sin(_vida * ritmo))
	if restante <= 0.0:
		_tomada = true
		set_deferred("monitoring", false)
		expirada.emit(self)
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.3)
		tw.tween_callback(queue_free)


func _on_body_entered(cuerpo: Node) -> void:
	if _tomada or not cuerpo.is_in_group("jugador") or not cuerpo.has_method("recuperar_vida"):
		return
	if not cuerpo.recuperar_vida(1):
		return            # ya tiene todas las vidas: el corazón se queda
	_tomada = true
	recogida.emit(self)
	set_deferred("monitoring", false)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "scale", Vector2(2.0, 2.0), 0.25)
	tw.tween_property(self, "modulate:a", 0.0, 0.25)
	tw.chain().tween_callback(queue_free)
