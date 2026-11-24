# Flujo de trabajo del equipo (Git y GitHub)

## Ramas
| Rama | Para qué | Quién la une |
|---|---|---|
| `main` | Versión estable que siempre abre y pasa las pruebas. No se trabaja directo en ella. | Por Pull Request, con revisión de otro integrante |
| `feature/<descripcion>` | Una funcionalidad nueva. Ej.: `feature/pantalla-acceso` | Pull Request a `main` |
| `fix/<descripcion>` | Corrección de un defecto. Ej.: `fix/d-10-fila-pausa` | Pull Request a `main` |
| `sc-xx-<descripcion>` | Solicitud de cambio del docente o del equipo. Ej.: `sc-04-historia-comic` | Pull Request a `main` |
| `docs/<descripcion>` | Solo documentación (GDD, README, diagramas) | Pull Request a `main` |

## Ciclo de cada cambio
1. Crear (o tomar) un **Issue** con la plantilla que corresponda: Tarea, Defecto o Solicitud de cambio.
2. Crear la rama desde `main` actualizado:
   ```bash
   git checkout main
   git pull
   git checkout -b feature/nombre-corto
   ```
3. Hacer commits pequeños y descriptivos (ver abajo).
4. Antes de subir: abrir `tests/pruebas.tscn` y pulsar **F6**. Todas las pruebas deben pasar.
5. Subir la rama y abrir un **Pull Request** con `Closes #N`:
   ```bash
   git push -u origin feature/nombre-corto
   ```
6. Otro integrante revisa y aprueba. Se hace **Merge** a `main` y se borra la rama.
7. Se anota el cambio en `CHANGELOG.md`.

## Mensajes de commit
Formato: `tipo(área): qué se hizo (#issue)`

| Tipo | Uso | Ejemplo |
|---|---|---|
| `feat` | Funcionalidad nueva | `feat(acceso): pantalla ¿Quién juega? con alias y PIN (#12)` |
| `fix` | Corrección | `fix(pausa): agregar fila Silenciar audio (#15)` |
| `test` | Pruebas | `test: pruebas PF-13 a PF-15 del cómic (#18)` |
| `docs` | Documentación | `docs(gdd): secciones 10 a 12 (#20)` |
| `db` | Cambios en la base de datos | `db: funciones acceder_jugador y guardar_partida (#11)` |
| `chore` | Mantenimiento | `chore: .gitignore para Godot 4 (#3)` |

Cada integrante hace commits con **su propia cuenta** de GitHub, para que se vea su participación en
*Insights → Contributors*.

## Seguimiento de tareas
- **Issues** con etiquetas: `tarea`, `defecto`, `solicitud de cambio`, `documentación`.
- **Project** (tablero) con columnas *Por hacer → En progreso → En revisión → Hecho*.
- **Milestones** por hito: H1 a H5 (ver GDD, sección 8.3).

## Reglas
- Nunca subir `config.cfg`, claves `secret` / `service_role`, contraseñas ni ejecutables.
- Una escena `.tscn` la edita una sola persona a la vez (evita conflictos).
- Todos usan **Godot 4.7.2.stable**.
