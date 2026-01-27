/*
  # Add language and participant count fields to meetings table

  1. Changes
    - Add language_code column with valid language codes
    - Add expected_participants column as nullable integer
    - Add check constraints for validation
    - Update existing meetings with default values
*/

-- Create enum for valid language codes
DO $$ BEGIN
  CREATE TYPE valid_language_code AS ENUM ('auto', 'fr', 'de', 'it', 'en');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

-- Add new columns to meetings table
ALTER TABLE meetings
  ADD COLUMN IF NOT EXISTS language_code valid_language_code NOT NULL DEFAULT 'auto',
  ADD COLUMN IF NOT EXISTS expected_participants INTEGER CHECK (expected_participants > 0);

-- Add comment to explain columns
COMMENT ON COLUMN meetings.language_code IS 'Language code for transcription (auto, fr, de, it, en)';
COMMENT ON COLUMN meetings.expected_participants IS 'Expected number of participants (optional)';