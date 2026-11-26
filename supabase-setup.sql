-- HCU-Rex Bestenliste: einmal im Supabase "SQL Editor" ausführen.

create table if not exists public.scores (
  id          bigint generated always as identity primary key,
  name        text        not null check (char_length(name) between 1 and 16),
  cp          integer     not null check (cp between 0 and 100000),
  cups        integer     not null check (cups between 0 and 100000),
  duration_s  integer     not null check (duration_s >= 0),
  created_at  timestamptz not null default now()
);
create index if not exists scores_cp_idx   on public.scores (cp desc);
create index if not exists scores_cups_idx on public.scores (cups desc);

-- Alle dürfen lesen. Schreiben geht nur über die Funktion unten (keine Insert-/Update-/Delete-Policy).
alter table public.scores enable row level security;
drop policy if exists "alle lesen" on public.scores;
create policy "alle lesen" on public.scores for select to anon, authenticated using (true);
grant select on public.scores to anon, authenticated;

-- Eintragen mit einfacher Plausibilitätsprüfung
drop function if exists public.submit_score(text, int, int, int);
create or replace function public.submit_score(p_name text, p_cp int, p_cups int, p_duration int)
returns bigint
language plpgsql
security definer
set search_path = public
as $$
declare
  n text;
  new_id bigint;
begin
  -- Name: nur Buchstaben, Ziffern, Leerzeichen, . _ - ; höchstens 16 Zeichen; leer = anonym
  n := btrim(regexp_replace(coalesce(p_name, ''), '[^A-Za-z0-9ÄÖÜäöüß ._-]', '', 'g'));
  n := btrim(left(n, 16));
  if n = '' then n := 'anonym'; end if;

  if p_cp is null or p_cups is null or p_duration is null then raise exception 'ungueltig'; end if;
  if p_cp < 10 or p_duration < 1 or p_duration > 21600 then raise exception 'ungueltig'; end if;
  -- Spieltempo: höchstens ca. 5 CP pro Sekunde, mindestens ca. 2
  if p_cp > p_duration * 5.5 + 5 or p_cp < p_duration * 1.5 - 10 then raise exception 'unplausibel'; end if;
  -- höchstens 6 Tassen pro Mülleimer, Mülleimer frühestens alle 2 CP
  if p_cups < 0 or p_cups > p_cp * 3 then raise exception 'unplausibel'; end if;
  -- Bremse gegen Massen-Einträge
  if (select count(*) from public.scores where created_at > now() - interval '1 minute') >= 30 then
    raise exception 'zu viele Eintraege, bitte kurz warten';
  end if;

  insert into public.scores (name, cp, cups, duration_s) values (n, p_cp, p_cups, p_duration) returning id into new_id;
  return new_id;
end;
$$;

revoke all on function public.submit_score(text, int, int, int) from public;
grant execute on function public.submit_score(text, int, int, int) to anon, authenticated;
