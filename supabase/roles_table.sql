-- Roles table for dynamic role management
CREATE TABLE IF NOT EXISTS roles (
  id TEXT PRIMARY KEY,
  label TEXT NOT NULL,
  sort_order INT NOT NULL DEFAULT 0,
  is_system BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Seed with existing roles
INSERT INTO roles (id, label, sort_order, is_system) VALUES
  ('admin', 'Admin', 1, TRUE),
  ('jaeger_medlem', 'Jæger Medlem', 2, FALSE),
  ('ejer', 'Ejer', 3, FALSE),
  ('forvalter', 'Forvalter', 4, FALSE),
  ('bb_direktoer', 'B&B Direktør', 5, FALSE),
  ('jagt_gaest', 'Jagt Gæst', 6, FALSE),
  ('gaest', 'Gæst', 7, TRUE)
ON CONFLICT (id) DO NOTHING;

-- RLS
ALTER TABLE roles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Roles viewable by authenticated" ON roles
  FOR SELECT TO authenticated USING (TRUE);

CREATE POLICY "Roles manageable by admin" ON roles
  FOR ALL TO authenticated
  USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );
