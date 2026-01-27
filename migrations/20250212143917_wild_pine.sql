/*
  # Fix MIME type validation and storage configuration

  1. Changes
    - Drop existing triggers and functions for a clean slate
    - Create new MIME type validation function with proper metadata handling
    - Update storage bucket configuration
    - Add proper RLS policies
    - Add performance optimizations

  2. Security
    - Enable RLS on storage bucket
    - Add proper policies for authenticated users
    - Validate file size and MIME types
*/

-- Drop existing triggers and functions for clean slate
DROP TRIGGER IF EXISTS validate_audio_file_trigger ON storage.objects;
DROP FUNCTION IF EXISTS validate_audio_file_trigger();
DROP FUNCTION IF EXISTS normalize_mime_type();
DROP FUNCTION IF EXISTS is_valid_mime_type();
DROP FUNCTION IF EXISTS get_current_date_folder();

-- Create type for valid audio MIME types
DO $$ BEGIN
  CREATE TYPE valid_audio_mime AS ENUM (
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
  );
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

-- Create function to get current date folder
CREATE OR REPLACE FUNCTION get_current_date_folder()
RETURNS TEXT AS $$
BEGIN
  RETURN to_char(CURRENT_DATE, 'DD_MM_YYYY');
END;
$$ LANGUAGE plpgsql STABLE;

-- Create function to normalize MIME types
CREATE OR REPLACE FUNCTION normalize_mime_type(mime_type TEXT)
RETURNS TEXT AS $$
BEGIN
  -- Handle null input
  IF mime_type IS NULL THEN
    RETURN NULL;
  END IF;

  -- Normalize and validate MIME type
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
  date_folder := get_current_date_folder();

  -- Extract MIME type from metadata or content_type
  mime_type := COALESCE(
    NEW.metadata->>'mimetype',
    NEW.metadata->>'content_type',
    NEW.content_type
  );

  IF mime_type IS NULL THEN
    RAISE EXCEPTION 'MIME type is required';
  END IF;

  -- Normalize MIME type
  normalized_mime := normalize_mime_type(mime_type);

  -- Validate MIME type
  IF normalized_mime NOT IN (
    'audio/mpeg',
    'audio/wav',
    'audio/m4a',
    'audio/mp4',
    'audio/aac'
  ) THEN
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
    'date_folder', date_folder,
    'uploaded_at', CURRENT_TIMESTAMP
  );

  -- Update content_type and size columns
  NEW.content_type := normalized_mime;
  NEW.size := file_size;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for audio file validation
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

-- Add indexes for better performance
CREATE INDEX IF NOT EXISTS idx_storage_objects_mime ON storage.objects(content_type) WHERE bucket_id = 'Audio';
CREATE INDEX IF NOT EXISTS idx_storage_objects_date ON storage.objects((metadata->>'date_folder')) WHERE bucket_id = 'Audio';
CREATE INDEX IF NOT EXISTS idx_storage_objects_size ON storage.objects(size) WHERE bucket_id = 'Audio';

-- Update RLS policies for better security
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow public read access to Audio bucket" ON storage.objects;
CREATE POLICY "Allow public read access to Audio bucket"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'Audio');

DROP POLICY IF EXISTS "Allow authenticated upload to Audio bucket" ON storage.objects;
CREATE POLICY "Allow authenticated upload to Audio bucket"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'Audio' AND
    size <= 10485760000
  );