-- =====================================================================
-- LUMINAR · Persistencia en la nube (Supabase / PostgreSQL)
-- Pegar completo en Supabase > SQL Editor > New query > Run.
-- Se puede ejecutar más de una vez sin romper nada.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. TABLAS (modelo 9.2: JUGADORES 1 ---- N PARTIDAS)
-- ---------------------------------------------------------------------
create table if not exists public.jugadores (
  id_jugador      bigint generated always as identity primary key,
  alias           text not null unique,
  fecha_registro  timestamptz not null default now()
);

create table if not exists public.partidas (
  id_partida       bigint generated always as identity primary key,
  id_jugador       bigint not null references public.jugadores (id_jugador) on delete cascade,
  puntuacion       integer not null,
  nivel_alcanzado  smallint not null default 1,
  fecha_partida    timestamptz not null default now()
);

-- Adaptación del modelo (justificada): columnas extra que el juego ya envía.
-- Sirven para que el servidor compruebe que la puntuación es posible.
alter table public.partidas add column if not exists celdas  integer not null default 0;
alter table public.partidas add column if not exists faroles integer not null default 0;
alter table public.partidas add column if not exists combo   integer not null default 1;
alter table public.partidas add column if not exists tiempo  integer not null default 0;

create index if not exists partidas_puntuacion_idx on public.partidas (puntuacion desc);
create index if not exists partidas_jugador_idx    on public.partidas (id_jugador, fecha_partida desc);

-- ---------------------------------------------------------------------
-- 2. VALIDACIONES EN EL SERVIDOR (RF-08 y 9.5)
--    Si hay filas viejas que no cumplen, el ALTER falla: bórralas antes.
-- ---------------------------------------------------------------------
alter table public.jugadores drop constraint if exists alias_valido;
alter table public.jugadores add constraint alias_valido check (
  char_length(btrim(alias)) between 3 and 20
  and alias = btrim(alias)
  and alias !~ '[[:cntrl:]]'
);

alter table public.partidas drop constraint if exists puntuacion_rango;
alter table public.partidas add constraint puntuacion_rango
  check (puntuacion between 0 and 99999);              -- sin negativos ni fuera de rango

alter table public.partidas drop constraint if exists nivel_rango;
alter table public.partidas add constraint nivel_rango
  check (nivel_alcanzado between 1 and 3);             -- el juego tiene 3 rondas

alter table public.partidas drop constraint if exists datos_rango;
alter table public.partidas add constraint datos_rango check (
  tiempo  between 0 and 365                            -- tope de 6:00 (+5 s de margen)
  and combo   between 1 and 5
  and faroles between 0 and nivel_alcanzado * 5        -- 5 faroles por ronda
  and celdas  between 0 and 400
);

-- La puntuación no puede ser mayor que lo máximo posible con esos datos:
-- 55 por celda (10 x combo 5 + 5 riesgo) + 50 por farol + 600 de rondas
-- + 1 por segundo + 500 de victoria.
alter table public.partidas drop constraint if exists puntuacion_posible;
alter table public.partidas add constraint puntuacion_posible check (
  puntuacion <= celdas * 55 + faroles * 50 + 600 + tiempo + 500
);

-- ---------------------------------------------------------------------
-- 3. TRIGGERS: fecha la pone el servidor y se bloquean duplicados
-- ---------------------------------------------------------------------
create or replace function public.validar_partida() returns trigger
language plpgsql as $$
begin
  new.fecha_partida := now();      -- el cliente no puede falsificar la fecha
  -- Registro duplicado: el mismo jugador no puede guardar dos partidas en 15 s
  if exists (
    select 1 from public.partidas
    where id_jugador = new.id_jugador
      and fecha_partida > now() - interval '15 seconds'
  ) then
    raise exception 'Partida duplicada: espera unos segundos'
      using errcode = '23505';     -- PostgREST responde 409 Conflict
  end if;
  return new;
end $$;

drop trigger if exists antes_de_insertar_partida on public.partidas;
create trigger antes_de_insertar_partida
  before insert on public.partidas
  for each row execute function public.validar_partida();

create or replace function public.fecha_registro_servidor() returns trigger
language plpgsql as $$
begin
  new.fecha_registro := now();
  return new;
end $$;

drop trigger if exists antes_de_insertar_jugador on public.jugadores;
create trigger antes_de_insertar_jugador
  before insert on public.jugadores
  for each row execute function public.fecha_registro_servidor();

-- ---------------------------------------------------------------------
-- 4. CONTROL DE ACCESO (Row Level Security)
--    El juego usa la clave publicable (rol "anon"): solo puede LEER e
--    INSERTAR. Sin políticas de UPDATE ni DELETE, nadie puede modificar
--    ni borrar puntuaciones desde el juego.
-- ---------------------------------------------------------------------
alter table public.jugadores enable row level security;
alter table public.partidas  enable row level security;

drop policy if exists "leer jugadores"  on public.jugadores;
drop policy if exists "crear jugador"   on public.jugadores;
drop policy if exists "leer partidas"   on public.partidas;
drop policy if exists "crear partida"   on public.partidas;

create policy "leer jugadores" on public.jugadores
  for select to anon, authenticated using (true);
create policy "crear jugador" on public.jugadores
  for insert to anon, authenticated with check (true);   -- los CHECK de arriba validan
create policy "leer partidas" on public.partidas
  for select to anon, authenticated using (true);
create policy "crear partida" on public.partidas
  for insert to anon, authenticated with check (true);

revoke all on public.jugadores, public.partidas from anon, authenticated;
grant select, insert on public.jugadores, public.partidas to anon, authenticated;

-- ---------------------------------------------------------------------
-- 5. CONSULTAS PARA LA EVIDENCIA (ejecutar aparte)
-- ---------------------------------------------------------------------
-- Top 10 (lo mismo que muestra el juego):
-- select j.alias, p.puntuacion, p.nivel_alcanzado, p.fecha_partida
-- from public.partidas p join public.jugadores j using (id_jugador)
-- order by p.puntuacion desc limit 10;
--
-- Las validaciones funcionan (las tres deben dar ERROR):
-- insert into public.partidas (id_jugador, puntuacion) values (1, -50);
-- insert into public.partidas (id_jugador, puntuacion, nivel_alcanzado) values (1, 100, 9);
-- insert into public.partidas (id_jugador, puntuacion, celdas, faroles, tiempo)
--   values (1, 99999, 0, 0, 10);
