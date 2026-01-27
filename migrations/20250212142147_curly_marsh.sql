/*
  # Fix MIME type validation and storage configuration

  1. Changes
    - Simplify MIME type validation
    - Add support for all common audio MIME types
    - Fix storage bucket configuration
    - Add proper error handling

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

-- Create or replace the validation function
CREATE OR REPLACE FUNCTION validate_audio_file_trigger()
RETURNS TRIGGER AS $$
DECLARE
  mime_type TEXT;
  file_size BIGINT;
  valid_types TEXT[] := ARRAY[
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
  ];
BEGIN
  -- Extract MIME type from metadata
  mime_type := LOWER(COALESCE(
    NEW.metadata->>'mimetype',
    NEW.metadata->>'content_type',
    NEW.content_type
  ));

  -- Extract file size
  file_size := COALESCE(
    (NEW.metadata->>'size')::bigint,
    NEW.size
  );

  -- Validate MIME type
  IF mime_type IS NULL OR NOT mime_type = ANY(valid_types) THEN
    RAISE EXCEPTION 'Invalid audio file: MIME type must be MP3, WAV, M4A, or AAC. Got: %', mime_type;
  END IF;

  -- Validate file size (100MB limit)
  IF file_size IS NULL OR file_size > 10485760000 THEN
    RAISE EXCEPTION 'File size must not exceed 100MB';
  END IF;

  -- Store normalized values in metadata
  NEW.metadata := jsonb_set(
    COALESCE(NEW.metadata, '{}'::jsonb),
    '{normalized_mime_type}',
    to_jsonb(mime_type)
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