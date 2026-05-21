-- Event tilmeldinger
CREATE TABLE IF NOT EXISTS event_signups (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  event_id UUID NOT NULL REFERENCES hunt_events(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  signed_up_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(event_id, user_id)
);

ALTER TABLE event_signups ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Alle kan se tilmeldinger" ON event_signups;
CREATE POLICY "Alle kan se tilmeldinger" ON event_signups
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "Medlemmer kan tilmelde sig" ON event_signups;
CREATE POLICY "Medlemmer kan tilmelde sig" ON event_signups
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Bruger kan afmelde sig eller admin kan" ON event_signups;
CREATE POLICY "Bruger kan afmelde sig eller admin kan" ON event_signups
  FOR DELETE USING (
    auth.uid() = user_id
    OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

ALTER PUBLICATION supabase_realtime ADD TABLE event_signups;

-- Admin log
CREATE TABLE IF NOT EXISTS admin_log (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  type TEXT NOT NULL,
  message TEXT NOT NULL,
  user_id UUID REFERENCES profiles(id),
  user_name TEXT,
  reference_id TEXT,
  metadata JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE admin_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admin kan laese log" ON admin_log;
CREATE POLICY "Admin kan laese log" ON admin_log
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

DROP POLICY IF EXISTS "Alle kan skrive til log" ON admin_log;
CREATE POLICY "Alle kan skrive til log" ON admin_log
  FOR INSERT WITH CHECK (true);
