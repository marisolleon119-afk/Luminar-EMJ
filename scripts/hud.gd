extends CanvasLayer
## HUD de la partida (GDD 5.4). Los nodos están en Escenas/hud.tscn (visibles en el editor);
## este script solo actualiza sus valores. mundo.gd llama a estas funciones.

const Estilo = preload("res://scripts/estilo.gd")
const TEX_CORAZON := preload("res://Recursos/UI/corazon.png")
const TEX_CORAZON_VACIO := preload("res://Recursos/UI/corazon_vacio.png")
const TEX_FAROL_ON := preload("res://Recursos/Mundo/farol_on.png")
const TEX_FAROL_OFF := preload("res://Recursos/Mundo/farol_off.png")

@onready var destello: ColorRect = %Destello
@onready var corazones: HBoxContainer = %Corazones
@onready var barra_energia: ProgressBar = %BarraEnergia
@onready var energia_valor: Label = %EnergiaValor
@onready var lbl_combo: Label = %Combo
@onready var barra_combo: ProgressBar = %BarraCombo
@onready var lbl_ronda: Label = %Ronda
@onready var fila_faroles: HBoxContainer = %FarolesValor.get_parent()
@onready var faroles_valor: Label = %FarolesValor
@onready var lbl_puntos: Label = %Puntos
@onready var lbl_tiempo: Label = %Tiempo
@onready var lbl_aviso: Label = %Aviso
@onready var banner_titulo: Label = %BannerTitulo
@onready var banner_sub: Label = %BannerSub
@onready var resultados: Control = %Resultados

var _iconos_faroles: Array[TextureRect] = []
var _tween_aviso: Tween
var _tweens_banner: Array[Tween] = []
var _energia_baja := false
var _corriendo := false


func _ready() -> void:
	for h in fila_faroles.get_children():
		if h is TextureRect:
			_iconos_faroles.append(h)
	# Los textos de ejemplo que se ven en el editor empiezan ocultos en el juego
	lbl_aviso.modulate.a = 0.0
	banner_titulo.modulate.a = 0.0
	banner_sub.modulate.a = 0.0
	destello.color.a = 0.0
	resultados.visible = false


func actualizar_vidas(actuales: int, maximas: int) -> void:
	while corazones.get_child_count() < maximas:
		var t := TextureRect.new()
		t.custom_minimum_size = Vector2(26, 24)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		corazones.add_child(t)
	for i in corazones.get_child_count():
		var c := corazones.get_child(i) as TextureRect
		c.visible = i < maximas
		c.texture = TEX_CORAZON if i < actuales else TEX_CORAZON_VACIO


func actualizar_energia(energia: float, maxima: float, baja: bool) -> void:
	barra_energia.max_value = maxima
	barra_energia.value = energia
	energia_valor.text = str(int(ceil(energia)))
	_energia_baja = baja
	_color_energia()


## Mientras Chispa corre, la barra de energía se pinta de azul claro.
func actualizar_corriendo(corriendo: bool) -> void:
	_corriendo = corriendo
	_color_energia()


func _color_energia() -> void:
	if _energia_baja:
		barra_energia.modulate = Color(1.0, 0.45, 0.4)
	elif _corriendo:
		barra_energia.modulate = Color(0.55, 0.9, 1.25)
	else:
		barra_energia.modulate = Color.WHITE


## Latido de los corazones al recuperar una vida.
func vida_recuperada() -> void:
	destello.color = Color(1, 0.45, 0.6, 0.18)
	destello.create_tween().tween_property(destello, "color:a", 0.0, 0.4)
	corazones.pivot_offset = corazones.size * 0.5
	var tw := corazones.create_tween()
	tw.tween_property(corazones, "scale", Vector2(1.25, 1.25), 0.1)
	tw.tween_property(corazones, "scale", Vector2.ONE, 0.2)


func actualizar_puntos(puntos: int, animar: bool = false) -> void:
	lbl_puntos.text = Estilo.miles(puntos)
	if animar:
		lbl_puntos.pivot_offset = lbl_puntos.size * 0.5
		var tw := lbl_puntos.create_tween()
		tw.tween_property(lbl_puntos, "scale", Vector2(1.18, 1.18), 0.08)
		tw.tween_property(lbl_puntos, "scale", Vector2.ONE, 0.12)


func actualizar_tiempo(segundos: float, maximo: float) -> void:
	lbl_tiempo.text = "%s / %s" % [Estilo.mmss(int(segundos)), Estilo.mmss(int(maximo))]
	var color := Estilo.ROJO if segundos >= maximo - 60.0 else Estilo.TEXTO
	lbl_tiempo.add_theme_color_override("font_color", color)


func actualizar_combo(combo: int, restante: float, ventana: float) -> void:
	lbl_combo.text = "COMBO x%d" % combo
	lbl_combo.modulate.a = 1.0 if combo > 1 else 0.55
	barra_combo.max_value = ventana
	barra_combo.value = restante
	barra_combo.visible = restante > 0.0


func actualizar_ronda(ronda: int, total: int) -> void:
	lbl_ronda.text = "RONDA %d / %d" % [ronda, total]


func actualizar_faroles(encendidos: int, total: int, animar: bool = false) -> void:
	for i in _iconos_faroles.size():
		_iconos_faroles[i].texture = TEX_FAROL_ON if i < encendidos else TEX_FAROL_OFF
	faroles_valor.text = "%d/%d" % [encendidos, total]
	if animar and encendidos > 0 and encendidos <= _iconos_faroles.size():
		var ic := _iconos_faroles[encendidos - 1]
		ic.pivot_offset = ic.size * 0.5
		var tw := ic.create_tween()
		tw.tween_property(ic, "scale", Vector2(1.5, 1.5), 0.12)
		tw.tween_property(ic, "scale", Vector2.ONE, 0.2)


func aviso(texto: String, color: Color = Estilo.TEXTO, duracion: float = 1.8) -> void:
	lbl_aviso.text = texto
	lbl_aviso.add_theme_color_override("font_color", color)
	if _tween_aviso:
		_tween_aviso.kill()
	_tween_aviso = lbl_aviso.create_tween()
	_tween_aviso.tween_property(lbl_aviso, "modulate:a", 1.0, 0.15)
	_tween_aviso.tween_interval(duracion)
	_tween_aviso.tween_property(lbl_aviso, "modulate:a", 0.0, 0.5)


func banner(titulo: String, sub: String, duracion: float) -> void:
	banner_titulo.text = titulo
	banner_sub.text = sub
	for t in _tweens_banner:
		if t and t.is_valid():
			t.kill()
	_tweens_banner.clear()
	for l in [banner_titulo, banner_sub]:
		var tw: Tween = l.create_tween()
		_tweens_banner.append(tw)
		tw.tween_property(l, "modulate:a", 1.0, 0.25)
		tw.tween_interval(duracion)
		tw.tween_property(l, "modulate:a", 0.0, 0.45)


## Destello rojo y sacudida de corazones al perder una vida.
func golpe() -> void:
	destello.color = Color(1, 0.15, 0.2, 0.35)
	destello.create_tween().tween_property(destello, "color:a", 0.0, 0.45)
	var tw := corazones.create_tween()
	var x0 := corazones.position.x
	for i in 3:
		tw.tween_property(corazones, "position:x", x0 + 6.0, 0.04)
		tw.tween_property(corazones, "position:x", x0 - 6.0, 0.04)
	tw.tween_property(corazones, "position:x", x0, 0.04)


func mostrar_resultados(datos: Dictionary) -> void:
	resultados.mostrar(datos)
