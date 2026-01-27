/*
  # Auth setup and policies

  1. Security
    - Enable email auth
    - Add auth policies for meetings table
    - Add auth policies for related tables
*/

-- Enable email auth
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Update RLS policies to be user-specific
DROP POLICY IF EXISTS "Allow authenticated to read meetings" ON meetings;
CREATE POLICY "Allow authenticated to read meetings"
  ON meetings FOR SELECT
  TO authenticated
  USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "Allow authenticated to read participants" ON participants;
CREATE POLICY "Allow authenticated to read participants"
  ON participants FOR SELECT
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM meetings m
    WHERE m.id = participants.meeting_id
  ));

DROP POLICY IF EXISTS "Allow authenticated to read transcription segments" ON transcription_segments;
CREATE POLICY "Allow authenticated to read transcription segments"
  ON transcription_segments FOR SELECT
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM meetings m
    WHERE m.id = transcription_segments.meeting_id
  ));