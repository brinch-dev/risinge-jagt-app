-- Test admin log entries for all types
INSERT INTO admin_log (type, message, user_name, created_at) VALUES
  ('new_user', 'Anders Brinch oprettede en konto', 'Anders Brinch', NOW() - INTERVAL '2 hours'),
  ('event_signup', 'Anders Brinch tilmeldt Morgen-jagt Dyrehaven', 'Anders Brinch', NOW() - INTERVAL '1 hour 50 minutes'),
  ('event_unsignup', 'Lars Jensen afmeldt Aften-jagt Gribskov', 'Lars Jensen', NOW() - INTERVAL '1 hour 40 minutes'),
  ('geofence_warning', 'Anders Brinch er 45m fra graensen af Dyrehaven', 'Anders Brinch', NOW() - INTERVAL '1 hour 30 minutes'),
  ('geofence_outside', 'Lars Jensen er uden for Gribskov', 'Lars Jensen', NOW() - INTERVAL '1 hour 20 minutes'),
  ('reservation', 'Anders Brinch reserverede Taarn Nord til Morgen-jagt Dyrehaven', 'Anders Brinch', NOW() - INTERVAL '1 hour 10 minutes'),
  ('reservation_cancel', 'Lars Jensen annullerede reservation af Taarn Syd til Aften-jagt Gribskov', 'Lars Jensen', NOW() - INTERVAL '1 hour'),
  ('event_created', 'Admin oprettede event: Weekend-jagt Nordskoven', 'Admin', NOW() - INTERVAL '50 minutes'),
  ('area_created', 'Admin oprettede omraade: Nordskoven', 'Admin', NOW() - INTERVAL '40 minutes'),
  ('broadcast', 'Admin sendte broadcast: Husk jagtpas til loerdag', 'Admin', NOW() - INTERVAL '30 minutes'),
  ('role_change', 'Lars Jensen rolle aendret fra Gaest til Medlem', 'Lars Jensen', NOW() - INTERVAL '20 minutes');
