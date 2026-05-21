-- Event-graenser: polygon-punkter tegnet af admin ved event-oprettelse
CREATE TABLE IF NOT EXISTS event_boundaries (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  event_id UUID NOT NULL REFERENCES hunt_events(id) ON DELETE CASCADE,
  point_order INT NOT NULL,
  latitude DOUBLE PRECISION NOT NULL,
  longitude DOUBLE PRECISION NOT NULL,
  UNIQUE(event_id, point_order)
);

ALTER TABLE event_boundaries ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Alle kan se event-graenser" ON event_boundaries;
CREATE POLICY "Alle kan se event-graenser" ON event_boundaries
  FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Admin kan oprette event-graenser" ON event_boundaries;
CREATE POLICY "Admin kan oprette event-graenser" ON event_boundaries
  FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

DROP POLICY IF EXISTS "Admin kan slette event-graenser" ON event_boundaries;
CREATE POLICY "Admin kan slette event-graenser" ON event_boundaries
  FOR DELETE TO authenticated
  USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );
