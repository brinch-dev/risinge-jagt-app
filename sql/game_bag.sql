-- Vildtudbytte (Game Bag) tables
-- Kør dette i Supabase SQL Editor

-- Tabel til vildtudbytte-registreringer per event
CREATE TABLE IF NOT EXISTS game_bag_entries (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id uuid NOT NULL REFERENCES hunt_events(id) ON DELETE CASCADE,
  species text NOT NULL,
  count integer NOT NULL DEFAULT 0,
  created_by uuid REFERENCES auth.users(id),
  created_at timestamptz DEFAULT now(),
  UNIQUE(event_id, species)
);

-- Tabel til samlet antal skud per event per bruger
CREATE TABLE IF NOT EXISTS game_bag_totals (
  event_id uuid NOT NULL REFERENCES hunt_events(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id),
  total_shots integer NOT NULL DEFAULT 0,
  updated_by uuid REFERENCES auth.users(id),
  updated_at timestamptz DEFAULT now(),
  PRIMARY KEY (event_id, user_id)
);

-- RLS
ALTER TABLE game_bag_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE game_bag_totals ENABLE ROW LEVEL SECURITY;

-- SELECT: alle authenticated users
CREATE POLICY "game_bag_entries_select" ON game_bag_entries
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "game_bag_totals_select" ON game_bag_totals
  FOR SELECT TO authenticated USING (true);

-- INSERT: authenticated non-guest users
CREATE POLICY "game_bag_entries_insert" ON game_bag_entries
  FOR INSERT TO authenticated
  WITH CHECK (get_my_role() NOT IN ('gaest'));

CREATE POLICY "game_bag_totals_insert" ON game_bag_totals
  FOR INSERT TO authenticated
  WITH CHECK (get_my_role() NOT IN ('gaest'));

-- UPDATE: authenticated non-guest users
CREATE POLICY "game_bag_entries_update" ON game_bag_entries
  FOR UPDATE TO authenticated
  USING (get_my_role() NOT IN ('gaest'));

CREATE POLICY "game_bag_totals_update" ON game_bag_totals
  FOR UPDATE TO authenticated
  USING (get_my_role() NOT IN ('gaest'));

-- DELETE: authenticated non-guest users
CREATE POLICY "game_bag_entries_delete" ON game_bag_entries
  FOR DELETE TO authenticated
  USING (get_my_role() NOT IN ('gaest'));

CREATE POLICY "game_bag_totals_delete" ON game_bag_totals
  FOR DELETE TO authenticated
  USING (get_my_role() NOT IN ('gaest'));

-- Realtime
ALTER PUBLICATION supabase_realtime ADD TABLE game_bag_entries;
ALTER PUBLICATION supabase_realtime ADD TABLE game_bag_totals;
