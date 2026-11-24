extends RefCounted
## Paleta y piezas de interfaz compartidas por las pantallas de Luminar (GDD 5.2).
## Uso: const Estilo = preload("res://scripts/estilo.gd")

const ORO     := Color("#FFD35A")
const DORADO  := Color("#FFC83D")
const PLATA   := Color("#D9DEE8")
const BRONCE  := Color("#E0A060")
const TEXTO   := Color("#F3E9D2")
const PANEL   := Color("#0D1633")
const BORDE   := Color("#3A5BA8")
const BTN     := Color("#0F1B3D")
const HOVER   := Color("#16285A")
const OSCURO  := Color("#2A1A00")
const FONDO   := Color("#0A1128")
const MAGENTA := Color("#E04DD8")
const ROJO    := Color("#FF7A7A")
const VERDE   := Color("#7BE0A0")

const FUENTE_NORMAL := "res://Recursos/fuentes/Poppins-Regular.ttf"
const FUENTE_BOLD   := "res://Recursos/fuentes/Poppins-Bold.ttf"
const IMG_FONDO     := "res://Recursos/Portada/LUMINAR_ La luz del pueblo nocturno.png"


static func fuente(bold: bool = false) -> Font:
	var ruta := FUENTE_BOLD if bold else FUENTE_NORMAL
	if ResourceLoader.exists(ruta):
		return load(ruta)
	return null


static func caja(bg: Color, borde: Color, ancho: int = 2, radio: int = 14, margen: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = borde
	s.set_border_width_all(ancho)
	s.set_corner_radius_all(radio)
	if margen > 0:
		s.set_content_margin_all(margen)
	return s


static func label(texto: String, tam: int, color: Color = TEXTO, alin := HORIZONTAL_ALIGNMENT_LEFT, bold: bool = false) -> Label:
	var l := Label.new()
	l.text = texto
	l.horizontal_alignment = alin
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", color)
	var f := fuente(bold)
	if f:
		l.add_theme_font_override("font", f)
	return l


## Texto con contorno oscuro, para que se lea sobre el mapa nocturno (GDD 5.2: legibilidad).
static func label_hud(texto: String, tam: int, color: Color = TEXTO, alin := HORIZONTAL_ALIGNMENT_LEFT, bold: bool = true) -> Label:
	var l := label(texto, tam, color, alin, bold)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.92))
	l.add_theme_constant_override("outline_size", maxi(4, tam / 5))
	return l


static func parrafo(texto: String, tam: int = 18, color: Color = TEXTO, ancho: float = 560.0) -> Label:
	var l := label(texto, tam, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = ancho
	return l


static func boton(texto: String, principal: bool = false, tam: int = 22, alto: float = 50.0) -> Button:
	var b := Button.new()
	b.text = texto
	b.custom_minimum_size = Vector2(0, alto)
	b.add_theme_font_size_override("font_size", tam)
	var f := fuente(true)
	if f:
		b.add_theme_font_override("font", f)
	if principal:
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(c, OSCURO)
		b.add_theme_stylebox_override("normal",  caja(DORADO, DORADO))
		b.add_theme_stylebox_override("hover",   caja(Color("#FFD866"), Color("#FFD866")))
		b.add_theme_stylebox_override("pressed", caja(Color("#E6AE22"), Color("#E6AE22")))
		b.add_theme_stylebox_override("focus",   caja(DORADO, Color.WHITE, 3))
	else:
		b.add_theme_color_override("font_color", TEXTO)
		b.add_theme_color_override("font_hover_color", Color.WHITE)
		b.add_theme_color_override("font_focus_color", TEXTO)
		b.add_theme_color_override("font_pressed_color", ORO)
		b.add_theme_stylebox_override("normal",  caja(BTN, BORDE))
		b.add_theme_stylebox_override("hover",   caja(HOVER, ORO))
		b.add_theme_stylebox_override("pressed", caja(Color("#0A1230"), DORADO))
		b.add_theme_stylebox_override("focus",   caja(BTN, ORO, 3))
	return b


## Fondo de pantalla: ilustración nocturna con un velo oscuro encima para que el texto se lea.
static func fondo_con_velo(padre: Control, opacidad: float = 0.55) -> void:
	if ResourceLoader.exists(IMG_FONDO):
		var tr := TextureRect.new()
		tr.texture = load(IMG_FONDO)
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		padre.add_child(tr)
	var velo := ColorRect.new()
	velo.color = Color(FONDO, opacidad)
	velo.set_anchors_preset(Control.PRESET_FULL_RECT)
	velo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	padre.add_child(velo)


## Panel oscuro con borde azul (GDD 5.2: "paneles oscuros con bordes azules").
static func panel(padre: Node, ancho_min: float = 0.0, margen: int = 28) -> VBoxContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(ancho_min, 0)
	p.add_theme_stylebox_override("panel", caja(PANEL, BORDE, 2, 14))
	padre.add_child(p)
	var m := MarginContainer.new()
	for lado in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		m.add_theme_constant_override(lado, margen)
	p.add_child(m)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	m.add_child(col)
	return col


static func mmss(segundos: int) -> String:
	segundos = maxi(segundos, 0)
	return "%02d:%02d" % [segundos / 60, segundos % 60]


static func miles(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	for i in s.length():
		if i > 0 and (s.length() - i) % 3 == 0:
			out += ","
		out += s[i]
	return ("-" if n < 0 else "") + out


static func nombre_tecla(k: int) -> String:
	if k == 0:
		return ""
	var nombre := OS.get_keycode_string(DisplayServer.keyboard_get_keycode_from_physical(k as Key))
	if nombre == "":
		nombre = OS.get_keycode_string(k as Key)
	match nombre:
		"Space": return "Espacio"
		"Escape": return "Esc"
		"Left": return "Flecha izq."
		"Right": return "Flecha der."
		"Up": return "Flecha arr."
		"Down": return "Flecha abj."
	return nombre if nombre != "" else str(k)
