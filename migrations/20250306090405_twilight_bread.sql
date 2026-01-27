-- Create function to handle audio file errors and retries
CREATE OR REPLACE FUNCTION handle_audio_file_error()
RETURNS TRIGGER AS $$
DECLARE
  retry_count INTEGER;
  max_retries INTEGER := 3;
  webhook_url TEXT;
BEGIN
  -- Only proceed if status changed to 'error'
  IF NEW.status = 'error' THEN
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

    -- Get current retry count from metadata, default to 0 if not set
    retry_count := COALESCE((NEW.metadata->>'retry_count')::INTEGER, 0);

    -- Check if we haven't exceeded max retries
    IF retry_count < max_retries THEN
      -- Increment retry count
      retry_count := retry_count + 1;

      -- Update metadata with new retry count
      NEW.metadata := jsonb_set(
        COALESCE(NEW.metadata, '{}'::jsonb),
        '{retry_count}',
        to_jsonb(retry_count)
      );

      -- Make HTTP request to webhook (assuming net.http_post exists)
      PERFORM net.http_post(
        url := webhook_url,
        headers := '{"Content-Type": "application/json"}'::jsonb,
        body := jsonb_build_object(
          'id', NEW.id,
          'file_name', NEW.filename,
          'storage_path', NEW.storage_path,
          'size', NEW.size,
          'status', NEW.status::text,
          'meeting_id', NEW.meeting_id
        )::jsonb
      );

      -- Update status back to 'pending'
      NEW.status := 'pending';
      
      -- Add retry timestamp to metadata
      NEW.metadata := jsonb_set(
        NEW.metadata,
        '{last_retry_at}',
        to_jsonb(CURRENT_TIMESTAMP)
      );

      RETURN NEW;

    ELSE
      -- Max retries reached, update metadata
      NEW.metadata := jsonb_set(
        COALESCE(NEW.metadata, '{}'::jsonb),
        '{max_retries_reached}',
        'true'::jsonb
      );
      
      -- Add timestamp when max retries was reached
      NEW.metadata := jsonb_set(
        NEW.metadata,
        '{max_retries_reached_at}',
        to_jsonb(CURRENT_TIMESTAMP)
      );

      RETURN NEW;
    END IF;
  END IF;

  -- If the status is not 'error', return the row unchanged
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for audio file error handling
CREATE TRIGGER handle_audio_file_error_trigger
  BEFORE UPDATE ON audio_files
  FOR EACH ROW
  WHEN (OLD.status IS DISTINCT FROM 'error' AND NEW.status = 'error')
  EXECUTE FUNCTION handle_audio_file_error();

-- Add comment to explain the trigger
COMMENT ON TRIGGER handle_audio_file_error_trigger ON audio_files IS 
  'Handles retries for failed audio processing with max 3 attempts';