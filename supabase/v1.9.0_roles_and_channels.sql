-- v1.9.0: New role system + predefined chat channels with role-based access

-- 1. Add new columns to chat_channels
ALTER TABLE chat_channels ADD COLUMN IF NOT EXISTS required_roles text[] DEFAULT '{}';
ALTER TABLE chat_channels ADD COLUMN IF NOT EXISTS is_predefined boolean DEFAULT false;
ALTER TABLE chat_channels ADD COLUMN IF NOT EXISTS sort_order integer DEFAULT 0;

-- 2. Migrate existing roles
UPDATE profiles SET role = 'gaest' WHERE role = 'guest';
UPDATE profiles SET role = 'jaeger_medlem' WHERE role = 'member';
-- admin stays as 'admin'

-- 3. Delete existing general channels (will be recreated as predefined)
DELETE FROM chat_messages WHERE channel_id IN (
  SELECT id FROM chat_channels WHERE type = 'general'
);
DELETE FROM channel_members WHERE channel_id IN (
  SELECT id FROM chat_channels WHERE type = 'general'
);
DELETE FROM chat_channels WHERE type = 'general';

-- 4. Create predefined chat channels
INSERT INTO chat_channels (name, type, created_by, is_predefined, required_roles, sort_order)
VALUES (
  'Admin Chat',
  'general',
  (SELECT id FROM profiles WHERE role = 'admin' LIMIT 1),
  true,
  ARRAY['admin', 'ejer', 'forvalter'],
  1
);

INSERT INTO chat_channels (name, type, created_by, is_predefined, required_roles, sort_order)
VALUES (
  'Jægermedlems Chat',
  'general',
  (SELECT id FROM profiles WHERE role = 'admin' LIMIT 1),
  true,
  ARRAY['admin', 'jaeger_medlem'],
  2
);

INSERT INTO chat_channels (name, type, created_by, is_predefined, required_roles, sort_order)
VALUES (
  'Jæger Gæst Chat',
  'general',
  (SELECT id FROM profiles WHERE role = 'admin' LIMIT 1),
  true,
  ARRAY['admin', 'bb_direktoer', 'jagt_gaest'],
  3
);

INSERT INTO chat_channels (name, type, created_by, is_predefined, required_roles, sort_order)
VALUES (
  'B&B Chat',
  'general',
  (SELECT id FROM profiles WHERE role = 'admin' LIMIT 1),
  true,
  ARRAY['bb_direktoer', 'gaest'],
  4
);

INSERT INTO chat_channels (name, type, created_by, is_predefined, required_roles, sort_order)
VALUES (
  'Generel Chat',
  'general',
  (SELECT id FROM profiles WHERE role = 'admin' LIMIT 1),
  true,
  ARRAY['admin', 'jaeger_medlem', 'ejer', 'forvalter', 'bb_direktoer'],
  99
);

-- 5. Add check-out support to event_checkins
ALTER TABLE event_checkins ADD COLUMN IF NOT EXISTS checked_out_at timestamptz;
