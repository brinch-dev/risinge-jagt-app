-- Tower reservations tabel
CREATE TABLE IF NOT EXISTS tower_reservations (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  tower_id UUID NOT NULL REFERENCES towers(id) ON DELETE CASCADE,
  event_id UUID NOT NULL REFERENCES hunt_events(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  reserved_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(tower_id, event_id)
);

-- RLS
ALTER TABLE tower_reservations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Alle kan laese reservationer" ON tower_reservations;
CREATE POLICY "Alle kan laese reservationer" ON tower_reservations
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "Medlemmer kan reservere" ON tower_reservations;
CREATE POLICY "Medlemmer kan reservere" ON tower_reservations
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Bruger kan slette egen reservation" ON tower_reservations;
CREATE POLICY "Bruger kan slette egen reservation" ON tower_reservations
  FOR DELETE USING (
    auth.uid() = user_id
    OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- Realtime
ALTER PUBLICATION supabase_realtime ADD TABLE tower_reservations;
