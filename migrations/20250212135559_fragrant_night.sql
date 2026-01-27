-- Add M4A support to audio validation
CREATE OR REPLACE FUNCTION check_audio_mime_type() RETURNS TRIGGER AS $$
BEGIN
  IF NEW.content_type NOT IN ('audio/mpeg', 'audio/mp3', 'audio/wav', 'audio/m4a', 'audio/x-m4a') THEN
    RAISE EXCEPTION 'Invalid audio MIME type: %. Only MP3, WAV and M4A are allowed.', NEW.content_type;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Update storage configuration for M4A support
UPDATE storage.buckets
SET public = true,
    file_size_limit = 10485760000, -- 100MB
    allowed_mime_types = ARRAY['audio/mpeg', 'audio/mp3', 'audio/wav', 'audio/m4a', 'audio/x-m4a']::text[]
WHERE id = 'Audio';

-- Update audio_files table constraints
ALTER TABLE audio_files
  DROP CONSTRAINT IF EXISTS audio_files_mime_type_check,
  ADD CONSTRAINT audio_files_mime_type_check 
    CHECK (mime_type IN ('audio/mpeg', 'audio/mp3', 'audio/wav', 'audio/m4a', 'audio/x-m4a'));