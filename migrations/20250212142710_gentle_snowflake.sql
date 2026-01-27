-- Drop existing trigger and functions
DROP TRIGGER IF EXISTS validate_audio_file_trigger ON storage.objects;
DROP FUNCTION IF EXISTS validate_audio_file_trigger();
DROP FUNCTION IF EXISTS normalize_mime_type();
DROP FUNCTION IF EXISTS is_valid_mime_type();

-- Create function to normalize MIME types with better handling
CREATE OR REPLACE FUNCTION normalize_mime_type(mime_type TEXT)
RETURNS TEXT AS $$
BEGIN
  -- Handle null input
  IF mime_type IS NULL THEN
    RETURN NULL;
  END IF;

  -- Normalize MIME type
  RETURN CASE LOWER(TRIM(mime_type))
    WHEN 'audio/x-mp3' THEN 'audio/mpeg'
    WHEN 'audio/mp3' THEN 'audio/mpeg'
    WHEN 'audio/x-wav' THEN 'audio/wav'
    WHEN 'audio/wave' THEN 'audio/wav'
    WHEN 'audio/x-m4a' THEN 'audio/m4a'
    ELSE LOWER(TRIM(mime_type))
  END;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

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
$$ LANGUAGE plpgsql IMMUTABLE;

-- Create or replace the validation function with better error handling
CREATE OR REPLACE FUNCTION validate_audio_file_trigger()
RETURNS TRIGGER AS $$
DECLARE
  mime_type TEXT;
  normalized_mime TEXT;
  file_size BIGINT;
  date_folder TEXT;
  max_size BIGINT := 10485760000; -- 100MB
BEGIN
  -- Get current date folder
  date_folder := to_char(CURRENT_DATE, 'DD_MM_YYYY');

  -- Extract and validate MIME type
  mime_type := COALESCE(
    NEW.metadata->>'mimetype',
    NEW.metadata->>'content_type',
    NEW.content_type
  );

  IF mime_type IS NULL THEN
    RAISE EXCEPTION 'MIME type is required';
  END IF;

  normalized_mime := normalize_mime_type(mime_type);

  IF NOT is_valid_mime_type(mime_type) THEN
    RAISE EXCEPTION 'Invalid audio file: MIME type must be MP3, WAV, M4A, or AAC. Got: %', mime_type;
  END IF;

  -- Extract and validate file size
  file_size := COALESCE(
    (NEW.metadata->>'size')::bigint,
    NEW.size
  );

  IF file_size IS NULL THEN
    RAISE EXCEPTION 'File size is required';
  END IF;

  IF file_size > max_size THEN
    RAISE EXCEPTION 'File size must not exceed 100MB. Got: %MB', (file_size::float / 1024 / 1024)::numeric(10,2);
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

  -- Update content_type and size columns
  NEW.content_type := normalized_mime;
  NEW.size := file_size;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Recreate trigger
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
file_size_limit = 10485760000, -- 100MB
public = true
WHERE id = 'Audio';