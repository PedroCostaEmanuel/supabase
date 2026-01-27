/*
  # Update Audio Configuration and Utility Functions

  1. Changes
    - Update audio configuration with expanded MIME types
    - Add utility functions for MIME type handling
    - Update storage bucket configuration

  2. Security
    - No changes to RLS policies
*/

-- Update audio configuration with expanded MIME types
UPDATE shared_constants
SET value = jsonb_build_object(
  'MAX_FILE_SIZE', 10485760000,
  'VALID_MIME_TYPES', jsonb_build_array(
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
  ),
  'NORMALIZED_MIME_TYPES', jsonb_build_object(
    'audio/x-mp3', 'audio/mpeg',
    'audio/mp3', 'audio/mpeg',
    'audio/x-wav', 'audio/wav',
    'audio/wave', 'audio/wav',
    'audio/x-m4a', 'audio/m4a'
  ),
  'STORAGE_PATH', 'PV'
),
updated_at = now()
WHERE key = 'AUDIO_CONFIG';

-- Create function to normalize MIME type
CREATE OR REPLACE FUNCTION normalize_mime_type(mime_type TEXT)
RETURNS TEXT AS $$
DECLARE
  config JSONB;
  normalized TEXT;
BEGIN
  -- Get configuration
  SELECT value INTO config
  FROM shared_constants
  WHERE key = 'AUDIO_CONFIG';

  -- Get normalized MIME type from configuration
  normalized := config->'NORMALIZED_MIME_TYPES'->mime_type;

  -- Return normalized type if found, otherwise return original
  RETURN COALESCE(normalized, mime_type);
END;
$$ LANGUAGE plpgsql STABLE;

-- Create function to validate MIME type
CREATE OR REPLACE FUNCTION is_valid_mime_type(mime_type TEXT)
RETURNS BOOLEAN AS $$
DECLARE
  config JSONB;
BEGIN
  -- Get configuration
  SELECT value INTO config
  FROM shared_constants
  WHERE key = 'AUDIO_CONFIG';

  -- Check if normalized MIME type is in valid types
  RETURN normalize_mime_type(mime_type) = ANY(
    ARRAY(SELECT jsonb_array_elements_text(config->'VALID_MIME_TYPES'))
  );
END;
$$ LANGUAGE plpgsql STABLE;

-- Update storage bucket configuration
UPDATE storage.buckets
SET allowed_mime_types = ARRAY(
  SELECT jsonb_array_elements_text(value->'VALID_MIME_TYPES')
  FROM shared_constants
  WHERE key = 'AUDIO_CONFIG'
),
file_size_limit = (
  SELECT (value->>'MAX_FILE_SIZE')::bigint
  FROM shared_constants
  WHERE key = 'AUDIO_CONFIG'
)
WHERE id = 'Audio';