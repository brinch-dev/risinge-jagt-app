-- Fix: chat_channels SELECT policy now allows creator to see their own channels
-- This fixes the error when creating private/group channels, because the
-- .select() after INSERT couldn't read back the row before channel_members were added.

DROP POLICY IF EXISTS "General channels viewable by members/admins" ON chat_channels;

CREATE POLICY "General channels viewable by members/admins"
  ON chat_channels FOR SELECT TO authenticated
  USING (
    created_by = auth.uid()
    OR (type = 'general' AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('member', 'admin')))
    OR EXISTS (SELECT 1 FROM channel_members WHERE channel_id = id AND user_id = auth.uid())
  );
