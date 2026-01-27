/*
  # Update webhook notification to include meeting details

  1. Changes
    - Add language_code and expected_participants to webhook payload
    - Join with meetings table to get additional data
    - Improve error handling and retry logic
*/

-- Drop existing function and trigger
DROP TRIGGER IF EXISTS audio_file_created_notification ON audio_files;
DROP FUNCTION IF EXISTS notify_audio_file_created();

-- Create or replace the webhook notification function
CREATE OR REPLACE FUNCTION notify_audio_file_created()
RETURNS TRIGGER AS $$
DECLARE
  webhook_url TEXT;
  retry_count INTEGER := 0;
  max_retries INTEGER := 3;
  meeting_data RECORD;
BEGIN
  -- Récupérer dynamiquement l'URL du webhook depuis la table config
  SELECT (value->>'url') || '/api/audio/new-audio'
  INTO webhook_url 
  FROM shared_constants 
  WHERE key = 'BACKEND_URL';

  -- Si aucune URL n'est trouvée, lever un avertissement et ne pas exécuter la requête
  IF webhook_url IS NULL THEN
    RAISE WARNING 'No webhook URL found in config';
    RETURN NEW;
  END IF;

  -- Get meeting data
  SELECT m.language_code, m.expected_participants
  INTO meeting_data
  FROM meetings m
  WHERE m.id = NEW.meeting_id;

  -- Retry loop for webhook reliability
  WHILE retry_count < max_retries LOOP
    BEGIN
      PERFORM net.http_post(
        url := webhook_url,
        headers := jsonb_build_object('Content-Type', 'application/json'),
        body := jsonb_build_object(
          'id', NEW.id,
          'file_name', NEW.filename,
          'storage_path', NEW.storage_path,
          'size', NEW.size,
          'status', NEW.status::text,
          'meeting_id', NEW.meeting_id,
          'language_code', meeting_data.language_code,
          'expected_participants', meeting_data.expected_participants
        )::jsonb
      );

      -- If we get here, the webhook was successful
      RETURN NEW;
    EXCEPTION
      WHEN OTHERS THEN
        -- Increment retry count
        retry_count := retry_count + 1;
        
        -- Log the error
        RAISE WARNING 'Webhook attempt % failed: %', retry_count, SQLERRM;
        
        -- Wait before retrying (exponential backoff)
        IF retry_count < max_retries THEN
          PERFORM pg_sleep(power(2, retry_count)::INTEGER);
        END IF;
    END;
  END LOOP;

  -- Log final failure but don't block the transaction
  RAISE WARNING 'Failed to send webhook notification after % attempts', max_retries;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for audio file notifications
CREATE TRIGGER audio_file_created_notification
  AFTER INSERT ON audio_files
  FOR EACH ROW
  EXECUTE FUNCTION notify_audio_file_created();