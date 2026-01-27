/*
  # Add updated_at column to transcription_segments

  1. Changes
    - Add updated_at column with default value
    - Add trigger to automatically update timestamp
    - Add index for better performance
*/

-- Add updated_at column if it doesn't exist
ALTER TABLE transcription_segments
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT now();

-- Create trigger to automatically update timestamp
CREATE TRIGGER set_transcription_segments_updated_at
  BEFORE UPDATE ON transcription_segments
  FOR EACH ROW
  EXECUTE FUNCTION handle_updated_at();

-- Add index for better query performance
CREATE INDEX IF NOT EXISTS idx_transcription_segments_updated_at 
  ON transcription_segments(updated_at);