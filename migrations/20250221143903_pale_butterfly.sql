/*
  # Add audio file status enum and column

  1. Changes
    - Creates audio_file_status enum type
    - Adds status column to audio_files table
    - Sets default value and constraints
*/

-- Drop existing enum if it exists
DROP TYPE IF EXISTS audio_file_status CASCADE;

-- Create enum for audio file status
CREATE TYPE audio_file_status AS ENUM (
  'pending',
  'uploading',
  'processing',
  'completed',
  'error'
);

-- Add status column if it doesn't exist
DO $$ BEGIN
  ALTER TABLE audio_files 
    ADD COLUMN IF NOT EXISTS status audio_file_status NOT NULL DEFAULT 'pending';
EXCEPTION
  WHEN duplicate_column THEN NULL;
END $$;

-- Add check constraint if it doesn't exist
DO $$ BEGIN
  ALTER TABLE audio_files
    ADD CONSTRAINT valid_status_values 
    CHECK (status IN ('pending', 'uploading', 'processing', 'completed', 'error'));
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

-- Update any NULL status values to 'pending'
UPDATE audio_files
SET status = 'pending'
WHERE status IS NULL;