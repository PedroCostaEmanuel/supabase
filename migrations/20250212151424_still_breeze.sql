-- Add metadata column to audio_files table
ALTER TABLE audio_files
  ADD COLUMN IF NOT EXISTS metadata JSONB,
  ADD COLUMN IF NOT EXISTS folder_name TEXT GENERATED ALWAYS AS (
    split_part(storage_path, '/', 1)
  ) STORED;

-- Create index on folder_name for better query performance
CREATE INDEX IF NOT EXISTS idx_audio_files_folder ON audio_files(folder_name);

-- Create index on metadata for better query performance with JSONB
CREATE INDEX IF NOT EXISTS idx_audio_files_metadata_gin ON audio_files USING GIN (metadata);

-- Add constraint to ensure storage_path follows the date folder pattern
ALTER TABLE audio_files
  ADD CONSTRAINT valid_storage_path_format 
  CHECK (storage_path ~ '^[0-9]{8}/.*$');

-- Update RLS policies
ALTER TABLE audio_files ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Enable read access for authenticated users" ON audio_files;
CREATE POLICY "Enable read access for authenticated users"
  ON audio_files FOR SELECT
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM meetings m
    WHERE m.id = meeting_id
  ));

DROP POLICY IF EXISTS "Enable insert access for authenticated users" ON audio_files;
CREATE POLICY "Enable insert access for authenticated users"
  ON audio_files FOR INSERT
  TO authenticated
  WITH CHECK (EXISTS (
    SELECT 1 FROM meetings m
    WHERE m.id = meeting_id
  ));

DROP POLICY IF EXISTS "Enable update access for authenticated users" ON audio_files;
CREATE POLICY "Enable update access for authenticated users"
  ON audio_files FOR UPDATE
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM meetings m
    WHERE m.id = meeting_id
  ));