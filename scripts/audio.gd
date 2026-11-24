extends Node
## Gestor de sonido y música de Luminar (GDD sección 6). Autoload "Audio".
##
##  6.1 Música: "menu" (inicio, instrucciones, ranking, créditos, ajustes), "juego" (partida)
##      y los temas cortos "victoria" / "derrota" en la pantalla de resultados.
##  6.2 Efectos: Audio.sfx("celda"), Audio.sfx("farol"), etc. Los botones suenan solos.
##  6.3 Volumen: la música va al bus "Musica" y los efectos al bus "Efectos" (los crea Global);
##      Ajustes controla volumen general, música, efectos y silencio. M silencia.
##  6.4 Todo el audio es original del equipo (ver Recursos/Audio/LEEME.txt y Créditos).
##
## Pausa (GDD 2.7): los efectos del juego se congelan con el árbol; la música baja de volumen.

const RUTA_MUSICA := "res://Recursos/Audio/musica/%s.ogg"
const RUTA_EFECTO := "res://Recursos/Audio/efectos/%s.wav"

const MUSICAS := ["menu", "juego", "victoria", "derrota"]
const EFECTOS := [
	"celda", "farol", "golpe", "sombra_disipa", "energia_baja", "error", "ronda",
	"ui_click", "ui_hover", "pausa", "cuenta", "cuenta_ya", "confirmar",
]
# Ajuste fino de volumen por efecto (dB) para que todos suenen parejos
const VOLUMEN_EFECTO := {
	"ui_hover": -8.0, "ui_click": -4.0, "celda": -3.0, "energia_baja": -4.0, "error": -5.0,
}
const VOLUMEN_MUSICA_DB := -4.0
const ATENUACION_PAUSA_DB := -12.0
const VOCES := 10

