-- Create storage bucket for homepage images
INSERT INTO storage.buckets (id, name, public)
VALUES ('homepage', 'homepage', TRUE)
ON CONFLICT (id) DO NOTHING;

-- Allow authenticated users to view
CREATE POLICY "Homepage images viewable by all" ON storage.objects
  FOR SELECT TO authenticated
  USING (bucket_id = 'homepage');

-- Allow admins to upload/delete
CREATE POLICY "Homepage images uploadable by admin" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'homepage'
    AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

CREATE POLICY "Homepage images deletable by admin" ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'homepage'
    AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );
