-- Notifications tabel
CREATE TABLE IF NOT EXISTS app_notifications (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  type TEXT NOT NULL CHECK (type IN ('broadcast', 'new_event', 'chat_message', 'chat_general')),
  title TEXT NOT NULL,
  body TEXT,
  target_role TEXT DEFAULT 'all' CHECK (target_role IN ('all', 'member', 'admin')),
  sender_id UUID REFERENCES profiles(id),
  reference_id TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Laeste notifikationer per bruger
CREATE TABLE IF NOT EXISTS notification_reads (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  notification_id UUID NOT NULL REFERENCES app_notifications(id) ON DELETE CASCADE,
  read_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, notification_id)
);

-- RLS
ALTER TABLE app_notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE notification_reads ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Alle kan laese notifikationer" ON app_notifications;
CREATE POLICY "Alle kan laese notifikationer" ON app_notifications
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "Admin kan oprette notifikationer" ON app_notifications;
CREATE POLICY "Admin kan oprette notifikationer" ON app_notifications
  FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
    OR type IN ('chat_message', 'chat_general')
  );

DROP POLICY IF EXISTS "Bruger kan laese egne reads" ON notification_reads;
CREATE POLICY "Bruger kan laese egne reads" ON notification_reads
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Bruger kan markere som laest" ON notification_reads;
CREATE POLICY "Bruger kan markere som laest" ON notification_reads
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Realtime
ALTER PUBLICATION supabase_realtime ADD TABLE app_notifications;
