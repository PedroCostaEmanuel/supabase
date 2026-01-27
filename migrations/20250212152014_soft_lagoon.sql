/*
  # Audio file management improvements

  1. Functions
    - `get_date_folder()`: Generates folder name in DDMMYYYY format
    - `validate_audio_metadata()`: Validates and normalizes audio metadata
    - `handle_audio_file_creation()`: Manages audio file creation with proper folder structure

  2. Changes
    - Add trigger to automatically handle audio file creation
    - Add metadata column and indexes
    - Add storage path validation
*/

-- Create function to get date folder name
CREATE OR REPLACE FUNCTION get_date_folder()
RETURNS TEXT AS $$
BEGIN
  RETURN to_char(CURRENT_DATE, 'DDMMYYYY');
END;
$$ LANGUAGE plpgsql STABLE;

-- Create function to validate and normalize audio metadata
CREATE OR REPLACE FUNCTION validate_audio_metadata(
  p_content_type TEXT,
  p_size BIGINT,
  p_filename TEXT
)
RETURNS JSONB AS $$
DECLARE
  normalized_type TEXT;
  folder_name TEXT;
BEGIN
  -- Get current date folder
  folder_name := get_date_folder();

  -- Normalize content type
  normalized_type := CASE LOWER(p_content_type)
    WHEN 'audio/x-mp3' THEN 'audio/mpeg'
    WHEN 'audio/mp3' THEN 'audio/mpeg'
    WHEN 'audio/x-wav' THEN 'audio/wav'
    WHEN 'audio/wave' THEN 'audio/wav'
    WHEN 'audio/x-m4a' THEN 'audio/m4a'
    ELSE LOWER(p_content_type)
  END;

  -- Validate content type
  IF normalized_type NOT IN (
    'audio/mpeg',
    'audio/wav',
    'audio/m4a',
    'audio/mp4',
    'audio/aac'
  ) THEN
    RAISE EXCEPTION 'Invalid audio type: %. Must be MP3, WAV, M4A, or AAC', p_content_type;
  END IF;

  -- Validate file size (100MB max)
  IF p_size > 10485760000 THEN
    RAISE EXCEPTION 'File size must not exceed 100MB';
  END IF;

  -- Return normalized metadata
  RETURN jsonb_build_object(
    'content_type', normalized_type,
    'original_content_type', p_content_type,
    'size', p_size,
    'folder', folder_name,
    'filename', p_filename,
    'upload_date', CURRENT_TIMESTAMP
  );
END;
$$ LANGUAGE plpgsql;

-- Create function to handle audio file creation
CREATE OR REPLACE FUNCTION handle_audio_file_creation()
RETURNS TRIGGER AS $$
DECLARE
  folder_name TEXT;
  clean_filename TEXT;
BEGIN
  -- Get current date folder
  folder_name := get_date_folder();

  -- Clean and normalize filename
  clean_filename := LOWER(NEW.filename);
  clean_filename := regexp_replace(clean_filename, '[^a-z0-9.-]', '_', 'g');
  clean_filename := regexp_replace(clean_filename, '\.+', '.', 'g');
  clean_filename := trim(both '.' from clean_filename);

  -- Set storage path with date folder
  NEW.storage_path := folder_name || '/' || clean_filename;

  -- Set default metadata if not provided
  IF NEW.metadata IS NULL THEN
    NEW.metadata := jsonb_build_object(
      'content_type', COALESCE(NEW.content_type, 'audio/mpeg'),
      'size', COALESCE(NEW.size, 0),
      'folder', folder_name,
      'filename', clean_filename,
      'upload_date', CURRENT_TIMESTAMP
    );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for audio file creation
DROP TRIGGER IF EXISTS handle_audio_file_creation_trigger ON audio_files;
CREATE TRIGGER handle_audio_file_creation_trigger
  BEFORE INSERT ON audio_files
  FOR EACH ROW
  EXECUTE FUNCTION handle_audio_file_creation();

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_audio_files_metadata_upload_date
  ON audio_files ((metadata->>'upload_date'));

CREATE INDEX IF NOT EXISTS idx_audio_files_metadata_content_type
  ON audio_files ((metadata->>'content_type'));

CREATE INDEX IF NOT EXISTS idx_audio_files_metadata_folder
  ON audio_files ((metadata->>'folder'));

-- Update storage path constraint to match new format
DO $$ BEGIN
  ALTER TABLE audio_files
    DROP CONSTRAINT IF EXISTS valid_storage_path_format;
  
  ALTER TABLE audio_files
    ADD CONSTRAINT valid_storage_path_format 
    CHECK (storage_path ~ '^[0-9]{8}/[a-z0-9._-]+$');
EXCEPTION
  WHEN undefined_column THEN NULL;
END $$;