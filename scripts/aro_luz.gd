extends Node2D
## Anillo tenue en el suelo que marca la zona segura de un farol encendido.

var radio: float = 128.0:
	set(v):
		radio = v
		queue_redraw()


func _draw() -> void:
	# Elipse achatada para dar sensación de perspectiva cenital
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.82))
	draw_arc(Vector2.ZERO, radio, 0.0, TAU, 72, Color(1.0, 0.82, 0.4, 0.22), 2.0, true)
	draw_arc(Vector2.ZERO, radio - 5.0, 0.0, TAU, 72, Color(1.0, 0.82, 0.4, 0.08), 6.0, true)
