-- Jagtomraade-graenser: polygon-punkter tegnet af admin ved omraade-oprettelse
CREATE TABLE IF NOT EXISTS area_boundaries (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  area_id UUID NOT NULL REFERENCES hunt_areas(id) ON DELETE CASCADE,
  point_order INT NOT NULL,
  latitude DOUBLE PRECISION NOT NULL,
  longitude DOUBLE PRECISION NOT NULL,
  UNIQUE(area_id, point_order)
);

ALTER TABLE area_boundaries ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Alle kan se omraade-graenser" ON area_boundaries;
CREATE POLICY "Alle kan se omraade-graenser" ON area_boundaries
  FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Admin kan oprette omraade-graenser" ON area_boundaries;
CREATE POLICY "Admin kan oprette omraade-graenser" ON area_boundaries
  FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

DROP POLICY IF EXISTS "Admin kan slette omraade-graenser" ON area_boundaries;
CREATE POLICY "Admin kan slette omraade-graenser" ON area_boundaries
  FOR DELETE TO authenticated
  USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );
