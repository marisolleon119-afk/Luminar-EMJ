extends Control
## Cómic de la historia de Luminar. Se arma por código con las imágenes del juego
## (pueblo, Chispa, Sombras, faroles y celdas): viñetas con recuadros de narración
## y globos de diálogo que aparecen una por una.
##
##   historia = "inicio" -> antes de la primera partida (y desde Instrucciones > Ver historia)
##   historia = "final"  -> al ganar, antes de los resultados
##
## Controles: clic / Enter / Espacio / A del control = siguiente.  Esc / botón "Saltar" = saltar.
## Uso como escena:   Global.ver_comic("inicio", Global.ESCENA_MUNDO)
## Uso como capa:     var c = ESCENA_COMIC.instantiate(); c.historia = "final"; c.terminado.connect(...)

signal terminado

const Estilo = preload("res://scripts/estilo.gd")

const IMG_PUEBLO := "res://Recursos/Portada/Pueblo medieval bajo la luna llena.png"
const IMG_PORTADA := "res://Recursos/Portada/LUMINAR_ La luz del pueblo nocturno.png"
const IMG_CHISPA := "res://Recursos/player chispa/FRENTE.png"
const IMG_SOMBRA := "res://Recursos/sombra/REPOSO.png"
const IMG_FAROL_ON := "res://Recursos/Mundo/farol_on.png"
const IMG_FAROL_OFF := "res://Recursos/Mundo/farol_off.png"
const IMG_ORBE := "res://Recursos/Celdas de energia/Luminar_orbes_sprites_Godot.png"

const R_CHISPA := Rect2(0, 0, 129, 206)
const R_SOMBRA := Rect2(0, 0, 123, 207)
const R_ORBE := Rect2(0, 0, 723, 725)
const R_CASTILLO := Rect2(720, 250, 620, 400)
const R_PORTADA_ABAJO := Rect2(0, 400, 1672, 541)

const OSCURO := Color(0.28, 0.32, 0.55)
const NOCHE := Color(0.16, 0.16, 0.30)
const PAPEL := Color("#F4E9D0")
const ORO := Color("#FFD35A")
const TINTA := Color("#1B1530")

@export_enum("inicio", "final") var historia: String = "inicio"
## Escena a la que ir al terminar (vacío = solo emitir "terminado" y cerrarse)
@export var siguiente_escena: String = ""
## Para el cómic final: puntuación que se muestra en la viñeta "FIN"
var puntos_finales: int = -1

var _paginas: Array = []
var _pagina := -1
var _animando := false
var _tween: Tween
var _hoja: Control
var _lbl_pagina: Label
var _lbl_seguir: Label
var _terminado := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS     # funciona aunque el juego esté en pausa
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if Global.comic_pendiente.size() > 0:     # abierto como escena con Global.ver_comic()
		historia = str(Global.comic_pendiente.get("historia", historia))
		siguiente_escena = str(Global.comic_pendiente.get("destino", siguiente_escena))
		Global.comic_pendiente = {}
	_paginas = _historia_inicio() if historia == "inicio" else _historia_final()
	_armar_interfaz()
	if historia == "inicio":
		Audio.musica("menu")
	_siguiente()


# ---------------------------------------------------------------
# GUION
# ---------------------------------------------------------------
## Cada página es una lista de viñetas. Posiciones de personajes y globos en 0..1 dentro de la viñeta.
func _historia_inicio() -> Array:
	return [
		[   # Página 1: la ciudad se apaga
			{"rect": Rect2(40, 40, 1200, 330), "fondo": IMG_PUEBLO,
			 "texto": "Ciudad Faro siempre brilló de noche. Sus faroles mantenían a salvo cada calle."},
			{"rect": Rect2(40, 390, 590, 290), "fondo": IMG_PUEBLO, "tinte": OSCURO,
			 "sprites": [{"tex": IMG_FAROL_OFF, "pos": Vector2(0.25, 0.92), "alto": 170},
						 {"tex": IMG_FAROL_OFF, "pos": Vector2(0.75, 0.92), "alto": 150}],
			 "texto": "Hasta que una tormenta apagó el Gran Farol... y con él, todos los faroles."},
			{"rect": Rect2(650, 390, 590, 290), "fondo": IMG_PUEBLO, "tinte": NOCHE,
			 "sprites": [{"tex": IMG_SOMBRA, "region": R_SOMBRA, "pos": Vector2(0.22, 0.95), "alto": 150},
						 {"tex": IMG_SOMBRA, "region": R_SOMBRA, "pos": Vector2(0.52, 0.98), "alto": 190},
						 {"tex": IMG_SOMBRA, "region": R_SOMBRA, "pos": Vector2(0.82, 0.95), "alto": 140, "flip": true}],
			 "texto": "De los rincones oscuros salieron las Sombras.",
			 "globo": {"texto": "¡La noche es nuestra!", "pos": Vector2(0.62, 0.32), "de": Vector2(0.52, 0.55)}},
		],
		[   # Página 2: aparece Chispa
			{"rect": Rect2(40, 40, 500, 640), "fondo": IMG_PUEBLO, "tinte": OSCURO, "region": Rect2(0, 120, 560, 821),
			 "luz": {"pos": Vector2(0.5, 0.62), "radio": 260, "color": Color(1, 0.8, 0.4, 0.55)},
			 "sprites": [{"tex": IMG_CHISPA, "region": R_CHISPA, "pos": Vector2(0.5, 0.9), "alto": 330}],
			 "texto": "Pero quedaba una pequeña luz: Chispa, el robot farolero.",
			 "globo": {"texto": "¡Yo volveré a encenderlos!", "pos": Vector2(0.5, 0.26), "de": Vector2(0.5, 0.42)}},
			{"rect": Rect2(560, 40, 680, 310), "fondo": IMG_PUEBLO, "tinte": OSCURO, "region": Rect2(500, 300, 1172, 641),
			 "luz": {"pos": Vector2(0.38, 0.5), "radio": 200, "color": Color(1, 0.75, 0.35, 0.6)},
			 "sprites": [{"tex": IMG_FAROL_ON, "pos": Vector2(0.38, 0.95), "alto": 230},
						 {"tex": IMG_CHISPA, "region": R_CHISPA, "pos": Vector2(0.58, 0.95), "alto": 120},
						 {"tex": IMG_SOMBRA, "region": R_SOMBRA, "pos": Vector2(0.88, 0.95), "alto": 130, "alpha": 0.55, "flip": true}],
			 "texto": "Cada farol encendido crea un refugio de luz. Las Sombras no lo soportan."},
			{"rect": Rect2(560, 370, 680, 310), "fondo": IMG_PUEBLO, "tinte": NOCHE, "region": Rect2(0, 500, 1672, 441),
			 "sprites": [{"tex": IMG_ORBE, "region": R_ORBE, "pos": Vector2(0.18, 0.72), "alto": 70},
						 {"tex": IMG_ORBE, "region": R_ORBE, "pos": Vector2(0.32, 0.86), "alto": 55},
						 {"tex": IMG_CHISPA, "region": R_CHISPA, "pos": Vector2(0.62, 0.97), "alto": 150}],
			 "texto": "Fuera de la luz Chispa gasta energía: debe recoger celdas para no apagarse.",
			 "globo": {"texto": "3 noches, 5 faroles cada una. ¡Vamos!", "pos": Vector2(0.8, 0.42), "de": Vector2(0.66, 0.6)}},
		],
	]


func _historia_final() -> Array:
	var fin_texto := "FIN"
	if puntos_finales >= 0:
		fin_texto = "FIN\n[font_size=26]Puntuación: %s[/font_size]" % Estilo.miles(puntos_finales)
	return [
		[   # Página 1: vuelve la luz
			{"rect": Rect2(40, 40, 1200, 330), "fondo": IMG_PUEBLO,
			 "luz": {"pos": Vector2(0.5, 0.75), "radio": 520, "color": Color(1, 0.85, 0.45, 0.35)},
			 "texto": "Al encenderse el último farol, una ola de luz recorrió todas las calles."},
			{"rect": Rect2(40, 390, 590, 290), "fondo": IMG_PUEBLO, "region": Rect2(200, 300, 1000, 641),
			 "luz": {"pos": Vector2(0.3, 0.6), "radio": 220, "color": Color(1, 0.8, 0.4, 0.55)},
			 "sprites": [{"tex": IMG_FAROL_ON, "pos": Vector2(0.22, 0.95), "alto": 190},
						 {"tex": IMG_SOMBRA, "region": R_SOMBRA, "pos": Vector2(0.62, 0.92), "alto": 160, "alpha": 0.8},
						 {"tex": IMG_SOMBRA, "region": R_SOMBRA, "pos": Vector2(0.86, 0.86), "alto": 115, "alpha": 0.5, "flip": true}],
			 "texto": "Las Sombras se deshicieron como humo al amanecer.",
			 "globo": {"texto": "¡Nooo... demasiada luz!", "pos": Vector2(0.7, 0.36), "de": Vector2(0.62, 0.52)}},
			{"rect": Rect2(650, 390, 590, 290), "fondo": IMG_PUEBLO, "region": R_CASTILLO,
			 "luz": {"pos": Vector2(0.5, 0.35), "radio": 260, "color": Color(1, 0.9, 0.55, 0.5)},
			 "texto": "¡Y el Gran Farol volvió a brillar sobre la colina!"},
		],
		[   # Página 2: final
			{"rect": Rect2(40, 40, 1200, 430), "fondo": IMG_PORTADA, "region": R_PORTADA_ABAJO,
			 "texto": "Ciudad Faro estaba a salvo... gracias a una pequeña chispa.",
			 "globo": {"texto": "¡La luz nunca se apaga!", "pos": Vector2(0.78, 0.2), "de": Vector2(0.58, 0.3)}},
			{"rect": Rect2(40, 490, 1200, 190), "fin": fin_texto},
		],
	]


# ---------------------------------------------------------------
# INTERFAZ
# ---------------------------------------------------------------
func _armar_interfaz() -> void:
	var fondo := ColorRect.new()
	fondo.color = Color("#0A1128")
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fondo)

	_hoja = Control.new()
	_hoja.size = Vector2(1280, 720)
	_hoja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hoja)

	var saltar := Button.new()
	saltar.text = "Saltar  ▸▸"
	saltar.focus_mode = Control.FOCUS_NONE
	saltar.add_theme_font_size_override("font_size", 16)
	saltar.position = Vector2(1140, 6)
	saltar.size = Vector2(130, 30)
	saltar.pressed.connect(_terminar)
	add_child(saltar)

	_lbl_pagina = _label("", 15, Color(PAPEL, 0.7))
	_lbl_pagina.position = Vector2(40, 690)
	_lbl_pagina.size = Vector2(200, 24)
	add_child(_lbl_pagina)

	_lbl_seguir = _label("Clic o Enter para continuar  ▸", 16, ORO)
	_lbl_seguir.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_lbl_seguir.position = Vector2(840, 688)
	_lbl_seguir.size = Vector2(400, 26)
	_lbl_seguir.modulate.a = 0.0
	add_child(_lbl_seguir)
	var tw := _lbl_seguir.create_tween().set_loops()
	tw.tween_property(_lbl_seguir, "self_modulate:a", 0.35, 0.6)
	tw.tween_property(_lbl_seguir, "self_modulate:a", 1.0, 0.6)


func _label(texto: String, tam: int, color: Color) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _tex(ruta: String, region: Rect2 = Rect2()) -> Texture2D:
	var t: Texture2D = load(ruta)
	if region.has_area():
		var a := AtlasTexture.new()
		a.atlas = t
		a.region = region
		return a
	return t


## Construye una viñeta: marco, fondo recortado, luces, personajes, narración y globo.
func _vineta(d: Dictionary) -> Control:
	var r: Rect2 = d.rect
	var marco := Panel.new()
	marco.position = r.position
	marco.size = r.size
	marco.pivot_offset = r.size * 0.5
	var est := StyleBoxFlat.new()
	est.bg_color = Color("#141a33")
	est.border_color = PAPEL
	est.set_border_width_all(4)
	est.set_corner_radius_all(6)
	est.shadow_color = Color(0, 0, 0, 0.5)
	est.shadow_size = 8
	marco.add_theme_stylebox_override("panel", est)
	marco.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var dentro := Control.new()
	dentro.position = Vector2(4, 4)
	dentro.size = r.size - Vector2(8, 8)
	dentro.clip_contents = true
	dentro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marco.add_child(dentro)
	var tam := dentro.size

	if d.has("fondo"):
		var f := TextureRect.new()
		f.texture = _tex(d.fondo, d.get("region", Rect2()))
		f.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		f.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		f.size = tam
		f.modulate = d.get("tinte", Color.WHITE)
		f.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dentro.add_child(f)

	if d.has("luz"):
		var luz: Dictionary = d.luz
		var g := Gradient.new()
		g.set_color(0, luz.color)
		g.set_color(1, Color(luz.color, 0.0))
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(1.0, 0.5)
		var lr := TextureRect.new()
		lr.texture = gt
		lr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		var rad: float = luz.radio
		lr.size = Vector2(rad, rad) * 2.0
		lr.position = Vector2(luz.pos.x * tam.x, luz.pos.y * tam.y) - lr.size * 0.5
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		lr.material = mat
		lr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dentro.add_child(lr)

	for s in d.get("sprites", []):
		var t := _tex(s.tex, s.get("region", Rect2()))
		var sp := TextureRect.new()
		sp.texture = t
		sp.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sp.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		var alto: float = s.alto
		var ancho := alto * float(t.get_width()) / maxf(float(t.get_height()), 1.0)
		sp.size = Vector2(ancho, alto)
		sp.position = Vector2(s.pos.x * tam.x - ancho * 0.5, s.pos.y * tam.y - alto)   # pos = pies
		sp.flip_h = s.get("flip", false)
		sp.modulate.a = s.get("alpha", 1.0)
		sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dentro.add_child(sp)

	if d.has("fin"):
		var fin := RichTextLabel.new()
		fin.bbcode_enabled = true
		fin.fit_content = true
		fin.scroll_active = false
		fin.text = "[center]" + str(d.fin) + "[/center]"
		fin.add_theme_font_size_override("normal_font_size", 64)
		fin.add_theme_color_override("default_color", ORO)
		fin.add_theme_color_override("font_outline_color", TINTA)
		fin.add_theme_constant_override("outline_size", 10)
		fin.size = Vector2(tam.x, tam.y)
		fin.position = Vector2(0, tam.y * 0.12)
		fin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dentro.add_child(fin)

	if d.has("texto"):
		dentro.add_child(_narracion(str(d.texto), tam.x))
	if d.has("globo"):
		dentro.add_child(_globo(d.globo, tam))
	return marco


## Recuadro amarillo de narración (arriba a la izquierda).
func _narracion(texto: String, ancho_vineta: float) -> Control:
	var caja := PanelContainer.new()
	var est := StyleBoxFlat.new()
	est.bg_color = ORO
	est.border_color = TINTA
	est.set_border_width_all(3)
	est.set_corner_radius_all(3)
	est.content_margin_left = 12
	est.content_margin_right = 12
	est.content_margin_top = 6
	est.content_margin_bottom = 6
	caja.add_theme_stylebox_override("panel", est)
	caja.position = Vector2(10, 10)
	caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := _label(texto, 18, TINTA)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = minf(ancho_vineta - 40.0, maxf(220.0, texto.length() * 9.5))
	caja.add_child(l)
	return caja


## Globo de diálogo blanco con colita hacia quien habla.
func _globo(g: Dictionary, tam: Vector2) -> Control:
	var raiz := Control.new()
	raiz.size = tam
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var centro := Vector2(g.pos.x * tam.x, g.pos.y * tam.y)
	var hacia := Vector2(g.de.x * tam.x, g.de.y * tam.y)

	var cola := Polygon2D.new()
	var lado := (hacia - centro).orthogonal().normalized() * 12.0
	cola.polygon = PackedVector2Array([centro + lado, centro - lado, hacia])
	cola.color = Color.WHITE
	var borde := Line2D.new()
	borde.points = PackedVector2Array([centro + lado, hacia, centro - lado])
	borde.width = 3.0
	borde.default_color = TINTA
	raiz.add_child(borde)
	raiz.add_child(cola)

	var caja := PanelContainer.new()
	var est := StyleBoxFlat.new()
	est.bg_color = Color.WHITE
	est.border_color = TINTA
	est.set_border_width_all(3)
	est.set_corner_radius_all(22)
	est.content_margin_left = 16
	est.content_margin_right = 16
	est.content_margin_top = 8
	est.content_margin_bottom = 8
	caja.add_theme_stylebox_override("panel", est)
	caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := _label(str(g.texto), 19, TINTA)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caja.add_child(l)
	raiz.add_child(caja)
	# centrar el globo en su punto cuando ya tiene tamaño
	caja.resized.connect(func():
		var p := centro - caja.size * 0.5
		p.x = clampf(p.x, 6.0, tam.x - caja.size.x - 6.0)
		p.y = clampf(p.y, 6.0, tam.y - caja.size.y - 6.0)
		caja.position = p)
	return raiz


# ---------------------------------------------------------------
# AVANCE
# ---------------------------------------------------------------
func _siguiente() -> void:
	if _terminado:
		return
	if _animando:
		_completar_animacion()
		return
	_pagina += 1
	if _pagina >= _paginas.size():
		_terminar()
		return
	if _pagina > 0:
		Audio.sfx_ui("ui_click")
	for c in _hoja.get_children():
		c.queue_free()
	_lbl_pagina.text = "%d / %d" % [_pagina + 1, _paginas.size()]
	_lbl_seguir.text = "Clic o Enter para continuar  ▸" if _pagina < _paginas.size() - 1 else ("Clic o Enter para jugar  ▸" if historia == "inicio" else "Clic o Enter para ver tus resultados  ▸")
	_lbl_seguir.modulate.a = 0.0

	_animando = true
	_tween = create_tween()
	for d in _paginas[_pagina]:
		var v := _vineta(d)
		v.modulate.a = 0.0
		v.scale = Vector2(0.94, 0.94)
		_hoja.add_child(v)
		_tween.tween_property(v, "modulate:a", 1.0, 0.35)
		_tween.parallel().tween_property(v, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_tween.tween_interval(0.9)
	_tween.tween_property(_lbl_seguir, "modulate:a", 1.0, 0.3)
	_tween.tween_callback(func(): _animando = false)


func _completar_animacion() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	for v in _hoja.get_children():
		v.modulate.a = 1.0
		v.scale = Vector2.ONE
	_lbl_seguir.modulate.a = 1.0
	_animando = false


func _terminar() -> void:
	if _terminado:
		return
	_terminado = true
	if _tween and _tween.is_valid():
		_tween.kill()
	terminado.emit()
	if siguiente_escena != "":
		Global.ir_a(siguiente_escena)
	else:
		queue_free()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		_siguiente()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_terminar()
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("encender_farol"):
		get_viewport().set_input_as_handled()
		_siguiente()
