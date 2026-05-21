-- Tilfoej checkin_enabled toggle til events
ALTER TABLE hunt_events ADD COLUMN IF NOT EXISTS checkin_enabled BOOLEAN NOT NULL DEFAULT false;
