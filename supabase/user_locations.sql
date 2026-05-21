-- Live bruger-positioner for admin-overvaagning
CREATE TABLE IF NOT EXISTS user_locations (
  user_id UUID PRIMARY KEY REFERENCES profiles(id) ON DELETE CASCADE,
  latitude DOUBLE PRECISION NOT NULL,
  longitude DOUBLE PRECISION NOT NULL,
  accuracy DOUBLE PRECISION,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE user_locations ENABLE ROW LEVEL SECURITY;

-- Brugere kan opdatere deres egen position
DROP POLICY IF EXISTS "Bruger kan upsert egen position" ON user_locations;
CREATE POLICY "Bruger kan upsert egen position" ON user_locations
  FOR ALL TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Admin kan se alle positioner
DROP POLICY IF EXISTS "Admin kan se alle positioner" ON user_locations;
CREATE POLICY "Admin kan se alle positioner" ON user_locations
  FOR SELECT TO authenticated
  USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- Realtime for live-overvaagning
DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE user_locations;
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

-- Checkins tabel
CREATE TABLE IF NOT EXISTS event_checkins (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  event_id UUID NOT NULL REFERENCES hunt_events(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  checked_in_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  latitude DOUBLE PRECISION NOT NULL,
  longitude DOUBLE PRECISION NOT NULL,
  UNIQUE(event_id, user_id)
);

ALTER TABLE event_checkins ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Bruger kan checke ind" ON event_checkins;
CREATE POLICY "Bruger kan checke ind" ON event_checkins
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Alle kan se checkins" ON event_checkins;
CREATE POLICY "Alle kan se checkins" ON event_checkins
  FOR SELECT TO authenticated
  USING (true);

DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE event_checkins;
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;
