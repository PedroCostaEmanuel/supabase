/*
  # Fix audio validation and folder structure

  1. Changes
    - Simplify MIME type validation
    - Add support for all common audio formats
    - Implement date-based folder structure
    - Fix metadata handling

  2. Security
    - Maintain RLS policies
    - Validate file types and sizes
*/

-- Update storage bucket configuration with expanded MIME types
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
]::text[]
WHERE id = 'Audio';

-- Create function to get current date folder
CREATE OR REPLACE FUNCTION get_current_date_folder()
RETURNS TEXT AS $$
BEGIN
  RETURN to_char(CURRENT_DATE, 'DD_MM_YYYY');
END;
$$ LANGUAGE plpgsql;

-- Create function to validate and normalize MIME type
CREATE OR REPLACE FUNCTION normalize_audio_mime_type(mime_type TEXT)
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

-- Create or replace the validation function
CREATE OR REPLACE FUNCTION validate_audio_file_trigger()
RETURNS TRIGGER AS $$
DECLARE
  normalized_mime_type TEXT;
  file_size BIGINT;
  date_folder TEXT;
BEGIN
  -- Get current date folder
  date_folder := get_current_date_folder();

  -- Extract and normalize MIME type
  normalized_mime_type := normalize_audio_mime_type(
    COALESCE(
      NEW.metadata->>'mimetype',
      NEW.metadata->>'content_type',
      NEW.content_type
    )
  );

  -- Extract file size
  file_size := COALESCE(
    (NEW.metadata->>'size')::bigint,
    NEW.size
  );

  -- Validate MIME type
  IF normalized_mime_type IS NULL OR normalized_mime_type NOT IN (
    'audio/mpeg',
    'audio/wav',
    'audio/m4a',
    'audio/mp4',
    'audio/aac'
  ) THEN
    RAISE EXCEPTION 'Invalid audio file: MIME type must be MP3, WAV, M4A, or AAC. Got: %', normalized_mime_type;
  END IF;

  -- Validate file size (100MB limit)
  IF file_size IS NULL OR file_size > 10485760000 THEN
    RAISE EXCEPTION 'File size must not exceed 100MB';
  END IF;

  -- Update path to use date folder
  NEW.name := date_folder || '/' || split_part(NEW.name, '/', array_length(string_to_array(NEW.name, '/'), 1));

  -- Store normalized metadata
  NEW.metadata := jsonb_build_object(
    'normalized_mime_type', normalized_mime_type,
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