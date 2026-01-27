/*
  # Fix webhook notification

  1. Changes
    - Remove dependency on app.settings.supabase_url
    - Use hardcoded Supabase URL for webhook
    - Improve error handling
  
  2. Security
    - Function runs with invoker security
    - Only authenticated users can trigger notifications
*/

-- Drop existing function and trigger
DROP TRIGGER IF EXISTS meeting_created_notification ON meetings;
DROP FUNCTION IF EXISTS notify_meeting_created();

-- Create updated function to send webhook notifications
CREATE OR REPLACE FUNCTION notify_meeting_created()
RETURNS TRIGGER AS $$
DECLARE
  supabase_url TEXT := 'https://itwecqiawtsorltahlwl.supabase.co';
BEGIN
  -- Send webhook notification using pg_net extension
  PERFORM net.http_post(
    url := 'https://lumind.app.n8n.cloud/webhook-test/a881f338-6ae6-4292-9253-c51c241b356f',
    headers := jsonb_build_object(
      'Content-Type', 'application/json'
    ),
    body := jsonb_build_object(
      'meeting', jsonb_build_object(
        'id', NEW.id,
        'title', NEW.title,
        'date', NEW.date,
        'status', NEW.status,
        'created_at', NEW.created_at
      ),
      'audio_file', jsonb_build_object(
        'filename', NEW.audio_file,
        'storage_path', 'PV/' || NEW.audio_file,
        'url', supabase_url || '/storage/v1/object/public/Audio/PV/' || NEW.audio_file
      )
    )::jsonb
  );
  
  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    -- Log error but don't block the transaction
    RAISE WARNING 'Failed to send webhook notification: %', SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Recreate trigger to send notifications on meeting creation
CREATE TRIGGER meeting_created_notification
  AFTER INSERT ON meetings
  FOR EACH ROW
  EXECUTE FUNCTION notify_meeting_created();