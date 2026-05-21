-- Fix: Chat RLS policies bruger nested subqueries gennem RLS-beskyttede tabeller,
-- hvilket kan give tomme resultater. Erstat med SECURITY DEFINER funktioner.

-- Helper function: check om en bruger kan se en kanal (bypasser RLS)
CREATE OR REPLACE FUNCTION can_access_channel(p_channel_id UUID, p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM chat_channels WHERE id = p_channel_id AND type = 'general'
  )
  OR EXISTS (
    SELECT 1 FROM channel_members WHERE channel_id = p_channel_id AND user_id = p_user_id
  )
  OR EXISTS (
    SELECT 1 FROM chat_channels WHERE id = p_channel_id AND created_by = p_user_id
  );
$$;

-- 1. Fix chat_channels SELECT policy
DROP POLICY IF EXISTS "General channels viewable by members/admins" ON chat_channels;
CREATE POLICY "Channels viewable by authorized users"
  ON chat_channels FOR SELECT TO authenticated
  USING (can_access_channel(id, auth.uid()));

-- 2. Fix chat_messages SELECT policy
DROP POLICY IF EXISTS "Messages viewable by channel members" ON chat_messages;
CREATE POLICY "Messages viewable by channel members"
  ON chat_messages FOR SELECT TO authenticated
  USING (can_access_channel(channel_id, auth.uid()));

-- 3. Sørg for at channel_members DELETE policy eksisterer (for admin channel deletion)
DROP POLICY IF EXISTS "Admin can delete members" ON channel_members;
CREATE POLICY "Admin can delete members" ON channel_members
  FOR DELETE TO authenticated
  USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
    OR user_id = auth.uid()
  );
