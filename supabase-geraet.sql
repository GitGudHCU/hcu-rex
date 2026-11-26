-- HCU-Rex: ein Eintrag pro Gerät, Name fest, jeder Name nur einmal (außer „anonym“).
-- Wurde am 2026-11-26 als Migration eingespielt; zum Nachvollziehen hier abgelegt.

alter table public.scores add column if not exists device_id uuid;
create unique index if not exists scores_device_idx on public.scores (device_id) where device_id is not null;

-- Die Geräte-Kennung bleibt geheim: öffentlich lesbar sind nur diese Spalten
revoke select on public.scores from anon, authenticated;
grant select (id, name, cups, created_at) on public.scores to anon, authenticated;

create or replace function public.submit_device_score(p_device uuid, p_name text, p_cp int, p_cups int, p_duration int)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  n text;
  ex public.scores%rowtype;
  new_id bigint;
begin
  if p_device is null or p_cp is null or p_cups is null or p_duration is null then raise exception 'ungueltig'; end if;
  if p_cp < 10 or p_duration < 1 or p_duration > 21600 then raise exception 'ungueltig'; end if;
  if p_cp > p_duration * 5.5 + 5 or p_cp < p_duration * 1.5 - 10 then raise exception 'unplausibel'; end if;
  if p_cups < 1 or p_cups > p_cp * 3 then raise exception 'unplausibel'; end if;
  if (select count(*) from public.scores where created_at > now() - interval '1 minute') >= 30 then
    raise exception 'zu viele Eintraege, bitte kurz warten';
  end if;

  -- Gerät schon bekannt: Name bleibt, Ergebnis nur ersetzen, wenn es besser ist
  select * into ex from public.scores where device_id = p_device;
  if found then
    if p_cups > ex.cups then
      update public.scores set cups = p_cups, cp = p_cp, duration_s = p_duration, created_at = now() where id = ex.id;
    end if;
    return json_build_object('id', ex.id, 'name', ex.name);
  end if;

  n := btrim(regexp_replace(coalesce(p_name, ''), '[^A-Za-z0-9ÄÖÜäöüß ._-]', '', 'g'));
  n := btrim(left(n, 16));
  if n = '' then n := 'anonym'; end if;
  if lower(n) <> 'anonym' and exists (select 1 from public.scores where lower(name) = lower(n)) then
    raise exception 'Name schon vergeben';
  end if;

  insert into public.scores (name, cp, cups, duration_s, device_id) values (n, p_cp, p_cups, p_duration, p_device)
  returning id into new_id;
  return json_build_object('id', new_id, 'name', n);
end;
$$;

revoke all on function public.submit_device_score(uuid, text, int, int, int) from public;
grant execute on function public.submit_device_score(uuid, text, int, int, int) to anon, authenticated;

-- alte Funktion ohne Geräte-Kennung abschalten
drop function if exists public.submit_score(text, int, int, int);
