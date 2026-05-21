-- Jagt-App Supabase Database Schema
-- Sikkert at køre på eksisterende database (DROP IF EXISTS + CREATE IF NOT EXISTS)

-- ============================================
-- PROFILES (opdater eksisterende tabel)
-- ============================================

-- Tilføj manglende kolonner hvis de ikke eksisterer
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS role TEXT DEFAULT 'guest';
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS display_name TEXT DEFAULT '';
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS avatar_url TEXT;

-- Drop eksisterende policies og genskab
DROP POLICY IF EXISTS "Profiles are viewable by authenticated users" ON profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON profiles;
DROP POLICY IF EXISTS "Users can insert own profile" ON profiles;
DROP POLICY IF EXISTS "Admins can update all profiles" ON profiles;
DROP POLICY IF EXISTS "Enable read access for all users" ON profiles;
DROP POLICY IF EXISTS "Enable insert for authenticated users only" ON profiles;
DROP POLICY IF EXISTS "Enable update for users based on id" ON profiles;

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Profiles are viewable by authenticated users"
  ON profiles FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Users can update own profile"
  ON profiles FOR UPDATE
  TO authenticated
  USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile"
  ON profiles FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = id);

CREATE POLICY "Admins can update all profiles"
  ON profiles FOR UPDATE
  TO authenticated
  USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- Auto-create profile on signup
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO profiles (id, email, display_name, role)
  VALUES (NEW.id, NEW.email, COALESCE(NEW.raw_user_meta_data->>'display_name', ''), 'guest')
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION handle_new_user();

-- ============================================
-- HUNT AREAS
-- ============================================
CREATE TABLE IF NOT EXISTS hunt_areas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  center_lat DOUBLE PRECISION NOT NULL,
  center_lng DOUBLE PRECISION NOT NULL,
  radius_meters DOUBLE PRECISION NOT NULL,
  description TEXT,
  created_by UUID NOT NULL REFERENCES profiles(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE hunt_areas ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Hunt areas viewable by all authenticated" ON hunt_areas;
DROP POLICY IF EXISTS "Admins can manage hunt areas" ON hunt_areas;

CREATE POLICY "Hunt areas viewable by all authenticated"
  ON hunt_areas FOR SELECT TO authenticated USING (true);

CREATE POLICY "Admins can manage hunt areas"
  ON hunt_areas FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'));

-- ============================================
-- TOWERS
-- ============================================
CREATE TABLE IF NOT EXISTS towers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  lat DOUBLE PRECISION NOT NULL,
  lng DOUBLE PRECISION NOT NULL,
  area_id UUID REFERENCES hunt_areas(id) ON DELETE SET NULL,
  description TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE towers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Towers viewable by all authenticated" ON towers;
DROP POLICY IF EXISTS "Admins can manage towers" ON towers;

CREATE POLICY "Towers viewable by all authenticated"
  ON towers FOR SELECT TO authenticated USING (true);

CREATE POLICY "Admins can manage towers"
  ON towers FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'));

-- ============================================
-- HUNT EVENTS
-- ============================================
CREATE TABLE IF NOT EXISTS hunt_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  description TEXT,
  date DATE NOT NULL,
  start_time TEXT,
  end_time TEXT,
  area_id UUID REFERENCES hunt_areas(id) ON DELETE SET NULL,
  created_by UUID NOT NULL REFERENCES profiles(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE hunt_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Events viewable by members and admins" ON hunt_events;
DROP POLICY IF EXISTS "Admins can manage events" ON hunt_events;

CREATE POLICY "Events viewable by members and admins"
  ON hunt_events FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('member', 'admin')));

CREATE POLICY "Admins can manage events"
  ON hunt_events FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'));

-- ============================================
-- CHAT CHANNELS (tabel først, policies efter channel_members)
-- ============================================
CREATE TABLE IF NOT EXISTS chat_channels (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  type TEXT NOT NULL DEFAULT 'general' CHECK (type IN ('general', 'private', 'group')),
  created_by UUID NOT NULL REFERENCES profiles(id),
  last_message TEXT,
  last_message_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================
-- CHANNEL MEMBERS (skal oprettes FØR chat_channels policies)
-- ============================================
CREATE TABLE IF NOT EXISTS channel_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  channel_id UUID NOT NULL REFERENCES chat_channels(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(channel_id, user_id)
);

ALTER TABLE channel_members ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Members can view their memberships" ON channel_members;
DROP POLICY IF EXISTS "Members can join channels" ON channel_members;

CREATE POLICY "Members can view their memberships"
  ON channel_members FOR SELECT TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "Members can join channels"
  ON channel_members FOR INSERT TO authenticated
  WITH CHECK (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('member', 'admin')));

-- ============================================
-- CHAT CHANNELS POLICIES (nu kan de referere channel_members)
-- ============================================
ALTER TABLE chat_channels ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "General channels viewable by members/admins" ON chat_channels;
DROP POLICY IF EXISTS "Members can create channels" ON chat_channels;
DROP POLICY IF EXISTS "Channel update by members" ON chat_channels;

CREATE POLICY "General channels viewable by members/admins"
  ON chat_channels FOR SELECT TO authenticated
  USING (
    created_by = auth.uid()
    OR (type = 'general' AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('member', 'admin')))
    OR EXISTS (SELECT 1 FROM channel_members WHERE channel_id = id AND user_id = auth.uid())
  );

CREATE POLICY "Members can create channels"
  ON chat_channels FOR INSERT TO authenticated
  WITH CHECK (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('member', 'admin')));

CREATE POLICY "Channel update by members"
  ON chat_channels FOR UPDATE TO authenticated
  USING (true);

-- ============================================
-- CHAT MESSAGES
-- ============================================
CREATE TABLE IF NOT EXISTS chat_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  channel_id UUID NOT NULL REFERENCES chat_channels(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES profiles(id),
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Messages viewable by channel members" ON chat_messages;
DROP POLICY IF EXISTS "Members can send messages" ON chat_messages;

CREATE POLICY "Messages viewable by channel members"
  ON chat_messages FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM chat_channels c
      WHERE c.id = channel_id AND (
        c.type = 'general'
        OR EXISTS (SELECT 1 FROM channel_members cm WHERE cm.channel_id = c.id AND cm.user_id = auth.uid())
      )
    )
  );

CREATE POLICY "Members can send messages"
  ON chat_messages FOR INSERT TO authenticated
  WITH CHECK (sender_id = auth.uid());

-- ============================================
-- REALTIME
-- ============================================
DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE chat_messages;
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;
