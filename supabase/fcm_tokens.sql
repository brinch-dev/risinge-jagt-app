-- FCM push notification tokens
CREATE TABLE IF NOT EXISTS fcm_tokens (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE UNIQUE,
  token TEXT NOT NULL,
  platform TEXT NOT NULL DEFAULT 'android',
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE fcm_tokens ENABLE ROW LEVEL SECURITY;

-- Brugere kan kun se/opdatere deres egne tokens
DROP POLICY IF EXISTS "Bruger kan se egen token" ON fcm_tokens;
CREATE POLICY "Bruger kan se egen token" ON fcm_tokens
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Bruger kan indsaette egen token" ON fcm_tokens;
CREATE POLICY "Bruger kan indsaette egen token" ON fcm_tokens
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Bruger kan opdatere egen token" ON fcm_tokens;
CREATE POLICY "Bruger kan opdatere egen token" ON fcm_tokens
  FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Bruger kan slette egen token" ON fcm_tokens;
CREATE POLICY "Bruger kan slette egen token" ON fcm_tokens
  FOR DELETE USING (auth.uid() = user_id);

-- Admin kan laese alle tokens (til at sende push)
DROP POLICY IF EXISTS "Admin kan laese alle tokens" ON fcm_tokens;
CREATE POLICY "Admin kan laese alle tokens" ON fcm_tokens
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );
