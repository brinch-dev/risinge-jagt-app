-- =============================================
-- Fix hunt_events RLS policies v2
-- Bruger SECURITY DEFINER funktion til at omgå
-- profiles RLS i subqueries
-- Kør i Supabase SQL Editor
-- =============================================

-- 1. Opret SECURITY DEFINER funktion der returnerer brugerens rolle
-- Denne omgår RLS på profiles-tabellen
CREATE OR REPLACE FUNCTION get_my_role()
RETURNS TEXT
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT role FROM profiles WHERE id = auth.uid();
$$;

-- 2. Drop alle eksisterende policies på hunt_events
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

ALTER TABLE hunt_events ENABLE ROW LEVEL SECURITY;

-- 3. SELECT: alle authenticated
CREATE POLICY "hunt_events_select"
  ON hunt_events FOR SELECT
  TO authenticated
  USING (true);

-- 4. INSERT: roller der må oprette events
CREATE POLICY "hunt_events_insert"
  ON hunt_events FOR INSERT
  TO authenticated
  WITH CHECK (
    get_my_role() IN ('admin', 'jaeger_medlem', 'ejer', 'forvalter', 'bb_direktoer')
  );

-- 5. UPDATE: admin/jaeger_medlem/bb_direktoer alle, ejer/forvalter egne
CREATE POLICY "hunt_events_update"
  ON hunt_events FOR UPDATE
  TO authenticated
  USING (
    get_my_role() IN ('admin', 'jaeger_medlem', 'bb_direktoer')
    OR (get_my_role() IN ('ejer', 'forvalter') AND created_by = auth.uid())
  );

-- 6. DELETE: same som update
CREATE POLICY "hunt_events_delete"
  ON hunt_events FOR DELETE
  TO authenticated
  USING (
    get_my_role() IN ('admin', 'jaeger_medlem', 'bb_direktoer')
    OR (get_my_role() IN ('ejer', 'forvalter') AND created_by = auth.uid())
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

CREATE POLICY "event_signups_select"
  ON event_signups FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "event_signups_insert"
  ON event_signups FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "event_signups_update"
  ON event_signups FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id);

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
  USING (auth.uid() = user_id OR get_my_role() = 'admin');

-- =============================================
-- Fix profiles RLS - alle authenticated skal
-- kunne læse egen profil
-- =============================================

-- Tilføj policy så brugere kan læse egen profil
-- (hvis den ikke allerede eksisterer)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'profiles' AND policyname = 'profiles_select_own'
  ) THEN
    CREATE POLICY "profiles_select_own"
      ON profiles FOR SELECT
      TO authenticated
      USING (id = auth.uid());
  END IF;
END $$;

-- Tilføj policy så alle authenticated kan læse alle profiler
-- (behøves for deltagerlister, chat, etc.)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'profiles' AND policyname = 'profiles_select_all'
  ) THEN
    CREATE POLICY "profiles_select_all"
      ON profiles FOR SELECT
      TO authenticated
      USING (true);
  END IF;
END $$;

-- =============================================
-- Verificer
-- =============================================
SELECT tablename, policyname, cmd
FROM pg_policies
WHERE tablename IN ('hunt_events', 'event_signups', 'event_comments', 'profiles')
ORDER BY tablename, cmd;
