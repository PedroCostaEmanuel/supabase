-- Drop existing trigger and function
DROP TRIGGER IF EXISTS validate_audio_file_trigger ON storage.objects;
DROP FUNCTION IF EXISTS validate_audio_file_trigger();

-- Create new validation function that handles metadata properly
CREATE OR REPLACE FUNCTION validate_audio_file_trigger()
RETURNS TRIGGER AS $$
DECLARE
  config JSONB;
  mime_type TEXT;
  file_size BIGINT;
BEGIN
  -- Get configuration
  SELECT value INTO config
  FROM shared_constants
  WHERE key = 'AUDIO_CONFIG';

  -- Extract metadata from NEW record
  mime_type := NEW.metadata->>'mimetype';
  IF mime_type IS NULL THEN
    mime_type := NEW.metadata->>'content_type';
  END IF;
  file_size := (NEW.metadata->>'size')::bigint;

  -- Validate MIME type and file size
  IF mime_type IS NULL OR NOT mime_type = ANY(ARRAY(
    SELECT jsonb_array_elements_text(config->'VALID_MIME_TYPES')
  )) THEN
    RAISE EXCEPTION 'Invalid audio file: MIME type must be one of (%)',
      array_to_string(ARRAY(
        SELECT jsonb_array_elements_text(config->'VALID_MIME_TYPES')
      ), ', ');
  END IF;

  IF file_size IS NULL OR file_size > (config->>'MAX_FILE_SIZE')::bigint THEN
    RAISE EXCEPTION 'File size must not exceed %MB',
      (config->>'MAX_FILE_SIZE')::bigint / 1024 / 1024;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Recreate trigger
CREATE TRIGGER validate_audio_file_trigger
  BEFORE INSERT OR UPDATE ON storage.objects
  FOR EACH ROW
  WHEN (NEW.bucket_id = 'Audio')
  EXECUTE FUNCTION validate_audio_file_trigger();