-- Homepage content table for editable front page
CREATE TABLE IF NOT EXISTS homepage_content (
  id TEXT PRIMARY KEY DEFAULT 'main',
  welcome_title TEXT NOT NULL DEFAULT 'Velkommen til Risinge Jagtvæsen',
  welcome_subtitle TEXT DEFAULT 'Jagt, natur og fællesskab på Risinge Herregård',
  body_text TEXT,
  image_urls TEXT[] DEFAULT '{}',
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_by UUID REFERENCES auth.users(id)
);

-- Seed default content
INSERT INTO homepage_content (id, welcome_title, welcome_subtitle, body_text) VALUES
  ('main',
   'Velkommen til Risinge Jagtvæsen',
   'Jagt, natur og fællesskab på Risinge Herregård',
   'Risinge Herregård byder velkommen til en unik jagtoplevelse i hjertet af Fyn. Her mødes tradition og natur i smukke omgivelser.'
  )
ON CONFLICT (id) DO NOTHING;

-- RLS
ALTER TABLE homepage_content ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Homepage viewable by authenticated" ON homepage_content
  FOR SELECT TO authenticated USING (TRUE);

CREATE POLICY "Homepage editable by admin" ON homepage_content
  FOR ALL TO authenticated
  USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );
