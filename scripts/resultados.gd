extends Control
## Pantalla de resultados (GDD 5.3). Los nodos están en Escenas/resultados.tscn.
## mundo.gd llama a mostrar() con los datos de la partida.

const Estilo = preload("res://scripts/estilo.gd")

@onready var titulo: Label = %Titulo
@onready var sub: Label = %Sub
@onready var total: Label = %Total
@onready var tabla: GridContainer = %Tabla
@onready var estado_nube: Label = %EstadoNube
@onready var btn_jugar: Button = %BtnJugar


func _ready() -> void:
	btn_jugar.pressed.connect(func(): Global.ir_a(Global.ESCENA_MUNDO))
	%BtnRanking.pressed.connect(func(): Global.ir_a(Global.ESCENA_RANKING))
	%BtnMenu.pressed.connect(func(): Global.ir_a(Global.ESCENA_PORTADA))


## datos: victoria, motivo, ronda, puntos, desglose, celdas, riesgo, faroles, rondas, rondas_totales, tiempo, combo_max
func mostrar(d: Dictionary) -> void:
	var victoria: bool = d.get("victoria", false)
	match String(d.get("motivo", "")):
		"vidas":
			titulo.text = "Las Sombras ganaron"
			sub.text = "Chispa se quedó sin vidas en la Ronda %d." % int(d.get("ronda", 1))
		"tiempo":
			titulo.text = "Se acabó el tiempo"
			sub.text = "Pasaron 6 minutos sin completar la Ronda 3."
		_:
			titulo.text = "¡Ciudad Faro vuelve a brillar!"
			sub.text = "Gracias a Chispa, la luz regresó a cada calle."
	titulo.add_theme_color_override("font_color", Estilo.ORO if victoria else Estilo.TEXTO)
	total.text = Estilo.miles(int(d.get("puntos", 0)))

	var des: Dictionary = d.get("desglose", {})
	_fila("Celdas", str(d.get("celdas", 0)), des.get("celdas", 0))
	_fila("Riesgo", "%d fuera de la luz" % int(d.get("riesgo", 0)), des.get("riesgo", 0))
	_fila("Faroles", str(d.get("faroles", 0)), des.get("faroles", 0))
	_fila("Rondas", "%d / %d" % [int(d.get("rondas", 0)), int(d.get("rondas_totales", 3))], des.get("rondas", 0))
	_fila("Tiempo", Estilo.mmss(int(d.get("tiempo", 0))), des.get("tiempo", 0))
	_fila("Victoria", "Sí" if victoria else "No", des.get("victoria", 0))
	_fila("Combo", "x%d" % int(d.get("combo_max", 1)), -1)

	estado_nube.text = "Guardando puntuación en la nube..."
	estado_nube.add_theme_color_override("font_color", Color(Estilo.TEXTO, 0.7))
	if not Global.puntaje_enviado.is_connected(_on_puntaje_enviado):
		Global.puntaje_enviado.connect(_on_puntaje_enviado, CONNECT_ONE_SHOT)

	visible = true
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.35)
	btn_jugar.grab_focus()


func _fila(clave: String, detalle: String, puntos) -> void:
	tabla.get_node(clave + "D").text = detalle
	var p := int(puntos)
	tabla.get_node(clave + "P").text = "" if p < 0 else "+" + Estilo.miles(p)


func _on_puntaje_enviado(ok: bool, mensaje: String) -> void:
	_mostrar_record()
	estado_nube.text = mensaje
	estado_nube.add_theme_color_override("font_color", Estilo.VERDE if ok else Color("#FFB37A"))


## MEJORA: récord personal ("¡Nuevo récord!" o cuánto faltó).
var _lbl_record: Label

func _mostrar_record() -> void:
	if _lbl_record == null:
		_lbl_record = Label.new()
		_lbl_record.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_lbl_record.add_theme_font_size_override("font_size", 20)
		_lbl_record.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		_lbl_record.add_theme_constant_override("outline_size", 4)
		var padre := total.get_parent()
		padre.add_child(_lbl_record)
		padre.move_child(_lbl_record, total.get_index() + 1)
	if Global.ultimo_es_record:
		_lbl_record.text = "★ ¡Nuevo récord personal! ★" if Global.record_anterior > 0 else "★ ¡Primer récord personal! ★"
		_lbl_record.add_theme_color_override("font_color", Estilo.ORO)
		_lbl_record.pivot_offset = Vector2(_lbl_record.size.x * 0.5, 12)
		var tw := _lbl_record.create_tween().set_loops(3)
		tw.tween_property(_lbl_record, "scale", Vector2(1.12, 1.12), 0.25)
		tw.tween_property(_lbl_record, "scale", Vector2.ONE, 0.25)
	else:
		var rec := Global.record_de(Global.alias)
		_lbl_record.text = "Tu récord: %s  (te faltaron %s)" % [Estilo.miles(rec), Estilo.miles(maxi(rec - Global.ultimo_puntaje, 0))]
		_lbl_record.add_theme_color_override("font_color", Color(Estilo.TEXTO, 0.75))
