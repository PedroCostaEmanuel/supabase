/*
  # Fix foreign key constraints and RLS policies

  1. Changes
    - Add explicit foreign key constraints to participants and transcription_segments tables
    - Update RLS policies to ensure proper access control

  2. Security
    - Maintain existing RLS policies
    - Ensure proper relationships between tables
*/

-- Drop existing foreign key constraints if they exist
DO $$ BEGIN
  ALTER TABLE participants DROP CONSTRAINT IF EXISTS fk_meeting;
  ALTER TABLE transcription_segments DROP CONSTRAINT IF EXISTS fk_meeting;
EXCEPTION
  WHEN undefined_object THEN NULL;
END $$;

-- Add explicit foreign key constraints
ALTER TABLE participants
  ADD CONSTRAINT fk_meeting 
  FOREIGN KEY (meeting_id) 
  REFERENCES meetings(id) 
  ON DELETE CASCADE;

ALTER TABLE transcription_segments
  ADD CONSTRAINT fk_meeting 
  FOREIGN KEY (meeting_id) 
  REFERENCES meetings(id) 
  ON DELETE CASCADE;

-- Ensure RLS is enabled
ALTER TABLE meetings ENABLE ROW LEVEL SECURITY;
ALTER TABLE participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE transcription_segments ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Allow all users to read meetings" ON meetings;
DROP POLICY IF EXISTS "Allow all users to read participants" ON participants;
DROP POLICY IF EXISTS "Allow all users to read transcription segments" ON transcription_segments;

-- Recreate policies with proper access control
CREATE POLICY "Allow all users to read meetings"
  ON meetings FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Allow all users to read participants"
  ON participants FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Allow all users to read transcription segments"
  ON transcription_segments FOR SELECT
  TO authenticated
  USING (true);

-- Ensure indexes exist
DO $$ BEGIN
  CREATE INDEX IF NOT EXISTS idx_meeting_date ON meetings(date);
  CREATE INDEX IF NOT EXISTS idx_participants_meeting ON participants(meeting_id);
  CREATE INDEX IF NOT EXISTS idx_transcription_meeting ON transcription_segments(meeting_id);
  CREATE INDEX IF NOT EXISTS idx_transcription_time ON transcription_segments(start_time, end_time);
EXCEPTION
  WHEN duplicate_table THEN NULL;
END $$;