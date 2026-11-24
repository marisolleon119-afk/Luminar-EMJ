-- =====================================================================
-- LUMINAR · Borrar datos de prueba antes de una entrega o demostración
-- Supabase > SQL Editor > New query > pegar > Run
-- Borra los jugadores de prueba y, en cascada, sus partidas y sesiones.
-- =====================================================================

-- 1) Ver primero qué se va a borrar (revisa la lista antes del paso 2)
select id_jugador, alias
from public.jugadores
where lower(alias) like 'test%'          -- alias que crean las pruebas automáticas (testNNNN)
   or lower(alias) like 'prueba%'        -- PruebaPin, PruebaNube, etc.
order by alias;

-- 2) Borrar (descomenta las 4 líneas y vuelve a ejecutar)
-- delete from public.partidas  where id_jugador in (select id_jugador from public.jugadores
--   where lower(alias) like 'test%' or lower(alias) like 'prueba%');
-- delete from public.jugadores where lower(alias) like 'test%' or lower(alias) like 'prueba%';

-- 3) Comprobar que quedó limpio
-- select count(*) as jugadores_de_prueba from public.jugadores
-- where lower(alias) like 'test%' or lower(alias) like 'prueba%';
