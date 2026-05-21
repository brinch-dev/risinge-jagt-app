-- Drop old homepage_content table (migrated to blocks)
-- DROP TABLE IF EXISTS homepage_content;

-- Homepage blocks for dynamic front page
CREATE TABLE IF NOT EXISTS homepage_blocks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  block_type TEXT NOT NULL DEFAULT 'text',
  title TEXT,
  content TEXT,
  image_url TEXT,
  icon TEXT,
  sort_order INT NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  visible_roles TEXT[] DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- block_type values:
--   'hero'         - Hero section (title, subtitle in content, image_url)
--   'welcome'      - Welcome text (title, content as subtitle)
--   'text'         - Free text block (title, content)
--   'announcement' - Highlighted announcement (title, content)
--   'info_cards'   - Auto info cards (events, chat) - no editable content
--   'image'        - Image block (image_url, title as caption)

-- Seed default blocks
INSERT INTO homepage_blocks (block_type, title, content, sort_order, visible_roles) VALUES
  ('hero', 'Risinge Jagtvæsen', 'Jagt, natur og fællesskab', 1, '{}'),
  ('welcome', 'Velkommen til Risinge Jagtvæsen', 'Jagt, natur og fællesskab på Risinge Herregård', 2, '{}'),
  ('info_cards', 'Overblik', NULL, 3, '{}'),
  ('text', 'Om Risinge', 'Risinge Herregård byder velkommen til en unik jagtoplevelse i hjertet af Fyn. Her mødes tradition og natur i smukke omgivelser.', 4, '{}'),
  ('announcement', 'Sæsonstart', 'Husk tilmelding til sæsonens første jagt senest 1. september.', 5, '{}')
ON CONFLICT DO NOTHING;

-- RLS
ALTER TABLE homepage_blocks ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Homepage blocks viewable by authenticated" ON homepage_blocks
  FOR SELECT TO authenticated USING (TRUE);

CREATE POLICY "Homepage blocks manageable by admin" ON homepage_blocks
  FOR ALL TO authenticated
  USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );
