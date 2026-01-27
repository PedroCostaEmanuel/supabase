/*
  # Shared Constants and Audio Configuration Migration

  1. Purpose
    - Creates shared_constants table for configuration
    - Sets up audio file validation rules
    - Configures storage bucket settings
    - Ensures proper access control

  2. Changes
    - Creates shared_constants table
    - Adds audio configuration constants
    - Updates storage bucket settings
    - Sets up RLS policies
*/

-- Create shared_constants table if it doesn't exist
CREATE TABLE IF NOT EXISTS shared_constants (
  key TEXT PRIMARY KEY,
  value JSONB NOT NULL,
  description TEXT,
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Drop existing policy if it exists
DROP POLICY IF EXISTS "Allow read access to shared constants" ON shared_constants;

-- Insert or update audio configuration
INSERT INTO shared_constants (key, value, description)
VALUES (
  'AUDIO_CONFIG',
  jsonb_build_object(
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
  'Audio file configuration constants'
)
ON CONFLICT (key) DO UPDATE
SET value = EXCLUDED.value,
    description = EXCLUDED.description,
    updated_at = now();

-- Update storage bucket configuration using LATERAL join
UPDATE storage.buckets b
SET allowed_mime_types = mime_types.array_value,
    file_size_limit = (
      SELECT (value->>'MAX_FILE_SIZE')::bigint
      FROM shared_constants
      WHERE key = 'AUDIO_CONFIG'
    )
FROM (
  SELECT array_agg(mime_type) as array_value
  FROM shared_constants,
       jsonb_array_elements_text(value->'VALID_MIME_TYPES') as mime_type
  WHERE key = 'AUDIO_CONFIG'
) mime_types
WHERE b.id = 'Audio';

-- Create function to get configuration
CREATE OR REPLACE FUNCTION get_audio_config()
RETURNS JSONB AS $$
  SELECT value
  FROM shared_constants
  WHERE key = 'AUDIO_CONFIG';
$$ LANGUAGE sql STABLE;

-- Add RLS policies
ALTER TABLE shared_constants ENABLE ROW LEVEL SECURITY;

-- Create new policy
CREATE POLICY "Allow read access to shared constants"
  ON shared_constants FOR SELECT
  TO authenticated
  USING (true);