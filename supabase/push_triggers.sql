-- Push notification triggers
-- Kalder Edge Function "send-push" via pg_net naar der oprettes chat-beskeder eller broadcasts

-- Aktiver pg_net extension
CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;

-- ============================================
-- TRIGGER: Ny chat-besked → push til kanal-medlemmer
-- ============================================
CREATE OR REPLACE FUNCTION handle_new_chat_message()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  PERFORM net.http_post(
    url := 'https://zbmpptfddowmchuyrrea.supabase.co/functions/v1/send-push',
    headers := '{"Content-Type": "application/json"}'::jsonb,
    body := jsonb_build_object(
      'type', 'chat_message',
      'channel_id', NEW.channel_id,
      'sender_id', NEW.sender_id,
      'content', LEFT(NEW.content, 120)
    )
  );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_new_chat_message ON chat_messages;
CREATE TRIGGER on_new_chat_message
  AFTER INSERT ON chat_messages
  FOR EACH ROW
  EXECUTE FUNCTION handle_new_chat_message();

-- ============================================
-- TRIGGER: Ny broadcast/notifikation → push til alle
-- ============================================
CREATE OR REPLACE FUNCTION handle_new_notification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Kun send push for broadcast-type notifikationer
  IF NEW.type = 'broadcast' OR NEW.type = 'new_event' THEN
    PERFORM net.http_post(
      url := 'https://zbmpptfddowmchuyrrea.supabase.co/functions/v1/send-push',
      headers := '{"Content-Type": "application/json"}'::jsonb,
      body := jsonb_build_object(
        'type', CASE WHEN NEW.type = 'broadcast' THEN 'broadcast' ELSE 'event_notification' END,
        'title', NEW.title,
        'message', LEFT(NEW.body, 200),
        'exclude_user_id', NEW.sender_id,
        'sender_id', NEW.sender_id
      )
    );
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_new_notification ON app_notifications;
CREATE TRIGGER on_new_notification
  AFTER INSERT ON app_notifications
  FOR EACH ROW
  EXECUTE FUNCTION handle_new_notification();
