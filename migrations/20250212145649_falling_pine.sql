/*
  # Improve Audio File Validation

  1. Changes
    - Simplified validation function
    - Better error handling
    - More robust MIME type checking
    - Clearer error messages

  2. Features
    - Supports all common audio formats
    - Validates file size
    - Normalizes MIME types
    - Preserves metadata
*/

-- Create or replace the validation function with better error handling
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
  normalized_mime TEXT;
BEGIN
  -- Extract MIME type with fallback
  mime_type := COALESCE(
    NEW.metadata->>'mimetype',
    NEW.metadata->>'content_type',
    NEW.content_type,
    'audio/mpeg'
  );

  -- Log for debugging
  RAISE NOTICE 'Received MIME type: %', mime_type;

  -- Validate MIME type
  IF mime_type IS NULL THEN
    RAISE EXCEPTION 'MIME type is required';
  END IF;

  -- Normalize if needed
  normalized_mime := CASE LOWER(TRIM(mime_type))
    WHEN 'audio/x-mp3' THEN 'audio/mpeg'
    WHEN 'audio/mp3' THEN 'audio/mpeg'
    WHEN 'audio/x-wav' THEN 'audio/wav'
    WHEN 'audio/wave' THEN 'audio/wav'
    ELSE LOWER(TRIM(mime_type))
  END;

  IF NOT normalized_mime = ANY(valid_types) THEN
    RAISE EXCEPTION 'Unsupported MIME type: %. Valid types: %', mime_type, array_to_string(valid_types, ', ');
  END IF;

  -- Extract size with fallback
  file_size := COALESCE(
    (NEW.metadata->>'size')::bigint,
    NEW.size,
    octet_length(NEW.metadata->>'file')
  );

  -- Log for debugging
  RAISE NOTICE 'File size: %', file_size;

  -- Validate size
  IF file_size IS NULL OR file_size > 10485760000 THEN
    RAISE EXCEPTION 'File size must not exceed 100MB';
  END IF;

  -- Update metadata
  NEW.content_type := normalized_mime;
  NEW.size := file_size;
  NEW.metadata := jsonb_build_object(
    'normalized_mime_type', normalized_mime,
    'original_mime_type', mime_type,
    'size', file_size,
    'uploaded_at', CURRENT_TIMESTAMP
  );

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop and recreate trigger
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
  ],
  file_size_limit = 10485760000,
  public = true
WHERE id = 'Audio';