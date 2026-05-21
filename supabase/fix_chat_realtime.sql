-- Aktiver realtime for channel_members og chat_channels
-- Saa nye kanaler og medlemskaber vises automatisk

DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE channel_members;
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE chat_channels;
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;
