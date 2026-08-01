-- Table d'ARCHIVE des quiz "La Table des Savoirs".
--
-- Volontairement SÉPARÉE de la table `cards` : c'est un backup brut de tous les
-- jours joués, il ne doit PAS alimenter le système Leitner de l'app.
--
-- À exécuter une fois dans Supabase → SQL Editor.

create table if not exists public.ltds_questions (
  day            integer not null,
  level          text    not null check (level in ('abordable', 'expert')),
  "order"        integer not null,
  theme          text,
  question       text    not null,
  answer         text    not null,          -- réponse attendue (validAnswers[0])
  valid_answers  jsonb   not null default '[]'::jsonb,
  imported_at    timestamptz not null default now(),
  primary key (day, level, "order")         -- upsert idempotent, zéro doublon
);

-- Index utile pour lister/filtrer par jour.
create index if not exists ltds_questions_day_idx on public.ltds_questions (day);

-- RLS activée + policy ouverte à la clé `anon`, comme la table `cards`.
-- Le cron (dépôt privé, secrets chiffrés) écrit donc avec la clé anon, ce qui
-- évite d'avoir à manipuler la clé `service_role`.
-- (Pour verrouiller davantage un jour : supprimer cette policy et utiliser la
--  clé service_role, qui contourne RLS.)
alter table public.ltds_questions enable row level security;

create policy "Public Access" on public.ltds_questions
  for all using (true) with check (true);
