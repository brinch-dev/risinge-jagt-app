-- ===========================================
-- v1.8.0 Migration — Risinge Jagt App
-- ===========================================

-- 1. Tilfoej can_monitor til profiles (4 specifikke brugere kan altid se live positioner)
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS can_monitor BOOLEAN DEFAULT false;

-- 2. Tilfoej status til event_signups (tilmeldt/kommer ikke/ikke reageret)
ALTER TABLE event_signups ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'attending'
  CHECK (status IN ('attending', 'not_attending'));

-- Tilfoej UPDATE policy saa brugere kan aendre deres status
DROP POLICY IF EXISTS "Bruger kan opdatere egen tilmelding" ON event_signups;
CREATE POLICY "Bruger kan opdatere egen tilmelding" ON event_signups
  FOR UPDATE TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- 3. Event-kommentarer
CREATE TABLE IF NOT EXISTS event_comments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id UUID NOT NULL REFERENCES hunt_events(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES profiles(id),
  body TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE event_comments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Alle autentificerede kan se kommentarer" ON event_comments;
CREATE POLICY "Alle autentificerede kan se kommentarer" ON event_comments
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Medlemmer kan skrive kommentarer" ON event_comments;
CREATE POLICY "Medlemmer kan skrive kommentarer" ON event_comments
  FOR INSERT TO authenticated
  WITH CHECK (
    user_id = auth.uid() AND
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('member', 'admin'))
  );

DROP POLICY IF EXISTS "Brugere kan slette egne kommentarer" ON event_comments;
CREATE POLICY "Brugere kan slette egne kommentarer" ON event_comments
  FOR DELETE TO authenticated
  USING (user_id = auth.uid());

-- Realtime for event_comments
DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE event_comments;
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

-- 4. Saet can_monitor = true for Maria, Claus, Daniel, Henrik (koer EFTER de har registreret sig)
-- UPDATE profiles SET can_monitor = true WHERE email IN (
--   'maria@risinge.dk',
--   'cj@risinge.dk',
--   'dhasselstrom@gmail.com',
--   'henrik.staer@colas.dk'
-- );

-- 5. Opret Risinge Herregaard omraade (1900m cirkulaert polygon)
-- Center: Risingevej 7, 5540 Ullerslev ≈ 55.3835, 10.6100
-- Genererer 36 punkter i en cirkel med 1900m radius
DO $$
DECLARE
  area_uuid UUID := gen_random_uuid();
  admin_id UUID;
  i INT;
  angle DOUBLE PRECISION;
  lat_offset DOUBLE PRECISION;
  lng_offset DOUBLE PRECISION;
  center_lat DOUBLE PRECISION := 55.3835;
  center_lng DOUBLE PRECISION := 10.6100;
  radius_m DOUBLE PRECISION := 1900;
  lat_per_m DOUBLE PRECISION := 1.0 / 111320.0;
  lng_per_m DOUBLE PRECISION;
BEGIN
  lng_per_m := 1.0 / (111320.0 * cos(radians(center_lat)));

  -- Find en admin bruger til created_by
  SELECT id INTO admin_id FROM profiles WHERE role = 'admin' LIMIT 1;
  IF admin_id IS NULL THEN
    SELECT id INTO admin_id FROM profiles LIMIT 1;
  END IF;

  -- Opret jagtomraadet
  INSERT INTO hunt_areas (id, name, center_lat, center_lng, radius_meters, description, alarm_text, alarm_margin_meters, created_by)
  VALUES (
    area_uuid,
    'Risinge Herregaard',
    center_lat,
    center_lng,
    radius_m,
    'Hovedjagtomraade — 1900m radius fra Risingevej 7, 5540 Ullerslev',
    'Advarsel: Du naermer dig jagtomraadets graense! Vend om.',
    150,
    admin_id
  );

  -- Generer cirkulaert polygon (36 punkter)
  FOR i IN 0..35 LOOP
    angle := radians(i * 10.0);
    lat_offset := radius_m * cos(angle) * lat_per_m;
    lng_offset := radius_m * sin(angle) * lng_per_m;

    INSERT INTO area_boundaries (area_id, point_order, latitude, longitude)
    VALUES (area_uuid, i, center_lat + lat_offset, center_lng + lng_offset);
  END LOOP;
END $$;

-- 6. Opret "Jaeger Chat" general kanal (hvis den ikke allerede eksisterer)
DO $$
DECLARE
  admin_id UUID;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM chat_channels WHERE name = 'Jaeger Chat' AND type = 'general') THEN
    SELECT id INTO admin_id FROM profiles WHERE role = 'admin' LIMIT 1;
    IF admin_id IS NOT NULL THEN
      INSERT INTO chat_channels (name, type, created_by)
      VALUES ('Jaeger Chat', 'general', admin_id);
    END IF;
  END IF;
END $$;
