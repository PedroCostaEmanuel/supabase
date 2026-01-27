/*
  # Fix transcription segments realtime updates

  1. Changes
    - Set REPLICA IDENTITY to FULL for transcription_segments table
    - Ensures DELETE events include complete old record data
    - Improves realtime updates for segment modifications
*/

-- Set REPLICA IDENTITY to FULL for transcription_segments table
ALTER TABLE transcription_segments REPLICA IDENTITY FULL;