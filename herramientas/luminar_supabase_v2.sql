-- =====================================================================
-- LUMINAR · Actualización v2: alias protegidos con PIN
-- Ejecutar DESPUÉS de luminar_supabase.sql (el script v1).
-- Pegar completo en Supabase > SQL Editor > New query > Run.
-- Se puede ejecutar más de una vez.
--
-- Qué cambia:
--   * Cada alias es único sin importar mayúsculas ("Ana" = "ana") y tiene un PIN de 4 números.
--   * Otro dispositivo solo puede usar ese alias si conoce el PIN.
--   * 5 PIN incorrectos seguidos bloquean el alias 10 minutos.
--   * El juego ya NO inserta directo en las tablas: usa 2 funciones seguras
--     (acceder_jugador y guardar_partida) que validan alias, PIN y sesión.
--   * El PIN se guarda cifrado (bcrypt) y nadie puede leerlo por la API.
-- =====================================================================

create extension if not exists pgcrypto with schema extensions;

-- ---------------------------------------------------------------------
-- 1. Columnas nuevas y tabla de sesiones
-- ---------------------------------------------------------------------
alter table public.jugadores add column if not exists pin_hash text;
alter table public.jugadores add column if not exists intentos_fallidos integer not null default 0;
alter table public.jugadores add column if not exists bloqueado_hasta timestamptz;

-- Por si las tablas se crearon antes del script v1 sin estas columnas
alter table public.jugadores add column if not exists fecha_registro timestamptz not null default now();
alter table public.partidas  add column if not exists fecha_partida  timestamptz not null default now();

-- Una sesión por dispositivo: el juego guarda el token, la base solo su huella (sha256).
-- id_jugador toma el MISMO tipo que jugadores.id_jugador (bigint o uuid, según tu base).
do $$
declare v_tipo text;
begin
  select format_type(a.atttypid, a.atttypmod) into v_tipo
  from pg_attribute a
  where a.attrelid = 'public.jugadores'::regclass and a.attname = 'id_jugador';
  execute format(
    'create table if not exists public.sesiones (
       token_hash  text primary key,
       id_jugador  %s not null references public.jugadores (id_jugador) on delete cascade,
       creada      timestamptz not null default now()
     )', v_tipo);
end $$;
alter table public.sesiones enable row level security;   -- sin políticas: nadie la ve por la API

-- ---------------------------------------------------------------------
-- 2. Alias único sin importar mayúsculas y con formato válido
--    (si falla el índice, hay 2 alias iguales como "Ana" y "ana": borra uno)
-- ---------------------------------------------------------------------
create unique index if not exists jugadores_alias_unico on public.jugadores (lower(alias));

alter table public.jugadores drop constraint if exists alias_formato;
alter table public.jugadores add constraint alias_formato check (
  char_length(alias) between 3 and 12
  and alias ~ '^[A-Za-z0-9ÁÉÍÓÚÜÑáéíóúüñ_-]+( [A-Za-z0-9ÁÉÍÓÚÜÑáéíóúüñ_-]+)*$'
) not valid;   -- NOT VALID: no revisa los alias que ya existían, solo los nuevos

-- ---------------------------------------------------------------------
-- 3. Función: entrar o registrarse con alias + PIN
--    Devuelve JSON: {ok, id_jugador, alias, token, nuevo} o {ok:false, error, ...}
-- ---------------------------------------------------------------------
create or replace function public.acceder_jugador(p_alias text, p_pin text)
returns json
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  j         public.jugadores;
  v_token   text;
  v_nuevo   boolean := false;
  v_intentos integer;
