-- Fix: channel_members har brug for en bredere SELECT policy
-- saa Supabase Realtime kan levere updates til medlemmer.
-- Den eksisterende policy lader kun brugere se EGNE memberships,
-- men chat_messages SELECT-policyen laver subquery paa channel_members
-- som ogsaa skal virke for andre brugeres raekker.

-- Tilfoej policy: medlemmer af en kanal kan se andre medlemmer i samme kanal
DROP POLICY IF EXISTS "Members can see co-members" ON channel_members;
CREATE POLICY "Members can see co-members" ON channel_members
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM channel_members my
      WHERE my.channel_id = channel_members.channel_id
        AND my.user_id = auth.uid()
    )
  );
