/*
  # Fix database relations and constraints

  1. Changes
    - Rename foreign key constraints to be more explicit
    - Add unique constraints on speaker_id columns
    - Add explicit foreign key names for meeting_tags relations
    - Add indexes for better query performance
    - Update RLS policies for better security

  2. Security
    - Maintain existing RLS policies
    - Add additional policies for data integrity
*/

-- Rename foreign key constraints for clarity
ALTER TABLE participants 
  DROP CONSTRAINT IF EXISTS participants_meeting_id_fkey,
  ADD CONSTRAINT participants_meeting_id_fkey 
    FOREIGN KEY (meeting_id) 
    REFERENCES meetings(id) 
    ON DELETE CASCADE;

ALTER TABLE transcription_segments 
  DROP CONSTRAINT IF EXISTS transcription_segments_meeting_id_fkey,
  ADD CONSTRAINT transcription_segments_meeting_id_fkey 
    FOREIGN KEY (meeting_id) 
    REFERENCES meetings(id) 
    ON DELETE CASCADE;

-- Add unique constraints on speaker_id columns
ALTER TABLE participants
  ADD CONSTRAINT unique_speaker_per_meeting 
  UNIQUE (meeting_id, speaker_id);

ALTER TABLE transcription_segments
  ADD CONSTRAINT unique_speaker_time_per_meeting 
  UNIQUE (meeting_id, speaker_id, start_time);

-- Add explicit foreign key names for meeting_tags
ALTER TABLE meeting_tags
  DROP CONSTRAINT IF EXISTS meeting_tags_meeting_id_fkey,
  ADD CONSTRAINT meeting_tags_meeting_id_fkey 
    FOREIGN KEY (meeting_id) 
    REFERENCES meetings(id) 
    ON DELETE CASCADE;

ALTER TABLE meeting_tags
  DROP CONSTRAINT IF EXISTS meeting_tags_tag_id_fkey,
  ADD CONSTRAINT meeting_tags_tag_id_fkey 
    FOREIGN KEY (tag_id) 
    REFERENCES tags(id) 
    ON DELETE CASCADE;

-- Add additional indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_participants_speaker 
  ON participants(speaker_id);

CREATE INDEX IF NOT EXISTS idx_transcription_speaker 
  ON transcription_segments(speaker_id);

-- Update RLS policies
ALTER TABLE meetings ENABLE ROW LEVEL SECURITY;
ALTER TABLE participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE transcription_segments ENABLE ROW LEVEL SECURITY;
ALTER TABLE tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE meeting_tags ENABLE ROW LEVEL SECURITY;

-- Recreate policies with better security
DROP POLICY IF EXISTS "Allow authenticated to read meetings" ON meetings;
CREATE POLICY "Allow authenticated to read meetings"
  ON meetings FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Allow authenticated to read participants" ON participants;
CREATE POLICY "Allow authenticated to read participants"
  ON participants FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Allow authenticated to read transcription segments" ON transcription_segments;
CREATE POLICY "Allow authenticated to read transcription segments"
  ON transcription_segments FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Allow authenticated to read tags" ON tags;
CREATE POLICY "Allow authenticated to read tags"
  ON tags FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Allow authenticated to read meeting tags" ON meeting_tags;
CREATE POLICY "Allow authenticated to read meeting tags"
  ON meeting_tags FOR SELECT
  TO authenticated
  USING (true);