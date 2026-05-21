-- Fjern den cirkulaere co-members policy (den kan blokere queries)
DROP POLICY IF EXISTS "Members can see co-members" ON channel_members;

-- Erstat med en simpel policy: admin kan se alle memberships
DROP POLICY IF EXISTS "Admin kan se alle memberships" ON channel_members;
CREATE POLICY "Admin kan se alle memberships" ON channel_members
  FOR SELECT TO authenticated
  USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );
