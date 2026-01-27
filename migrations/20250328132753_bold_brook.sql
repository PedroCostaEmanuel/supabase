/*
  # Add webhook notification for transcription segment updates

  1. Changes
    - Create trigger function to send webhook notifications when transcription segments are updated
    - Only send notification if text or speaker_id has changed
    - Include old and new values in payload
    - Add retry mechanism with exponential backoff
*/

-- Create or replace the webhook notification function
CREATE OR REPLACE FUNCTION notify_transcription_segment_updated()
RETURNS TRIGGER AS $$
DECLARE
  webhook_url TEXT;
  retry_count INTEGER := 0;
  max_retries INTEGER := 3;
  meeting_id UUID;
BEGIN
  -- Only proceed if text or speaker_id has changed
  IF NEW.text = OLD.text AND NEW.speaker_id = OLD.speaker_id THEN
    RETURN NEW;
  END IF;

  -- Get meeting_id
  meeting_id := NEW.meeting_id;

  -- Get webhook URL from config
  SELECT (value->>'url') || '/api/transcript/update_segment'
  INTO webhook_url 
  FROM shared_constants 
  WHERE key = 'BACKEND_URL';

  -- If no URL found, log warning and exit
  IF webhook_url IS NULL THEN
    RAISE WARNING 'No webhook URL found in config';
    RETURN NEW;
  END IF;

  -- Retry loop with exponential backoff
  WHILE retry_count < max_retries LOOP
    BEGIN
      PERFORM net.http_post(
        url := webhook_url,
        headers := jsonb_build_object('Content-Type', 'application/json'),
        body := jsonb_build_object(
          'segment_id', NEW.id,
          'meeting_id', meeting_id,
          'old_text', OLD.text,
          'old_speaker_id', OLD.speaker_id,
          'new_text', NEW.text,
          'new_speaker_id', NEW.speaker_id
        )::jsonb
      );

      -- If we get here, webhook was successful
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

-- Create trigger for transcription segment updates
DROP TRIGGER IF EXISTS transcription_segment_updated_notification ON transcription_segments;
CREATE TRIGGER transcription_segment_updated_notification
  AFTER UPDATE ON transcription_segments
  FOR EACH ROW
  EXECUTE FUNCTION notify_transcription_segment_updated();

-- Add comment explaining the trigger
COMMENT ON TRIGGER transcription_segment_updated_notification ON transcription_segments IS 
  'Sends webhook notification when transcription segment text or speaker_id is updated';