# Luminar

> *La luz nunca se apaga, solo espera a ser encontrada.*

Videojuego arcade 2D de supervivencia y recolección con vista cenital, hecho en **Godot 4.7.2**.
Una tormenta apagó el Gran Farol de Ciudad Faro y las Sombras invadieron las calles. **Chispa**, un pequeño
robot farolero, debe volver a encender los 5 faroles de la ciudad durante 3 noches (rondas), recogiendo
celdas de energía y esquivando a las Sombras. Las puntuaciones se guardan en la nube (**Supabase /
PostgreSQL**) y se muestran en un ranking global con las 10 mejores.

Proyecto de la materia **Proyecto de Videojuegos 2D** · Ingeniería en Software ·
Universidad Autónoma de Occidente, Unidad Regional Guamúchil · 2026.

## Participantes
| Integrante | Matrícula | Rol |
|---|---|---|
| Marisol Carvajal León | 23060279 | Líder de proyecto y programación de jugabilidad |
| Emmanuel Isaias Bojorquez Iribe | 23060223 | Backend, nube y pruebas |
| Juan José Sánchez Navarro | 23060053 | Arte, interfaz, audio y documentación |

---

## Tecnologías y versiones
| Componente | Versión | Uso |
|---|---|---|
| Godot Engine (estándar, no .NET) | **4.7.2.stable** | Motor, editor y exportación |
| GDScript | incluido en Godot 4.7 | Toda la lógica del juego |
| Renderizador Compatibility | OpenGL 3.3 | Dibujo 2D y luces |
| Supabase | API REST v1 (PostgREST) | Servicio en la nube |
| PostgreSQL | administrado por Supabase | Base de datos (`jugadores`, `partidas`, `sesiones`) |
| pgcrypto | extensión de PostgreSQL | Cifrado del PIN (bcrypt) y tokens |

## Requisitos previos
- **Windows 10/11 de 64 bits** (también abre en Linux y macOS desde el editor).
- **Godot 4.7.2.stable** (versión estándar): <https://godotengine.org/download/archive/>
- Para exportar el `.exe`: plantillas de exportación 4.7.2 (*Editor → Administrar plantillas de exportación*).
- Una cuenta gratuita de **Supabase**: <https://supabase.com> (solo para la nube; sin ella el juego funciona en modo local).
- Git: <https://git-scm.com>

---

## Descargar, configurar y ejecutar

### 1. Descargar
```bash
git clone https://github.com/<usuario>/<repositorio>.git
cd <repositorio>
```
o en GitHub: **Code → Download ZIP** y descomprimir.

### 2. Configurar la nube (una sola vez)
1. En <https://supabase.com> crea un proyecto nuevo.
2. Abre **SQL Editor → New query** y ejecuta, **en este orden**:
   1. `herramientas/luminar_supabase.sql` → tablas, validaciones `CHECK`, anti-duplicados y RLS.
   2. `herramientas/luminar_supabase_v2.sql` → alias únicos con PIN y funciones seguras.

   Cada uno debe terminar en *Success. No rows returned*.
3. Ve a **Project Settings → API Keys** y copia:
   - la **Project URL** (`https://xxxx.supabase.co`)
   - la **Publishable key** (`sb_publishable_...`)

### 3. Configurar el juego sin exponer secretos
1. Copia `config.ejemplo.cfg` y renómbralo **`config.cfg`** (en la misma carpeta que `project.godot`).
2. Llénalo:
   ```ini
   [nube]
   url="https://xxxx.supabase.co"
   api_key="sb_publishable_..."
   ```
3. Reglas:
   - `config.cfg` está en `.gitignore`: **nunca se sube** al repositorio.
   - Usa solo la clave **publicable**. La clave **secret / service_role** y la contraseña de la base
     **nunca** van en el juego, en el repositorio ni en chats.
   - La clave publicable puede ir dentro del `.exe`: lo que protege los datos son las reglas del servidor
     (RLS, funciones con PIN y validaciones).

### 4. Ejecutar
1. Abre Godot → **Importar** → elige `project.godot` → **Importar y editar**.
2. Pulsa **F5**. Aparece la pantalla **¿Quién juega?**.
3. Escribe un alias (3 a 12 letras, números, `_` o `-`) y un PIN de 4 números → **Entrar**.

### 5. Exportar el ejecutable (opcional)
El perfil **Windows Desktop** ya viene configurado (un solo `.exe`, incluye `config.cfg`, excluye pruebas y documentación).
*Proyecto → Exportar → Windows Desktop → Exportar proyecto* → desmarcar *Exportar con depuración* →
guardar como `Luminar.exe` en una carpeta **fuera** del proyecto. Requiere tener `config.cfg` (paso 3).

> Si el juego muestra **"Nube sin configurar (falta config.cfg)"**, falta el paso 3.

---

