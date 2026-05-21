-- Medlemmer og admin kan slette ikke-generelle kanaler
DROP POLICY IF EXISTS "Members can delete own channels" ON chat_channels;
CREATE POLICY "Members can delete own channels" ON chat_channels
  FOR DELETE TO authenticated
  USING (
    type != 'general' AND (
      created_by = auth.uid()
      OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
    )
  );
