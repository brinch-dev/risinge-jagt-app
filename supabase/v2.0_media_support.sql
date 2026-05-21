-- v2.0: Media support for towers and chat

-- 1. Add image_urls to towers
ALTER TABLE towers ADD COLUMN IF NOT EXISTS image_urls TEXT[] DEFAULT '{}';

-- 2. Add media fields to chat_messages
ALTER TABLE chat_messages ADD COLUMN IF NOT EXISTS message_type TEXT NOT NULL DEFAULT 'text';
ALTER TABLE chat_messages ADD COLUMN IF NOT EXISTS media_url TEXT;
ALTER TABLE chat_messages ADD COLUMN IF NOT EXISTS media_type TEXT;

-- message_type: 'text', 'image', 'video'
-- media_url: public URL to the file
-- media_type: MIME type (image/jpeg, video/mp4, etc.)

-- 3. Create storage bucket for tower images
INSERT INTO storage.buckets (id, name, public)
VALUES ('towers', 'towers', TRUE)
ON CONFLICT (id) DO NOTHING;

-- 4. Create storage bucket for chat media
INSERT INTO storage.buckets (id, name, public)
VALUES ('chat', 'chat', TRUE)
ON CONFLICT (id) DO NOTHING;

-- 5. Storage policies for towers bucket
CREATE POLICY "Tower images viewable by authenticated" ON storage.objects
  FOR SELECT TO authenticated
  USING (bucket_id = 'towers');

CREATE POLICY "Tower images uploadable by admin" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'towers'
    AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

CREATE POLICY "Tower images deletable by admin" ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'towers'
    AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- 6. Storage policies for chat bucket
CREATE POLICY "Chat media viewable by authenticated" ON storage.objects
  FOR SELECT TO authenticated
  USING (bucket_id = 'chat');

CREATE POLICY "Chat media uploadable by authenticated" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'chat');

CREATE POLICY "Chat media deletable by owner" ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'chat'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );
