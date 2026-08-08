-- Table des RÉGLAGES synchronisés — « le projet Supabase est le compte » (#42).
--
-- Une seule ligne aujourd'hui (id = 'default') qui regroupe ce qui était
-- local-only : réglages Leitner (boîtes, intervalles, golden +2) et jeton LTDS.
-- Saisir URL + clé anon sur un nouvel appareil restaure donc cartes ET réglages.
--
-- `id` est un text : le jour où l'app passera aux vrais comptes (Supabase Auth),
-- il recevra un user_id sans changer le schéma.
--
-- À exécuter une fois dans Supabase → SQL Editor.

create table if not exists public.user_settings (
  id         text primary key,               -- 'default' (mono-utilisateur)
  data       jsonb not null,                 -- enveloppe SyncedSettings (timestamps par section)
  updated_at timestamptz not null default now()
);

-- RLS activée + policy ouverte à la clé `anon`, comme `cards` et `ltds_questions`.
-- (Pour verrouiller un jour : policies par user_id avec Supabase Auth — option A.)
alter table public.user_settings enable row level security;

create policy "Public Access" on public.user_settings
  for all using (true) with check (true);
