-- ============================================
-- DUMMY DATA til test af Jagt-App
-- Koer EFTER at mindst 1 admin bruger er oprettet
-- ============================================

-- Saet din bruger til admin (udskift email hvis noedvendigt)
UPDATE profiles SET role = 'admin', display_name = 'Anders Brinch', full_name = 'Anders Brinch'
WHERE email = 'brinchanders@gmail.com';

-- Hent admin bruger id
DO $$
DECLARE
  admin_id UUID;
  test_user_id UUID;
  area1_id UUID;
  area2_id UUID;
  channel_id UUID;
BEGIN
  SELECT id INTO admin_id FROM profiles WHERE email = 'brinchanders@gmail.com';

  -- Opret jagtomraader
  area1_id := gen_random_uuid();
  area2_id := gen_random_uuid();

  INSERT INTO hunt_areas (id, name, center_lat, center_lng, radius_meters, description, created_by)
  VALUES
    (area1_id, 'Dyrehaven', 55.7717, 12.5794, 800, 'Hovedjagtomraade - Dyrehaven nord', admin_id),
    (area2_id, 'Gribskov', 55.9833, 12.2833, 1200, 'Stort skovomraade - Gribskov', admin_id);

  -- Opret jagttaarne
  INSERT INTO towers (name, lat, lng, area_id, description)
  VALUES
    ('Taarn Nord', 55.7740, 12.5780, area1_id, 'Nordligt udsigstaarn med god sigt'),
    ('Taarn Syd', 55.7695, 12.5810, area1_id, 'Sydligt taarn ved soeen'),
    ('Taarn Vest', 55.7720, 12.5750, area1_id, 'Vestligt taarn i skovkanten'),
    ('Gribskov Hovedtaarn', 55.9850, 12.2850, area2_id, 'Centralt taarn i Gribskov'),
    ('Gribskov Oesttaarn', 55.9820, 12.2900, area2_id, 'OEstligt taarn med udsigt over sletten');

  -- Opret jagt-events
  INSERT INTO hunt_events (title, description, date, start_time, end_time, area_id, created_by)
  VALUES
    ('Morgen-jagt Dyrehaven', 'Tidlig morgenjagt i Dyrehaven. Moed op ved hovedtaarn.', CURRENT_DATE + INTERVAL '2 days', '06:00', '10:00', area1_id, admin_id),
    ('Aften-jagt Gribskov', 'Aftenjagt i Gribskov. Samlingssted ved parkeringspladsen.', CURRENT_DATE + INTERVAL '5 days', '16:00', '20:00', area2_id, admin_id),
    ('Weekendjagt', 'Stor weekendjagt for alle medlemmer. Froekost inkluderet.', CURRENT_DATE + INTERVAL '7 days', '08:00', '16:00', area1_id, admin_id),
    ('Nyjaegers introduktion', 'Introduktionsjagt for nye jaegere. Erfarne jaegere som guides.', CURRENT_DATE + INTERVAL '14 days', '09:00', '14:00', area2_id, admin_id),
    ('Maanedlig jagt-dag', 'Fast maanedlig jagtdag. Alle velkommen.', CURRENT_DATE + INTERVAL '30 days', '07:00', '15:00', area1_id, admin_id);

  -- Opret generel chat-kanal
  channel_id := gen_random_uuid();
  INSERT INTO chat_channels (id, name, type, created_by, last_message, last_message_at)
  VALUES (channel_id, 'Generel Chat', 'general', admin_id, 'Velkommen til Jagt-App!', NOW());

  -- Tilfoej dummy chat-beskeder
  INSERT INTO chat_messages (channel_id, sender_id, content, created_at)
  VALUES
    (channel_id, admin_id, 'Velkommen til Jagt-App! Her kan vi koordinere jagter.', NOW() - INTERVAL '2 hours'),
    (channel_id, admin_id, 'Husk at tjekke kalenderen for kommende events.', NOW() - INTERVAL '1 hour'),
    (channel_id, admin_id, 'Naeste jagt er i Dyrehaven om 2 dage. Alle er velkomne!', NOW() - INTERVAL '30 minutes');

END $$;
