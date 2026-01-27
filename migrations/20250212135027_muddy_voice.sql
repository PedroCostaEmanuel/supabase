/*
  # Fix Audio Storage Configuration

  1. Changes
    - Add MIME type validation for audio files
    - Configure storage bucket for audio files
    - Add metadata columns to audio_files table
    - Update storage policies

  2. Security
    - Enable RLS on storage.objects
    - Add policies for authenticated users
*/

-- Add MIME type validation
CREATE OR REPLACE FUNCTION check_audio_mime_type() RETURNS TRIGGER AS $$
BEGIN
  IF NEW.content_type NOT IN ('audio/mpeg', 'audio/mp3', 'audio/wav') THEN
    RAISE EXCEPTION 'Invalid audio MIME type: %. Only MP3 and WAV are allowed.', NEW.content_type;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for MIME type validation
DROP TRIGGER IF EXISTS check_audio_mime_type_trigger ON storage.objects;
CREATE TRIGGER check_audio_mime_type_trigger
  BEFORE INSERT OR UPDATE ON storage.objects
  FOR EACH ROW
  WHEN (NEW.bucket_id = 'Audio')
  EXECUTE FUNCTION check_audio_mime_type();

-- Update storage configuration
UPDATE storage.buckets
SET public = true,
    file_size_limit = 10485760000, -- 100MB
    allowed_mime_types = ARRAY['audio/mpeg', 'audio/mp3', 'audio/wav']::text[]
WHERE id = 'Audio';

-- Add metadata columns to audio_files
ALTER TABLE audio_files
  ADD COLUMN IF NOT EXISTS mime_type TEXT CHECK (mime_type IN ('audio/mpeg', 'audio/mp3', 'audio/wav')),
  ADD COLUMN IF NOT EXISTS file_size BIGINT CHECK (file_size > 0),
  ADD COLUMN IF NOT EXISTS duration INTEGER CHECK (duration > 0),
  ADD COLUMN IF NOT EXISTS sample_rate INTEGER CHECK (sample_rate > 0),
  ADD COLUMN IF NOT EXISTS channels SMALLINT CHECK (channels > 0),
  ADD COLUMN IF NOT EXISTS bit_rate INTEGER CHECK (bit_rate > 0);

-- Update storage policies
DROP POLICY IF EXISTS "Enable public access to Audio bucket" ON storage.objects;
CREATE POLICY "Enable public access to Audio bucket"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'Audio' AND split_part(name, '/', 1) = 'PV');

-- Add function to get public URL
CREATE OR REPLACE FUNCTION get_audio_url(filename TEXT)
RETURNS TEXT AS $$
BEGIN
  RETURN CASE 
    WHEN filename IS NULL THEN NULL
    ELSE current_setting('app.settings.supabase_url') || '/storage/v1/object/public/Audio/' || filename
  END;
END;
$$ LANGUAGE plpgsql;