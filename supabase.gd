extends Node
## Cliente mínimo de Supabase (REST / PostgREST).

var url := ""
var key := ""


## false si falta config.cfg o le faltan datos: el juego lo dice claramente (no "Sin conexión")
var configurada := false


func _ready() -> void:
	# Las peticiones deben seguir aunque el juego esté en pausa (pantalla de fin de partida)
	process_mode = Node.PROCESS_MODE_ALWAYS
	var cfg := ConfigFile.new()
	if cfg.load("res://config.cfg") != OK:
		push_error("Supabase: no se encontró config.cfg")
		return
	url = str(cfg.get_value("nube", "url", "")).strip_edges().rstrip("/")
	key = str(cfg.get_value("nube", "api_key", "")).strip_edges()
	if url == "" or key == "":
		push_error("Supabase: faltan url o api_key en config.cfg")
	else:
		configurada = true


func _headers(extra: Array = []) -> PackedStringArray:
	var h: Array = ["apikey: " + key, "Content-Type: application/json"]
	# Las claves nuevas (sb_publishable_...) NO son JWT: no deben ir como Bearer
	if not key.begins_with("sb_"):
		h.append("Authorization: Bearer " + key)
	h.append_array(extra)
	return PackedStringArray(h)


## El JSON devuelve los números como float (12 -> 12.0). Los ids se normalizan a texto limpio.
func id_a_texto(valor) -> String:
	if valor is float and valor == floorf(valor):
		return str(int(valor))
	return str(valor)


## Para enviar un id: entero si lo parece, texto si no (uuid).
func id_valor(id: String):
	return int(id) if id.is_valid_int() else id


func _request(method: int, path: String, body = null, extra: Array = []) -> Dictionary:
	if url == "" or key == "":
		return {"ok": false, "code": 0, "data": null, "error": "config incompleta"}
	var http := HTTPRequest.new()
	http.timeout = 8.0
	add_child(http)
	var payload := "" if body == null else JSON.stringify(body)
	var err := http.request(url + "/rest/v1/" + path, _headers(extra), method, payload)
	if err != OK:
		http.queue_free()
		push_warning("Supabase: no se pudo lanzar la petición (error %d)" % err)
		return {"ok": false, "code": 0, "data": null, "error": "request error %d" % err}
	var r = await http.request_completed
	http.queue_free()
	var text: String = r[3].get_string_from_utf8()
	var data = null
	if text.strip_edges() != "":
		var json := JSON.new()
		if json.parse(text) == OK:
			data = json.data
		else:
			push_warning("Supabase: la respuesta no es JSON: %s" % text.left(300))
	var ok: bool = r[0] == HTTPRequest.RESULT_SUCCESS and r[1] >= 200 and r[1] < 300
	if not ok:
		push_warning("Supabase %s -> resultado %d, HTTP %d: %s" % [path.get_slice("?", 0), r[0], r[1], text.left(300)])
	return {"ok": ok, "code": r[1], "data": data, "error": text}


# RF-01 (v2): entrar o registrarse con alias + PIN.
# La función acceder_jugador del servidor valida el alias, el PIN y bloquea tras 5 intentos.
# Devuelve {ok, id_jugador, alias, token, nuevo} o {ok:false, error}.
func acceder_jugador(alias: String, pin: String) -> Dictionary:
	var r = await _request(HTTPClient.METHOD_POST, "rpc/acceder_jugador", {"p_alias": alias, "p_pin": pin})
	return _resultado_rpc(r)


# RF-03 y RF-04 (v2): guardar la partida con la sesión del dispositivo.
func guardar_partida(token: String, datos: Dictionary) -> Dictionary:
	var r = await _request(HTTPClient.METHOD_POST, "rpc/guardar_partida", {
		"p_token": token,
		"p_puntuacion": int(datos.get("puntos", 0)), "p_nivel": int(datos.get("nivel", 1)),
		"p_celdas": int(datos.get("celdas", 0)), "p_faroles": int(datos.get("faroles", 0)),
		"p_combo": int(datos.get("combo", 1)), "p_tiempo": int(datos.get("tiempo", 0)),
	})
	return _resultado_rpc(r)


func _resultado_rpc(r: Dictionary) -> Dictionary:
	if r.code == 0:
		return {"ok": false, "error": "SIN_CONEXION", "code": 0}
	if r.code == 404:
		# Las funciones no existen: falta ejecutar luminar_supabase_v2.sql
		return {"ok": false, "error": "BD_DESACTUALIZADA", "code": 404}
	if r.ok and r.data is Dictionary:
		var d: Dictionary = r.data
		if d.has("id_jugador"):
			d["id_jugador"] = id_a_texto(d["id_jugador"])
		d["code"] = r.code
		return d
	return {"ok": false, "error": "ERROR_SERVIDOR", "code": r.code}


# RF-05: las 10 mejores
func obtener_top10() -> Dictionary:
	return await _request(HTTPClient.METHOD_GET,
		"partidas?select=puntuacion,nivel_alcanzado,fecha_partida,jugadores(alias)&order=puntuacion.desc&limit=10")
