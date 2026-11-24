# Registro de cambios — Luminar

Formato basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/).
Cada versión indica la fecha, qué se agregó, qué cambió y qué se corrigió.
Las solicitudes de cambio se identifican como SC-xx y los defectos como D-xx (ver GDD, sección 10).

## [1.0.0] — 2026-11-22 · Entrega final
### Cambiado
- Si falta `config.cfg`, el juego muestra "Nube sin configurar (falta config.cfg)" en lugar de un falso
  "Sin conexión" (D-17). Prueba de regresión PU-23.
- Nombre de la aplicación "Luminar", versión 1.0.0 visible en la pantalla de acceso.
- Perfil de exportación listo: incluye `config.cfg`, excluye pruebas y documentación, datos del ejecutable.
- La pantalla **¿Quién juega?** aparece siempre al abrir el juego. Si el equipo tiene una sesión guardada
  ofrece **Continuar como [alias]** o **Entrar con otro jugador**: el juego nunca entra solo con el usuario
  de otra persona al compartir la computadora o el ejecutable.
- **Más espacio en el mapa:** faroles, celdas y corazones se colocan lejos del dibujo completo de los obstáculos
  (no solo de su colisión). Faroles encimados en objetos: de 61 % a 0 %; celdas encimadas: de 9.5 % a 0 %.
  Los lugares de los faroles se eligen de una cuadrícula de puntos libres.
### Corregido
- D-15: faroles y celdas aparecían encimados sobre arbustos, bancas o la fuente.
- D-17: con `config.cfg` ausente (p. ej. al clonar el repositorio) el juego decía "Sin conexión" teniendo internet.
- D-16 (regresión detectada por PF-08): con los márgenes nuevos, a veces los faroles repetían lugar en la
  ronda siguiente. Ahora se prioriza no repetir lugar en todos los intentos.
### Agregado
- README completo, CHANGELOG, `.gitignore` de Godot, guía de flujo de trabajo (`docs/FLUJO_DE_TRABAJO.md`),
  plantillas de issues y pull requests, script `herramientas/limpiar_datos_prueba.sql`.
- Diagramas actualizados en `docs/` (casos de uso, componentes, entidad-relación).

## [0.7.0] — 2026-11-13 · Historia en cómic (SC-04)
### Agregado
- Cómic de inicio (2 páginas) antes de la primera partida y cómic final (2 páginas) al ganar.
- Botón **Ver historia** en Instrucciones.
- Pruebas PF-13, PF-14 y PF-15.
### Corregido
- D-14: la prueba del cómic seguía avanzando después de cerrarlo.

## [0.6.0] — 2026-11-10 · Pantalla de acceso (SC-03)
### Agregado
- Escena inicial `acceso.tscn` (alias + PIN). Sin jugador válido no se entra al menú ni al juego.
- Botón **Cambiar jugador** en el menú. Modo local sin conexión con alias válido.
- Pruebas PU-19 a PU-22, PF-00 y PF-00b.
### Corregido
- D-12: se podía entrar al menú sin un jugador válido.

## [0.5.0] — 2026-11-10 · Alias protegidos con PIN y mejoras de juego (SC-02)
### Agregado
- `luminar_supabase_v2.sql`: PIN cifrado (bcrypt), tabla `sesiones`, funciones `acceder_jugador`
  y `guardar_partida`, bloqueo tras 5 intentos, alias único sin importar mayúsculas.
- Récord personal, soporte de control (gamepad), pausa automática al perder el foco, pistas en la primera
  partida, sacudida de cámara al recibir daño, "!" sobre la Sombra que te ve, estela al correr.
### Corregido
- D-06: un alias podía usarse desde otro dispositivo. D-07: el script v2 fallaba con `id_jugador` uuid.
- D-08: alias repetidos con distinta mayúscula. D-09: partida marcada como duplicada se perdía.
- D-10: faltaba la fila "Silenciar audio" en la pausa. D-11: la fila de alias se salía de la pantalla.

## [0.4.0] — 2026-11-09 · Modo sin conexión
### Agregado
- Indicador "En línea / Sin conexión", aviso al empezar sin internet, cola de partidas pendientes
  que se suben solas al volver la conexión.
### Corregido
- D-04: decía "Sin conexión" aunque el servidor respondiera. D-05: partidas sin internet nunca llegaban a la nube.

## [0.3.0] — 2026-11-06 · Persistencia en la nube (H3)
### Agregado
- `luminar_supabase.sql`: tablas `jugadores` y `partidas`, validaciones CHECK, trigger anti-duplicados,
  fecha del servidor y Row Level Security.
### Corregido
- D-01: 0 % de peticiones exitosas (faltaban tablas y permisos). D-02: se aceptaban puntuaciones imposibles.
- D-03: se podían guardar partidas duplicadas.

## [0.2.0] — 2026-11-05 · Nuevas mecánicas (SC-01)
### Agregado
- Los faroles cambian de lugar en cada ronda, corazones de vida extra y correr con Shift/K gastando energía.

## [0.1.0] — hasta 2026-11-05 · Prototipo, mecánicas y puntuación (H1 y H2)
- 3 rondas, Sombras con máquina de estados, energía, vidas, combo, puntuación, HUD, pausa y audio.
