-- Create function to normalize MIME types
CREATE OR REPLACE FUNCTION normalize_mime_type(mime_type TEXT)
RETURNS TEXT AS $$
BEGIN
  RETURN CASE LOWER(mime_type)
    WHEN 'audio/x-mp3' THEN 'audio/mpeg'
    WHEN 'audio/mp3' THEN 'audio/mpeg'
    WHEN 'audio/x-wav' THEN 'audio/wav'
    WHEN 'audio/wave' THEN 'audio/wav'
    WHEN 'audio/x-m4a' THEN 'audio/m4a'
    ELSE LOWER(mime_type)
  END;
END;
$$ LANGUAGE plpgsql;

-- Create function to validate MIME type
CREATE OR REPLACE FUNCTION is_valid_mime_type(mime_type TEXT)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN normalize_mime_type(mime_type) IN (
    'audio/mpeg',
    'audio/wav',
    'audio/m4a',
    'audio/mp4',
    'audio/aac'
  );
END;
$$ LANGUAGE plpgsql;

-- Create function to get current date folder
CREATE OR REPLACE FUNCTION get_current_date_folder()
RETURNS TEXT AS $$
BEGIN
  RETURN to_char(CURRENT_DATE, 'DD_MM_YYYY');
END;
$$ LANGUAGE plpgsql;

-- Create or replace the validation function
CREATE OR REPLACE FUNCTION validate_audio_file_trigger()
RETURNS TRIGGER AS $$
DECLARE
  mime_type TEXT;
  normalized_mime TEXT;
  file_size BIGINT;
  date_folder TEXT;
BEGIN
  -- Get current date folder
  date_folder := get_current_date_folder();

  -- Extract MIME type from metadata
  mime_type := COALESCE(
    NEW.metadata->>'mimetype',
    NEW.metadata->>'content_type',
    NEW.content_type
  );

  -- Normalize MIME type
  normalized_mime := normalize_mime_type(mime_type);

  -- Extract file size
  file_size := COALESCE(
    (NEW.metadata->>'size')::bigint,
    NEW.size
  );

  -- Validate MIME type
  IF NOT is_valid_mime_type(mime_type) THEN
    RAISE EXCEPTION 'Invalid audio file: MIME type must be MP3, WAV, M4A, or AAC. Got: %', mime_type;
  END IF;

  -- Validate file size (100MB limit)
  IF file_size IS NULL OR file_size > 10485760000 THEN
    RAISE EXCEPTION 'File size must not exceed 100MB';
  END IF;

  -- Update path to use date folder if not already present
  IF NOT NEW.name ~ '^[0-9]{2}_[0-9]{2}_[0-9]{4}/' THEN
    NEW.name := date_folder || '/' || NEW.name;
  END IF;

  -- Store normalized metadata
  NEW.metadata := jsonb_build_object(
    'normalized_mime_type', normalized_mime,
    'original_mime_type', mime_type,
    'size', file_size,
    'date_folder', date_folder
  );

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop and recreate the trigger
DROP TRIGGER IF EXISTS validate_audio_file_trigger ON storage.objects;
CREATE TRIGGER validate_audio_file_trigger
  BEFORE INSERT OR UPDATE ON storage.objects
  FOR EACH ROW
  WHEN (NEW.bucket_id = 'Audio')
  EXECUTE FUNCTION validate_audio_file_trigger();

-- Update storage bucket configuration
UPDATE storage.buckets
SET allowed_mime_types = ARRAY[
  'audio/mpeg',
  'audio/mp3',
  'audio/x-mp3',
  'audio/wav',
  'audio/x-wav',
  'audio/wave',
  'audio/m4a',
  'audio/x-m4a',
  'audio/mp4',
  'audio/aac'
]::text[],
file_size_limit = 10485760000
WHERE id = 'Audio';