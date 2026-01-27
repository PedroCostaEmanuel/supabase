/*
  # Fix Storage Trigger and Metadata

  1. Storage Objects
    - Add metadata columns for content type and size
    - Update trigger to use metadata

  2. Functions
    - Update validation function to handle metadata
*/

-- Add metadata columns to storage.objects if they don't exist
ALTER TABLE storage.objects
  ADD COLUMN IF NOT EXISTS content_type TEXT,
  ADD COLUMN IF NOT EXISTS size BIGINT;

-- Update trigger function to use metadata
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
  mime_type := NEW.metadata->>'content_type';
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

  -- Store metadata in dedicated columns for better querying
  NEW.content_type := mime_type;
  NEW.size := file_size;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Recreate trigger
DROP TRIGGER IF EXISTS validate_audio_file_trigger ON storage.objects;
CREATE TRIGGER validate_audio_file_trigger
  BEFORE INSERT OR UPDATE ON storage.objects
  FOR EACH ROW
  WHEN (NEW.bucket_id = 'Audio')
  EXECUTE FUNCTION validate_audio_file_trigger();