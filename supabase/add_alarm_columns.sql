-- Tilfoej alarm-kolonner til hunt_areas
ALTER TABLE hunt_areas ADD COLUMN IF NOT EXISTS alarm_text TEXT DEFAULT 'Advarsel: Du naermer dig jagtomraadets graense! Vend om.';
ALTER TABLE hunt_areas ADD COLUMN IF NOT EXISTS alarm_margin_meters DOUBLE PRECISION DEFAULT 100;
