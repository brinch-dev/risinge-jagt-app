-- Opret public storage bucket til app-releases
INSERT INTO storage.buckets (id, name, public)
VALUES ('app-releases', 'app-releases', true)
ON CONFLICT (id) DO NOTHING;

-- Alle kan laese (download APK og version.json)
DROP POLICY IF EXISTS "Public read app-releases" ON storage.objects;
CREATE POLICY "Public read app-releases" ON storage.objects
  FOR SELECT TO public
  USING (bucket_id = 'app-releases');

-- Kun admin kan uploade
DROP POLICY IF EXISTS "Admin upload app-releases" ON storage.objects;
CREATE POLICY "Admin upload app-releases" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'app-releases'
    AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- Admin kan overskrive/slette
DROP POLICY IF EXISTS "Admin update app-releases" ON storage.objects;
CREATE POLICY "Admin update app-releases" ON storage.objects
  FOR UPDATE TO authenticated
  USING (
    bucket_id = 'app-releases'
    AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

DROP POLICY IF EXISTS "Admin delete app-releases" ON storage.objects;
CREATE POLICY "Admin delete app-releases" ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'app-releases'
    AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );
