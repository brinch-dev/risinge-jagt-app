-- RENS OP i alt dummy data og opret forfra
DELETE FROM tower_reservations;
DELETE FROM chat_messages;
DELETE FROM channel_members;
DELETE FROM chat_channels;
DELETE FROM hunt_events;
DELETE FROM towers;
DELETE FROM hunt_areas;
DELETE FROM app_notifications;
DELETE FROM notification_reads;

DO $$
DECLARE
  admin_id UUID;
  area1_id UUID;
  area2_id UUID;
  channel_id UUID;
BEGIN
  SELECT id INTO admin_id FROM profiles WHERE email = 'brinchanders@gmail.com';

  -- Opret 2 jagtomraader
  area1_id := gen_random_uuid();
  area2_id := gen_random_uuid();

  INSERT INTO hunt_areas (id, name, center_lat, center_lng, radius_meters, description, created_by, alarm_text, alarm_margin_meters)
  VALUES
    (area1_id, 'Dyrehaven', 55.7717, 12.5794, 800, 'Hovedjagtomraade - Dyrehaven nord', admin_id, 'Advarsel: Du naermer dig Dyrehaven graense!', 150),
    (area2_id, 'Gribskov', 55.9833, 12.2833, 1200, 'Stort skovomraade - Gribskov', admin_id, 'Advarsel: Du naermer dig Gribskov graense!', 200);

  -- Opret 5 taarne (tilknyttet de rigtige areas)
  INSERT INTO towers (id, name, lat, lng, area_id, description, created_at)
  VALUES
    (gen_random_uuid(), 'Taarn Nord', 55.7740, 12.5780, area1_id, 'Nordligt udsigstaarn med god sigt', NOW()),
    (gen_random_uuid(), 'Taarn Syd', 55.7695, 12.5810, area1_id, 'Sydligt taarn ved soeen', NOW()),
    (gen_random_uuid(), 'Taarn Vest', 55.7720, 12.5750, area1_id, 'Vestligt taarn i skovkanten', NOW()),
    (gen_random_uuid(), 'Gribskov Hovedtaarn', 55.9850, 12.2850, area2_id, 'Centralt taarn i Gribskov', NOW()),
    (gen_random_uuid(), 'Gribskov Oesttaarn', 55.9820, 12.2900, area2_id, 'OEstligt taarn med udsigt over sletten', NOW());

  -- Opret 5 events (tilknyttet de rigtige areas)
  INSERT INTO hunt_events (title, description, date, start_time, end_time, area_id, created_by)
  VALUES
    ('Morgen-jagt Dyrehaven', 'Tidlig morgenjagt i Dyrehaven.', CURRENT_DATE + INTERVAL '2 days', '06:00', '10:00', area1_id, admin_id),
    ('Aften-jagt Gribskov', 'Aftenjagt i Gribskov.', CURRENT_DATE + INTERVAL '5 days', '16:00', '20:00', area2_id, admin_id),
    ('Weekendjagt', 'Stor weekendjagt for alle.', CURRENT_DATE + INTERVAL '7 days', '08:00', '16:00', area1_id, admin_id),
    ('Nyjaegers introduktion', 'Introduktionsjagt for nye jaegere.', CURRENT_DATE + INTERVAL '14 days', '09:00', '14:00', area2_id, admin_id),
    ('Maanedlig jagt-dag', 'Fast maanedlig jagtdag.', CURRENT_DATE + INTERVAL '30 days', '07:00', '15:00', area1_id, admin_id);

  -- Opret general chat
  channel_id := gen_random_uuid();
  INSERT INTO chat_channels (id, name, type, created_by, last_message, last_message_at)
  VALUES (channel_id, 'Generel Chat', 'general', admin_id, 'Velkommen til Jagt-App!', NOW());

  INSERT INTO chat_messages (channel_id, sender_id, content, created_at)
  VALUES
    (channel_id, admin_id, 'Velkommen til Jagt-App!', NOW() - INTERVAL '2 hours'),
    (channel_id, admin_id, 'Husk at tjekke kalenderen for kommende events.', NOW() - INTERVAL '1 hour'),
    (channel_id, admin_id, 'Naeste jagt er i Dyrehaven om 2 dage!', NOW() - INTERVAL '30 minutes');

  -- Opret test notifikation
  INSERT INTO app_notifications (type, title, body, sender_id, target_role)
  VALUES ('broadcast', 'Velkommen til Risinge Jagt!', 'Appen er nu klar. Tjek kalenderen for kommende jagter.', admin_id, 'all');

END $$;
