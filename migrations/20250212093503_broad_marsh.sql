/*
  # Update audio_files table structure

  1. Changes
    - Add storage_path column to store the full path in the Audio bucket
    - Add content_type column for MIME type
    - Add size column for file size in bytes
    - Add duration column for audio duration in seconds
    - Add error_message column for storing error details
    - Update status type with enum values

  2. Data Migration
    - Convert existing filenames to storage paths
*/

-- Create enum for audio file status
DO $$ BEGIN
  CREATE TYPE audio_file_status AS ENUM (
    'pending',
    'uploading',
    'processing',
    'completed',
    'error'
  );
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

-- Add new columns to audio_files table
ALTER TABLE audio_files
  ADD COLUMN storage_path TEXT,
  ADD COLUMN content_type TEXT,
  ADD COLUMN size BIGINT,
  ADD COLUMN duration FLOAT,
  ADD COLUMN error_message TEXT;

-- Update existing records to use proper storage paths
UPDATE audio_files
SET storage_path = 'PV/' || filename
WHERE storage_path IS NULL;

-- Make storage_path NOT NULL after migration
ALTER TABLE audio_files
  ALTER COLUMN storage_path SET NOT NULL,
  ALTER COLUMN storage_path SET DEFAULT '';

-- Convert status column to use the new enum
ALTER TABLE audio_files
  ALTER COLUMN status DROP DEFAULT,
  ALTER COLUMN status TYPE audio_file_status USING status::audio_file_status,
  ALTER COLUMN status SET DEFAULT 'pending'::audio_file_status;

-- Add check constraints
ALTER TABLE audio_files
  ADD CONSTRAINT audio_files_size_check 
    CHECK (size IS NULL OR size > 0),
  ADD CONSTRAINT audio_files_duration_check 
    CHECK (duration IS NULL OR duration > 0);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_audio_files_storage_path ON audio_files(storage_path);
CREATE INDEX IF NOT EXISTS idx_audio_files_content_type ON audio_files(content_type);

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