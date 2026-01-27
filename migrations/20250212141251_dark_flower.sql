/*
  # Shared Constants and Types

  1. Constants
    - Valid audio MIME types
    - Maximum file size
    - Storage paths
    - Status types

  2. Functions
    - Audio file validation
    - Storage path generation
    - URL generation

  3. Triggers
    - Automatic validation on file upload
*/

-- Create enum for valid audio MIME types
DO $$ BEGIN
  CREATE TYPE valid_audio_mime_type AS ENUM (
    'audio/mpeg',
    'audio/mp3',
    'audio/wav',
    'audio/m4a',
    'audio/x-m4a'
  );
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

-- Create constants table for shared configuration
CREATE TABLE IF NOT EXISTS shared_constants (
  key TEXT PRIMARY KEY,
  value JSONB NOT NULL,
  description TEXT,
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Insert shared constants with properly formatted JSONB array
INSERT INTO shared_constants (key, value, description)
VALUES
  ('AUDIO_CONFIG', jsonb_build_object(
    'MAX_FILE_SIZE', 10485760000,
    'VALID_MIME_TYPES', jsonb_build_array('audio/mpeg', 'audio/mp3', 'audio/wav', 'audio/m4a', 'audio/x-m4a'),
    'STORAGE_PATH', 'PV'
  ), 'Audio file configuration constants')
ON CONFLICT (key) DO UPDATE
SET value = EXCLUDED.value,
    description = EXCLUDED.description,
    updated_at = now();

INSERT INTO shared_constants (key, value, description)
VALUES
  ('BACKEND_URL', jsonb_build_object('url', 'http://host.docker.internal:8001'), 'URL of the backend that process audios and manage the agent')
ON CONFLICT (key) DO UPDATE
SET value = EXCLUDED.value,
    description = EXCLUDED.description,
    updated_at = now();

-- Create function to validate audio files
CREATE OR REPLACE FUNCTION validate_audio_file(
  mime_type TEXT,
  file_size BIGINT
) RETURNS BOOLEAN AS $$
DECLARE
  config JSONB;
BEGIN
  SELECT value INTO config
  FROM shared_constants
  WHERE key = 'AUDIO_CONFIG';

  RETURN
    mime_type = ANY(ARRAY(SELECT jsonb_array_elements_text(config->'VALID_MIME_TYPES')))
    AND file_size <= (config->>'MAX_FILE_SIZE')::bigint;
END;
$$ LANGUAGE plpgsql;

-- Create function to generate storage path
CREATE OR REPLACE FUNCTION generate_storage_path(filename TEXT)
RETURNS TEXT AS $$
DECLARE
  config JSONB;
  clean_filename TEXT;
BEGIN
  SELECT value INTO config
  FROM shared_constants
  WHERE key = 'AUDIO_CONFIG';

  -- Clean filename: lowercase, replace special chars with underscore
  clean_filename := lower(filename);
  clean_filename := regexp_replace(clean_filename, '[^a-z0-9.-]', '_', 'g');
  clean_filename := regexp_replace(clean_filename, '\.+', '.', 'g');
  clean_filename := trim(both '.' from clean_filename);

  RETURN config->>'STORAGE_PATH' || '/' || clean_filename;
END;
$$ LANGUAGE plpgsql;

-- Update storage bucket configuration
UPDATE storage.buckets
SET public = true,
    file_size_limit = (
      SELECT (value->>'MAX_FILE_SIZE')::bigint
      FROM shared_constants
      WHERE key = 'AUDIO_CONFIG'
    ),
    allowed_mime_types = ARRAY(
      SELECT jsonb_array_elements_text(value->'VALID_MIME_TYPES')
      FROM shared_constants
      WHERE key = 'AUDIO_CONFIG'
    )
WHERE id = 'Audio';

-- Create trigger function for audio file validation
CREATE OR REPLACE FUNCTION validate_audio_file_trigger()
RETURNS TRIGGER AS $$
BEGIN
  IF NOT validate_audio_file(NEW.content_type, NEW.size) THEN
    RAISE EXCEPTION 'Invalid audio file: MIME type must be one of (%) and size must not exceed %MB',
      (SELECT string_agg(mime_type::text, ', ')
       FROM (
         SELECT jsonb_array_elements_text(value->'VALID_MIME_TYPES') as mime_type
         FROM shared_constants
         WHERE key = 'AUDIO_CONFIG'
       ) t),
      (SELECT (value->>'MAX_FILE_SIZE')::bigint / 1024 / 1024
       FROM shared_constants
       WHERE key = 'AUDIO_CONFIG');
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for audio file validation
DROP TRIGGER IF EXISTS validate_audio_file_trigger ON storage.objects;
CREATE TRIGGER validate_audio_file_trigger
  BEFORE INSERT OR UPDATE ON storage.objects
  FOR EACH ROW
  WHEN (NEW.bucket_id = 'Audio')
  EXECUTE FUNCTION validate_audio_file_trigger();

-- Add RLS policies
ALTER TABLE shared_constants ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow read access to shared constants"
  ON shared_constants FOR SELECT
  TO authenticated
  USING (true);

-- Create function to get configuration
CREATE OR REPLACE FUNCTION get_audio_config()
RETURNS JSONB AS $$
  SELECT value
  FROM shared_constants
  WHERE key = 'AUDIO_CONFIG';
$$ LANGUAGE sql;