## Controles
| Acción | Teclado | Control (gamepad) |
|---|---|---|
| Moverse | WASD / flechas | Stick izquierdo / cruceta |
| Correr (gasta energía) | Shift / K | RB / X |
| Encender farol | E / Espacio | A |
| Pausar / reanudar | P / Esc | Start |
| Silenciar | M | — |
| Menús | Flechas + Enter / clic | Cruceta + A |
| Cómic: siguiente / saltar | Clic, Enter o Espacio / Esc | A |

Las teclas se pueden cambiar en **Ajustes → Controles**. Si la ventana pierde el foco, el juego se pausa solo.

## Cómo se juega
- Enciende los **5 faroles** de cada ronda (cuesta 10 de energía, +50 puntos). En cada ronda cambian de lugar.
- Fuera de la luz gastas energía: recoge **celdas** doradas (+10 × combo). Lejos de la luz dan +5 de riesgo.
- Las **Sombras** te persiguen si te ven ("!"). Llévalas a la luz para disiparlas. Si te tocan, pierdes una vida.
- Si te falta una vida, a veces aparece un **corazón** que la recupera.
- **3 rondas**: ganar da +500. Tope de 6 minutos.

---

## Ejecutar las pruebas
1. En Godot abre `tests/pruebas.tscn` y pulsa **F6** (*Ejecutar escena actual*).
   - **Unitarias y funcionales** (40): no necesitan internet.
2. **Integración con la nube** (14): selecciona el nodo *Pruebas*, marca **Probar Nube** en el Inspector y
   pulsa **F6**. Crea un jugador `testNNNN` en Supabase.
3. Los resultados salen en la ventana y en el panel **Salida**: `RESULTADO: N pasan, 0 fallan`.

Desde la terminal: `godot --path . res://tests/pruebas.tscn -- --salir` (agrega `--nube` para la integración).

## Verificar el ranking
1. Juega una partida hasta terminarla. En resultados debe decir **"Puntuación guardada en el ranking global"**.
2. En Supabase: **Table Editor → `partidas`** debe tener la fila nueva. O en **SQL Editor**:
   ```sql
   select j.alias, p.puntuacion, p.nivel_alcanzado, p.fecha_partida
   from partidas p join jugadores j using (id_jugador)
   order by p.puntuacion desc limit 10;
   ```
3. Cierra el juego por completo, vuelve a abrirlo y entra a **Ranking**: la puntuación sigue ahí.
4. Prueba sin conexión: apaga el Wi‑Fi y juega. Debe decir *"Sin conexión: partida guardada en este equipo"*;
   al volver el internet la partida se sube sola.
5. Antes de entregar, borra los datos de prueba con `herramientas/limpiar_datos_prueba.sql`.

---

## Estructura del proyecto
| Carpeta / archivo | Contenido |
|---|---|
| `Escenas/` | Escenas `.tscn`: acceso, portada (menú), cómic, mundo, HUD, pausa, resultados, ranking, ajustes, instrucciones, créditos |
| `scripts/` | Lógica: `mundo.gd`, `chispa.gd`, `sombra.gd`, `farol.gd`, `vida_extra.gd`… Datos: `global.gd`, `supabase.gd` (único que usa la red) |
| `Recursos/` | Imágenes, tipografías y audio |
| `tests/` | Pruebas automáticas |
| `herramientas/` | Scripts SQL de la base de datos y generador de audio |
| `docs/` | Diagramas y flujo de trabajo del equipo |
| `config.ejemplo.cfg` | Plantilla de configuración de la nube (sin datos) |
| `CHANGELOG.md` | Registro de cambios por versión |

## Flujo de trabajo
Ramas `feature/…`, `fix/…`, `sc-xx-…` y Pull Requests revisados a `main`. Detalle en
[`docs/FLUJO_DE_TRABAJO.md`](docs/FLUJO_DE_TRABAJO.md). Tareas e incidencias en **Issues** y el tablero **Projects**.

---

## Limitaciones conocidas
- La puntuación se calcula en el cliente. El servidor rechaza valores negativos, fuera de rango, imposibles
  o duplicados, pero no puede comprobar que la partida realmente se jugó.
- El PIN es de 4 números: es una protección básica para un juego escolar, no una contraseña. Tras 5 intentos
  fallidos el alias se bloquea 10 minutos.
- El proyecto gratuito de Supabase se pausa tras una semana sin uso: hay que entrar al panel antes de la demostración.
- Solo se probó en Windows 10/11 y Linux. Un solo mapa.

## Créditos y licencias de recursos
| Recurso | Procedencia | Licencia |
|---|---|---|
| Chispa, Sombras, faroles, celdas, escenario, portada e interfaz | Equipo Luminar | Autoría del equipo |
| Música y efectos de sonido | Creación propia por síntesis (`herramientas/sintetizar_audio.py`) | Autoría del equipo |
| Tipografía Poppins | Indian Type Foundry · Google Fonts | SIL Open Font License 1.1 |
| Godot Engine 4.7.2 | godotengine.org | MIT |
| Supabase / PostgreSQL | supabase.com | Servicio en la nube (plan gratuito) / PostgreSQL License |