var _musica: Dictionary = {}
var _efectos: Dictionary = {}
var _reproductor_a: AudioStreamPlayer
var _reproductor_b: AudioStreamPlayer
var _actual: AudioStreamPlayer
var _nombre_actual := ""
var _voces_juego: Array[AudioStreamPlayer] = []   # se pausan con el juego
var _voces_ui: Array[AudioStreamPlayer] = []      # suenan siempre (menús, pausa)
var _siguiente_juego := 0
var _siguiente_ui := 0
var _atenuada := false
var _tween_musica: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for nombre in MUSICAS:
		var s = _cargar(RUTA_MUSICA % nombre)
		if s:
			if s is AudioStreamOggVorbis:
				(s as AudioStreamOggVorbis).loop = nombre in ["menu", "juego"]
			_musica[nombre] = s
	for nombre in EFECTOS:
		var s = _cargar(RUTA_EFECTO % nombre)
		if s:
			if s is AudioStreamWAV:
				(s as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_DISABLED
			_efectos[nombre] = s

	_reproductor_a = _nuevo_reproductor("Musica", Node.PROCESS_MODE_ALWAYS)
	_reproductor_b = _nuevo_reproductor("Musica", Node.PROCESS_MODE_ALWAYS)
	for i in VOCES:
		_voces_juego.append(_nuevo_reproductor("Efectos", Node.PROCESS_MODE_PAUSABLE))
	for i in 4:
		_voces_ui.append(_nuevo_reproductor("Efectos", Node.PROCESS_MODE_ALWAYS))

	# Sonido automático en todos los botones de todas las pantallas
	get_tree().node_added.connect(_on_nodo_agregado)


func _cargar(ruta: String) -> AudioStream:
	if not ResourceLoader.exists(ruta):
		push_warning("Audio: no se encontró " + ruta)
		return null
	return load(ruta) as AudioStream


func _nuevo_reproductor(bus: String, modo: int) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus if AudioServer.get_bus_index(bus) != -1 else "Master"
	p.process_mode = modo
	add_child(p)
	return p


# ---------------------------------------------------------------
# MÚSICA (6.1)
# ---------------------------------------------------------------
## Cambia de pista con un fundido cruzado. Si ya suena la misma, no la reinicia.
func musica(nombre: String, fundido: float = 0.8) -> void:
	if nombre == _nombre_actual and _actual and _actual.playing:
		return
	var stream: AudioStream = _musica.get(nombre)
	if stream == null:
		return
	_nombre_actual = nombre
	_atenuada = false
	var anterior := _actual
	_actual = _reproductor_b if _actual == _reproductor_a else _reproductor_a
	_actual.bus = _bus("Musica")
	_actual.stream = stream
	_actual.pitch_scale = 1.0
	_actual.volume_db = -40.0 if fundido > 0.0 else VOLUMEN_MUSICA_DB
	_actual.play()

	if _tween_musica:
		_tween_musica.kill()
	_tween_musica = create_tween().set_parallel(true)
	_tween_musica.tween_property(_actual, "volume_db", VOLUMEN_MUSICA_DB, maxf(fundido, 0.01))
	if anterior and anterior.playing:
		_tween_musica.tween_property(anterior, "volume_db", -40.0, maxf(fundido, 0.01))
		_tween_musica.chain().tween_callback(anterior.stop)


## Tema corto (victoria/derrota) y después, opcionalmente, vuelve a otra pista.
func tema_y_despues(nombre: String, despues: String = "menu") -> void:
	musica(nombre, 0.15)
	var reproductor := _actual
	if reproductor == null or reproductor.stream == null:
		return
	await reproductor.finished
	if _nombre_actual == nombre and despues != "":
		musica(despues, 1.5)


func detener_musica(fundido: float = 0.6) -> void:
	_nombre_actual = ""
	if _actual and _actual.playing:
		var tw := create_tween()
		tw.tween_property(_actual, "volume_db", -40.0, fundido)
		tw.tween_callback(_actual.stop)


## Durante la partida la música acelera un poco en cada ronda (más tensión).
func ritmo_musica(escala: float) -> void:
	if _actual:
		create_tween().tween_property(_actual, "pitch_scale", escala, 1.0)


## Al pausar la música no se detiene: baja de volumen.
func atenuar_musica(activa: bool) -> void:
	if _actual == null or activa == _atenuada:
		return
	_atenuada = activa
	var destino := VOLUMEN_MUSICA_DB + (ATENUACION_PAUSA_DB if activa else 0.0)
	create_tween().tween_property(_actual, "volume_db", destino, 0.3)


# ---------------------------------------------------------------
# EFECTOS (6.2)
# ---------------------------------------------------------------
## Efecto del juego: se congela si el juego está en pausa.
func sfx(nombre: String, tono: float = 1.0, vol_db: float = 0.0) -> void:
	_tocar(nombre, tono, vol_db, _voces_juego, false)


## Efecto de interfaz: suena aunque el juego esté en pausa (menús, cuenta regresiva).
func sfx_ui(nombre: String, tono: float = 1.0, vol_db: float = 0.0) -> void:
	_tocar(nombre, tono, vol_db, _voces_ui, true)


func _tocar(nombre: String, tono: float, vol_db: float, voces: Array[AudioStreamPlayer], es_ui: bool) -> void:
	var stream: AudioStream = _efectos.get(nombre)
	if stream == null or voces.is_empty():
		return
	var i := _siguiente_ui if es_ui else _siguiente_juego
	var p := voces[i % voces.size()]
	if es_ui:
		_siguiente_ui = (i + 1) % voces.size()
	else:
		_siguiente_juego = (i + 1) % voces.size()
	p.bus = _bus("Efectos")
	p.stream = stream
	p.pitch_scale = tono
	p.volume_db = vol_db + float(VOLUMEN_EFECTO.get(nombre, 0.0))
	p.play()


func _bus(nombre: String) -> String:
	return nombre if AudioServer.get_bus_index(nombre) != -1 else "Master"


# ---------------------------------------------------------------
# BOTONES: clic y paso del ratón en todas las pantallas
# ---------------------------------------------------------------
func _on_nodo_agregado(nodo: Node) -> void:
	if nodo is BaseButton and not nodo.has_meta("sin_sonido"):
		var b := nodo as BaseButton
		b.pressed.connect(sfx_ui.bind("ui_click"))
		b.mouse_entered.connect(_on_hover.bind(b))


func _on_hover(b: BaseButton) -> void:
	if is_instance_valid(b) and not b.disabled:
		sfx_ui("ui_hover")