begin
  p_alias := btrim(regexp_replace(coalesce(p_alias, ''), '\s+', ' ', 'g'));

  if char_length(p_alias) not between 3 and 12
     or p_alias !~ '^[A-Za-z0-9ÁÉÍÓÚÜÑáéíóúüñ_-]+( [A-Za-z0-9ÁÉÍÓÚÜÑáéíóúüñ_-]+)*$' then
    return json_build_object('ok', false, 'error', 'ALIAS_INVALIDO');
  end if;
  if coalesce(p_pin, '') !~ '^[0-9]{4}$' then
    return json_build_object('ok', false, 'error', 'PIN_INVALIDO');
  end if;

  select * into j from public.jugadores where lower(alias) = lower(p_alias) for update;

  if not found then
    -- Alias libre: se registra con su PIN
    insert into public.jugadores (alias, pin_hash)
    values (p_alias, crypt(p_pin, gen_salt('bf')))
    returning * into j;
    v_nuevo := true;

  elsif j.pin_hash is null then
    -- Alias creado antes de la v2 (sin PIN): se protege con el primer PIN que se use
    update public.jugadores set pin_hash = crypt(p_pin, gen_salt('bf')), intentos_fallidos = 0
    where id_jugador = j.id_jugador;

  else
    if j.bloqueado_hasta is not null and j.bloqueado_hasta > now() then
      return json_build_object('ok', false, 'error', 'BLOQUEADO',
        'minutos', ceil(extract(epoch from (j.bloqueado_hasta - now())) / 60));
    end if;
    if j.pin_hash <> crypt(p_pin, j.pin_hash) then
      v_intentos := j.intentos_fallidos + 1;
      if v_intentos >= 5 then
        update public.jugadores set intentos_fallidos = 0, bloqueado_hasta = now() + interval '10 minutes'
        where id_jugador = j.id_jugador;
        return json_build_object('ok', false, 'error', 'BLOQUEADO', 'minutos', 10);
      end if;
      update public.jugadores set intentos_fallidos = v_intentos where id_jugador = j.id_jugador;
      return json_build_object('ok', false, 'error', 'ALIAS_EN_USO', 'intentos_restantes', 5 - v_intentos);
    end if;
    update public.jugadores set intentos_fallidos = 0, bloqueado_hasta = null
    where id_jugador = j.id_jugador;
  end if;

  -- Sesión nueva para este dispositivo
  v_token := encode(gen_random_bytes(24), 'hex');
  insert into public.sesiones (token_hash, id_jugador)
  values (encode(digest(v_token, 'sha256'), 'hex'), j.id_jugador);

  return json_build_object('ok', true, 'id_jugador', j.id_jugador, 'alias', j.alias,
                           'token', v_token, 'nuevo', v_nuevo);
end $$;

-- ---------------------------------------------------------------------
-- 4. Función: guardar partida (solo con una sesión válida)
--    Las reglas CHECK y el trigger anti-duplicados del script v1 se siguen aplicando.
-- ---------------------------------------------------------------------
create or replace function public.guardar_partida(
  p_token text, p_puntuacion integer, p_nivel integer,
  p_celdas integer default 0, p_faroles integer default 0,
  p_combo integer default 1, p_tiempo integer default 0)
returns json
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_jugador public.jugadores.id_jugador%TYPE;
  v_id      public.partidas.id_partida%TYPE;
begin
  select id_jugador into v_jugador from public.sesiones
  where token_hash = encode(digest(coalesce(p_token, ''), 'sha256'), 'hex');
  if v_jugador is null then
    return json_build_object('ok', false, 'error', 'SESION_INVALIDA');
  end if;

  begin
    insert into public.partidas (id_jugador, puntuacion, nivel_alcanzado, celdas, faroles, combo, tiempo)
    values (v_jugador, p_puntuacion, p_nivel, p_celdas, p_faroles, p_combo, p_tiempo)
    returning id_partida into v_id;
  exception
    when check_violation or not_null_violation or numeric_value_out_of_range then
      return json_build_object('ok', false, 'error', 'DATOS_INVALIDOS');
    when unique_violation then
      return json_build_object('ok', false, 'error', 'DUPLICADA');
  end;
  return json_build_object('ok', true, 'id_partida', v_id);
end $$;

-- ---------------------------------------------------------------------
-- 5. Permisos: el juego solo LEE (sin el PIN) y usa las 2 funciones
-- ---------------------------------------------------------------------
revoke all on public.jugadores, public.partidas, public.sesiones from anon, authenticated;
grant select (id_jugador, alias, fecha_registro) on public.jugadores to anon, authenticated;
grant select on public.partidas to anon, authenticated;

drop policy if exists "crear jugador" on public.jugadores;
drop policy if exists "crear partida" on public.partidas;

revoke all on function public.acceder_jugador(text, text) from public;
revoke all on function public.guardar_partida(text, integer, integer, integer, integer, integer, integer) from public;
grant execute on function public.acceder_jugador(text, text) to anon, authenticated;
grant execute on function public.guardar_partida(text, integer, integer, integer, integer, integer, integer) to anon, authenticated;

-- ---------------------------------------------------------------------
-- 6. Pruebas rápidas (ejecutar aparte, una por una)
-- ---------------------------------------------------------------------
-- select acceder_jugador('Chispa', '1234');   -- nuevo: ok true, nuevo true
-- select acceder_jugador('chispa', '1234');   -- mismo jugador (no importa mayúsculas)
-- select acceder_jugador('CHISPA', '9999');   -- ok false, ALIAS_EN_USO
-- select acceder_jugador('a', '1234');        -- ok false, ALIAS_INVALIDO
