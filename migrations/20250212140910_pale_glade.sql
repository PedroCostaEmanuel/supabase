/*
  # Add webhook notification for meetings

  1. New Function
    - Create a function to send webhook notifications when meetings are created
    - Include meeting and audio file details in the payload
  
  2. Security
    - Function runs with invoker security for safety
    - Only authenticated users can trigger notifications
*/

-- Create a function to send webhook notifications
CREATE OR REPLACE FUNCTION notify_meeting_created()
RETURNS TRIGGER AS $$
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
        'url', current_setting('app.settings.supabase_url') || '/storage/v1/object/public/Audio/PV/' || NEW.audio_file
      )
    )::jsonb
  );
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to send notifications on meeting creation
DROP TRIGGER IF EXISTS meeting_created_notification ON meetings;
CREATE TRIGGER meeting_created_notification
  AFTER INSERT ON meetings
  FOR EACH ROW
  EXECUTE FUNCTION notify_meeting_created();

-- Enable pg_net extension if not already enabled
CREATE EXTENSION IF NOT EXISTS pg_net;