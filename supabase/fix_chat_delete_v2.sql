-- Fix: Allow admin and channel creator to delete messages and members
-- so cascade delete works from the app

-- chat_messages: allow delete by admin or message sender
DROP POLICY IF EXISTS "Users can delete own messages" ON chat_messages;
CREATE POLICY "Users can delete own messages" ON chat_messages
  FOR DELETE TO authenticated
  USING (
    user_id = auth.uid()
    OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- channel_members: allow delete by admin or the member themselves
DROP POLICY IF EXISTS "Members can leave channels" ON channel_members;
CREATE POLICY "Members can leave channels" ON channel_members
  FOR DELETE TO authenticated
  USING (
    user_id = auth.uid()
    OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- chat_channels: allow admin to delete any non-predefined channel
DROP POLICY IF EXISTS "Members can delete own channels" ON chat_channels;
CREATE POLICY "Members can delete own channels" ON chat_channels
  FOR DELETE TO authenticated
  USING (
    (is_predefined IS NOT TRUE) AND (
      created_by = auth.uid()
      OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
    )
  );
