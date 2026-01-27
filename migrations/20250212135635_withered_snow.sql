-- Drop existing trigger and function
DROP TRIGGER IF EXISTS check_audio_mime_type_trigger ON storage.objects;
DROP FUNCTION IF EXISTS check_audio_mime_type();

-- Update storage configuration
UPDATE storage.buckets
SET public = true,
    file_size_limit = 10485760000, -- 100MB
    allowed_mime_types = ARRAY['audio/mpeg', 'audio/mp3', 'audio/wav', 'audio/m4a', 'audio/x-m4a']::text[]
WHERE id = 'Audio';

-- Update storage policies for better access control
DROP POLICY IF EXISTS "Enable public access to Audio bucket" ON storage.objects;
CREATE POLICY "Enable public access to Audio bucket"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'Audio');

-- Enable upload for authenticated users
CREATE POLICY "Enable upload for authenticated users"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (bucket_id = 'Audio');

-- Add metadata columns to audio_files if they don't exist
DO $$ BEGIN
  ALTER TABLE audio_files
    ADD COLUMN IF NOT EXISTS mime_type TEXT,
    ADD COLUMN IF NOT EXISTS file_size BIGINT,
    ADD COLUMN IF NOT EXISTS duration INTEGER,
    ADD COLUMN IF NOT EXISTS sample_rate INTEGER,
    ADD COLUMN IF NOT EXISTS channels SMALLINT,
    ADD COLUMN IF NOT EXISTS bit_rate INTEGER;
EXCEPTION
  WHEN duplicate_column THEN NULL;
END $$;

-- Add constraints after ensuring columns exist
ALTER TABLE audio_files
  DROP CONSTRAINT IF EXISTS audio_files_mime_type_check,
  ADD CONSTRAINT audio_files_mime_type_check 
    CHECK (mime_type IS NULL OR mime_type IN ('audio/mpeg', 'audio/mp3', 'audio/wav', 'audio/m4a', 'audio/x-m4a')),
  DROP CONSTRAINT IF EXISTS audio_files_file_size_check,
  ADD CONSTRAINT audio_files_file_size_check 
    CHECK (file_size IS NULL OR file_size > 0),
  DROP CONSTRAINT IF EXISTS audio_files_duration_check,
  ADD CONSTRAINT audio_files_duration_check 
    CHECK (duration IS NULL OR duration > 0),
  DROP CONSTRAINT IF EXISTS audio_files_sample_rate_check,
  ADD CONSTRAINT audio_files_sample_rate_check 
    CHECK (sample_rate IS NULL OR sample_rate > 0),
  DROP CONSTRAINT IF EXISTS audio_files_channels_check,
  ADD CONSTRAINT audio_files_channels_check 
    CHECK (channels IS NULL OR channels > 0),
  DROP CONSTRAINT IF EXISTS audio_files_bit_rate_check,
  ADD CONSTRAINT audio_files_bit_rate_check 
    CHECK (bit_rate IS NULL OR bit_rate > 0);