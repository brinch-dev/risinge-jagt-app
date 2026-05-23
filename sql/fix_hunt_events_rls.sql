-- =============================================
-- Fix hunt_events RLS policies
-- Kør i Supabase SQL Editor
-- =============================================

-- 1. Drop alle eksisterende policies på hunt_events (ryd op)
DO $$
DECLARE
  pol RECORD;
BEGIN
  FOR pol IN
    SELECT policyname FROM pg_policies WHERE tablename = 'hunt_events'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON hunt_events', pol.policyname);
  END LOOP;
END $$;

-- 2. Sørg for at RLS er aktiveret
ALTER TABLE hunt_events ENABLE ROW LEVEL SECURITY;

-- 3. SELECT: alle authenticated brugere kan se events
-- (app-side filtrerer baseret på rolle)
CREATE POLICY "hunt_events_select"
  ON hunt_events FOR SELECT
  TO authenticated
  USING (true);

-- 4. INSERT: roller der må oprette events
-- admin, jaeger_medlem, ejer, forvalter, bb_direktoer
CREATE POLICY "hunt_events_insert"
  ON hunt_events FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
        AND profiles.role IN ('admin', 'jaeger_medlem', 'ejer', 'forvalter', 'bb_direktoer')
    )
  );

-- 5. UPDATE: admin/jaeger_medlem/bb_direktoer kan redigere alle,
--            ejer/forvalter kan redigere egne
CREATE POLICY "hunt_events_update"
  ON hunt_events FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
        AND (
          profiles.role IN ('admin', 'jaeger_medlem', 'bb_direktoer')
          OR (profiles.role IN ('ejer', 'forvalter') AND hunt_events.created_by = auth.uid())
        )
    )
  );

-- 6. DELETE: admin/jaeger_medlem/bb_direktoer kan slette alle,
--            ejer/forvalter kan slette egne
CREATE POLICY "hunt_events_delete"
  ON hunt_events FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
        AND (
          profiles.role IN ('admin', 'jaeger_medlem', 'bb_direktoer')
          OR (profiles.role IN ('ejer', 'forvalter') AND hunt_events.created_by = auth.uid())
        )
    )
  );

-- =============================================
-- Fix event_signups RLS policies
-- =============================================

DO $$
DECLARE
  pol RECORD;
BEGIN
  FOR pol IN
    SELECT policyname FROM pg_policies WHERE tablename = 'event_signups'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON event_signups', pol.policyname);
  END LOOP;
END $$;

ALTER TABLE event_signups ENABLE ROW LEVEL SECURITY;

-- Alle authenticated kan se tilmeldinger
CREATE POLICY "event_signups_select"
  ON event_signups FOR SELECT
  TO authenticated
  USING (true);

-- Alle authenticated (ikke gæst) kan tilmelde sig
CREATE POLICY "event_signups_insert"
  ON event_signups FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- Brugere kan opdatere egne tilmeldinger
CREATE POLICY "event_signups_update"
  ON event_signups FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id);

-- Brugere kan slette egne tilmeldinger
CREATE POLICY "event_signups_delete"
  ON event_signups FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

-- =============================================
-- Fix event_comments RLS policies
-- =============================================

DO $$
DECLARE
  pol RECORD;
BEGIN
  FOR pol IN
    SELECT policyname FROM pg_policies WHERE tablename = 'event_comments'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON event_comments', pol.policyname);
  END LOOP;
END $$;

ALTER TABLE event_comments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "event_comments_select"
  ON event_comments FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "event_comments_insert"
  ON event_comments FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "event_comments_delete"
  ON event_comments FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id OR EXISTS (
    SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.role = 'admin'
  ));

-- =============================================
-- Verificer alle policies
-- =============================================
SELECT tablename, policyname, cmd
FROM pg_policies
WHERE tablename IN ('hunt_events', 'event_signups', 'event_comments')
ORDER BY tablename, cmd;
